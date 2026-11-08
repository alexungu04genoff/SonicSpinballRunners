extends "res://tests/gimmick_batch_regression.gd"
const Run = preload("res://scripts/prototype/zone_run.gd")
const Session = preload("res://scripts/prototype/session.gd")
const RETRY_PATH := "res://test-results/soft-retry-act.tres"
var session: Control

func start_game() -> bool:
 await session.start_run()
 game = session.game
 var deadline := Time.get_ticks_msec() + 180000
 while not game.started and game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
 check(game.started, "Legal single-Act fixture starts through the Prototype session", game.last_source_error)
 if not game.started: return false
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.scorecraft.set_physics_process(false)
 live_ball()
 manager = game.active.runtime.mechanics
 return true

func live_ball() -> void:
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.auto_launch_time = -1.0

func retry(manual := false) -> void:
 var score: int = game.score
 var target_time = game.telemetry.target_at
 var spinner_ticks: int = manager.by_id.spinner.goal_ticks
 var drop_state: Dictionary = manager.by_id.drops.duplicate(true)
 var balls: int = game.balls_remaining
 var bank_timer: float = manager.banks[0].get("reset_remaining", 0.0)
 var lane_timer: float = manager.by_id.lanes.cooldown
 var enemy_timer: float = manager.enemies.by_id.enemy.respawn_remaining
 var rack = game.ring_field.rings[0].rack
 var rack_timer: float = rack.timeout_remaining
 if manual: game._on_retry_requested()
 else: game._on_ball_drained()
 check(is_instance_valid(game.transfer) and game.balls_remaining == balls - (0 if game.practice_mode else 1), "Retry uses a protected transfer and spends a Ball only in Challenge")
 check(game.score == score and game.scorecraft.multiplier == 1 and game.scorecraft.chain == 0, "Actual drain preserves score and resets combo")
 game.ring_field._physics_process(1.0)
 manager.enemies.tick(1.0)
 var deadline := Time.get_ticks_msec() + 10000
 while is_instance_valid(game.transfer) and Time.get_ticks_msec() < deadline: await process_frame
 check(not is_instance_valid(game.transfer), "Protected retry completes within its deadline")
 live_ball()
 check(manager.by_id.spinner.goal_ticks == spinner_ticks and manager.banks[0].get("reset_remaining", 0.0) == bank_timer and manager.by_id.lanes.cooldown == lane_timer, "Protected retry preserves objective progress and exact timers")
 check(rack.timeout_remaining == rack_timer and game.telemetry.target_at == target_time, "Ring rack lifecycle and telemetry snapshots survive retry")
 check(manager.enemies.by_id.enemy.respawn_remaining == enemy_timer, "Actual protected retry pauses and preserves the enemy respawn countdown")
 check(manager.by_id.drops == drop_state, "Drop Target progress, retraction and exact reset timer survive retry")
 check(game.ball.position.distance_to(game.active.spawn()) < 1.0, "Retry arrives at the existing checkpoint")

func cross_lane(index: int) -> void:
 var lanes: Dictionary = manager.by_id.lanes
 var at: Vector2 = (lanes.posts[index] + lanes.posts[index + 1]) * 0.5
 manager._observe_travel(null, at + Vector2(0, 35), at - Vector2(0, 35))

func spin_ticks(count: int) -> void:
 for i in count:
  manager.by_id.spinner.spin = PI * 1001.0
  manager.tick(0.001)
 manager.by_id.spinner.spin = 0.0

