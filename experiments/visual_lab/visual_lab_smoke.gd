extends SceneTree
## Deterministic integration check for the experimental visual adapter.
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
 root.add_child(game)
 await frames(3)
 check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/playground.tscn", "Normal playground entry point remains unchanged")
 check(collision_count(game.presentation) == 0, "Scenery and imported character add no 3D collision objects")
 check(not game.debug_panel.visible and game.presentation.camera.current, "Dedicated play view starts without the physics debug panels")
 var actor: Node3D = game.character
 var local_model_exists := FileAccess.file_exists(ProjectSettings.globalize_path(actor.MODEL_PATH))
 if local_model_exists and not OS.get_cmdline_user_args().has("--no-model"):
  check(actor.model_available, "Prepared Sonic GLB loads at runtime")
  check(actor._clips.has("idle") and actor._clips.has("jump") and actor._clips.has("trick"), "Imported animation player exposes all three authored clips")
  var skeletons: Array[Node] = actor.model.find_children("*", "Skeleton3D", true, false)
  check(skeletons.size() == 1, "Imported character has one usable skin skeleton")
  if skeletons.size() == 1:
   var skeleton: Skeleton3D = skeletons[0]
   var arm_index := skeleton.find_bone("UpperArm_L")
   var thigh_index := skeleton.find_bone("Thigh_L")
   check(arm_index >= 0 and thigh_index >= 0, "Authored arm and hip joints exist for pose verification")
   if arm_index >= 0 and thigh_index >= 0:
    actor.select_preview("idle")
    actor.seek_pose(0.55)
    var idle_arm := skeleton.get_bone_pose_rotation(arm_index)
    var idle_thigh := skeleton.get_bone_pose_rotation(thigh_index)
    actor.select_preview("jump")
    actor.seek_pose(0.55)
    var jump_arm := skeleton.get_bone_pose_rotation(arm_index)
    var jump_thigh := skeleton.get_bone_pose_rotation(thigh_index)
    actor.select_preview("trick")
    actor.seek_pose(0.55)
    var trick_arm := skeleton.get_bone_pose_rotation(arm_index)
    var trick_thigh := skeleton.get_bone_pose_rotation(thigh_index)
    check(idle_arm.angle_to(jump_arm) > 0.2 and idle_thigh.angle_to(jump_thigh) > 0.2, "Static jump capture evaluates distinct arm and hip poses after clearing crossfade")
    check(jump_arm.angle_to(trick_arm) > 0.1 and jump_thigh.angle_to(trick_thigh) > 0.1, "Static trick capture evaluates distinct arm and hip poses")
    actor.capture_hold = false
    actor.select_preview("roll")
 else:
  check(not actor.model_available and actor.spin_root.visible and not actor.upright.visible, "Missing or disabled local model uses a visible spin-ball fallback")
 var original_position: Vector2 = game.ball.position
 game._set_close_view(true)
 game._select_pose("jump")
 var original_clock: float = actor._pose_time
 await frames(5)
 check(paused and not game.world.can_process() and not game.ring_field.can_process(), "Showcase pauses the authoritative physics and pickups")
 check(game.ball.position.is_equal_approx(original_position), "Showcase animation never moves the physics ball")
 check(actor._pose_time > original_clock, "Manual pose animation advances while gameplay is paused")
 actor.spin_root.rotate_z(1.2)
 actor._process(0.0)
 check(is_equal_approx(actor.upright.rotation.z, 0.0), "Upright Sonic never inherits the rolling transform")
 check(TablePresentation.unmap_point(actor.marker.position).distance_to(game.ball.position) < 0.001, "Contact marker stays at the exact authoritative ball position")
 game._select_pose("roll")
 await frames(2)
 check(actor.pose == "roll" and actor.spin_root.visible and not actor.upright.visible, "Rolling preview is selectable while paused at serve")
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
 var bumper: Dictionary = {}
 for descriptor: Dictionary in game.chunks.back().descriptors:
  if descriptor.kind == "circle":
   bumper = descriptor
   break
 check(not bumper.is_empty(), "Generated launch section supplies a real bumper for the visual-event probe")
 if not bumper.is_empty():
  var hits_before: int = game.ball.bumper_hit_count
  game.ball.teleport_to(bumper.position - Vector2(0, bumper.radius + PlaygroundBall.RADIUS + 35), Vector2(0, 900))
  await frames(18)
  check(game.ball.bumper_hit_count > hits_before and actor.event_pose == "trick" and actor.event_time > 0.0, "A real 2D bumper collision triggers the brief trick presentation")
 print("VISUAL_LAB_SMOKE | %d checks | %d failures" % [checks, failures])
 game.free()
 quit(0 if failures == 0 else 1)
