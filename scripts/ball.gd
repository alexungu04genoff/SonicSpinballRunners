class_name PlaygroundBall
extends RigidBody2D

signal bumper_hit(collider: Node)
signal physical_impact(collider: Node2D, normal: Vector2, speed: float)
signal launch_started
signal launched(impulse: Vector2)
const RADIUS: float = 14.0
## Generated tables keep the legacy radius; authored Acts set their cell-relative size.
var radius: float = RADIUS:
 set(value):
  radius = value
  if _collision_circle != null:
   _collision_circle.radius = radius
var _collision_circle: CircleShape2D
var mechanics: Node
var on_ramp := false
## Elevation in physics pixels, consumed only by collisionless presentation.
var ramp_height := 0.0
var tuning: PhysicsTuning
var controls: PlaygroundInput
var steering_contribution: float = 0.0
var steering_acceleration_applied: float = 0.0
var steering_impulse_applied: float = 0.0
var steering_target: float = 0.0
var steering_at_limit: bool = false
var steering_mode: String = "Idle"
var steering_block_reason: String = "Waiting for launch"
var steering_last_reset: String = "None"
var steering_reset_age: float = 0.0
var serve_pending: bool = true
var release_pending := false
var serve_position: Vector2 = Vector2(665, 1120)
var _teleport_pending: bool = false
var _teleport_position: Vector2
var _teleport_velocity: Vector2
var _contact_cooldowns: Dictionary = {}
var bumper_hit_count: int = 0
var sweep_rebounds: int = 0
var _previous_step_velocity := Vector2.ZERO
var flipper_launch_pending := false
var _motion_query := PhysicsTestMotionParameters2D.new()
var _motion_result := PhysicsTestMotionResult2D.new()

func _ready() -> void:
 mass = 1.0
 lock_rotation = true
 can_sleep = false
 continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
 contact_monitor = true
 max_contacts_reported = 12
 collision_layer = 2
 collision_mask = 1
 linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
 linear_damp = 0.0
 var shape := CollisionShape2D.new()
 _collision_circle = CircleShape2D.new()
 _collision_circle.radius = radius
 shape.shape = _collision_circle
 add_child(shape)
 physics_material_override = PhysicsMaterial.new()
 physics_material_override.friction = 0.0
 physics_material_override.bounce = 0.0

func teleport_to(where: Vector2, velocity: Vector2 = Vector2.ZERO, waiting: bool = false) -> void:
 # Reset/serve and explicit rail constraints own full velocity replacement.
 if is_instance_valid(mechanics): mechanics.reset()
 _teleport_position = where
 _teleport_velocity = velocity
 _teleport_pending = true
 serve_pending = waiting
 release_pending = false
 flipper_launch_pending = false
 _reset_steering("Serve / reset")
 steering_acceleration_applied = 0.0
 steering_impulse_applied = 0.0
 _contact_cooldowns.clear()

func launch() -> void:
 if serve_pending and not release_pending:
  release_pending = true
  launch_started.emit()

static func steering_step(previous: float, axis: float, stats: Dictionary, dt: float, horizontal_velocity: float = 0.0) -> float:
 # Neutral input preserves momentum already added by steering. Only active input
 # changes this ledger; contacts and explicit resets can clear it separately.
 if absf(axis) <= 0.01:
  return previous
 var target: float = axis * float(stats.max_steering_speed)
 var rate: float = stats.steering_acceleration
 if is_counter_steering(previous, axis, stats, horizontal_velocity):
  var brake_rate: float = float(stats.counter_steering_deceleration) * float(stats.steering_strength)
  var next: float = move_toward(previous, target, brake_rate * dt)
  # A stronger braking rate must not carry through zero into a powered reversal.
  # Spend only the remaining fraction of this tick at the normal acceleration rate.
  if brake_rate > 0.0 and absf(next - previous) > absf(horizontal_velocity):
   var remaining: float = maxf(0.0, dt - absf(horizontal_velocity) / brake_rate)
   return move_toward(previous - horizontal_velocity, target, float(stats.steering_acceleration) * float(stats.steering_strength) * remaining)
  return next
 return move_toward(previous, target, rate * float(stats.steering_strength) * dt)

static func is_counter_steering(previous: float, axis: float, stats: Dictionary, horizontal_velocity: float) -> bool:
 var target: float = axis * float(stats.max_steering_speed)
 return absf(axis) > 0.01 and axis * horizontal_velocity < 0.0 and (target - previous) * horizontal_velocity < 0.0

