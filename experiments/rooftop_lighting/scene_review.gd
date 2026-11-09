extends "res://experiments/rooftop_lighting/review.gd"
## Whole-level presentation experiment. Production materials and meshes are immutable.
const SCENE_NAMES := ["None", "Beveled", "Faceted", "Hybrid"]
const MAPS := "res://experiments/rooftop_lighting/scene_maps/"
const DEFAULT_STRENGTHS := {"floor": 1.0, "ramp": 0.65, "wall": 0.65, "facade": 0.55, "top": 0.85, "border": 0.25, "guard": 0.22, "stone": 0.65, "trim": 0.30, "support": 0.25}
var strengths := DEFAULT_STRENGTHS.duplicate()
var scene_entries: Array[Dictionary] = []
var scene_inventory: Array[Dictionary] = []
var material_cache := {}
var scene_mode := 3
var scene_view := "gameplay"
var strength_widgets := {}
var normal_multiplier := 1.0
var height_depth := 0.04
var parallax_steps := 12

func run() -> void:
 output_path = OUTPUT + "scene-study/"
 DirAccess.make_dir_recursive_absolute(output_path)
 await super.run()
 set_scene_view("close")
 apply_mode(3)
 var act := "res://experiments/rooftop_lighting/existing_act.tres"
 var source := FileAccess.get_file_as_bytes(act)
 var document: String = game.authored_document.fingerprint()
 var ball_id: int = game.ball.get_instance_id()
 var coverage := {}
 for entry in scene_entries: coverage[entry.role] = int(coverage.get(entry.role, 0)) + 1
 for required in ["floor", "ramp", "wall", "facade", "top", "border", "guard", "stone"]:
  if int(coverage.get(required, 0)) == 0:
   push_error("Missing required relief coverage: " + required)
   failures += 1
 FileAccess.open(output_path + "inventory.json", FileAccess.WRITE).store_string(JSON.stringify({"coverage": coverage, "strengths": strengths, "slots": scene_inventory}, "  "))
 print("COVERAGE | ", coverage)
 if "--capture-scene" in OS.get_cmdline_user_args():
  for view_name in ["gameplay", "close", "overview"]:
   set_scene_view(view_name)
   for mode in 4:
    apply_mode(mode)
    await frames(12)
    await capture(view_name + "-" + SCENE_NAMES[mode].to_lower())
  set_scene_view("close")
  for role in strengths: strengths[role] = 0.0
  apply_mode(3)
  await frames(10)
  await capture("zero-strength")
  strengths["guard"] = DEFAULT_STRENGTHS.guard
  apply_mode(3)
  await frames(10)
  await capture("guards-only")
  if source != FileAccess.get_file_as_bytes(act) or document != game.authored_document.fingerprint() or ball_id != game.ball.get_instance_id(): failures += 1
  report["failures"] = failures
  report["coverage"] = coverage
  report["strengths"] = DEFAULT_STRENGTHS
  report["renderer"] = RenderingServer.get_current_rendering_method()
  report["document"] = document
  FileAccess.open(output_path + "validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
  print("RESULT | Whole Rooftop Run | ", failures, " failures")
  quit(1 if failures else 0)
 elif "--scene-controls-smoke" in OS.get_cmdline_user_args():
  walk(root.get_node("SceneControls"), func(node: Node) -> void:
   if node is Button: node.pressed.emit()
   if node is HSlider:
    var previous: float = node.value
    node.value = previous + 0.05
    node.value = previous
  )
  for role in DEFAULT_STRENGTHS:
   if not is_equal_approx(float(strengths[role]), float(DEFAULT_STRENGTHS[role])):
    push_error("Strength reset failed: " + role)
    failures += 1
  for mode in 4:
   var key := InputEventKey.new()
   key.keycode = KEY_1 + mode
   key.pressed = true
   Input.parse_input_event(key)
   await frames(2)
   if scene_mode != mode:
    push_error("Mode shortcut failed: " + str(mode + 1))
    failures += 1
   key.pressed = false
   Input.parse_input_event(key)
  apply_mode(3)
  set_scene_view("close")
  await frames(10)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output_path + "controls.png")
  var valid := geometry_fingerprint() == baseline_geometry and failures == 0
  print("RESULT | Scene controls | ", "PASS" if valid else "FAIL")
  quit(0 if valid else 1)

func set_scene_view(view_name: String) -> void:
 scene_view = view_name
 var camera: Camera3D = game.presentation.camera
 if view_name == "gameplay":
  camera.transform = gameplay_camera_state.transform
  camera.projection = gameplay_camera_state.projection
  camera.fov = gameplay_camera_state.fov
  camera.size = gameplay_camera_state.size
 else:
  camera.projection = Camera3D.PROJECTION_PERSPECTIVE
  camera.fov = 44
  set_review_camera(view_name == "close")
 baseline_camera = camera.transform

