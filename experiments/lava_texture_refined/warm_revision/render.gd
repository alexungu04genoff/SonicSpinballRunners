extends SceneTree
## Albedo-only concept board and generic stepped material study, not gameplay.
const BASE := "res://experiments/lava_texture_refined/"
const OUTPUT := BASE + "warm_revision/"
var materials := {}

func _initialize() -> void:
 call_deferred("run")

func read_image(path: String) -> Image:
 var picture := Image.new()
 var error := picture.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
 assert(error == OK, "Cannot read " + path)
 return picture

func material(path: String) -> StandardMaterial3D:
 if materials.has(path): return materials[path]
 var result := StandardMaterial3D.new()
 result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 result.cull_mode = BaseMaterial3D.CULL_DISABLED
 result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 result.albedo_texture = ImageTexture.create_from_image(read_image(path))
 materials[path] = result
 return result

func quad(parent: Node3D, points: Array[Vector3], coordinates: Array[Vector2], path: String) -> void:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for index in [0,1,2,0,2,3]:
  surface.set_uv(coordinates[index])
  surface.add_vertex(points[index])
 surface.generate_normals()
 var instance := MeshInstance3D.new()
 instance.mesh = surface.commit()
 instance.material_override = material(path)
 parent.add_child(instance)

func top(parent: Node3D, x: float, z: float, width: float, depth: float, height: float, path: String, period: Vector2) -> void:
 quad(parent,[Vector3(x,height,z),Vector3(x+width,height,z),Vector3(x+width,height,z+depth),Vector3(x,height,z+depth)],
  [Vector2.ZERO,Vector2(width/period.x,0),Vector2(width/period.x,depth/period.y),Vector2(0,depth/period.y)],path)

func front(parent: Node3D, x: float, z: float, width: float, height: float, path: String) -> void:
 quad(parent,[Vector3(x,height,z),Vector3(x+width,height,z),Vector3(x+width,0,z),Vector3(x,0,z)],
  [Vector2.ZERO,Vector2(width/3.2,0),Vector2(width/3.2,height/1.6),Vector2(0,height/1.6)],path)

func study(viewport: SubViewport, warm: bool, save_path: String = "", top_path: String = "", floor_path: String = "", wall_path: String = "") -> void:
 var stage := Node3D.new()
 viewport.add_child(stage)
 var folder := OUTPUT if warm else BASE
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color("17171b")
 stage.add_child(env)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 9.3
 stage.add_child(camera)
 camera.position = Vector3(6.7,6.6,8.4)
 camera.look_at(Vector3(0,0.35,0))
 # Generic two-level slab, deliberately without game actors, collision or scene code.
 top(stage,-3.5,-2.7,7.0,5.4,0,BASE+"1C.png" if floor_path.is_empty() else floor_path,Vector2.ONE*(8.0/2.1))
 top(stage,-3.5,2.58,7.0,0.12,0.006,BASE+"2A.png",Vector2(1,0.12))
 top(stage,-3.5,-2.7,7.0,0.12,0.006,BASE+"2A.png",Vector2(1,0.12))
 top(stage,-2.15,-2.25,5.2,2.6,1.05,folder+"5B.png" if top_path.is_empty() else top_path,Vector2(1.6,1.6))
 front(stage,-2.15,0.35,5.2,1.05,folder+"3B.png" if wall_path.is_empty() else wall_path)
 quad(stage,[Vector3(3.05,1.05,0.35),Vector3(3.05,1.05,-2.25),Vector3(3.05,0,-2.25),Vector3(3.05,0,0.35)],
  [Vector2.ZERO,Vector2(2.6/3.2,0),Vector2(2.6/3.2,1.05/1.6),Vector2(0,1.05/1.6)],folder+"9B.png")
 top(stage,-2.15,0.23,5.2,0.12,1.056,BASE+"6B.png",Vector2(1,0.12))
 top(stage,-2.15,-2.25,5.2,0.12,1.056,BASE+"6B.png",Vector2(1,0.12))
 # A small ramp carries retained 7A and 8B, showing their share of the palette.
 quad(stage,[Vector3(-1.75,0.018,2.2),Vector3(-0.75,0.018,2.2),Vector3(-0.75,1.064,0.16),Vector3(-1.75,1.064,0.16)],
  [Vector2(0,1.4),Vector2(0.625,1.4),Vector2(0.625,0),Vector2.ZERO],BASE+"7A.png")
 for x: float in [-1.75,-0.75]:
  quad(stage,[Vector3(x,0.018,2.2),Vector3(x,1.064,0.16),Vector3(x,1.20,0.16),Vector3(x,0.155,2.2)],
   [Vector2(0,1),Vector2(2.2,1),Vector2(2.2,0),Vector2.ZERO],BASE+"8B.png")
 for frame in 8: await process_frame
 await RenderingServer.frame_post_draw
 var destination := OUTPUT + ("proposed-study.png" if warm else "previous-study.png") if save_path.is_empty() else save_path
 viewport.get_texture().get_image().save_png(destination)
 stage.free()

func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var source := FileAccess.get_file_as_string(BASE+"selected.gdshader")
 source = source.left(source.find("void fragment()")) + FileAccess.get_file_as_string(OUTPUT+"warm.gdshaderinc")
 var shader := Shader.new()
 shader.code = source
 var shader_material := ShaderMaterial.new()
 shader_material.shader = shader
 swatch.material = shader_material
 for item: int in [3,5,9]:
  var size := Vector2i(512,512) if item==5 else Vector2i(512,256)
  viewport.size = size*2
  swatch.size = Vector2(viewport.size)
  shader_material.set_shader_parameter("item",item)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var picture := viewport.get_texture().get_image()
  picture.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
  assert(picture.save_png(OUTPUT+str(item)+"B.png")==OK)
  var repeated := Image.create(size.x*2,size.y*2,false,picture.get_format())
  for y in 2:
   for x in 2: repeated.blit_rect(picture,Rect2i(Vector2i.ZERO,size),Vector2i(x,y)*size)
  repeated.save_png(OUTPUT+str(item)+"B-repeat.png")
  print("WARM_STUDY | ",item,"B")
 swatch.free()
 viewport.own_world_3d = true
 viewport.msaa_3d = Viewport.MSAA_4X
 viewport.size = Vector2i(1000,760)
 await study(viewport,false)
 await study(viewport,true)
 viewport.free()
 print("Three proposed albedos and two unlit material studies saved. No production changes.")
 quit()
