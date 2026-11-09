extends CanvasLayer
## Session-only Rooftop Run material comparison in the actual playable game.
## Material swaps never rebuild geometry, reset the ball, or alter the camera.
const MODES := ["Flat materials", "Approved Hybrid"]
const MAPS := "res://experiments/rooftop_lighting/scene_maps/"
const STRENGTHS := {"floor": 1.0, "ramp": 0.65, "wall": 0.65, "facade": 0.55, "top": 0.85, "border": 0.25, "guard": 0.22, "stone": 0.65, "trim": 0.30, "support": 0.25}
var game: Node
var mode := 1
var entries: Array[Dictionary] = []
var material_cache := {}
var buttons: Array[Button] = []
var retro_toggle: CheckButton
var caption: Label
var panel: PanelContainer
var settings = preload("res://experiments/rooftop_lighting/settings.tres").duplicate()
var toolbar_visible := true
var normal_strength := 1.0
var height_depth := 0.04
var parallax_steps := 12
var detail_camera := false
var saved_camera := {}
var original_light := {}
var original_world := {}


func install(owner_game: Node) -> void:
 game = owner_game
 layer = 35
 process_priority = 100
 process_mode = Node.PROCESS_MODE_ALWAYS
 var layout := Control.new()
 layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(layout)
 layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel = PanelContainer.new()
 layout.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 panel.offset_left = 16
 panel.offset_top = -170
 panel.offset_right = 950
 panel.offset_bottom = -14
 var background := StyleBoxFlat.new()
 background.bg_color = Color(0.025, 0.10, 0.13, 0.92)
 background.content_margin_left = 12
 background.content_margin_right = 12
 background.content_margin_top = 8
 background.content_margin_bottom = 8
 panel.add_theme_stylebox_override("panel", background)
 var column := VBoxContainer.new()
 panel.add_child(column)
 var header := HBoxContainer.new()
 column.add_child(header)
 caption = Label.new()
 caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(caption)
 var close_button := Button.new()
 close_button.text = "Close ×"
 close_button.tooltip_text = "Hide material controls. Press F8 to reopen."
 close_button.focus_mode = Control.FOCUS_NONE
 close_button.pressed.connect(func() -> void:
  toolbar_visible = false
  panel.hide()
 )
 header.add_child(close_button)
 var row := GridContainer.new()
 row.columns = 4
 column.add_child(row)
 var group := ButtonGroup.new()
 for index in MODES.size():
  var button := Button.new()
  button.text = "%d  %s" % [index + 1, MODES[index]]
  button.focus_mode = Control.FOCUS_NONE
  button.toggle_mode = true
  button.button_group = group
  button.pressed.connect(set_mode.bind(index))
  row.add_child(button)
  buttons.append(button)
 retro_toggle = CheckButton.new()
 retro_toggle.text = "F4  Retro stack"
 retro_toggle.focus_mode = Control.FOCUS_NONE
 retro_toggle.toggled.connect(func(enabled: bool) -> void:
  game.retro_filter.set_effects(game.retro_filter.settings.default_effects if enabled else [])
 )
 row.add_child(retro_toggle)
 var camera_button := Button.new()
 camera_button.text = "F7 Close-up / gameplay"
 camera_button.focus_mode = Control.FOCUS_NONE
 camera_button.pressed.connect(toggle_detail_camera)
 row.add_child(camera_button)
 var tuning := HBoxContainer.new()
 column.add_child(tuning)
 add_tunable(tuning, "Normal", 0.0, 2.0, 0.05, normal_strength, func(value: float) -> void:
  normal_strength = value
  set_mode(mode)
 )
 add_tunable(tuning, "Grass height", 0.0, 0.15, 0.005, 0.075, func(value: float) -> void:
  if game.presentation.theme_definition.get("material_maps") != null:
   game.presentation.theme_definition.material_maps.set_grass_height(value)
 )
 game.retro_filter.preset_changed.connect(func(_index: int) -> void: sync_retro())
 refresh()

func refresh() -> void:
 # Called only after the game's existing level/theme rebuild has finished.
 # Discard references to old visuals; never restore them onto a new level.
 entries.clear()
 material_cache.clear()
 detail_camera = false
 saved_camera.clear()
 visible = game.theme_id == "rooftop_run"
 if not visible: return
 # The theme now owns the approved maps; never reapply obsolete experiment maps.
 if game.presentation.theme_definition.get("material_maps") != null:
  collect_slots(game.presentation)
  apply_lighting()
  set_mode(mode)
  sync_retro()
  return
 collect_slots(game.presentation)
 apply_lighting()
 set_mode(mode)
 sync_retro()

func collect_slots(node: Node) -> void:
 if node is GeometryInstance3D and node.material_override:
  add_slot({"node": node, "surface": -1, "material": node.material_override})
 elif node is MeshInstance3D and node.mesh:
  for index in node.mesh.get_surface_count():
   var material: Material = node.get_active_material(index)
   if material: add_slot({"node": node, "surface": index, "material": material})
 for child in node.get_children(): collect_slots(child)

func add_slot(slot: Dictionary) -> void:
 if slot.material.get_meta("approved_rooftop",false):
  entries.append({"role":"approved", "slot":slot})
  return
 var entry := classify(slot)
 if entry.has("role"):
  entry["slot"] = slot
  entries.append(entry)

