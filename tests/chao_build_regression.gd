extends SceneTree
## Bounded Zone builds use the same resolver as the single-slot Chao Lab.
var checks := 0
var failures := 0

func _initialize() -> void:
 var tuning := PhysicsTuning.new()
 var original := tuning.base.as_values()
 check(tuning.build_ids.is_empty() and tuning.chao_id == "none" and tuning.effective == original, "An empty build preserves the baseline")
 var chosen: Array[String] = ["ice", "spring", "magnet"]
 var expected := PhysicsTuning.resolve(tuning.base, {}, [PhysicsTuning.CHAO.ice.modifier, PhysicsTuning.CHAO.spring.modifier, PhysicsTuning.CHAO.magnet.modifier])
 check(tuning.preview_build(chosen) == expected and tuning.build_ids.is_empty(), "Draft previews combine modifiers without equipping")
 check(tuning.equip_build(chosen) and tuning.effective == expected, "Three different Chao combine through the existing resolver")
 chosen.clear()
 var exposed := tuning.build_ids
 exposed.clear()
 check(tuning.build_ids == ["ice", "spring", "magnet"], "Caller-owned arrays cannot mutate the equipped build")
 for iteration in 3:
  tuning.equip_build(tuning.build_ids)
  tuning.rebuild()
 check(tuning.effective == expected and tuning.base.as_values() == original, "Repeated restoration never adds duplicate modifier instances or mutates profiles")
 check(tuning.build_name() == "Ice Chao, Spring Chao, Magnet Chao" and tuning.chao_id == "magnet", "Build labels show every Chao while the legacy ID remains valid")
 check(tuning.add_chao("ice") and tuning.chao_count("ice") == 2 and tuning.effective.steering_acceleration == 4000 and tuning.effective.counter_steering_deceleration == 8000 and tuning.effective.max_steering_speed == 187.5, "A second Ice pick adds one bounded copy with centralized clamping")
 var retained := tuning.effective.duplicate()
 check(not tuning.can_add_chao("ice") and not tuning.add_chao("ice") and tuning.effective == retained and tuning.build_ids.size() == 4, "A third copy is rejected without changing the build")
 check(tuning.add_chao("magnet") and tuning.build_ids.size() == PhysicsTuning.MAX_BUILD_SLOTS and tuning.effective.ring_magnet_radius == 200, "A five-slot build supports a second Magnet pick")
 check(not tuning.add_chao("spring") and tuning.build_ids.size() == 5, "The five-slot limit rejects further rewards")
 var snapshot := tuning.build_ids
 check(not tuning.equip_build(["unknown"]) and not tuning.equip_build(["none"]) and not tuning.equip_build(["practice", "ice"]) and tuning.build_ids == snapshot, "Invalid and mixed Practice builds are rejected atomically")
 check(tuning.preview_build(["ice", "ice", "ice"]).is_empty() and tuning.build_ids == snapshot, "Invalid previews cannot alter equipment")
 tuning.select_profile(1)
 check(tuning.build_ids == snapshot and tuning.effective == tuning.preview_build(snapshot) and tuning.overrides.is_empty(), "Profile changes preserve the full build and resolve it afresh")
 tuning.set_value("ring_magnet_radius", 210)
 check(tuning.effective.ring_magnet_radius == 220, "Live overrides remain subject to the shared final clamp")
 tuning.modifier_enabled = true
 check(tuning.build_ids == ["practice"] and tuning.modifier_enabled and not tuning.can_add_chao("ice"), "Legacy Practice replaces the whole build and cannot join a draft stack")
 tuning.equip_chao("spring")
 tuning.modifier_enabled = false
 check(tuning.build_ids == ["spring"] and tuning.chao_id == "spring" and tuning.effective == tuning.preview_chao("spring"), "Single-slot selection replaces a build and stale Practice-off cannot remove it")
 tuning.clear_build()
 check(tuning.build_ids.is_empty() and tuning.chao_id == "none" and tuning.build_name() == "None" and tuning.effective == PhysicsTuning.resolve(tuning.base, tuning.overrides, []), "A new Zone clears acquired Chao without clearing profile or session tuning")
 tuning.equip_chao("practice")
 tuning.modifier_enabled = false
 check(tuning.build_ids.is_empty() and not tuning.modifier_enabled, "Legacy Practice-off restores an empty build")
 tuning.free()
 print("CHAO BUILD RESULT | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)
