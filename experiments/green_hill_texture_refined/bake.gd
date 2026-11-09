extends SceneTree
## Selected colour textures only. No production materials or maps are modified.
const OUTPUT := "res://experiments/green_hill_texture_refined/"
const PICKS := {1:"1A",2:"2B",3:"3A",4:"4B",5:"5B",6:"6B",8:"8B",10:"10A",11:"11B"}
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var viewport := SubViewport.new()
 viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shared := FileAccess.get_file_as_string("res://experiments/rooftop_lighting/texture-procedural-refined/selected.gdshader")
 var ideas := FileAccess.get_file_as_string("res://experiments/green_hill_texture_choices/patterns.gdshaderinc")
 var shader := Shader.new()
 shader.code=shared.left(shared.find("vec3 roof_color"))+ideas.left(ideas.find("void fragment()"))+FileAccess.get_file_as_string(OUTPUT+"selected.gdshaderinc")
 var material := ShaderMaterial.new()
 material.shader=shader
 swatch.material=material
 for item in PICKS:
  var size := Vector2i(512,512)
  if item in [2,4,6,8]:size=Vector2i(512,128)
  viewport.size=size*2
  swatch.size=Vector2(viewport.size)
  material.set_shader_parameter("item",item)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var image := viewport.get_texture().get_image()
  image.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
  image.save_png(OUTPUT+PICKS[item]+".png")
 print("Selected Green Hill colours saved. Item 9 reuses 3A; 7C remains untouched.")
 viewport.queue_free()
 quit()
