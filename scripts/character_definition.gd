class_name CharacterDefinition
extends Resource
## Data shared by selection, ability mechanics and presentation adapters.
@export var display_name := "Sonic"
@export var profile: PhysicsProfile
@export_enum("Homing Attack", "Tail Flight") var ability := 0
@export var description := ""
@export var color := Color("5fbaff")
@export var meter_capacity := 100.0
@export var meter_cost := 100.0
@export var ring_charge := 5.0
@export var bumper_charge := 2.0
@export var target_range := 400.0
@export var homing_speed := 1050.0
@export var impulse_limit := 2600.0
@export var hit_window := 0.65
@export var hit_multiplier := 5
@export var flight_duration := 1.6
@export var flight_fade := 0.35
@export var flight_lift_limit := 700.0
@export var flight_multipliers := {"gravity_scale": 0.25, "steering_acceleration": 1.6, "counter_steering_deceleration": 1.5, "max_steering_speed": 1.4}
