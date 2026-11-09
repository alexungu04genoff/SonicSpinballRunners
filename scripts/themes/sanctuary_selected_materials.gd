extends RefCounted
## Selected Sky Sanctuary albedo and structural response through the production theme.
const DIRECTORY := "res://assets/textures/sky_sanctuary/selected/"
const SHADER = preload("res://scripts/themes/sanctuary_selected.gdshader")
static var textures: Dictionary = {}

static func texture(id: String) -> Texture2D:
 if not textures.has(id):
  if OS.has_feature("editor"):
   var image := Image.load_from_file(DIRECTORY+id+".png")
   image.generate_mipmaps()
   textures[id]=ImageTexture.create_from_image(image)
  else:
   textures[id]=load(DIRECTORY+id+".png")
 return textures[id]

static func surface(id: String, mapping: int, repeat_size: Vector2) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader=SHADER
 result.set_shader_parameter("albedo_texture",texture(id))
 result.set_shader_parameter("relief_normal",texture(id+"_normal"))
 result.set_shader_parameter("roughness_map",texture(id+"_roughness"))
 result.set_shader_parameter("relief_strength",0.75)
 result.set_meta("sky_selected",true)
 result.set_meta("normal_strength",0.75)
 result.set_shader_parameter("mapping",mapping)
 result.set_shader_parameter("repeat_size",repeat_size)
 if id=="8A": result.set_meta("route_strip_uv",true)
 return result

static func set_detail(root: Node, enabled: bool, strength: float = 1.0) -> int:
 # Walk actual bound resources, including baked/private materials and batches.
 var seen := {}
 var pending: Array[Node]=[root]
 while not pending.is_empty():
  var node: Node=pending.pop_back()
  pending.append_array(node.get_children())
  if not node is GeometryInstance3D: continue
  var candidates: Array[Material]=[node.material_override,node.material_overlay]
  var mesh: Mesh=null
  if node is MeshInstance3D:
   mesh=node.mesh
   if mesh!=null:
    for i in mesh.get_surface_count(): candidates.append(node.get_active_material(i))
  elif node is MultiMeshInstance3D and node.multimesh!=null:mesh=node.multimesh.mesh
  if mesh!=null:
   for i in mesh.get_surface_count():candidates.append(mesh.surface_get_material(i))
  for material: Material in candidates:
   if not material is ShaderMaterial or not material.get_meta("sky_selected",false) or seen.has(material):continue
   seen[material]=true
   material.set_shader_parameter("relief_strength",float(material.get_meta("normal_strength",.75))*clampf(strength,0.0,2.0) if enabled else 0.0)
   material.set_shader_parameter("detail_mix",1.0 if enabled else 0.0)
 return seen.size()

static func wrap_wall_mesh(mesh: ArrayMesh, outline: PackedVector2Array) -> ArrayMesh:
 var points := outline.duplicate()
 if Geometry2D.is_polygon_clockwise(points): points.reverse()
 var arrays := mesh.surface_get_arrays(1)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var coords := PackedVector2Array()
 var distance := 0.0
 var perimeter := 0.0
 for i in points.size(): perimeter+=points[i].distance_to(points[(i+1)%points.size()])*.01
 # Fit complete three-column tiles around the contour, with minimal pitch adjustment.
 var fit := maxf(1.0,roundf(perimeter/1.8))*1.8/maxf(perimeter,.001)
 for i in points.size():
  var end := distance+points[i].distance_to(points[(i+1)%points.size()])*.01
  for j in 6:
   coords.append(Vector2((end if j in [1,3,4] else distance)*fit,vertices[i*6+j].y))
  distance=end
 arrays[Mesh.ARRAY_TEX_UV]=coords
 var result := ArrayMesh.new()
 for i in mesh.get_surface_count():
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays if i==1 else mesh.surface_get_arrays(i))
  result.surface_set_material(i,mesh.surface_get_material(i))
 return result
