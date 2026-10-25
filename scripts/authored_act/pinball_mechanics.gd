extends Node
## Authored mechanics run only through the authoritative ball's 120 Hz integration.
signal scoring_tick(object_id: String, points: int)
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const RailPath = preload("res://scripts/authored_act/rail_path.gd")
const MAX_FIELD_ACCELERATION := 600.0
const MAX_TICKS_PER_STEP := 2
var ball: PlaygroundBall
var items: Array[Dictionary] = []
var ramp: Dictionary = {}
var progress := 0.0
var speed := 0.0
var age := 0.0
var reentry_time := 0.0
var _saved_layer := 2
var _saved_mask := 1

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 ball.mechanics = self

func _exit_tree() -> void:
 reset()
 if is_instance_valid(ball) and ball.mechanics == self: ball.mechanics = null

func add_object(placement: Dictionary, descriptor: Dictionary) -> void:
 var item := placement.duplicate(true)
 item.properties = Objects.properties(placement)
 item["spin"] = 0.0
 item["angle"] = 0.0
 item["tick_rotation"] = 0.0
 item["cooldown"] = 0.0
 if item.type == "elevated_rail":
  var control: PackedVector2Array = item.properties.points.duplicate()
  for i in control.size(): control[i] = item.position + control[i].rotated(deg_to_rad(float(item.rotation_degrees)))
  item["path"] = RailPath.build(control)
 items.append(item)
 descriptor["mechanic"] = item

func reset() -> void:
 leave_ramp()
 reentry_time = 0.0
 for item: Dictionary in items:
  item.spin = 0.0
  item.angle = 0.0
  item.tick_rotation = 0.0
  item.cooldown = 0.0

func leave_ramp() -> void:
 if is_instance_valid(ball) and not ramp.is_empty():
  ball.collision_layer = _saved_layer
  ball.collision_mask = _saved_mask
  ball.gravity_scale = float(ball.tuning.effective.gravity_scale)
  ball.on_ramp = false
  ball.ramp_height = 0.0
 ramp = {}
 progress = 0.0
 speed = 0.0
 age = 0.0

func tick(dt: float) -> void:
 reentry_time = maxf(0.0, reentry_time - dt)
 var budget := MAX_TICKS_PER_STEP
 for item: Dictionary in items:
  item.cooldown = maxf(0.0, item.cooldown - dt)
  if item.type != "spinner": continue
  var rotation_step: float = item.spin * dt
  item.angle = fposmod(item.angle + rotation_step, TAU)
  item.tick_rotation += absf(rotation_step)
  item.spin *= exp(-float(item.properties.decay) * dt)
  if absf(item.spin) < 0.02: item.spin = 0.0
  var ticks := mini(budget, floori(item.tick_rotation / PI))
  # Discard excess complete rotations instead of building an event backlog.
  item.tick_rotation = fmod(item.tick_rotation, PI)
  for i in ticks:
   scoring_tick.emit(item.get("object_id", ""), int(item.properties.tick_score))
  budget -= ticks

static func magnetic_acceleration(item: Dictionary, at: Vector2) -> Vector2:
 var offset: Vector2 = item.position - at
 var distance := offset.length()
 var radius := float(item.properties.radius)
 if distance >= radius or distance < 0.001: return Vector2.ZERO
 # Smooth center clamp and outer falloff: no inverse-distance singularity or trap.
 var weight := minf(1.0, distance / maxf(8.0, radius * 0.2)) * (1.0 - distance / radius)
 return offset / distance * float(item.properties.strength) * weight * (-1.0 if item.properties.mode == "repel" else 1.0)

func apply_fields(state: PhysicsDirectBodyState2D) -> void:
 var acceleration := Vector2.ZERO
 for item: Dictionary in items:
  if item.type == "magnetic_field": acceleration += magnetic_acceleration(item, state.transform.origin)
 state.apply_central_impulse(acceleration.limit_length(MAX_FIELD_ACCELERATION) * ball.mass * state.step)

static func crossing_fraction(start: Vector2, end: Vector2, center: Vector2, forward: Vector2, half_width: float, one_way: bool) -> float:
 var a := (start - center).dot(forward)
 var b := (end - center).dot(forward)
 if one_way and not (a <= 0.0 and b > 0.0): return -1.0
 if not one_way and not ((a <= 0.0 and b > 0.0) or (a >= 0.0 and b < 0.0)): return -1.0
 var fraction := -a / (b - a)
 var sideways := Vector2(-forward.y, forward.x)
 if absf((start.lerp(end, fraction) - center).dot(sideways)) > half_width: return -1.0
 return fraction

