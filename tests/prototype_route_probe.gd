extends SceneTree
## Input-only route survey through the real run. Never teleports or grants score.
const Run = preload("res://scripts/prototype/zone_run.gd")
var game: Node

func _initialize() -> void: call_deferred("run")

func run() -> void:
 game = Run.new()
 var buddy := "bumper_coach"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--buddy="): buddy = argument.trim_prefix("--buddy=")
 game.draft_started.connect(func(_act: Dictionary, offers: Array[Dictionary]):
  var choice: String = offers[0].id
  for offer: Dictionary in offers:
   if offer.id == buddy: choice = buddy
  game.call_deferred("choose_buddy", choice)
 )
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
  var height: float = game.active.document.terrain_bounds().size.y
  var aim_x: float = game.active.document.spawn_position.x
  if game.exit_unlocked: aim_x = (game.active.document.exit_start_x + game.active.document.exit_width * 0.5) * game.active.document.cell_size
  game.controls.virtual_steering = clampf((aim_x - local.x) * 0.04 - game.ball.linear_velocity.x * 0.02, -1.0, 1.0)
  game.controls.virtual_left = local.y > height - 180.0 and frame % 60 < 12
  game.controls.virtual_right = game.controls.virtual_left
  stalled = stalled + 1 if local.y > height - 120.0 else 0
  if stalled > 360:
   print("ROUTE_RETRY | act=", game.active_sequence + 1, " at=", local, " balls=", game.balls_remaining)
   game.controls.reset_requested.emit()
   stalled = 0
  if game.ball.serve_pending and game.respawn_time < 0.0: game.launch_ball()
  if not game.exit_unlocked and game.special_meter >= 100.0 and local.y > 550.0: game.specials.activate()
  if frame % 3600 == 0: print("ROUTE | t=", frame / 120, " act=", game.active_sequence + 1, " score=", game.act_score, " at=", local, " top=", lowest)
  await physics_frame
 var complete: bool = game.finished and game.active_sequence == Run.RunPlan.ACT_COUNT - 1 and game.results.back().cleared
 print("ROUTE_RESULT | won=", complete, " finished=", game.finished, " act=", game.active_sequence + 1, " score=", game.score, " seconds=", game.elapsed, " balls_lost=", game.ball_number - 1)
 await game.prepare_to_close()
 game.free()
 quit(0 if complete else 1)
