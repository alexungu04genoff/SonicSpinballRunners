extends RefCounted
## Current Ice Cap artwork, aligned structural normals and reflection response.
const DIRECTORY := "res://assets/textures/ice_cap/selected/"
const SHADER = preload("res://scripts/themes/ice_selected.gdshader")
const WALL_REPEAT := Vector2(1.8, 0.9)
const NORMAL_STRENGTH := {"1A": .45, "2B": .4, "3A": .65, "5A": .35, "6A": .4, "7B": .65, "9A": .65, "11A": .3, "12B": .35}
static var textures: Dictionary = {}

static func texture(id: String) -> Texture2D:
 if not textures.has(id):
  if OS.has_feature("editor"):
   # Embed current source pixels in authoring bakes, without stale import caches.
   var image := Image.load_from_file(DIRECTORY + id + ".png")
   image.generate_mipmaps()
   textures[id] = ImageTexture.create_from_image(image)
  else:
   textures[id] = load(DIRECTORY + id + ".png")
 return textures[id]

static func surface(id: String, mapping: int, repeat_size: Vector2) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.resource_name = "Ice Cap " + id
 result.shader = SHADER
 result.set_shader_parameter("albedo_texture", texture(id))
 result.set_shader_parameter("has_response_map", id != "11A")
 if id != "11A": result.set_shader_parameter("response_texture", texture(id + "-response"))
 configure_detail(result, id)
 result.set_shader_parameter("mapping", mapping)
 result.set_shader_parameter("repeat_size", repeat_size)
 return result

static func configure_detail(material: ShaderMaterial, id: String) -> void:
 material.set_shader_parameter("relief_normal", texture(id + "-normal"))
 material.set_shader_parameter("relief_strength", NORMAL_STRENGTH[id])
 material.set_meta("ice_selected", true)
 material.set_meta("normal_strength", NORMAL_STRENGTH[id])

static func set_detail(root: Node, enabled: bool, strength := 1.0) -> int:
 # Reach the actual bound materials, including private atmosphere copies and bakes.
 var seen := {}
 var pending: Array[Node] = [root]
 while not pending.is_empty():
  var node: Node = pending.pop_back()
  pending.append_array(node.get_children())
  if not node is GeometryInstance3D: continue
  var candidates: Array[Material] = [node.material_override, node.material_overlay]
  var mesh: Mesh
  if node is MeshInstance3D:
   mesh = node.mesh
   if mesh != null:
    for i in mesh.get_surface_count(): candidates.append(node.get_active_material(i))
  elif node is MultiMeshInstance3D and node.multimesh != null:
   mesh = node.multimesh.mesh
  if mesh != null:
   for i in mesh.get_surface_count(): candidates.append(mesh.surface_get_material(i))
  for material: Material in candidates:
   if not material is ShaderMaterial or not material.get_meta("ice_selected", false) or seen.has(material): continue
   seen[material] = true
   material.set_shader_parameter("relief_strength", float(material.get_meta("normal_strength")) * clampf(strength, 0.0, 2.0) if enabled else 0.0)
 return seen.size()

static func wrap_wall_mesh(mesh: ArrayMesh, outline: PackedVector2Array) -> ArrayMesh:
 var points := outline.duplicate()
 if Geometry2D.is_polygon_clockwise(points): points.reverse()
 var arrays := mesh.surface_get_arrays(1)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var coords := PackedVector2Array()
 var distance := 0.0
 var perimeter := 0.0
 for i in points.size(): perimeter += points[i].distance_to(points[(i + 1) % points.size()]) * 0.01
 # Fit whole crystal modules around each closed outline. Only UVs change.
 var fit := maxf(1.0, roundf(perimeter / WALL_REPEAT.x)) * WALL_REPEAT.x / maxf(perimeter, 0.001)
 for i in points.size():
  var end := distance + points[i].distance_to(points[(i + 1) % points.size()]) * 0.01
  for j in 6:
   coords.append(Vector2((end if j in [1, 3, 4] else distance) * fit, vertices[i * 6 + j].y))
  distance = end
 arrays[Mesh.ARRAY_TEX_UV] = coords
 var result := ArrayMesh.new()
 for i in mesh.get_surface_count():
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays if i == 1 else mesh.surface_get_arrays(i))
  result.surface_set_material(i, mesh.surface_get_material(i))
 return result
