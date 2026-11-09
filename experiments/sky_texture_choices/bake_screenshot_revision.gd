extends SceneTree
## Color studies for the two user-requested screenshot corrections only.
const SOURCE := "res://experiments/sky_texture_choices/"
const OUTPUT := SOURCE + "v4/"
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 var viewport := SubViewport.new()
 viewport.size=Vector2i(512,512)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 swatch.size=Vector2(512,512)
 viewport.add_child(swatch)
 var source := FileAccess.get_file_as_string(SOURCE+"patterns_v3.gdshader")
 var shader := Shader.new()
 shader.code=source.substr(0,source.find("void fragment()"))+FileAccess.get_file_as_string(SOURCE+"screenshot_revision.gdshaderinc")
 var material := ShaderMaterial.new()
 material.shader=shader
 swatch.material=material
 for item in [1,5]:
  material.set_shader_parameter("item",item)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var error := viewport.get_texture().get_image().save_png(OUTPUT+str(item)+"A.png")
  if error!=OK:
   quit(1)
   return
 print("Screenshot revision: 1A and 5A saved. Role 4 omitted; production unchanged.")
 quit()
