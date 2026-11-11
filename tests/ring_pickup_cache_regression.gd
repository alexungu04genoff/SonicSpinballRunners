extends SceneTree
## Floor candidate filtering preserves global pickup indices and live signal behavior.
class ObservedField extends RingField:
 var attempts: Array[int] = []
 var eligibility_checks := 0
 func claim_ring(index: int, source: String = "", multiplier: int = 1) -> bool:
  attempts.append(index)
  return super.claim_ring(index, source, multiplier)
 func ring_eligible(ring: Dictionary) -> bool:
  eligibility_checks += 1
  return super.ring_eligible(ring)

var checks := 0
var failures := 0
var pickups: Array[int] = []
var field: ObservedField

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func fixture(owner := "a", neighbor := "b") -> Array[Dictionary]:
 var floor_pattern := [{"pattern_id": "floor", "start": Vector2.ZERO, "end": Vector2(300, 0), "spacing": 100.0}]
 var a := RingField.pattern_records(floor_pattern, owner)
 var b := RingField.pattern_records(floor_pattern, neighbor)
 var rails := RingField.pattern_records([{"pattern_id": "rail", "start": Vector2.ZERO, "end": Vector2(200, 0), "spacing": 100.0}], owner)
 for i in rails.size():
  rails[i].rail_id = "route"
  rails[i].rail_distance = (i + 1) * 10.0
  rails[i].height = 40.0
 return [a[0], b[0], rails[0], a[1], b[1], rails[1], a[2], a[3], rails[2], b[2], b[3]]

func prepare(records: Array[Dictionary], owner := "a") -> void:
 field.rings = records
 field.active_owner_id = owner
 field.collection_bounds = Rect2()
 field.scoring_enabled = true
 field.ball.serve_pending = false
 field.ball._teleport_pending = false
 field.ball.on_ramp = false
 field.tuning.set_value("ring_magnet_radius", 0.0)
 sweep()

func sweep() -> void:
 field.previous_ball_position = Vector2(-100, 0)
 field.ball.position = Vector2(400, 0)
 field.attempts.clear()
 pickups.clear()

