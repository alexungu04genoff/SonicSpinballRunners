class_name PlaygroundFlipper
extends AnimatableBody2D

signal struck
signal shot_fired(contact_position: Vector2, impulse: Vector2, contact_fraction: float)
const LENGTH: float = 150.0
const RADIUS: float = 13.0
var length: float = LENGTH
var side: float = 1.0
var ball: PlaygroundBall
var controls: PlaygroundInput
var tuning: PhysicsTuning
var held: bool = false
var swing_remaining: float = 0.0
var struck_this_swing: bool = false
var strikes: int = 0
var enabled := true

func set_enabled(value: bool) -> void:
 enabled = value
 set_deferred("collision_layer", 1 if value else 0)
 set_deferred("collision_mask", 2 if value else 0)
 if not value:
  held = false
  swing_remaining = 0.0
  struck_this_swing = false
  rotation = rest_angle()

func _ready() -> void:
 collision_layer = 1
 collision_mask = 2
 sync_to_physics = false
 # The body's transform is driven at the fixed physics tick. Godot estimates its velocity.
 var collision := CollisionShape2D.new()
 var capsule := CapsuleShape2D.new()
 capsule.radius = RADIUS
 capsule.height = length + RADIUS * 2.0
 collision.shape = capsule
 collision.position.x = length / 2.0
 collision.rotation = PI / 2.0
 add_child(collision)
 physics_material_override = PhysicsMaterial.new()
 physics_material_override.bounce = 0.15
 physics_material_override.friction = 0.0
 rotation = rest_angle()

func rest_angle() -> float:
 return 0.32 if side > 0.0 else PI - 0.32

func active_angle() -> float:
 return -0.48 if side > 0.0 else PI + 0.48

func tip() -> Vector2:
 return global_position + Vector2.RIGHT.rotated(rotation) * length

func strike_direction(contact_fraction: float) -> Vector2:
 # Keep an upward arcade bias while letting heel/tip contact and swing timing aim.
 # The mirrored surface normal supplies orientation; strength stays in the resolver.
 var axis := Vector2.RIGHT.rotated(rotation)
 var normal := Vector2(axis.y, -axis.x) * side
 var normal_angle := atan2(normal.x * side, -normal.y)
 var inward_angle := clampf(0.12 + 0.45 * normal_angle + 0.5 * (0.65 - clampf(contact_fraction, 0.0, 1.0)), -0.18, 0.55)
 return Vector2.UP.rotated(side * inward_angle)

func _physics_process(delta: float) -> void:
 if not enabled:
  return
 var pressed: bool = controls.left_held if side > 0.0 else controls.right_held
 if pressed and not held:
  swing_remaining = 0.11
  struck_this_swing = false
 if not pressed:
  swing_remaining = 0.0
 held = pressed
 var old_angle := rotation
 var old_tip: Vector2 = tip()
 rotation = move_toward(rotation, active_angle() if held else rest_angle(), (12.0 if held else 7.0) * delta)
 if swing_remaining > 0.0:
  # A two-tick follow-through is forgiving without powering a stationary hold.
  if is_equal_approx(old_angle, rotation):
   swing_remaining = minf(swing_remaining, 2.0 * delta)
  swing_remaining -= delta
  if not struck_this_swing and not ball.serve_pending:
   var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(ball.global_position, global_position, tip())
   var old_nearest: Vector2 = Geometry2D.get_closest_point_to_segment(ball.global_position, global_position, old_tip)
   var old_is_closer := ball.global_position.distance_squared_to(old_nearest) < ball.global_position.distance_squared_to(nearest)
   var contact := old_nearest if old_is_closer else nearest
   var axis := Vector2.RIGHT.rotated(old_angle if old_is_closer else rotation)
   var upward_normal := Vector2(axis.y, -axis.x) * side
   var distance := ball.global_position.distance_to(contact)
   if distance < RADIUS + PlaygroundBall.RADIUS + 9.0 and (ball.global_position - contact).dot(upward_normal) > 0.0:
    var fraction := clampf(contact.distance_to(global_position) / length, 0.0, 1.0)
    var leverage := clampf(fraction, 0.35, 1.0)
    var impulse := strike_direction(fraction) * float(tuning.effective.flipper_launch_strength) * (0.65 + 0.35 * leverage) * ball.mass
    ball.apply_central_impulse(impulse)
    struck_this_swing = true
    strikes += 1
    struck.emit()
    shot_fired.emit(contact, impulse, fraction)
