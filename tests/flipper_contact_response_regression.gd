extends SceneTree
## Deterministic contact-response contract. Falling-body timing is covered by flipper_aim_regression.
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void:
 var stats := PhysicsTuning.BALANCED.as_values()
 var left := PlaygroundFlipper.new()
 var right := PlaygroundFlipper.new()
 right.side = -1.0
 for timing in [0.0, 0.5, 1.0]:
  left.rotation = lerpf(left.rest_angle(), left.active_angle(), timing)
  right.rotation = lerpf(right.rest_angle(), right.active_angle(), timing)
  var axis := Vector2.RIGHT.rotated(left.rotation)
  var normal := left.strike_direction(0.0)
  for i in 11:
   var fraction := i / 10.0
   var direction := left.strike_direction(fraction)
   check(direction.is_equal_approx(normal) and absf(direction.dot(axis)) < 0.00001, "Position cannot reverse the face normal")
   var mirrored := right.strike_direction(fraction)
   check(Vector2(-direction.x, direction.y).is_equal_approx(mirrored), "Both hands mirror at all contact fractions and timings")
   var incoming := axis * 95.0 - normal * 150.0
   var outgoing := PlaygroundFlipper.assisted_velocity(incoming, normal, fraction, stats)
   check(is_equal_approx(outgoing.dot(axis), 95.0), "Incoming tangential momentum survives")
   check(is_equal_approx(outgoing.dot(normal), 340.0 * (0.2 + 0.8 * fraction)), "Corrective assist reaches the specified normal speed")
   var rebound := axis * -120.0 + normal * 500.0
   check(PlaygroundFlipper.assisted_velocity(rebound, normal, fraction, stats).is_equal_approx(rebound), "Native rebound does not receive a second full kick")
 check(is_equal_approx(PlaygroundFlipper.launch_normal_speed(0.0, stats), 68.0), "Hinge assist is 20 percent, not 77 percent")
 check(is_equal_approx(PlaygroundFlipper.launch_normal_speed(1.0, stats), 340.0), "Tip retains resolved profile power")
 var boosted := PhysicsTuning.resolve(PhysicsTuning.BALANCED, {}, [power_modifier()])
 check(is_equal_approx(PlaygroundFlipper.launch_normal_speed(0.6, boosted) / PlaygroundFlipper.launch_normal_speed(0.6, stats), 1.35), "Central modifier resolution applies once to assist target")
 var normal := left.strike_direction(0.5)
 var offset := 1.2
 left.rotation += offset
 check(left.strike_direction(0.5).is_equal_approx(normal.rotated(offset)), "Authored angle rotates contact direction without a world-up bias")
 var ball := PlaygroundBall.new()
 ball.serve_pending = false
 check(ball.request_flipper_strike(left, Vector2.ZERO, Vector2.UP, 0.5), "One pending strike accepted")
 check(not ball.request_flipper_strike(right, Vector2.ZERO, Vector2.UP, 0.5), "Two paddles cannot stack assistance in one physics step")
 ball.teleport_to(Vector2.ZERO)
 check(ball._flipper_strike.is_empty(), "Reset clears pending contact assistance")
 ball.free()
 left.free()
 right.free()
 call_deferred("run_trials")

func trial(side: float, fraction: float) -> Dictionary:
 var world := Node2D.new()
 root.add_child(world)
 var tuning := PhysicsTuning.new()
 world.add_child(tuning)
 var controls := PlaygroundInput.new()
 controls.virtual_enabled = true
 world.add_child(controls)
 var ball := PlaygroundBall.new()
 ball.radius = 7.0
 ball.tuning = tuning
 ball.controls = controls
 var paddle := PlaygroundFlipper.new()
 paddle.side = side
 paddle.length = 32.5
 paddle.radius = 2.5
 paddle.tuning = tuning
 paddle.controls = controls
 paddle.ball = ball
 world.add_child(paddle)
 world.add_child(ball)
 var axis := Vector2.RIGHT.rotated(paddle.rest_angle())
 var normal := paddle.strike_direction(fraction)
 var start := axis * paddle.length * fraction + normal * 10.5
 ball.teleport_to(start, -normal * 20.0)
 for i in 2: await physics_frame
 var result := {"shots": 0, "rise": 0.0, "velocity": Vector2.ZERO, "impulse": Vector2.ZERO, "contact_fraction": 0.0, "angle": 0.0}
 paddle.shot_fired.connect(func(_point, impulse, contact_fraction): result.shots += 1; result.impulse = impulse; result.contact_fraction = contact_fraction; result.angle = paddle.rotation)
 controls.virtual_left = side > 0
 controls.virtual_right = side < 0
 for i in 300:
  await physics_frame
  result.rise = maxf(result.rise, start.y - ball.position.y)
  if -ball.linear_velocity.y > -result.velocity.y: result.velocity = ball.linear_velocity
 check(result.shots == 1, "One powered contact at authored-scale fraction " + str(fraction))
 check(-result.velocity.y <= 400.0 * sqrt(0.5) + 2.0, "Authored ball retains the upward safety cap")
 print("AUTHORED CONTACT | side=", side, " fraction=", fraction, " ", result)
 world.free()
 await physics_frame
 return result

func run_trials() -> void:
 for side: float in [1.0, -1.0]:
  var heel := await trial(side, 0.05)
  var middle := await trial(side, 0.5)
  var tip := await trial(side, 0.95)
  check(heel.rise < middle.rise * 0.5 and heel.rise < tip.rise * 0.5, "Hinge contact is substantially weaker in actual authored-scale physics")
  check(tip.rise > middle.rise, "Outer contact provides more climbing power")
 # Exact mirrored response is checked above with matched contact states. Full
 # capsule-tip trajectories can diverge after native solver contacts, so enforce
 # power ordering and the shared speed cap on each hand independently instead.
 print("CONTACT RESPONSE | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func power_modifier() -> PhysicsModifier:
 var modifier := PhysicsModifier.new()
 modifier.multipliers = {"flipper_launch_strength": 1.35, "flipper_upward_speed_limit": 1.35}
 return modifier