func classify(slot: Dictionary) -> Dictionary:
 var original: Material = slot.material
 var node: GeometryInstance3D = slot.node
 var path := str(node.get_path())
 var rail_role := str(node.get_meta("rail_surface", ""))
 if original is ShaderMaterial:
  for parameter in ["surface_texture", "wall_texture", "border_texture"]:
   var texture = original.get_shader_parameter(parameter)
   if not texture is Texture2D: continue
   var source: String = texture.resource_path.get_file().get_basename()
   if source in ["floor", "ramp", "top", "wall", "facade"]:
    return {"role": source, "map": source, "mapping": parameter, "source": texture.resource_path}
   if source in ["floor-border", "top-border"]:
    return {"role": "border", "map": "border", "mapping": parameter, "source": texture.resource_path}
  return {"skip": "Water, effects, or non-structural shader"}
 if not original is StandardMaterial3D: return {"skip": "No recognized structural material"}
 if rail_role in ["Fascia", "InnerEdge"]:
  return {"role": "guard", "map": "guard", "mapping": "route_strip", "source": "Solid cut-stone railguard; profile follows existing strip boundaries"}
 if rail_role == "Underside": return {"skip": "Hidden smooth ramp soffit; no surface artwork"}
 if "ElevatedRail_" in path and not "EntryArrow" in path:
  return {"role": "support", "map": "block", "mapping": "box", "source": "Solid stone support; existing box face boundary"}
 var palette: Dictionary = game.presentation.theme_definition._library.materials
 var key := ""
 for color in palette:
  if palette[color] == original: key = color; break
 var mesh: Mesh = node.multimesh.mesh if node is MultiMeshInstance3D else (node.mesh if node is MeshInstance3D else null)
 if mesh is BoxMesh and key == "stone":
  return {"role": "stone", "map": "block", "mapping": "box", "source": "Solid architectural stone; one profile per existing box face"}
 if mesh is BoxMesh and key == "cream" and not ("CafeAwning" in path or "FestivalPennant" in path):
  return {"role": "trim", "map": "block", "mapping": "box", "source": "Solid coping/eaves/frame; one profile per existing box face"}
 return {"skip": "Preserved: painted/plaster, cloth, graphics, vegetation, smooth metal, or wood without source grain", "palette": key}

func replacement_for(entry: Dictionary, style: String) -> Material:
 var original: Material = entry.slot.material
 var key: String = str(original.get_instance_id()) + "/" + entry.role + "/" + style
 if material_cache.has(key): return material_cache[key]
 var normal: Texture2D = load(MAPS + entry.map + "_" + style + "_normal.png")
 var result: Material
 if entry.mapping == "box":
  result = original.duplicate()
  result.normal_enabled = true
  result.normal_texture = normal
 elif entry.mapping == "route_strip":
  result = ShaderMaterial.new()
  result.shader = preload("res://experiments/rooftop_lighting/scene_guard.gdshader")
  result.set_shader_parameter("base_color", original.albedo_color)
  result.set_shader_parameter("base_roughness", original.roughness)
  result.set_shader_parameter("base_specular", original.metallic_specular)
  result.set_shader_parameter("relief_normal", normal)
 else:
  result = original.duplicate()
  var code: String = original.shader.code
  code = code.replace("void fragment() {", "#include \"res://experiments/rooftop_lighting/scene_normal.gdshaderinc\"\nvoid fragment() {")
  var assignment := ""
  match entry.mapping:
   "surface_texture":
    assignment = "vec2 relief_uv = coordinates / repeat_size; NORMAL = relief(VERTEX, NORMAL, relief_uv, relief_uv);"
   "border_texture":
    assignment = "NORMAL = relief(VERTEX, NORMAL, UV, vec2(fract(UV.x), clamp(UV.y, 0.0, 1.0)));"
   "wall_texture":
    assignment = "vec2 a = vec2(world_position.z, depth) / vec2(3.4, 1.45); vec2 b = vec2(world_position.x, depth) / vec2(3.4, 1.45); vec3 na = relief(VERTEX, NORMAL, a, vec2(fract(a.x), clamp(a.y, 0.0, 1.0))); vec3 nb = relief(VERTEX, NORMAL, b, vec2(fract(b.x), clamp(b.y, 0.0, 1.0))); NORMAL = normalize(na * weights.x + nb * weights.y + NORMAL * max(0.0, 1.0 - weights.x - weights.y));"
  var closing := code.rfind("}")
  code = code.insert(closing, assignment + "\n")
  var shader := Shader.new()
  shader.code = code
  result.shader = shader
  result.set_shader_parameter("relief_normal", normal)
 material_cache[key] = result
 return result

