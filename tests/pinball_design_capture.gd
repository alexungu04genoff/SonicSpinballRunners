extends "res://tests/zone_play_survey.gd"
## Rendered design review fixtures, separate from input-only play surveys.

func capture(label: String) -> void:
 await frames(3)
 await RenderingServer.frame_post_draw
 var path := "res://test-results/pinball-%s.png" % label
 game.view.get_texture().get_image().save_png(path)
 print("PINBALL CAPTURE | ", path)

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("This capture requires a graphical renderer.")
  quit(1)
  return
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.zone_enabled = true
 game.generation_seed = 18
 root.add_child(game)
 await frames(5)
 for seed_value in [18, 23, 41]:
  paused = true
  game.request_generation(seed_value)
  await frames(8)
  game.view_container.stretch = false
  game.view.size = Vector2i(512, 2560)
  game.presentation.set_camera_follow(false)
  game.presentation.set_camera_preset(TablePresentation.CameraPreset.TOP_DOWN)
  await capture("zone-seed-%d" % seed_value)
 paused = true
 game.request_generation(18)
 await frames(8)
 game.view_container.stretch = false
 game.view.size = Vector2i(1280, 900)
 game.presentation.set_camera_preset(TablePresentation.CameraPreset.REAL_PINBALL)
 game.presentation.set_camera_follow(true)
 for act in 3:
  if act > 0:
   # Public progression with prescribed contacts for still-image review only.
   game.score += game.zone.targets[game.zone.active_act]
   game._observe_challenge_score()
   var line: float = game.zone.acts[game.zone.active_act].clear_y
   game.zone.observe_motion(Vector2(400, line + 20), Vector2(400, line - 20))
   game.choose_zone_chao(["spring", "ice"][act - 1])
  paused = false
  game.reset_ball(false)
  await frames(3)
  paused = true
  game.presentation.reset_camera(game.ball.serve_position)
  await capture("act-%d-serve" % (act + 1))
 paused = false
 game.launch_ball()
 await frames(45)
 paused = true
 await capture("act-3-roll-in")
 paused = false
 game.free()
 await frames(3)
 quit(0)
