class_name PhysicsProfile
extends Resource
## Pixels, seconds, and a one-kilogram ball are the gameplay units.

@export var display_name: String = "Balanced"
@export_group("Steering")
@export var steering_acceleration: float = 1000.0
@export var counter_steering_deceleration: float = 1000.0
@export var max_steering_speed: float = 120.0
## Retained for resource/preset compatibility; persistent steering ignores release decay.
@export var steering_deceleration: float = 1400.0
@export var steering_strength: float = 0.065
@export_group("Movement")
@export var gravity_scale: float = 0.25
@export var max_downward_speed: float = 750.0
@export var rolling_acceleration: float = 20.0
@export var rolling_drag: float = 0.20
@export var max_rolling_speed: float = 450.0
@export_group("Collisions")
@export var flipper_launch_strength: float = 450.0
@export var flipper_upward_speed_limit: float = 525.0
@export var flipper_swing_speed: float = 8.5
@export var bumper_launch_speed: float = 420.0
@export var bumper_speed_limit: float = 500.0
@export var bumper_rebound_multiplier: float = 0.5
@export var wall_restitution: float = 0.60
@export_group("Collectibles and abilities")
@export var ring_magnet_radius: float = 50.0
@export var special_meter_charge_multiplier: float = 1.0

# key: [minimum, maximum, step, label, unit]. This is also the tuning UI schema.
const FIELDS: Dictionary = {
 "steering_acceleration": [0.0, 4000.0, 50.0, "Steering acceleration", "px/s²"],
 "counter_steering_deceleration": [0.0, 8000.0, 50.0, "Counter-steering deceleration", "px/s²"],
 "max_steering_speed": [0.0, 400.0, 5.0, "Steering contribution limit", "px/s"],
 "steering_deceleration": [0.0, 4000.0, 50.0, "Release deceleration (inactive)", "px/s²"],
 "steering_strength": [0.0, 0.3, 0.005, "Steering strength (0.065 = 6.5%)", "ratio"],
 "gravity_scale": [0.1, 2.0, 0.05, "Gravity scale", "×"],
 "max_downward_speed": [300.0, 3000.0, 50.0, "Maximum downward speed", "px/s"],
 "rolling_acceleration": [0.0, 500.0, 10.0, "Contact rolling acceleration", "px/s²"],
 "rolling_drag": [0.0, 3.0, 0.05, "Contact rolling drag", "1/s"],
 "max_rolling_speed": [100.0, 2000.0, 50.0, "Rolling assistance cutoff", "px/s"],
 "flipper_launch_strength": [200.0, 2200.0, 25.0, "Flipper launch impulse / mass", "px/s"],
 "flipper_upward_speed_limit": [100.0, 2200.0, 25.0, "Flipper upward speed limit", "px/s"],
 "bumper_launch_speed": [100.0, 1200.0, 20.0, "Bumper base rebound speed", "px/s"],
 "bumper_speed_limit": [100.0, 2200.0, 25.0, "Bumper rebound speed limit", "px/s"],
 "flipper_swing_speed": [4.0, 16.0, 0.5, "Flipper swing speed", "rad/s"],
 "bumper_rebound_multiplier": [0.25, 2.5, 0.05, "Bumper rebound multiplier", "×"],
 "wall_restitution": [0.0, 0.95, 0.05, "Wall restitution", "ratio"],
 "ring_magnet_radius": [0.0, 220.0, 5.0, "Ring magnet radius", "px"],
 "special_meter_charge_multiplier": [0.0, 5.0, 0.1, "Special meter charge", "×"],
}

func as_values() -> Dictionary:
 var result: Dictionary = {}
 for key in FIELDS:
  result[key] = float(get(key))
 return result
