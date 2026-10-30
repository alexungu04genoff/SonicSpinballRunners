extends SceneTree
const Session = preload("res://scripts/prototype/session.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func frames(count := 3) -> void:
 for i in count: await process_frame

func capture(label: String) -> void:
 if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/score-feedback-%s.png" % label)

func run() -> void:
 var session := Session.new()
 session.settings_path = "user://score-feedback-regression.cfg"
 session.archive_directory = "user://telemetry/runs/_validation/prototype_score_feedback_regression"
 root.add_child(session)
 session.selected_character = "sonic"
 session.sound_enabled = false
 while is_instance_valid(session.setup_menu) and session.setup_menu.checking: await process_frame
 await session.start_run()
 var deadline := Time.get_ticks_msec() + 180000
 while not session.game.started and session.state != "error" and Time.get_ticks_msec() < deadline: await process_frame
 check(session.game.started, "Feedback fixture starts the real prototype")
 if not session.game.started: await session.return_to_menu(); quit(1); return
 var game: Node = session.game
 game.set_physics_process(false)
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.ring_field.set_physics_process(false)
 game.scorecraft.set_physics_process(false)
 var overlay: Control = game.score_overlay
 await frames()
 check(overlay.visible and overlay.displayed_multiplier == 1 and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Base combo uses the white circle and does not intercept input")
 await capture("x1")
 var bumpers: Array[Node2D] = []
 for item: Dictionary in game.active.runtime.objects:
  if item.body.has_meta("bumper"): bumpers.append(item.body)
 check(bumpers.size() >= 2, "Authored fixture has distinct scoring bumpers")
 if bumpers.size() < 2: await session.return_to_menu(); quit(1); return
 check(game.fps_label.text.ends_with(" FPS"), "Compact FPS counter is visible")
 check(game.scorecraft.bumper_can_build_multiplier(bumpers[0]), "Fresh bumpers can build the multiplier")
 check(game.combo_glow.targets.any(func(target): return target.has("body") and target.lit), "Eligible bumpers receive a glow overlay")
 game.ball.position = bumpers[0].global_position + Vector2(0, 20)
 await frames(20)
 game._on_bumper_hit(bumpers[0])
 check(overlay.popups.back().total == 100 and overlay.popups.back().at == bumpers[0].global_position, "Bumper popup uses the accepted amount and the struck bumper's position")
 await frames()
 check(not game.scorecraft.bumper_can_build_multiplier(bumpers[0]), "Used bumper stops glowing until the chain resets")
 check(game.combo_glow.targets.any(func(target): return target.has("body") and target.body.get_ref() == bumpers[0] and not target.lit), "Used bumper overlay is removed")
 check(game.scorecraft.rings_can_build_multiplier(), "Rings become eligible after a fresh bumper")
 check(game.combo_glow.targets.all(func(target): return target.has("body")) and game.presentation.ring_visuals.all(func(mesh): return mesh.material_overlay != game.combo_glow.glow), "Combo-eligible rings never receive eligibility glow")
 game._on_bumper_hit(bumpers[1])
 await frames()
 check(overlay.displayed_multiplier == 2, "A second distinct bumper updates the ball indicator to x2")
 await capture("x2")
 var ring_position: Vector2 = game.ball.position + Vector2(25, 0)
 for i in 3: game._on_ring_collected(ring_position)
 await frames()
 check(overlay.displayed_multiplier == 3, "A completed ring link updates the ball indicator to x3")
 var ring_popup: Dictionary = overlay.popups.back()
 check(ring_popup.kind == "ring" and ring_popup.total == 105 and ring_popup.at == ring_position, "Rapid ring pickups combine exact 30 + 30 + 45 awards at their pickup position")
 await capture("x3")
 game.buddies.choose("wizard_chao")
 game.scorecraft.award_bonuses = game.buddies.modifiers()
 game.active.runtime.mechanics.complete_feature(&"switch_bank", "feedback_fixture", 100)
 check(overlay.popups.back().total == 125, "Feature popup includes its percentage Buddy bonus exactly once")
 var shown := 0
 for popup: Dictionary in overlay.popups: shown += int(popup.total)
 check(shown == game.score and game.score == 530, "Visible popup totals reconcile with the actual score ledger")
 var extra_bumper := Node2D.new()
 game.world.add_child(extra_bumper)
 extra_bumper.position = game.ball.position
 game.scorecraft.award_bumper(extra_bumper)
 game.scorecraft.award_mechanic(&"switch", "goal-readiness", ceili(float(game.act_score_target - game.act_score) / game.scorecraft.multiplier))
 await frames()
 check(overlay.displayed_multiplier == 4 and game.active.runtime.goal_ring.unlocked, "A fresh hit earns red x4 and meeting the target unlocks the goal")
 game.scorecraft.remaining = game.scorecraft.config.combo_window * 0.5
 await frames()
 check(not game.scorecraft.rings_can_build_multiplier() and not game.scorecraft.bumper_can_build_multiplier(extra_bumper), "Multiplier cap disables eligibility glow")
 await capture("x4")
 game.ball.position = game.active.runtime.goal_ring.center + Vector2(50, 0)
 await frames(15)
 await capture("goal-ready")
 extra_bumper.queue_free()
 if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
  root.size = Vector2i(1920, 810)
  await frames(15)
  await capture("wide")
 game.toggle_pause()
 await frames()
 var age: float = overlay.popups.back().age if not overlay.popups.is_empty() else 0.0
 await frames(5)
 check(not overlay.visible and (overlay.popups.is_empty() or overlay.popups.back().age == age), "Pause hides feedback and freezes its lifetime")
 game.toggle_pause()
 await frames()
 game.scorecraft.reset("Expired")
 await frames()
 check(overlay.displayed_multiplier == 1, "Combo reset returns the ball indicator to x1")
 check(game.scorecraft.bumper_can_build_multiplier(bumpers[0]) and game.combo_glow.targets.any(func(target): return target.has("body") and target.lit), "Combo reset restores fresh bumper glow")
 var score_before: int = game.score
 var popup_count: int = overlay.popups.size()
 game._on_traversal_event(&"spring", "feedback_spring", &"used", game.active_scoring_id)
 check(game.score == score_before and overlay.popups.size() == popup_count, "A routing-only spring does not invent a points popup")
 var expiry := Time.get_ticks_msec() + 2000
 while not overlay.popups.is_empty() and Time.get_ticks_msec() < expiry: await process_frame
 check(overlay.popups.is_empty(), "Floating awards expire without retaining UI nodes")
 var original_position: Vector2 = game.ball.position
 for i in 30:
  game.ball.position += Vector2(game.ball.radius * 6.0, 0)
  game._on_mechanic_score(&"spinner_tick", "burst", 5, game.active_scoring_id)
 game.ball.position = original_position
 check(overlay.popups.size() == overlay.MAX_POPUPS and game.score == score_before + 150, "Popup cap discards old visuals without discarding earned points")
 game._on_ball_drained()
 await frames()
 check(not overlay.visible and overlay.popups.is_empty(), "Drain transfer hides the indicator and clears old awards")
 await session.return_to_menu()
 session.free()
 print("RESULT | Prototype score feedback | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
