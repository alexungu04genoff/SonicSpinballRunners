extends SceneTree
## Deterministic integration check for the current ball-form visual adapter.
var failures := 0
var checks := 0
var game: Node

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, description: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", description)
 else:
  failures += 1
  push_error("FAIL | " + description)

func frames(count: int) -> void:
 for i in count:
  await physics_frame

func collision_count(node: Node) -> int:
 var count := 1 if node is CollisionObject3D else 0
 for child: Node in node.get_children():
  count += collision_count(child)
 return count

func run() -> void:
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.authored_act_path = "res://data/acts/playtest_showcase.tres"
 root.add_child(game)
 await frames(3)
 check(ProjectSettings.get_setting("application/run/main_scene") == "res://experiments/visual_lab/visual_lab.tscn", "Project entry point opens themed Play Act")
 check(collision_count(game.presentation) == 0, "Scenery and ball-form character add no 3D collision objects")
 check(not game.debug_panel.visible and game.presentation.camera.current, "Dedicated play view starts without the physics debug panels")
 var actor: Node3D = game.character
 var original_position: Vector2 = game.ball.position
 game._set_close_view(true)
 game._select_pose("jump")
 var original_clock: float = actor._pose_time
 await frames(5)
 check(paused and not game.world.can_process() and not game.ring_field.can_process(), "Showcase pauses the authoritative physics and pickups")
 check(game.ball.position.is_equal_approx(original_position), "Showcase animation never moves the physics ball")
 check(actor._pose_time > original_clock, "Character-study animation advances while gameplay is paused")
 actor.spin_root.rotate_z(1.2)
 actor._process(0.0)
 check(actor.marker.rotation.is_zero_approx(), "Contact marker never inherits the rolling transform")
 check(TablePresentation.unmap_point(actor.marker.position).distance_to(game.ball.position) < 0.001, "Contact marker stays at the exact authoritative ball position")
 game._select_pose("roll")
 await frames(2)
 check(actor.pose == "roll" and actor.spin_root.visible, "Rolling preview is selectable while paused at serve")
 game._set_close_view(false)
 check(not paused and game.presentation.camera.current, "Returning from showcase restores live play and its camera")
 game.controls.virtual_enabled = true
 game.tuning.effective.gravity_scale = 0.0
 var flipper: PlaygroundFlipper = game.flippers[0]
 var before: int = flipper.strikes
 var strike_position := flipper.position + Vector2.RIGHT.rotated(flipper.rest_angle()) * flipper.length * 0.55 + Vector2(0, -32)
 game.ball.teleport_to(strike_position, Vector2(0, 100))
 await frames(3)
 game.controls.virtual_left = flipper.side > 0.0
 game.controls.virtual_right = flipper.side < 0.0
 await frames(12)
 check(flipper.strikes > before and actor.event_pose == "jump" and actor.event_time > 0.0, "A real 2D flipper strike triggers the brief jump presentation")
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 # Isolate the bumper probe from the preceding jump reaction cooldown.
 game.reset_ball()
 await frames(24)
 var bumper: Dictionary = {}
 for descriptor: Dictionary in game.authored_runtime.objects:
  if descriptor.type == "round_bumper":
   bumper = descriptor
   break
 check(not bumper.is_empty(), "Authored Act supplies a real bumper for the visual-event probe")
 if not bumper.is_empty():
  var hits_before: int = game.ball.bumper_hit_count
  game.ball.teleport_to(bumper.position - Vector2(0, bumper.radius + PlaygroundBall.RADIUS + 35), Vector2(0, 900))
  await frames(18)
  check(game.ball.bumper_hit_count > hits_before and actor.event_pose == "trick" and actor.event_time > 0.0, "A real 2D bumper collision triggers the brief trick presentation")
 print("VISUAL_LAB_SMOKE | %d checks | %d failures" % [checks, failures])
 game.free()
 quit(0 if failures == 0 else 1)
