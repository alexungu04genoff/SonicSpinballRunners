extends SceneTree
## Cached membership must preserve rack clocks and release replaced resident data.
class CountedField extends RingField:
 var eligibility_checks := 0
 func ring_eligible(ring: Dictionary) -> bool:
  eligibility_checks += 1
  return super.ring_eligible(ring)

var checks := 0
var failures := 0
var resets := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func patterns(owner: String, racks := 3, count := 8, offset := Vector2.ZERO) -> Array[Dictionary]:
 var trails: Array = []
 for i in racks:
  trails.append({"pattern_id": "rack_%d" % i, "start": Vector2(100, i * 100),
   "end": Vector2(100 + (count - 1) * 10, i * 100), "spacing": 10.0})
 return RingField.pattern_records(trails, owner, offset)

func retained_probe(field: RingField) -> WeakRef:
 var token := RefCounted.new()
 var records := patterns("probe", 1, 2)
 records[0].cache_probe = token
 var reference: WeakRef = weakref(token)
 field.rings = records
 field.active_owner_id = "probe"
 field.advance_racks(0.01)
 return reference

func run() -> void:
 var field := CountedField.new()
 field.rack_reset.connect(func(): resets += 1)
 field.rings = patterns("a") + patterns("b", 3, 8, Vector2(2000, 0)) + patterns("c", 3, 8, Vector2(4000, 0))
 field.active_owner_id = "a"
 for tick in 120: field.advance_racks(1.0 / 120.0)
 check(field.eligibility_checks == 3 * 120, "72 resident Rings require only three active rack eligibility checks per tick")
 var a: Dictionary = field.rings[0].rack
 var b: Dictionary = field.rings[24].rack
 field.claim_ring(0)
 field.advance_racks(1.25)
 check(is_equal_approx(a.timeout_remaining, 23.75) and b.timeout_remaining == -1.0, "Cached clocks advance once per rack and keep neighbor state untouched")
 field.active_owner_id = "b"
 field.claim_ring(24)
 field.advance_racks(2.0)
 check(is_equal_approx(a.timeout_remaining, 23.75) and b.timeout_remaining == 23.0, "Switching active owner immediately selects the other cached rack view")
 field.active_owner_id = "absent"
 field.advance_racks(30.0)
 check(a.timeout_remaining == 23.75 and b.timeout_remaining == 23.0, "An owner without resident racks cannot advance another Act's clocks")
 field.active_owner_id = "b"
 field.scoring_enabled = false
 field.advance_racks(9.0)
 field.scoring_enabled = true
 field.advance_racks(0.0)
 field.advance_racks(-1.0)
 check(b.timeout_remaining == 23.0, "Suspended, paused and negative-delta updates preserve exact timers")

 field.active_owner_id = ""
 field.collection_bounds = Rect2(field.rings[25].home - Vector2.ONE, Vector2.ONE * 2)
 b.timeout_remaining = 0.01
 var signal_before := resets
 field.advance_racks(0.02)
 var expired := true
 for i in range(24, 32): expired = expired and not field.rings[i].active
 check(expired and b.ready and resets == signal_before + 1 and a.timeout_remaining == 23.75, "Partial legacy bounds select an eligible member and hide the complete rack exactly once")
 field.rings[31].home += Vector2(3, 9)
 field.advance_racks(RingField.RESPAWN_FADE_SECONDS)
 var restored := true
 for i in range(24, 32): restored = restored and field.rings[i].active and field.rings[i].position == field.rings[i].home
 check(restored and b.remaining == 8 and resets == signal_before + 2, "Respawn reads live member data and restores the entire rack, including out-of-bounds members")

 field.rings.append_array(patterns("d"))
 field.active_owner_id = "d"
 check(field.claim_ring(72), "Directly appended resident Rings remain claimable")
 field.advance_racks(0.5)
 check(field.rings[72].rack.timeout_remaining == 24.5, "A changed list size lazily refreshes cached membership")
 var retired: Dictionary = field.rings[72].rack
 var replacement := patterns("replacement", 4, 24)
 check(replacement.size() == field.rings.size(), "Replacement fixture keeps the same Ring count")
 field.rings = replacement
 field.active_owner_id = "replacement"
 field.claim_ring(0)
 field.advance_racks(0.5)
 check(field.rings[0].rack.timeout_remaining == 24.5 and retired.timeout_remaining == 24.5, "Same-size assignment advances only the replacement rack and leaves retired state unchanged")
 var former: Dictionary = field.rings[0].rack
 field.invalidate_rack_cache() # The real resident synchronizer uses this bulk edit.
 field.rings.clear()
 field.rings.append_array(patterns("bulk", 4, 24))
 field.active_owner_id = "bulk"
 field.claim_ring(0)
 field.advance_racks(0.1)
 check(is_equal_approx(field.rings[0].rack.timeout_remaining, 24.9) and former.timeout_remaining == 24.5, "Same-size in-place resident rebuilds use the new rack dictionaries")

 field.rings.clear()
 field.add_ring(Vector2(100, 100))
 field.claim_ring(0)
 field.advance_racks(18.01)
 check(field.rings[0].rack.ready and not field.rings[0].active, "add_ring invalidates membership and retains the full-clear delay")
 field.advance_racks(0.35)
 check(field.rings[0].active and field.rings[0].rack.remaining == 1, "Single-ring rack respawn restores the cached member")
 var single: Dictionary = field.rings[0].rack
 field.rings.clear()
 field.add_ring(Vector2(900, 900))
 field.claim_ring(0)
 field.advance_racks(1.0)
 check(field.rings[0].rack.respawn_remaining == 17.0 and single.respawn_remaining == -1.0, "Clear/re-add at the same count discards the previous cache")
 field.rings.clear()
 field.add_pattern({"start": Vector2(100, 100), "end": Vector2(110, 100), "spacing": 10.0}, "new_pattern", "bulk")
 field.claim_ring(0)
 field.advance_racks(0.25)
 check(field.rings[0].rack.timeout_remaining == 24.75, "add_pattern refreshes cached membership")

 # Legacy repeated IDs use the first eligible state and whole-ID membership.
 var duplicate_a := patterns("same-a", 1)
 var duplicate_b := patterns("same-b", 1)
 duplicate_b[0].rack.id = duplicate_a[0].rack.id
 field.rings = duplicate_a + duplicate_b
 field.active_owner_id = "same-b"
 field.claim_ring(8)
 field.advance_racks(1.0)
 check(duplicate_b[0].rack.timeout_remaining == 24.0 and duplicate_a[0].rack.timeout_remaining == -1.0, "Repeated legacy IDs still select the active owner's actual state")
 field.advance_racks(24.0)
 check(field.rings.all(func(ring): return not ring.active), "Legacy duplicate-ID expiration retains the original complete-ID hide behavior")
 field.advance_racks(0.35)
 check(field.rings.all(func(ring): return ring.active) and duplicate_b[0].rack.remaining == 8, "Legacy duplicate-ID respawn restores all cached members exactly once")

 field.rings = [{"home": Vector2.ZERO, "position": Vector2.ZERO, "active": true}]
 field.active_owner_id = ""
 signal_before = resets
 field.advance_racks(1.0)
 check(field.rings[0].active and resets == signal_before, "Legacy Rings without rack records have no rack timer side effects")
 var reference := retained_probe(field)
 check(reference.get_ref() != null, "Resident records retain their own attached data")
 field.rings = []
 check(reference.get_ref() == null, "Replacing resident membership releases cached record data immediately")
 field.advance_racks(1.0)
 check(field.rings.is_empty(), "An empty resident list remains valid")
 field.free()
 print("RESULT | Ring rack cache | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
