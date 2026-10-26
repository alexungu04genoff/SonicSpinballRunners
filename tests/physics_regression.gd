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
 # Count physics ticks exactly; rendered frames can span several fixed ticks.
 for i in count:
  await physics_frame

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
 check(absf(test_ball.linear_velocity.x - 1520.0) < 1.0 and is_equal_approx(test_ball.steering_contribution, 120.0), "Release preserves steering contribution and launch momentum", str(test_ball.linear_velocity))
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
 root.add_child(game)
 await frames(5)
 check(game.ball.position.distance_to(game.playfield.spawn) < 1.0, "Authored spawn remains exact")
 check(not contains_3d_collision(game.presentation), "Presentation contains no 3D collision objects")
 var mapping_error := TablePresentation.unmap_point(TablePresentation.map_point(Vector2(234.5, 678.9))).distance_to(Vector2(234.5, 678.9))
 check(mapping_error < 0.001, "2D/3D mapping round trip")
 game.tuning.set_value("wall_restitution", 0.5)
 var correct := true
 for body: StaticBody2D in game.playfield.terrain_bodies:
  correct = correct and is_equal_approx(body.physics_material_override.bounce, 0.5)
 check(correct, "Live tuning updates every authored terrain body")
 game.controls.virtual_enabled = true
 game.controls.virtual_left = true
 game.controls.virtual_right = true
 await frames(12)
 for paddle: PlaygroundFlipper in game.flippers:
  check(is_equal_approx(paddle.rotation, paddle.active_angle()), "Authored flipper responds to shared input")
 game.reset_ball()
 await frames(3)
 check(game.ball.serve_pending and game.ball.position == game.playfield.spawn, "Reset returns to authored spawn")
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
