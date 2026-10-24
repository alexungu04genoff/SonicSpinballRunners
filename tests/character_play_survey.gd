extends "res://tests/zone_play_survey.gd"
## Identical seed and input policy for both characters. No score, meter, position
## or velocity injection. Specials activate only from ordinary earned charge.
## -- --seconds=180 --grid=0 --mode=2 [--green-hill]

func run() -> void:
 var results: Array[Dictionary] = []
 var mode := option("--mode=", 2)
 var graphical := OS.get_cmdline_user_args().has("--green-hill")
 for id: String in ["sonic", "tails"]:
  game = load("res://experiments/visual_lab/visual_lab.tscn" if graphical else "res://scenes/playground.tscn").instantiate()
  game.character_id = id
  game.generation_seed = option("--seed=", 18)
  game.generation_grid_mode = option("--grid=", 0)
  game.generation_difficulty = option("--difficulty=", TableGenerator.Difficulty.EASY)
  game.zone_difficulty_override = option("--difficulty=", -1)
  game.zone_enabled = mode == 2
  game.score_attack_enabled = mode == 1
  root.add_child(game)
  await frames(5)
  var result := {"character": id, "seed": game.generation_seed, "grid": game.generation_grid_mode, "mode": mode, "seconds": 0.0, "activations": 0, "homing_hits": 0, "first_ready": -1.0, "minimum_y": game.ball.position.y, "score": 0, "rings": 0, "balls": 0, "acts": 0, "complete": false, "escaped": false}
  game.specials.special_activated.connect(func(_id: String): result.activations += 1)
  game.specials.special_hit.connect(func(_target: Node2D, _multiplier: int): result.homing_hits += 1)
  game.controls.virtual_enabled = true
  game.launch_ball()
  var cooldown := 0
  var captured := false
  for tick in option("--seconds=", 180) * 120:
   result.seconds = float(tick) / 120.0
   if game.zone.state == ZoneRun.State.DRAFT:
    game.choose_zone_chao(["spring", "ice", "magnet"][game.zone.active_act])
   if game.zone.state == ZoneRun.State.COMPLETE or game.score_attack.state == ScoreAttack.State.COMPLETE:
    result.complete = true
    break
   cooldown = maxi(0, cooldown - 1)
   game.controls.virtual_left = cooldown > 15
   game.controls.virtual_right = cooldown > 15
   if cooldown == 0 and game.ball.linear_velocity.y > 0:
    for paddle: PlaygroundFlipper in game.flippers:
     var near := Geometry2D.get_closest_point_to_segment(game.ball.position, paddle.position, paddle.position + Vector2.RIGHT.rotated(paddle.rest_angle()) * paddle.length)
     if game.ball.position.y < paddle.position.y + 15 and near.distance_to(game.ball.position) < 58:
      cooldown = 30
      game.controls.virtual_left = true
      game.controls.virtual_right = true
      break
   game.controls.virtual_steering = steering(tick, 2)
   if game.specials.ready_to_use() and game.specials.can_use():
    if result.first_ready < 0:
     result.first_ready = result.seconds
    if (id == "sonic" and is_instance_valid(game.specials.target)) or (id == "tails" and game.ball.linear_velocity.y > 300):
     game.controls.special_requested.emit()
   await frames(1)
   if graphical and not captured and (game.specials.homing_remaining > 0 or game.specials.flight_remaining > 0) and DisplayServer.get_name() != "headless":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://test-results/character-play-%s.png" % id)
    captured = true
   result.minimum_y = minf(result.minimum_y, game.ball.position.y)
   result.escaped = result.escaped or not game.ball.position.is_finite() or game.ball.position.x < -20 or game.ball.position.x > 820 or game.ball.position.y < -20
  result.score = game.score
  result.difficulty = game.generation_difficulty
  result.rings = game.rings_collected
  result.balls = game.ball_number
  result.acts = game.zone.completed_acts
  results.append(result)
  print("CHARACTER PLAY | ", JSON.stringify(result))
  paused = false
  game.free()
  await frames(4)
 var path := "res://test-results/character-play-seed%d-tier%d-mode%d-grid%d%s.json" % [option("--seed=", 18), option("--difficulty=", -1), mode, option("--grid=", 0), "-green-hill" if graphical else ""]
 var output := FileAccess.open(path, FileAccess.WRITE)
 output.store_string(JSON.stringify(results, " "))
 output.close()
 quit(1 if results.any(func(item: Dictionary): return item.escaped or item.activations == 0) else 0)
