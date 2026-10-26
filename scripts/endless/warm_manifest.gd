extends RefCounted
## Offline-only material inspection. The saved manifest is consumed without
## reflecting material properties or depending on process-local resource IDs.
const VERSION := 1
var _material_keys := {}
var _texture_keys := {}
var _shader_keys := {}
var error := ""

func prepare(recipe: Resource) -> void:
 # Run after asset sharing and static batching: those operations can replace
 # materials, meshes and the ordinary/instanced rendering path.
 for record: Dictionary in recipe.records:
  var node: Node = record.scene.instantiate()
  record.warm_visible = true
  record.warm_cull_margin = 0.0
  record.warm_signatures = PackedStringArray()
  if node is Node3D: record.warm_visible = node.visible
  if node is GeometryInstance3D:
   record.warm_cull_margin = node.extra_cull_margin
   record.warm_signatures = signatures(node, record.get("instance_mesh"))
  node.free()
 recipe.warm_manifest_version = VERSION
 if not error.is_empty(): recipe.error = error

func signatures(node: GeometryInstance3D, instance_mesh: Mesh = null) -> PackedStringArray:
 var meshes: Array[Mesh] = []
 if node is MeshInstance3D:
  if node.mesh != null: meshes.append(node.mesh)
 elif node is MultiMeshInstance3D:
  if instance_mesh != null: meshes.append(instance_mesh)
  elif node.multimesh != null and node.multimesh.mesh != null: meshes.append(node.multimesh.mesh)
 elif node is GPUParticles3D:
  for index in node.draw_passes:
   var mesh: Mesh = node.get_draw_pass_mesh(index)
   if mesh != null: meshes.append(mesh)
 elif node is CPUParticles3D:
  if node.mesh != null: meshes.append(node.mesh)
 var state: Array = [node.get_class(), node.cast_shadow, node.gi_mode, node.transparency > 0.0]
 if node is MultiMeshInstance3D and node.multimesh != null:
  state.append([node.multimesh.use_colors, node.multimesh.use_custom_data])
 elif node is MultiMeshInstance3D:
  state.append([false, false])
 var result := PackedStringArray()
 for mesh: Mesh in meshes:
  for surface in mesh.get_surface_count():
   var material := node.material_override
   if material == null:
    material = node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface)
   # Vertex attributes can enable another renderer permutation. Primitive type
   # also affects the graphics path, but vertex positions and counts do not.
   var geometry := _geometry_features(mesh, surface)
   var signature := _digest([state, geometry, _material_key(material, false)])
   if not signature in result: result.append(signature)
   if node.material_overlay != null:
    signature = _digest([state, geometry, _material_key(node.material_overlay, false)])
    if not signature in result: result.append(signature)
 # Empty draw nodes still retain a deterministic feature description. This
 # keeps tiny fixture/probe nodes useful before their mesh is attached.
 if meshes.is_empty(): result.append(_digest([state, _material_key(node.material_override, false)]))
 return result

func _geometry_features(mesh: Mesh, surface: int) -> Array:
 if mesh is ArrayMesh:
  return [mesh.surface_get_format(surface), mesh.surface_get_primitive_type(surface)]
 # Production bakes canonicalize PrimitiveMesh resources first. The explicit
 # authoring fallback can still inspect them without assuming ArrayMesh APIs.
 var format := 0
 var arrays := mesh.surface_get_arrays(surface)
 for index in arrays.size():
  if arrays[index] != null and arrays[index].size() > 0: format |= 1 << index
 return [format, Mesh.PRIMITIVE_TRIANGLES]

func material_probe_key(material: Material) -> String:
 return _material_key(material, true)

