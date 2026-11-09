extends SceneTree
## Render only new Phase 1 albedo studies. Current artwork is never rebaked.
const OUTPUT := "res://experiments/lava_texture_choices/"

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var selections := PackedStringArray()
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--studies="): selections = argument.trim_prefix("--studies=").split(",")
 var written := 0
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
 for item in [1, 2, 3, 5, 6, 7, 8, 9, 10, 11]:
  var size := Vector2i(512, 512)
  if item in [2, 6, 8]: size = Vector2i(768, 192)
  elif item in [3, 9]: size = Vector2i(768, 384)
  viewport.size = size
  swatch.size = Vector2(size)
  for option in 2:
   var option_id: String = str(item) + ["A", "B"][option]
   if not selections.is_empty() and not option_id in selections: continue
   material.set_shader_parameter("item", item)
   material.set_shader_parameter("option", option)
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   var result := viewport.get_texture().get_image().save_png(OUTPUT + str(item) + ["A", "B"][option] + ".png")
   if result != OK:
    push_error("Could not save Phase 1 study")
    quit(1)
    return
   written += 1
 viewport.free()
 print("Phase 1: %d A/B albedo studies saved. Current production assets untouched." % written)
 quit()
