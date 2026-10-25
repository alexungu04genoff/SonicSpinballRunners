extends SceneTree
## Review-only overlay on the real authored game. Never changes the Act.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const OUTPUT := "res://test-results/casino-review"
var game: Node
var failures := 0

class Callout extends Node2D:
 var target := Vector2.ZERO
 var number := 1
 var tint := Color.WHITE
 func _draw() -> void:
  draw_line(Vector2.ZERO, target, Color(0.02, 0.03, 0.08), 6.0, true)
  draw_line(Vector2.ZERO, target, tint, 2.0, true)
  draw_circle(target, 4.0, tint)
  draw_circle(Vector2.ZERO, 17.0, Color("080d20"))
  draw_arc(Vector2.ZERO, 17.0, 0, TAU, 32, tint, 2.0, true)
  draw_string(ThemeDB.fallback_font, Vector2(-6, 7), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tint)

func _initialize() -> void:
 call_deferred("run")

func label(parent: Node, text: String, at: Vector2, size: int, color := Color.WHITE) -> Label:
 var result := Label.new()
 result.text = text
 result.position = at
 result.add_theme_font_size_override("font_size", size)
 result.add_theme_color_override("font_color", color)
 parent.add_child(result)
 return result

func prop_point(variant: String, local: Vector3) -> Vector3:
 for prop: Node3D in game.presentation.decor_root.get_children():
  if prop.get_meta("decor_variant") == variant: return prop.to_global(local)
 push_error("The guide Act is missing " + variant)
 failures += 1
 return Vector3.ZERO

func marker(parent: Node, point: Vector3, number: int, offset: Vector2, tint: Color) -> void:
 var projected: Vector2 = game.presentation.camera.unproject_position(point)
 projected = game.view_container.position + projected / Vector2(game.view.size) * game.view_container.size
 var callout := Callout.new()
 callout.position = projected + offset
 callout.target = -offset
 callout.number = number
 callout.tint = tint
 parent.add_child(callout)

func save_capture(name: String) -> Image:
 for i in 10: await process_frame
 await RenderingServer.frame_post_draw
 var picture := root.get_texture().get_image()
 var result := picture.save_png(OUTPUT + "/" + name + ".png")
 if result != OK:
  failures += 1
  push_error(error_string(result))
 return picture

func run() -> void:
 if DisplayServer.get_name() == "headless":
  quit(1)
  return
 root.size = Vector2i(1440, 1000)
 root.content_scale_size = Vector2i(1440, 1000)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 game = Game.new()
 game.authored_act_path = "res://data/acts/decor_terraces.tres"
 game.theme_id = "casino_night"
 root.add_child(game)
 for i in 20: await process_frame
 paused = true
 game.retro_filter.set_preset(0)
 game.presentation.set_camera_follow(false)
 for child: Node in game.get_children():
  if child is CanvasLayer: child.visible = false
 for i in 10: await process_frame
 var overlay := CanvasLayer.new()
 overlay.layer = 120
 root.add_child(overlay)
 var header := ColorRect.new()
 header.color = Color("080d20")
 header.size = Vector2(root.size.x, 66)
 overlay.add_child(header)
 label(overlay, "CASINO NIGHT / WHICH PARTS EMIT LIGHT?", Vector2(28, 15), 28)
 var legend := ColorRect.new()
 legend.color = Color("080d20")
 legend.position.y = root.size.y - 210
 legend.size = Vector2(root.size.x, 210)
 overlay.add_child(legend)
 var warm: OmniLight3D = game.presentation.scenery_root.get_node("CasinoWarmSpill")
 var blue: OmniLight3D = game.presentation.scenery_root.get_node("CasinoBlueSpill")
 var entries := [
  [warm.global_position, Vector2(-70, -70), "1  AMBER CROWN LAMP — real light; illuminates nearby surfaces", Color("ffca70")],
  [blue.global_position, Vector2(80, -65), "2  BLUE CROWN LAMP — real light; illuminates nearby surfaces", Color("69cfff")],
  [prop_point("star_lantern", Vector3(0, 1.3, 0)), Vector2(65, 65), "3  STAR LANTERN — emissive bands, shaft strips and stars", Color("f7a3e9")],
  [prop_point("neon_palm", Vector3(0, 0.77, 0)), Vector2(115, -10), "4  NEON PALM — emissive green branches", Color("68ffc2")],
  [prop_point("reel_cabinet", Vector3(0, 0.42, 0.30)), Vector2(-95, 40), "5  REEL CABINET — emissive amber frame and reel stars", Color("ffca70")],
  [prop_point("star_gateway", Vector3(0, 1.32, 0)), Vector2(-100, -55), "6  STAR GATEWAY — emissive pink border and star row", Color("f7a3e9")],
  [Vector3(3, -0.055, 6), Vector2(-80, 65), "7  LEDGE RIM — broad emissive pink strip", Color("f7a3e9")],
  [Vector3(3.21, -0.33, 6), Vector2(130, 70), "8  WALL PANELS — emissive blue inserts in navy and gold", Color("69cfff")],
 ]
 for i in entries.size():
  var entry: Array = entries[i]
  marker(overlay, entry[0], i + 1, entry[1], entry[3])
  label(overlay, entry[2], Vector2(25 + (i % 2) * 705, root.size.y - 194 + (i / 2) * 37), 17, entry[3])
 label(overlay, "Only 1 and 2 cast local light. Other marked parts glow through emissive materials + bloom. No particle emitters.", Vector2(25, root.size.y - 36), 19)
 await save_capture("emitter-guide")
 overlay.visible = false
 var lit := await save_capture("spill-on")
 warm.visible = false
 blue.visible = false
 var unlit := await save_capture("spill-off")
 var difference := 0.0
 var samples := 0
 for y in range(80, mini(lit.get_height(), 780), 4):
  for x in range(0, lit.get_width(), 4):
   var a := lit.get_pixel(x, y)
   var b := unlit.get_pixel(x, y)
   difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
   samples += 3
 difference /= samples
 print("RESULT | Casino emitters | Local-light RGB mean difference: ", difference)
 game.free()
 overlay.free()
 quit(0 if difference > 0.0001 and failures == 0 else 1)
