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
 check(lab.picker.item_count == 15 and lab.cameras.item_count == 4, "Original clips and the four gameplay cameras are selectable")
 var point: Vector2 = game.ball.position
 check(is_equal_approx(lab.sliders.speed.value, 2.0) and is_equal_approx(lab.sliders.opacity.value, 0.30) and is_equal_approx(lab.sliders.blur.value, 1.0), "Inspection opens with the selected Sonic defaults")
 var score: int = game.score
 var angle: float = lab.roll_angle
 for frame in 6: await process_frame
 check(game.ball.position == point and game.score == score and lab.roll_angle != angle, "Sonic spins while the real Ball and score remain fixed")
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
 angle = lab.roll_angle
 lab._process(0.1)
 check(lab.roll_angle == angle, "Zero spin speed holds the model in place")
 for i in lab.cameras.item_count:
  lab.cameras.select(i)
  lab.cameras.item_selected.emit(i)
  check(game.presentation.camera_preset == lab.cameras.get_item_id(i) and lab.orbit.current, "Inspection uses the selected real camera preset")
 for i in lab.picker.item_count:
  lab.picker.select(i)
  lab.picker.item_selected.emit(i)
  var clip: String = lab.active_clip
  if clip == "sn_ball_loop": check(lab.curl.visible, "Roll selects the shader-equipped mesh")
  elif clip in lab.Assets.TRICKS: check(lab.held.visible and lab.held.mesh != null, "Baked trick keeps its original mesh")
  else: check(lab.rig.visible and lab.player.current_animation == clip, "Original Action plays: " + clip)
  if clip == "sn_run_loop":
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
 var inspect_camera: WeakRef = weakref(lab.orbit)
 var inspect_model: WeakRef = weakref(lab.pivot)
 lab.resume_requested.emit()
 check(not paused and session.state == "playing" and game.presentation.camera.current and game.character.rolling_mesh.visible and game.hud.visible, "Resume restores the original table camera, HUD and rolling mesh")
 var pose = game.combo_celebration.sonic_pose
 check(is_equal_approx(pose.runners_roll.scale.x / pose.radius, 1.42) and is_equal_approx(game.character.rolling_mesh.mesh.radius / pose.radius, 0.8) and is_zero_approx(game.character.roll_speed_scale), "Chosen values apply to the real gameplay model and shell")
 check(inspect_camera.get_ref() == null and inspect_model.get_ref() == null, "Closing releases the inspection camera and models")
 game.toggle_pause()
 for frame in 2: await process_frame
 var entries := session.overlay_root.find_children("*", "Button", true, false)
 var menu_button: Button
 for button: Button in entries:
  if button.text.begins_with("Sonic spin preview"): menu_button = button
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
  shortcut.keycode = KEY_C
  var old_preset: int = game.presentation.camera_preset
  root.push_input(shortcut)
  check(game.presentation.camera_preset != old_preset, "C cycles the camera inside the inspector")
  shortcut.keycode = KEY_ESCAPE
  root.push_input(shortcut)
  check(session.state == "playing" and not paused, "Escape returns to play")
 session.archive_attempted = true
 await session._close_run("review")
 session.free()
 print("RESULT | In-game Sonic spin lab | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
