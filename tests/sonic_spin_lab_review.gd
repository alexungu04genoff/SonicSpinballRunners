extends SceneTree
## Exercises the pause menu, the live table viewport and session-scoped controls.
const Session = preload("res://scripts/prototype/session.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func capture(name: String) -> void:
 if output.is_empty(): return
 for frame in 3: await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Saved " + name)

func check_flight_facing(model: Node3D, camera: Camera3D, side: float, message: String) -> void:
 var relative := camera.global_basis.orthonormalized().inverse() * model.global_basis.orthonormalized()
 check(relative.y.is_equal_approx(Vector3.UP) and relative.z.z > 0.75 and relative.z.x * side > 0.25, message)

func run() -> void:
 Review.position_review_window(root)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
 if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
 var local := "res://test-results/runners-review/menu-%d" % OS.get_process_id()
 DirAccess.make_dir_recursive_absolute(local)
 var session := Session.new()
 session.settings_path = local.path_join("settings.cfg")
 session.archive_directory = local
 root.add_child(session)
 var deadline := Time.get_ticks_msec() + 90000
 while session.state != "spin_lab" and Time.get_ticks_msec() < deadline: await process_frame
 if not is_instance_valid(session.spin_lab):
  push_error("Start this local-asset review with --spin-lab --act and an authored Act path.")
  quit(1)
  return
 var lab = session.spin_lab
 var game = session.game
 check(paused and lab.orbit.get_viewport() == game.presentation.camera.get_viewport() and lab.pivot.get_world_3d() == game.character.get_world_3d(), "Inspector uses the actual paused table and play viewport")
 var tails: bool = game.character_id == "tails"
 check(lab.picker.item_count == (17 if tails else 15) and lab.cameras.item_count == 4, "Original clips and the four gameplay cameras are selectable")
 var point: Vector2 = game.ball.position
 check(is_equal_approx(lab.sliders.speed.value, 2.0) and is_equal_approx(lab.sliders.opacity.value, 0.30) and is_equal_approx(lab.sliders.blur.value, 1.0), "Inspection opens with the selected roll defaults")
 var score: int = game.score
 var angle: float = lab.roll_angle
 for frame in 6: await process_frame
 check(game.ball.position == point and game.score == score and lab.roll_angle != angle, "The model spins while the real Ball and score remain fixed")
 if tails:
  var tail_frame: Transform3D = lab.trailing_tails.global_transform
  var body_frame: Basis = lab.curl.global_basis
  lab._process(0.10)
  check(lab.trailing_tails.is_visible_in_tree() and lab.trailing_tails.global_transform.is_equal_approx(tail_frame) and not lab.curl.global_basis.is_equal_approx(body_frame), "Preview spins the curl while both exterior tails hold their heading")
  check(lab.trailing_tails.get_surface_override_material(0) == null, "The exterior tails retain their original skin at full spin blur")
  check(lab.trailing_tails.get_blend_shape_count() == 7, "The original eight-frame roll keeps all seven poses after the base frame")
  if lab.trailing_tails.get_blend_shape_count() == 7:
   lab.roll_angle = TAU * 1.5 / 8.0
   lab._orient_model()
   check(is_equal_approx(lab.trailing_tails.get_blend_shape_value(0), 0.5) and is_equal_approx(lab.trailing_tails.get_blend_shape_value(1), 0.5), "Preview interpolates the original tail motion between frames")
   lab.roll_angle = TAU
   lab._orient_model()
   check(is_zero_approx(lab.trailing_tails.get_blend_shape_value(0)) and is_zero_approx(lab.trailing_tails.get_blend_shape_value(1)), "A full revolution wraps to the authored start pose")
 await capture("in-game-spin")
 var wheel := InputEventMouseButton.new()
 wheel.button_index = MOUSE_BUTTON_WHEEL_UP
 wheel.position = Vector2(800, 420)
 wheel.pressed = true
 var old_zoom: float = lab.sliders.zoom.value
 root.push_input(wheel)
 check(lab.sliders.zoom.value > old_zoom, "Mouse wheel zooms over the table")
 var drag := InputEventMouseMotion.new()
 drag.position = wheel.position
 drag.relative = Vector2(20, 8)
 drag.button_mask = MOUSE_BUTTON_MASK_LEFT
 root.push_input(drag)
 check(not is_zero_approx(lab.yaw) and not is_zero_approx(lab.pitch), "Dragging orbits the actual Ball")
 for id in lab.sliders: check(lab.sliders[id].is_visible_in_tree(), "Visible slider " + str(id))
 lab.sliders.model.value = 1.42
 lab.sliders.ball.value = 0.8
 lab.sliders.blur.value = 0.4
 lab.sliders.opacity.value = 0.55
 lab.sliders.speed.value = 0.0
 lab.sliders.zoom.value = 4.0
 check(is_equal_approx(lab.art.scale.x, 1.42) and is_equal_approx(lab.shell.scale.x, 0.8) and is_equal_approx(lab.shell.transparency, 0.45) and is_equal_approx(lab.curl.get_instance_shader_parameter("roll_exposure"), 0.4), "All material and size sliders act independently")
 if tails: check(lab.trailing_tails.scale.is_equal_approx(lab.art.scale), "The exterior tails follow model size independently of the shell size")
 angle = lab.roll_angle
 lab._process(0.1)
 check(lab.roll_angle == angle, "Zero spin speed holds the model in place")
 for i in lab.cameras.item_count:
  lab.cameras.select(i)
  lab.cameras.item_selected.emit(i)
  check(game.presentation.camera_preset == lab.cameras.get_item_id(i) and lab.orbit.current, "Inspection uses the selected real camera preset")
 lab.sliders.speed.value = 2.0
 for i in lab.picker.item_count:
  lab.picker.select(i)
  lab.picker.item_selected.emit(i)
  var clip: String = lab.active_clip
  if clip == lab.roll_clip: check(lab.curl.visible, "Roll selects the shader-equipped mesh")
  elif clip in lab.trick_names: check(lab.held.visible and lab.held.mesh != null, "Baked trick keeps its original mesh")
  else: check(lab.rig.visible and lab.player.current_animation == clip, "Original Action plays: " + clip)
  if clip != lab.roll_clip and clip != lab.Assets.FLIGHT:
   lab._process(0.17)
   var model: Node3D = lab.held if clip in lab.trick_names else lab.rig
   check(model.global_basis.orthonormalized().is_equal_approx(lab.orbit.global_basis.orthonormalized()), clip + " faces the top-down camera as the animation plays")
   if clip in lab.trick_names:
    lab._toggle_playback()
    lab.yaw = 0.45
    lab.pitch = 0.48
    lab._aim_camera()
    check(model.global_basis.orthonormalized().is_equal_approx(lab.orbit.global_basis.orthonormalized()), "A held trick stays upright when orbiting with playback paused")
    lab.yaw = 0.0
    lab.pitch = 0.0
    lab._aim_camera()
    lab._toggle_playback()
  if clip in ["sn_run_loop", "tl_run_loop"]:
   var skins := lab.rig.find_children("*", "MeshInstance3D", true, false) as Array
   check(not skins.is_empty() and skins[0].is_visible_in_tree() and skins[0].skin != null, "A visible skinned mesh is bound to the original Runners skeleton")
   var skeleton: Skeleton3D = lab.rig.find_children("*", "Skeleton3D", true, false)[0]
   var bones := []
   for bone in skeleton.get_bone_count(): bones.append(skeleton.get_bone_pose(bone))
   lab._process(0.19)
   var moved := false
   for bone in skeleton.get_bone_count(): moved = moved or not skeleton.get_bone_pose(bone).is_equal_approx(bones[bone])
   check(moved, "Run animates bones while the gameplay tree is paused")
   await capture("in-game-run")
 lab.sliders.speed.value = 0.0
 var inspect_camera: WeakRef = weakref(lab.orbit)
 var inspect_model: WeakRef = weakref(lab.pivot)
 lab.resume_requested.emit()
 check(not paused and session.state == "playing" and game.presentation.camera.current and game.character.rolling_mesh.visible and game.hud.visible, "Resume restores the original table camera, HUD and rolling mesh")
 var pose = game.combo_celebration.character_pose
 check(is_equal_approx(pose.runners_roll.scale.x / pose.radius, 1.42) and is_equal_approx(game.character.rolling_mesh.mesh.radius / pose.radius, 0.8) and is_zero_approx(game.character.roll_speed_scale), "Chosen values apply to the real gameplay model and shell")
 check(inspect_camera.get_ref() == null and inspect_model.get_ref() == null, "Closing releases the inspection camera and models")
 game.toggle_pause()
 for frame in 2: await process_frame
 var entries := session.overlay_root.find_children("*", "Button", true, false)
 var menu_button: Button
 for button: Button in entries:
  if button.text.begins_with(game.character_id.capitalize() + " spin preview"): menu_button = button
 check(menu_button != null, "Preview is reachable from the ordinary pause menu")
 if menu_button:
  menu_button.pressed.emit()
  check(is_equal_approx(session.spin_lab.sliders.model.value, 1.42), "Reopening preserves this run's controls")
  session.spin_lab._reset()
  session._resume_spin_lab()
 var shortcut := InputEventKey.new()
 shortcut.keycode = KEY_F8
 shortcut.pressed = true
 game.ball.serve_pending = false
 game.ball.linear_velocity = Vector2(230, -140)
 game.character._process(1.0 / 60.0)
 root.push_input(shortcut)
 check(session.state == "spin_lab" and paused, "F8 opens the preview during ordinary play")
 if session.state == "spin_lab":
  session.spin_lab._process(0.04)
  var preview_axle: Vector3 = session.spin_lab.pivot.global_basis.x.normalized()
  check(preview_axle.is_equal_approx(game.character.rolling_mesh.global_basis.x.normalized()), "The paused curl keeps the live roll axle on a diagonal heading")
  if tails and not output.is_empty(): await capture_roll_cycle(session.spin_lab)
  shortcut.keycode = KEY_C
  var old_preset: int = game.presentation.camera_preset
  root.push_input(shortcut)
  check(game.presentation.camera_preset != old_preset, "C cycles the camera inside the inspector")
  shortcut.keycode = KEY_ESCAPE
  root.push_input(shortcut)
  check(session.state == "playing" and not paused, "Escape returns to play")
 if tails: await review_flight(session, game)
 session.archive_attempted = true
 await session._close_run("review")
 session.free()
 print("RESULT | In-game %s spin lab | %d checks | %d failures" % ["Tails" if tails else "Sonic", checks, failures])
 quit(1 if failures else 0)

func capture_roll_cycle(lab: Control) -> void:
 lab._toggle_playback()
 lab.pitch = 0.55
 lab._aim_camera()
 for i in 12:
  lab.roll_angle = TAU * i / 12.0
  lab._orient_model()
  await capture("tails-roll-%02d" % i)
 lab._toggle_playback()

func review_flight(session: Node, game: Node) -> void:
 var card = game.combo_celebration
 var pose = card.character_pose
 var specials: CharacterSpecials = game.specials
 game.auto_launch_time = -1.0
 game.respawn_time = -1.0
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.controls.virtual_enabled = true
 game.controls.input_blocked = false
 game.controls.virtual_steering = -0.75
 game.controls._physics_process(0.0)
 game.ball.linear_velocity = Vector2(300, -90)
 game.special_meter = specials.definition.meter_capacity
 var activated := specials.activate()
 check(activated and pose.flying and game.special_meter == specials.definition.meter_capacity - specials.definition.meter_cost, "Charged Fly starts the recovered animation and spends the usual meter")
 if not activated or not pose.flying: return
 check(pose.flight.is_visible_in_tree() and not pose.trailing_tails.visible and not game.character.rolling_mesh.visible and pose.flight_player.current_animation == pose.Assets.FLIGHT, "Only the animated flight rig occupies the live Ball")
 check_flight_facing(pose.flight, game.presentation.camera, -1.0, "Left steering turns toward screen left while facing the player despite rightward momentum")
 var skeleton: Skeleton3D = pose.flight.find_children("*", "Skeleton3D", true, false)[0]
 var tails_before := {}
 for i in skeleton.get_bone_count():
  if skeleton.get_bone_name(i).to_lower().contains("tail"): tails_before[i] = skeleton.get_bone_global_pose(i)
 pose._process(0.12)
 var moving_tails := 0
 for i: int in tails_before:
  if not skeleton.get_bone_global_pose(i).is_equal_approx(tails_before[i]): moving_tails += 1
 check(moving_tails >= 2, "The original Flight action animates the tails")
 game.controls.virtual_steering = 0.65
 game.controls._physics_process(0.0)
 game.ball.linear_velocity = Vector2(-300, -60)
 pose._process(0.016)
 check_flight_facing(pose.flight, game.presentation.camera, 1.0, "Reversing steering turns toward screen right against a leftward shot")
 game.controls.virtual_steering = 0.0
 game.controls._physics_process(0.0)
 pose._process(0.016)
 check_flight_facing(pose.flight, game.presentation.camera, 1.0, "Neutral steering keeps the last flight heading")
 var time_left := specials.flight_remaining
 var original_phase: float = pose.flight_player.current_animation_position
 session._open_spin_lab()
 var lab = session.spin_lab
 check(paused and lab.active_clip == pose.Assets.FLIGHT and not pose.flight.visible, "F8 during Fly opens the matching clip")
 lab.sliders.zoom.value = 3.0
 lab.pitch = 0.65
 for direction: int in [-1, 1]:
  game.controls.virtual_steering = float(direction)
  lab.yaw = 0.32 * direction
  lab._aim_camera()
  lab._process(0.12)
  check_flight_facing(lab.rig, lab.orbit, direction, "Preview follows screen-relative steering after orbiting")
  await capture("tails-flight-left" if direction < 0 else "tails-flight-right")
 game.controls.virtual_steering = 0.0
 lab._process(0.05)
 check_flight_facing(lab.rig, lab.orbit, 1.0, "The preview keeps its heading with the stick released")
 if not output.is_empty():
  lab.yaw = 0.1
  lab.pitch = 0.4
  for i in lab.picker.item_count:
   var trick: int = lab.trick_names.find(lab.picker.get_item_metadata(i))
   if trick >= 0:
    lab.picker.select(i)
    lab.picker.item_selected.emit(i)
    await capture("tails-trick-%d" % (trick + 1))
 session._resume_spin_lab()
 check(not paused and pose.flight.visible and is_equal_approx(original_phase, pose.flight_player.current_animation_position) and is_equal_approx(time_left, specials.flight_remaining), "Resume preserves the real Flight phase and remaining time")
 await capture("tails-flight-in-play")
 card.reset_combo()
 var expected: int = pose.trick_index
 for milestone: int in [5, 8, 10, 15]:
  game.select_play_camera(game.PLAY_CAMERAS[(expected + 1) % game.PLAY_CAMERAS.size()])
  card.consider("tails", milestone, 100)
  card._process(0.3)
  expected = (expected + 1) % 3
  check(pose.visible and pose.mesh == pose.tricks[expected] and not pose.flight.visible, "Tails performs the next trick at hit %d" % milestone)
  check(pose.global_basis.orthonormalized().is_equal_approx(game.presentation.camera.global_basis.orthonormalized()), "Tails's live trick %d faces the play camera" % (expected + 1))
  card._process(card.DURATION)
  check(pose.flight.visible and not game.character.rolling_mesh.visible, "The live flight rig resumes after the trick")
 specials._physics_process(specials.flight_remaining + 0.01)
 check(not pose.flying and not pose.flight.visible and pose.runners_roll.is_visible_in_tree() and pose.trailing_tails.is_visible_in_tree(), "Flight expiry restores the translucent shell, curled body and trailing tails")
 game.special_meter = specials.definition.meter_capacity
 if specials.activate():
  specials.reset(false, "Checkpoint transfer")
  check(not pose.flying and pose.runners_roll.is_visible_in_tree(), "Checkpoint reset immediately restores the curl")
 else: check(false, "A second charged Flight can start")