func _reset_steering(reason: String) -> void:
 steering_contribution = 0.0
 steering_at_limit = false
 if steering_block_reason == "Contribution target reached":
  steering_block_reason = ""
 steering_last_reset = reason
 steering_reset_age = 0.0

func _apply_steering(state: PhysicsDirectBodyState2D, stats: Dictionary) -> void:
 var axis: float = controls.steering
 steering_target = axis * float(stats.max_steering_speed)
 steering_mode = "Counter" if axis * state.linear_velocity.x < 0.0 else "Normal"
 if axis * (steering_target - steering_contribution) < 0.0:
  steering_mode = "Trim"
 if absf(axis) <= 0.01:
  steering_mode = "Coast" if absf(steering_contribution) > 0.001 else "Idle"
  steering_target = steering_contribution
 var next: float = steering_step(steering_contribution, axis, stats, state.step, state.linear_velocity.x)
 steering_impulse_applied = (next - steering_contribution) * mass
 steering_acceleration_applied = (next - steering_contribution) / state.step
 state.apply_central_impulse(Vector2(steering_impulse_applied, 0.0))
 steering_contribution = next
 steering_at_limit = absf(axis) > 0.01 and is_equal_approx(next, steering_target)
 steering_block_reason = controls.steering_block_reason
 if steering_block_reason.is_empty():
  if float(stats.steering_strength) <= 0.0:
   steering_block_reason = "Strength is zero"
  elif steering_at_limit:
   steering_block_reason = "Contribution target reached"
  elif is_zero_approx(steering_impulse_applied):
   steering_block_reason = "No command / deadzone" if absf(axis) <= 0.01 else "Selected acceleration rate is zero"

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
 steering_reset_age += state.step
 steering_acceleration_applied = 0.0
 steering_impulse_applied = 0.0
 if _teleport_pending:
  state.transform = Transform2D(0.0, _teleport_position)
  state.linear_velocity = _teleport_velocity
  state.angular_velocity = 0.0
  _previous_step_velocity = _teleport_velocity
  _teleport_pending = false
 if is_instance_valid(mechanics):
  mechanics.tick(state.step)
  if on_ramp:
   mechanics.advance_ramp(state, state.step)
   return
 if serve_pending:
  # Waiting at serve is an explicit reset state, not an active physics trajectory.
  # Clear residual contact recovery after a long teleport until launch releases it.
  state.transform = Transform2D(0.0, _teleport_position)
  state.linear_velocity = Vector2.ZERO
  state.angular_velocity = 0.0
  gravity_scale = 0.0
  steering_mode = "Idle"
  steering_target = 0.0
  steering_at_limit = false
  steering_block_reason = "Waiting for launch"
  if release_pending:
   release_pending = false
   serve_pending = false
   gravity_scale = tuning.effective.gravity_scale
   # The serve releases into ordinary gravity. Flippers supply the first shot.
   launched.emit(Vector2.ZERO)
  return
 var stats: Dictionary = tuning.effective
 gravity_scale = stats.gravity_scale
 var dt: float = state.step
 for id: int in _contact_cooldowns.keys():
  _contact_cooldowns[id] -= dt
  if _contact_cooldowns[id] <= 0.0:
   _contact_cooldowns.erase(id)

 # A collision absorbs the assist ledger into physical momentum. Never undo a rebound.
 if state.get_contact_count() > 0:
  _reset_steering("2D contact")
 _apply_steering(state, stats)

 # Terminal fall limiter acts only downward. Upward and lateral launch speeds survive.
 var excess: float = maxf(0.0, state.linear_velocity.y - float(stats.max_downward_speed))
 if excess > 0.0:
  state.apply_central_impulse(Vector2(0.0, -excess * mass))
 var flipper_contact := flipper_launch_pending
 flipper_launch_pending = false
 var rolling_applied: bool = false
 for index in state.get_contact_count():
  var collider: Object = state.get_contact_collider_object(index)
  if not is_instance_valid(collider):
   continue
  flipper_contact = flipper_contact or collider is PlaygroundFlipper
  var normal: Vector2 = state.get_contact_local_normal(index).normalized()
  # Native contact resolution can already have stopped or bounced the body.
  # Use its previous physics-step approach speed, not the resolved remainder.
  var approach := maxf(0.0, -(_previous_step_velocity - state.get_contact_collider_velocity_at_position(index)).dot(normal))
  # An impulse applied between steps can hit a touching wall immediately. The
  # solver's contact impulse supplies that impact even before a velocity sample.
  approach = maxf(approach, absf(state.get_contact_impulse(index).dot(normal)) / mass)
  physical_impact.emit(collider, normal, approach)
  if collider.has_meta("bumper"):
   var id: int = collider.get_instance_id()
   if not _contact_cooldowns.has(id):
    _contact_cooldowns[id] = 0.16
    var outward_speed: float = state.linear_velocity.dot(normal)
    var desired := bumper_rebound_speed(approach, stats)
    # Native restitution may already exceed the tuned rebound. Remove that
    # excess as well as supplying lift, matching the swept collision response.
    state.apply_central_impulse(normal * (desired - outward_speed) * mass)
    bumper_hit_count += 1
    bumper_hit.emit(collider)
  elif not rolling_applied and normal.y < -0.15:
   rolling_applied = true
   var tangent := Vector2(-normal.y, normal.x)
   var tangent_speed: float = state.linear_velocity.dot(tangent)
   var slope: float = Vector2.DOWN.dot(tangent)
   if absf(tangent_speed) < float(stats.max_rolling_speed):
    state.apply_central_impulse(tangent * slope * float(stats.rolling_acceleration) * mass * dt)
   state.apply_central_impulse(-tangent * tangent_speed * (1.0 - exp(-float(stats.rolling_drag) * dt)) * mass)
 if is_instance_valid(mechanics):
  mechanics.apply_fields(state)
  if mechanics.observe_motion(state): return
 _guard_fast_motion(state)
 if flipper_contact or flipper_launch_pending:
  # Moving paddles contribute native collision velocity in addition to the
  # powered impulse. Bound their combined upward result, not other free flight.
  # Speed squared determines ballistic height: scale height with physical size.
  var launch_limit := float(stats.flipper_upward_speed_limit) * sqrt(radius / RADIUS)
  var excess_upward := maxf(0.0, -state.linear_velocity.y - launch_limit)
  state.apply_central_impulse(Vector2(0.0, excess_upward * mass))
 flipper_launch_pending = false
 _previous_step_velocity = state.linear_velocity

