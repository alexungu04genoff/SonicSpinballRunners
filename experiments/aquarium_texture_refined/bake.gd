extends SceneTree
## Phase 2 selected albedo only. Re-evaluates analytic artwork at output resolution.
const OUTPUT := "res://experiments/aquarium_texture_refined/"
const PICKS := {1:"1-from-5A",2:"2A",3:"3B",4:"4B",5:"5A-red",6:"6A-red",7:"7B",8:"8A",9:"9A"}
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shader := Shader.new()
 shader.code=FileAccess.get_file_as_string(OUTPUT+"selected.gdshader")
 var material := ShaderMaterial.new()
 material.shader=shader
 swatch.material=material
 for item: int in PICKS:
  var size := Vector2i(512,512)
  if item in [2,4,6,8]: size=Vector2i(512,128)
  elif item in [3,9]: size=Vector2i(512,256)
  viewport.size=size*2
  swatch.size=Vector2(viewport.size)
  material.set_shader_parameter("item",item)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var picture := viewport.get_texture().get_image()
  picture.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
  if picture.save_png(OUTPUT+PICKS[item]+".png") != OK:
   quit(1)
   return
  print("SAVED ",PICKS[item]," ",size)
 viewport.free()
 print("Phase 2: nine rebuilt albedos. Current C materials and production untouched.")
 quit()
