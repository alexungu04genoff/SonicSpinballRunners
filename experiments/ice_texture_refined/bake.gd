extends SceneTree
## Phase 2 selected albedo only. Existing 10C and production bindings stay intact.
const OUTPUT := "res://experiments/ice_texture_refined/"
const PICKS := {1: "1A", 2: "2B", 3: "3A", 5: "5A", 6: "6A", 7: "7B", 8: "8A", 9: "9A", 11: "11A", 12: "12B"}

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var source := FileAccess.get_file_as_string(OUTPUT + "selected.gdshader")
 for item: int in PICKS:
  var size := Vector2i(512, 512)
  if item in [2, 6, 8]: size = Vector2i(512, 128)
  elif item in [3, 9]: size = Vector2i(512, 256)
  elif item == 12: size = Vector2i(1024, 1024)
  viewport.size = size * 2
  swatch.size = Vector2(viewport.size)
  # Specialize the offline export so each program compiles only one pattern.
  var shader := Shader.new()
  shader.code = source.replace("uniform int item = 1;", "const int item = %d;" % item)
  var material := ShaderMaterial.new()
  material.shader = shader
  swatch.material = material
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var texture_image := viewport.get_texture().get_image()
  texture_image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
  var error := texture_image.save_png(OUTPUT + PICKS[item] + ".png")
  if error != OK:
   push_error("Could not save selected Ice Cap color texture: " + str(error))
   quit(1)
   return
  print("Saved ", PICKS[item], " ", size)
 print("Phase 2: 10 selected color textures saved. 10C and production unchanged.")
 viewport.queue_free()
 quit()
