extends SceneTree
const Session = preload("res://scripts/prototype/session.gd")
var session: Control
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func start(practice: bool) -> Node:
 session.practice_mode = practice
 while is_instance_valid(session.setup_menu) and session.setup_menu.checking: await process_frame
 await session.start_run()
 var deadline := Time.get_ticks_msec() + 180000
 while not session.game.started and session.state != "error" and Time.get_ticks_msec() < deadline: await process_frame
 check(session.game.started, "Run starts in %s mode" % ("Practice" if practice else "Challenge"))
 if not session.game.started: return null
 var game: Node = session.game
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.ball.freeze = true
 return game

func live_ball(game: Node) -> void:
 game.ball.serve_pending = false
 game.ball._teleport_pending = false

func finish_transfer(game: Node) -> void:
 var deadline := Time.get_ticks_msec() + 10000
 while is_instance_valid(game.transfer) and Time.get_ticks_msec() < deadline: await process_frame
 check(not is_instance_valid(game.transfer) and game.ball.position.distance_to(game.ball.serve_position) < 1.0, "Transfer arrives at the active authored spawn")
 check(not game.ball.freeze and not game.controls.input_blocked and game.character.visible and game.ball.collision_layer != 0 and game.ball.collision_mask != 0, "Arrival restores presentation, collisions and input")
 game.ball.freeze = true # Keep subsequent injected scoring independent of route physics.
 live_ball(game)

func capture(label: String) -> void:
 if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/transfer-%s.png" % label)

