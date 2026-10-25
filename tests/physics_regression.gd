extends SceneTree
## Run: Godot --headless --path <project> --script res://tests/physics_regression.gd
var failures: int = 0
var checks: int = 0
var game: Node
var fixture: Node2D
var test_ball: PlaygroundBall
var test_input: PlaygroundInput
var test_tuning: PhysicsTuning

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String, detail: String = "") -> void:
 checks += 1
 if condition:
  print("PASS | ", label, " | ", detail)
 else:
  failures += 1
  push_error("FAIL | " + label + " | " + detail)

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func run() -> void:
 var profile := PhysicsProfile.new()
 var modifier := PhysicsModifier.new()
 modifier.additions = {"steering_acceleration": 100.0}
 modifier.multipliers = {"steering_acceleration": 1.5}
 var resolved: Dictionary = PhysicsTuning.resolve(profile, {}, [modifier, modifier])
 check(is_equal_approx(resolved.steering_acceleration, 2700.0), "Additions then multiplicative stacking")
 check(is_equal_approx(profile.steering_acceleration, 1000.0), "Base resource remains unchanged")
 resolved = PhysicsTuning.resolve(profile, {"steering_acceleration": 3999.0}, [modifier, modifier])
 check(is_equal_approx(resolved.steering_acceleration, 4000.0), "Extreme modifiers clamp to field limits")
 var assist60: float = 0.0
 var assist120: float = 0.0
 for i in 60:
  assist60 = PlaygroundBall.steering_step(assist60, 1.0, profile.as_values(), 1.0 / 60.0)
 for i in 120:
  assist120 = PlaygroundBall.steering_step(assist120, 1.0, profile.as_values(), 1.0 / 120.0)
 check(absf(assist60 - assist120) < 0.001 and absf(assist120 - 65.0) < 0.001, "6.5% steering calibration at 60/120 Hz", str(assist120))

 fixture = Node2D.new()
 root.add_child(fixture)
 test_tuning = PhysicsTuning.new()
 test_tuning.apply_steering_preset(0) # Keep the original 6.5% calibration fixture.
 fixture.add_child(test_tuning)
 test_input = PlaygroundInput.new()
 fixture.add_child(test_input)
 test_input.virtual_enabled = true
 test_ball = PlaygroundBall.new()
 test_ball.tuning = test_tuning
 test_ball.controls = test_input
 test_ball.position = Vector2(2000, 0)
 fixture.add_child(test_ball)
 test_tuning.effective.gravity_scale = 0.0
 test_ball.teleport_to(Vector2(2000, 0), Vector2(1400, -300))
 await frames(3)
 test_input.virtual_steering = 1.0
 await frames(120)
 check(test_ball.linear_velocity.x > 1460 and test_ball.linear_velocity.x < 1470, "Steering adds to launch momentum", str(test_ball.linear_velocity))
 check(absf(test_ball.linear_velocity.y + 300.0) < 0.1, "Steering preserves vertical momentum")
 await frames(240)
 check(test_ball.steering_contribution <= 120.01 and test_ball.linear_velocity.x > 1510, "Only steering contribution is capped", str(test_ball.linear_velocity))
 test_input.virtual_steering = 0
 await frames(180)
 check(absf(test_ball.linear_velocity.x - 1400.0) < 1.0, "Release removes assist without erasing launch momentum", str(test_ball.linear_velocity))
 test_ball.teleport_to(Vector2(2000, 0), Vector2(1400, 0))
 test_input.virtual_steering = -1
 await frames(120)
 check(test_ball.linear_velocity.x > 1325 and test_ball.linear_velocity.x < 1345, "Opposite steering does not clamp external speed", str(test_ball.linear_velocity))
 test_input.virtual_steering = 0
 test_tuning.select_profile(0)
 test_ball.teleport_to(Vector2(2000, 0), Vector2(0, -500))
 await frames(121)
 var balanced_y: float = test_ball.position.y
 var balanced_vy: float = test_ball.linear_velocity.y
 test_tuning.select_profile(1)
 test_ball.teleport_to(Vector2(2000, 0), Vector2(0, -500))
 await frames(121)
 var gravity_difference := float(ProjectSettings.get_setting("physics/2d/default_gravity")) * (test_tuning.BALANCED.gravity_scale - test_tuning.FLOATY.gravity_scale)
 check(absf((balanced_y - test_ball.position.y) - 0.5 * gravity_difference) < 5.0 and absf((balanced_vy - test_ball.linear_velocity.y) - gravity_difference) < 5.0, "Floaty trajectory follows the profile gravity difference over one second", "Balanced y=%.1f vy=%.1f; Floaty y=%.1f vy=%.1f" % [balanced_y, balanced_vy, test_ball.position.y, test_ball.linear_velocity.y])
 test_ball.teleport_to(Vector2(2000, 0), Vector2(900, 4000))
 await frames(4)
 check(test_ball.linear_velocity.y <= test_tuning.FLOATY.max_downward_speed + 10.0 and test_ball.linear_velocity.x > 890, "Floaty terminal fall limit preserves lateral velocity", str(test_ball.linear_velocity))
 fixture.queue_free()
 await frames(3)

 game = load("res://scenes/playground.tscn").instantiate()
 game.generation_enabled = false # Preserve exact legacy geometry for existing shot fixtures.
 root.add_child(game)
 await frames(5)
 check(game.ball.position.distance_to(game.ball.serve_position) < 1.0, "Serve marker does not overlap geometry", str(game.ball.position))
 check(not contains_3d_collision(game.presentation), "Presentation contains no 3D collision objects")
 var mapping_error: float = TablePresentation.unmap_point(TablePresentation.map_point(Vector2(234.5, 678.9))).distance_to(Vector2(234.5, 678.9))
 check(mapping_error < 0.001, "2D/3D mapping round trip", str(mapping_error))
 game.set_physics_process(false)
 game.controls.virtual_enabled = false
 Input.action_press("left_flipper")
 Input.action_press("right_flipper")
 await frames(12)
 check(absf(game.flippers[0].rotation - game.flippers[0].active_angle()) < 0.01 and absf(game.flippers[1].rotation - game.flippers[1].active_angle()) < 0.01, "Both input actions actuate flippers simultaneously within 100 ms")
 Input.action_release("left_flipper")
 Input.action_release("right_flipper")
 await frames(18)
 check(absf(game.flippers[0].rotation - game.flippers[0].rest_angle()) < 0.01 and absf(game.flippers[1].rotation - game.flippers[1].rest_angle()) < 0.01, "Both flippers return after release")
 game.controls.virtual_enabled = true
 game.tuning.effective.gravity_scale = 0.0
 game.ball.teleport_to(Vector2(310, 1240), Vector2(0, 100))
 await frames(3)
 game.controls.virtual_left = true
 await frames(12)
 check(game.flippers[0].strikes > 0 and game.ball.linear_velocity.y < -300, "Left flipper launches an approaching ball", str(game.ball.linear_velocity))
 game.controls.virtual_left = false
 await frames(20)
 game.ball.teleport_to(Vector2(490, 1240), Vector2(0, 100))
 await frames(3)
 game.controls.virtual_right = true
 await frames(12)
 check(game.flippers[1].strikes > 0 and game.ball.linear_velocity.y < -300, "Right flipper launches an approaching ball", str(game.ball.linear_velocity))
 game.controls.virtual_right = false
 await frames(20)

 for speed: float in [1800.0, 4000.0, 8000.0]:
  game.ball.teleport_to(Vector2(150, 600), Vector2(-speed, 0))
  await frames(8)
  check(game.ball.position.x > 68 and game.ball.linear_velocity.x > 0, "CCD rebounds from left rail at %d px/s" % speed, str(game.ball.position) + " " + str(game.ball.linear_velocity))
 for start_y: float in [685.0, 700.0, 715.0]:
  game.ball.teleport_to(Vector2(650, start_y), Vector2(4000, 0))
  await frames(8)
  check(game.ball.position.x < 732 and game.ball.linear_velocity.x < 0, "Chunk seam side wall is closed at y=%d" % start_y, str(game.ball.position))
 game.ball.teleport_to(Vector2(300, 660), Vector2(0, 1000))
 await frames(12)
 check(game.ball.position.y > 745 and absf(game.ball.linear_velocity.y - 1000) < 2, "Open connector crosses downward without snagging", str(game.ball.position))
 game.ball.teleport_to(Vector2(300, 740), Vector2(0, -1000))
 await frames(12)
 check(game.ball.position.y < 650 and absf(game.ball.linear_velocity.y + 1000) < 2, "Open connector crosses upward without snagging", str(game.ball.position))
 var hits_before: int = game.ball.bumper_hit_count
 var score_before: int = game.score
 game.ball.teleport_to(Vector2(260, 240), Vector2(0, 1400))
 await frames(12)
 check(game.ball.bumper_hit_count > hits_before and game.ball.linear_velocity.y < 0, "Circular bumper rebounds and emits gameplay event", str(game.ball.linear_velocity))
 check(game.score > score_before, "Bumper hit increases score")
 hits_before = game.ball.bumper_hit_count
 game.ball.teleport_to(Vector2(205, 900), Vector2(0, 1200))
 await frames(18)
 check(game.ball.bumper_hit_count > hits_before, "Triangle bumper has solid collision")
 hits_before = game.ball.bumper_hit_count
 game.ball.teleport_to(Vector2(130, 350), Vector2(8000, 0))
 await frames(4)
 check(game.ball.bumper_hit_count > hits_before and game.ball.position.x < 317, "Shape sweep catches circular bumper at 8000 px/s", str(game.ball.position))
 game.ball.teleport_to(Vector2(120, 1015), Vector2(6000, 0))
 hits_before = game.ball.bumper_hit_count
 await frames(4)
 check(game.ball.bumper_hit_count > hits_before and game.ball.position.x < 260, "Shape sweep catches triangle at 6000 px/s", str(game.ball.position))
 var rings_before: int = game.rings_collected
 game.ring_field.reset_rings()
 game.ball.teleport_to(Vector2(155, 230), Vector2(0, 400))
 game.ring_field.previous_ball_position = Vector2(155, 230)
 await frames(12)
 check(game.rings_collected > rings_before and game.special_meter > 0, "Ring collection scores and charges special meter")
 game.tuning.select_profile(0)
 game.tuning.set_value("wall_restitution", 0.5)
 check(is_equal_approx(game.chunks[0].wall_material.bounce, 0.5) and is_equal_approx(game.chunks[1].wall_material.bounce, 0.5), "Live tuning updates both chunks")
 game.tuning.modifier_enabled = true
 game.tuning.rebuild()
 check(is_equal_approx(game.tuning.effective.steering_acceleration, 2750.0) and is_equal_approx(game.tuning.effective.flipper_launch_strength, game.tuning.BALANCED.flipper_launch_strength * 1.15), "Example Chao boosts Quick / Tight effective stats")
 game.tuning.modifier_enabled = false
 game.tuning.select_profile(0)
 game.toggle_pause()
 var paused_position: Vector2 = game.ball.position
 await frames(12)
 check(game.ball.position.distance_to(paused_position) < 0.1, "Pause freezes gameplay physics")
 game.toggle_pause()
 game.ball.teleport_to(Vector2(400, 1470), Vector2(0, 800))
 game.set_physics_process(true)
 var old_number: int = game.ball_number
 await frames(140)
 check(game.ball_number > old_number and game.ball.position.y < 1400 and not game.ball.serve_pending, "Drain automatically respawns and relaunches", str(game.ball.position))
 # Fixed-seed broad play: repeatedly time both flippers when the ball approaches.
 game.tuning.select_profile(0)
 var escaped: bool = false
 var trapped_ticks: int = 0
 var worst_trapped_ticks: int = 0
 var previous_sample: Dictionary = {}
 for i in 2400:
  game.controls.virtual_left = game.ball.position.y > 1130 and (i % 36 < 18)
  game.controls.virtual_right = game.controls.virtual_left
  game.controls.virtual_steering = sin(float(i) / 110.0) * 0.7
  # After a detected drain the body falls below the table during the respawn delay.
  # Sample eligibility before stepping so an escape cannot hide behind a new respawn.
  var active_shot: bool = game.respawn_time < 0.0 and not game.ball.serve_pending and not game.ball._teleport_pending
  await frames(1)
  if active_shot and (game.ball.position.x < 20 or game.ball.position.x > 780 or game.ball.position.y < 10):
   if not escaped:
    print("ESCAPE TRACE | previous=", previous_sample, " current=", {"tick": i, "position": game.ball.position, "velocity": game.ball.linear_velocity, "respawn": game.respawn_time})
   escaped = true
  previous_sample = {"tick": i, "position": game.ball.position, "velocity": game.ball.linear_velocity, "respawn": game.respawn_time}
  trapped_ticks = trapped_ticks + 1 if game.ball.linear_velocity.length() < 5 and not game.ball.serve_pending else 0
  worst_trapped_ticks = maxi(worst_trapped_ticks, trapped_ticks)
 check(not escaped, "20-second simulated play stays inside side/top rails")
 check(worst_trapped_ticks < 240, "20-second simulated play has no stationary trap lasting 2 seconds", str(worst_trapped_ticks))
 print("RESULT | %d checks | %d failures" % [checks, failures])
 game.queue_free()
 await frames(3)
 quit(0 if failures == 0 else 1)

func contains_3d_collision(node: Node) -> bool:
 if node is CollisionObject3D:
  return true
 for child: Node in node.get_children():
  if contains_3d_collision(child):
   return true
 return false
