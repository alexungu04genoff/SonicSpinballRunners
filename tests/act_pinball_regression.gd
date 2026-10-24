extends "res://tests/score_attack_regression.gd"
## Controlled starting trajectories isolate physical recovery, drains and passage.
## Positions, velocities and target scores are fixtures, not an input-only playthrough.
var release_events: Array[Vector2] = []

func place_ball(at: Vector2, velocity: Vector2) -> void:
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 game.controls.virtual_steering = 0.0
 game.ball.teleport_to(at, velocity)
 game.previous_goal_position = at
 game._goal_motion_ready = false
 await frames(2)

func bottom_paddles(act_index: int) -> Array[PlaygroundFlipper]:
 var result: Array[PlaygroundFlipper] = []
 var bottom: TableChunk = game.chunks[game.zone.acts[act_index].chunk_indices.back()]
 for placement: Dictionary in bottom.data.world_flippers():
  for paddle: PlaygroundFlipper in game.flippers:
   if paddle.position.is_equal_approx(placement.position):
    result.append(paddle)
 return result

func checkpoint_collisions(act_index: int, expected: bool) -> bool:
 var bottom: TableChunk = game.chunks[game.zone.acts[act_index].chunk_indices.back()]
 for descriptor: Dictionary in bottom.descriptors:
  if descriptor.get("checkpoint_only", false) and (descriptor.body.collision_layer != 0) != expected:
   return false
 for paddle: PlaygroundFlipper in bottom_paddles(act_index):
  if paddle.enabled != expected or (paddle.collision_layer != 0) != expected:
   return false
 return true

func test_recovery(act_index: int, paddle: PlaygroundFlipper) -> void:
 game.reset_ball(false)
 await frames(5)
 var contact := paddle.position + Vector2.RIGHT.rotated(paddle.rest_angle()) * paddle.length * 0.65
 var initial_strikes := paddle.strikes
 var initial_ball: int = game.ball_number
 await place_ball(contact + Vector2(0, -34), Vector2(0, 400))
 game.controls.virtual_left = paddle.side > 0.0
 game.controls.virtual_right = paddle.side < 0.0
 var upward := false
 for tick in 16:
  await frames(1)
  upward = upward or game.ball.linear_velocity.y < -300.0
 check(paddle.strikes > initial_strikes and upward and game.ball_number == initial_ball, "Act %d %s flipper recovers a falling ball with a real upward strike" % [act_index + 1, "left" if paddle.side > 0 else "right"])
 game.controls.virtual_left = false
 game.controls.virtual_right = false

func test_drain(act_index: int) -> void:
 game.reset_ball(false)
 await frames(5)
 var total: int = game.score
 var build: Array = game.tuning.build_ids.duplicate()
 var initial_ball: int = game.ball_number
 var drain: Vector2 = game.zone.acts[act_index].drain
 var expected_sensor: PlayfieldDrain
 for sensor: PlayfieldDrain in game.drains:
  if sensor.bounds.grow(10).has_point(drain):
   expected_sensor = sensor
 check(expected_sensor != null and expected_sensor.active, "Act %d owns an active central 2D drain sensor" % (act_index + 1))
 # Release above the gap between the resting tips, with no flipper inputs.
 await place_ball(drain - Vector2(0, 150), Vector2(0, 500))
 var furthest_y: float = game.ball.position.y
 for tick in 50:
  await frames(1)
  furthest_y = maxf(furthest_y, game.ball.position.y)
  if game.respawn_time >= 0.0:
   break
 check(game.respawn_time > 0.0 and game.ball_number == initial_ball + 1 and game.ball.position.y < game.zone.acts[act_index].bounds.end.y, "Act %d missed shot passes the paddle gap and enters its drain before the old boundary" % (act_index + 1))
 check(game.zone.active_act == act_index and game.zone.completed_acts == act_index and game.score == total and game.tuning.build_ids == build and game.scorecraft.chain == 0, "Act %d drain retains score, completed Acts and Chao while clearing combo" % (act_index + 1))
 if act_index > 0:
  check(furthest_y < game.zone.acts[act_index].bounds.end.y and game.zone_gates[act_index - 1].closed, "Act %d drain cannot fall into the completed Act" % (act_index + 1))
 await frames(115)
 check(game.respawn_time < 0.0 and game.ball.serve_position == game.zone.acts[act_index].entry and not game.ball.serve_pending and game.zone.active_act == act_index, "Act %d checkpoint retry releases from its generated serve" % (act_index + 1))

