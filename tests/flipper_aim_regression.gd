extends SceneTree
## Real falling bodies and button inputs. Each sample has one initial condition;
## no transform, velocity or force edits follow it. Geometry feeds are tested separately.
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for tick in count:
  await physics_frame

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func trial(side: float, fraction: float, trigger: float, mode: String = "timed", power_scale: float = 1.0, physical_scale: float = 1.0) -> Dictionary:
 var world := Node2D.new()
 root.add_child(world)
 var tuning := PhysicsTuning.new()
 var modifier := PhysicsModifier.new()
 modifier.multipliers = {"flipper_launch_strength": power_scale, "flipper_upward_speed_limit": power_scale}
 tuning.set_temporary("power_test", modifier)
 world.add_child(tuning)
 var controls := PlaygroundInput.new()
 controls.virtual_enabled = true
 world.add_child(controls)
 var ball := PlaygroundBall.new()
 ball.radius = PlaygroundBall.RADIUS * physical_scale
 ball.tuning = tuning
 ball.controls = controls
 var paddle := PlaygroundFlipper.new()
 paddle.length = 130.0 * physical_scale
 paddle.radius *= physical_scale
 paddle.side = side
 paddle.ball = ball
 paddle.controls = controls
 paddle.tuning = tuning
 world.add_child(paddle)
 var start := Vector2(side * 130.0 * fraction, -160.0)
 var velocity := Vector2.ZERO
 if mode == "underside":
  start = Vector2(side * 65.0, 55.0)
  velocity = Vector2(0.0, -250.0)
 elif mode == "released":
  # Arrive during the original 110ms window, after a one-tick press is released.
  start = Vector2(side * 84.5, -20.0)
  velocity = Vector2(0.0, 250.0)
 start *= physical_scale
 trigger *= physical_scale
 ball.position = start
 world.add_child(ball)
 ball.teleport_to(start, velocity)
 var result := {"side": side, "fraction": fraction, "trigger": trigger, "mode": mode, "power_scale": power_scale, "press_tick": -1, "shots": 0, "impulse": Vector2.ZERO, "contact_fraction": -1.0, "angle": 0.0, "rise": 0.0, "velocity": Vector2.ZERO, "passed_below": false}
 paddle.shot_fired.connect(func(_contact: Vector2, impulse: Vector2, contact_fraction: float) -> void:
  result.shots += 1
  result.impulse = impulse
  result.contact_fraction = contact_fraction
  result.angle = paddle.rotation)
 for tick in 360:
  var nearest := Geometry2D.get_closest_point_to_segment(ball.position, paddle.position, paddle.tip())
  if mode == "timed" and result.press_tick < 0 and ball.linear_velocity.y > 0.0 and ball.position.distance_to(nearest) < trigger:
   result.press_tick = tick
  var press: bool = result.press_tick >= 0 and tick - result.press_tick < 18
  if mode in ["early", "underside"]:
   press = tick < 18
  elif mode == "released":
   press = tick == 0
  elif mode == "hold":
   press = true
  elif mode == "none":
   press = false
  controls.virtual_left = press and side > 0.0
  controls.virtual_right = press and side < 0.0
  await frames(1)
  if result.shots > 0:
   result.rise = maxf(result.rise, -ball.position.y)
   if result.velocity == Vector2.ZERO and ball.linear_velocity.y < 0.0:
    result.velocity = ball.linear_velocity
  result.passed_below = result.passed_below or ball.position.y > 100.0
  if ball.position.y > 350.0:
   break
 print("AIM SHOT | ", result)
 world.free()
 await frames(2)
 return result

func run() -> void:
 var samples: Array[Dictionary] = []
 for side: float in [1.0, -1.0]:
  for fraction: float in [0.35, 0.65, 0.9]:
   for trigger: float in [43.0, 62.0]:
    var shot := await trial(side, fraction, trigger)
    # Preserve the original launch-energy threshold as gravity changes; the
    # independent 160-pixel traversal requirement still verifies a useful shot.
    var minimum_upward_speed := 200.0 * sqrt(PhysicsTuning.BALANCED.gravity_scale)
    check(shot.shots == 1 and shot.velocity.y < -minimum_upward_speed and shot.rise > 160.0, "Timed falling catch produces one useful upward strike: side %d / contact %.2f / trigger %.0f" % [side, fraction, trigger])
    var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity")) * PhysicsTuning.BALANCED.gravity_scale
    var maximum_rise := pow(PhysicsTuning.BALANCED.flipper_upward_speed_limit, 2) / (2.0 * gravity) + 100.0
    check(shot.rise < maximum_rise, "Moving-paddle collision and powered impulse cannot exceed bounded shot height")
    samples.append(shot)
 var mirrored := true
 for index in 6:
  var left: Vector2 = samples[index].impulse
  var right: Vector2 = samples[index + 6].impulse
  mirrored = mirrored and Vector2(-left.x, left.y).distance_to(right) < 0.1
 check(mirrored, "Physical mirrored catches produce mirrored impulses")
 var heel: Vector2 = samples[0].impulse.normalized()
 var tip: Vector2 = samples[4].impulse.normalized()
 var early_contact: Vector2 = samples[2].impulse.normalized()
 var later_contact: Vector2 = samples[3].impulse.normalized()
 check(absf(heel.angle_to(tip) - (samples[4].angle - samples[0].angle)) < 0.1, "Heel and tip aim differences follow contact angle, not position bias")
 check(absf(early_contact.angle_to(later_contact)) > deg_to_rad(4.0), "Changing the press timing changes a shot from the same falling trajectory")
 for mode: String in ["none", "early", "hold", "released", "underside"]:
  var miss := await trial(1.0, 0.65, 43.0, mode)
  check(miss.shots == 0 and miss.passed_below, "No powered recovery from %s; the ball remains free to fall" % mode)
 var spring := await trial(1.0, 0.65, 43.0, "timed", 1.35)
 check(spring.shots == 1 and spring.velocity.length() > samples[2].velocity.length(), "A power modifier increases the assisted shot without requiring additive impulse scaling")
 for side: float in [1.0, -1.0]:
  var compact := await trial(side, 0.65, 43.0, "timed", 1.0, 0.5)
  var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity")) * PhysicsTuning.BALANCED.gravity_scale
  var compact_height := pow(PhysicsTuning.BALANCED.flipper_upward_speed_limit, 2) * 0.5 / (2.0 * gravity)
  check(compact.shots == 1 and compact.rise > 80.0 and compact.rise < compact_height + 50.0, "Compact authored-scale flipper retains a useful shot without full-Act launch height")
 var output := FileAccess.open("res://test-results/flipper-aim-shots.json", FileAccess.WRITE)
 output.store_string(JSON.stringify(samples, " "))
 output.close()
 print("RESULT | Flipper aiming | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
