extends SceneTree
## Phase 2 floor revision only. No production bindings or other approved artwork change.
const OUTPUT := "res://experiments/aquarium_texture_refined/floor_revision/"
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var viewport := SubViewport.new()
 viewport.size=Vector2i(1024,1024)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 swatch.size=Vector2(viewport.size)
 viewport.add_child(swatch)
 var shader := Shader.new()
 shader.code=FileAccess.get_file_as_string(OUTPUT+"floor.gdshader")
 var material := ShaderMaterial.new()
 material.shader=shader
 swatch.material=material
 var names := ["1-mixed-floor","1-flagstone","1-square-blue-panel"]
 for index in names.size():
  material.set_shader_parameter("view",index)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var picture := viewport.get_texture().get_image()
  picture.resize(512,512,Image.INTERPOLATE_LANCZOS)
  if picture.save_png(OUTPUT+names[index]+".png")!=OK:
   quit(1)
   return
  print("SAVED ",names[index])
 viewport.free()
 quit()
