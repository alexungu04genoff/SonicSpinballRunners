class_name PlaygroundFlipper
extends AnimatableBody2D

signal struck
signal shot_fired(contact_position: Vector2, impulse: Vector2, contact_fraction: float)
const LENGTH: float = 150.0
const RADIUS: float = 13.0
var length: float = LENGTH
var radius: float = RADIUS
var side: float = 1.0
var ball: PlaygroundBall
var controls: PlaygroundInput
var tuning: PhysicsTuning
var held: bool = false
var swing_remaining: float = 0.0
var struck_this_swing: bool = false
var strikes: int = 0
var enabled := true
## Optional authored rest rotation, in radians. NaN keeps the legacy table angles.
var authored_rest_angle: float = NAN

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
 capsule.radius = radius
 capsule.height = length + radius * 2.0
 collision.shape = capsule
 collision.position.x = length / 2.0
 collision.rotation = PI / 2.0
 add_child(collision)
 physics_material_override = PhysicsMaterial.new()
 physics_material_override.bounce = 0.15
 physics_material_override.friction = 0.0
 rotation = rest_angle()

func rest_angle() -> float:
 if is_finite(authored_rest_angle):
  return authored_rest_angle
 return 0.32 if side > 0.0 else PI - 0.32

func active_angle() -> float:
 if is_finite(authored_rest_angle):
  return authored_rest_angle - (0.8 if side > 0.0 else -0.8)
 return -0.48 if side > 0.0 else PI + 0.48

func tip() -> Vector2:
 return global_position + Vector2.RIGHT.rotated(rotation) * length

func strike_direction(_contact_fraction: float) -> Vector2:
 # The straight face normal depends on paddle angle, never heel/tip position.
 var axis := Vector2.RIGHT.rotated(rotation)
 return Vector2(axis.y, -axis.x) * side

static func launch_normal_speed(contact_fraction: float, stats: Dictionary) -> float:
 # A small arcade floor helps hinge recoveries without making the entire heel
 # nearly as powerful as the tip. Timing still comes from the moving surface.
 return float(stats.flipper_launch_strength) * lerpf(0.2, 1.0, clampf(contact_fraction, 0.0, 1.0))

static func assisted_velocity(incoming: Vector2, normal: Vector2, contact_fraction: float, stats: Dictionary) -> Vector2:
 # Top up only the outward component after native contact resolution. Preserve
 # tangential momentum and never add another full kick to an existing rebound.
 return incoming + normal * maxf(0.0, launch_normal_speed(contact_fraction, stats) - incoming.dot(normal))

func complete_strike(contact: Vector2, impulse: Vector2, fraction: float) -> void:
 strikes += 1
 struck.emit()
 shot_fired.emit(contact, impulse, fraction)

func _physics_process(delta: float) -> void:
 if not enabled:
  return
 var pressed: bool = controls.left_held if side > 0.0 else controls.right_held
 if pressed and not held:
  swing_remaining = absf(active_angle() - rest_angle()) / float(tuning.effective.flipper_swing_speed) + 0.04
  struck_this_swing = false
 if not pressed:
  swing_remaining = 0.0
 held = pressed
 var old_angle := rotation
 var old_tip: Vector2 = tip()
 rotation = move_toward(rotation, active_angle() if held else rest_angle(), (float(tuning.effective.flipper_swing_speed) if held else 7.0) * delta)
 if swing_remaining > 0.0:
  # Expire the contact window at the stop; assistance requires angular motion.
  if is_equal_approx(old_angle, rotation):
   swing_remaining = minf(swing_remaining, 2.0 * delta)
  swing_remaining -= delta
  if not struck_this_swing and not is_equal_approx(old_angle, rotation) and not ball.serve_pending and not ball.on_ramp and not ball._teleport_pending:
   var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(ball.global_position, global_position, tip())
   var old_nearest: Vector2 = Geometry2D.get_closest_point_to_segment(ball.global_position, global_position, old_tip)
   var old_is_closer := ball.global_position.distance_squared_to(old_nearest) < ball.global_position.distance_squared_to(nearest)
   var contact := old_nearest if old_is_closer else nearest
   var axis := Vector2.RIGHT.rotated(old_angle if old_is_closer else rotation)
   var upward_normal := Vector2(axis.y, -axis.x) * side
   var distance := ball.global_position.distance_to(contact)
   # Preserve the legacy contact allowance while scaling it with the actual ball.
   var contact_allowance := 9.0 * ball.radius / PlaygroundBall.RADIUS
   if distance < radius + ball.radius + contact_allowance and (ball.global_position - contact).dot(upward_normal) > 0.0:
    var fraction := clampf(contact.distance_to(global_position) / length, 0.0, 1.0)
    var normal := (ball.global_position - contact).normalized()
    var angular_speed := (rotation - old_angle) / delta
    var offset := contact - global_position
    var surface_velocity := Vector2(-offset.y, offset.x) * angular_speed
    # A ball already escaping the paddle must not receive a proximity boost.
    if (ball.linear_velocity - surface_velocity).dot(normal) >= 0.0:
     return
    if ball.request_flipper_strike(self, contact, normal, fraction):
     struck_this_swing = true
