extends SceneTree
## Compare source-built and disk-baked traversal in the supported Prototype route.
const Session = preload("res://scripts/prototype/session.gd")
const ACT := "res://data/acts/Experiments/Traversal Diagnostic.tres"
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func run() -> void:
 for baked in [false, true]:
  var session := Session.new()
  session.settings_path = "user://traversal-test-unused.cfg"
  session.archive_directory = "user://traversal-test-telemetry"
  session.configure_act_test(ACT)
  session.run_configuration.single_act_use_bakes = baked
  session.sound_enabled = false
  root.add_child(session)
  await session.start_run()
  var deadline := Time.get_ticks_msec() + 120000
  while is_instance_valid(session.game) and not session.game.started and session.game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
  var game: Node = session.game
  check(is_instance_valid(game) and game.started, "Prototype starts " + ("disk bake" if baked else "source"))
  if is_instance_valid(game) and game.started:
   check(game.library.fallback_builds == (0 if baked else 1), "Requested construction path is authoritative")
   game.auto_launch_time = -1.0
   var manager: Node = game.active.runtime.mechanics
   check(manager.exit_obstacles.size() == 6 and manager.cell_size == 50.0, "Streamed runtime retains exit safety geometry")
   check(game.active.runtime.flippers[2].length == 65.0, "Streamed 2x flipper collision matches its bake")
   var transfer_midpoint := Vector2(290, 270)
   game.active.runtime.goal_ring.center = transfer_midpoint
   game.ball.serve_pending = false
   manager.mechanic_score.emit(&"switch", "test_unlock", game.act_score_target)
   check(game.active.runtime.goal_ring.unlocked, "Intermediate Goal is unlocked for swept-transfer regression")
   game.ring_field.add_ring(transfer_midpoint)
   var ring_index: int = game.ring_field.rings.size() - 1
   game.ball.teleport_to(Vector2(80, 440), Vector2(0, -220))
   for frame in 8: await physics_frame
   check(not game.finished and game.telemetry.goal_at == null, "Teleporter cannot sweep-complete an intermediate Goal")
   check(game.ring_field.rings[ring_index].active, "Teleporter cannot sweep-collect intermediate Rings")
   check(game.telemetry.teleporters.transfers == 1 and game.ball.position.x > 500.0, "Streamed Teleporter transfers once and records passive telemetry")
   check(game.ball.linear_velocity.x > 210.0, "Streamed exit preserves reasonable speed along its direction")
   var data: Dictionary = game._act_result(false).telemetry
   check(data.teleporters.transfers == 1 and data.drop_targets.hits == 0 and data.slingshots.activations == 0, "Export adds transfer counters without changing existing mechanic counters")
  await session._close_run("test_finished")
  session.free()
  paused = false
  await process_frame
 print("RESULT | Traversal Prototype | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
