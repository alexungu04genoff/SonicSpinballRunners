extends SceneTree
## Isolated, reversible presentation experiment. No production files are changed.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const OUTPUT := "res://experiments/rooftop_lighting/captures/"
const NAMES := ["current", "lighting-only", "normal-only", "normal-roughness", "material-detail", "convex-normal", "convex-parallax"]
const HEIGHT_MODES := [1, 2, 5, 6]
const HEIGHT_LABELS := {1: "Flat floor", 2: "Old edge normal", 5: "Convex normal", 6: "Convex + parallax"}
var settings = preload("res://experiments/rooftop_lighting/settings.tres").duplicate()
var game: Node
var original_environment: Environment
var original_light := {}
var slots: Array[Dictionary] = []
var replacements := {}
var floor_material: ShaderMaterial
var detail_floor: ShaderMaterial
var convex_floor: ShaderMaterial
var height_study := false
var close_camera := false
var output_path := OUTPUT
var selected := 1
var label: Label
var baseline_geometry: Dictionary
var baseline_camera: Transform3D
var gameplay_camera_state := {}
var failures := 0
var report := {}
const SLIDERS := {"key_energy": [0.4, 2.0], "key_elevation": [-75.0, -15.0], "key_azimuth": [-180.0, 180.0], "ambient_energy": [0.05, 0.8], "exposure": [0.5, 1.8], "normal_strength": [0.0, 0.8], "roughness_variation": [0.0, 1.0], "floor_specular": [0.0, 0.5], "ssao_intensity": [0.0, 2.0]}

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count: await process_frame

func walk(node: Node, action: Callable) -> void:
 action.call(node)
 for child in node.get_children(): walk(child, action)

func geometry_fingerprint() -> Dictionary:
 var state := {}
 walk(game, func(node: Node) -> void:
  var values: Array = []
  if node is GeometryInstance3D: values.append(node.global_transform)
  if node is PhysicsBody2D or node is Area2D or node is CollisionShape2D: values.append(node.global_transform)
  if node is MeshInstance3D:
   values.append(node.mesh.get_instance_id())
   for index in node.mesh.get_surface_count(): values.append(node.mesh.surface_get_arrays(index))
  if node is MultiMeshInstance3D:
   values.append([node.multimesh.mesh.get_instance_id(), node.multimesh.buffer])
  if node is CollisionShape2D: values.append([node.shape.get_instance_id(), node.shape.get_rid()])
  if not values.is_empty(): state[str(node.get_path())] = hash(values)
 )
 return state

