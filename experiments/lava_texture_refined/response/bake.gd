extends SceneTree
## Graphical authoring only: structural maps, leaving approved albedos untouched.
const BASE:="res://experiments/lava_texture_refined/"
const OUTPUT:="res://assets/textures/lava_reef/selected/"
const SPECS:={1:["1C",Vector2.ONE*(8.0/2.1)],2:["2A",Vector2(1.0,0.07)],3:["3B",Vector2(3.2,1.6)],
 5:["5B",Vector2(1.6,1.6)],6:["6B",Vector2(1.0,0.05)],7:["7A",Vector2(1.6,1.6)],
 8:["8B",Vector2(1.0,0.12)],9:["9B",Vector2(3.2,1.6)]}
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var viewport:=SubViewport.new()
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch:=ColorRect.new()
 viewport.add_child(swatch)
 var shader:=Shader.new()
 var source:=""
 for path: String in ["selected.gdshader","timber_revision/timber.gdshaderinc","balanced_revision/balanced.gdshaderinc"]:
  var piece:=FileAccess.get_file_as_string(BASE+path)
  source+=piece.left(piece.find("void fragment()"))
 shader.code=source+FileAccess.get_file_as_string(BASE+"response/response.gdshaderinc")
 var paint:=ShaderMaterial.new()
 paint.shader=shader
 swatch.material=paint
 var receipt:={"normal_convention":"OpenGL","height_source":"Procedural structural definitions; no albedo sampling","items":[]}
 for item: int in SPECS:
  var id: String=SPECS[item][0]
  var before:=FileAccess.get_sha256(OUTPUT+id+".png")
  var size:=Vector2i(512,512)
  if item in [2,6,8]:size=Vector2i(512,128)
  elif item in [3,9]:size=Vector2i(512,256)
  viewport.size=size*2
  swatch.size=Vector2(viewport.size)
  paint.set_shader_parameter("item",item)
  paint.set_shader_parameter("texel",Vector2.ONE/Vector2(size))
  paint.set_shader_parameter("physical_repeat",SPECS[item][1])
  paint.set_shader_parameter("reference_range",0.12 if item==1 else 0.065)
  for index in (4 if item in [1,5] else 3):
   paint.set_shader_parameter("response_pass",index)
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   var picture:=viewport.get_texture().get_image()
   picture.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
   var suffix: String=["height","normal","roughness","cavity"][index]
   var folder: String=BASE+"response/" if index==0 else OUTPUT
   assert(picture.save_png(folder+id+"_"+suffix+".png")==OK)
   if index==0 and item in [1,5]:
    var mesh:=preload("res://experiments/lava_texture_refined/response/rock_mesh.gd").build(picture,SPECS[item][1].x,0.12 if item==1 else 0.065)
    assert(ResourceSaver.save(mesh,OUTPUT+id+"_relief.res",ResourceSaver.FLAG_COMPRESS)==OK)
    print("LAVA_ROCK_MESH | ",id," | rocks=",mesh.get_meta("rock_count")," | triangles=",mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()/3)
  assert(before==FileAccess.get_sha256(OUTPUT+id+".png"))
  receipt.items.append({"id":id,"albedo_sha256":before,"repeat_world":str(SPECS[item][1]),"normal":OUTPUT+id+"_normal.png","roughness":OUTPUT+id+"_roughness.png","height_reference":BASE+"response/"+id+"_height.png","height_reference_range":0.12 if item==1 else 0.065,"cavity":OUTPUT+id+"_cavity.png" if item in [1,5] else ""})
  print("LAVA_RESPONSE | ",id," | structural normal and roughness; albedo unchanged")
 var file:=FileAccess.open(BASE+"response/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 file.close()
 viewport.free()
 quit()
