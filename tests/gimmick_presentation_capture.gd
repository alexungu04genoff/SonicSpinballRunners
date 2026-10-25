extends "res://tests/authored_gimmick_regression.gd"
## Close inspection of the same authored objects in the main game's theme renderer.
func run() -> void:
 if DisplayServer.get_name() == "headless": quit(0); return
 root.size = Vector2i(1280, 900)
 root.gui_embed_subwindows = true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/gimmick-captures"))
 var act := ActData.new()
 act.title = "Gimmick presentation reference"
 act.grid_size = Vector2i(8, 6)
 act.spawn_position = Vector2(350, 275)
 act.gameplay_objects = [object("one_way_gate", "gate", Vector2(200, 65), {"width": 160.0})]
 for i in 4:
  act.gameplay_objects.append(object("switch_target", "switch_%d" % i, Vector2(100 + i * 65, 140), {"color": ["blue", "red", "yellow", "green"][i]}))
 for i in 3:
  act.gameplay_objects.append(object("spring", "spring_%d" % i, Vector2(110 + i * 90, 225), {"color": ["red", "yellow", "blue"][i]}, [-20.0, 0.0, 20.0][i]))
 var path := "res://test-results/gimmick-gallery.tres"
 if act.save_document(path) != OK: quit(1); return
 game = ObservedGame.new()
 game.authored_act_path = path
 root.add_child(game)
 await frames(5)
 game.presentation.set_camera_follow(false)
 game.presentation.set_camera_preset(TablePresentation.CameraPreset.DRAMATIC_PINBALL)
 game.retro_filter.set_preset(0)
 manager = game.ball.mechanics
 manager.by_id.switch_1.active = true
 manager.by_id.switch_3.active = true
 for theme_id: String in Models.STYLES:
  game.set_theme(theme_id)
  await frames(8)
  await RenderingServer.frame_post_draw
  game.view.get_texture().get_image().save_png("res://docs/gimmick-captures/" + theme_id + ".png")
 game.set_theme("green_hill")
 manager.by_id.gate.open = true
 await frames(8)
 await RenderingServer.frame_post_draw
 game.view.get_texture().get_image().save_png("res://docs/gimmick-captures/open.png")
 game.free()
 await frames(3)
 print("RESULT | Gimmick presentation | Eight themes and open gate captured")
 quit()
