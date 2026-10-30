extends SceneTree
const Run = preload("res://scripts/prototype/zone_run.gd")
const Telemetry = preload("res://scripts/prototype/run_telemetry.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func run() -> void:
 for count in [1, 7]:
  var game := Run.new()
  game.run_configuration = Run.RunPlan.Configuration.new(Run.RunPlan.source_paths().slice(0, 3))
  game.run_configuration.zone_count = count
  game.run_configuration.selected_theme_ids = ["green_hill"]
  game.practice_mode = true
  var summary := {}
  game.completed.connect(func(value: Dictionary): summary.merge(value, true))
  root.add_child(game)
  var deadline := Time.get_ticks_msec() + 180000
  while not game.started and game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
  check(game.started, "%d-Zone run starts from disk bakes" % count)
  if not game.started:
   await game.prepare_to_close()
   game.free()
   paused = false
   break
  game.set_physics_process(false)
  game.ring_field.set_physics_process(false)
  for sequence in count * 3:
   game.ball.freeze = true
   game.ball.serve_pending = false
   game.auto_launch_time = -1.0
   game.ball.position = game.active.spawn()
   game.active.runtime.mechanics.mechanic_score.emit(&"wall_switch", "variable_run_award", game.act_score_target)
   deadline = Time.get_ticks_msec() + 180000
   while game._has_next_act() and not game._next_ready() and Time.get_ticks_msec() < deadline: await process_frame
   check(game.active_sequence == sequence and game.act_score_target == 1000 + sequence * 500 and game.active.plan.theme == "green_hill", "Configured Act %d has the correct target and theme" % (sequence + 1))
   var goal: Vector2 = game.active.runtime.goal_ring.center
   game._observe_authored_motion(goal, goal)
   if sequence < count * 3 - 1:
    check(game.drafting and not game.finished, "Nonfinal goal enters the existing Buddy draft")
    var offers: Array = game.buddies.offers()
    check(game.choose_buddy("" if offers.is_empty() else offers[0].id), "Draft continues even after available upgrades are exhausted")
    deadline = Time.get_ticks_msec() + 10000
    while is_instance_valid(game.transfer) and Time.get_ticks_msec() < deadline: await process_frame
  var data := Telemetry.export_run(summary) if not summary.is_empty() else {}
  check(game.finished and summary.get("won", false) and data.get("acts", []).size() == count * 3 and data.get("course", []).size() == count * 3, "%d-Zone final goal completes and exports the whole course" % count)
  check(game.library.fallback_builds == 0, "Variable run never builds runtime geometry")
  await game.prepare_to_close()
  game.free()
  paused = false
  for i in 5: await process_frame
 print("RESULT | Prototype variable run | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
