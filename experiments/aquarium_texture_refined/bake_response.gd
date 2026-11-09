extends SceneTree
## Generate structural response without rewriting any approved albedo.
const SOURCE := "res://experiments/aquarium_texture_refined/"
const OUTPUT := "res://assets/textures/aquarium_park/selected/"
const ITEMS := {
 1:["1-mixed-floor",Vector2(3.6,3.6),.009],
 2:["2A-red-gold-studs",Vector2(.16,.04),.0015],
 3:["3B",Vector2(.64,.26),.007],
 4:["4B",Vector2(.64,.065),.003],
 5:["5A-red",Vector2(1.8,1.8),.024],
 6:["6A-red",Vector2(1.8,.02),.0015],
 7:["7B",Vector2(.6,1.2),.008],
 8:["8A",Vector2(.72,.06),.002],
 9:["9A",Vector2(2.4,1.925),.020]}
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shader := Shader.new()
 var source := FileAccess.get_file_as_string(SOURCE+"selected.gdshader")
 var floor_source := FileAccess.get_file_as_string(SOURCE+"floor_revision/floor.gdshader")
 # Reuse the exact approved periodic stone-cell search, not a second noise field.
 var shape_start := floor_source.find("vec3 flagstone(")
 var shape_end := floor_source.find(" vec2 tint=",shape_start)
 var shape := floor_source.substr(shape_start,shape_end-shape_start).replace("vec3 flagstone(","vec3 stone_structure(")
 shape+=" return vec3(edge_distance,nearest);\n}\n"
 var hash_start := floor_source.find("vec2 hash2(")
 var hash_end := floor_source.find("\n",hash_start)
 shader.code=source.substr(0,source.find("void fragment()"))+floor_source.substr(hash_start,hash_end-hash_start)+"\n"+shape+FileAccess.get_file_as_string(SOURCE+"response.gdshaderinc")
 var material := ShaderMaterial.new()
 material.shader=shader
 swatch.material=material
 var receipt := {"normal_convention":"OpenGL","response_channels":{"r":"roughness","g":"exposed metal only","b":"unused"},"height_usage":"Source reference only; no runtime parallax or displacement","source_sha256":{},"items":{}}
 for path: String in ["selected.gdshader","floor_revision/floor.gdshader","border_revision/border.gdshader","response.gdshaderinc"]:
  receipt.source_sha256[path]=FileAccess.get_sha256(SOURCE+path)
 for item: int in ITEMS:
  var spec: Array=ITEMS[item]
  var size := Vector2i(512,512)
  if item in [2,4,6,8]:size=Vector2i(512,128)
  elif item in [3,9]:size=Vector2i(512,256)
  viewport.size=size*2
  swatch.size=Vector2(viewport.size)
  material.set_shader_parameter("item",item)
  material.set_shader_parameter("texel",Vector2.ONE/Vector2(size))
  material.set_shader_parameter("physical_repeat",spec[1])
  material.set_shader_parameter("height_range",spec[2])
  receipt.items[spec[0]]={"nominal_repeat":str(spec[1]),"height_range_world":spec[2],"albedo_sha256":FileAccess.get_sha256(OUTPUT+spec[0]+".png"),"maps":{}}
  for pass_index in 3:
   var suffix: String=["height","normal","response"][pass_index]
   material.set_shader_parameter("response_pass",pass_index)
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   var result := viewport.get_texture().get_image()
   result.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
   var path: String=OUTPUT+spec[0]+"_"+suffix+".png"
   if result.save_png(path)!=OK:
    quit(1)
    return
   receipt.items[spec[0]].maps[suffix]=FileAccess.get_sha256(path)
  print("AQUARIUM_RESPONSE | ",spec[0]," | normal, packed response, source height")
 var file := FileAccess.open(SOURCE+"response-manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 quit()
