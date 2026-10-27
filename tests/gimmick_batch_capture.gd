extends "res://tests/gimmick_batch_regression.gd"
## Original hardware gallery rendered by the live main-game theme presenter.
func run() -> void:
 if DisplayServer.get_name() == "headless": quit(1); return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 root.size = Vector2i(1440, 1000)
 root.gui_embed_subwindows = true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/routing-captures"))
 var act := ActData.new()
 act.title = "Authored Routing Hardware"
 act.grid_size = Vector2i(8, 7)
 act.spawn_position = Vector2(350, 320)
 act.gameplay_objects = [
  object("lane_barrier", "lanes", Vector2(65, 75), {"points": PackedVector2Array([Vector2.ZERO, Vector2(90, 0), Vector2(180, 0), Vector2(270, 0)])}),
  object("diverter", "route", Vector2(120, 175), {"length": 110.0}),
  object("dash_panel", "dash", Vector2(285, 175), {"width": 70.0}, -35.0),
 ]
 for i in 4:
  act.gameplay_objects.append(object("wall_switch", "wall_%d" % i, Vector2(80 + i * 80, 285), {"color": ["blue", "red", "yellow", "green"][i]}, 180.0))
 # Mounting ledges align to each authored wall face.
 act.placements = []
 for x in [55, 135, 215, 295]:
  var wall := {"shape_id": "composite", "base_size": Vector2i(1, 1), "anchor": Vector2i.ZERO, "quarter_turns": 0, "flip_h": false, "flip_v": false,
   "composite_version": 1, "smoothing_strength": 0.0, "outline": PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.16), Vector2(0, 0.16)])}
  preload("res://scripts/act_editor/terrain_shapes.gd").set_placement_position(wall, Vector2(x, 277) / 50.0)
  act.placements.append(wall)
 var path := "res://test-results/routing-gallery.tres"
 if act.save_document(path) != OK: quit(1); return
 game = ObservedGame.new()
 game.authored_act_path = path
 root.add_child(game)
 await frames(5)
 game.presentation.set_camera_follow(false)
 game.presentation.set_camera_preset(TablePresentation.CameraPreset.DRAMATIC_PINBALL)
 game.retro_filter.set_preset(0)
 manager = game.ball.mechanics
 manager.by_id.lanes.lanes[0].lit = true
 manager.by_id.lanes.lanes[2].lit = true
 manager.by_id.wall_1.active = true
 manager.by_id.wall_3.active = true
 for theme: String in Models.STYLES:
  game.set_theme(theme)
  await frames(8)
  await RenderingServer.frame_post_draw
  game.view.get_texture().get_image().save_png("res://docs/routing-captures/" + theme + ".png")
 game.set_theme("green_hill")
 manager.by_id.lanes.complete = true
 manager.by_id.lanes.cooldown = 10.0
 manager.by_id.route.state = "b"
 manager.by_id.dash.pulse = 1.0
 await frames(8)
 await RenderingServer.frame_post_draw
 game.view.get_texture().get_image().save_png("res://docs/routing-captures/complete.png")
 game.free()
 print("RESULT | Routing gallery | Eight themes and completed lane state captured")
 quit(0)
