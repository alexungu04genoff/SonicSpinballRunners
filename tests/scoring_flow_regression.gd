extends "res://tests/authored_gimmick_regression.gd"
## Real main-game contacts, traversal events, fixed awards and physical score exit.
const SCORING_PATH := "res://test-results/scoring-flow.tres"

func fixture() -> Resource:
 var act := ActData.new()
 act.title = "Scoring Flow Regression"
 act.grid_size = Vector2i(20, 20)
 act.spawn_position = Vector2(500, 900)
 act.exit_start_x = 9
 act.exit_width = 2
 act.score_target = 1000
 act.gameplay_objects = [
  object("round_bumper", "bumper_a", Vector2(100, 800)),
  object("round_bumper", "bumper_b", Vector2(250, 800)),
  object("spring", "spring", Vector2(150, 600), {"launch_strength": 600.0}),
  object("dash_panel", "dash", Vector2(350, 600), {"boost_strength": 400.0}),
  object("elevated_rail", "rail", Vector2(500, 500), {"points": PackedVector2Array([Vector2.ZERO, Vector2(0, -100), Vector2(150, -100), Vector2(150, 0)]), "width": 60.0, "drag": 0.0}),
 ]
 return act

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 root.gui_embed_subwindows = true
 var document := fixture()
 check(document.validation_errors().is_empty() and document.save_document(SCORING_PATH) == OK, "Scored authored fixture saves through normal authoring")
 game = ObservedGame.new()
 game.authored_act_path = SCORING_PATH
 root.add_child(game)
 await frames(8)
 check(game.playfield.source == "authored", "Scoring fixture runs in actual main game", game.last_source_error)
 if game.playfield.source != "authored": game.free(); quit(1); return
 manager = game.ball.mechanics
 game.controls.virtual_enabled = true
 game.scorecraft.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.tuning.effective.gravity_scale = 0.0
 check(game.act_score == 0 and game.act_score_target == 1000 and not game.exit_unlocked and is_instance_valid(game._score_exit), "Opt-in target starts a separate Act ledger and physical locked exit")
 var barrier_id: int = game._score_exit.get_instance_id()
 game.set_theme("chemical_plant")
 await frames(2)
 var feedback_roots: Array = game.presentation.get_children().filter(func(child): return str(child.name).begins_with("ActScoringFeedback"))
 check(feedback_roots.size() == 1 and game._score_exit.get_instance_id() == barrier_id and not game.exit_unlocked, "Theme reskin preserves one feedback root and the same locked physical exit")
 await move_in_run(Vector2(500, 80), Vector2(0, -16000))
 await frames(3)
 check(game.ball.position.y > 0.0 and game.authored_exit_count == 0, "Score exit blocks a single-step high-speed upward shot", str(game.ball.position))
 await _traversal_checks()
 await _rail_checks()
 await _award_and_lifecycle_checks()
 game.free()
 await frames(3)
 print("RESULT | Scoring flow | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func _spring_shot() -> void:
 await move_in_run(Vector2(800, 700), Vector2.ZERO)
 await frames(20)
 await move_in_run(Vector2(150, 560), Vector2(0, 900))
 await frames(5)

func _dash_shot() -> void:
 await move_in_run(Vector2(800, 700), Vector2.ZERO)
 await frames(25)
 await move_in_run(Vector2(350, 650), Vector2(0, -900))
 await frames(6)

func _traversal_checks() -> void:
 await _spring_shot()
 await _dash_shot()
 check(game.score == 0 and game.scorecraft.chain == 0 and game.special_meter == 0, "Physical spring and dash cannot start combos, award points or charge specials")
 await move_in_run(Vector2(60, 800), Vector2(900, 0))
 await frames(8)
 check(game.score == 100 and game.act_score == 100 and game.scorecraft.chain == 1, "Physical bumper starts shared score and Act score together")
 var meter: float = game.special_meter
 game.scorecraft._physics_process(2.0)
 await _spring_shot()
 check(game.scorecraft.remaining == 3.0 and game.scorecraft.multiplier == 1 and game.score == 100 and game.special_meter == meter, "First spring launch refreshes only the active combo window")
 game.scorecraft._physics_process(2.2)
 var remaining: float = game.scorecraft.remaining
 await _spring_shot()
 check(game.scorecraft.remaining == remaining and game.score == 100, "Same spring cannot farm refresh within one chain")
 await _dash_shot()
 check(game.scorecraft.remaining == 3.0 and game.scorecraft.chain == 1 and game.special_meter == meter, "First dash crossing refreshes combo without links or meter")
 game.scorecraft._physics_process(2.2)
 remaining = game.scorecraft.remaining
 await _dash_shot()
 check(game.scorecraft.remaining == remaining, "Same dash cannot farm refresh within one chain")
 game.scorecraft._physics_process(remaining)
 await move_in_run(Vector2(60, 800), Vector2(900, 0))
 await frames(8)
 game.scorecraft._physics_process(2.0)
 await _spring_shot()
 check(game.scorecraft.chain == 1 and game.scorecraft.remaining == 3.0, "Expired chain makes the same spring eligible again")

func _enter_rail() -> void:
 await move_in_run(Vector2(500, 525), Vector2(0, -900))
 for i in 12:
  if game.ball.on_ramp: break
  await frames(1)

func _rail_checks() -> void:
 game.scorecraft.remaining = 1.0
 await _enter_rail()
 var points: int = game.score
 check(game.ball.on_ramp and not game.scorecraft.protected_rail.is_empty(), "Real rail capture begins protection for existing combo")
 game.scorecraft._physics_process(4.0)
 check(game.scorecraft.remaining == 1.0 and game.scorecraft.rail_protection_remaining == 1.0, "Rail ride pauses decay within five-second budget")
 game.scorecraft._physics_process(1.5)
 check(game.scorecraft.remaining == 0.5 and game.scorecraft.rail_protection_remaining == 0.0, "Elapsed ride budget resumes ordinary combo decay")
 game.scorecraft._physics_process(0.5)
 check(game.scorecraft.chain == 0 and game.score == points, "Stalled rail cannot preserve combo indefinitely or award points")
 game.reset_ball(false)
 await frames(2)
 check(not game.ball.on_ramp and game.scorecraft.protected_rail.is_empty(), "Reset cancels physical ride and Scorecraft protection")
 await move_in_run(Vector2(60, 800), Vector2(900, 0))
 await frames(8)
 game.scorecraft.remaining = 1.0
 await _enter_rail()
 for i in 160:
  if not game.ball.on_ramp: break
  await frames(1)
 check(not game.ball.on_ramp and game.scorecraft.protected_rail.is_empty(), "Normal rail departure clears protection through actual exit event")
 game.scorecraft._physics_process(0.25)
 check(game.scorecraft.remaining == 2.75, "Completed rail refreshes the active combo before ordinary decay resumes")

func _award_and_lifecycle_checks() -> void:
 await move_in_run(Vector2(800, 700), Vector2.ZERO)
 var before: int = game.score
 var meter: float = game.special_meter
 var chain: int = game.scorecraft.chain
 var remaining: float = game.scorecraft.remaining
 var position: Vector2 = game.ball.position
 for feature: Array in [[&"switch_bank", 500], [&"spinner_goal", 300], [&"lane_set", 750]]:
  manager.complete_feature(feature[0], "fixture_feature", feature[1])
 check(game.score - before == 1550 and game.act_score == game.score, "Fixed feature events enter both ledgers exactly once")
 check(game.scorecraft.chain >= chain and game.scorecraft.chain == game.scorecraft.multiplier and game.scorecraft.remaining == 3.0 and game.special_meter == meter, "Distinct feature completions build visible tiers without charging Special")
 check(game.exit_unlocked and game.ball.position == position, "Target award unlocks exit without moving the authoritative ball")
 var sum := 0
 for value: int in game.act_score_breakdown.values(): sum += value
 check(sum == game.act_score, "Actual category awards sum exactly to the Act score")
 await frames(2)
 await move_in_run(Vector2(500, 80), Vector2(0, -16000))
 await frames(3)
 check(game.ball.position.y < 0.0 and game.authored_exit_count > 0, "Unlocked exit requires and allows physical crossing")
 var total: int = game.score
 var act_total: int = game.act_score
 game.reset_ball(false)
 await frames(2)
 check(game.score == total and game.act_score == act_total and game.exit_unlocked and game.scorecraft.chain == 0, "Checkpoint reset preserves earned Act score and unlocked exit but clears combo")
 var next_document: Resource = fixture()
 next_document.score_target = 200
 game._activate_scoring_context(next_document, game.authored_runtime, "next_scoring_act")
 check(game.score == total and game.act_score == 0 and not game.exit_unlocked and game.act_score_breakdown.is_empty(), "New Act activation preserves total score and resets local target baseline")
 game.scored_progression_enabled = false
 game._activate_scoring_context(next_document, game.authored_runtime, "free_play_act")
 check(game.act_score_target == 0 and game.exit_unlocked, "Explicit Free Play bypasses even an authored target")
 game.ring_field.scoring_enabled = false # Reload may be requested while paused during a drain.
 check(game.request_replay(), "New run uses ordinary authored replay")
 await await_rebuild()
 check(game.score == 0 and game.act_score == 0 and game.scorecraft.chain == 0, "New run clears both score ledgers and combo")
 check(game.ring_field.scoring_enabled, "Reload during drain restores physical ring collection in the new run")
