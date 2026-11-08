extends "res://tests/render_cost_profile.gd"
## Matched, stationary Prototype pixel-cost experiment. No player preferences.
const Session = preload("res://scripts/prototype/session.gd")
const Options = preload("res://scripts/rendering_options.gd")
const CASES := {
 "small": {"act": "Reverse C Spring", "theme": "green_hill"},
 "dense": {"act": "RampMania", "theme": "green_hill"},
 "multi": {"act": "", "theme": "green_hill"},
 "busy": {"act": "RampMania", "theme": "chemical_plant"},
}
var workload := "small"
var session: Control
var failures := 0

func verify(value: bool, message: String) -> void:
 if not value: failures += 1; push_error(message)

func run() -> void:
 samples = 600
 output = "res://test-results/pixel-cost/small.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--workload="): workload = arg.trim_prefix("--workload=")
  if arg.begins_with("--profile-output="): output = arg.trim_prefix("--profile-output=")
  if arg.begins_with("--profile-samples="): samples = maxi(120, int(arg.trim_prefix("--profile-samples=")))
 if workload not in CASES or DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
  push_error("Pixel profiling requires a named workload and graphical Forward+/Vulkan.")
  quit(1)
  return
 root.size = Vector2i(1280, 900)
 seed(18)
 theme = CASES[workload].theme
 root.gui_disable_input = true
 Engine.max_fps = 0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 Options.settings_path = output.get_basename() + "-isolated-graphics.cfg"
 verify(not FileAccess.file_exists(Options.settings_path), "Use a fresh output path; never inherit a previous graphics probe")
 verify(Options.shadow_resolution() == 8192 and Options.shadow_cascades() == 4 and not Options.smooth_shadows_enabled(), "Primary attribution uses unchanged production shadows with Smooth/FXAA off")
 session = Session.new()
 session.settings_path = output.get_basename() + "-isolated-session.cfg"
 session.sound_enabled = false
 if workload != "multi":
  session.configure_act_test("res://data/acts/Authored/" + CASES[workload].act + ".tres")
  session.run_configuration.single_act_use_bakes = true
 else:
  session.run_configuration = Run.RunPlan.Configuration.new(["res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/Reverse C Spring.tres", "res://data/acts/Authored/Secret Entry.tres"])
  session.run_configuration.zone_count = 1
 session.run_configuration.selected_theme_ids = [CASES[workload].theme]
 session.run_configuration.atmosphere_overrides = {CASES[workload].theme: "default"}
 session.practice_mode = true
 root.add_child(session)
 while is_instance_valid(session.setup_menu) and session.setup_menu.checking: await process_frame
 await session.start_run()
 game = session.game
 Report.disable_native_input(session)
 var deadline := Time.get_ticks_msec() + 180000
 while not game.started and game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
 verify(game.started, "Production disk session starts: " + game.last_source_error)
 if not game.started: quit(1); return
 game.controls.input_blocked = true
 game.auto_launch_time = -1.0
 var settled := 0
 while settled < 120 and Time.get_ticks_msec() < deadline:
  await process_frame
  if not game.library.busy and game.building == null: settled += 1
  else: settled = 0
 verify(settled == 120 and game.library.fallback_builds == 0, "All preparation settles without source fallback")
 game.fps_label.hide()
 game.presentation.set_process(false)
 if workload == "dense": game.presentation.set_camera_follow(false)
 elif workload == "multi":
  game.presentation.reset_camera(Vector2(game.active.bounds().get_center().x, game.active.bounds().position.y))
 # Freeze animation/shader time as well as gameplay for genuinely matched pixels.
 # These are stationary rendering costs, not input/streaming FPS measurements.
 session.set_process(false)
 session.overlay_root.hide()
 game.set_process(false)
 paused = true
 Engine.time_scale = 0.0
 game._update_foreground_contribution()
 if workload == "multi": verify(game.resident.size() >= 2 and game.foreground_contributing >= 2, "Multi-resident view actually draws multiple foreground Acts")
 _inspect(root)
 var identity := invariant_state()
 var phases: Array[Dictionary] = []
 # Alternating forward/reverse order reduces warm-up and clock-order bias.
 var modes := [[4,100], [2,100], [0,100], [4,85], [4,75]]
 for repeat in 2:
  var order := modes.duplicate()
  if repeat == 1: order.reverse()
  for setting: Array in order:
   Options.set_pixel_profile(setting[0], setting[1])
   for frame in 30: await process_frame
   verify(invariant_state() == identity, "Pixel control changes only the native 3D buffer")
   var label := "r%d-msaa%d-scale%d" % [repeat + 1, setting[0], setting[1]]
   var result := await _sample(label, repeat == 0)
   result["profile"] = Options.pixel_profile()
   result["viewports"] = viewport_state()
   result["texture_bytes"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
   result["buffer_bytes"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
   result["video_bytes"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
   verify(result.pipelines_start == result.pipelines_end, "No pipeline compilation inside measured block: " + label)
   phases.append(result)
 # Additional visual-only frames remove Retro; never combine these with timings.
 game.retro_filter.set_preset(0)
 for frame in 10: await process_frame
 var clean_camera := _camera_state()
 var visual_frames: Array[String] = []
 for setting: Array in [[0,100,0], [2,100,0], [4,100,0], [2,100,1], [4,85,0], [4,75,0]]:
  Options.set_pixel_profile(setting[0], setting[1], setting[2])
  _restore_camera(clean_camera)
  for frame in 12: await process_frame
  await RenderingServer.frame_post_draw
  var path := output.get_basename() + "-clean-msaa%d-scale%d-fxaa%d.png" % [setting[0], setting[1], setting[2]]
  verify(root.get_texture().get_image().save_png(path) == OK, "Save native full frame")
  visual_frames.append(path)
 var report := {"workload": workload, "metadata": Report.metadata(), "stationary": true,
  "invariants": identity, "phases": phases, "visual_only": visual_frames,
  "shadow_resolution": Options.shadow_resolution(), "shadow_cascades": Options.shadow_cascades(),
  "smooth_shadows": Options.smooth_shadows_enabled(), "fallback_builds": game.library.fallback_builds,
  "disk_acts": game.library.visual_bake_hits, "disk_themes": game.library.theme_bake_hits,
  "course": game.course_snapshot(), "failures": failures,
  "clean_viewports_final": viewport_state(),
  "note": "Primary blocks keep the shipped Retro stack and use active viewport CPU/GPU timing sums. Clean/FXAA images have no timing claims. Memory is engine-reported aggregate allocation, not physical VRAM residency."}
 var file := FileAccess.open(output, FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 file.close()
 Options.set_pixel_profile(4, 100)
 Engine.time_scale = 1.0
 paused = false
 session.archive_attempted = true
 await session._close_run("pixel_profile")
 session.free()
 print("PIXEL_COST | workload=%s blocks=%d failures=%d" % [workload, phases.size(), failures])
 quit(1 if failures else 0)

func invariant_state() -> Dictionary:
 return {"window": str(root.size), "world": str(game.view.size), "composite": str(game._composite_view.size),
  "camera": str(game.presentation.camera.global_transform), "fov": game.presentation.camera.fov,
  "ball": str(game.ball.position), "ball_id": game.ball.get_instance_id(), "score": game.score,
  "retro": game.retro_filter.selected_effects.duplicate(), "contribution": game.foreground_contribution_enabled,
  "atmosphere": game.active.plan.atmosphere.duplicate(true), "residents": game.resident.size()}

func viewport_state() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for view: Viewport in views:
  if not view is SubViewport: continue
  result.append({"path": str(view.get_path()), "size": str(view.size), "disable_3d": view.disable_3d,
   "native_3d_size": str(Vector2i(Vector2(view.size) * view.scaling_3d_scale)),
   "scale": view.scaling_3d_scale, "scaling_mode": view.scaling_3d_mode,
   "msaa": view.msaa_3d, "fxaa": view.screen_space_aa, "update_mode": view.render_target_update_mode})
 return result
