extends SceneTree
## Matched palette-only ABBA samples. Preparation and screenshot readback are
## outside steady-state samples. Run one graphical process at a time.
const Report := preload("res://tests/render_profile_support.gd")
var game: Node
var views: Array[Viewport] = []
var results: Array = []
var preparation: Array = []
var samples := 480
var output := "res://test-results/atmosphere/profile"
var only_theme := ""
var ocean_only := false
var reverse_order := false

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
 for frame in count: await process_frame

func run() -> void:
 if DisplayServer.get_name() == "headless":
  quit(1)
  return
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--atmosphere-theme="): only_theme = arg.get_slice("=", 1)
  if arg.begins_with("--atmosphere-output="): output = arg.get_slice("=", 1)
  if arg.begins_with("--atmosphere-samples="): samples = maxi(120, int(arg.get_slice("=", 1)))
  if arg == "--atmosphere-ocean": ocean_only = true
  if arg == "--atmosphere-reverse": reverse_order = true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 root.size = Vector2i(1280, 900)
 seed(18)
 var start := Time.get_ticks_usec()
 game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 game.authored_act_path = "res://data/acts/Authored/Reverse C Spring.tres"
 root.add_child(game)
 paused = true
 root.gui_disable_input = true
 Report.disable_native_input(game)
 await frames(120)
 preparation.append({"phase": "initial_load_and_120_frames", "elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0, "pipelines": Report.pipelines()})
 _views(root)
 var panel = game.lighting_controls
 panel.saved = ConfigFile.new()
 panel.drafts.clear()
 panel.reset_values()
 panel.toggle_panel()
 panel.fps_overlay.hide()
 panel.reopen.hide()
 # Keep the existing retro stack for measurements. Capture native views too.
 await frames(15)
 for theme: String in game.ThemeRegistry.IDS:
  if not only_theme.is_empty() and theme != only_theme: continue
  if ocean_only and theme != "green_hill": continue
  start = Time.get_ticks_usec()
  var pipelines_before := Report.pipelines()
  game.set_theme(theme)
  panel.reset_values()
  await frames(60)
  preparation.append({"theme": theme, "phase": "theme_load_and_60_frames", "elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0, "pipelines_before": pipelines_before, "pipelines_after": Report.pipelines()})
  var p: Node3D = game.presentation
  p.set_camera_preset(p.CameraPreset.DRAMATIC_PINBALL)
  p.camera_settings.screen_target_y = 0.55
  p.set_camera_value("zoom", 1.3)
  p.set_camera_follow(true)
  var bounds: Rect2 = p.table_bounds
  game.ball.position = bounds.position + bounds.size * Vector2(0.19, 0.877)
  p.reset_camera(game.ball.position)
  p.camera_focus.x = bounds.position.x + bounds.size.x * 0.04
  p.camera_target = p.camera_focus
  p.camera.position = p.map_point(p.camera_focus) + p._camera_offset
  # Lock the representative edge view while preserving all scenery animation.
  p.set_process(false)
  var camera: Transform3D = p.camera.transform
  var original: Dictionary = panel.originals.duplicate(true)
  var modified: Dictionary = original.duplicate(true)
  for spec: Array in panel.palette_fields:
   modified[spec[1]] = Color("452078") if spec[2] == "color" else 0.25
  var ocean: MeshInstance3D
  var stylized: Material
  var flat: StandardMaterial3D
  if ocean_only:
   for entry: Node in p.scenery_root.find_children("*", "MeshInstance3D", true, false):
    if entry.material_override is ShaderMaterial and entry.material_override.shader.resource_path.ends_with("green_hill_ocean.gdshader"):
     ocean = entry
   assert(ocean != null)
   stylized = ocean.material_override
   flat = StandardMaterial3D.new()
   flat.albedo_color = Color("24afc0")
   flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
   flat.roughness = 0.87
   flat.metallic_specular = 0.16
  var pass_index := 0
  var variants := ["old_flat", "stylized", "stylized", "old_flat"] if ocean_only else ["authored", "modified", "modified", "authored"]
  if reverse_order: variants = [variants[1], variants[0], variants[0], variants[1]]
  for variant: String in variants:
   # Changing Retro for screenshots opens a timed toast. Exclude that UI
   # variation from matched draw/object counters in the next measured pass.
   game.retro_controls.toast.hide()
   start = Time.get_ticks_usec()
   pipelines_before = Report.pipelines()
   if ocean_only: ocean.material_override = flat if variant == "old_flat" else stylized
   else:
    panel.values = modified if variant == "modified" else original
    panel.apply_values()
   var apply_ms := (Time.get_ticks_usec() - start) / 1000.0
   var prep_times: Array = []
   var prep_gpu: Array = []
   var previous := Time.get_ticks_usec()
   for frame in 60:
    await process_frame
    var now := Time.get_ticks_usec()
    prep_times.append((now - previous) / 1000.0)
    prep_gpu.append(_render_time(true))
    previous = now
   preparation.append({"theme": theme, "phase": variant, "pass": pass_index, "apply_cpu_ms": apply_ms, "first_60_frames": Report.timing(prep_times), "first_60_gpu": Report.timing(prep_gpu), "pipelines_before": pipelines_before, "pipelines_after": Report.pipelines()})
   await frames(120)
   results.append(await sample(theme, variant, pass_index))
   assert(p.camera.transform.is_equal_approx(camera), "Matched camera changed during sample")
   if pass_index < 2: await capture(theme + "-" + variant)
   pass_index += 1
  if ocean_only: ocean.material_override = stylized
  else:
   for look: String in ["Sunset", "Night"]:
    panel.values = panel.LightingLooks.create(look, original, theme)
    panel.apply_values()
    await frames(60)
    await capture(theme + "-" + look.to_lower())
   panel.reset_values()
  p.set_process(true)
 var report := {"samples_per_pass": samples, "preparation": preparation, "results": results, "window": [1280, 900], "act": "Reverse C Spring", "camera": "50 degrees / 52 FOV / 1.3 zoom / left edge", "retro": "existing default stack", "note": "Standalone generated Act; palette-only comparison, unchanged lights/shadows. Preparation windows include ordinary frames; they are not isolated compiler timings."}
 report.merge(Report.metadata())
 var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 file.close()
 game.free()
 quit()

func _views(node: Node) -> void:
 if node is Viewport:
  views.append(node)
  RenderingServer.viewport_set_measure_render_time(node.get_viewport_rid(), true)
 for child: Node in node.get_children(): _views(child)

func _render_time(gpu: bool) -> float:
 var result := 0.0
 for view: Viewport in views:
  if view is SubViewport and view.render_target_update_mode == SubViewport.UPDATE_DISABLED: continue
  result += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid()) if gpu else RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())
 return result

func sample(theme: String, variant: String, pass_index: int) -> Dictionary:
 var columns := {"frame_ms": [], "render_cpu_ms": [], "render_gpu_ms": [], "draw_calls": [], "rendered_objects": [], "resources": []}
 var before := Report.pipelines()
 var previous := Time.get_ticks_usec()
 for frame in samples:
  await process_frame
  var now := Time.get_ticks_usec()
  columns.frame_ms.append((now - previous) / 1000.0)
  columns.render_cpu_ms.append(_render_time(false))
  columns.render_gpu_ms.append(_render_time(true))
  columns.draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
  columns.rendered_objects.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
  columns.resources.append(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
  previous = now
 var result := {"theme": theme, "variant": variant, "pass": pass_index, "world_size": str(game.view.size), "camera": var_to_str(game.presentation.camera.transform), "pipelines_before": before, "pipelines_after": Report.pipelines()}
 for key: String in columns:
  var values: Array = columns[key]
  values.sort()
  result[key + "_median"] = values[values.size() / 2]
  result[key + "_p95"] = values[int(values.size() * 0.95)]
 var active_materials := {}
 for node: Node in game.presentation.find_children("*", "GeometryInstance3D", true, false):
  if node.material_override != null: active_materials[node.material_override.get_instance_id()] = true
  elif node is MeshInstance3D and node.mesh != null:
   for surface in node.mesh.get_surface_count():
    var material: Material = node.get_active_material(surface)
    if material != null: active_materials[material.get_instance_id()] = true
  elif node is MultiMeshInstance3D and node.multimesh != null:
   var mesh: Mesh = node.multimesh.mesh
   for surface in mesh.get_surface_count():
    var material := mesh.surface_get_material(surface)
    if material != null: active_materials[material.get_instance_id()] = true
 result.active_materials = active_materials.size()
 print("ATMOSPHERE_PROFILE | ", JSON.stringify(result))
 return result

func capture(label: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label + ".png"))
 var effects: Array = game.retro_filter.selected_effects.duplicate()
 var camera: Transform3D = game.presentation.camera.transform
 game.retro_filter.set_effects([])
 game.retro_controls.toast.hide()
 await frames(12)
 game.presentation.camera.transform = camera
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label + "-native.png"))
 game.retro_filter.set_effects(effects)
 game.retro_controls.toast.hide()
 await frames(12)
 game.presentation.camera.transform = camera
