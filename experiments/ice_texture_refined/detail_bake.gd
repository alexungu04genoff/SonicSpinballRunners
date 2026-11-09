extends SceneTree
## Structural OpenGL normals and reference heights; approved albedos stay intact.
const OUTPUT := "res://assets/textures/ice_cap/selected/"
const SOURCE := "res://experiments/ice_texture_refined/"
const PROFILES := {
 1: ["1A", Vector2(7.2, 7.2), .025],
 2: ["2B", Vector2(.48, .06), .006],
 3: ["3A", Vector2(1.8, .9), .055],
 5: ["5A", Vector2(8, 8), .025],
 6: ["6A", Vector2(.48, .04), .006],
 7: ["7B", Vector2(.6, 1.8), .018],
 9: ["9A", Vector2(1.8, 1.6), .055],
 11: ["11A", Vector2.ONE, .008],
 12: ["12B", Vector2(32, 32), .04],
}

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var source := FileAccess.get_file_as_string(SOURCE + "response.gdshader")
 source = source.left(source.find("\nvoid fragment()"))
 source += FileAccess.get_file_as_string(SOURCE + "structure.gdshaderinc")
 for item: int in PROFILES:
  var profile: Array = PROFILES[item]
  var albedo := Image.load_from_file(OUTPUT + str(profile[0]) + ".png")
  var size := albedo.get_size()
  viewport.size = size * 2
  swatch.size = Vector2(viewport.size)
  for normal: bool in [false, true]:
   var shader := Shader.new()
   shader.code = source.replace("uniform int item = 1;", "const int item = %d;" % item).replace("uniform bool export_normal = true;", "const bool export_normal = %s;" % ("true" if normal else "false"))
   if shader.get_shader_uniform_list().is_empty():
    push_error("Structural shader did not compile for " + str(profile[0]))
    quit(1)
    return
   var material := ShaderMaterial.new()
   material.shader = shader
   material.set_shader_parameter("physical_size", profile[1])
   material.set_shader_parameter("height_world_scale", profile[2])
   material.set_shader_parameter("sample_step", Vector2.ONE / Vector2(size))
   swatch.material = material
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   var output := viewport.get_texture().get_image()
   output.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
   var path := OUTPUT + str(profile[0]) + ("-normal" if normal else "-height") + ".png"
   if output.save_png(path) != OK:
    push_error("Could not save " + path)
    quit(1)
    return
   print("ICE_DETAIL_SAVED | ", path)
 viewport.queue_free()
 quit()
