extends SceneTree
const ROOT := "res://assets/textures/chemical_plant/selected/"
const PICKS := {1:"1C",2:"2A",3:"3C",5:"5A",6:"6B",7:"7C-yellow",8:"8B",9:"9C"}
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shader := Shader.new()
 shader.code = FileAccess.get_file_as_string("res://experiments/chemical_texture_refined/relief.gdshader")
 var material := ShaderMaterial.new()
 material.shader = shader
 swatch.material = material
 for item in PICKS:
  var size := Vector2i(512,512)
  if item==1: size=Vector2i(1024,1024)
  elif item in [3,9]: size=Vector2i(1024,512)
  elif item in [2,6,8]: size=Vector2i(512,128)
  viewport.size=size
  swatch.size=Vector2(size)
  material.set_shader_parameter("item",item)
  material.set_shader_parameter("pixel_size",Vector2.ONE/Vector2(size))
  material.set_shader_parameter("normal_gain",.003 if item in [1,3,9] else .005)
  for channel in 5:
   material.set_shader_parameter("output_map",channel)
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   viewport.get_texture().get_image().save_png(ROOT+PICKS[item]+"_"+["height","normal","roughness","ao","metallic"][channel]+".png")
  print("Chemical material maps: ",PICKS[item])
 viewport.queue_free()
 quit()
