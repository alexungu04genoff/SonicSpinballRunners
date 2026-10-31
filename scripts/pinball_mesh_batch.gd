extends RefCounted
## Merge rigid pieces inside one animated pinball actor, retaining its root and bindings.
const Surface = preload("res://scripts/pinball_surface.gdshader")
const VisualDetail = preload("res://scripts/endless/visual_detail.gd")
const ATTRIBUTES := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT,
 Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]
const STATE := ["layers", "cast_shadow", "gi_mode", "extra_cull_margin", "lod_bias",
 "ignore_occlusion_culling", "sorting_offset", "sorting_use_aabb_center"]
## In-process profiling switch; ordinary builders and offline exports leave it enabled.
static var enabled := true
static var shadow_batch_enabled := true

static func combine_shadows(actor: Node3D) -> int:
 if not shadow_batch_enabled: return 0
 var groups := {}
 for child: Node in actor.get_children():
  if not _eligible(child) or child.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: continue
  var source := child as MeshInstance3D
  if source.mesh.get_surface_count() == 0: continue
  var safe := true
  for surface in source.mesh.get_surface_count():
   if source.mesh is ArrayMesh and source.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: safe = false
   var material := source.get_active_material(surface)
   # This shader has no vertex displacement, alpha, discard or changed culling.
   # Preserve normals too: directional shadow normal bias uses them.
   if not material is ShaderMaterial or material.shader != Surface or material.next_pass != null:
    safe = false
   var arrays := source.mesh.surface_get_arrays(surface)
   if not _arrays_safe(arrays) or arrays[Mesh.ARRAY_NORMAL] == null or arrays[Mesh.ARRAY_NORMAL].size() != arrays[Mesh.ARRAY_VERTEX].size(): safe = false
  if not safe: continue
  var state := {}
  for property: String in STATE: state[property] = source.get(property)
  var key := str(state)
  if not groups.has(key): groups[key] = {"sources": [], "state": state}
  groups[key].sources.append(source)
 var removed := 0
 for group: Dictionary in groups.values():
  if group.sources.size() < 2: continue
  var arrays: Array = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
  arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
  arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
  for source: MeshInstance3D in group.sources:
   for surface in source.mesh.get_surface_count():
    _append(arrays, source.mesh.surface_get_arrays(surface), source.position)
  var mesh := ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  var caster := MeshInstance3D.new()
  caster.name = "PinballShadow"
  caster.mesh = mesh
  for property: String in STATE: caster.set(property, group.state[property])
  caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
  actor.add_child(caster)
  for source: MeshInstance3D in group.sources: source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  removed += group.sources.size() - 1
 return removed

static func combine(actor: Node3D, baked := false) -> Dictionary:
 if not enabled: return {}
 var groups := {}
 var sources: Array[MeshInstance3D] = []
 var surface_count := 0
 for child: Node in actor.get_children():
  if not _eligible(child): continue
  var source := child as MeshInstance3D
  var mesh: Mesh = source.mesh
  # ArrayMeshes bypass the later primitive conversion in BakeAssets. Apply the
  # existing bake detail policy here first; standalone geometry stays unchanged.
  if baked and mesh is PrimitiveMesh: mesh = VisualDetail.primitive(mesh)
  var surfaces: Array[Dictionary] = []
  for index in mesh.get_surface_count():
   if mesh is ArrayMesh and mesh.surface_get_primitive_type(index) != Mesh.PRIMITIVE_TRIANGLES: break
   var arrays := mesh.surface_get_arrays(index)
   var material := source.get_active_material(index)
   if not _arrays_safe(arrays) or not _material_safe(material): break
   surfaces.append({"arrays": arrays, "material": material})
  # A partly supported node must remain whole, including all its surfaces.
  if surfaces.size() != mesh.get_surface_count() or surfaces.is_empty(): continue
  sources.append(source)
  surface_count += surfaces.size()
  var state := {}
  for property: String in STATE: state[property] = source.get(property)
  for surface: Dictionary in surfaces:
   var format := 0
   for attribute: int in ATTRIBUTES:
    if surface.arrays[attribute] != null and not surface.arrays[attribute].is_empty(): format |= 1 << attribute
   var material_id: int = surface.material.get_instance_id() if surface.material != null else 0
   var key := str([material_id, state, format])
   if not groups.has(key):
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    for attribute: int in ATTRIBUTES:
     if format & (1 << attribute):
      var empty: Variant = surface.arrays[attribute].duplicate()
      empty.clear()
      arrays[attribute] = empty
    arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
    groups[key] = {"arrays": arrays, "material": surface.material, "state": state}
   _append(groups[key].arrays, surface.arrays, source.position)
 var result := {"surfaces_before": surface_count, "surfaces_after": surface_count,
  "nodes_before": sources.size(), "nodes_after": sources.size()}
 if groups.size() >= surface_count: return result
 for group: Dictionary in groups.values():
  var mesh := ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, group.arrays)
  var visual := MeshInstance3D.new()
  visual.name = "PinballBatch%d" % actor.get_child_count()
  visual.mesh = mesh
  visual.material_override = group.material
  for property: String in STATE: visual.set(property, group.state[property])
  actor.add_child(visual)
 # Free immediately: offline capture follows construction without an idle frame.
 for source: MeshInstance3D in sources:
  actor.remove_child(source)
  source.free()
 result.surfaces_after = groups.size()
 result.nodes_after = groups.size()
 return result

