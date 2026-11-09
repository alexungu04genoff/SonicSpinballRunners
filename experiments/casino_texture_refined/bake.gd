extends SceneTree
## Phase 2: selected albedo only. Production materials and retained C assets stay untouched.
const OUTPUT := "res://experiments/casino_texture_refined/"
const PICKS := {2:"2A",3:"3A",4:"4B",5:"5A",6:"6B",7:"7Cards",8:"8B",9:"9A",10:"10B"}
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
 var cards := Shader.new()
 cards.code = FileAccess.get_file_as_string(OUTPUT + "cards.gdshader")
 var material := ShaderMaterial.new()
 swatch.material = material
 for item in PICKS:
  var size := Vector2i(512,512)
  if item in [2,4,6,8]: size=Vector2i(512,128)
  if item==3: size=Vector2i(512,256)
  material.shader = cards if item==7 else shader
  if item!=7:
   material.set_shader_parameter("item",item)
   material.set_shader_parameter("option",1 if item in [4,6,8,10] else 0)
  viewport.size=size*2
  swatch.size=Vector2(viewport.size)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var image := viewport.get_texture().get_image()
  image.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
  image.save_png(OUTPUT+PICKS[item]+".png")
 print("Selected Casino Night albedos saved. 1C and 11C retained; no maps or game integration.")
 viewport.queue_free()
 quit()
