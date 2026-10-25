extends "res://tests/theme_surface_capture.gd"
## Reproducible unlit comparison, plus the actual editable source PNGs.
const Rooftop = preload("res://scripts/themes/rooftop_run_theme.gd")
const REVIEW := "res://docs/rooftop-textures/"

func reference(file: String, parameters: Dictionary = {}) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = load("res://tools/texture_sources/rooftop_" + file + ".gdshader")
 for key: String in parameters: result.set_shader_parameter(key, parameters[key])
 return result

func run() -> void:
 if DisplayServer.get_name() == "headless":
  quit(1)
  return
 root.size = Vector2i(1780, 1100)
 root.content_scale_size = root.size
 var theme := Rooftop.new()
 var before := [reference("paving"), reference("paving", {"raised_surface": true}), reference("masonry"), reference("masonry", {"facade": true, "top_height": 0.0}), reference("ramp", {"base_color": Color("bf7954"), "alternate_color": Color("dba27a"), "surface_kind": 2})]
 var after := [theme.floor_material, theme.top_material, theme.side_material, theme.cliff_material, theme.ramp_materials().deck]
 var canvas := CanvasLayer.new()
 root.add_child(canvas)
 var background := ColorRect.new()
 background.color = Color("101623")
 background.size = Vector2(root.size)
 canvas.add_child(background)
 label(canvas, "ROOFTOP RUN / EDITABLE TEXTURES", Vector2(30, 20), 34)
 label(canvas, "Original shader reference / editable PNGs. Cobblestone floor and contour borders; terracotta tops retained.", Vector2(30, 66), 21)
 for column in 5: label(canvas, HEADINGS[column], Vector2(30 + column * 350, 112), 21)
 for row in 2:
  var y := 158 + row * 250
  label(canvas, "BEFORE / procedural reference" if row == 0 else "AFTER / imported PNG materials", Vector2(30, y), 25)
  var materials: Array = before if row == 0 else after
  for column in 5:
   var container := SubViewportContainer.new()
   container.position = Vector2(30 + column * 350, y + 40)
   container.size = Vector2(320, 175)
   container.stretch = true
   canvas.add_child(container)
   var viewport := SubViewport.new()
   viewport.size = Vector2i(640, 350)
   viewport.own_world_3d = true
   viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
   container.add_child(viewport)
   var stage := Node3D.new()
   viewport.add_child(stage)
   stage.add_child(panel(materials[column], column))
   var camera := Camera3D.new()
   camera.projection = Camera3D.PROJECTION_ORTHOGONAL
   camera.keep_aspect = Camera3D.KEEP_WIDTH
   camera.size = 2.65
   stage.add_child(camera)
   if column in [2, 3]:
    var center := Vector3(0, -0.725 if column == 3 else 0, 0)
    camera.position = center + Vector3(0, 0, 4)
    camera.look_at(center)
   else:
    camera.position = Vector3(0, 4, 0.001)
    camera.look_at(Vector3.ZERO)
   camera.current = true
 label(canvas, "SOURCE PNGs / edit these files to change the game", Vector2(30, 682), 25)
 var names := ["floor", "top", "wall", "facade", "ramp", "floor-border", "top-border"]
 for i in names.size():
  var item := TextureRect.new()
  item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  item.texture = load(Rooftop.TEXTURES + names[i] + ".png")
  item.position = Vector2(30 + i * 250, 730)
  item.size = Vector2(192, 192)
  item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  canvas.add_child(item)
  label(canvas, names[i] + ".png", Vector2(30 + i * 250, 936), 20)
 label(canvas, "Floor border: 12 px   /   Raised-top border: 8 px   /   Open-rail border shrinks to preserve its center", Vector2(30, 1010), 23)
 for i in 15: await process_frame
 await RenderingServer.frame_post_draw
 var error := root.get_texture().get_image().save_png(REVIEW + "materials.png")
 print("RESULT | Rooftop material comparison | ", error)
 canvas.free()
 quit(error)
