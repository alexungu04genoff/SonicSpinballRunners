extends SceneTree
## Phase 1 albedo studies only. Never regenerates current production textures.
const OUTPUT := "res://experiments/aquarium_texture_choices/"
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
 for item in [1,2,3,5,6,7,8,9]:
  var size := Vector2i(384,384)
  if item in [2,6,8]: size=Vector2i(512,128)
  elif item in [3,9]: size=Vector2i(512,256)
  viewport.size=size
  swatch.size=Vector2(size)
  for option in 2:
   material.set_shader_parameter("item",item)
   material.set_shader_parameter("option",option)
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   var error := viewport.get_texture().get_image().save_png(OUTPUT+str(item)+["A","B"][option]+".png")
   if error != OK:
    quit(1)
    return
 print("Phase 1: 16 A/B albedo studies saved. Production unchanged.")
 quit()

