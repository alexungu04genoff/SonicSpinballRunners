extends SceneTree
## Matched captures in the normal main game. Each pair keeps the same Act,
## camera, ball and HUD; only the production theme selector changes presentation.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const Filter = preload("res://scripts/retro/retro_filter.gd")
const OUTPUT := "res://test-results/theme-review"
const EXAMPLES := ["decor_terraces", "decor_curve_relay"]
var game: Node
var failures := 0
var captures: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func frames(count := 8) -> void:
 for i in count: await process_frame

func capture(name: String, theme_id: String, framing: String) -> void:
 await frames(12)
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 var path := OUTPUT + "/" + name + ".png"
 if image.save_png(path) != OK:
  failures += 1
  push_error("Cannot save theme capture: " + path)
 captures.append({"path": path, "theme": theme_id, "framing": framing, "act": game.authored_act_path, "act_fingerprint": game.authored_document.fingerprint(), "camera_transform": str(game.presentation.camera.global_transform), "camera_settings": game.presentation.camera_settings.duplicate(true), "ball_position": str(game.ball.position), "filter": game.retro_filter.display_name(), "size": str(image.get_size())})
 print("THEME_CAPTURE | ", path)

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Theme captures require a graphical renderer.")
  quit(1)
  return
 root.size = Vector2i(1440, 1000)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 game = Game.new()
 game.authored_act_path = "res://data/acts/decor_terraces.tres"
 root.add_child(game)
 await frames(20)
 game.retro_filter.set_preset(Filter.Preset.OFF)
 paused = true
 for example: String in EXAMPLES:
  if not game.request_authored_act("res://data/acts/%s.tres" % example):
   failures += 1
   continue
  for i in 120:
   await frames(1)
   if not game.generation_pending: break
  await frames(8)
  for framing: String in ["overview", "follow"]:
   game.presentation.set_camera_follow(framing == "follow")
   for theme_id: String in ["green_hill", "chemical_plant"]:
    if not game.set_theme(theme_id):
     failures += 1
     continue
    await capture("%s-%s-%s-off" % [example, theme_id, framing], theme_id, framing)
   if framing == "follow" and OS.get_cmdline_user_args().has("--retro"):
    game.retro_filter.set_effects([Filter.Preset.N64, Filter.Preset.CRT])
    await capture(example + "-chemical_plant-follow-retro", "chemical_plant", framing)
    game.retro_filter.set_preset(Filter.Preset.OFF)
 var file := FileAccess.open(OUTPUT + "/manifest.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(captures, "  "))
 file.close()
 game.free()
 print("RESULT | Theme captures | %d captures | %d failures" % [captures.size(), failures])
 quit(0 if failures == 0 else 1)
