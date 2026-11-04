extends RefCounted
## Combine opaque, untextured static scenery in small spatial cells.
## Animated props, terrain shaders and gameplay objects retain their own meshes.

static func combine(root: Node3D) -> void:
 var groups: Dictionary = {}
 var signatures: Dictionary = {}
 var root_inverse := root.global_transform.affine_inverse()
 for visual: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
  if not visual.is_visible_in_tree() or visual.mesh == null or visual.mesh.get_surface_count() != 1:
   continue
  if visual.get_child_count() != 0 or visual.material_overlay != null or visual.skin != null:
   continue
  var animated := false
  var scenery_kind := ""
  var ancestor: Node = visual
  while ancestor != root:
   if ancestor.has_meta("atmosphere_scenery"):
    scenery_kind = str(ancestor.get_meta("atmosphere_scenery"))
   if ancestor.get_script() != null:
    animated = true
    break
   ancestor = ancestor.get_parent()
  if animated: continue
  var material := visual.get_active_material(0) as StandardMaterial3D
  if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
   continue
  if material.albedo_texture != null or material.normal_enabled or material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
   continue
  if material.next_pass != null or material.vertex_color_use_as_albedo or visual.transparency > 0.0: continue
  var uses_texture := false
  for property in material.get_property_list():
   if property.usage & PROPERTY_USAGE_STORAGE and material.get(property.name) is Texture2D:
    uses_texture = true
    break
  if uses_texture: continue
  if not signatures.has(material):
   var properties: Array = []
   for property in material.get_property_list():
    if property.usage & PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_"):
     properties.append([property.name, material.get(property.name)])
   signatures[material] = var_to_str(properties)
  var transform := root_inverse * visual.global_transform
  # Mirrored meshes need their original winding/culling treatment.
  if transform.basis.determinant() <= 0.0: continue
  var cell := Vector2i(floori(transform.origin.x / 4.0), floori(transform.origin.z / 4.0))
  # Far Zone scenery and Act-local framing must remain independently visible.
  # Palette copies retain their shared material bindings through the batch.
  if not scenery_kind.is_empty(): visual.set_meta("atmosphere_scenery", scenery_kind)
  var key: String = str([cell, scenery_kind, visual.layers, visual.cast_shadow, visual.gi_mode, signatures[material]])
  if not groups.has(key): groups[key] = []
  groups[key].append(visual)
 for group: Array in groups.values():
  if group.size() < 2: continue
  var first: MeshInstance3D = group[0]
  var vertices := PackedVector3Array()
  var normals := PackedVector3Array()
  var indices := PackedInt32Array()
  for visual: MeshInstance3D in group:
   var arrays := visual.mesh.surface_get_arrays(0)
   var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
   var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
   var transform := root_inverse * visual.global_transform
   var normal_basis := transform.basis.inverse().transposed()
   var offset := vertices.size()
   for i in source_vertices.size():
    vertices.append(transform * source_vertices[i])
    normals.append((normal_basis * source_normals[i]).normalized())
   if source_indices.is_empty():
    for i in source_vertices.size(): indices.append(offset + i)
   else:
    for i in source_indices: indices.append(offset + i)
  var arrays: Array = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_NORMAL] = normals
  arrays[Mesh.ARRAY_INDEX] = indices
  var mesh := ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  var batch := MeshInstance3D.new()
  batch.name = "StaticSceneryBatch"
  batch.mesh = mesh
  batch.material_override = first.get_active_material(0)
  batch.layers = first.layers
  batch.cast_shadow = first.cast_shadow
  batch.gi_mode = first.gi_mode
  if first.has_meta("atmosphere_scenery"):
   batch.set_meta("atmosphere_scenery", first.get_meta("atmosphere_scenery"))
  root.add_child(batch)
  for visual: MeshInstance3D in group:
   visual.hide()
   visual.queue_free()
