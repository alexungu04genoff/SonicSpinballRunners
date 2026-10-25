extends SceneTree
## Matched production-game captures. Reference materials never enter saved Acts.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const GreenHill = preload("res://scripts/themes/green_hill_theme.gd")
const OUTPUT := "res://docs/green-hill-textures/"
var game: Node
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count: await process_frame

func reference(name: String, parameters: Dictionary = {}) -> ShaderMaterial:
 var mat := ShaderMaterial.new()
 mat.shader = load("res://tools/texture_sources/green_hill_" + name + ".gdshader")
 for key: String in parameters: mat.set_shader_parameter(key, parameters[key])
 return mat

func run() -> void:
 root.size = Vector2i(1440, 1000)
 game = Game.new()
 game.authored_act_path = "res://data/acts/decor_curve_relay.tres"
 root.add_child(game)
 await frames(20)
 paused = true
 game.retro_filter.set_preset(0)
 # Capture the real world viewport directly, so HUD panels cannot hide borders.
 var document: String = game.authored_document.fingerprint()
 var ball: int = game.ball.get_instance_id()
 for variant: String in ["before", "after"]:
  var theme := GreenHill.new()
  if variant == "before":
   theme.floor_material = reference("grass")
   theme.top_material = reference("grass", {"raised_turf": true})
   theme.side_material = reference("wall")
   theme.cliff_material = reference("cliff")
   theme.floor_border_material = null
   theme.top_border_material = null
  game.presentation.set_theme_definition(theme)
  var started := Time.get_ticks_msec()
  game._rebuild_presentation()
  print("BUILD | ", variant, " | ", Time.get_ticks_msec() - started, " ms")
  game.presentation.set_camera_follow(false)
  await frames(8)
  if game.authored_document.fingerprint() != document or game.ball.get_instance_id() != ball: failures += 1
  var borders: Array = game.presentation.find_children("*Border*", "MeshInstance3D", true, false)
  if variant == "after" and borders.is_empty(): failures += 1
  print("BORDERS | ", variant, " | ", borders.size())
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   if game.retro_filter.world_view.get_texture().get_image().save_png(OUTPUT + "curves-" + variant + ".png") != OK: failures += 1
   # Same unobstructed overhead detail of the top half for contour inspection.
   var camera: Camera3D = game.presentation.camera
   camera.projection = Camera3D.PROJECTION_ORTHOGONAL
   camera.size = 6.5
   var center: Vector3 = game.presentation.map_point(game.presentation.table_bounds.get_center() + Vector2(0, -65))
   camera.position = center + Vector3(0, 10, 0.001)
   camera.look_at(center)
   await frames(5)
   await RenderingServer.frame_post_draw
   if game.retro_filter.world_view.get_texture().get_image().save_png(OUTPUT + "detail-" + variant + ".png") != OK: failures += 1
 game.free()
 print("RESULT | Green Hill scene comparison | %d failures" % failures)
 quit(1 if failures else 0)