func run() -> void:
 session = Session.new()
 session.settings_path = "user://buddy-budget-regression.cfg"
 var legacy := ConfigFile.new()
 legacy.set_value("challenge_records", "score", 2468)
 legacy.set_value("records", "score", 9999)
 legacy.save(session.settings_path)
 root.add_child(session)
 check(session.best_score == 0 and session.practice_best_score == 0, "Old three-Act records do not become two-Zone completion records")
 session.sound_enabled = false
 var previous_best: int = session.best_score
 var game: Node = await start(false)
 if game == null: await session.return_to_menu(); quit(1); return
 game.controls.reset_requested.emit()
 check(game.balls_remaining == 3, "Retry before launching cannot spend a ball")
 live_ball(game)
 game.controls.reset_requested.emit()
 check(game.balls_remaining == 2 and game.ball_number == 2, "The real retry input spends exactly one Challenge ball")
 game.controls.reset_requested.emit()
 check(game.balls_remaining == 2, "Repeated retry while teleporting cannot spend extra balls")
 await finish_transfer(game)
 game.active.runtime.mechanics.complete_feature(&"switch_bank", "clear", 1000)
 var next: RefCounted = game.resident[1]
 # Find a reproducible draft seed that offers the completion Buddy under test.
 for draft_seed in 100:
  var probe := Session.Run.Buddies.new()
  probe.run_seed = draft_seed
  if probe.offers().any(func(offer): return offer.id == "wizard_chao"):
   game.buddies.run_seed = draft_seed
   break
 var at: Vector2 = game.active.runtime.goal_ring.center
 game._observe_authored_motion(at + Vector2.DOWN, at - Vector2.DOWN)
 session._choose_buddy("wizard_chao")
 check(game.balls_remaining == 3 and game.active_sequence == 1, "Clearing an Act refreshes the budget to three balls")
 await finish_transfer(game)
 game.active.runtime.mechanics.complete_feature(&"switch_bank", "feature", 100)
 check(game.act_score == 125 and game.buddy_contributions.wizard_chao == 25, "An acquired Buddy feeds both score ledgers and contribution tracking")
 for lost in 3:
  game.ball.position = Vector2(game.ball.serve_position.x, game.active.document.red_gutter_bounds().end.y + game.active.plan.offset.y)
  game.ball.linear_velocity = Vector2(300, 800)
  game._on_ball_drained()
  check(game.balls_remaining == 2 - lost, "Drain %d spends one ball" % (lost + 1))
  check(game.ball.freeze and game.ball.linear_velocity == Vector2.ZERO, "Drain stops the ball immediately")
  var stock: int = game.balls_remaining
  game._on_ball_drained()
  check(game.balls_remaining == stock, "Duplicate drain notification cannot spend another ball")
  if lost < 2:
   check(game.ball.collision_layer == 0 and game.ball.collision_mask == 0 and game.controls.input_blocked, "Drain transfer disables collisions and input")
   game.active.runtime.mechanics.complete_feature(&"switch_bank", "during_transfer", 900)
   check(game.act_score == 125 and not game.ring_field.scoring_enabled, "Transfer cannot earn feature or ring points")
   if lost == 0:
    while game.transfer.elapsed < 0.18: await process_frame
    check(game.transfer.proxy.scale.x < 1.0 and game.transfer.proxy.scale.x > 0.0 and not game.character.visible, "Drain displays a shrinking ball without a duplicate character")
    await capture("shrink")
    game.toggle_pause()
    var held_time: float = game.transfer.elapsed
    var held_position: Vector2 = game.ball.position
    for frame in 10: await process_frame
    check(paused and game.transfer.elapsed == held_time and game.ball.position == held_position, "Pause holds the transfer animation and ball")
    game.toggle_pause()
    while is_instance_valid(game.transfer) and game.transfer.elapsed < 0.95: await process_frame
    await capture("return")
   await finish_transfer(game)
   check(game.act_score == 125 and game.scorecraft.award_bonuses.has("wizard_chao"), "Checkpoint retains score and the acquired build")
 check(not is_instance_valid(game.transfer), "Final Challenge drain does not start another respawn")
 check(game.finished and session.state == "results" and not session.last_summary.won and paused, "The third lost ball ends Challenge in a failure result")
 check(session.last_summary.acts.size() == 2 and session.last_summary.acts[0].cleared and not session.last_summary.acts[1].cleared, "Failure retains cleared Acts and includes the unfinished Act")
 check(session.last_summary.score == 1125 and session.last_summary.normal_score == 1100 and session.last_summary.buddy_contributions.wizard_chao == 25, "Build-aware results reconcile base scoring plus Buddy contributions")
 var data = JSON.parse_string(session.run_data_json())
 check(not data.won and data.acts.size() == 2 and data.acts[1].target_ready_time_seconds == null and data.acts[1].goal_touched_time_seconds == null, "Failed run exports its partial Act with unavailable target and goal times")
 check(data.acts[1].final_score == 125 and data.acts[1].final_buddy_score == 25 and data.balls_lost == 4, "Failure telemetry keeps actual points, Buddy contribution and lost balls")
 session._copy_run_data()
 if DisplayServer.get_name() != "headless": check(JSON.parse_string(DisplayServer.clipboard_get()).won == false, "Failure telemetry copies to the OS clipboard")
 check(session.best_score == previous_best, "A failed run cannot replace completed-run records")
 legacy.load(session.settings_path)
 check(legacy.get_value("challenge_records", "score", 0) == 2468 and legacy.get_value("records", "score", 0) == 9999, "Saving the new course preserves earlier Challenge and Practice records")
 game.controls.reset_requested.emit()
 game.active.runtime.mechanics.complete_feature(&"switch_bank", "late", 500)
 check(game.score == 1125 and game.balls_remaining == 0, "Failure rejects retries and late rewards")
 if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
  for i in 5: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/prototype-failure.png")
 await session.return_to_menu()
 game = await start(true)
 if game == null: await session.return_to_menu(); quit(1); return
 live_ball(game)
 game.active.runtime.mechanics.complete_feature(&"switch_bank", "practice_points", 75)
 for lost in 4:
  game._on_ball_drained()
  await finish_transfer(game)
 check(not game.finished and game.score == 75 and game.ball_number == 5, "Practice survives more than three drains and keeps its points")
 # Exercise the real drain detector and physics integration, not only injected events.
 var gutter := Vector2(game.ball.serve_position.x, game.active.document.red_gutter_bounds().end.y + game.active.plan.offset.y + 2.0)
 game.ball.teleport_to(gutter, Vector2(100, 800), false)
 game.ball.freeze = false
 game.set_physics_process(true)
 var deadline := Time.get_ticks_msec() + 10000
 while not is_instance_valid(game.transfer) and Time.get_ticks_msec() < deadline: await physics_frame
 check(is_instance_valid(game.transfer) and game.ball_number == 6 and game.ball.linear_velocity == Vector2.ZERO, "Real drain-zone crossing starts exactly one stopped-ball transfer")
 while (is_instance_valid(game.transfer) or game.ball.serve_pending) and Time.get_ticks_msec() < deadline: await physics_frame
 check(not is_instance_valid(game.transfer) and not game.ball.freeze and not game.ball.serve_pending and not game.ball._teleport_pending, "Physics resumes and automatically launches after transfer arrival")
 game.set_physics_process(false)
 game.ball.freeze = true
 game.controls.reset_requested.emit()
 check(not game.finished and game.ball_number == 7, "Practice also allows unlimited manual retries")
 check(game.buddies.levels.is_empty() and game.buddy_contributions.is_empty(), "Switching modes starts with a fresh build")
 var cancelled_transfer: WeakRef = weakref(game.transfer)
 var cancelled_proxy: WeakRef = weakref(game.transfer.proxy)
 await session.return_to_menu()
 for frame in 3: await process_frame
 check(cancelled_transfer.get_ref() == null and cancelled_proxy.get_ref() == null and not paused and session.state == "menu", "Returning to menu cancels the animation and frees its visual proxy")
 session.free()
 print("RESULT | Prototype budget | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