func observe_motion(state: PhysicsDirectBodyState2D) -> bool:
 if items.is_empty(): return false
 var start := state.transform.origin
 var motion := state.linear_velocity * state.step
 var query := PhysicsTestMotionParameters2D.new()
 query.from = state.transform
 query.motion = motion
 var hit := PhysicsTestMotionResult2D.new()
 if PhysicsServer2D.body_test_motion(ball.get_rid(), query, hit): motion = hit.get_travel()
 var end := start + motion
 for item: Dictionary in items:
  if item.type == "spinner" and item.cooldown <= 0.0:
   var forward := Vector2.UP.rotated(deg_to_rad(float(item.rotation_degrees)))
   if crossing_fraction(start, end, item.position, forward, float(item.properties.width) * 0.5, false) >= 0.0:
    item.spin = clampf(float(item.spin) + state.linear_velocity.dot(forward) * 0.08, -float(item.properties.max_spin), float(item.properties.max_spin))
    item.cooldown = 0.08
  elif item.type == "elevated_rail" and reentry_time <= 0.0:
   var forward := RailPath.tangent(item.path, 0.0)
   var incoming := state.linear_velocity.dot(forward)
   if incoming < float(item.properties.entry_speed): continue
   if incoming / maxf(1.0, state.linear_velocity.length()) < 0.35: continue
   var fraction := crossing_fraction(start, end, item.path.points[0], forward, maxf(1.0, float(item.properties.width) * 0.5 - ball.radius), true)
   if fraction < 0.0: continue
   ramp = item
   speed = minf(incoming, 2400.0)
   progress = 0.0
   age = 0.0
   _saved_layer = ball.collision_layer
   _saved_mask = ball.collision_mask
   ball.collision_layer = 0
   ball.collision_mask = 0
   ball.gravity_scale = 0.0
   ball.on_ramp = true
   ball._reset_steering("Elevated rail")
   ball.flipper_launch_pending = false
   advance_ramp(state, state.step * (1.0 - fraction))
   return true
 return false

func advance_ramp(state: PhysicsDirectBodyState2D, dt: float) -> void:
 if ramp.is_empty(): return
 age += dt
 if age > 30.0:
  # Last-resort lifecycle reset for an externally obstructed mouth, never a rail exit.
  ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
  return
 var path: Dictionary = ramp.path
 var tangent := RailPath.tangent(path, progress)
 var rise := (RailPath.height(path, progress + 0.5, ramp.properties.height) - RailPath.height(path, progress - 0.5, ramp.properties.height))
 var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 700.0)) * float(ball.tuning.effective.gravity_scale)
 var metric := sqrt(1.0 + rise * rise)
 var acceleration := gravity * (tangent.y - rise) / metric
 # A weak shot can roll back. A stalled/very long ride eventually rolls to entry.
 if age > 12.0: acceleration = -180.0
 speed = (speed + acceleration * dt) * exp(-float(ramp.properties.drag) * dt)
 speed = clampf(speed, -2400.0, 2400.0)
 progress += speed * dt / metric
 var at_end: bool = progress >= path.length
 var at_start := progress <= 0.0 and speed < 0.0
 progress = clampf(progress, 0.0, path.length)
 var point := RailPath.sample(path, progress)
 state.transform = Transform2D(0.0, point)
 state.linear_velocity = Vector2.ZERO
 state.angular_velocity = 0.0
 ball.ramp_height = RailPath.height(path, progress, ramp.properties.height)
 if at_end or at_start:
  var outgoing := RailPath.tangent(path, progress) * speed
  if not _exit_clear(point):
   # A moving flipper may temporarily cover the mouth; reverse along the rail.
   speed = -maxf(80.0, absf(speed)) if at_end else maxf(80.0, absf(speed))
   return
  leave_ramp()
  reentry_time = 0.3
  state.linear_velocity = outgoing
  ball._previous_step_velocity = outgoing

func _exit_clear(point: Vector2) -> bool:
 var shape := CircleShape2D.new()
 shape.radius = ball.radius + 0.1
 var query := PhysicsShapeQueryParameters2D.new()
 query.shape = shape
 query.transform = Transform2D(0.0, point)
 query.collision_mask = _saved_mask
 query.exclude = [ball.get_rid()]
 return ball.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
