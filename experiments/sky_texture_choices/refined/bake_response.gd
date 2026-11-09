extends SceneTree
## Phase 4 analytical maps. The selected albedo files are never rewritten.
const SOURCE := "res://experiments/sky_texture_choices/refined/"
const OUTPUT := "res://assets/textures/sky_sanctuary/selected/"
const ITEMS := {
 1:["1A",Vector2(3.2,3.2),.012], 2:["2B",Vector2(1.92,.08),.003],
 3:["3B",Vector2(1.8,.325),.008], 5:["5A",Vector2(2.4,2.4),.012],
 6:["6A",Vector2(1.92,.08),.003], 7:["7B",Vector2(.8,1.6),.008],
 8:["8A",Vector2(1.92,.12),.004], 9:["9B",Vector2(2.4,1.6),.030]}
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shader := Shader.new()
 var source := FileAccess.get_file_as_string(SOURCE+"albedo.gdshader")
 shader.code=source.substr(0,source.find("void fragment()"))+FileAccess.get_file_as_string(SOURCE+"response.gdshaderinc")
 var material := ShaderMaterial.new()
 material.shader=shader
 swatch.material=material
 var receipt := {"albedo_source_sha256":FileAccess.get_sha256(SOURCE+"albedo.gdshader"),"normal_convention":"OpenGL","items":{}}
 for item: int in ITEMS:
  var spec: Array=ITEMS[item]
  var size:=Vector2i(512,512)
  if item in [2,6,8]:size=Vector2i(512,128)
  elif item in [3,9]:size=Vector2i(512,256)
  viewport.size=size*2
  swatch.size=Vector2(size*2)
  material.set_shader_parameter("item",item)
  material.set_shader_parameter("texel",Vector2.ONE/Vector2(size))
  material.set_shader_parameter("physical_repeat",spec[1])
  material.set_shader_parameter("height_range",spec[2])
  receipt.items[spec[0]]={"nominal_repeat":str(spec[1]),"height_range_world":spec[2],"albedo_sha256":FileAccess.get_sha256(OUTPUT+spec[0]+".png")}
  for pass_index in 3:
   var suffix: String=["height","normal","roughness"][pass_index]
   material.set_shader_parameter("response_pass",pass_index)
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   var result:=viewport.get_texture().get_image()
   result.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
   if result.save_png(OUTPUT+spec[0]+"_"+suffix+".png")!=OK:
    quit(1)
    return
  print("SKY_RESPONSE | ",spec[0]," | normal, roughness, source height")
 var file:=FileAccess.open(SOURCE+"response-manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 quit()