static func _eligible(node: Node) -> bool:
 if not node is MeshInstance3D or node.mesh == null: return false
 if node.get_child_count() > 0 or node.get_script() != null or not node.get_meta_list().is_empty(): return false
 if not node.visible or node.top_level or node.transform.basis != Basis.IDENTITY: return false
 if node.skin != null or node.material_overlay != null or node.transparency != 0.0: return false
 if node.custom_aabb != AABB() or not node.visibility_parent.is_empty(): return false
 if node.mesh.custom_aabb != AABB(): return false
 if node.visibility_range_begin != 0.0 or node.visibility_range_end != 0.0: return false
 if node.mesh is ArrayMesh:
  if node.mesh.get_blend_shape_count() > 0: return false
 elif not node.mesh is BoxMesh and not node.mesh is CylinderMesh:
  return false # The current pinball builders use only these triangle primitives.
 for property: Dictionary in node.get_property_list():
  if str(property.name).begins_with("instance_shader_parameters/") and node.get(property.name) != null: return false
 return true

static func _material_safe(material: Material) -> bool:
 if material == null: return true
 if material.next_pass != null: return false
 if material is ShaderMaterial: return material.shader == Surface
 if material is BaseMaterial3D:
  return material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED and not material.grow and not material.uv1_triplanar and not material.uv2_triplanar
 return false

static func _arrays_safe(arrays: Array) -> bool:
 if arrays.size() != Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] == null: return false
 var count: int = arrays[Mesh.ARRAY_VERTEX].size()
 if count == 0: return false
 for attribute in Mesh.ARRAY_MAX:
  if arrays[attribute] == null or arrays[attribute].is_empty(): continue
  if attribute == Mesh.ARRAY_INDEX: continue
  if attribute not in ATTRIBUTES: return false
  if arrays[attribute].size() != count * (4 if attribute == Mesh.ARRAY_TANGENT else 1): return false
 if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty():
  if arrays[Mesh.ARRAY_INDEX].size() % 3 != 0: return false
  for index: int in arrays[Mesh.ARRAY_INDEX]:
   if index < 0 or index >= count: return false
 elif count % 3 != 0: return false
 return true

static func _append(target: Array, source: Array, translation: Vector3) -> void:
 var vertices: PackedVector3Array = target[Mesh.ARRAY_VERTEX]
 var offset := vertices.size()
 for vertex: Vector3 in source[Mesh.ARRAY_VERTEX]: vertices.append(vertex + translation)
 target[Mesh.ARRAY_VERTEX] = vertices
 for attribute: int in ATTRIBUTES:
  if attribute == Mesh.ARRAY_VERTEX or target[attribute] == null: continue
  var values: Variant = target[attribute]
  values.append_array(source[attribute])
  target[attribute] = values
 var indices: PackedInt32Array = target[Mesh.ARRAY_INDEX]
 if source[Mesh.ARRAY_INDEX] != null and not source[Mesh.ARRAY_INDEX].is_empty():
  for index: int in source[Mesh.ARRAY_INDEX]: indices.append(offset + index)
 else:
  for index in source[Mesh.ARRAY_VERTEX].size(): indices.append(offset + index)
 target[Mesh.ARRAY_INDEX] = indices
