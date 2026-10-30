extends "res://tests/gimmick_batch_regression.gd"
const Run = preload("res://scripts/prototype/zone_run.gd")
const RETRY_PATH := "res://test-results/soft-retry-act.tres"

func start_game() -> void:
 game = Run.new()
 game.source_paths = [RETRY_PATH, RETRY_PATH, RETRY_PATH]
 game.practice_mode = true
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 180000
 while not game.started and game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
 check(game.started, "Focused fixture starts the real streamed prototype", game.last_source_error)
 if not game.started: await game.prepare_to_close(); game.free(); quit(1); return
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.scorecraft.set_physics_process(false)
 live_ball()
 manager = game.active.runtime.mechanics

func live_ball() -> void:
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.auto_launch_time = -1.0

func retry(manual := false) -> void:
 var score: int = game.score
 var target_time = game.telemetry.target_at
 var spinner_ticks: int = manager.by_id.spinner.goal_ticks
 var bank_timer: float = manager.banks[0].get("reset_remaining", 0.0)
 var lane_timer: float = manager.by_id.lanes.cooldown
 var rack = game.ring_field.rings[0].rack
 var rack_timer: float = rack.timeout_remaining
 if manual: game._on_retry_requested()
 else: game._on_ball_drained()
 check(game.score == score and game.scorecraft.multiplier == 1 and game.scorecraft.chain == 0, "Actual drain preserves score and resets combo")
 game.ring_field._physics_process(1.0)
 while is_instance_valid(game.transfer): await process_frame
 live_ball()
 check(manager.by_id.spinner.goal_ticks == spinner_ticks and manager.banks[0].get("reset_remaining", 0.0) == bank_timer and manager.by_id.lanes.cooldown == lane_timer, "Protected retry preserves objective progress and exact timers")
 check(rack.timeout_remaining == rack_timer and game.telemetry.target_at == target_time, "Ring rack lifecycle and telemetry snapshots survive retry")
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
 var document := batch_fixture()
 document.gameplay_objects.append(object("one_way_gate", "gate", Vector2(500, 350)))
 document.gameplay_objects.append(object("spinner", "spinner", Vector2(450, 300), {"completion_enabled": true, "target_ticks": 10}))
 document.gameplay_objects.append(object("buzz_bomber", "enemy", Vector2(450, 200)))
 document.switch_banks[0].actions.append({"object_id": "gate", "action": "open"})
 document.switch_banks[0].reset_delay = 5.0
 for placement: Dictionary in document.gameplay_objects:
  if placement.type == "lane_barrier": placement.properties.reset_delay = 5.0
 check(document.save_document(RETRY_PATH) == OK, "Focused multi-objective fixture saves", str(document.validation_errors()))
 if failures: quit(1); return
 await start_game()
 manager._activate_switch(manager.by_id.floor_blue)
 manager._activate_switch(manager.by_id.wall_green)
 spin_ticks(7)
 cross_lane(0)
 cross_lane(1)
 check(manager.enemies.destroy("enemy"), "Enemy is destroyed through the real scoring adapter")
 game.ring_field.claim_ring(0)
 var neighbor: Node = game.resident[1].runtime.mechanics
 neighbor.by_id.floor_red.active = true
 neighbor.banks[0].reset_remaining = 17.0
 manager.by_id.route.pending_state = "b"
 manager.by_id.spinner.tick_rotation = 0.25
 manager.by_id.spinner.spin = 10.0
 game.scorecraft.chain = 3
 game.scorecraft.multiplier = 3
 await retry()
 check(manager.by_id.spinner.spin == 0.0 and manager.by_id.spinner.tick_rotation == 0.25 and manager.by_id.route.pending_state == "b", "Retry stops spinner inertia but preserves partial rotation and pending earned diverter action")
 check(manager.by_id.floor_blue.active and manager.by_id.wall_green.active and not manager.by_id.floor_red.active, "Partial floor/wall switch bank survives")
 check(manager.by_id.spinner.goal_ticks == 7 and manager.by_id.lanes.lanes[0].lit and manager.by_id.lanes.lanes[1].lit, "Spinner 7/10 and lanes 2/3 survive")
 check(not manager.enemies.by_id.enemy.alive and neighbor.by_id.floor_red.active and neighbor.banks[0].reset_remaining == 17.0, "Defeated enemy and neighboring objective state are preserved")
 manager._activate_switch(manager.by_id.floor_red)
 manager._advance_diverters(Vector2(-1000, -1000), Vector2.ZERO)
 spin_ticks(3)
 cross_lane(2)
 check(manager.banks[0].complete and manager.by_id.gate.open and manager.by_id.route.state == "b", "Remaining member opens the gate and switches the diverter")
 check(manager.by_id.spinner.completions == 1 and manager.by_id.lanes.completions == 1, "Retained spinner and lane progress completes normally")
 var earned: int = game.score
 await retry()
 manager._activate_switch(manager.by_id.floor_red)
 check(game.score == earned and manager.by_id.gate.open and manager.by_id.route.state == "b" and manager.banks[0].complete, "Completed objectives remain open without duplicate awards")
 await retry(true)
 check(manager.by_id.gate.open and manager.by_id.lanes.complete and game.exit_unlocked, "Manual retry also preserves completed routes, lane cooldown and Goal readiness")
 manager.reset()
 check(not manager.by_id.floor_blue.active and not manager.by_id.gate.open and manager.by_id.route.state == "a" and manager.by_id.spinner.goal_ticks == 0 and not manager.by_id.lanes.lanes[0].lit, "Explicit full reset retains authored initial-state semantics")
 await game.prepare_to_close()
 game.free()
 await start_game()
 check(manager.enemies.by_id.enemy.alive and not manager.by_id.floor_blue.active and not manager.by_id.gate.open and manager.by_id.spinner.goal_ticks == 0, "Fresh runtime starts with a live enemy and fresh objectives")
 await game.prepare_to_close()
 game.free()
 print("RESULT | Soft retry | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
