class_name CharacterDefinition
extends Resource
## Data shared by selection, ability mechanics and presentation adapters.
@export var display_name := "Sonic"
@export var profile: PhysicsProfile
@export_enum("Homing Attack", "Tail Flight", "Glide + Shockwave", "Chaos Blast") var ability := 0
@export var selection_label := ""
@export var description := ""
@export var color := Color("5fbaff")
@export var ball_color := Color("075dd2")
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
@export var glide_duration := 0.85
@export var glide_speed := 650.0
@export var glide_impulse_limit := 950.0
@export var glide_min_impact_speed := 180.0
@export var glide_multipliers := {"steering_acceleration": 1.4, "counter_steering_deceleration": 1.3, "max_steering_speed": 1.3}
@export var shockwave_width := 360.0
@export var shockwave_range := 500.0
@export var shockwave_multiplier := 2
@export var blast_radius := 300.0
