extends SceneTree
## Produces only the six approved albedo candidates. No game scene is loaded.
const OUTPUT := "res://experiments/rooftop_lighting/texture-procedural-refined/"
const SELECTIONS := {1: "1A", 2: "2A", 5: "5A", 7: "7B", 8: "8B", 9: "9B"}

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
 for item in SELECTIONS:
  var size := Vector2i(512, 512)
  if item in [8, 9]: size = Vector2i(512, 256)
  viewport.size = size
  swatch.size = Vector2(size)
  material.set_shader_parameter("item", item)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var filename: String = SELECTIONS[item] + ".png"
  var error := viewport.get_texture().get_image().save_png(OUTPUT + filename)
  if error != OK:
   push_error("Could not save " + filename)
   quit(1)
   return
  print("ALBEDO | ", filename)
 viewport.queue_free()
 quit()
