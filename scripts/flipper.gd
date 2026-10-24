class_name PlaygroundFlipper
extends AnimatableBody2D

signal struck
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

func _physics_process(delta: float) -> void:
 if not enabled:
  return
 var pressed: bool = controls.left_held if side > 0.0 else controls.right_held
 if pressed and not held:
  swing_remaining = 0.11
  struck_this_swing = false
 held = pressed
 var old_tip: Vector2 = tip()
 rotation = move_toward(rotation, active_angle() if held else rest_angle(), (12.0 if held else 7.0) * delta)
 if swing_remaining > 0.0:
  swing_remaining -= delta
  if not struck_this_swing and not ball.serve_pending:
   var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(ball.global_position, global_position, tip())
   var old_nearest: Vector2 = Geometry2D.get_closest_point_to_segment(ball.global_position, global_position, old_tip)
   var distance: float = minf(ball.global_position.distance_to(nearest), ball.global_position.distance_to(old_nearest))
   if distance < RADIUS + PlaygroundBall.RADIUS + 9.0 and ball.global_position.y < global_position.y + 35.0:
    var leverage: float = clampf(nearest.distance_to(global_position) / length, 0.35, 1.0)
    var direction := Vector2(side * 0.25, -1.0).normalized()
    ball.apply_central_impulse(direction * float(tuning.effective.flipper_launch_strength) * (0.65 + 0.35 * leverage) * ball.mass)
    struck_this_swing = true
    strikes += 1
    struck.emit()