func run() -> void:
 root.size = Vector2i(1440, 1000)
 height_study = "--height-study" in OS.get_cmdline_user_args() or "--capture-height-study" in OS.get_cmdline_user_args() or "--height-controls-smoke" in OS.get_cmdline_user_args()
 if height_study:
  output_path = OUTPUT + "height-study/"
  DirAccess.make_dir_recursive_absolute(output_path)
 var act := "res://experiments/rooftop_lighting/existing_act.tres"
 var source_bytes := FileAccess.get_file_as_bytes(act)
 game = Game.new()
 game.authored_act_path = act
 game.theme_id = "rooftop_run"
 root.add_child(game)
 await frames(20)
 paused = true
 game.retro_filter.set_preset(0)
 game.presentation.set_camera_follow(false)
 await frames(5)
 walk(game, func(node: Node) -> void: node.process_mode = Node.PROCESS_MODE_DISABLED)
 var camera: Camera3D = game.presentation.camera
 gameplay_camera_state = {"transform": camera.transform, "projection": camera.projection, "fov": camera.fov, "size": camera.size}
 var target: Vector3 = game.presentation.map_point(game.presentation.table_bounds.get_center() + Vector2(0, 90), 0.15)
 camera.projection = Camera3D.PROJECTION_PERSPECTIVE
 camera.fov = 44
 camera.position = target + Vector3(0.4, 3.8, 5.2)
 camera.look_at(target)
 baseline_camera = camera.transform
 original_environment = game.presentation._world_environment.environment.duplicate(true)
 for property in ["rotation_degrees", "light_color", "light_energy", "shadow_bias", "shadow_normal_bias", "directional_shadow_max_distance", "directional_shadow_mode"]:
  original_light[property] = game.presentation._key_light.get(property)
 floor_material = game.presentation.theme_definition.floor_material
 detail_floor = ShaderMaterial.new()
 detail_floor.shader = preload("res://experiments/rooftop_lighting/floor.gdshader")
 detail_floor.set_shader_parameter("surface_texture", floor_material.get_shader_parameter("surface_texture"))
 detail_floor.set_shader_parameter("normal_texture", preload("res://experiments/rooftop_lighting/floor_normal.png"))
 detail_floor.set_shader_parameter("roughness_texture", preload("res://experiments/rooftop_lighting/floor_roughness.png"))
 convex_floor = ShaderMaterial.new()
 convex_floor.shader = preload("res://experiments/rooftop_lighting/convex_floor.gdshader")
 convex_floor.set_shader_parameter("surface_texture", floor_material.get_shader_parameter("surface_texture"))
 convex_floor.set_shader_parameter("normal_texture", preload("res://experiments/rooftop_lighting/floor_convex_normal_gl.png"))
 convex_floor.set_shader_parameter("height_texture", preload("res://experiments/rooftop_lighting/floor_height.png"))
 walk(game.presentation, func(node: Node) -> void:
  if node is GeometryInstance3D and node.material_override:
   slots.append({"node": node, "surface": -1, "material": node.material_override})
  elif node is MeshInstance3D:
   for index in node.mesh.get_surface_count():
    var material: Material = node.get_active_material(index)
    if material: slots.append({"node": node, "surface": index, "material": material})
 )
 baseline_geometry = geometry_fingerprint()
 var document: String = game.authored_document.fingerprint()
 var ball_identity: int = game.ball.get_instance_id()
 RenderingServer.viewport_set_measure_render_time(game.retro_filter.world_view.get_viewport_rid(), true)
 print("EXPERIMENT | ", Engine.get_version_info().string, " | ", RenderingServer.get_current_rendering_method())
 print("SCENE | ", game.presentation.table_bounds, " | material slots ", slots.size())
 var floor_slots := 0
 for slot in slots:
  if slot.material == floor_material: floor_slots += 1
 print("FLOOR SLOTS | ", floor_slots)
 if floor_slots == 0:
  push_error("No floor materials matched; comparison would be invalid.")
  quit(1)
  return
 if "--capture-height-study" in OS.get_cmdline_user_args():
  for mode in HEIGHT_MODES:
   apply_mode(mode)
   await frames(12)
   await capture("overview-" + NAMES[mode])
  var close_target: Vector3 = game.presentation.map_point(Vector2(465, 420), 0.02)
  camera.position = close_target + Vector3(0.1, 1.0, 1.4)
  camera.look_at(close_target)
  baseline_camera = camera.transform
  for mode in HEIGHT_MODES:
   apply_mode(mode)
   await frames(12)
   await capture("close-" + NAMES[mode])
  settings.height_strength = 0.0
  apply_mode(6)
  await frames(8)
  await capture("parallax-zero")
  settings.convex_normal_strength = 0.0
  apply_mode(5)
  await frames(8)
  await capture("normal-zero")
  if source_bytes != FileAccess.get_file_as_bytes(act) or document != game.authored_document.fingerprint() or ball_identity != game.ball.get_instance_id(): failures += 1
  report["failures"] = failures
  report["document"] = document
  report["renderer"] = RenderingServer.get_current_rendering_method()
  report["floor_slots"] = floor_slots
  var file := FileAccess.open(output_path + "validation.json", FileAccess.WRITE)
  file.store_string(JSON.stringify(report, "  "))
  print("RESULT | Convex height review | ", failures, " failures")
  quit(1 if failures else 0)
 elif "--capture-review" in OS.get_cmdline_user_args():
  for mode in 5:
   apply_mode(mode)
   await frames(12)
   await capture(NAMES[mode])
  # Controlled ablations quantify each setting without rebuilding geometry.
  settings.ssao_enabled = false
  apply_mode(1)
  await frames(12)
  await capture("lighting-no-ao")
  settings.ssao_enabled = true
  apply_mode(0)
  await frames(10)
  await capture("current-restored")
  # A second fixed camera makes the small floor response easier to inspect.
  var close_target: Vector3 = game.presentation.map_point(Vector2(465, 420), 0.02)
  camera.position = close_target + Vector3(0.1, 1.0, 1.4)
  camera.look_at(close_target)
  baseline_camera = camera.transform
  for mode in [1, 2, 3]:
   apply_mode(mode)
   await frames(12)
   await capture("floor-close-" + NAMES[mode])
  if source_bytes != FileAccess.get_file_as_bytes(act) or document != game.authored_document.fingerprint() or ball_identity != game.ball.get_instance_id(): failures += 1
  report["failures"] = failures
  report["document"] = document
  report["renderer"] = RenderingServer.get_current_rendering_method()
  report["camera"] = str(baseline_camera)
  var file := FileAccess.open(OUTPUT + "validation.json", FileAccess.WRITE)
  file.store_string(JSON.stringify(report, "  "))
  print("RESULT | Rooftop lighting review | ", failures, " failures")
  quit(1 if failures else 0)
 else:
  walk(game, func(node: Node) -> void:
   if node is CanvasLayer: node.hide()
  )
  build_controls()
  apply_mode(1)
  if height_study: set_review_camera(true)
  if "--control-smoke" in OS.get_cmdline_user_args() or "--height-controls-smoke" in OS.get_cmdline_user_args():
   var controls: Node = root.get_node("ExperimentControls")
   walk(controls, func(node: Node) -> void:
    if node is Button and not node is CheckButton: node.pressed.emit()
    if node is HSlider:
     var value: float = node.value
     node.value = value + node.step
     node.value = value
    if node is CheckButton:
     node.button_pressed = not node.button_pressed
     node.button_pressed = not node.button_pressed
   )
   apply_mode(5 if height_study else 4)
   if height_study: set_review_camera(true)
   await frames(8)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output_path + "controls.png")
   print("RESULT | Controls smoke | ", "PASS" if geometry_fingerprint() == baseline_geometry else "FAIL")
   quit(0 if geometry_fingerprint() == baseline_geometry else 1)

