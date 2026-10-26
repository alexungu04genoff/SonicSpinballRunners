extends Node
## Isolated production-physics catches. No authored geometry or live gameplay state.
signal changed
const Dimensions = preload("res://scripts/act_dimensions.gd")
class ProbeInput extends PlaygroundInput:
 func _ready() -> void:
  # Reuse virtual controls without registering global keyboard/joypad actions.
  virtual_enabled = true
  set_process_unhandled_input(false)

var shots: Array[Dictionary] = []
var busy := false
var _key: Array = []
var _generation := 0
var _viewport: SubViewport
var _trials: Array[Dictionary] = []
var _elapsed := 0.0

func _ready() -> void:
 set_physics_process(false)

func request(item: Dictionary, cell_size: float, resolved_stats: Dictionary = {}) -> void:
 var stats := PhysicsTuning.resolve(PhysicsTuning.BALANCED, {}, []) if resolved_stats.is_empty() else resolved_stats.duplicate(true)
 # Translation, selection identity and zoom do not change a catch.
 var key := [item.type, float(item.rotation_degrees), cell_size, stats]
 if key == _key: return
 _key = key.duplicate(true)
 _generation += 1
 set_physics_process(false)
 shots.clear()
 busy = true
 _restart.call_deferred(_generation, item.duplicate(true), cell_size, stats)

func _restart(generation: int, item: Dictionary, cell_size: float, stats: Dictionary) -> void:
 if generation != _generation: return
 set_physics_process(false)
 if is_instance_valid(_viewport):
  remove_child(_viewport)
  _viewport.queue_free()
 _trials.clear()
 shots.clear()
 _viewport = SubViewport.new()
 _viewport.size = Vector2i(2, 2)
 _viewport.world_2d = World2D.new()
 _viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
 _viewport.disable_3d = true
 add_child(_viewport)
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
   "pressed_at": -1.0, "done": false, "path": PackedVector2Array(), "gravity_scale": stats.gravity_scale})
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
  if trial.pressed_at < 0.0 and ball.linear_velocity.y > 0.0 and distance <= trial.trigger:
   trial.pressed_at = _elapsed
   trial.controls.virtual_left = paddle.side > 0.0
   trial.controls.virtual_right = paddle.side < 0.0
  if paddle.strikes > 0:
   trial.path.append(ball.position - paddle.position)
   # Include native paddle contact and follow-through before extrapolating free flight.
   if is_equal_approx(paddle.rotation, paddle.active_angle()) and distance > ball.radius + paddle.radius + 2.0:
    shots.append({"label": trial.label, "origin": ball.position - paddle.position,
     "velocity": ball.linear_velocity, "gravity_scale": trial.gravity_scale,
     "path_prefix": trial.path})
    trial.done = true
  if _elapsed >= 2.0:
   trial.done = true
  if trial.done:
   ball.freeze = true
   paddle.set_physics_process(false)
   trial.controls.set_physics_process(false)
   finished += 1
 if finished == _trials.size():
  busy = false
  set_physics_process(false)
  _trials.clear()
  remove_child(_viewport)
  _viewport.queue_free()
  _viewport = null
  changed.emit()
