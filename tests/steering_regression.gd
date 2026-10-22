extends SceneTree
## Focused steering checks against real RigidBody2D integration. No test dependency.
var failures: int = 0
var checks: int = 0
var fixture: Node2D
var ball: PlaygroundBall
var controls: PlaygroundInput
var tuning: PhysicsTuning

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func measure(velocity: Vector2, axis: float, ticks: int = 30) -> Dictionary:
 controls.virtual_steering = 0.0
 # Isolate steering from gravity and board contacts; leave production profile intact.
 tuning.effective.gravity_scale = 0.0
 ball.teleport_to(Vector2(2000, 0), velocity)
 await frames(3)
 var initial: Vector2 = ball.linear_velocity
 controls.virtual_steering = axis
 await frames(ticks)
 return {"dx": ball.linear_velocity.x - initial.x, "dy": ball.linear_velocity.y - initial.y}

func run() -> void:
 fixture = Node2D.new()
 root.add_child(fixture)
 tuning = PhysicsTuning.new()
 fixture.add_child(tuning)
 controls = PlaygroundInput.new()
 fixture.add_child(controls)
 controls.virtual_enabled = true
 ball = PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 fixture.add_child(ball)
 var wall := StaticBody2D.new()
 wall.position = Vector2(-10000, 0)
 wall.collision_layer = 1
 wall.collision_mask = 2
 wall.physics_material_override = PhysicsMaterial.new()
 wall.physics_material_override.bounce = 0.72
 wall.physics_material_override.friction = 0.0
 var collision := CollisionShape2D.new()
 var capsule := CapsuleShape2D.new()
 capsule.radius = 12.0
 capsule.height = 2000.0
 collision.shape = capsule
 wall.add_child(collision)
 fixture.add_child(wall)

 # Quantify every preset using the same quarter-second counter-steering shot.
 for i in PhysicsTuning.STEERING_PRESETS.size():
  tuning.apply_steering_preset(i)
  var result: Dictionary = await measure(Vector2(-1400, 700), 1.0)
  print("PRESET | %s | 0.25 s counter delta vx=%.2f; remaining vx=%.2f; contribution=%.2f" % [PhysicsTuning.STEERING_PRESETS[i].name, result.dx, ball.linear_velocity.x, ball.steering_contribution])
 tuning.apply_steering_preset(2)
 var ascending: Dictionary = await measure(Vector2(0, -700), 1.0)
 var descending: Dictionary = await measure(Vector2(0, 700), 1.0)
 check(ascending.dx > 40 and absf(ascending.dx - descending.dx) < 0.1 and absf(ascending.dy) < 0.1 and absf(descending.dy) < 0.1, "Same steering response while ascending and descending; vertical momentum survives")
 var aligned_left: Dictionary = await measure(Vector2(-1400, -300), -1.0)
 var aligned_right: Dictionary = await measure(Vector2(1400, 300), 1.0)
 check(aligned_left.dx < -40 and aligned_right.dx > 40 and absf(aligned_left.dx + aligned_right.dx) < 0.1, "Aligned steering adds symmetrically to existing horizontal momentum")
 var counter_left: Dictionary = await measure(Vector2(-1400, 700), 1.0)
 var counter_right: Dictionary = await measure(Vector2(1400, -700), -1.0)
 check(counter_left.dx > 80 and counter_right.dx < -80 and absf(counter_left.dx + counter_right.dx) < 0.1 and ball.linear_velocity.x > 1200, "Counter-steering slows both directions more strongly without cancelling the launch")
 await measure(Vector2(-1400, 0), 1.0, 180)
 var capped_velocity: float = ball.linear_velocity.x
 await frames(60)
 check(absf(capped_velocity + 1220) < 0.1 and absf(ball.linear_velocity.x - capped_velocity) < 0.1 and ball.steering_at_limit and is_zero_approx(ball.steering_impulse_applied), "Contribution cap stops continuous braking; total speed is not capped")
 controls.virtual_steering = 0.0
 await frames(120)
 check(absf(ball.linear_velocity.x + 1400) < 0.1 and absf(ball.steering_contribution) < 0.01, "Release removes only assistance, restoring external momentum")
 await measure(Vector2(-1400, 0), -1.0, 60)
 var before_reverse: float = ball.linear_velocity.x
 controls.virtual_steering = 1.0
 await frames(30)
 check(ball.linear_velocity.x - before_reverse > 80 and ball.linear_velocity.x < -1200 and ball.steering_acceleration_applied > 350, "Reversing input begins braking immediately despite a negative contribution")

 # A strong counter rate changes to the normal rate at zero horizontal velocity.
 var stats: Dictionary = tuning.effective.duplicate()
 var next: float = PlaygroundBall.steering_step(0.0, 1.0, stats, 1.0 / 120.0, -1.0)
 var at60: float = 0.0
 var at120: float = 0.0
 for i in 60:
  at60 = PlaygroundBall.steering_step(at60, 1.0, stats, 1.0 / 60.0, -100.0 + at60)
 for i in 120:
  at120 = PlaygroundBall.steering_step(at120, 1.0, stats, 1.0 / 120.0, -100.0 + at120)
 check(absf(next - 2.0) < 0.001 and absf(at60 - at120) < 0.001, "Counter rate does not power through zero; 60/120 Hz results agree")

 controls.virtual_steering = -1.0
 ball.teleport_to(Vector2(-9850, 0), Vector2(-1800, 0))
 var old_sweeps: int = ball.sweep_rebounds
 for i in 30:
  await frames(1)
  if ball.sweep_rebounds > old_sweeps:
   break
 await frames(3)
 var after_rebound: bool = ball.sweep_rebounds > old_sweeps and ball.linear_velocity.x > 1100 and ball.steering_mode == "Counter" and ball.steering_impulse_applied < 0 and ball.steering_last_reset == "Sweep rebound"
 controls.virtual_steering = 1.0
 await frames(3)
 check(after_rebound and ball.steering_mode == "Normal" and ball.steering_impulse_applied > 0, "Steering resets its ledger at a real rebound, then follows reversed input")
 controls.virtual_steering = -1.0
 ball.teleport_to(Vector2(-9958, 0), Vector2(-400, 0))
 await frames(14)
 check(ball.steering_last_reset == "2D contact" and ball.linear_velocity.x > 150 and ball.steering_impulse_applied < 0, "Native low-speed contact resets bookkeeping without disabling counter-steering")

 await measure(Vector2(0, -300), 1.0, 15)
 var contribution_before: float = ball.steering_contribution
 tuning.select_profile(1)
 var preserved: bool = is_equal_approx(ball.steering_contribution, contribution_before)
 ball.apply_central_impulse(Vector2(700, -600))
 tuning.effective.gravity_scale = 0.0
 await frames(3)
 check(preserved and ball.steering_contribution >= contribution_before and ball.linear_velocity.x > 700 and ball.linear_velocity.y < -890, "Profile switch and external launch impulse preserve the steering ledger and momentum")

 # Exercise mapped keyboard/joypad events, including raw versus deadzone-adjusted input.
 controls.virtual_enabled = false
 var key := InputEventKey.new()
 key.physical_keycode = KEY_RIGHT
 key.pressed = true
 Input.parse_input_event(key)
 await frames(2)
 var keyboard_axis: float = controls.steering
 key.pressed = false
 Input.parse_input_event(key)
 var joy := InputEventJoypadMotion.new()
 joy.axis = JOY_AXIS_LEFT_X
 joy.axis_value = 1.0
 Input.parse_input_event(joy)
 await frames(2)
 var full_stick_matches: bool = is_equal_approx(controls.steering, keyboard_axis) and keyboard_axis == 1.0
 joy.axis_value = 0.1
 Input.parse_input_event(joy)
 await frames(2)
 check(full_stick_matches and absf(controls.raw_steering - 0.1) < 0.01 and is_zero_approx(controls.steering), "Keyboard and full stick agree; telemetry exposes stick input inside the deadzone")
 joy.axis_value = 0.0
 Input.parse_input_event(joy)
 controls.virtual_enabled = true
 controls.virtual_steering = 1.0
 controls.input_blocked = true
 ball.teleport_to(Vector2(2000, 0), Vector2.ZERO)
 await frames(3)
 check(controls.raw_steering == 1.0 and controls.steering == 0.0 and ball.steering_block_reason == "Editing a numeric field" and is_zero_approx(ball.steering_impulse_applied), "Blocked input remains visible and explains why no new steering is applied")
 print("RESULT | %d steering checks | %d failures" % [checks, failures])
 fixture.queue_free()
 await frames(3)
 quit(0 if failures == 0 else 1)
