extends RefCounted
## Canonical Lava Reef albedo and structural response for source and disk play.
const DIRECTORY := "res://assets/textures/lava_reef/selected/"
const SHADER = preload("res://scripts/themes/lava_selected.gdshader")
const NORMAL_STRENGTH := 0.85
const FLOOR_NORMAL_STRENGTH := 6.0
static var textures: Dictionary = {}

static func texture(id: String) -> Texture2D:
 if not textures.has(id):
  if OS.has_feature("editor"):
   # Bake the current source pixels without relying on an older import cache.
   var image := Image.new()
   var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(DIRECTORY+id+".png"))
   assert(error==OK,"Cannot load Lava Reef albedo: "+id)
   image.generate_mipmaps()
   textures[id]=ImageTexture.create_from_image(image)
  else:
   textures[id]=load(DIRECTORY+id+".png")
 return textures[id]

static func surface(id: String, mapping: int, repeat_size: Vector2) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.resource_name="Lava Reef "+id
 result.shader=SHADER
 result.set_shader_parameter("albedo_texture",texture(id))
 result.set_shader_parameter("relief_normal",texture(id+"_normal"))
 result.set_shader_parameter("roughness_map",texture(id+"_roughness"))
 if id in ["1C","5B"]:
  result.set_shader_parameter("cavity_map",texture(id+"_cavity"))
  result.set_shader_parameter("cavity_enabled",true)
 var strength:=FLOOR_NORMAL_STRENGTH if id in ["1C","5B"] else NORMAL_STRENGTH
 result.set_shader_parameter("relief_strength",strength)
 result.set_meta("lava_selected",true)
 result.set_meta("lava_floor",id in ["1C","5B"])
 result.set_meta("normal_strength",strength)
 result.set_shader_parameter("mapping",mapping)
 result.set_shader_parameter("repeat_size",repeat_size)
 if id=="9B": result.set_shader_parameter("top_height",0.0)
 if mapping==6: result.set_meta("route_strip_uv",true)
 return result

static func bound_materials(root: Node) -> Array[ShaderMaterial]:
 # Include baked/private materials, surface overrides and MultiMesh batches.
 var result: Array[ShaderMaterial]=[]
 var seen: Dictionary={}
 var pending: Array[Node]=[root]
 while not pending.is_empty():
  var node: Node=pending.pop_back()
  pending.append_array(node.get_children())
  if not node is GeometryInstance3D:continue
  var candidates: Array[Material]=[node.material_override,node.material_overlay]
  var mesh: Mesh=null
  if node is MeshInstance3D:
   mesh=node.mesh
   if mesh!=null:
    for i in mesh.get_surface_count():candidates.append(node.get_active_material(i))
  elif node is MultiMeshInstance3D and node.multimesh!=null:mesh=node.multimesh.mesh
  if mesh!=null:
   for i in mesh.get_surface_count():candidates.append(mesh.surface_get_material(i))
  for material: Material in candidates:
   if not material is ShaderMaterial or not material.get_meta("lava_selected",false) or seen.has(material):continue
   seen[material]=true
   result.append(material)
 return result

static func set_detail(root: Node,enabled: bool,strength: float=1.0) -> int:
 var materials:=bound_materials(root)
 for material: ShaderMaterial in materials:
  material.set_shader_parameter("relief_strength",float(material.get_meta("normal_strength",NORMAL_STRENGTH))*clampf(strength,0.0,2.0) if enabled else 0.0)
  material.set_shader_parameter("detail_mix",1.0 if enabled else 0.0)
 return materials.size()
