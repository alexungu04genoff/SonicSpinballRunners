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
 check(first.destroy("easy_top", &"test") and game.score == 250 and game.rings_collected == 1, "Actual run adapter gives Dark Chao generic enemy rewards")
 check(game.buddy_contributions.dark_chao == 50 and game.act_buddy_contributions.dark_chao == 50 and game.special_meter == 0, "Run and Act Buddy score ledgers reconcile without Special charge")
 check(not first.destroy("easy_top") and game.score == 250, "Repeated destruction cannot farm score")
 var ring: Dictionary = active.ring_data[0]
 var index: int = game.ring_field.rings.find(ring)
 game.ring_field.claim_ring(index)
 var timer: float = ring.rack.timeout_remaining
 game.ring_field.active_owner_id = second.owner_act
 game.ring_field.advance_racks(30.0)
 check(ring.rack.timeout_remaining == timer, "Inactive streamed ring patterns cannot advance toward respawn")
 game.ring_field.active_owner_id = first.owner_act
 first.tick(5.0)
 var respawn_clock: float = first.by_id.easy_top.respawn_remaining
 game.reset_ball(false)
 for i in 3: await physics_frame
 check(not first.by_id.easy_top.alive and second.by_id.easy_top.alive, "Checkpoint retry retains death only in the owning Act instance")
 first.tick(20.0)
 check(respawn_clock == 10.0 and first.by_id.easy_top.respawn_remaining == respawn_clock, "Real checkpoint serve preserves and pauses the owning enemy countdown")
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.ball.position = Vector2(500, 850) + Vector2(active.plan.offset)
 first.tick(10.0)
 first.tick(0.01)
 first.tick(0.35)
 check(first.by_id.easy_top.alive and game.telemetry.enemies.respawns == 1, "Owning Act safely respawns and reports exactly one enemy event")
 # Actual generic destruction signals reach the live run's score and telemetry.
 game.elapsed = 20.0
 for id: String in ["easy_top", "side_target", "bottom_target", "patrol_target"]:
  first.destroy(id)
 check(game.scorecraft.multiplier == 4 and game.telemetry.x4_activations == 1, "Four distinct enemy builders reach x4 through the streamed run")
 game._on_mechanic_score(&"ring_rack", "telemetry_rack", 500, first.owner_act)
 game._on_mechanic_score(&"switch", "telemetry_switch", 25, first.owner_act)
 first.tick(15.0)
 first.tick(0.35)
 game.elapsed = 35.35
 game.ball.freeze = false
 game.ball.teleport_to(Vector2(180, 330) + Vector2(active.plan.offset), Vector2.ZERO, false)
 for i in 3: await physics_frame
 game.special_meter = 100
 check(game.specials.activate(), "Real Sonic activation spends meter and starts a telemetry finisher")
 game.ball.freeze = false
 for i in 60:
  await physics_frame
  await process_frame
  if not first.by_id.easy_top.alive: break
 game.ball.freeze = true
 check(game.telemetry.homing.finishers_used == 1 and game.telemetry.homing.successful_hits == 1 and game.telemetry.homing.normal_score == 1200 and game.scorecraft.chain == 0, "Real x4 enemy Homing records one 1200-point cash-out and ends the combo")
 game.buddies.choose("chip")
 game.balls_remaining = 1
 check(game._spend_ball() and game.balls_remaining == 1 and not game.finished, "Actual Challenge final-ball loss consumes Chip and continues this Act")
 check(not game._spend_ball() and game.finished, "A second final-ball loss ends the run; Chip cannot repeat")
 var summary: Dictionary = game.results.back()
 check(summary.buddy_state.rescues_used.chip == 1 and summary.normal_score + Run.Buddies.total(summary.buddy_contributions) == summary.score, "Results preserve Chip's consumed state and exact contribution reconciliation")
 check(summary.telemetry.buddy_state.rescues_used.chip == 1, "Copyable Act telemetry preserves the consumed rescue state")
 var data: Dictionary = summary.telemetry
 var normal_sum := 0
 for points: int in data.score_by_category.values(): normal_sum += points
 check(normal_sum == summary.normal_score and data.score_by_category.enemy == 3400 and data.score_by_category.ring_rack == 500 and data.score_by_category.switch == 100, "V2 normal categories exclude Buddy bonuses and reconcile with the real Act ledger")
 check(data.combo_score_by_multiplier == {"1": 415, "2": 400, "3": 600, "4": 1700}, "Multiplier buckets include sensitive bases only, excluding fixed rack and Homing bonus")
 check(data.combo_advances_by_source.enemy == 5 and data.combo_support_by_source.ring_rack == 1 and data.combo_support_by_source.switch == 1, "Advances and support count their distinct production events")
 check(data.enemies.destructions == 6 and data.enemies.respawns == 5 and data.enemies.normal_score == 3400, "Enemy totals include normal and Homing destruction with no duplicate lifecycle event")
 check(is_equal_approx(data.longest_combo_seconds, 15.35) and data.longest_combo_max_multiplier == 4 and data.highest_multiplier == 4, "Longest combo uses the gameplay clock and retains its peak")
 var exported := preload("res://scripts/prototype/run_telemetry.gd").export_run({"seed": game.run_seed, "practice": false, "character": "sonic", "won": false, "score": game.score, "normal_score": summary.normal_score, "seconds": game.elapsed, "drains": 2, "buddies": game.buddies.levels, "buddy_contributions": game.buddy_contributions, "acts": game.results})
 var copy: Dictionary = JSON.parse_string(JSON.stringify(exported))
 check(copy.telemetry_format_version == 2 and data.score_by_category.keys().all(func(key): return int(copy.acts[0].score_by_category[key]) == data.score_by_category[key]) and copy.acts[0].score_at_target == data.score_at_target, "Copied V2 JSON round-trips new counters and original raw timing snapshots")
 var retired_mechanics: Node = neighbor.runtime.mechanics
 await game.prepare_to_close()
 game.free()
 await process_frame
 check(not is_instance_valid(retired_mechanics) and second.targets().is_empty(), "Closing streaming frees enemy mechanics and leaves no live target nodes")
 print("RESULT | Enemy streaming | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
