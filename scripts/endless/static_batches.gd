extends RefCounted
## Offline-only spatial instancing. Dynamic bindings and collision data stay intact.
const CELL_SIZE := 2.0
const MAX_INSTANCES := 64
const MAX_TRIANGLES := 8192
const MIN_INSTANCES := 3
var _resource_keys := {}
var _protected_resources := {}

func optimize(recipe: Resource) -> Dictionary:
 if not recipe.batch_stats.is_empty(): return recipe.batch_stats
 var nodes: Array[Node] = []
 var transforms: Array[Transform3D] = []
 var children: Array[int] = []
 var safe: Array[bool] = []
 var protected := {}
 var native_animation := false
 for index: int in recipe.flippers + recipe.retracted + recipe.rings: protected[index] = true
 for index: int in recipe.bumpers.values(): protected[index] = true
 for animation: Dictionary in recipe.animations:
  protected[animation.index] = true
  _protect_references(animation.values, protected)
 var probe := MultiMeshInstance3D.new()
 var common := {}
 for property: Dictionary in probe.get_property_list():
  if int(property.usage) & PROPERTY_USAGE_STORAGE: common[property.name] = true
 probe.free()
 for record: Dictionary in recipe.records:
  var node: Node = record.scene.instantiate()
  native_animation = native_animation or node is AnimationMixer or node is Skeleton3D
  var parent: int = record.parent
  var transform := Transform3D.IDENTITY if parent < 0 else transforms[parent]
  var allowed: bool = parent < 0 or safe[parent]
  if node is Node3D:
   allowed = allowed and node.visible and not node.top_level
   transform *= node.transform
  if protected.has(parent): protected[nodes.size()] = true
  allowed = allowed and transform.basis.determinant() > 0.00001
  nodes.append(node)
  transforms.append(transform)
  safe.append(allowed)
  children.append(0)
  if parent >= 0: children[parent] += 1
 if native_animation:
  # Native track paths can target siblings outside the player's subtree. Keep
  # the whole hierarchy until that binding format has an explicit bake adapter.
  recipe.batch_stats = {"records_before": nodes.size(), "records_after": nodes.size(), "instances": 0, "batches": 0, "reason": "native animation"}
  for node: Node in nodes: node.free()
  return recipe.batch_stats
 var groups := {}
 var source_meshes := 0
 for index in nodes.size():
  var node: Node = nodes[index]
  if node is MeshInstance3D: source_meshes += 1
  if protected.has(index) or not safe[index] or children[index] > 0 or not _eligible(node): continue
  var mesh: Mesh = node.mesh
  var triangles: int = mesh.surface_get_array_index_len(0) / 3 if mesh.surface_get_array_index_len(0) > 0 else mesh.surface_get_array_len(0) / 3
  var limit := mini(MAX_INSTANCES, MAX_TRIANGLES / maxi(1, triangles))
  if limit < MIN_INSTANCES: continue
  var bounds: AABB = transforms[index] * mesh.get_aabb()
  if maxf(bounds.size.x, bounds.size.z) > CELL_SIZE * 2.0: continue
  var center := bounds.get_center()
  var cell := Vector2i(floori(center.x / CELL_SIZE), floori(center.z / CELL_SIZE))
  var state := _render_state(node, common)
  var background: bool = recipe.records[index].get("background", false)
  var key := str(mesh.get_instance_id()) + ":" + str(cell) + ":" + str(background) + ":" + _digest(_value_key(state))
  if not groups.has(key): groups[key] = {"indices": [], "cell": cell, "limit": limit, "state": state, "background": background}
  groups[key].indices.append(index)
 var removed := {}
 var additions: Array[Dictionary] = []
 var instances := 0
 for group: Dictionary in groups.values():
  var members: Array = group.indices
  for start in range(0, members.size(), group.limit):
   var count := mini(group.limit, members.size() - start)
   if count < MIN_INSTANCES: continue
   var mesh: Mesh = nodes[members[start]].mesh
   var buffer := PackedFloat32Array()
   var bounds := AABB()
   var anchor := Transform3D(Basis.IDENTITY, Vector3(group.cell.x * CELL_SIZE, 0, group.cell.y * CELL_SIZE))
   for offset in count:
    var index: int = members[start + offset]
    var local := anchor.affine_inverse() * transforms[index]
    buffer.append_array(_transform_buffer(local))
    var instance_bounds: AABB = local * mesh.get_aabb()
    bounds = instance_bounds if offset == 0 else bounds.merge(instance_bounds)
    removed[index] = true
   var batch := MultiMeshInstance3D.new()
   batch.name = "StaticBatch_%d" % additions.size()
   batch.transform = anchor
   for property: String in group.state: batch.set(property, group.state[property])
   var scene := PackedScene.new()
   scene.pack(batch)
   batch.free()
   # The dummy renderer does not retain MultiMesh transforms. Store the CPU
   # buffer explicitly so headless offline baking never serializes identities.
   additions.append({"scene": scene, "parent": -1, "instance_mesh": mesh, "instance_buffer": buffer, "instance_bounds": bounds, "background": group.background})
   instances += count
 # Prune only empty plain transforms without metadata or any external binding.
 # Retained nodes keep their original hierarchy and therefore their transforms.
 for index in range(nodes.size() - 1, -1, -1):
  var node: Node = nodes[index]
  if not removed.has(index) and children[index] == 0 and node.get_class() == "Node3D" and node.get_meta_list().is_empty() and not protected.has(index):
   removed[index] = true
  if removed.has(index) and recipe.records[index].parent >= 0: children[recipe.records[index].parent] -= 1
 var remap := {}
 var records: Array[Dictionary] = []
 for index in recipe.records.size():
  if removed.has(index): continue
  var record: Dictionary = recipe.records[index].duplicate()
  remap[index] = records.size()
  if record.parent >= 0: record.parent = remap[record.parent]
  records.append(record)
 records.append_array(additions)
 for animation: Dictionary in recipe.animations:
  animation.index = remap[animation.index]
  animation.values = _remap_references(animation.values, remap)
 for list: Array in [recipe.flippers, recipe.retracted, recipe.rings]:
  for index in list.size(): list[index] = remap[list[index]]
 for key: Variant in recipe.bumpers: recipe.bumpers[key] = remap[recipe.bumpers[key]]
 recipe.batch_stats = {"records_before": nodes.size(), "records_after": records.size(), "source_meshes": source_meshes,
  "instances": instances, "batches": additions.size(), "removed_nodes": removed.size()}
 recipe.records = records
 recipe.indices.clear()
 for node: Node in nodes: node.free()
 return recipe.batch_stats

