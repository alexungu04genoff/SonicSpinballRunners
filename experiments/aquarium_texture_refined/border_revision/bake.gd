extends SceneTree
## Reopened role 2 border studies only. No production bindings or other approved artwork change.
const OUTPUT := "res://experiments/aquarium_texture_refined/border_revision/"
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var viewport := SubViewport.new()
 viewport.size=Vector2i(1024,256)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 swatch.size=Vector2(viewport.size)
 viewport.add_child(swatch)
 var shader := Shader.new()
 shader.code=FileAccess.get_file_as_string(OUTPUT+"border.gdshader")
 var material := ShaderMaterial.new()
 material.shader=shader
 swatch.material=material
 var names := ["2A-red-gold-studs","2B-plain-red"]
 for index in names.size():
  material.set_shader_parameter("view",index)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var picture := viewport.get_texture().get_image()
  picture.resize(512,128,Image.INTERPOLATE_LANCZOS)
  if picture.save_png(OUTPUT+names[index]+".png")!=OK:
   quit(1)
   return
  print("SAVED ",names[index])
 viewport.free()
 quit()