func run() -> void:
 field = ObservedField.new()
 field.ball = PlaygroundBall.new()
 field.tuning = PhysicsTuning.new()
 field.ball.tuning = field.tuning
 field.pickup_claimed.connect(func(index: int): pickups.append(index))
 prepare(fixture())
 field._physics_process(0.0)
 check(pickups == [0, 3, 6, 7] and field.attempts == pickups, "Cold zero-delta sweep claims only active floor Rings in original global-index order")
 check([1, 2, 4, 5, 8, 9, 10].all(func(i): return field.rings[i].active), "Overlapping neighboring and elevated Rings remain active")
 field._physics_process(1.0 / 120.0)
 check(pickups.size() == 4, "Repeated contact cannot award cached candidates twice")

 prepare(fixture())
 field.ball.position = Vector2(10000, 10000)
 field.previous_ball_position = field.ball.position
 field.eligibility_checks = 0
 for tick in 120: field._physics_process(1.0 / 120.0)
 check(field.eligibility_checks == 120 * (2 + 4), "Steady ticks check two active racks and four floor candidates, excluding resident neighbors and rails")
 check(field.attempts.is_empty(), "A distant stationary Ball cannot trigger pickups")
 sweep()
 field.active_owner_id = "b"
 field._physics_process(0.0)
 check(pickups == [1, 4, 9, 10], "Owner switches immediately use the other Act's floor indices")
 field.reset_rings()
 sweep()
 field.active_owner_id = "missing"
 field._physics_process(0.0)
 check(pickups.is_empty() and field.previous_ball_position == field.ball.position, "Missing owner updates the sweep origin without collecting")
 field.active_owner_id = "a"
 field._physics_process(0.0)
 check(pickups.is_empty(), "Returning to an owner cannot create a deferred artificial sweep")

 prepare(fixture())
 field.active_owner_id = ""
 field.collection_bounds = Rect2(Vector2(99, -1), Vector2(2, 2))
 field._physics_process(0.0)
 check(pickups == [3, 4], "Legacy bounds remain live across all owners and preserve global ordering")
 prepare(fixture())
 field._physics_process(0.0)
 field.reset_rings()
 field.rings[0].position = Vector2(900, 0)
 field.ball.position = Vector2(900, 0)
 field.previous_ball_position = field.ball.position
 pickups.clear()
 field._physics_process(0.0)
 check(pickups == [0], "Cached indices read current positions instead of freezing coordinates")

 prepare(fixture())
 field.ball.on_ramp = true
 field._physics_process(1.0 / 120.0)
 check(pickups.is_empty(), "Ramp travel suppresses floor pickup scans")
 field.collect_rail_progress("route", 30.0, 0.0, "a")
 check(pickups == [2, 5, 8] and [0, 3, 6, 7].all(func(i): return field.rings[i].active), "Reverse rail travel keeps its existing callback and collects only its elevated chain")
 prepare(fixture())
 var nested_sweep := func(index: int):
  if index == 2: field._physics_process(0.0)
 field.pickup_claimed.connect(nested_sweep)
 field.collect_rail_progress("route", 10.0, 10.0, "a")
 check(pickups == [2, 0, 3, 5, 6, 7, 8], "A nested sweep during a rail callback preserves the existing collection context and signal order")
 field.pickup_claimed.disconnect(nested_sweep)

 prepare(fixture())
 field.ball.position = Vector2(10000, 10000)
 field.previous_ball_position = field.ball.position
 field._physics_process(0.0)
 field.rings.reverse()
 field.invalidate_rack_cache()
 sweep()
 field._physics_process(0.0)
 check(pickups == [3, 4, 7, 10], "Same-count resident reordering refreshes global pickup indices")
 var old: Dictionary = field.rings[10]
 prepare(fixture("c", "d"), "c")
 field._physics_process(0.0)
 check(pickups == [0, 3, 6, 7] and not old.active, "Same-count replacement collects fresh records without changing retired state")
 field.reset_rings()
 field.add_ring(Vector2(350, 0))
 sweep()
 field._physics_process(0.0)
 check(pickups == [0, 3, 6, 7, 11], "Added floor Rings extend the cached list in source order")
 field.reset_rings()
 field.rings.append_array(RingField.pattern_records([{"start": Vector2(360, 0), "end": Vector2(370, 0), "spacing": 10.0}], "c"))
 sweep()
 field._physics_process(0.0)
 check(pickups == [0, 3, 6, 7, 11, 12, 13], "Direct append refreshes candidate indices even on a zero-delta tick")

 var bare := {"home": Vector2(50, 0), "position": Vector2(50, 0), "active": true}
 var empty_tag := RingField.pattern_records([{"start": Vector2(100, 0), "end": Vector2(200, 0), "spacing": 100.0}], "legacy")
 empty_tag[0].rail_id = ""
 prepare([bare, empty_tag[0]], "")
 field._physics_process(0.0)
 check(pickups == [0, 1], "Legacy unowned records and empty rail tags retain floor pickup behavior")

 prepare(fixture())
 var switch_owner := func(index: int):
  if index == 0: field.active_owner_id = "b"
 field.pickup_claimed.connect(switch_owner)
 field._physics_process(0.0)
 check(pickups == [0, 1, 4, 9, 10], "Owner changes inside pickup signals finish the same sweep in original order")
 field.pickup_claimed.disconnect(switch_owner)
 prepare(fixture())
 var append_member := func(index: int):
  if index == 0: field.add_ring(Vector2(350, 0))
 field.pickup_claimed.connect(append_member)
 field._physics_process(0.0)
 check(pickups == [0, 3, 6, 7] and field.rings[11].active, "Signal-time additions preserve the sweep's original count and remaining indices")
 field.pickup_claimed.disconnect(append_member)
 prepare(fixture())
 var replace_and_rebuild := func(index: int):
  if index == 0:
   field.rings = fixture("b", "a")
   field.advance_racks(0.01)
 field.pickup_claimed.connect(replace_and_rebuild)
 field._physics_process(0.0)
 check(pickups == [0, 1, 4, 9, 10] and field.rings[0].active, "Same-size signal-time replacement and rebuild cannot leave a stale candidate list")
 field.pickup_claimed.disconnect(replace_and_rebuild)

 field.ball.free()
 field.tuning.free()
 field.free()
 print("RESULT | Ring pickup cache | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