func set_mode(index: int) -> void:
 mode = clampi(index, 0, MODES.size() - 1)
 if is_instance_valid(game) and game.presentation.theme_definition.get("material_maps") != null:
  var approved=game.presentation.theme_definition.material_maps
  approved.enabled=mode!=0
  approved.strength=normal_strength
  approved.update()
  # Route generation duplicates materials to set double-sided rendering.
  # Update those bound copies as well as the theme's source materials.
  for entry in entries:
   var bound: Material=entry.slot.material
   if bound is ShaderMaterial and bound.get_meta("approved_rooftop",false):
    bound.set_shader_parameter("relief_strength",float(bound.get_meta("normal_strength",0.0))*normal_strength if mode!=0 else 0.0)
    bound.set_shader_parameter("detail_mix",1.0 if mode!=0 else 0.0)
  for index_button in buttons.size(): buttons[index_button].set_pressed_no_signal(index_button==mode)
  caption.text="Rooftop Run: %s | F7 close-up | F8 controls | F11 fullscreen" % MODES[mode]
  return
 for entry in entries:
  var slot: Dictionary = entry.slot
  if not is_instance_valid(slot.node): continue
  var material: Material = slot.material
  if mode != 0:
   var style := "faceted" if mode == 2 or (mode >= 3 and entry.role == "floor") else "beveled"
   if mode >= 4:
    var cache_key: String = str(slot.material.get_instance_id()) + "/cross/" + entry.role + "/" + str(mode)
    if not material_cache.has(cache_key):
     material_cache[cache_key] = preload("res://experiments/rooftop_lighting/crossed_material.gd").create(slot.material, "faceted" if mode == 4 else "beveled", "beveled" if mode == 4 else "faceted", entry.map, entry.mapping)
    material = material_cache[cache_key]
    material.set_shader_parameter("height_strength", height_depth * (0.25 if entry.role in ["guard", "border", "trim", "support"] else 1.0))
    material.set_shader_parameter("parallax_steps", parallax_steps)
   else:
    material = replacement_for(entry, style)
   if material is StandardMaterial3D: material.normal_scale = float(STRENGTHS[entry.role]) * normal_strength
   else: material.set_shader_parameter("relief_strength", float(STRENGTHS[entry.role]) * normal_strength)
  if slot.surface == -1: slot.node.material_override = material
  else: slot.node.set_surface_override_material(slot.surface, material)
 for index_button in buttons.size(): buttons[index_button].set_pressed_no_signal(index_button == mode)
 caption.text = "Rooftop materials: %s  |  F8 hide/show controls  |  F11 fullscreen" % MODES[mode]

func sync_retro() -> void:
 retro_toggle.set_pressed_no_signal(not game.retro_filter.selected_effects.is_empty())

func handle_key(event: InputEventKey) -> bool:
 if game.theme_id != "rooftop_run" or game.close_view: return false
 var focus := get_viewport().gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit: return false
 var key := event.physical_keycode if event.physical_keycode != 0 else event.keycode
 if key >= KEY_1 and key <= KEY_2:
  set_mode(key - KEY_1)
 elif key == KEY_F4:
  game.retro_filter.set_effects(game.retro_filter.settings.default_effects if game.retro_filter.selected_effects.is_empty() else [])
 elif key == KEY_F7:
  toggle_detail_camera()
 elif key == KEY_F8:
  toolbar_visible = not toolbar_visible
  panel.visible = toolbar_visible
 else:
  return false
 return true

func apply_lighting() -> void:
 var light: DirectionalLight3D = game.presentation._key_light
 var world: Environment = game.presentation._world_environment.environment
 for property in ["rotation_degrees", "light_color", "light_energy", "shadow_bias", "shadow_normal_bias", "directional_shadow_max_distance"]:
  original_light[property] = light.get(property)
 for property in ["ambient_light_source", "ambient_light_energy", "ambient_light_sky_contribution", "reflected_light_source", "tonemap_mode", "tonemap_exposure", "ssao_enabled", "ssao_radius", "ssao_intensity", "ssao_power", "ssao_detail", "ssao_light_affect", "fog_enabled", "fog_density"]:
  original_world[property] = world.get(property)
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


func restore_lighting() -> void:
 if not is_instance_valid(game.presentation): return
 for property in original_light: game.presentation._key_light.set(property, original_light[property])
 for property in original_world: game.presentation._world_environment.environment.set(property, original_world[property])
 original_light.clear()
 original_world.clear()

func add_tunable(row: Container, title: String, low: float, high: float, step: float, initial: float, changed: Callable) -> void:
 var label := Label.new()
 label.text = title
 row.add_child(label)
 var value := SpinBox.new()
 value.min_value = low
 value.max_value = high
 value.step = step
 value.value = initial
 value.custom_minimum_size.x = 110
 value.value_changed.connect(changed)
 row.add_child(value)

func toggle_detail_camera() -> void:
 var camera: Camera3D = game.presentation.camera
 detail_camera = not detail_camera
 if detail_camera:
  saved_camera = {"transform": camera.transform, "projection": camera.projection, "fov": camera.fov, "size": camera.size, "follow": game.presentation.camera_follow_enabled}
  game.presentation.set_camera_follow(false)
  apply_detail_camera()
 else:
  game.presentation.set_camera_follow(saved_camera.follow)
  camera.transform = saved_camera.transform
  camera.projection = saved_camera.projection
  camera.fov = saved_camera.fov
  camera.size = saved_camera.size

func _process(_delta: float) -> void:
 # Retro resolution and fullscreen changes can reconfigure the game's camera.
 # Keep the reference angle fixed while the material close-up is selected.
 if detail_camera and is_instance_valid(game): apply_detail_camera()

func apply_detail_camera() -> void:
 game.presentation.camera_follow_enabled = false
 var camera: Camera3D = game.presentation.camera
 camera.projection = Camera3D.PROJECTION_PERSPECTIVE
 camera.fov = 44
 var target: Vector3 = game.presentation.map_point(Vector2(465, 420), 0.02)
 camera.position = target + Vector3(0.1, 1.0, 1.4)
 camera.look_at(target)
