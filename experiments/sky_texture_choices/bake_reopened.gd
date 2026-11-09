extends SceneTree
## Reopened Phase 1 concepts only; selected concepts and production stay unchanged.
const SOURCE := "res://experiments/sky_texture_choices/"
const OUTPUT := SOURCE + "v3/"
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 var viewport := SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shader := Shader.new()
 shader.code = FileAccess.get_file_as_string(SOURCE + "patterns_v3.gdshader")
 var material := ShaderMaterial.new()
 material.shader = shader
 swatch.material = material
 for item in [1,4,5]:
  if OS.get_cmdline_user_args().has("only5a") and item != 5: continue
  var size := Vector2i(512,512) if item != 4 else Vector2i(768,192)
  viewport.size=size
  swatch.size=Vector2(size)
  for option in (2 if item==5 else 1):
   if OS.get_cmdline_user_args().has("only5a") and option != 0: continue
   material.set_shader_parameter("item",item)
   material.set_shader_parameter("option",option)
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   var error := viewport.get_texture().get_image().save_png(OUTPUT+str(item)+["A","B"][option]+".png")
   if error != OK:
    quit(1)
    return
 print("Reopened Phase 1: 1A, 4A, 5A and 5B saved. Selected options and C unchanged.")
 quit()