func enter_next_act(act_index: int) -> void:
 game.reset_ball(false)
 game.score += game.zone.targets[act_index]
 game._observe_challenge_score()
 await frames(5)
 var act: Dictionary = game.zone.acts[act_index]
 var gate_x: float = (act.exit_left + act.exit_right) * 0.5
 check(checkpoint_collisions(act_index + 1, false), "Act %d future funnel and paddles remain collisionless for entry" % (act_index + 2))
 await place_ball(Vector2(gate_x, act.exit_y + 45), Vector2(0, -350))
 var entered := false
 var returned := false
 for tick in 150:
  await frames(1)
  entered = entered or game.ball.position.y < act.exit_y
  if entered and game.ball.position.y > act.exit_y and game.ball.linear_velocity.y > 0:
   returned = true
   break
 check(entered and returned and game.zone.active_act == act_index and game.zone.state == ZoneRun.State.PLAYING, "Act %d weak upward entry returns without completing or sealing the next funnel" % (act_index + 1))
 await place_ball(Vector2(gate_x, act.exit_y + 90), Vector2(0, -1700))
 var identity: int = game.ball.get_instance_id()
 for tick in 65:
  await frames(1)
  if game.zone.state == ZoneRun.State.DRAFT:
   break
 check(game.zone.state == ZoneRun.State.DRAFT and paused and game.ball.position.y < act.clear_y, "Act %d physical upward shot clears the whole future funnel before drafting" % (act_index + 1))
 var at_draft: Vector2 = game.ball.position
 var velocity: Vector2 = game.ball.linear_velocity
 await frames(8)
 check(game.ball.position == at_draft and game.ball.linear_velocity == velocity, "Act %d draft freezes the arriving trajectory" % (act_index + 1))
 var reward := "spring" if act_index == 0 else "ice"
 check(game.choose_zone_chao(reward) and game.ball.position == at_draft and game.ball.linear_velocity == velocity and game.ball.get_instance_id() == identity and not game.ball._teleport_pending, "Act %d reward preserves body and momentum while setting the next checkpoint" % (act_index + 1))
 await frames(2)
 check(checkpoint_collisions(act_index + 1, true) and game.zone_gates[act_index].collision_layer != 0 and game.zone.act_score == 0, "Act %d funnel activates and previous gate seals only after safe entry" % (act_index + 2))

func run() -> void:
 game = load("res://scenes/playground.tscn").instantiate()
 game.generation_seed = 18
 game.zone_enabled = true
 root.add_child(game)
 await frames(5)
 game.controls.virtual_enabled = true
 # Isolate pinball geometry from unrelated ring pickups during trajectory fixtures.
 game.ring_field.set_physics_process(false)
 var serve: Vector2 = game.ball.serve_position
 await frames(30)
 check(game.ball.serve_pending and game.ball.position.is_equal_approx(serve) and game.ball.linear_velocity.is_zero_approx(), "Character waits visibly at the generated serve without drifting")
 game.ball.launched.connect(func(impulse: Vector2): release_events.append(impulse))
 game.launch_ball()
 game.launch_ball()
 check(game.ball.release_pending and not game.ball._teleport_pending and game.ball.position.is_equal_approx(serve), "Launch queues one gravity release without teleporting or setting velocity")
 await frames(8)
 check(release_events == [Vector2.ZERO] and not game.ball.serve_pending and game.ball.position.y > serve.y and game.ball.linear_velocity.y > 0.0 and game.ball.linear_velocity.length() < 200.0, "One release starts ordinary downward gravity without a launch impulse")
 for act_index in 3:
  for paddle: PlaygroundFlipper in bottom_paddles(act_index):
   await test_recovery(act_index, paddle)
  await test_drain(act_index)
  if act_index < 2:
   await enter_next_act(act_index)
 var signature: String = game.layout.signature
 paused = true
 check(game.request_generation(game.generation_seed), "Same-seed replay is accepted after all checkpoint geometry activated")
 await frames(8)
 check(game.layout.signature == signature and game.zone.active_act == 0 and game.zone.completed_acts == 0 and game.tuning.build_ids.is_empty() and game.score == 0 and game.ball.serve_pending and not game.ball.release_pending, "Replay clears progress, score, Chao and pending release on identical geometry")
 check(checkpoint_collisions(1, false) and checkpoint_collisions(2, false) and game.drains.size() == 3 and game.drains.filter(func(sensor: PlayfieldDrain): return sensor.active).size() == 1, "Replay restores future open entrances and exactly one active drain without stale bodies")
 paused = false
 game.free()
 await frames(3)
 print("RESULT | Act pinball | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