static func bumper_rebound_speed(incoming_speed: float, stats: Dictionary) -> float:
 return minf(maxf(float(stats.bumper_launch_speed), incoming_speed * 0.85), float(stats.bumper_speed_limit)) * float(stats.bumper_rebound_multiplier)

func _guard_fast_motion(state: PhysicsDirectBodyState2D) -> void:
 # Native CCD remains enabled. A conservative shape sweep handles thin-rail misses
 # observed on this Godot build. Rebound occurs at most one physics tick early.
 # The query uses actual 2D collision shapes, including moving flippers.
 var motion: Vector2 = state.linear_velocity * state.step
 if motion.length() < radius * 0.5:
  return
 _motion_query.from = state.transform
 _motion_query.motion = motion
 _motion_query.margin = 0.08 * radius / RADIUS
 if not PhysicsServer2D.body_test_motion(get_rid(), _motion_query, _motion_result):
  return
 var normal: Vector2 = _motion_result.get_collision_normal()
 var relative: Vector2 = state.linear_velocity - _motion_result.get_collider_velocity()
 var incoming: float = relative.dot(normal)
 if incoming >= 0.0:
  return
 var collider: Object = _motion_result.get_collider()
 if is_instance_valid(collider):
  physical_impact.emit(collider, normal, -incoming)
 var restitution: float = tuning.effective.wall_restitution
 if collider is PlaygroundFlipper:
  restitution = 0.15
  flipper_launch_pending = true
 var outgoing: float = -incoming * restitution
 if is_instance_valid(collider) and collider.has_meta("bumper"):
  outgoing = bumper_rebound_speed(-incoming, tuning.effective)
  var id: int = collider.get_instance_id()
  if not _contact_cooldowns.has(id):
   _contact_cooldowns[id] = 0.16
   bumper_hit_count += 1
   bumper_hit.emit(collider)
 _reset_steering("Sweep rebound")
 state.apply_central_impulse(normal * (outgoing - incoming) * mass)
 sweep_rebounds += 1