func build_probes(materials: Array[Material]) -> Resource:
 var recipe: Resource = load("res://scripts/endless/visual_recipe.gd").new()
 var primitive := BoxMesh.new()
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, primitive.get_mesh_arrays())
 var seen := {}
 for material: Material in materials:
  var key := material_probe_key(material)
  if seen.has(key): continue
  seen[key] = true
  var ordinary := MeshInstance3D.new()
  ordinary.mesh = mesh
  ordinary.material_override = material
  recipe.capture(ordinary)
  ordinary.free()
  var instanced := MultiMeshInstance3D.new()
  instanced.material_override = material
  recipe.capture(instanced)
  var record: Dictionary = recipe.records[-1]
  record.instance_mesh = mesh
  record.instance_buffer = PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0])
  record.instance_bounds = mesh.get_aabb()
  instanced.free()
 prepare(recipe)
 return recipe

func _material_key(material: Material, textures: bool, active: Dictionary = {}) -> String:
 if material == null: return "default"
 var id := material.get_instance_id()
 var cache_key := str(id) + (":bindings" if textures else ":features")
 if _material_keys.has(cache_key): return _material_keys[cache_key]
 if active.has(id): return "material-cycle"
 active[id] = true
 var features: Array = [material.get_class()]
 for property: Dictionary in material.get_property_list():
  if int(property.usage) & PROPERTY_USAGE_STORAGE == 0: continue
  var name: String = property.name
  if name in ["resource_local_to_scene", "resource_name", "script"]: continue
  var value: Variant = material.get(name)
  if value is Shader: features.append([name, _shader_key(value)])
  elif value is Texture: features.append([name, _texture_key(value) if textures else value.get_class()])
  elif value is Material: features.append([name, _material_key(value, textures, active)])
  elif value is bool or value is int: features.append([name, value])
 active.erase(id)
 var result := _digest(features)
 _material_keys[cache_key] = result
 return result

func _shader_key(shader: Shader) -> String:
 var id := shader.get_instance_id()
 if _shader_keys.has(id): return _shader_keys[id]
 # Shader source survives save/reload with a different instance ID. Include
 # content participates too, even when the shader's top-level text is unchanged.
 var includes := RegEx.create_from_string('#include\\s+"([^\"]+)"')
 var pending: Array = [[shader.code, shader.resource_path.get_base_dir()]]
 var visited := {}
 var sources: Array = [shader.code]
 while not pending.is_empty():
  var item: Array = pending.pop_back()
  for match: RegExMatch in includes.search_all(item[0]):
   var path: String = match.get_string(1)
   if not path.begins_with("res://"): path = str(item[1]).path_join(path).simplify_path()
   if visited.has(path): continue
   visited[path] = true
   if FileAccess.file_exists(path):
    var source := FileAccess.get_file_as_string(path).replace("\r", "")
    sources.append([path, source])
    pending.append([source, path.get_base_dir()])
 var result := _digest(sources)
 _shader_keys[id] = result
 return result

func _texture_key(texture: Texture) -> String:
 var id := texture.get_instance_id()
 if _texture_keys.has(id): return _texture_keys[id]
 var identity: Array = [texture.get_class()]
 if not texture.resource_path.is_empty() and not texture.resource_path.contains("::"):
  identity.append(texture.resource_path)
 elif texture is Texture2D:
  var pixels: Image = texture.get_image()
  if pixels != null:
   identity.append([pixels.get_width(), pixels.get_height(), pixels.get_format(), pixels.has_mipmaps(), pixels.get_data()])
  else:
   identity.append([texture.get_width(), texture.get_height()])
 else:
  # Baked production textures use external shared asset paths. A pathless
  # non-2D texture needs an explicit adapter before it can be safely deduplicated.
  error = "Warm-up manifest requires an external path for " + texture.get_class()
  identity.append("unsupported-pathless-texture")
 var result := _digest(identity)
 _texture_keys[id] = result
 return result

static func _digest(value: Variant) -> String:
 var digest := HashingContext.new()
 digest.start(HashingContext.HASH_SHA256)
 digest.update(var_to_bytes(value))
 return digest.finish().hex_encode()
