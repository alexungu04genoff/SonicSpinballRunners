extends SceneTree
## Normal follow-camera review. Run each launch in a fresh process at fixed 60 fps.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const Audit = preload("res://scripts/diagnostics/render_audit.gd")
const CANDIDATES := {"rooftop_run":"A", "casino_night":"B", "sky_sanctuary":"A"}
const OUTPUT := "res://test-results/motion-final"
var fixture := Fixture.new()
var theme := ""
var state := "C"
var motion: RefCounted
var folder := ""
var errors := PackedStringArray()

func _initialize() -> void:
 run.call_deferred()

func require(ok: bool, message: String) -> void:
 if not ok:
  errors.append(message)
  push_error(message)

func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--theme="): theme = arg.trim_prefix("--theme=")
  if arg.begins_with("--state="): state = arg.trim_prefix("--state=")
 if not CANDIDATES.has(theme) or state not in ["C", CANDIDATES[theme]]:
  push_error("Choose an included theme and its reviewed state.")
  quit(1)
  return
 var measuring := "--measure" in OS.get_cmdline_user_args()
 folder = OUTPUT.path_join(theme + ("-cost" if measuring else "-" + state))
 DirAccess.make_dir_recursive_absolute(folder)
 Review.position_review_window(root)
 Engine.time_scale = 0.0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Review.Options.settings_path = folder.path_join("graphics.cfg")
 Review.Options.update_quality(Review.Options.defaults(), false)
 if not await fixture.open(self, Fixture.DEFAULT_ACT, theme, folder, "default", "production"):
  push_error(fixture.error)
  quit(1)
  return
 var game := fixture.game
 var layer: Node = game.backgrounds[game.active.plan.zone].layer
 motion = layer.motion
 var report := {"fixture":fixture.receipt, "spawn":fixture.state(), "settings":Audit.settings(game),
  "device_defaults":Review.Options.quality(), "production_state":motion.candidate}
 require(fixture.authority_error().is_empty() and fixture.still_current(), "Disk authority failed")
 require(game.view.size.y == 480 and game.retro_filter.settings.crt_480p and game.retro_filter.selected_effects.size() == 3, "Expected full 480-line Retro")
 if measuring:
  report.measurements = {}
  for view: Viewport in [game.view, layer.view]:
   RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
  for i in 60: await process_frame
  for selection: String in ["C", CANDIDATES[theme]]:
   report.measurements[selection] = await measure(selection, game.view, layer.view)
 else:
  require(motion.select(state, "NATIVE"), "Candidate selection failed")
  report.edge = await right_edge()
  require(fixture.state() == report.spawn, "Normal camera did not return to the served Ball")
  report.path = await served_shot()
 report.errors = errors
 var file := FileAccess.open(folder.path_join("receipt.json"), FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 file.close()
 await fixture.close()
 print("THEME_LIFE_REVIEW | ", theme, " | ", state, " | ", errors)
 quit(0 if errors.is_empty() else 1)

func right_edge() -> Dictionary:
 var game := fixture.game
 var bounds: Rect2 = game.active.document.terrain_bounds()
 var target := Vector2(bounds.end.x - 0.6 * game.active.document.cell_size, game.ball.position.y)
 game.presentation.reset_camera(target)
 game._update_backgrounds()
 for i in 5: await process_frame
 for i in 40:
  motion.seek(4.0 + i / 20.0)
  await process_frame
  await save_frame(80 + i)
 var edge := fixture.state()
 game.presentation.reset_camera(game.ball.position)
 game._update_backgrounds()
 for i in 5: await process_frame
 return edge

func save_frame(index: int) -> void:
 await RenderingServer.frame_post_draw
 require(root.get_texture().get_image().save_jpg(folder.path_join("%03d.jpg" % index), 0.98) == OK, "Frame write failed")

func served_shot() -> Array:
 var game := fixture.game
 var path := []
 var furthest := 0.0
 var origin: Vector2 = game.ball.position
 # 1.5 seconds served, followed by the real launch. The fixture owns the
 # session overlay, while the ordinary game drives physics, camera, and scoring.
 for tick in 240:
  if tick == 90:
   paused = false
   Engine.time_scale = 1.0
   game.ball.freeze = false
   game.set_physics_process(true)
   game.launch_ball()
  motion.seek(tick / 60.0)
  await process_frame
  if tick % 3 != 0: continue
  await save_frame(path.size())
  path.append([str(game.ball.position), str(game.ball.linear_velocity), str(game.presentation.camera.global_transform),
   game.score, game.rings_collected, game.ball.serve_pending])
  furthest = maxf(furthest, origin.distance_to(game.ball.position))
 require(furthest > 40.0 and path.front()[2] != path.back()[2], "Expected a moving Ball and follow camera")
 return path

func measure(selection: String, foreground: Viewport, background: Viewport) -> Dictionary:
 var before := Fixture.Report.pipelines()
 var resources_before := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 motion.select(selection, "NATIVE")
 motion.seek(-1.0)
 for i in 48:
  motion.update(1.0 / 60.0, true)
  await process_frame
 var delta := Fixture.Report.pipelines()
 for key: String in delta: delta[key] -= before[key]
 var cpu := []
 var fg := []
 var bg := []
 for i in 120:
  var start := Time.get_ticks_usec()
  motion.update(1.0 / 60.0, true)
  cpu.append((Time.get_ticks_usec() - start) / 1000.0)
  await process_frame
  fg.append(RenderingServer.viewport_get_measured_render_time_gpu(foreground.get_viewport_rid()))
  bg.append(RenderingServer.viewport_get_measured_render_time_gpu(background.get_viewport_rid()))
 return {"update":Fixture.Report.timing(cpu), "foreground_gpu":Fixture.Report.timing(fg), "background_gpu":Fixture.Report.timing(bg),
  "foreground":Audit.viewport_state(foreground, "foreground", true), "background":Audit.viewport_state(background, "background", true),
  "motion":motion.stats(), "pipelines_on_switch":delta, "resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) - resources_before,
  "resident":resident_materials([foreground, background])}

func resident_materials(views: Array) -> Dictionary:
 var materials := {}
 var programs := {}
 for view: Viewport in views:
  for node: GeometryInstance3D in view.find_children("*", "GeometryInstance3D", true, false):
   var mesh := Audit.mesh_of(node)
   if mesh == null: continue
   var bound: Array = [node.material_overlay]
   for index in mesh.get_surface_count():
    var active: Material = node.get_active_material(index) if node is MeshInstance3D else node.material_override
    bound.append(active if active else mesh.surface_get_material(index))
   for material: Material in bound:
    while material and not materials.has(material):
     materials[material] = true
     if material is ShaderMaterial: programs[material.shader] = true
     material = material.next_pass
 return {"materials":materials.size(), "shader_programs":programs.size()}
