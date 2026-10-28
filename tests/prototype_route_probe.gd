extends SceneTree
## Input-only route survey through the real run. Never teleports or grants score.
const Run = preload("res://scripts/prototype/zone_run.gd")
var game: Node

func _initialize() -> void: call_deferred("run")

func run() -> void:
 game = Run.new()
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 180000
 while not game.started and Time.get_ticks_msec() < deadline: await process_frame
 if not game.started: quit(1); return
 game.controls.virtual_enabled = true
 game.launch_ball()
 var lowest := 1000.0
 var stalled := 0
 for frame in 120 * 360:
  if game.finished: break
  var local: Vector2 = game.ball.position - Vector2(game.active.plan.offset)
  lowest = minf(lowest, local.y)
  var aim_x := 300.0
  if game.active_sequence == 1 and game.exit_unlocked and local.y > 500.0 and local.y < 820.0: aim_x = 170.0
  game.controls.virtual_steering = clampf((aim_x - local.x) * 0.04 - game.ball.linear_velocity.x * 0.02, -1.0, 1.0)
  game.controls.virtual_left = local.y > 820.0 and frame % 60 < 12
  game.controls.virtual_right = game.controls.virtual_left
  stalled = stalled + 1 if local.y > 880.0 else 0
  if stalled > 360:
   game.controls.reset_requested.emit()
   stalled = 0
  if game.ball.serve_pending and game.respawn_time < 0.0: game.launch_ball()
  if game.special_meter >= 100.0 and local.y > 550.0: game.specials.activate()
  if frame % 3600 == 0: print("ROUTE | t=", frame / 120, " act=", game.active_sequence + 1, " score=", game.act_score, " at=", local, " top=", lowest)
  await physics_frame
 print("ROUTE_RESULT | finished=", game.finished, " act=", game.active_sequence + 1, " score=", game.score, " seconds=", game.elapsed, " drains=", game.ball_number - 1)
 var complete: bool = game.finished
 await game.prepare_to_close()
 game.free()
 quit(0 if complete else 1)
