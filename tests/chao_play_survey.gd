extends "res://tests/score_attack_regression.gd"
## Same seed and feedback-input policy; trajectories/score are observations, not
## win-rate or fun assertions. No ball/velocity edits after the normal serve.
func run() -> void:
 var samples: Array[Dictionary] = []
 for profile in 2:
  for id: String in ["none", "ice", "spring", "magnet"]:
   game = load("res://scenes/playground.tscn").instantiate()
   game.generation_seed = 18
   root.add_child(game)
   await frames(4)
   game.tuning.select_profile(profile)
   game.tuning.equip_chao(id)
   game.controls.virtual_enabled = true
   game.launch_ball()
   var sample := {"chao": id, "profile": profile, "seed": 18, "minimum_y": game.ball.position.y, "peak_speed": 0.0, "escaped": false}
   var cooldown := 0
   for tick in 4800:
    cooldown = maxi(0, cooldown - 1)
    game.controls.virtual_left = cooldown > 15
    game.controls.virtual_right = cooldown > 15
    if cooldown == 0 and game.ball.linear_velocity.y > 0:
     for paddle: PlaygroundFlipper in game.flippers:
      var near := Geometry2D.get_closest_point_to_segment(game.ball.position, paddle.position, paddle.tip())
      if game.ball.position.y < paddle.position.y + 15 and near.distance_to(game.ball.position) < 48:
       cooldown = 30
       game.controls.virtual_left = true
       game.controls.virtual_right = true
       break
    game.controls.virtual_steering = 0.5 if (tick / 240) % 2 == 0 else -0.5
    await frames(1)
    sample.minimum_y = minf(sample.minimum_y, game.ball.position.y)
    sample.peak_speed = maxf(sample.peak_speed, game.ball.linear_velocity.length())
    sample.escaped = sample.escaped or game.ball.position.x < -20 or game.ball.position.x > 820 or game.ball.position.y < -20 or not game.ball.position.is_finite()
   sample.score = game.score
   sample.rings = game.rings_collected
   sample.balls = game.ball_number
   sample.strikes = []
   for paddle: PlaygroundFlipper in game.flippers:
    sample.strikes.append(paddle.strikes)
   samples.append(sample)
   print("CHAO PLAY | ", JSON.stringify(sample))
   check(not sample.escaped, "40-second real play stays within side/top bounds: %s / profile %d" % [id, profile])
   game.free()
   await frames(3)
 var output := FileAccess.open("res://test-results/chao-play-survey.json", FileAccess.WRITE)
 output.store_string(JSON.stringify(samples, " "))
 output.close()
 print("RESULT | Chao play | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
