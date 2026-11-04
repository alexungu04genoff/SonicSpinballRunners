class_name TypeAction
extends Resource
## One shared tuning resource per type; characters only choose one and a profile.
enum Kind { SPEED, FLY, POWER }
@export var kind: Kind = Kind.SPEED
@export var action_name := "Target Dash"
@export_multiline var description := ""
@export var target_range := 400.0
@export var dash_speed := 520.0
@export var dash_acceleration := 2600.0
@export var dash_contact_speed := 180.0
@export var dash_exit_speed := 240.0
@export var dash_max_duration := 1.6
@export var flight_duration := 1.6
@export var flight_fade := 0.35
@export var flight_lift_limit := 700.0
@export var flight_multipliers := {"gravity_scale": 0.25, "steering_acceleration": 1.6, "counter_steering_deceleration": 1.5, "max_steering_speed": 1.4}
@export var smash_radius := 300.0

func type_id() -> String:
 return ["speed", "fly", "power"][kind]

func label() -> String:
 return "%s · %s" % [type_id().capitalize(), action_name]

func dash_duration(distance: float, away_speed: float) -> float:
 return clampf(0.35 + distance / maxf(1.0, dash_speed * 0.8) + maxf(0.0, away_speed) / maxf(1.0, dash_acceleration), 0.4, dash_max_duration)

func guided_velocity(velocity: Vector2, offset: Vector2, contact_radius: float, delta: float) -> Vector2:
 # Arrival slows toward the physical surface, never toward a teleport/snap point.
 var gap := maxf(0.0, offset.length() - contact_radius)
 var arrival_speed := minf(dash_speed, sqrt(dash_contact_speed * dash_contact_speed + 2.0 * dash_acceleration * gap))
 # Entry may brake an already excessive speed immediately; subsequent guidance
 # changes velocity by at most acceleration * dt and never adds a launch spike.
 return velocity.limit_length(dash_speed).move_toward(offset.normalized() * arrival_speed, dash_acceleration * delta).limit_length(dash_speed)
