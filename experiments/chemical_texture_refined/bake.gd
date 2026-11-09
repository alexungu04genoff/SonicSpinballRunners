extends SceneTree
## Refines only selected colour artwork. Production assets remain unchanged.
const OUTPUT := "res://experiments/chemical_texture_refined/"
const PICKS := {2: "2A", 5: "5A", 6: "6B", 7: "7A", 8: "8B", 10: "10A"}
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shader := Shader.new()
 shader.code = FileAccess.get_file_as_string(OUTPUT + "selected.gdshader")
 var material := ShaderMaterial.new()
 material.shader = shader
 swatch.material = material
 for item in PICKS:
  var size := Vector2i(512,512) if item in [5,7] else Vector2i(512,128)
  viewport.size=size*2
  swatch.size=Vector2(viewport.size)
  material.set_shader_parameter("item",item)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var image := viewport.get_texture().get_image()
  image.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
  image.save_png(OUTPUT+PICKS[item]+".png")
 print("Selected colour textures saved.")
 viewport.queue_free()
 quit()
