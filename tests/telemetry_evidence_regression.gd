extends SceneTree
## Bounded statistics plus real Prototype ownership/action hooks; no balance simulation.
const Telemetry = preload("res://scripts/prototype/run_telemetry.gd")
const Samples = preload("res://scripts/prototype/ball_speed_telemetry.gd")
const Run = preload("res://scripts/prototype/zone_run.gd")
const ACT := "res://data/acts/Experiments/Lockbox.tres"
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func statistics() -> void:
 var samples := Samples.new()
 check(samples.snapshot().average == null and samples.snapshot().p95 == null, "No eligible samples exports null statistics")
 for i in 100: samples.observe(0.1, i * 10.0, true)
 var stats := samples.snapshot()
 check(stats.samples == 100 and stats.average == 495.0 and stats.median == 480.0 and stats.p95 == 940.0 and stats.max == 990.0, "Known distribution has exact sample average/max and bounded percentile error")
 samples.observe(0.1, 50000.0, false)
 samples.observe(0.1, INF, true)
 check(samples.snapshot() == stats, "Excluded and nonfinite speeds never contaminate statistics")
 samples.reset()
 for i in 12: samples.observe(1.0 / 120.0, 500.0, true)
 check(samples.snapshot().samples == 1, "120 Hz physics produces one sample per 0.1 eligible seconds")
 samples.reset()
 samples.observe(0.05, 10.0, true)
 samples.observe(1.0, 10.0, false)
 samples.observe(0.05, 10.0, true)
 check(samples.snapshot().samples == 0, "An exclusion resets the cadence without catch-up samples")
 samples.observe(0.05, 20000.0, true)
 check(samples.snapshot().overflow_samples == 1 and samples.snapshot().max == 20000.0 and samples.snapshot().p95 == 10240.0, "Overflow preserves exact mean/max and reports percentile saturation")
 var recorder := Telemetry.new()
 recorder.begin_act(0.0)
 recorder.action_used("speed")
 recorder.speed_started(50.0, 300.0)
 recorder.speed_ended("Hit")
 recorder.speed_hit("bumper")
 recorder.speed_hit("bumper")
 recorder.action_used("speed")
 recorder.speed_started(280.0, 300.0)
 recorder.speed_ended("Expired")
 recorder.speed_ended("Reset")
 var action := recorder._action_snapshot()
 check(action.uses == 2 and action.successful_uses == 1 and action.speed.failed_approaches == 1 and action.speed.distance.close.hits == 1 and action.speed.distance.far.failed == 1, "Speed outcomes and tuning-relative distance buckets count each approach once")
 recorder.action_used("speed")
 recorder.speed_started(150.0, 300.0)
 check(recorder._action_snapshot().speed.pending_approaches == 1, "Unfinished approaches remain pending, not invented failures")
 seed(701)
 var expected := randi()
 seed(701)
 recorder.observe_motion(0.1, 900.0, true, 0.0)
 var row := {"zone": 1, "zone_act": 1, "act": 1, "title": "Fixture", "source": ACT, "cleared": true, "target": 1000, "score": 1000, "drains": 0, "buddy_contributions": {}, "authored_difficulty": 4}
 var result := recorder.finish_act(row, 1.0)
 check(randi() == expected and row.score == 1000, "Recording and snapshotting preserve RNG and input score")
 var summary := {"won": true, "seed": 18, "practice": true, "character": "sonic", "score": 1000, "normal_score": 1000, "buddy_contributions": {}, "buddies": {}, "seconds": 1.0, "drains": 0, "acts": [{"telemetry": result}]}
 var json: Dictionary = JSON.parse_string(JSON.stringify(Telemetry.export_run(summary)))
 check(json.telemetry_format_version == 4 and json.completed_act_difficulties == {"4": 1.0} and json.action_totals.uses == 3 and json.acts[0].ball_speed.max == 900.0 and json.acts[0].wide_spring == null, "V4 JSON keeps authored difficulty and compact run totals; unavailable Saver is null")
 result.erase("character_action")
 check(Telemetry.export_run(summary).action_totals.successful_uses == null, "Legacy rows without generalized success evidence remain unknown")
 recorder.begin_act(2.0)
 check(recorder.type_actions.uses == 0 and recorder.ball_speed.snapshot().samples == 0 and recorder.drop_targets.hits == 0 and recorder._action_snapshot().successful_uses == 0, "Act boundary resets every new evidence group")

