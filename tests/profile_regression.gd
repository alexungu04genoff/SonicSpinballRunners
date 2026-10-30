extends SceneTree
## Run after a headless editor import: godot --headless --path . --script tests/profile_regression.gd

var failures: int = 0

func _initialize() -> void:
	var profile := PhysicsProfile.new()
	var before := profile.as_values()
	var resolved := PhysicsTuning.resolve(profile, {}, [])
	check(resolved == before, "Unmodified profile preserves defaults")
	var first := PhysicsModifier.new()
	first.additions = {"flipper_launch_strength": 50.0}
	first.multipliers = {"flipper_launch_strength": 1.2}
	var second := PhysicsModifier.new()
	second.additions = {"flipper_launch_strength": 100.0}
	second.multipliers = {"flipper_launch_strength": 0.5}
	var combined := PhysicsTuning.resolve(profile, {"flipper_launch_strength": 1000.0}, [first, second])
	check(is_equal_approx(combined.flipper_launch_strength, 690.0), "Overrides precede additive and multiplicative stacking")
	check(combined == PhysicsTuning.resolve(profile, {"flipper_launch_strength": 1000.0}, [second, first]), "Modifier order preserves the resolved result")
	check(is_equal_approx(PhysicsTuning.resolve(profile, {"wall_restitution": 9.0}, []).wall_restitution, 0.95), "Resolution clamps to field limits")
	check(profile.as_values() == before, "Resolution does not mutate shared profile data")
	var tuning := PhysicsTuning.new()
	tuning.set_temporary("first", first)
	tuning.set_temporary("second", second)
	check(tuning.effective == PhysicsTuning.resolve(tuning.base, {}, [first, second]), "Named temporary effects share the central resolver")
	tuning.set_temporary("first", first)
	check(tuning._temporary.size() == 2 and tuning.effective == PhysicsTuning.resolve(tuning.base, {}, [first, second]), "Replacing a named effect never compounds it")
	tuning.set_value("gravity_scale", 1.8)
	tuning.select_profile(1)
	check(tuning.overrides.is_empty() and is_equal_approx(tuning.effective.gravity_scale, tuning.FLOATY.gravity_scale), "Profile switching clears overrides and selects Floaty")
	check(tuning.effective == PhysicsTuning.resolve(tuning.FLOATY, {}, [first, second]), "Profile switching preserves active named effects")
	tuning.clear_temporary("first")
	check(tuning.effective == PhysicsTuning.resolve(tuning.FLOATY, {}, [second]), "Clearing one effect preserves the other")
	tuning.clear_temporary("first")
	check(tuning._temporary.size() == 1, "Clearing an absent effect is harmless")
	tuning.clear_temporary("second")
	tuning.select_profile(0)
	check(tuning.effective == tuning.BALANCED.as_values(), "Removing modifier and selecting Balanced restores defaults")
	tuning.free()
	print("Profile regression checks: %d failures" % failures)
	quit(1 if failures else 0)

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
