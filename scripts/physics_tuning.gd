class_name PhysicsTuning
extends Node

signal changed
const BALANCED = preload("res://data/balanced.tres")
const FLOATY = preload("res://data/floaty.tres")
const TAILS = preload("res://data/tails.tres")
const KNUCKLES = preload("res://data/knuckles.tres")
const SHADOW = preload("res://data/shadow.tres")
const PROFILES := [BALANCED, FLOATY, TAILS, KNUCKLES, SHADOW]
# Session experiments. Character resources start with half-strength steering.
const STEERING_PRESETS: Array[Dictionary] = [
 {"name": "Original (6.5%)", "values": {"steering_strength": 0.065, "steering_acceleration": 1000.0, "counter_steering_deceleration": 1000.0, "max_steering_speed": 120.0, "steering_deceleration": 1400.0}},
 {"name": "Quick / tight", "values": {"steering_strength": 0.1, "steering_acceleration": 2200.0, "counter_steering_deceleration": 4000.0, "max_steering_speed": 120.0, "steering_deceleration": 3000.0}},
 {"name": "Air control", "values": {"steering_strength": 0.1, "steering_acceleration": 1800.0, "counter_steering_deceleration": 3600.0, "max_steering_speed": 180.0, "steering_deceleration": 2200.0}},
 {"name": "Stronger brake", "values": {"steering_strength": 0.1, "steering_acceleration": 2000.0, "counter_steering_deceleration": 6000.0, "max_steering_speed": 220.0, "steering_deceleration": 2600.0}},
 {"name": "Light / half strength", "values": {"steering_strength": 0.05, "steering_acceleration": 2200.0, "counter_steering_deceleration": 4000.0, "max_steering_speed": 120.0, "steering_deceleration": 3000.0}},
]
var base: PhysicsProfile = BALANCED
var overrides: Dictionary = {}
var _temporary: Dictionary = {}
var effective: Dictionary = {}

func _init() -> void:
 rebuild()

static func resolve(profile: PhysicsProfile, changes: Dictionary, modifiers: Array) -> Dictionary:
 var values: Dictionary = profile.as_values()
 for key in values:
  var value: float = float(changes.get(key, values[key]))
  var addition: float = 0.0
  var multiplier: float = 1.0
  for modifier: PhysicsModifier in modifiers:
   addition += float(modifier.additions.get(key, 0.0))
   multiplier *= float(modifier.multipliers.get(key, 1.0))
  var spec: Array = PhysicsProfile.FIELDS[key]
  values[key] = clampf((value + addition) * multiplier, spec[0], spec[1])
 return values

func rebuild() -> void:
 var modifiers: Array[PhysicsModifier] = []
 modifiers.append_array(_temporary.values())
 effective = resolve(base, overrides, modifiers)
 changed.emit()

func set_temporary(key: String, modifier: PhysicsModifier) -> void:
 _temporary[key] = modifier
 rebuild()

func clear_temporary(key: String) -> void:
 if _temporary.erase(key):
  rebuild()

func use_profile(profile: PhysicsProfile) -> void:
 base = profile
 overrides.clear()
 rebuild()

func select_profile(index: int) -> void:
 use_profile(PROFILES[clampi(index, 0, PROFILES.size() - 1)])

func set_value(key: String, value: float) -> void:
 overrides[key] = value
 rebuild()

func editable_value(key: String) -> float:
 return float(overrides.get(key, base.get(key)))

func apply_steering_preset(index: int) -> void:
 for key: String in STEERING_PRESETS[index].values:
  overrides[key] = STEERING_PRESETS[index].values[key]
 rebuild()
