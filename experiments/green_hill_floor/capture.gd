extends SceneTree
## Explicit disk-backed Prototype study. No production entry point loads it.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const Audit = preload("res://scripts/diagnostics/render_audit.gd")
const Study = preload("res://experiments/green_hill_floor/study.gd")
const Options = Review.Options
var output := "res://test-results/green-hill-floor"
var errors := PackedStringArray()
var records := {}
var fixture := Fixture.new()
var study := Study.new()
var pose := {}
var baseline: Image
var previous_image: Image

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, message: String) -> void:
 if not ok:
  errors.append(message)
  push_error(message)

func inventory() -> Dictionary:
 var materials := {}
 var programs := {}
 for node: GeometryInstance3D in fixture.game.active.visual.find_children("*", "GeometryInstance3D", true, false):
  var mesh := Audit.mesh_of(node)
  if not mesh: continue
  var bound: Array = [node.material_overlay]
  for surface in mesh.get_surface_count():
   var material: Material = node.material_override
   if not material: material = mesh.surface_get_material(surface)
   bound.append(material)
  for material: Material in bound:
   if not material: continue
   materials[material] = true
   if material is ShaderMaterial: programs[material.shader] = true
 return {"bound_act_materials": materials.size(), "bound_act_shader_programs": programs.size()}

func frame() -> Image:
 for i in 5: await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()

func capture_pan(label: String) -> void:
 var folder := output.path_join("pan-" + label)
 DirAccess.make_dir_recursive_absolute(folder)
 var origin: Vector2 = fixture.game.ball.position
 for i in 72:
  var amount := 0.5 - 0.5 * cos(TAU * i / 72.0)
  fixture.game.presentation.reset_camera(origin + Vector2(-95, -140) * amount)
  fixture.game._update_backgrounds()
  await process_frame
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(folder.path_join("%03d.png" % i)) == OK, "Cannot save pan")
 fixture.game.presentation.reset_camera(origin)
 fixture.game._update_backgrounds()
 check(pose == fixture.state(), "Pan failed to restore served pose")

func capture(label: String, started: int, before: Dictionary, prep_ms: float) -> void:
 var image := await frame()
 var first_readback_ms := (Time.get_ticks_usec() - started) / 1000.0
 var view: SubViewport = fixture.game.view
 var intervals := []
 var gpu := []
 var last := Time.get_ticks_usec()
 for i in 48:
  await process_frame
  var now := Time.get_ticks_usec()
  intervals.append((now-last)/1000.0)
  last = now
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid()))
 check(image.save_png(output.path_join(label + ".png")) == OK, "Cannot save " + label)
 check(pose == fixture.state(), "Camera or simulation moved at " + label)
 if label == "A": baseline = image
 if previous_image: check(image.get_data() != previous_image.get_data(), "Comparison has no visible effect: " + label)
 previous_image = image
 var environment: Environment = fixture.game.presentation._world_environment.environment
 var policy = fixture.game.terrain_shadows
 records[label] = {"cpu_apply_ms": prep_ms, "first_five_frames_and_readback_ms": first_readback_ms,
  "frame_intervals": Fixture.Report.timing(intervals), "foreground_gpu": Fixture.Report.timing(gpu),
  "foreground": Audit.viewport_state(view,"foreground",true), "act_inventory": inventory(),
  "pipelines_before": before, "pipelines_after": Fixture.Report.pipelines(),
  "quality": Options.quality(), "ssao_enabled": environment.ssao_enabled, "ssao_intensity": environment.ssao_intensity,
  "cast_receivers": policy.bands.stats() if policy.bands else {}, "settings": Audit.settings(fixture.game)}
 print("FLOOR_FRAME | ", label)

func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
 DirAccess.make_dir_recursive_absolute(output)
 Review.position_review_window(root)
 Engine.time_scale = 0.0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Options.settings_path = output.path_join("isolated-graphics.cfg")
 Options.update_quality(Options.defaults(), false)
 var themes: Array = Fixture.Registry.IDS.duplicate() if "--audit" in OS.get_cmdline_user_args() else ["green_hill"]
 check(RenderingServer.get_current_rendering_method() == "forward_plus" and RenderingServer.get_current_rendering_driver_name() == "vulkan", "Requires Forward+ Vulkan")
 var receipts := {}
 for theme: String in themes:
  var start := Time.get_ticks_usec()
  var pipelines := Fixture.Report.pipelines()
  if not await fixture.open(self, Fixture.DEFAULT_ACT, theme, output, "default", "production"):
   check(false, fixture.error)
   break
  var startup_ms := (Time.get_ticks_usec()-start)/1000.0
  RenderingServer.viewport_set_measure_render_time(fixture.game.view.get_viewport_rid(), true)
  if pose.is_empty(): pose = fixture.state()
  check(pose == fixture.state(), "Unmatched theme pose")
  check(fixture.still_current() and fixture.authority_error().is_empty(), "Disk recipe freshness/authority " + theme)
  check(fixture.game.retro_filter.settings.crt_480p and fixture.game.retro_filter.selected_effects.size() == 3, "Full Retro")
  receipts[theme] = {"receipt": fixture.receipt, "startup_ms": startup_ms, "pipelines_at_start": pipelines}
  if theme == "green_hill":
   for label: String in ["A","B","C","D"]:
    pipelines = Fixture.Report.pipelines()
    start = Time.get_ticks_usec()
    if label in ["B","C"]: check(study.apply(fixture.game.active.visual, label == "C"), "Could not bind the Green Hill ground")
    if label == "D": Options.update_quality({"shadow_treatment": Options.ShadowTreatment.FOUR_CAST}, false)
    await capture(label, start, pipelines, (Time.get_ticks_usec()-start)/1000.0)
    if label in ["A", "D"] and "--pan" in OS.get_cmdline_user_args(): await capture_pan(label)
   check(fixture.game.terrain_shadows.bands != null and fixture.game.terrain_shadows.bands.stats().receivers > 0, "Four-tone cast receivers")
   Options.update_quality(Options.defaults(), false)
   await frame()
   study.restore()
   check((await frame()).get_data() == baseline.get_data(), "Restoring the floor and depth must reproduce A")
  else:
   check((await frame()).save_png(output.path_join(theme + ".png")) == OK, "Cannot save audit frame")
  if "--audit" in OS.get_cmdline_user_args():
   fixture.game.presentation.reset_camera(Vector2(275, 250))
   fixture.game._process(0.0)
   receipts[theme].upper_camera = fixture.state()
   check((await frame()).save_png(output.path_join(theme + "-upper.png")) == OK, "Cannot save upper court")
  await fixture.close()
  paused = false
  if not errors.is_empty(): break
 await fixture.close()
 FileAccess.open(output.path_join("study.json"),FileAccess.WRITE).store_string(JSON.stringify({"errors":errors,"state":pose,"themes":receipts,"frames":records},"  "))
 print("FLOOR_RESULT | ", errors)
 quit(0 if errors.is_empty() else 1)
