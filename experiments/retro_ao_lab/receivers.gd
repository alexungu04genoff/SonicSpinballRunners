extends RefCounted
## Only semantic, opaque, single-surface terrain is substituted. Each slot
## remembers its exact original override, including a null surface fallback.
const ShadowReceivers = preload("../retro_shadow_lab/receivers.gd")
const Audit = preload("res://scripts/diagnostics/render_audit.gd")
const INCLUDE := '#include "res://experiments/retro_ao_lab/contact.gdshaderinc"'
const RESPONSE := """
 vec3 contact_world_n = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
 float contact_amount;
 if (face_study) {
  contact_amount = face_cavity(normalize(contact_face_normal), contact_local.y);
 } else {
  float contact_signal = contact_field(SCREEN_UV, VERTEX, normalize(NORMAL), PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
  contact_signal = 1.0 - pow(1.0 - clamp(contact_signal * contact_gain, 0.0, 1.0), contact_contrast);
  float contact_phase = contact_threshold(FRAGCOORD.xy, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz,
   contact_world_n, contact_local, transpose(mat3(MODEL_MATRIX)) * contact_world_n);
  contact_amount = contact_band(contact_signal, contact_phase, contact_levels);
 }
 AO = min(AO, 1.0 - contact_strength * contact_amount);
"""
var owners := {}
var programs := {}
var active := false
var settings := {}

func specialize(source: Shader) -> Shader:
 var code := source.code
 # Existing cavity maps in Rooftop and Chemical explicitly keep direct AO at
 # zero. Preserve the authored AO and accept that exact native assignment.
 if not ShadowReceivers.Terrain.supports_face_shader(code): return null
 var fragment := RegEx.create_from_string("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{").search(code)
 if not fragment: return null
 var start := fragment.get_end()
 var braces := 1
 var end := start
 while end < code.length() and braces:
  if code[end] == "{": braces += 1
  elif code[end] == "}": braces -= 1
  end += 1
 if braces or "return;" in code.substr(start, end - start): return null
 code = code.insert(end - 1, RESPONSE)
 var vertex := RegEx.create_from_string("void\\s+vertex\\s*\\(\\s*\\)\\s*\\{")
 if not vertex.search(code): code += "\nvoid vertex() {}\n"
 code = vertex.sub(code, "void vertex() {\n contact_local = VERTEX;\n contact_face_normal = MODEL_NORMAL_MATRIX * NORMAL;")
 var first_fn := RegEx.create_from_string("\\bvoid\\s+(vertex|fragment)\\s*\\(").search(code)
 code = code.insert(first_fn.get_start(), "\n" + INCLUDE + "\n")
 var shader := Shader.new()
 shader.code = code
 return shader

func collect(root: Node3D, scenery: Node3D = null) -> Dictionary:
 var state := {"slots": [], "materials": {}}
 for node: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
  if scenery and scenery.is_ancestor_of(node): continue
  if node.transparency > 0.0 or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
  var mesh := Audit.mesh_of(node)
  if not mesh or mesh.get_surface_count() != 1: continue
  var source: Material = node.material_override
  if source == null and node is MeshInstance3D: source = node.get_active_material(0)
  if source == null: source = mesh.surface_get_material(0)
  if not source is ShaderMaterial or not source.shader or source.next_pass: continue
  if source.get_meta("atmosphere_hue", "") not in ShadowReceivers.ROLES: continue
  var code: String = source.shader.code
  if not programs.has(code): programs[code] = specialize(source.shader)
  if programs[code] == null: continue
  var bounds := mesh.get_aabb()
  var key := [source.get_instance_id(), bounds.position.y, bounds.size.y]
  if not state.materials.has(key):
   var mat: ShaderMaterial = source.duplicate()
   mat.shader = programs[code]
   mat.set_meta("contact_source_material", source)
   mat.set_shader_parameter("contact_heights", Vector2(bounds.position.y, bounds.size.y))
   for param: String in settings: mat.set_shader_parameter(param, settings[param])
   state.materials[key] = mat
  state.slots.append([weakref(node), node.material_override, state.materials[key]])
 return state

func show_slots(state: Dictionary, enabled: bool) -> void:
 for slot: Array in state.slots:
  var node: GeometryInstance3D = slot[0].get_ref()
  if not node: continue
  if enabled and node.material_override == slot[1]: node.material_override = slot[2]
  elif not enabled and node.material_override == slot[2]: node.material_override = slot[1]

func sync(game: Node, enabled: bool) -> void:
 if not enabled and owners.is_empty(): return
 var live := {}
 if "resident" in game:
  for act: RefCounted in game.resident:
   if not act.ready: continue
   var id := act.get_instance_id()
   live[id] = true
   if enabled and not owners.has(id):
    owners[id] = collect(act.visual)
    show_slots(owners[id], true)
 elif game.presentation.terrain_root:
  var id: int = game.presentation.terrain_root.get_instance_id()
  live[id] = true
  if enabled and not owners.has(id):
   owners[id] = collect(game.presentation, game.presentation.scenery_root)
   show_slots(owners[id], true)
 for id: int in owners.keys():
  if not live.has(id):
   show_slots(owners[id], false)
   owners.erase(id)
 if enabled != active:
  for state: Dictionary in owners.values(): show_slots(state, enabled)
 active = enabled

func refresh_source_parameters() -> void:
 for owner: Dictionary in owners.values():
  for material: ShaderMaterial in owner.materials.values():
   var source: ShaderMaterial = material.get_meta("contact_source_material")
   for uniform: Dictionary in source.shader.get_shader_uniform_list():
    material.set_shader_parameter(uniform.name, source.get_shader_parameter(uniform.name))

func apply(values: Dictionary) -> void:
 settings = values
 for owner: Dictionary in owners.values():
  for mat: ShaderMaterial in owner.materials.values():
   for param: String in settings: mat.set_shader_parameter(param, settings[param])

func clear() -> void:
 for owner: Dictionary in owners.values(): show_slots(owner, false)
 active = false
 owners.clear()
 programs.clear()
 settings.clear()

func inventory() -> Dictionary:
 var result := {"acts": owners.size(), "receivers": 0, "materials": 0, "programs": 0}
 for owner: Dictionary in owners.values():
  if active: result.receivers += owner.slots.size()
  result.materials += owner.materials.size()
 result.programs = programs.values().filter(func(p): return p != null).size()
 return result