func _protect_references(value: Variant, protected: Dictionary) -> void:
 if value is Resource:
  _protected_resources[value.get_instance_id()] = true
 elif value is Dictionary:
  if value.has("$node"): protected[int(value["$node"])] = true
  for item: Variant in value.values(): _protect_references(item, protected)
 elif value is Array:
  for item: Variant in value: _protect_references(item, protected)

func _remap_references(value: Variant, remap: Dictionary) -> Variant:
 if value is Dictionary:
  if value.has("$node"): return {"$node": remap[int(value["$node"])]}
  var result := {}
  for key: Variant in value: result[key] = _remap_references(value[key], remap)
  return result
 if value is Array:
  var result: Array = []
  for item: Variant in value: result.append(_remap_references(item, remap))
  return result
 return value

func _eligible(node: Node) -> bool:
 if not node is MeshInstance3D or not node.mesh is ArrayMesh: return false
 if node.mesh.get_surface_count() != 1 or node.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES: return false
 if node.mesh.get_blend_shape_count() > 0 or node.skin != null: return false
 var arrays: Array = node.mesh.surface_get_arrays(0)
 if arrays[Mesh.ARRAY_BONES] != null and not arrays[Mesh.ARRAY_BONES].is_empty(): return false
 if node.transparency > 0.0 or not node.get_meta_list().is_empty() or node.material_overlay != null: return false
 if node.custom_aabb != AABB(): return false
 if node.get_surface_override_material(0) != null or not node.visibility_parent.is_empty(): return false
 if node.visibility_range_begin > 0.0 or node.visibility_range_end > 0.0: return false
 for property: Dictionary in node.get_property_list():
  if str(property.name).begins_with("instance_shader_parameters/") and node.get(property.name) != null: return false
 return _material_safe(node.get_active_material(0))

func _material_safe(material: Material) -> bool:
 if material == null: return true
 if _protected_resources.has(material.get_instance_id()) or material.next_pass != null: return false
 if material is BaseMaterial3D:
  return material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED and not material.grow
 if material is ShaderMaterial:
  # Per-node coordinates/instance IDs and transparency ordering can change when
  # objects share a draw. Shader includes require a separate equivalence audit.
  var source: String = material.shader.code if material.shader != null else ""
  for token: String in ["ALPHA", "INSTANCE_ID", "INSTANCE_CUSTOM", "NODE_POSITION", "#include", "POSITION =", "POSITION=", "skip_vertex_transform"]:
   if token in source: return false
  return not source.is_empty()
 return false

func _render_state(node: MeshInstance3D, common: Dictionary) -> Dictionary:
 var result := {}
 for property: Dictionary in node.get_property_list():
  var key: String = property.name
  if int(property.usage) & PROPERTY_USAGE_STORAGE == 0 or not common.has(key): continue
  if key in ["name", "script", "owner", "transform", "unique_name_in_owner", "scene_file_path"]: continue
  result[key] = node.get(key)
 return result

func _value_key(value: Variant) -> Variant:
 if value is Resource:
  var id: int = value.get_instance_id()
  if _resource_keys.has(id): return _resource_keys[id]
  if not value.resource_path.is_empty() and not value.resource_path.contains("::"):
   return [value.get_class(), value.resource_path]
  # A cycle remains distinct instead of guessing resource equivalence.
  _resource_keys[id] = ["resource", id]
  var properties := {}
  for property: Dictionary in value.get_property_list():
   var key: String = property.name
   if int(property.usage) & PROPERTY_USAGE_STORAGE and key not in ["resource_name", "resource_path", "resource_scene_unique_id"]:
    properties[key] = value.get(key)
  var result: Array = [value.get_class(), _value_key(properties)]
  _resource_keys[id] = result
  return result
 if value is Dictionary:
  var keys: Array = value.keys()
  keys.sort()
  var result: Array = []
  for key: Variant in keys: result.append([key, _value_key(value[key])])
  return result
 if value is Array:
  var result: Array = []
  for item: Variant in value: result.append(_value_key(item))
  return result
 if value is Object: return ["object", value.get_instance_id()]
 return value

func _digest(value: Variant) -> String:
 var context := HashingContext.new()
 context.start(HashingContext.HASH_SHA256)
 context.update(var_to_bytes(value))
 return context.finish().hex_encode()

static func _transform_buffer(value: Transform3D) -> PackedFloat32Array:
 # RenderingServer.multimesh_set_buffer uses three row-major affine rows.
 return PackedFloat32Array([value.basis.x.x, value.basis.y.x, value.basis.z.x, value.origin.x,
  value.basis.x.y, value.basis.y.y, value.basis.z.y, value.origin.y,
  value.basis.x.z, value.basis.y.z, value.basis.z.z, value.origin.z])
