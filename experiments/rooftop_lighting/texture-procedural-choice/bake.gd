extends SceneTree
## Standalone swatch bake, following tools/bake_rooftop_textures.gd.
## Writes experiment artwork only; does not load or modify the game scene.
const OUTPUT := "res://experiments/rooftop_lighting/texture-procedural-choice/"

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
 for item in range(1,10):
  var size := Vector2i(512,512)
  if item in [4,6]: size=Vector2i(512,128)
  elif item==8: size=Vector2i(512,256)
  viewport.size=size
  swatch.size=Vector2(size)
  for option in 2:
   material.set_shader_parameter("item",item)
   material.set_shader_parameter("option",option)
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   var filename := str(item) + ("A" if option==0 else "B") + ".png"
   var error := viewport.get_texture().get_image().save_png(OUTPUT+filename)
   if error != OK:
    push_error("Could not save " + filename)
    quit(1)
    return
   print("SWATCH | ", filename)
 viewport.queue_free()
 quit()
