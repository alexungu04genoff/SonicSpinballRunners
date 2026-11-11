extends RefCounted
## Known hardware builders opt in: their rigid leaves never animate independently.
## Each moving/hidden parent keeps its own caster. Visible meshes remain untouched.
const Batch = preload("res://scripts/pinball_mesh_batch.gd")
const Detail = preload("res://scripts/endless/visual_detail.gd")
static var enabled := not "--profile-original-gimmick-shadows" in OS.get_cmdline_user_args()

static func combine(root: Node3D, baked := false, excluded: Array = [], cell_size := 0.0) -> int:
 if not enabled: return 0
 var saved := 0
 var groups := {}
 for child: Node in root.get_children():
  if child is Node3D and not child is GeometryInstance3D:
   saved += combine(child, baked, excluded, cell_size)
  if child in excluded or not Batch._eligible(child): continue
  var source := child as MeshInstance3D
  if source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: continue
  var mesh: Mesh = Detail.primitive(source.mesh) if baked and source.mesh is PrimitiveMesh else source.mesh
  var cell := Vector2i.ZERO
  if cell_size > 0.0:
   # Rails keep independently culled sections. Never pull a long deck or pipe
   # into a group of small posts, even if a future style uses a standard material.
   var box: AABB = source.transform * mesh.get_aabb()
   if maxf(box.size.x, box.size.z) > cell_size: continue
   var center := box.get_center()
   cell = Vector2i(floori(center.x / cell_size), floori(center.z / cell_size))
  var surfaces: Array[Array] = []
  for index in mesh.get_surface_count():
   if mesh is ArrayMesh and mesh.surface_get_primitive_type(index) != Mesh.PRIMITIVE_TRIANGLES: break
   if not _opaque(source.get_active_material(index)): break
   var arrays := mesh.surface_get_arrays(index)
   if not Batch._arrays_safe(arrays) or arrays[Mesh.ARRAY_NORMAL] == null or arrays[Mesh.ARRAY_NORMAL].size() != arrays[Mesh.ARRAY_VERTEX].size(): break
   surfaces.append(arrays)
  if surfaces.is_empty() or surfaces.size() != mesh.get_surface_count(): continue
  var state := {}
  for property: String in Batch.STATE: state[property] = source.get(property)
  var key := str([cell, state])
  if not groups.has(key): groups[key] = {"sources": [], "surfaces": [], "state": state}
  groups[key].sources.append(source)
  groups[key].surfaces.append(surfaces)
 for group: Dictionary in groups.values():
  if group.sources.size() < 2: continue
  var arrays: Array = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
  arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
  arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
  for index in group.sources.size():
   for surface: Array in group.surfaces[index]:
    Batch._append(arrays, surface, group.sources[index].position)
  var caster := MeshInstance3D.new()
  caster.name = "GimmickShadow"
  caster.mesh = ArrayMesh.new()
  caster.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  for property: String in Batch.STATE: caster.set(property, group.state[property])
  caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
  root.add_child(caster)
  for source: MeshInstance3D in group.sources: source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  saved += group.sources.size() - 1
 return saved

static func _opaque(material: Material) -> bool:
 # Alpha, altered culling, displacement and arbitrary shaders need their original
 # shadow program. Color/emission animation on these standard materials does not.
 return material is StandardMaterial3D and material.next_pass == null \
  and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
  and material.cull_mode == BaseMaterial3D.CULL_BACK \
  and material.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED \
  and not material.grow and not material.no_depth_test \
  and not material.heightmap_enabled \
  and not material.shadow_to_opacity