func run() -> void:
 statistics()
 var game := Run.new()
 game.run_configuration = Run.RunPlan.Configuration.new([ACT])
 game.run_configuration.single_act_test = true
 game.run_configuration.zone_count = 1
 game.run_configuration.selected_theme_ids = ["green_hill"]
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 60000
 while not game.started and game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
 check(game.started, "Real Prototype fixture starts with its authored mechanics")
 if not game.started:
  await game.prepare_to_close()
  game.free()
  quit(1)
  return
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.specials.set_physics_process(false)
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.auto_launch_time = -1.0
 var document: Resource = game.active.document
 var mechanics: Node = game.active.runtime.mechanics
 var sling_id := ""
 var spring_id := ""
 var bank := {}
 for item: Dictionary in mechanics.items:
  if item.type == "slingshot": sling_id = item.object_id
  if item.type == "spring": spring_id = item.object_id
  if item.type == "drop_target_bank": bank = item
 check(not sling_id.is_empty() and not spring_id.is_empty() and not bank.is_empty(), "Fixture contains Slingshot, ordinary Spring and Drop Bank")
 check(game.telemetry.slingshots.by_object[sling_id] == 0 and game.telemetry.drop_targets.banks[bank.object_id].hits == 0, "Unused authored objects appear with zero counters")
 game._on_traversal_event(&"spring", sling_id, &"used", "act:999")
 game._on_traversal_event(&"spring", spring_id, &"used", game.active_scoring_id)
 game._on_traversal_event(&"spring", sling_id, &"used", game.active_scoring_id)
 check(game.telemetry.slingshots.activations == 1, "Prototype adapter excludes neighbor ownership and ordinary Springs")
 var target: Dictionary = bank.targets[0]
 mechanics.drop_target(bank, target)
 mechanics.drop_target(bank, target)
 game._on_drop_target_event(bank.object_id, target.object_id, &"hit", bank.targets.size(), "act:999")
 check(game.telemetry.drop_targets.hits == 1 and game.telemetry.score_by_category.switch == 25, "Accepted Drop hit records once, retains Switch score semantics and excludes neighbors")
 game.specials.select_character("tails")
 game.telemetry.begin_act(game.elapsed, document, "tails")
 game.special_meter = 100
 game.ball.linear_velocity = Vector2(0, 100)
 check(game.specials.activate(), "Real Flight activates during a fall")
 var flight: Dictionary = game.telemetry._action_snapshot()
 check(flight.type == "fly" and flight.uses == 1 and flight.successful_uses == 1 and flight.fly.rescue_lift_activations == 1, "Flight use, accepted activation and actual rescue lift are counted")
 game._physics_process(0.1)
 check(game.telemetry._action_snapshot().fly.active_seconds == 0.0 and game.telemetry.ball_speed.snapshot().samples == 0, "Frozen Ball contributes neither Flight gameplay time nor speed")
 game.ball.freeze = false
 game._physics_process(0.1)
 check(is_equal_approx(game.telemetry._action_snapshot().fly.active_seconds, 0.1) and game.telemetry.ball_speed.snapshot().samples == 1, "Live Flight contributes gameplay time and ordinary free-motion speed")
 paused = true
 game._physics_process(0.1)
 paused = false
 game.ball.on_ramp = true
 game._physics_process(0.1)
 game.ball.on_ramp = false
 check(game.telemetry.ball_speed.snapshot().samples == 1 and is_equal_approx(game.telemetry._action_snapshot().fly.active_seconds, 0.2), "Pause excludes all time; rail travel excludes speed but preserves active Flight time")
 game.ball.serve_pending = true
 game._physics_process(0.1)
 game.ball.serve_pending = false
 game.ball._teleport_pending = true
 game._physics_process(0.1)
 game.ball._teleport_pending = false
 game.specials.homing_remaining = 0.5
 game._physics_process(0.1)
 game.specials.homing_remaining = 0.0
 check(game.telemetry.ball_speed.snapshot().samples == 1, "Serve, teleport and guided approach cannot contribute tempo samples")
 game.ball.freeze = true
 game.specials.select_character("knuckles")
 game.telemetry.begin_act(game.elapsed, document, "knuckles")
 game.ball.position = game.playfield.bumpers[0].global_position
 game.special_meter = 100
 check(game.specials.activate(), "Real Power activation uses accepted atomic target callbacks")
 var power: Dictionary = game.telemetry._action_snapshot()
 var affected: Dictionary = power.power.affected_by_type
 check(power.uses == 1 and power.successful_uses == 1 and power.power.affected_total == affected.ring + affected.bumper + affected.enemy and affected.bumper > 0, "Power totals reconcile with type breakdown and successful nonempty uses")
 check(game.telemetry.type_actions.affected_targets + game.telemetry.type_actions.affected_rings == power.power.affected_total, "V2-era area totals retain their meaning")
 game.ball.position = Vector2(-10000, -10000)
 game.special_meter = 100
 game.specials.activate()
 check(game.telemetry._action_snapshot().uses == 2 and game.telemetry._action_snapshot().successful_uses == 1, "Empty Smash spends a use but records no successful affected-object use")
 var final_row: Dictionary = game._act_result(false).telemetry
 check(final_row.character == "knuckles" and final_row.character_type == "power" and final_row.authored_difficulty == document.authored_difficulty and final_row.design_thesis == document.design_thesis, "Act row snapshots authored and character context")
 await game.prepare_to_close()
 game.free()
 paused = false
 print("RESULT | Telemetry evidence | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
