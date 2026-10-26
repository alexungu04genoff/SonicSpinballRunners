extends Node
## Isolated production-physics catches; never changes live gameplay or source Acts.
signal changed
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const Dimensions = preload("res://scripts/act_dimensions.gd")
class ProbeInput extends PlaygroundInput:
 func _ready() -> void:
  # Reuse virtual controls without registering global keyboard/joypad actions.
  virtual_enabled = true
  set_process_unhandled_input(false)

var shots: Array[Dictionary] = []
var busy := false
var status := ""
var _timeout := 2.0
var _key: Array = []
var _generation := 0
var _viewport: SubViewport
var _trials: Array[Dictionary] = []
var _elapsed := 0.0

func _ready() -> void:
 set_physics_process(false)

func request(item: Dictionary, cell_size: float, resolved_stats: Dictionary = {}, spawn_context: Dictionary = {}) -> void:
 var stats := PhysicsTuning.resolve(PhysicsTuning.BALANCED, {}, []) if resolved_stats.is_empty() else resolved_stats.duplicate(true)
 # Generic catches ignore translation. Spawn catches depend on the entire Act.
 var key := [item.type, float(item.rotation_degrees), cell_size, stats]
 if not spawn_context.is_empty():
  key.append([spawn_context.document.fingerprint(), item, spawn_context.index, spawn_context.target])
 if key == _key: return
 _key = key.duplicate(true)
 _generation += 1
 set_physics_process(false)
 shots.clear()
 busy = true
 status = ""
 var context := spawn_context.duplicate()
 if not context.is_empty(): context.document = context.document.duplicate(true)
 _restart.call_deferred(_generation, item.duplicate(true), cell_size, stats, context)

func _restart(generation: int, item: Dictionary, cell_size: float, stats: Dictionary, context: Dictionary) -> void:
 if generation != _generation: return
 if not context.is_empty():
  # Avoid rebuilding full Act collision geometry on every pointer-drag event.
  await get_tree().create_timer(0.12).timeout
  if generation != _generation: return
 set_physics_process(false)
 if is_instance_valid(_viewport):
  remove_child(_viewport)
  _viewport.queue_free()
  _viewport = null
 _trials.clear()
 shots.clear()
 _viewport = SubViewport.new()
 _viewport.size = Vector2i(2, 2)
 _viewport.world_2d = World2D.new()
 _viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
 _viewport.disable_3d = true
 add_child(_viewport)
 if not context.is_empty():
  _start_spawn(item, stats, context)
  return
 _timeout = 2.0
 var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 700.0)) * float(stats.gravity_scale)
 for sample: Dictionary in [{"label": "Typical", "gap": 0.12}, {"label": "Early", "gap": 0.27}, {"label": "Late", "gap": 0.02}]:
  var tuning := PhysicsTuning.new()
  tuning.effective = stats.duplicate(true)
  _viewport.add_child(tuning)
  var controls := ProbeInput.new()
  _viewport.add_child(controls)
  var ball := PlaygroundBall.new()
  ball.radius = Dimensions.BALL_RADIUS_CELLS * cell_size
  ball.tuning = tuning
  ball.controls = controls
  var paddle := PlaygroundFlipper.new()
  paddle.side = 1.0 if item.type == "left_flipper" else -1.0
  paddle.authored_rest_angle = deg_to_rad(float(item.rotation_degrees))
  paddle.length = Dimensions.FLIPPER_LENGTH_CELLS * cell_size
  paddle.radius = Dimensions.FLIPPER_RADIUS_CELLS * cell_size
  paddle.position = Vector2(_trials.size() * 10000.0, 0)
  paddle.ball = ball
  paddle.tuning = tuning
  paddle.controls = controls
  _viewport.add_child(paddle)
  _viewport.add_child(ball)
  var start := paddle.position + Vector2.RIGHT.rotated(paddle.rotation) * paddle.length * 0.65
  start += Vector2.UP * (ball.radius + paddle.radius + cell_size * 0.6)
  ball.teleport_to(start, Vector2.DOWN * sqrt(2.0 * maxf(gravity, 0.0) * cell_size))
  _trials.append({"label": sample.label, "ball": ball, "paddle": paddle, "controls": controls,
   "trigger": ball.radius + paddle.radius + cell_size * float(sample.gap),
   "pressed_at": -1.0, "done": false, "path": PackedVector2Array(), "gravity_scale": stats.gravity_scale, "spawn": false})
 _elapsed = 0.0
 set_physics_process(true)
 changed.emit()

