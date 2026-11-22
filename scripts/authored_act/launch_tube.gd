extends Node2D
## Act-owned constrained motion for the real ball. Presentation never drives this state.
signal exited(position: Vector2, velocity: Vector2)
const Path = preload("res://scripts/authored_act/rail_path.gd")
enum Phase { DOCKED, CHARGING, OUTBOUND, RETURNING, IDLE }
var properties: Dictionary
var path: Dictionary
var ball: PlaygroundBall
var phase := Phase.IDLE
var contained := false
var charge := 0.0
var distance := 0.0
var speed := 0.0
var require_release := true
var visual_time := 0.0
var exit_flash := 0.0
var feedback := "Hold Launch, then release"
var _saved_layer := 2
var _saved_mask := 1

func configure(values: Dictionary) -> void:
 properties = values.duplicate(true)
 path = Path.build(properties.points)

## Visual rolling speed while the constrained body has zero physics velocity.
func roll_velocity() -> Vector2:
 var rolling_speed := charge * float(properties.max_speed) if phase == Phase.CHARGING else speed
 return global_transform.basis_xform(Path.tangent(path, distance)).normalized() * rolling_speed

func dock_position() -> Vector2:
 return to_global(Path.sample(path, 0.0))

func dock(player: PlaygroundBall) -> void:
 if is_instance_valid(player.launch_tube): player.launch_tube.detach()
 ball = player
 _saved_layer = ball.collision_layer
 _saved_mask = ball.collision_mask
 ball.launch_tube = self
 contained = true
 ball.freeze = false
 ball.serve_pending = true
 ball.release_pending = false
 ball._teleport_pending = false
 ball.on_ramp = false
 ball.gravity_scale = 0.0
 ball.collision_layer = 0
 ball.collision_mask = 0
 ball.linear_velocity = Vector2.ZERO
 ball.angular_velocity = 0.0
 ball._reset_steering("Launch Tube dock")
 ball._contact_cooldowns.clear()
 ball._flipper_strike.clear()
 ball.flipper_launch_pending = false
 ball.serve_position = dock_position()
 ball._teleport_position = ball.serve_position
 ball.position = ball.serve_position
 _redock()

func _redock() -> void:
 phase = Phase.DOCKED
 distance = 0.0
 speed = 0.0
 charge = 0.0
 require_release = true
 feedback = "Release Launch, then hold for a fresh charge"
 ball.ramp_height = 0.0

func detach() -> void:
 if is_instance_valid(ball) and ball.launch_tube == self:
  ball.collision_layer = _saved_layer
  ball.collision_mask = _saved_mask
  ball.gravity_scale = float(ball.tuning.effective.gravity_scale)
  ball.ramp_height = 0.0
  ball.launch_tube = null
 contained = false
 phase = Phase.IDLE
 charge = 0.0

func _exit_tree() -> void:
 detach()

func _process(delta: float) -> void:
 visual_time += delta
 exit_flash = maxf(0.0, exit_flash - delta)

func integrate(state: PhysicsDirectBodyState2D, delta: float) -> void:
 advance(delta, ball.controls.launch_held(), ball.controls.input_blocked)
 var point := to_global(Path.sample(path, distance))
 state.transform = Transform2D(0.0, point)
 state.angular_velocity = 0.0
 state.linear_velocity = Vector2.ZERO
 ball._teleport_pending = false
 ball._teleport_position = point
 ball._previous_step_velocity = Vector2.ZERO
 ball.steering_acceleration_applied = 0.0
 ball.steering_impulse_applied = 0.0
 ball.steering_block_reason = "Contained in Launch Tube"
 if phase == Phase.OUTBOUND and distance >= float(path.length):
  var direction := global_transform.basis_xform(Path.tangent(path, path.length)).normalized()
  if exit_is_clear(point, direction):
   var velocity := direction * maxf(0.0, speed)
   detach()
   ball.serve_pending = false
   ball.release_pending = false
   ball._reset_steering("Launch Tube exit")
   ball._previous_step_velocity = velocity
   ball.transfer_serial += 1
   if is_instance_valid(ball.mechanics): ball.mechanics.reset_motion()
   state.linear_velocity = velocity
   exit_flash = 0.28
   feedback = "Launch Tube exit"
   ball.launched.emit(velocity)
   exited.emit(point, velocity)
  else:
   phase = Phase.RETURNING
   speed = 0.0
   feedback = "Exit blocked — returning safely to dock"

func advance(delta: float, held: bool, input_blocked := false) -> void:
 # The release latch survives death/transfer. A held button cannot become a new press.
 if phase in [Phase.DOCKED, Phase.CHARGING]:
  if input_blocked:
   phase = Phase.DOCKED
   charge = 0.0
   require_release = true
   return
  if require_release:
   if not held:
    require_release = false
    feedback = "Hold Launch to charge; release to fire"
   return
  if held:
   phase = Phase.CHARGING
   charge = minf(1.0, charge + delta / float(properties.charge_seconds))
   feedback = "Launch Tube charge %d%%" % roundi(charge * 100.0)
  elif phase == Phase.CHARGING:
   speed = lerpf(float(properties.min_speed), float(properties.max_speed), charge)
   phase = Phase.OUTBOUND
   feedback = "Launch Tube traversal"
 elif phase == Phase.OUTBOUND:
  # Constant authored resistance gives weak shots a real stopping distance.
  var duration := minf(delta, speed / float(properties.resistance))
  distance = minf(float(path.length), distance + speed * duration - 0.5 * float(properties.resistance) * duration * duration)
  speed = maxf(0.0, speed - float(properties.resistance) * duration)
  if speed <= 0.0 and distance < float(path.length):
   phase = Phase.RETURNING
   feedback = "Weak launch — rolling back to dock"
 elif phase == Phase.RETURNING:
  speed = move_toward(speed, -float(properties.return_speed), float(properties.return_speed) * 2.0 * delta)
  distance = maxf(0.0, distance + speed * delta)
  if distance <= 0.0: _redock()

func exit_is_clear(point: Vector2, direction: Vector2) -> bool:
 return preload("res://scripts/authored_act/gimmick_geometry.gd").release_clear(ball, _saved_mask, point, direction)
