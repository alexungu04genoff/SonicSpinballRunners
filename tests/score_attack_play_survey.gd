extends SceneTree
## Input-only play diagnostic: normal serve, actual score events, automatic drains.
## No teleports, injected points, or trajectory edits after launch. Not human fun testing.
## --headless --fixed-fps 120 --script res://tests/score_attack_play_survey.gd
## Optional -- --quick (catalogue only), --target=1000, --seed=2, --seconds=120.
var game: Node

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func option(prefix: String, fallback: int) -> int:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with(prefix):
   return int(argument.trim_prefix(prefix))
 return fallback

func trial(difficulty: int, grid_mode: int, trigger: float) -> Dictionary:
 game = load("res://scenes/playground.tscn").instantiate()
 game.generation_seed = option("--seed=", 1)
 game.generation_difficulty = difficulty
 game.generation_grid_mode = grid_mode
 game.score_attack_enabled = true
 game.score_attack_target = option("--target=", ScoreAttack.DEFAULT_TARGET)
 root.add_child(game)
 await frames(5)
 game.controls.virtual_enabled = true
 game.launch_ball()
 var result := {"difficulty": difficulty, "grid_mode": grid_mode, "signature": game.layout.signature, "target": game.score_attack.target, "goal": str(game.score_attack.goal_position), "trigger": trigger, "unlock_seconds": -1.0, "upper_seconds": -1.0, "complete_seconds": -1.0, "score": 0, "rings": 0, "balls": 1, "minimum_y": game.ball.position.y, "strikes": []}
 var cooldown := 0
 var duration := option("--seconds=", 90)
 for tick in duration * 120:
  cooldown = maxi(0, cooldown - 1)
  game.controls.virtual_left = cooldown > 15
  game.controls.virtual_right = cooldown > 15
  if cooldown == 0 and game.ball.linear_velocity.y > 0:
   for flipper: PlaygroundFlipper in game.flippers:
    var nearest := Geometry2D.get_closest_point_to_segment(game.ball.position, flipper.position, flipper.position + Vector2.RIGHT.rotated(flipper.rest_angle()) * flipper.length)
    if game.ball.position.y < flipper.position.y + 15 and nearest.distance_to(game.ball.position) < trigger:
     cooldown = 30
     game.controls.virtual_left = true
     game.controls.virtual_right = true
     break
  # Gentle legal steering aims toward the visible goal only within the top chamber.
  game.controls.virtual_steering = clampf((game.score_attack.goal_position.x - game.ball.position.x) / 100.0, -1.0, 1.0) if game.ball.position.y < 650.0 else 0.0
  await frames(1)
  result.minimum_y = minf(result.minimum_y, game.ball.position.y)
  if result.upper_seconds < 0 and game.ball.position.y < 450:
   result.upper_seconds = float(tick) / 120.0
  if result.unlock_seconds < 0 and game.score_attack.state >= ScoreAttack.State.UNLOCKED:
   result.unlock_seconds = float(tick) / 120.0
  if game.score_attack.state == ScoreAttack.State.COMPLETE:
   result.complete_seconds = float(tick) / 120.0
   break
 result.score = game.score
 result.rings = game.rings_collected
 result.balls = game.ball_number
 for flipper: PlaygroundFlipper in game.flippers:
  result.strikes.append(flipper.strikes)
 if result.complete_seconds >= 0 and DisplayServer.get_name() != "headless":
  await create_timer(0.4).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/score-attack-play-clear.png")
 print("PLAY | ", JSON.stringify(result))
 paused = false
 game.queue_free()
 await frames(3)
 return result

func run() -> void:
 var results: Array[Dictionary] = []
 var modes := [0] if OS.get_cmdline_user_args().has("--quick") else [0, 1, 2]
 for difficulty in 3:
  if option("--difficulty=", difficulty) != difficulty:
   continue
  for grid_mode: int in modes:
   # Alternate timing only when the first policy cannot complete in the sample window.
   for trigger: float in [58.0, 48.0, 42.0]:
    var result := await trial(difficulty, grid_mode, trigger)
    results.append(result)
    if result.complete_seconds >= 0:
     break
 var path := "res://test-results/score-attack-play-%d-seed%d.json" % [option("--target=", ScoreAttack.DEFAULT_TARGET), option("--seed=", 1)]
 var output := FileAccess.open(path, FileAccess.WRITE)
 output.store_string(JSON.stringify(results, " "))
 output.close()
 print("RESULT | Score Attack input-only survey | %d trials | %s" % [results.size(), path])
 quit()
