extends SceneTree
## Exercises the pause menu, the live table viewport and session-scoped controls.
const Session = preload("res://scripts/prototype/session.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
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

# Sample the live inspector clock for repeatable motion comparisons at 24 fps.
func sample_motion(lab: Control) -> void:
 var folder := output.path_join("motion")
 DirAccess.make_dir_recursive_absolute(folder)
 lab.set_process(false)
 for frame in 192:
  lab._process(1.0 / 24.0)
  await RenderingServer.frame_post_draw
  var shot := root.get_texture().get_image().get_region(Rect2i(396, 162, 488, 488))
  shot.save_png(folder.path_join("%03d.png" % frame))
 lab.set_process(true)

func run() -> void:
 if DisplayServer.get_name() != "headless":
  print("SPIN_REVIEW_SCREEN | initial=", root.current_screen, " primary=", DisplayServer.get_primary_screen(), " origin=", DisplayServer.screen_get_position(root.current_screen))
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
 var character: String = game.character_id
 check(lab.picker.item_count == {"sonic": 14, "tails": 16, "knuckles": 15, "shadow": 14, "rouge": 15, "amy": 14, "blaze": 15}[character] and lab.cameras.item_count == 4, "Gameplay clips and the four gameplay cameras are selectable")
 var point: Vector2 = game.ball.position
 check(is_equal_approx(lab.sliders.speed.value, 2.0) and is_equal_approx(lab.sliders.opacity.value, 0.45) and is_equal_approx(lab.sliders.blur.value, 1.0), "Inspection opens with the selected roll defaults")
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
   lab.tail_time = 1.5 / 7.0
   lab._orient_model()
   check(is_equal_approx(lab.trailing_tails.get_blend_shape_value(0), 0.5) and is_equal_approx(lab.trailing_tails.get_blend_shape_value(1), 0.5), "Preview interpolates the original tail motion between frames")
   lab.tail_time = lab.Assets.TAIL_WEAVE_DURATION
   lab._orient_model()
   check(is_zero_approx(lab.trailing_tails.get_blend_shape_value(0)) and is_zero_approx(lab.trailing_tails.get_blend_shape_value(1)), "The slower weave wraps to the authored start pose")
 await capture("in-game-spin")
 if not output.is_empty():
  lab.sliders.zoom.value = 4.0
  var motion_samples := "--sample-motion" in OS.get_cmdline_user_args()
  if motion_samples and tails:
   lab.yaw = 0.9
   lab.pitch = 0.35
   lab._aim_camera()
   await sample_motion(lab)
   lab.yaw = 0.0
   lab.pitch = 0.0
   lab._aim_camera()
  if character == "amy":
   lab._toggle_playback()
   for phase in 8:
    lab.roll_angle = TAU * phase / 8.0
    lab._orient_model()
    await capture("curl-%02d" % phase)
   lab._toggle_playback()
  var gallery := [lab.trick_names[0], lab.Assets.BOOST[character]]
  if lab.Assets.FLIGHT_CLIPS.has(character): gallery.append(lab.Assets.FLIGHT_CLIPS[character])
  if lab.Assets.POWER_DIVE.has(character): gallery.append(lab.Assets.POWER_DIVE[character])
  for i in lab.picker.item_count:
   var clip: String = lab.picker.get_item_metadata(i)
   if clip not in gallery: continue
   lab.picker.select(i)
   lab.picker.item_selected.emit(i)
   lab._process(0.10)
   await capture(clip)
   if motion_samples and not tails and clip == lab.Assets.BOOST[character]:
    lab.yaw = 1.0
    lab.pitch = 0.45
    lab._aim_camera()
    await capture("boost-stride")
    await sample_motion(lab)
    lab.pitch = 0.0
    lab.yaw = 0.0
    lab._aim_camera()
  lab._reset()
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
 for id in lab.sliders: check(lab.sliders[id].is_visible_in_tree() == (id != "boost"), "Roll controls show the applicable slider " + str(id))
 lab.sliders.model.value = 1.42
 lab.sliders.ball.value = 0.8
 lab.sliders.blur.value = 0.4
 lab.sliders.opacity.value = 0.55
 lab.sliders.speed.value = 0.0
 lab.sliders.zoom.value = 4.0
 check(is_equal_approx(lab.art.scale.x, 1.42) and is_equal_approx(lab.shell.scale.x, 0.8) and is_equal_approx(lab.shell.transparency, 0.45) and is_equal_approx(lab.curl.get_instance_shader_parameter("roll_exposure"), 0.4), "All material and size sliders act independently")
 if tails: check(lab.trailing_tails.scale.is_equal_approx(lab.art.scale), "The exterior tails follow model size independently of the shell size")
 angle = lab.roll_angle
 var weave: float = lab.tail_time
 lab._process(0.1)
 check(lab.roll_angle == angle, "Zero spin speed holds the model in place")
 if tails:
  check(is_equal_approx(lab.tail_time, fposmod(weave + 0.1, lab.Assets.TAIL_WEAVE_DURATION)), "The tails keep their slower cadence with the curled body stopped")
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
  if clip == lab.Assets.BOOST[game.character_id]:
   check(lab.rig.global_basis.y.normalized().is_equal_approx(Vector3.UP) and lab.sliders.boost.is_visible_in_tree() and is_equal_approx(lab.player.get_playing_speed() / lab.player.current_animation_length, 2.7), "Boost preview plays 2.7 strides per second")
  elif clip == lab.Assets.POWER_DIVE.get(character):
   check(lab.rig.global_basis.z.normalized().is_equal_approx(Vector3.DOWN), character.capitalize() + "'s original forward axis points into the table for the slam")
  elif clip != lab.roll_clip and clip != lab.Assets.FLIGHT_CLIPS.get(character, "") and clip != lab.Assets.DASH_RING[game.character_id]:
   lab._process(0.17)
   var model: Node3D = lab.held if clip in lab.trick_names else lab.rig
   if clip in lab.trick_names:
    var relative: Basis = lab.orbit.global_basis.orthonormalized().inverse() * model.global_basis.orthonormalized()
    var yaw_degrees := rad_to_deg(atan2(relative.z.x, relative.z.z))
    check(relative.y.is_equal_approx(Vector3.UP) and yaw_degrees > -11.0 and yaw_degrees < -9.0, clip + " approaches center from the left during playback")
    lab._toggle_playback()
    lab.yaw = 0.45
    lab.pitch = 0.48
    lab._process(0.1)
    lab._aim_camera()
    check(model.global_basis.orthonormalized().is_equal_approx(lab.orbit.global_basis.orthonormalized() * relative), "A paused trick keeps its facing angle when orbiting")
    lab.yaw = 0.0
    lab.pitch = 0.0
    lab._aim_camera()
    lab._toggle_playback()
   else: check(model.global_basis.orthonormalized().is_equal_approx(lab.orbit.global_basis.orthonormalized()), clip + " faces the top-down camera as the animation plays")
  if clip == lab.Assets.BOOST[character]:
   var skins := lab.rig.find_children("*", "MeshInstance3D", true, false) as Array
   check(not skins.is_empty() and skins[0].is_visible_in_tree() and skins[0].skin != null, "A visible skinned mesh is bound to the original Runners skeleton")
   var skeleton: Skeleton3D = lab.rig.find_children("*", "Skeleton3D", true, false)[0]
   var bones := []
   for bone in skeleton.get_bone_count(): bones.append(skeleton.get_bone_pose(bone))
   lab._process(0.19)
   var moved := false
   for bone in skeleton.get_bone_count(): moved = moved or not skeleton.get_bone_pose(bone).is_equal_approx(bones[bone])
   check(moved, "Boost run animates bones while the gameplay tree is paused")
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
 if game.specials.action.kind == TypeAction.Kind.FLY: await review_flight(session, game)
 if game.specials.action.kind == TypeAction.Kind.POWER: await review_smash(session, game)
 await review_traversal(session, game)
 session.archive_attempted = true
 await session._close_run("review")
 session.free()
 print("RESULT | In-game %s spin lab | %d checks | %d failures" % [character.capitalize(), checks, failures])
 quit(1 if failures else 0)

func review_smash(session: Node, game: Node) -> void:
 var pose = game.combo_celebration.character_pose
 var specials: CharacterSpecials = game.specials
 var events: Array[int] = []
 specials.area_started.connect(func(_source: String, _at: Vector2, _size: Vector2): events.append(Engine.get_physics_frames()))
 game.auto_launch_time = -1.0
 var ball: PlaygroundBall = game.ball
 ball.teleport_to(game.active.spawn(), Vector2.RIGHT * 75.0)
 while ball._teleport_pending: await physics_frame
 game.select_play_camera(TablePresentation.CameraPreset.DRAMATIC_PINBALL)
 game.presentation.camera_settings.zoom = 2.0
 game.presentation.reset_camera(ball.position)
 game.special_meter = specials.definition.meter_capacity
 var start := Engine.get_physics_frames()
 check(specials.activate() and not specials.activate() and events.is_empty(), "Power starts once and waits for impact")
 var origin := specials.smash_origin
 var wave: AreaSpecialFeedback
 for node in game.presentation.get_children():
  if node is AreaSpecialFeedback: wave = node
 check(is_instance_valid(wave), "Prototype installs its shockwave on the live table")
 var saw_rise := false
 var saw_dive := false
 var saw_wave := false
 var anchored := true
 var dive_playing := true
 var frame := 0
 while (events.is_empty() or Engine.get_physics_frames() - events.back() < 45) and frame < 350:
  await process_frame
  var remaining := specials.smash_remaining
  if is_instance_valid(wave) and wave.effect.is_visible_in_tree():
   saw_wave = not events.is_empty() and is_zero_approx(remaining)
  if remaining > 0.0: anchored = anchored and ball.position.distance_to(origin) < 0.2
  if remaining > 1.0 and specials.smash_height_fraction() > 0.25:
   saw_rise = pose.runners_roll.is_visible_in_tree() and not pose.motion_rig.visible
  if remaining > 0.0 and remaining < 0.95:
   saw_dive = true
   dive_playing = dive_playing and pose.motion == &"smash" and pose.motion_player.current_animation == pose.Assets.POWER_DIVE[game.character_id] and pose.motion_rig.global_basis.z.normalized().is_equal_approx(Vector3.DOWN)
  if not output.is_empty():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_jpg(output.path_join("smash-%03d.jpg" % frame), 0.95)
  frame += 1
 check(saw_rise and anchored, "The curled character jumps above a fixed contact point")
 check(saw_dive and dive_playing, "The recovered Power attack plays fists down throughout the descent")
 check(events.size() == 1 and absi(events[0] - start - Engine.physics_ticks_per_second * 2) <= 1, "One wave lands after two seconds of real physics ticks")
 check(saw_wave, "The expanding shockwave is visible at impact on the live table")
 check(pose.runners_roll.is_visible_in_tree() and not pose.motion_rig.visible, "Impact restores the curl")
 game.special_meter = specials.definition.meter_capacity
 check(specials.activate(), "A second charged jump can start")
 session.game.toggle_pause()
 var held := specials.smash_remaining
 for i in 4: await process_frame
 check(specials.smash_remaining == held, "Pause freezes the Power action clock")
 session.game.toggle_pause()
 ball.teleport_to(origin)
 check(specials.smash_remaining == 0.0 and events.size() == 1, "Reposition cancels the pending wave")

func review_traversal(session: Node, game: Node) -> void:
 var pose = game.combo_celebration.character_pose
 var ball: PlaygroundBall = game.ball
 var manager: Node = game.active.runtime.mechanics
 if game.character_id == "tails":
  for speed: float in [0.0, 1200.0]:
   pose.tail_time = 0.0
   ball.linear_velocity = Vector2.RIGHT * speed
   pose._process(1.5 / 7.0)
   check(is_equal_approx(pose.trailing_tails.get_blend_shape_value(0), 0.5) and is_equal_approx(pose.trailing_tails.get_blend_shape_value(1), 0.5), "The live tail weave has the same cadence at %d px/s" % speed)
 var spring: Dictionary = manager.by_id.scoop_kicker
 var direction := Objects.forward(spring)
 game.auto_launch_time = -1.0
 game.respawn_time = -1.0
 ball.teleport_to(spring.position + direction * 35.0, -direction * 500.0)
 for i in 25:
  await physics_frame
  if pose.motion == &"spring": break
 check(pose.motion == &"spring" and pose.motion_player.current_animation == pose.Assets.DASH_RING[game.character_id], "Hitting the Clover Scoop spring starts the original ring dash")
 if pose.motion == &"spring":
  var camera: Camera3D = game.presentation.camera
  var anchor: Vector3 = pose.motion_rig.global_position
  var origin := camera.unproject_position(anchor)
  var head := camera.unproject_position(anchor + pose.motion_rig.global_basis.y.normalized()) - origin
  var travel := camera.unproject_position(anchor + TablePresentation.map_point(direction)) - origin
  check(head.normalized().dot(travel.normalized()) > 0.98, "The ring-dash pose points along the angled launch in screen space")
  session._open_spin_lab()
  check(session.spin_lab.active_clip == pose.Assets.DASH_RING[game.character_id], "F8 selects the live spring animation")
  session.spin_lab.sliders.zoom.value = 4.0
  await capture("spring-ring-dash")
  session._resume_spin_lab()
  # Sample the actual outgoing movement before forcing a clean apex.
  await physics_frame
  check(ball.linear_velocity.y < 0 and pose.motion == &"spring", "The upward spring pose survives the first integration")
  ball.linear_velocity = Vector2(100, 0)
  pose._physics_process(1.0 / 120.0)
  check(pose.motion == &"" and pose.runners_roll.is_visible_in_tree(), "The first level or downward velocity restores the curl")
 ball.traversal_launched.emit(&"dash_panel", Vector2.RIGHT * 550)
 check(pose.motion == &"dash_panel" and pose.motion_player.current_animation == pose.Assets.BOOST[game.character_id] and not game.character.rolling_mesh.visible, "Dash panel selects the character's Boost and hides the curl")
 pose._process(0.075)
 check(is_equal_approx(pose.motion_player.current_animation_position / pose.motion_player.current_animation_length, 0.075 * 2.7), "Panel Boost advances at 2.7 strides per second")
 pose._physics_process(0.75)
 ball.traversal_launched.emit(&"dash_panel", Vector2.RIGHT * 550)
 pose._physics_process(119.0 / 120.0)
 check(pose.motion == &"dash_panel", "Boost stays visible through tick 119 after a second dash panel")
 session._open_spin_lab()
 check(session.spin_lab.active_clip == pose.Assets.BOOST[game.character_id], "F8 selects the live panel boost")
 session.spin_lab.sliders.zoom.value = 4.0
 await capture("dash-panel-boost")
 session._resume_spin_lab()
 pose._physics_process(1.0 / 120.0)
 check(pose.motion == &"" and pose.runners_roll.is_visible_in_tree(), "The curl returns at exactly one second of panel boost")
 var loop: Dictionary = manager.by_id.clover_loop
 direction = Objects.forward(loop)
 ball.teleport_to(loop.position - direction * 14.0, direction * 550.0)
 while ball._teleport_pending: await physics_frame
 ball.traversal_launched.emit(&"dash_panel", direction * 550.0)
 pose._process(0.075)
 for i in 30:
  await physics_frame
  if ball.in_loop: break
 check(ball.in_loop and pose.motion == &"loop", "Crossing the Clover Loop mouth switches to Boost")
 check(pose.motion_player.current_animation_position >= 0.074, "Panel-to-Loop handoff carries the running stride into the Loop")
 if ball.in_loop:
  session._open_spin_lab()
  var loop_player: AnimationPlayer = session.spin_lab.player
  check(is_equal_approx(loop_player.get_playing_speed() / loop_player.current_animation_length, 3.375), "F8 previews the faster Loop stride during a ride")
  session._resume_spin_lab()
 var boosted := ball.in_loop
 var inverted := false
 for i in 360:
  if not ball.in_loop: break
  boosted = boosted and pose.motion_rig.is_visible_in_tree() and pose.motion_player.current_animation == pose.Assets.BOOST[game.character_id] and not game.character.rolling_mesh.visible
  if ball.track_frame.y.y < -0.95:
   pose._process(0.0)
   if not inverted:
    game.combo_celebration.consider(game.character_id, 5, 100)
    game.combo_celebration._process(0.2)
    check(pose.motion_rig.is_visible_in_tree() and not pose.visible, "A combo receipt at the crest keeps the Loop boost visible")
    if not output.is_empty():
     session._open_spin_lab()
     # View across the track to see the character beneath the tread at the crest.
     var side := ball.track_frame.x
     session.spin_lab.pitch = 1.35
     session.spin_lab.yaw = atan2(side.x, side.z)
     session.spin_lab.sliders.zoom.value = 2.5
     session.spin_lab._aim_camera()
     await capture("loop-boost-crest")
     session._resume_spin_lab()
   inverted = inverted or pose.motion_rig.global_basis.y.normalized().dot(ball.track_frame.y) > 0.99
  await physics_frame
 check(boosted and inverted, "Boost covers the entire real ride and the character's feet follow the surface through inversion")
 check(not ball.in_loop and pose.motion == &"" and pose.runners_roll.is_visible_in_tree(), "Exiting the Loop immediately restores the curl")

func capture_roll_cycle(lab: Control) -> void:
 lab._toggle_playback()
 lab.pitch = 0.55
 lab._aim_camera()
 for i in 12:
  lab.roll_angle = TAU * i / 12.0
  lab.tail_time = lab.Assets.TAIL_WEAVE_DURATION * i / 12.0
  lab._orient_model()
  await capture("tails-roll-%02d" % i)
 lab._toggle_playback()

func review_flight(session: Node, game: Node) -> void:
 var card = game.combo_celebration
 var pose = card.character_pose
 var specials: CharacterSpecials = game.specials
 var character: String = game.character_id
 var flight_clip: String = pose.Assets.FLIGHT_CLIPS[character]
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
 check(pose.motion_rig.is_visible_in_tree() and (not pose.trailing_tails or not pose.trailing_tails.visible) and not game.character.rolling_mesh.visible and pose.motion_player.current_animation == flight_clip, "Only the animated flight rig occupies the live Ball")
 check_flight_facing(pose.motion_rig, game.presentation.camera, -1.0, "Left steering turns toward screen left while facing the player despite rightward momentum")
 var skeleton: Skeleton3D = pose.motion_rig.find_children("*", "Skeleton3D", true, false)[0]
 var animated_before := {}
 for i in skeleton.get_bone_count():
  if character != "tails" or skeleton.get_bone_name(i).to_lower().contains("tail"): animated_before[i] = skeleton.get_bone_global_pose(i)
 pose._process(0.12)
 var moving_bones := 0
 for i: int in animated_before:
  if not skeleton.get_bone_global_pose(i).is_equal_approx(animated_before[i]): moving_bones += 1
 check(moving_bones >= 2, "The original Flight action animates " + ("the tails" if character == "tails" else character.capitalize()))
 game.controls.virtual_steering = 0.65
 game.controls._physics_process(0.0)
 game.ball.linear_velocity = Vector2(-300, -60)
 pose._process(0.016)
 check_flight_facing(pose.motion_rig, game.presentation.camera, 1.0, "Reversing steering turns toward screen right against a leftward shot")
 game.controls.virtual_steering = 0.0
 game.controls._physics_process(0.0)
 pose._process(0.016)
 check_flight_facing(pose.motion_rig, game.presentation.camera, 1.0, "Neutral steering keeps the last flight heading")
 var time_left := specials.flight_remaining
 var original_phase: float = pose.motion_player.current_animation_position
 session._open_spin_lab()
 var lab = session.spin_lab
 check(paused and lab.active_clip == flight_clip and not pose.motion_rig.visible, "F8 during Fly opens the matching clip")
 lab.sliders.zoom.value = 3.0
 lab.pitch = 0.65
 for direction: int in [-1, 1]:
  game.controls.virtual_steering = float(direction)
  lab.yaw = 0.32 * direction
  lab._aim_camera()
  lab._process(0.12)
  check_flight_facing(lab.rig, lab.orbit, direction, "Preview follows screen-relative steering after orbiting")
  await capture(character + ("-flight-left" if direction < 0 else "-flight-right"))
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
    await capture("%s-trick-%d" % [character, trick + 1])
 session._resume_spin_lab()
 check(not paused and pose.motion_rig.visible and is_equal_approx(original_phase, pose.motion_player.current_animation_position) and is_equal_approx(time_left, specials.flight_remaining), "Resume preserves the real Flight phase and remaining time")
 await capture(character + "-flight-in-play")
 card.reset_combo()
 var expected: int = pose.trick_index
 for milestone: int in [5, 8, 10, 15]:
  game.select_play_camera(game.PLAY_CAMERAS[(expected + 1) % game.PLAY_CAMERAS.size()])
  card.consider(character, milestone, 100)
  card._process(0.3)
  expected = (expected + 1) % 3
  check(pose.visible and pose.mesh == pose.tricks[expected] and not pose.motion_rig.visible, character.capitalize() + " performs the next trick at hit %d" % milestone)
  var relative: Basis = game.presentation.camera.global_basis.orthonormalized().inverse() * pose.global_basis.orthonormalized()
  check(relative.y.is_equal_approx(Vector3.UP) and is_equal_approx(rad_to_deg(atan2(relative.z.x, relative.z.z)), 27.421875), character.capitalize() + "'s trick turns right relative to the play camera")
  card._process(card.DURATION)
  check(pose.motion_rig.visible and not game.character.rolling_mesh.visible, "The live flight rig resumes after the trick")
 specials._physics_process(specials.flight_remaining + 0.01)
 check(not pose.flying and not pose.motion_rig.visible and pose.runners_roll.is_visible_in_tree() and (not pose.trailing_tails or pose.trailing_tails.is_visible_in_tree()), "Flight expiry restores the translucent shell and curled body")
 game.special_meter = specials.definition.meter_capacity
 if specials.activate():
  specials.reset(false, "Checkpoint transfer")
  check(not pose.flying and pose.runners_roll.is_visible_in_tree(), "Checkpoint reset immediately restores the curl")
 else: check(false, "A second charged Flight can start")
