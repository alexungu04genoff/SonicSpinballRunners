extends SceneTree
const OUTPUT := "res://experiments/rooftop_lighting/texture-procedural-refined/"
const SELECTIONS := {1: "1A", 2: "2A", 3: "3C", 5: "5A", 6: "6C", 7: "7B", 8: "8B", 9: "9B", 10:"foliage"}
const SUFFIXES := ["height", "normal", "roughness", "ao", "metallic"]

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shader := Shader.new()
 var source := FileAccess.get_file_as_string(OUTPUT + "selected.gdshader")
 shader.code = source.left(source.find("void fragment()")) + FileAccess.get_file_as_string(OUTPUT + "relief_shapes.gdshaderinc")
 var material := ShaderMaterial.new()
 material.shader = shader
 swatch.material = material
 for item in SELECTIONS:
  if "--vegetation" in OS.get_cmdline_user_args() and item not in [2,10]: continue
  if "--surface-fixes" in OS.get_cmdline_user_args() and item not in [2,5,6]: continue
  var size := Vector2i(512,512)
  if item in [8,9]: size=Vector2i(512,256)
  elif item==3: size=Vector2i(1024,512) # Match the retained C artwork exactly.
  elif item==6: size=Vector2i(512,128)
  viewport.size=size
  swatch.size=Vector2(size)
  material.set_shader_parameter("item",item)
  material.set_shader_parameter("pixel_size",Vector2.ONE/Vector2(size))
  var gain := 0.004 if item in [2,3,8,9] else 0.006
  if item==5: gain=0.020
  elif item==6: gain=0.008
  elif item==2: gain=0.020
  material.set_shader_parameter("normal_gain",gain)
  for map in 6 if item in [2,10] else 5:
   material.set_shader_parameter("output_map",map)
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   var name: String=SELECTIONS[item]+(".png" if map==5 else "_"+SUFFIXES[map]+".png")
   var error := viewport.get_texture().get_image().save_png(OUTPUT+name)
   if error != OK:
    push_error("Could not save "+name)
    quit(1)
    return
  print("MATERIAL_MAPS | ",SELECTIONS[item])
 viewport.queue_free()
 quit()
