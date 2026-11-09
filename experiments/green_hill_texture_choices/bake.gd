extends SceneTree
## Phase-one colour sketches only; current game assets are never overwritten.
const OUTPUT := "res://experiments/green_hill_texture_choices/"
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
 var shader := Shader.new()
 shader.code=shared.left(shared.find("vec3 roof_color"))+FileAccess.get_file_as_string(OUTPUT+"patterns.gdshaderinc")
 var material := ShaderMaterial.new()
 material.shader=shader
 swatch.material=material
 for item in range(1,12):
  var size := Vector2i(384,384)
  if item in [2,4,6,8]:size=Vector2i(512,128)
  viewport.size=size
  swatch.size=Vector2(size)
  material.set_shader_parameter("item",item)
  for option in 2:
   material.set_shader_parameter("option",option)
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   viewport.get_texture().get_image().save_png(OUTPUT+str(item)+("A" if option==0 else "B")+".png")
 print("Green Hill A/B colour sketches saved.")
 viewport.queue_free()
 quit()
