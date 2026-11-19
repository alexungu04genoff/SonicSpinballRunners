extends RefCounted
## Transient overlays on single-material foreground terrain only. The original
## material, mesh, render layers and casting mode remain owned by the Act.
const ROLES := ["terrain_ground", "terrain_upper", "terrain_walls", "terrain_borders", "terrain_ledges", "ramps"]
const INCLUDE := '#include "res://experiments/retro_shadow_lab/response.gdshaderinc"'
const Audit = preload("res://scripts/diagnostics/render_audit.gd")
var mode := -1 # -1 removes every overlay; 0 submits a zero-delta control.
const LEVEL_COUNTS := [0, 2, 4, 4, 3, 8]
var native_range := true
var levels := Vector4(0.25, 0.50, 0.75, 1.0)
var binary_dark := 0.50
var anchor := 2
var matrix := 4
var cell := 0.035
var width := 0.70
var owners := {}
var programs := {} # Source text keys share identical baked programs across Acts.
var last_lighting: Array = []
var active := false
var sole_directional := true

func _shader(source: Shader) -> Shader:
 var code := source.code
 var modes := RegEx.create_from_string("render_mode\\s+([^;]+);")
 var match_modes := modes.search(code)
 var flags := match_modes.get_string(1) if match_modes else ""
 # Fail closed on features that would invalidate signed diffuse compositing.
 for token in ["ALPHA", "DEPTH", "POSITION", "BACKLIGHT", "RIM", "TRANSMITTANCE", "CLEARCOAT", "FOG =", "hint_screen_texture", "void light", "unshaded", "shadows_disabled", "vertex_lighting", "diffuse_lambert", "diffuse_toon", "blend_add", "blend_sub", "blend_mul", "depth_test_disabled", "world_vertex_coords", "skip_vertex_transform"]:
  if token in code: return null
 var cull := "cull_disabled" if "cull_disabled" in flags else ("cull_front" if "cull_front" in flags else "cull_back")
 if match_modes: code = modes.sub(code, "")
 code = code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode blend_premul_alpha, depth_draw_never, ambient_light_disabled, fog_disabled, specular_disabled, " + cull + ";\n" + INCLUDE)
 var vertex := RegEx.create_from_string("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
 var fragment := RegEx.create_from_string("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
 if not fragment.search(code): return null
 if not vertex.search(code): code += "\nvoid vertex() {}\n"
 code = vertex.sub(code, """void vertex() {
 lab_object = VERTEX;
 lab_object_axis = abs(NORMAL);""")
 code = RegEx.create_from_string("\\bEMISSION\\b").sub(code, "lab_ignored_emission", true)
 code = fragment.sub(code, """void fragment() {
 vec3 lab_ignored_emission = vec3(0.0);
 ALPHA = 0.0;
 lab_world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
 lab_world_axis = abs(mat3(INV_VIEW_MATRIX) * NORMAL);
 lab_transmission = lab_fog_transmission(length(VERTEX), lab_world.y);""")
 var program := Shader.new()
 program.code = code
 return program

func _attach(act: RefCounted) -> Dictionary:
 var state := {"slots": [], "materials": {}, "roles": {}, "excluded_alpha": 0}
 for node: Node in act.visual.find_children("*", "GeometryInstance3D", true, false):
  if node.material_overlay != null or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
  var mesh := Audit.mesh_of(node)
  if mesh == null or mesh.get_surface_count() != 1: continue
  var material: Material = node.material_override
  if material == null and node is MeshInstance3D: material = node.get_active_material(0)
  if material == null: material = mesh.surface_get_material(0)
  if not material is ShaderMaterial or material.shader == null: continue
  var role: String = material.get_meta("atmosphere_hue", "")
  if role not in ROLES or material.next_pass != null: continue
  if not state.materials.has(material):
   var code: String = material.shader.code
   if "ALPHA" in code:
    state.excluded_alpha += 1
    continue
   if not programs.has(code): programs[code] = _shader(material.shader)
   if programs[code] == null: continue
   var overlay: ShaderMaterial = material.duplicate()
   overlay.shader = programs[code]
   overlay.render_priority = Material.RENDER_PRIORITY_MIN
   state.materials[material] = overlay
  node.material_overlay = state.materials[material]
  state.slots.append({"node": weakref(node), "overlay": node.material_overlay})
  state.roles[role] = state.roles.get(role, 0) + 1
 return state

func sync(game: Node) -> void:
 if mode < 0 and owners.is_empty(): return
 var changed := false
 var live := {}
 for act: RefCounted in game.resident:
  if not act.ready: continue
  var id := act.get_instance_id()
  live[id] = true
  if mode >= 0 and not owners.has(id):
   owners[id] = _attach(act)
   changed = true
 for id: int in owners.keys():
  if not live.has(id): _retire(id)
 if active != (mode >= 0):
  active = mode >= 0
  for owner: Dictionary in owners.values(): _show(owner, active)
 if not active: return
 var light: DirectionalLight3D = game.presentation._key_light
 if changed:
  # light() has a type flag and direction, but no instance ID. Fail closed if
  # another directional shares the foreground scenario, even with the same aim.
  sole_directional = true
  for other: DirectionalLight3D in game.view.find_children("*", "DirectionalLight3D", true, false):
   if other != light and other.get_world_3d() == light.get_world_3d() and other.is_visible_in_tree():
    sole_directional = false
    break
 var env: Environment = game.presentation._world_environment.environment
 var fog := Vector4.ZERO
 var height_fog := Vector2.ZERO
 if env.fog_enabled:
  fog = Vector4(env.fog_density, env.fog_depth_begin, env.fog_depth_end, env.fog_depth_curve if env.fog_mode == Environment.FOG_MODE_DEPTH else 0.0)
  if fog.z <= fog.y: fog.z = game.presentation.camera.far
  height_fog = Vector2(env.fog_height, env.fog_height_density)
 var lighting := [light.global_basis.z.normalized(), 1.0 - cos(deg_to_rad(light.light_angular_distance)), fog, height_fog, sole_directional and light.shadow_enabled and not env.volumetric_fog_enabled, light.shadow_opacity]
 if changed or lighting != last_lighting:
  last_lighting = lighting
  update()

func update() -> void:
 if last_lighting.is_empty(): return
 for owner: Dictionary in owners.values():
  for overlay: ShaderMaterial in owner.materials.values():
   overlay.set_shader_parameter("lab_count", LEVEL_COUNTS[maxi(0, mode)] if last_lighting[4] else 0)
   overlay.set_shader_parameter("lab_dither", mode == 3)
   overlay.set_shader_parameter("lab_native_range", native_range)
   overlay.set_shader_parameter("lab_shadow_opacity", last_lighting[5])
   overlay.set_shader_parameter("lab_levels", levels)
   overlay.set_shader_parameter("lab_binary_dark", binary_dark)
   overlay.set_shader_parameter("lab_anchor", anchor)
   overlay.set_shader_parameter("lab_matrix", matrix)
   overlay.set_shader_parameter("lab_cell", cell)
   overlay.set_shader_parameter("lab_screen_cell", maxf(1.0, cell / 0.035))
   overlay.set_shader_parameter("lab_width", width)
   overlay.set_shader_parameter("lab_key_direction", last_lighting[0])
   overlay.set_shader_parameter("lab_sun_size", last_lighting[1])
   overlay.set_shader_parameter("lab_fog", last_lighting[2])
   overlay.set_shader_parameter("lab_height_fog", last_lighting[3])

func _retire(id: int) -> void:
 _show(owners[id], false)
 owners.erase(id)

func _show(owner: Dictionary, enabled: bool) -> void:
 for slot: Dictionary in owner.slots:
  var node: GeometryInstance3D = slot.node.get_ref()
  if not node: continue
  if enabled and node.material_overlay == null: node.material_overlay = slot.overlay
  elif not enabled and node.material_overlay == slot.overlay: node.material_overlay = null

func clear() -> void:
 for id: int in owners.keys(): _retire(id)
 programs.clear()
 active = false
 last_lighting.clear()

func stats() -> Dictionary:
 var counts := {"acts": owners.size(), "receivers": 0, "materials": 0, "programs": 0, "excluded_alpha": 0, "roles": {}}
 for owner: Dictionary in owners.values():
  counts.receivers += owner.slots.size() if active else 0
  counts.materials += owner.materials.size()
  counts.excluded_alpha += owner.excluded_alpha
  for role: String in owner.roles: counts.roles[role] = counts.roles.get(role, 0) + owner.roles[role]
 counts.programs = programs.values().filter(func(p): return p != null).size()
 return counts
