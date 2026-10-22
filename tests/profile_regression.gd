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
	tuning.modifier_enabled = true
	tuning.set_value("gravity_scale", 1.8)
	tuning.select_profile(1)
	check(tuning.overrides.is_empty() and is_equal_approx(tuning.effective.gravity_scale, 0.58), "Profile switching clears overrides and selects Floaty")
	check(tuning.modifier_enabled, "Profile switching preserves the enabled practice modifier")
	tuning.modifier_enabled = false
	tuning.select_profile(0)
	check(tuning.effective == tuning.BALANCED.as_values(), "Removing modifier and selecting Balanced restores defaults")
	tuning.free()
	print("Profile regression checks: %d failures" % failures)
	quit(1 if failures else 0)

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
