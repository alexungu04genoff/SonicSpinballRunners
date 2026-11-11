extends RefCounted
## Shared GPU spin preserves Forward+'s automatic instancing and per-Ring culling.
const SHADER_PATH := "res://scripts/ring_spin.gdshader"
var materials: Array[ShaderMaterial] = []
var fallback_indices: Array[int] = []
var gpu_rings: Array[bool] = []
var enabled := not OS.get_cmdline_user_args().has("--ring-spin=legacy")
var _legacy_materials := {}
var _last_phase := INF

static func spin_basis(phase: float) -> Basis:
 return Basis.from_euler(Vector3(PI * 0.5, phase, 0))

static func vertex_code() -> String:
 return "void vertex() {\n VERTEX = ring_rotation * VERTEX;\n NORMAL = ring_rotation * NORMAL;\n TANGENT = ring_rotation * TANGENT;\n BINORMAL = ring_rotation * BINORMAL;\n}"

static func is_material(material: Material) -> bool:
 return material is ShaderMaterial and material.shader != null and material.shader.resource_path == SHADER_PATH and material.shader.code.contains(vertex_code())

static func bound(node: GeometryInstance3D) -> bool:
 # Compute the all-angle envelope from the actual mesh, including rail Rings.
 # A tag cannot grant unknown vertex programs or MultiMeshes bounded status.
 if not node is MeshInstance3D or node.mesh == null: return false
 var radius := 0.0
 for i in 8: radius = maxf(radius, node.mesh.get_aabb().get_endpoint(i).length())
 if not is_finite(radius): return false
 var box := AABB(-Vector3.ONE * radius, Vector3.ONE * radius * 2.0)
 node.custom_aabb = box.merge(node.custom_aabb) if node.custom_aabb != AABB() else box
 return true

static func _material(source: Material, neutral: StandardMaterial3D) -> ShaderMaterial:
 if not source is StandardMaterial3D or source.get_script() != null or not source.get_meta_list().is_empty(): return null
 if source.albedo_color.a != 1.0: return null
 # Reproduce only opaque, texture-free Standard surfaces. Future features keep
 # their original material and CPU rotation until explicitly supported.
 var copied := ["albedo_color", "roughness", "metallic", "metallic_specular", "emission_enabled", "emission", "emission_energy_multiplier", "render_priority"]
 for property: Dictionary in source.get_property_list():
  var key: String = property.name
  if int(property.usage) & PROPERTY_USAGE_STORAGE == 0 or key in copied or key.begins_with("resource_"): continue
  if source.get(key) != neutral.get(key): return null
 var result := ShaderMaterial.new()
 # Load during construction so scene teardown can release the shader; keep GPU
 # resources out of long-lived Script constants. ResourceCache still shares it.
 result.shader = load(SHADER_PATH)
 if result.shader == null or not result.shader.code.contains(vertex_code()): return null
 result.render_priority = source.render_priority
 result.set_shader_parameter("ring_rotation", spin_basis(0))
 result.set_shader_parameter("paint", source.albedo_color)
 result.set_shader_parameter("surface_roughness", source.roughness)
 result.set_shader_parameter("surface_metallic", source.metallic)
 result.set_shader_parameter("surface_specular", source.metallic_specular)
 result.set_shader_parameter("emission_color", source.emission)
 # Preserve the atmosphere editor's existing global emission control.
 result.set_shader_parameter("emission_scale", source.emission_energy_multiplier if source.emission_enabled else 0.0)
 return result

static func prepare(visuals: Array[MeshInstance3D]) -> int:
 var converted := {}
 var neutral := StandardMaterial3D.new()
 var count := 0
 for node: MeshInstance3D in visuals:
  if node.mesh == null or node.mesh.get_surface_count() != 1 or node.get_child_count() > 0: continue
  if not node.basis.is_equal_approx(Basis.IDENTITY) or node.get_script() != null or not node.get_meta_list().is_empty(): continue
  if node.material_overlay != null or node.transparency != 0.0 or node.custom_aabb != AABB(): continue
  var source := node.get_active_material(0)
  if not converted.has(source): converted[source] = _material(source, neutral)
  if converted[source] == null: continue
  node.set_meta("ring_standard_material", source) # Same-bake diagnostic A/B.
  node.material_override = converted[source]
  bound(node)
  count += 1
 return count

func clear() -> void:
 materials.clear()
 fallback_indices.clear()
 gpu_rings.clear()
 _legacy_materials.clear()
 _last_phase = INF

func append(visual: MeshInstance3D) -> void:
 var material := visual.material_override
 var gpu := enabled and is_material(material)
 if not enabled and is_material(material):
  var original: StandardMaterial3D = visual.get_meta("ring_standard_material")
  if not _legacy_materials.has(material):
   var copy: StandardMaterial3D = original.duplicate()
   copy.emission_energy_multiplier = float(material.get_shader_parameter("emission_scale"))
   _legacy_materials[material] = copy
  visual.material_override = _legacy_materials[material]
 if gpu:
  visual.basis = Basis.IDENTITY
  if not material in materials: materials.append(material)
 else:
  fallback_indices.append(gpu_rings.size())
 gpu_rings.append(gpu)

func is_gpu(index: int) -> bool:
 return index >= 0 and index < gpu_rings.size() and gpu_rings[index]

func spin(phase: float) -> void:
 if phase == _last_phase: return
 _last_phase = phase
 var basis := spin_basis(phase)
 for material: ShaderMaterial in materials: material.set_shader_parameter("ring_rotation", basis)
