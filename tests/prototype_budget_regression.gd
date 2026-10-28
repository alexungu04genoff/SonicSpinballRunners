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

func run() -> void:
 session = Session.new()
 session.settings_path = "user://buddy-budget-regression.cfg"
 root.add_child(session)
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
 live_ball(game)
 game.active.runtime.mechanics.complete_feature(&"switch_bank", "clear", 1000)
 var next: RefCounted = game.resident[1]
 var at: Vector2 = next.plan.offset + Vector2(next.document.spawn_position.x, next.document.activation_y)
 game._observe_authored_motion(at + Vector2.DOWN, at - Vector2.DOWN)
 session._choose_buddy("feature_fox")
 check(game.balls_remaining == 3 and game.active_sequence == 1, "Clearing an Act refreshes the budget to three balls")
 game.active.runtime.mechanics.complete_feature(&"switch_bank", "feature", 100)
 check(game.act_score == 350 and game.buddy_contributions.feature_fox == 250, "An acquired Buddy feeds both score ledgers and contribution tracking")
 for lost in 3:
  game._on_ball_drained()
  check(game.balls_remaining == 2 - lost, "Drain %d spends one ball" % (lost + 1))
  var stock: int = game.balls_remaining
  game._on_ball_drained()
  check(game.balls_remaining == stock, "Duplicate drain notification cannot spend another ball")
  if lost < 2:
   game.reset_ball(false)
   live_ball(game)
   check(game.act_score == 350 and game.scorecraft.award_bonuses.has("feature_fox"), "Checkpoint retains score and the acquired build")
 check(game.finished and session.state == "results" and not session.last_summary.won and paused, "The third lost ball ends Challenge in a failure result")
 check(session.last_summary.acts.size() == 2 and session.last_summary.acts[0].cleared and not session.last_summary.acts[1].cleared, "Failure retains cleared Acts and includes the unfinished Act")
 check(session.last_summary.score == 1350 and session.last_summary.normal_score == 1100 and session.last_summary.buddy_contributions.feature_fox == 250, "Build-aware results reconcile base scoring plus Buddy contributions")
 check(session.best_score == previous_best, "A failed run cannot replace completed-run records")
 game.controls.reset_requested.emit()
 game.active.runtime.mechanics.complete_feature(&"switch_bank", "late", 500)
 check(game.score == 1350 and game.balls_remaining == 0, "Failure rejects retries and late rewards")
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
  game.reset_ball(false)
  live_ball(game)
 check(not game.finished and game.score == 75 and game.ball_number == 5, "Practice survives more than three drains and keeps its points")
 game.controls.reset_requested.emit()
 check(not game.finished and game.ball_number == 6, "Practice also allows unlimited manual retries")
 check(game.buddies.levels.is_empty() and game.buddy_contributions.is_empty(), "Switching modes starts with a fresh build")
 await session.return_to_menu()
 session.free()
 print("RESULT | Prototype budget | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
