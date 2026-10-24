extends "res://tests/act_pinball_regression.gd"
## One controlled trajectory: enter a narrow gate, then fan into the wider
## checkpoint chamber. No position or velocity edits occur during the shot.

func run() -> void:
 game = load("res://scenes/playground.tscn").instantiate()
 game.generation_seed = 24
 game.zone_enabled = true
 game.zone_difficulty_override = TableGenerator.Difficulty.HARD
 root.add_child(game)
 await frames(5)
 game.controls.virtual_enabled = true
 game.ring_field.set_physics_process(false)
 var act: Dictionary = game.zone.acts[0]
 check(act.clear_left < act.exit_left and act.clear_right > act.exit_right, "Hard24 incoming checkpoint is wider than its physical score-gate mouth")

 var observer := ZoneRun.new()
 observer.reset(true, game.zone_config, game.layout)
 var inside_x: float = (act.clear_left + act.exit_left) * 0.5
 check(not observer.observe_motion(Vector2(inside_x, act.clear_y + 5), Vector2(inside_x, act.clear_y - 5)), "A locked score target still rejects the wider safe entry line")
 observer.observe_score(observer.targets[0])
 for outside_x: float in [act.clear_left - 1.0, act.clear_right + 1.0]:
  check(not observer.observe_motion(Vector2(outside_x, act.clear_y + 5), Vector2(outside_x, act.clear_y - 5)) and observer.state == ZoneRun.State.PLAYING, "Completion rejects a crossing outside the actual safe chamber span at x%.1f" % outside_x)
 check(observer.observe_motion(Vector2(inside_x, act.clear_y + 5), Vector2(inside_x, act.clear_y - 5)), "Unlocked completion accepts safe chamber space outside the old seam span")

 game.score = game.zone.targets[0]
 game._observe_challenge_score()
 await frames(4)
 check(not game.zone_gates[0].closed and checkpoint_collisions(1, false), "Opening the score gate leaves future recovery geometry retracted")
 var start := Vector2(float(act.exit_left) + 50.0, float(act.exit_y) + 80.0)
 var velocity := Vector2(-180.0, -1500.0)
 var body_identity: int = game.ball.get_instance_id()
 await place_ball(start, velocity)
 var previous: Vector2 = game.ball.position
 var gate_crossing := Vector2.INF
 var line_crossing := Vector2.INF
 for tick in 65:
  await frames(1)
  var current: Vector2 = game.ball.position
  if previous.y >= act.exit_y and current.y < act.exit_y:
   gate_crossing = previous.lerp(current, (act.exit_y - previous.y) / (current.y - previous.y))
  if previous.y >= act.clear_y and current.y < act.clear_y:
   line_crossing = previous.lerp(current, (act.clear_y - previous.y) / (current.y - previous.y))
  previous = current
  if game.zone.state == ZoneRun.State.DRAFT:
   break
 print("OFFSET ENTRY | start=", start, " velocity=", velocity, " gate=", gate_crossing, " clear=", line_crossing, " gate_span=", Vector2(act.exit_left, act.exit_right), " clear_span=", Vector2(act.clear_left, act.clear_right))
 check(gate_crossing.is_finite() and gate_crossing.x > act.exit_left and gate_crossing.x < act.exit_right, "A real upward shot physically enters through the narrower gate")
 check(line_crossing.is_finite() and line_crossing.x < act.exit_left and line_crossing.x >= act.clear_left, "The same shot fans left of the old seam span while staying inside the safe chamber")
 check(game.zone.state == ZoneRun.State.DRAFT and paused and game.zone.completed_acts == 1, "Safe offset arrival starts the mandatory Chao draft")
 if game.zone.state == ZoneRun.State.DRAFT:
  var arrival: Vector2 = game.ball.position
  var momentum: Vector2 = game.ball.linear_velocity
  await frames(6)
  check(game.ball.position == arrival and game.ball.linear_velocity == momentum, "The draft freezes the exact offset arrival trajectory")
  check(game.choose_zone_chao("spring") and game.ball.get_instance_id() == body_identity and game.ball.position == arrival and game.ball.linear_velocity == momentum and not game.ball._teleport_pending, "Reward choice preserves the body and offset-shot momentum")
  await frames(2)
  check(game.zone.active_act == 1 and game.zone_gates[0].closed and checkpoint_collisions(1, true), "Only safe completion activates the next funnel and seals the completed Act")
 paused = false
 game.free()
 await frames(3)
 print("RESULT | Zone offset entry | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
