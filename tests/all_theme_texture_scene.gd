extends SceneTree
## Runs the actual game with the same document and state across every registered theme.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const OUTPUT := "res://docs/all-theme-textures/"
var game: Node
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count: await process_frame

func run() -> void:
 root.size = Vector2i(1440, 1000)
 var act := "res://data/acts/decor_terraces.tres"
 var label := "terraces"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--act="):
   act = argument.trim_prefix("--act=")
   label = "local-act"
 var original := FileAccess.get_file_as_bytes(act)
 game = Game.new()
 game.authored_act_path = act
 game.theme_id = "rooftop_run"
 root.add_child(game)
 await frames(20)
 paused = true
 game.retro_filter.set_preset(0)
 var identity: int = game.ball.get_instance_id()
 var document: String = game.authored_document.fingerprint()
 for theme: String in preload("res://scripts/themes/theme_registry.gd").IDS:
  var started := Time.get_ticks_msec()
  if not game.set_theme(theme): failures += 1
  print("THEME BUILD | ", theme, " | ", Time.get_ticks_msec() - started, " ms")
  game.presentation.set_camera_follow(false)
  await frames(8)
  if game.ball.get_instance_id() != identity or game.authored_document.fingerprint() != document: failures += 1
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   if game.retro_filter.world_view.get_texture().get_image().save_png(OUTPUT + label + "-" + theme + ".png") != OK: failures += 1
   var camera: Camera3D = game.presentation.camera
   var target: Vector3 = game.presentation.map_point(game.presentation.table_bounds.get_center() + Vector2(0, 90), 0.15)
   camera.projection = Camera3D.PROJECTION_PERSPECTIVE
   camera.fov = 44
   camera.position = target + Vector3(0.4, 2.0, 3.1)
   camera.look_at(target)
   await frames(8)
   await RenderingServer.frame_post_draw
   if game.retro_filter.world_view.get_texture().get_image().save_png(OUTPUT + label + "-" + theme + "-detail.png") != OK: failures += 1
 if original != FileAccess.get_file_as_bytes(act): failures += 1
 game.free()
 print("RESULT | All-theme texture gameplay review | %d failures" % failures)
 quit(1 if failures else 0)