func set_review_camera(close: bool) -> void:
 close_camera = close
 var camera: Camera3D = game.presentation.camera
 var target: Vector3
 if close:
  target = game.presentation.map_point(Vector2(465, 420), 0.02)
  camera.position = target + Vector3(0.1, 1.0, 1.4)
 else:
  target = game.presentation.map_point(game.presentation.table_bounds.get_center() + Vector2(0, 90), 0.15)
  camera.position = target + Vector3(0.4, 3.8, 5.2)
 camera.look_at(target)
 baseline_camera = camera.transform

func apply_mode(mode: int) -> void:
 selected = mode
 game.presentation._world_environment.environment = original_environment.duplicate(true)
 var world: Environment = game.presentation._world_environment.environment
 var light: DirectionalLight3D = game.presentation._key_light
 for property in original_light: light.set(property, original_light[property])
 if mode > 0:
  light.rotation_degrees = Vector3(settings.key_elevation, settings.key_azimuth, 0)
  light.light_color = settings.key_color
  light.light_energy = settings.key_energy
  light.shadow_bias = settings.shadow_bias
  light.shadow_normal_bias = settings.shadow_normal_bias
  light.directional_shadow_max_distance = settings.shadow_distance
  world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
  world.ambient_light_energy = settings.ambient_energy
  world.ambient_light_sky_contribution = settings.sky_contribution
  world.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
  world.tonemap_mode = settings.tonemap_mode
  world.tonemap_exposure = settings.exposure
  world.ssao_enabled = settings.ssao_enabled
  world.ssao_radius = settings.ssao_radius
  world.ssao_intensity = settings.ssao_intensity
  world.ssao_power = 1.0
  world.ssao_detail = 0.25
  world.ssao_light_affect = settings.ssao_light_affect
  world.fog_enabled = settings.fog_enabled
  world.fog_density = settings.fog_density
 detail_floor.set_shader_parameter("normal_strength", settings.normal_strength)
 detail_floor.set_shader_parameter("roughness_variation", settings.roughness_variation if mode in [3, 4] else 0.0)
 detail_floor.set_shader_parameter("specular_strength", settings.floor_specular if mode in [3, 4] else 0.0)
 convex_floor.set_shader_parameter("normal_strength", settings.convex_normal_strength)
 convex_floor.set_shader_parameter("parallax_enabled", mode == 6)
 convex_floor.set_shader_parameter("height_strength", settings.height_strength)
 convex_floor.set_shader_parameter("parallax_steps", settings.parallax_steps)
 for slot in slots:
  var material: Material = slot.material
  if mode >= 2 and material == floor_material: material = convex_floor if mode in [5, 6] else detail_floor
  elif mode == 4: material = response_material(material)
  if slot.surface == -1: slot.node.material_override = material
  else: slot.node.set_surface_override_material(slot.surface, material)
 if is_instance_valid(label): label.text = "Mode: " + str(HEIGHT_LABELS.get(mode, NAMES[mode])) + " | Fixed geometry and camera"

func response_material(original: Material) -> Material:
 var key := original.get_instance_id()
 if replacements.has(key): return replacements[key]
 var result: Material = original
 if original is StandardMaterial3D:
  # Restrict the experiment to the theme's scenery palette; leave Sonic, rings,
  # flippers, effects and gameplay markers on their original materials.
  var palette: Dictionary = game.presentation.theme_definition._library.materials
  for name in palette:
   if palette[name] != original: continue
   result = original.duplicate()
   result.roughness = {"roof": 0.62, "roof_light": 0.65, "shutter": 0.68, "dark": 0.72, "wood": 0.82, "leaf": 0.92, "leaf_light": 0.92}.get(name, 0.86)
   result.metallic_specular = 0.23
   break
 elif original is ShaderMaterial and original.shader.resource_path in ["res://scripts/themes/texture_surface.gdshader", "res://scripts/themes/texture_wall.gdshader", "res://scripts/themes/terrain_border.gdshader"]:
  result = original.duplicate()
  var shader := Shader.new()
  shader.code = original.shader.code.replace(", specular_disabled", "").replace("ROUGHNESS = 1.0;", "ROUGHNESS = 0.84; SPECULAR = 0.2;").replace("ROUGHNESS = 0.95;", "ROUGHNESS = 0.84; SPECULAR = 0.2;")
  result.shader = shader
 replacements[key] = result
 return result

