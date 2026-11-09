extends SceneTree
## Phase 2: rebuild selected albedo analytically, supersample, then export.
## Does not read Phase 1 bitmaps or write production assets.
const OUTPUT := "res://experiments/sky_texture_choices/refined/"
const IDS := {1:"1A",2:"2B",3:"3B",5:"5A",6:"6A",7:"7B",8:"8A",9:"9B"}
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shader := Shader.new()
 shader.code=FileAccess.get_file_as_string(OUTPUT+"albedo.gdshader")
 var material := ShaderMaterial.new()
 material.shader=shader
 swatch.material=material
 for item: int in IDS:
  var size := Vector2i(512,512)
  if item in [2,6,8]: size=Vector2i(512,128)
  elif item in [3,9]: size=Vector2i(512,256)
  viewport.size=size*2
  swatch.size=Vector2(size*2)
  material.set_shader_parameter("item",item)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var result := viewport.get_texture().get_image()
  result.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
  var error := result.save_png(OUTPUT+IDS[item]+".png")
  if error!=OK:
   quit(1)
   return
  print("REFINED | ",IDS[item]," | ",size)
 quit()