func _physics_process(delta: float) -> void:
 _elapsed += delta
 var finished := 0
 for trial: Dictionary in _trials:
  if trial.done:
   finished += 1
   continue
  var ball: PlaygroundBall = trial.ball
  var paddle: PlaygroundFlipper = trial.paddle
  if ball._teleport_pending: continue
  var nearest := Geometry2D.get_closest_point_to_segment(ball.global_position, paddle.global_position, paddle.tip())
  var distance := ball.global_position.distance_to(nearest)
  var should_press: bool = ball.linear_velocity.y > 0.0 and distance <= trial.trigger
  if trial.spawn:
   var axis := Vector2.RIGHT.rotated(paddle.rotation)
   var fraction := clampf((ball.global_position - paddle.global_position).dot(axis) / paddle.length, 0.0, 1.0)
   var normal := Vector2(axis.y, -axis.x) * paddle.side
   var on_face := (ball.global_position - nearest).dot(normal) > 0.0
   trial.landed = trial.landed or (ball.get_colliding_bodies().has(paddle) and on_face)
   should_press = trial.landed and on_face and distance <= trial.trigger and absf(fraction - trial.target) <= 0.035
   if paddle.strikes == 0 and Engine.get_physics_frames() % 3 == 0:
    trial.approach.append(ball.position - paddle.position)
  if trial.pressed_at < 0.0 and should_press:
   trial.pressed_at = _elapsed
   trial.controls.virtual_left = paddle.side > 0.0
   trial.controls.virtual_right = paddle.side < 0.0
  if paddle.strikes > 0:
   trial.path.append(ball.position - paddle.position)
   # Include native paddle contact and follow-through before extrapolating free flight.
   if is_equal_approx(paddle.rotation, paddle.active_angle()) and distance > ball.radius + paddle.radius + 2.0:
    shots.append({"label": trial.label, "origin": ball.position - paddle.position,
     "velocity": ball.linear_velocity, "gravity_scale": trial.gravity_scale,
     "path_prefix": trial.path, "approach": trial.get("approach", PackedVector2Array()),
     "actual_fraction": trial.get("actual_fraction", -1.0), "target_fraction": trial.get("target", -1.0)})
    trial.done = true
  if _elapsed >= _timeout or (trial.spawn and ball.position.y > trial.drain_y):
   trial.done = true
  if trial.done:
   ball.freeze = true
   paddle.set_physics_process(false)
   trial.controls.set_physics_process(false)
   finished += 1
 if finished == _trials.size():
  if shots.is_empty(): status = "Target contact was not reached from spawn without steering." if _trials[0].spawn else "No catch in this falling-ball setup at this angle."
  _finish()

func _finish() -> void:
 busy = false
 set_physics_process(false)
 _trials.clear()
 if is_instance_valid(_viewport):
  remove_child(_viewport)
  _viewport.queue_free()
  _viewport = null
 changed.emit()

func _start_spawn(item: Dictionary, stats: Dictionary, context: Dictionary) -> void:
 var document: Resource = context.document
 if document.spawn_position == null:
  status = "Set a Spawn point to preview this drop."
  _finish()
  return
 var index: int = context.index
 if index >= 0 and index < document.gameplay_objects.size():
  document.gameplay_objects[index] = item.duplicate(true)
 else:
  index = document.gameplay_objects.size()
  document.gameplay_objects.append(item.duplicate(true))
 var tuning := PhysicsTuning.new()
 tuning.effective = stats.duplicate(true)
 _viewport.add_child(tuning)
 var controls := ProbeInput.new()
 _viewport.add_child(controls)
 var ball := PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 _viewport.add_child(ball)
 var compiled := Compiler.compile(document, tuning, controls, ball)
 if not compiled.error.is_empty():
  status = "Preview blocked: use Verify to resolve Act errors."
  _finish()
  return
 _viewport.add_child(compiled.root)
 var paddle: PlaygroundFlipper = compiled.objects[index].body
 var trial := {"label": "Spawn", "ball": ball, "paddle": paddle, "controls": controls,
  # Match the production contact allowance after the ball has landed once.
  "trigger": ball.radius + paddle.radius + 9.0 * ball.radius / PlaygroundBall.RADIUS,
  "pressed_at": -1.0, "done": false, "spawn": true,
  "landed": false, "target": float(context.target), "actual_fraction": -1.0,
  "path": PackedVector2Array(), "approach": PackedVector2Array(), "gravity_scale": stats.gravity_scale,
  "drain_y": float(document.grid_size.y + 2) * float(document.cell_size)}
 paddle.shot_fired.connect(func(_point: Vector2, _impulse: Vector2, fraction: float): trial.actual_fraction = fraction)
 _trials.append(trial)
 ball.teleport_to(document.spawn_position, Vector2.ZERO)
 var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 700.0)) * float(stats.gravity_scale)
 _timeout = clampf(4.0 + sqrt(2.0 * maxf(0.0, paddle.position.y - document.spawn_position.y) / maxf(1.0, gravity)), 4.0, 12.0)
 _elapsed = 0.0
 set_physics_process(true)
 changed.emit()