func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 var image: Image = game.retro_filter.world_view.get_texture().get_image()
 if image.save_png(output_path + name + ".png") != OK: failures += 1
 var actual := geometry_fingerprint()
 var unchanged: bool = actual == baseline_geometry and game.presentation.camera.transform == baseline_camera
 if actual != baseline_geometry:
  for key in actual:
   if actual[key] != baseline_geometry.get(key): print("CHANGED GEOMETRY | ", key)
 if not unchanged: failures += 1
 # ANGLE can return zero because GPU timer queries are unavailable. Never report that as a zero-cost pass.
 var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(game.retro_filter.world_view.get_viewport_rid())
 report[name] = {"geometry_camera_unchanged": unchanged, "gpu_ms": gpu_ms if gpu_ms > 0.0 else null, "size": str(image.get_size()), "camera": str(baseline_camera), "fov": game.presentation.camera.fov}
 if height_study:
  report[name]["normal_strength"] = settings.convex_normal_strength if selected in [5, 6] else (settings.normal_strength if selected == 2 else 0.0)
  report[name]["height_strength"] = settings.height_strength if selected == 6 else 0.0
  report[name]["lighting"] = [str(game.presentation._key_light.rotation_degrees), settings.key_energy, settings.ambient_energy, settings.ssao_intensity, settings.exposure]
 print("CAPTURE | ", name, " | ", report[name])

func build_controls() -> void:
 var layer := CanvasLayer.new()
 layer.name = "ExperimentControls"
 layer.layer = 100
 layer.process_mode = Node.PROCESS_MODE_ALWAYS
 root.add_child(layer)
 var panel := PanelContainer.new()
 panel.position = Vector2(8, 8)
 layer.add_child(panel)
 var column := VBoxContainer.new()
 panel.add_child(column)
 label = Label.new()
 column.add_child(label)
 var buttons := HBoxContainer.new()
 column.add_child(buttons)
 var modes: Array = HEIGHT_MODES if height_study else [0, 1, 2, 3, 4]
 for index in modes:
  var button := Button.new()
  button.text = str(modes.find(index) + 1) + ". " + str(HEIGHT_LABELS[index] if height_study else NAMES[index])
  button.pressed.connect(apply_mode.bind(index))
  buttons.add_child(button)
 if height_study:
  var camera_button := Button.new()
  camera_button.text = "Overview / floor close-up"
  camera_button.pressed.connect(func() -> void: set_review_camera(not close_camera))
  column.add_child(camera_button)
 var tuning := VBoxContainer.new()
 var toggle := Button.new()
 toggle.text = "Show / hide tuning controls"
 toggle.pressed.connect(func() -> void: tuning.visible = not tuning.visible)
 column.add_child(toggle)
 column.add_child(tuning)
 tuning.hide()
 var sliders := SLIDERS.duplicate()
 if height_study:
  sliders.erase("roughness_variation")
  sliders.erase("floor_specular")
  sliders["convex_normal_strength"] = [0.0, 2.0]
  sliders["height_strength"] = [0.0, 0.08]
  sliders["parallax_steps"] = [4.0, 24.0]
 for property in sliders:
  var bounds: Array = sliders[property]
  var row := HBoxContainer.new()
  tuning.add_child(row)
  var caption := Label.new()
  caption.text = "old_edge_strength" if height_study and property == "normal_strength" else property
  caption.custom_minimum_size.x = 170
  row.add_child(caption)
  var slider := HSlider.new()
  slider.custom_minimum_size.x = 220
  slider.min_value = bounds[0]
  slider.max_value = bounds[1]
  slider.step = 1.0 if property == "parallax_steps" else (0.001 if property == "height_strength" else 0.01)
  slider.value = settings.get(property)
  var number := Label.new()
  number.text = "%.3f" % slider.value
  slider.value_changed.connect(func(value: float) -> void:
   settings.set(property, value)
   number.text = "%.3f" % value
   apply_mode(selected)
  )
  row.add_child(slider)
  row.add_child(number)
 var ao := CheckButton.new()
 ao.text = "Ambient occlusion"
 ao.button_pressed = settings.ssao_enabled
 ao.toggled.connect(func(value: bool) -> void:
  settings.ssao_enabled = value
  apply_mode(selected)
 )
 tuning.add_child(ao)