func apply_mode(mode: int) -> void:
 super.apply_mode(1)
 scene_mode = mode
 selected = mode
 if mode != 0:
  for entry in scene_entries:
   # Rounded/worn path cobbles are the only rough-stone source in this scene.
   # Coping, terracotta, bricks and architectural blocks remain cut masonry.
   var style := "faceted" if mode == 2 or (mode >= 3 and entry.role == "floor") else "beveled"
   var material: Material
   if mode >= 4:
    var key: String = str(entry.slot.material.get_instance_id()) + "/cross/" + entry.role + "/" + str(mode)
    if not material_cache.has(key):
     material_cache[key] = preload("res://experiments/rooftop_lighting/crossed_material.gd").create(entry.slot.material, "faceted" if mode == 4 else "beveled", "beveled" if mode == 4 else "faceted", entry.map, entry.mapping)
    material = material_cache[key]
    material.set_shader_parameter("height_strength", height_depth * (0.25 if entry.role in ["guard", "border", "trim", "support"] else 1.0))
    material.set_shader_parameter("parallax_steps", parallax_steps)
   else:
    material = replacement_for(entry, style)
   if material is StandardMaterial3D: material.normal_scale = float(strengths[entry.role]) * normal_multiplier
   else: material.set_shader_parameter("relief_strength", float(strengths[entry.role]) * normal_multiplier)
   var slot: Dictionary = entry.slot
   if slot.surface == -1: slot.node.material_override = material
   else: slot.node.set_surface_override_material(slot.surface, material)
 if is_instance_valid(label): label.text = SCENE_NAMES[mode] + " | Approved lighting | Same scene and geometry"

func capture(name: String) -> void:
 await super.capture(name)
 report[name]["mode"] = SCENE_NAMES[scene_mode]
 report[name]["projection"] = game.presentation.camera.projection
 report[name]["lighting"] = [str(game.presentation._key_light.rotation_degrees), settings.key_energy, settings.ambient_energy, settings.ssao_intensity, settings.exposure]
 report[name]["normal_strengths"] = strengths.duplicate()

func build_controls() -> void:
 for slot in slots:
  var result := classify(slot)
  scene_inventory.append({"node": str(slot.node.get_path()), "visible": slot.node.is_visible_in_tree(), "surface": slot.surface, "rail_surface": slot.node.get_meta("rail_surface", ""), "material": slot.material.resource_path, "treatment": result.duplicate()})
  if result.has("role"):
   result["slot"] = slot
   scene_entries.append(result)
 var layer := CanvasLayer.new()
 layer.name = "SceneControls"
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
 var modes := GridContainer.new()
 modes.columns = 3
 column.add_child(modes)
 for mode in SCENE_NAMES.size():
  var button := Button.new()
  button.text = str(mode + 1) + ". " + SCENE_NAMES[mode]
  var shortcut := Shortcut.new()
  var key := InputEventKey.new()
  key.keycode = KEY_1 + mode
  shortcut.events = [key]
  button.shortcut = shortcut
  button.pressed.connect(apply_mode.bind(mode))
  modes.add_child(button)
 var quick_tuning := HBoxContainer.new()
 column.add_child(quick_tuning)
 add_quick_tunable(quick_tuning, "Normal", 0.0, 2.0, 0.05, normal_multiplier, func(value: float) -> void:
  normal_multiplier = value
  apply_mode(scene_mode)
 )
 var cameras := HBoxContainer.new()
 column.add_child(cameras)
 for view_name in ["gameplay", "close", "overview"]:
  var button := Button.new()
  button.text = view_name.capitalize() + " camera"
  button.pressed.connect(set_scene_view.bind(view_name))
  cameras.add_child(button)
 var tuning := VBoxContainer.new()
 var toggle := Button.new()
 toggle.text = "Show / hide per-surface normal strengths"
 toggle.pressed.connect(func() -> void: tuning.visible = not tuning.visible)
 column.add_child(toggle)
 column.add_child(tuning)
 tuning.hide()
 for role in strengths:
  var row := HBoxContainer.new()
  tuning.add_child(row)
  var title := Label.new()
  title.text = role.capitalize()
  title.custom_minimum_size.x = 100
  row.add_child(title)
  var slider := HSlider.new()
  slider.min_value = 0.0
  slider.max_value = 1.5
  slider.step = 0.01
  slider.value = strengths[role]
  slider.custom_minimum_size.x = 210
  row.add_child(slider)
  var number := Label.new()
  number.text = "%.2f" % slider.value
  row.add_child(number)
  slider.value_changed.connect(func(value: float) -> void:
   strengths[role] = value
   number.text = "%.2f" % value
   apply_mode(scene_mode)
  )
  strength_widgets[role] = slider
 var reset := Button.new()
 reset.text = "Restore gameplay-safe strengths"
 reset.pressed.connect(func() -> void:
  for role in DEFAULT_STRENGTHS: strength_widgets[role].value = DEFAULT_STRENGTHS[role]
 )
 tuning.add_child(reset)


func add_quick_tunable(row: Container, title: String, low: float, high: float, step: float, initial: float, changed: Callable) -> void:
 var title_label := Label.new()
 title_label.text = title
 row.add_child(title_label)
 var value := SpinBox.new()
 value.min_value = low
 value.max_value = high
 value.step = step
 value.value = initial
 value.custom_minimum_size.x = 110
 value.value_changed.connect(changed)
 row.add_child(value)
