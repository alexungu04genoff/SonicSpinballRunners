extends SceneTree
## Real resident instances, run hooks and baked-animation binding in a small pool.
const Run = preload("res://scripts/prototype/zone_run.gd")
const FIXTURE := "res://data/acts/buzz_bomber_test.tres"
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
 checks += 1
 if ok: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func run() -> void:
 game = Run.new()
 game.source_paths = [FIXTURE, FIXTURE, FIXTURE]
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 180000
 while not game.started and game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
 check(game.started and game.resident.size() >= 2, "Real streaming starts multiple instances of the authored enemy fixture")
 if not game.started:
  await game.prepare_to_close()
  game.free()
  quit(1)
  return
 while not game.resident[1].ready and Time.get_ticks_msec() < deadline: await process_frame
 check(game.resident[1].ready, "Neighbor finishes incremental visual attachment before binding inspection")
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.scorecraft.set_physics_process(false)
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 var active: RefCounted = game.active
 var neighbor: RefCounted = game.resident[1]
 var first: RefCounted = active.runtime.mechanics.enemies
 var second: RefCounted = neighbor.runtime.mechanics.enemies
 check(first.owner_act != second.owner_act and first.items.size() == 4 and second.items.size() == 4, "Streamed Acts own distinct generic enemy instances")
 var entries: Array[Dictionary] = []
 for node: Node in neighbor.nodes:
  if node.get_script() == preload("res://scripts/authored_act/mechanics_presentation.gd"): entries.append_array(node.enemies)
 check(entries.size() == 4 and entries.all(func(entry): return is_same(entry.item, second.by_id[entry.item.object_id])), "Baked animation references bind to the live neighbor's enemy state")
 check(second.by_id.easy_top.position == Vector2(180, 400) + Vector2(neighbor.plan.offset), "Enemy hit sensors inherit the streamed Act offset")
 check(not second.destroy("easy_top") and second.by_id.easy_top.alive and game.score == 0, "Inactive neighbor cannot destroy or award")
 game.buddies.choose("dark_chao")
 game.buddies.choose("rc_ufo")
 game.scorecraft.award_bonuses = game.buddies.modifiers()
 check(first.destroy("easy_top", &"test") and game.score == 125 and game.rings_collected == 1, "Actual run adapter gives Dark Chao generic enemy rewards")
 check(game.buddy_contributions.dark_chao == 25 and game.act_buddy_contributions.dark_chao == 25 and game.special_meter == 0, "Run and Act Buddy score ledgers reconcile without Special charge")
 check(not first.destroy("easy_top") and game.score == 125, "Repeated destruction cannot farm score")
 var ring: Dictionary = active.ring_data[0]
 var index: int = game.ring_field.rings.find(ring)
 game.ring_field.claim_ring(index)
 var timer: float = ring.rack.timeout_remaining
 game.ring_field.active_owner_id = second.owner_act
 game.ring_field.advance_racks(30.0)
 check(ring.rack.timeout_remaining == timer, "Inactive streamed ring patterns cannot advance toward respawn")
 game.ring_field.active_owner_id = first.owner_act
 game.reset_ball(false)
 for i in 3: await physics_frame
 check(not first.by_id.easy_top.alive and second.by_id.easy_top.alive, "Checkpoint retry retains death only in the owning Act instance")
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.buddies.choose("chip")
 game.balls_remaining = 1
 check(game._spend_ball() and game.balls_remaining == 1 and not game.finished, "Actual Challenge final-ball loss consumes Chip and continues this Act")
 check(not game._spend_ball() and game.finished, "A second final-ball loss ends the run; Chip cannot repeat")
 var summary: Dictionary = game.results.back()
 check(summary.buddy_state.rescues_used.chip == 1 and summary.normal_score + Run.Buddies.total(summary.buddy_contributions) == summary.score, "Results preserve Chip's consumed state and exact contribution reconciliation")
 check(summary.telemetry.buddy_state.rescues_used.chip == 1, "Copyable Act telemetry preserves the consumed rescue state")
 var retired_mechanics: Node = neighbor.runtime.mechanics
 await game.prepare_to_close()
 game.free()
 await process_frame
 check(not is_instance_valid(retired_mechanics) and second.targets().is_empty(), "Closing streaming frees enemy mechanics and leaves no live target nodes")
 print("RESULT | Enemy streaming | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
