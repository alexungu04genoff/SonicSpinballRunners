extends SceneTree
## Focused user-requested albedo adjustments and structural reflection masks.
const OUTPUT := "res://experiments/ice_texture_refined/revision/"
const PICKS := {1: "1A", 2: "2B", 3: "3A", 5: "5A", 6: "6A", 7: "7B", 8: "8A", 9: "9A", 12: "12B"}

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var source := FileAccess.get_file_as_string("res://experiments/ice_texture_refined/response.gdshader")
 var only := 0
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--item="): only = int(argument.trim_prefix("--item="))
 for item: int in PICKS:
  if only != 0 and item != only: continue
  var size := Vector2i(512, 512)
  if item in [2, 6, 8]: size = Vector2i(512, 128)
  elif item in [3, 9]: size = Vector2i(512, 256)
  elif item == 12: size = Vector2i(1024, 1024)
  viewport.size = size * 2
  swatch.size = Vector2(viewport.size)
  for response: bool in [false, true]:
   var shader := Shader.new()
   shader.code = source.replace("uniform int item = 1;", "const int item = %d;" % item).replace("uniform bool response_map = false;", "const bool response_map = %s;" % ("true" if response else "false"))
   var material := ShaderMaterial.new()
   material.shader = shader
   swatch.material = material
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   var texture_image := viewport.get_texture().get_image()
   texture_image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
   var path: String = OUTPUT + PICKS[item] + ("-response" if response else "") + ".png"
   if texture_image.save_png(path) != OK:
    push_error("Could not export " + path)
    quit(1)
    return
   print("Saved ", path)
 viewport.queue_free()
 quit()
