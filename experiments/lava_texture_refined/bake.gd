extends SceneTree
## Phase 2 only: selected albedos and repeat previews. No production asset writes.
const OUTPUT := "res://experiments/lava_texture_refined/"
const PICKS := {1: "1C", 2: "2A", 3: "3B", 5: "5B", 6: "6B", 7: "7A", 8: "8B", 9: "9B"}
const SOURCE_FLOOR := "res://assets/textures/lava_reef/floor.png"

func _initialize() -> void:
 call_deferred("run")

func repeated(source: Image, count: Vector2i) -> Image:
 var result := Image.create(source.get_width()*count.x, source.get_height()*count.y, false, source.get_format())
 for y in count.y:
  for x in count.x:
   result.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(x,y)*source.get_size())
 return result

func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var swatch := ColorRect.new()
 viewport.add_child(swatch)
 var shader := Shader.new()
 shader.code = FileAccess.get_file_as_string(OUTPUT + "selected.gdshader")
 var material := ShaderMaterial.new()
 material.shader = shader
 var source_floor := Image.new()
 if source_floor.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE_FLOOR)) != OK:
  push_error("Cannot read the current Lava Reef floor PNG")
  quit(1)
  return
 material.set_shader_parameter("current_floor", ImageTexture.create_from_image(source_floor))
 swatch.material = material
 var receipts: Array[Dictionary] = []
 for item: int in PICKS:
  var size := Vector2i(512,512)
  if item in [2,6,8]: size = Vector2i(512,128)
  elif item in [3,9]: size = Vector2i(512,256)
  viewport.size = size*2
  swatch.size = Vector2(viewport.size)
  material.set_shader_parameter("item",item)
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var picture := viewport.get_texture().get_image()
  picture.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
  var id: String = PICKS[item]
  if picture.save_png(OUTPUT+id+".png") != OK:
   quit(1)
   return
  var repeat_count := Vector2i(3,1) if item in [2,6,8] else Vector2i(2,2)
  if repeated(picture,repeat_count).save_png(OUTPUT+id+"-repeat.png") != OK:
   quit(1)
   return
  receipts.append({"id":id,"size":[size.x,size.y],"repeat_count":[repeat_count.x,repeat_count.y],"maps":["albedo"]})
  print("PHASE2 | ",id," | ",size)
 var receipt := FileAccess.open(OUTPUT+"render-receipt.json",FileAccess.WRITE)
 receipt.store_string(JSON.stringify({"phase":2,"integration":false,"unchanged":["10C","11C"],"source_floor":SOURCE_FLOOR,"textures":receipts},"  "))
 receipt.close()
 viewport.free()
 print("Phase 2: eight selected albedos and repeated previews saved. Production unchanged.")
 quit()
