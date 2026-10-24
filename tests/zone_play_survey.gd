extends SceneTree
## A genuine input-only Zone witness: ordinary serve, flippers, steering, real
## score callbacks, automatic checkpoint drains and the public draft choice.
## No trajectory edits, teleports or injected score. Fixtures live in regressions.
## --headless --fixed-fps 120 --script res://tests/zone_play_survey.gd
## Options: -- --seed=18 --seconds=240 --grid=0 --trigger=58 --policy=2 --green-hill
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

func steering(tick: int, policy: int) -> float:
 var ball: PlaygroundBall = game.ball
 if game.zone.active_act == 2 and ball.position.y < 650.0 and game.zone.exit_unlocked:
  return clampf((game.zone.acts[2].goal_position.x - ball.position.x) / 100.0, -1.0, 1.0)
 if policy == 0:
  return 0.0
 if policy == 2:
  return 0.5 if (tick / 240) % 2 == 0 else -0.5
 var target := Vector2.INF
 var cost := INF
 for paddle: PlaygroundFlipper in game.flippers:
  if paddle.position.y < ball.position.y - 40.0:
   continue
  var contact := paddle.position + Vector2.RIGHT.rotated(paddle.rest_angle()) * paddle.length * 0.7
  var candidate_cost := maxf(0.0, contact.y - ball.position.y) + absf(contact.x - ball.position.x) * 0.6
  if candidate_cost < cost:
   cost = candidate_cost
   target = contact
 if not target.is_finite():
  return 0.0
 # Start positioning near the apex. Strong upward travel retains its aimed shot.
 if ball.linear_velocity.y < -250.0:
  return 0.0
 return clampf((target.x - ball.position.x) / 120.0, -1.0, 1.0)

func run() -> void:
 var started := Time.get_ticks_usec()
 var scene := "res://experiments/visual_lab/visual_lab.tscn" if OS.get_cmdline_user_args().has("--green-hill") else "res://scenes/playground.tscn"
 game = load(scene).instantiate()
 game.generation_seed = option("--seed=", 18)
 game.generation_grid_mode = option("--grid=", 0)
 game.zone_enabled = true
 game.zone_difficulty_override = option("--difficulty=", -1)
 root.add_child(game)
 await frames(5)
 game.controls.virtual_enabled = true
 game.launch_ball()
 var trigger := float(option("--trigger=", 58))
 var policy := option("--policy=", 2)
 var result := {"seed": game.generation_seed, "grid": game.generation_grid_mode, "signature": game.layout.signature, "targets": game.zone.targets, "trigger": trigger, "policy": policy, "drafts": [], "unlocks": [], "complete_seconds": -1.0, "minimum_y": game.ball.position.y, "escaped": false, "score": 0, "rings": 0, "balls": 1}
 var cooldown := 0
 var seen_unlocks := {}
 var rewards: Array[String] = ["spring", "ice", "magnet"]
 for tick in option("--seconds=", 240) * 120:
  if game.zone.state == ZoneRun.State.DRAFT:
   var reward := rewards[game.zone.active_act]
   var draft := {"act": game.zone.active_act + 1, "seconds": float(tick) / 120.0, "act_score": game.zone.act_score, "total_score": game.score, "position": str(game.ball.position), "velocity": str(game.ball.linear_velocity), "chao": reward}
   result.drafts.append(draft)
   print("ZONE DRAFT | ", JSON.stringify(draft))
   if not game.choose_zone_chao(reward):
    push_error("Zone play witness could not select reward: " + reward)
    break
  if game.zone.state == ZoneRun.State.COMPLETE:
   result.complete_seconds = float(tick) / 120.0
   break
  if game.zone.exit_unlocked and not seen_unlocks.has(game.zone.active_act):
   seen_unlocks[game.zone.active_act] = true
   var unlock := {"act": game.zone.active_act + 1, "seconds": float(tick) / 120.0, "act_score": game.zone.act_score, "position": str(game.ball.position)}
   result.unlocks.append(unlock)
   print("ZONE UNLOCK | ", JSON.stringify(unlock))
  cooldown = maxi(0, cooldown - 1)
  game.controls.virtual_left = cooldown > 15
  game.controls.virtual_right = cooldown > 15
  if cooldown == 0 and game.ball.linear_velocity.y > 0:
   for paddle: PlaygroundFlipper in game.flippers:
    var near := Geometry2D.get_closest_point_to_segment(game.ball.position, paddle.position, paddle.position + Vector2.RIGHT.rotated(paddle.rest_angle()) * paddle.length)
    if game.ball.position.y < paddle.position.y + 15 and near.distance_to(game.ball.position) < trigger:
     cooldown = 30
     game.controls.virtual_left = true
     game.controls.virtual_right = true
     break
  game.controls.virtual_steering = steering(tick, policy)
  await frames(1)
  result.minimum_y = minf(result.minimum_y, game.ball.position.y)
  result.escaped = result.escaped or not game.ball.position.is_finite() or game.ball.position.x < -20.0 or game.ball.position.x > 820.0 or game.ball.position.y < -20.0
 result.score = game.score
 result.rings = game.rings_collected
 result.balls = game.ball_number
 result.completed_acts = game.zone.completed_acts
 result.act_score = game.zone.act_score
 result.chao = game.zone.acquired
 result.wall_seconds = float(Time.get_ticks_usec() - started) / 1000000.0
 result.strikes = []
 for paddle: PlaygroundFlipper in game.flippers:
  result.strikes.append(paddle.strikes)
 if result.complete_seconds >= 0 and DisplayServer.get_name() != "headless":
  await create_timer(0.3).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/zone-play-complete.png")
 var suffix := "-green-hill" if OS.get_cmdline_user_args().has("--green-hill") else ""
 var path := "res://test-results/zone-play-%d-grid%d-policy%d-trigger%d%s.json" % [game.generation_seed, game.generation_grid_mode, policy, int(trigger), suffix]
 var output := FileAccess.open(path, FileAccess.WRITE)
 output.store_string(JSON.stringify(result, " "))
 output.close()
 print("ZONE PLAY | ", JSON.stringify(result))
 print("RESULT | Zone input-only survey | completed=%d/3 | %s" % [game.zone.completed_acts, path])
 paused = false
 game.free()
 await frames(3)
 quit(0 if result.complete_seconds >= 0 and not result.escaped else 1)
