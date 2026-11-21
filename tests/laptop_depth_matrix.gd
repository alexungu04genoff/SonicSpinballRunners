extends SceneTree
## Each case opens the same disk-backed course in a fresh engine process.
const Course = preload("res://scripts/diagnostics/grounding_endless.gd")
const Sampler = preload("res://scripts/diagnostics/render_sampler.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const Options = Review.Options
const CASES := ["smooth85", "four85", "four85-low-contact", "four75"]
var game := Course.new()
var sampler := Sampler.new()
var output := ""
var case_id := ""
var failures := PackedStringArray()
var pipeline_events := []
var previous_pipelines := {}
var evidence := {}

func _initialize() -> void:
 run.call_deferred()

func require(ok: bool, message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)

func tick() -> void:
 var previous := sampler.previous
 sampler.tick()
 var counters := Sampler.Report.pipelines()
 if counters != previous_pipelines:
  pipeline_events.append({"phase": sampler.phase, "elapsed_ms": (sampler.previous-sampler.started)/1000.0,
   "frame_interval_ms": (sampler.previous-previous)/1000.0, "cumulative": counters})
  previous_pipelines = counters

func phase_frames(label: String, seconds: float) -> void:
 sampler.phase = label
 var until := Time.get_ticks_usec() + int(seconds*1000000)
 while Time.get_ticks_usec() < until:
  await process_frame
  tick()

func screenshot(name: String) -> void:
 await RenderingServer.frame_post_draw
 require(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Could not save " + name)
 # Readback and PNG encoding are outside all timing phases.
 sampler.previous = Time.get_ticks_usec()

func settings() -> Dictionary:
 var report := Sampler.Audit.settings(game)
 var env: Environment = game.presentation._world_environment.environment
 var policy = game.terrain_shadows
 report.merge({"device_policy": Options.quality(), "ssao": env.ssao_enabled, "ssao_intensity": env.ssao_intensity,
  "ssao_radius": env.ssao_radius, "ssao_power": env.ssao_power, "raster_lines": game.retro_filter.crt_display.get_shader_parameter("raster_lines"),
  "world_size": str(game.view.size), "actual_scale": game.view.scaling_3d_scale, "actual_msaa": game.view.msaa_3d,
  "active_cast_levels": policy.bands.LEVEL_COUNTS[policy.bands.mode] if policy.bands and policy.bands.active else 0,
  "cast_receivers": policy.bands.stats().receivers if policy.bands else 0})
 return report

func phase_totals() -> Dictionary:
 var intervals := {}
 for group: String in sampler.distributions:
  var phase := group.get_slice("/", 0)
  if not intervals.has(phase): intervals[phase] = []
  intervals[phase].append_array(sampler.distributions[group])
 var totals := {}
 for phase: String in intervals: totals[phase] = Sampler.Report.timing(intervals[phase])
 return totals

func verify_display(report: Dictionary) -> void:
 var four := case_id != "smooth85"
 require(report.ssao and report.raster_lines == 480 and game.view.size.y == 480 and game.retro_filter.selected_effects == game.retro_filter.settings.default_effects and game.retro_filter.selected_effects.size() == 3, "Expected native SSAO and full 480-line Retro")
 require(report.active_cast_levels == (4 if four else 0) and (not four or report.cast_receivers > 0), "Cast treatment missing")
 require(is_equal_approx(report.actual_scale, 0.75 if case_id == "four75" else 0.85) and report.actual_msaa == Viewport.MSAA_2X and report.fxaa and report.cascade_count == 1 and Options.shadow_resolution() == 2048, "Unexpected laptop settings")

func measure() -> void:
 var start := Time.get_ticks_usec()
 sampler.begin(game)
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 150000
 while not game.started and game.library.error.is_empty() and Time.get_ticks_msec() < deadline:
  await process_frame
  tick()
 evidence.startup_ms = (Time.get_ticks_usec()-start)/1000.0
 require(game.started, "Startup failed: " + game.library.error)
 if not game.started: return
 game.controls.input_blocked = true
 game.auto_launch_time = -1
 sampler.phase = "next_zone_preparation"
 start = Time.get_ticks_usec()
 deadline = Time.get_ticks_msec() + 120000
 while not (game._zone_ready(1) and game.resident.any(func(act): return act.ready and act.plan.sequence == 3)):
  if Time.get_ticks_msec() >= deadline or not game.library.error.is_empty():
   require(false, "Next Zone missed its preparation deadline: " + game.library.error)
   return
  await process_frame
  tick()
 evidence.next_zone_preparation_ms = (Time.get_ticks_usec()-start)/1000.0
 game.reset_ball(false)
 await phase_frames("stationary", 3.0)
 evidence.opening = settings()
 verify_display(evidence.opening)
 await screenshot("stationary")
 var start_position: Vector2 = game.ball.position
 game.launch_ball()
 sampler.phase = "normal_play"
 var distance := 0.0
 var end_tick := Engine.get_physics_frames() + 480
 while Engine.get_physics_frames() < end_tick:
  await process_frame
  tick()
  distance = maxf(distance, start_position.distance_to(game.ball.position))
 evidence.ball_max_displacement_px = distance
 require(distance > 20.0, "Served ball failed to move during normal physics")
 game.toggle_tour()
 game.tour_speed = 100.0
 var camera_start: Vector2 = game.presentation.camera_focus
 await phase_frames("camera_tour", 2.5)
 require(camera_start.distance_to(game.presentation.camera_focus) > 20.0, "Camera tour did not move")
 var boundary: RefCounted
 for act: RefCounted in game.resident:
  if act.plan.sequence == 2: boundary = act
 require(boundary != null, "Boundary Act missing")
 if not boundary: return
 game._activate(boundary)
 game.presentation.tour_focus = Vector2(boundary.bounds().get_center().x, game.backgrounds[1].entrance_y + 260.0)
 game.tour_speed = 110.0
 sampler.phase = "relocation_excluded"
 for i in 8:
  await process_frame
  tick()
 sampler.phase = "zone_crossfade"
 var overlap_frames := 0
 deadline = Time.get_ticks_msec() + 45000
 while game._background_zone < 1 and Time.get_ticks_msec() < deadline:
  await process_frame
  tick()
  if game.background_blend > 0.0 and game.background_blend < 1.0: overlap_frames += 1
 evidence.overlap_frames = overlap_frames
 require(overlap_frames > 0 and game._background_zone == 1, "Crossfade did not complete")
 game.tour_speed = 0.0
 await phase_frames("after_crossfade", 1.0)
 evidence.destination = settings()
 verify_display(evidence.destination)
 await screenshot("destination")

func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--case="): case_id = arg.trim_prefix("--case=")
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
 if case_id not in CASES or output.is_empty() or RenderingServer.get_current_rendering_method() != "forward_plus" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
  push_error("Select a laptop case, output folder and Forward+ Vulkan.")
  quit(1)
  return
 DirAccess.make_dir_recursive_absolute(output)
 Review.position_review_window(root)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps = 0
 seed(18)
 Options.settings_path = output.path_join("isolated-graphics.cfg")
 var profile := Options.LAPTOP.duplicate()
 if case_id != "smooth85": profile.shadow_treatment = Options.ShadowTreatment.FOUR_CAST
 if case_id == "four75": profile.scale_percent = 75
 Options.update_quality(profile, false)
 var ao := {}
 for key: String in ["quality","half_size","adaptive_target","blur_passes","fadeout_from","fadeout_to"]:
  ao[key] = ProjectSettings.get_setting("rendering/environment/ssao/" + key)
 if case_id == "four85-low-contact": ao.quality = RenderingServer.ENV_SSAO_QUALITY_LOW
 RenderingServer.environment_set_ssao_quality(ao.quality,ao.half_size,ao.adaptive_target,ao.blur_passes,ao.fadeout_from,ao.fadeout_to)
 evidence.ssao_submitted = ao
 game.diagnostic_theme = "green_hill"
 game.next_theme = "chemical_plant"
 sampler.checkpoint_directory = output
 await measure()
 require(game.library.fallback_builds == 0 and game.library.error.is_empty(), "Disk recipe fallback or loader error")
 evidence.disk_act_hits = game.library.visual_bake_hits
 evidence.disk_theme_hits = game.library.theme_bake_hits
 sampler.write(output, {"case_id":case_id, "evidence":evidence, "failures":failures,
  "frame_intervals_by_phase":phase_totals(), "pipeline_changes":pipeline_events}, evidence.get("opening", {"startup_failed":true}))
 await game.prepare_to_close()
 game.free()
 for frame in 4: await process_frame
 print("LAPTOP_DEPTH_RESULT | ",case_id," failures=",failures)
 quit(0 if failures.is_empty() else 1)