func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://test-results")
 var document := batch_fixture()
 document.gameplay_objects.append(object("one_way_gate", "gate", Vector2(500, 350)))
 document.gameplay_objects.append(object("spinner", "spinner", Vector2(450, 300), {"completion_enabled": true, "target_ticks": 10}))
 document.gameplay_objects.append(object("buzz_bomber", "enemy", Vector2(450, 200)))
 document.gameplay_objects.append(object("drop_target_bank", "drops", Vector2(350, 100), {"reset_delay": 5.0}))
 document.switch_banks[0].actions.append({"object_id": "gate", "action": "open"})
 document.switch_banks[0].reset_delay = 5.0
 for placement: Dictionary in document.gameplay_objects:
  if placement.type == "lane_barrier": placement.properties.reset_delay = 5.0
 check(document.save_document(RETRY_PATH) == OK, "Focused multi-objective fixture saves", str(document.validation_errors()))
 if failures: quit(1); return
 var illegal := Run.RunPlan.Configuration.new([RETRY_PATH, RETRY_PATH, RETRY_PATH])
 check(illegal.validation_error() == "Select distinct Act sources.", "Ordinary run pools still reject repeated source Acts")
 session = Session.new()
 session.settings_path = "user://soft-retry-regression.cfg"
 session.archive_directory = "user://telemetry/runs/_validation/soft_retry_regression"
 session.configure_act_test(RETRY_PATH)
 session.sound_enabled = false
 root.add_child(session)
 if not await start_game(): session.free(); quit(1); return
 check(game.run_plan.size() == 1 and game.practice_mode and game.library.fallback_builds == 1, "Editor Practice uses one source-built Act through the current planner")
 manager._activate_switch(manager.by_id.floor_blue)
 manager._activate_switch(manager.by_id.wall_green)
 spin_ticks(7)
 cross_lane(0)
 cross_lane(1)
 check(manager.enemies.destroy("enemy"), "Enemy is destroyed through the real scoring adapter")
 game.ring_field.claim_ring(0)
 manager.drop_target(manager.by_id.drops, manager.by_id.drops.targets[0])
 manager.by_id.route.pending_state = "b"
 manager.by_id.spinner.tick_rotation = 0.25
 manager.by_id.spinner.spin = 10.0
 game.scorecraft.chain = 3
 game.scorecraft.multiplier = 3
 await retry()
 check(manager.by_id.spinner.spin == 0.0 and manager.by_id.spinner.tick_rotation == 0.25 and manager.by_id.route.pending_state == "b", "Retry stops spinner inertia but preserves partial rotation and pending earned diverter action")
 check(manager.by_id.floor_blue.active and manager.by_id.wall_green.active and not manager.by_id.floor_red.active, "Partial floor/wall switch bank survives")
 check(manager.by_id.spinner.goal_ticks == 7 and manager.by_id.lanes.lanes[0].lit and manager.by_id.lanes.lanes[1].lit, "Spinner 7/10 and lanes 2/3 survive")
 check(not manager.enemies.by_id.enemy.alive and manager.by_id.drops.targets[0].down and not manager.by_id.drops.complete, "Defeated enemy and partial Drop Target Bank are preserved")
 manager._activate_switch(manager.by_id.floor_red)
 manager._advance_diverters(Vector2(-1000, -1000), Vector2.ZERO)
 spin_ticks(3)
 cross_lane(2)
 for target: Dictionary in manager.by_id.drops.targets: manager.drop_target(manager.by_id.drops, target)
 check(manager.banks[0].complete and manager.by_id.gate.open and manager.by_id.route.state == "b", "Remaining member opens the gate and switches the diverter")
 check(manager.by_id.spinner.completions == 1 and manager.by_id.lanes.completions == 1, "Retained spinner and lane progress completes normally")
 var earned: int = game.score
 await retry()
 manager._activate_switch(manager.by_id.floor_red)
 check(game.score == earned and manager.by_id.gate.open and manager.by_id.route.state == "b" and manager.banks[0].complete, "Completed objectives remain open without duplicate awards")
 await retry(true)
 check(manager.by_id.gate.open and manager.by_id.lanes.complete and game.exit_unlocked, "Manual retry also preserves completed routes, lane cooldown and Goal readiness")
 manager.reset()
 check(not manager.by_id.floor_blue.active and not manager.by_id.gate.open and manager.by_id.route.state == "a" and manager.by_id.spinner.goal_ticks == 0 and not manager.by_id.lanes.lanes[0].lit and not manager.by_id.drops.targets[0].down, "Explicit mechanic reset retains authored initial-state semantics")
 manager._activate_switch(manager.by_id.floor_blue)
 spin_ticks(7)
 manager.drop_target(manager.by_id.drops, manager.by_id.drops.targets[0])
 var old_manager: Node = manager
 if not await start_game(): session.free(); quit(1); return
 check(not is_instance_valid(old_manager) and manager.enemies.by_id.enemy.alive and not manager.by_id.floor_blue.active and not manager.by_id.gate.open and manager.by_id.spinner.goal_ticks == 0 and not manager.by_id.drops.targets[0].down, "Session Restart run rebuilds fresh enemies and objectives")
 check(game.score == 0 and game.act_score == 0 and not game.exit_unlocked and game.telemetry.target_at == null, "Hard restart clears scores, Goal readiness and target telemetry")
 session.practice_mode = false
 if not await start_game(): session.free(); quit(1); return
 manager._activate_switch(manager.by_id.floor_blue)
 spin_ticks(7)
 await retry()
 await retry(true)
 check(game.balls_remaining == 1 and manager.by_id.floor_blue.active and manager.by_id.spinner.goal_ticks == 7, "Challenge preserves objectives across drain and manual retry")
 game._on_ball_drained()
 check(game.finished and game.balls_remaining == 0 and not is_instance_valid(game.transfer), "Final Challenge loss ends the run instead of starting another retry")
 await session._close_run("test_finished")
 session.free()
 _neighbor_retry_check()
 print("RESULT | Soft retry | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func _neighbor_retry_check() -> void:
 # A small adapter diagnostic covers resident isolation independently of pool setup.
 var hub := preload("res://scripts/endless/mechanics_hub.gd").new()
 var active := preload("res://scripts/authored_act/pinball_mechanics.gd").new()
 var neighbor := preload("res://scripts/authored_act/pinball_mechanics.gd").new()
 for runtime: Node in [active, neighbor]:
  runtime.add_object(object("switch_target", "switch", Vector2.ZERO), {})
  runtime.by_id.switch.active = true
  runtime.by_id.switch.latched = true
  runtime.banks = [{"complete": true, "reset_remaining": 17.0}]
 neighbor.scoring_active = false
 hub.runtimes.assign([active, neighbor])
 hub.reset_for_retry()
 check(not active.by_id.switch.latched and active.by_id.switch.active, "Streamed adapter clears active contacts while preserving earned progress")
 check(neighbor.by_id.switch.active and neighbor.by_id.switch.latched and neighbor.banks[0].reset_remaining == 17.0, "Streamed retry leaves neighboring objectives and exact timers untouched")
 active.free()
 neighbor.free()
 hub.free()
