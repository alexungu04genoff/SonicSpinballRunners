extends SceneTree
## Colour sketches only. No game scene or production materials are changed.
const OUTPUT := "res://experiments/chemical_texture_choices/"
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shader := Shader.new()
 shader.code = FileAccess.get_file_as_string(OUTPUT + "patterns.gdshader")
 var material := ShaderMaterial.new()
 material.shader = shader
 swatch.material = material
 for item in range(1,12):
  var size := Vector2i(384,384)
  if item in [2,4,6,8,10]: size=Vector2i(512,128)
  viewport.size=size
  swatch.size=Vector2(size)
  for option in (3 if item==11 else 2):
   material.set_shader_parameter("item",item)
   material.set_shader_parameter("option",option)
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   viewport.get_texture().get_image().save_png(OUTPUT+str(item)+["A","B","C"][option]+".png")
 viewport.queue_free()
 print("Colour sketches saved.")
 quit()
