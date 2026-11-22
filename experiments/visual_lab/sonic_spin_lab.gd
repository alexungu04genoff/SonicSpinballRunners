extends PanelContainer
## Paused inspection inside the active table, camera viewport and lighting.
signal resume_requested
const Assets = preload("res://experiments/visual_lab/runners_sonic_assets.gd")
const Pose = preload("res://scripts/prototype/sonic_combo_pose.gd")
const Celebration = preload("res://scripts/prototype/combo_celebration.gd")
const CLIPS := {
 "sn_ball_loop": "Spin ball", "sn_jump_trick": "Jump trick 1", "sn_jump_trick_02": "Jump trick 2",
 "sn_jump_trick_03": "Jump trick 3", "sn_boost_loop": "Boost run",
 "sn_stumble_run_loop": "Stumble", "sn_jump_fall_loop": "Fall", "sn_landing": "Landing",
 "sn_springjump_loop": "Spring jump", "sn_dashring_loop": "Dash ring", "sn_damage_miss_loop": "Defeat",
 "sn_ph_astero_start": "Asteroid start", "sn_ph_laser_start": "Laser start", "sn_ph_spin_start": "Drill start",
}
var game: Node
var pose: Pose
var embedded := false
var panel := VBoxContainer.new()
var cameras := OptionButton.new()
var orbit := Camera3D.new()
var pivot := Node3D.new()
var shell := MeshInstance3D.new()
var art := Node3D.new()
var curl: MeshInstance3D
var trailing_tails: MeshInstance3D
var held := MeshInstance3D.new()
var tricks: Array[Mesh] = []
var rig: Node3D
var sage: Pose.Sage
var player: AnimationPlayer
var source_radius := 1.0
var picker := OptionButton.new()
var pause_button := Button.new()
var shell_on_poses := CheckBox.new()
var sliders := {}
var active_clip := ""
var active_character := ""
var roll_clip := ""
var trick_names: Array
var playing := true
var yaw := 0.0
var pitch := 0.0
var roll_angle := 0.0
var trick_time := 0.0
var shell_fade := Pose.ShellFade.new()
var tail_time := 0.0
var flight_heading := Vector2.RIGHT
var hint: Label

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 if not embedded:
  anchor_bottom = 1.0
  offset_left = 14
  offset_top = 14
  offset_right = 318
  offset_bottom = -14
 var style := StyleBoxFlat.new()
 style.bg_color = Color("#101e31ed")
 style.border_color = Color("#4389ab")
 style.border_width_right = 2
 style.set_content_margin_all(14)
 add_theme_stylebox_override("panel", style)
 var scroll := ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 add_child(scroll)
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 panel.add_theme_constant_override("separation", 8)
 scroll.add_child(panel)
 if not embedded: pose = game.combo_celebration.character_pose
 active_character = pose.character
 roll_clip = Pose.Sage.BALL if pose.sage else Assets.CURLS.get(pose.character, "painted_roll" if embedded else "")
 trick_names = Assets.trick_names(pose.character)
 _build_stage()
 _load_models()
 _build_controls()
 tail_time = pose.tail_time
 if pose.motion != &"" and (player or sage):
  var current: String = pose.sage.action if sage else pose.motion_player.current_animation
  for i in picker.item_count:
   if picker.get_item_metadata(i) == current: picker.select(i)
 _select_clip(picker.selected)

func _build_stage() -> void:
 var camera: Camera3D = game.presentation.camera
 camera.get_parent().add_child(orbit)
 orbit.cull_mask = camera.cull_mask
 orbit.keep_aspect = camera.keep_aspect
 orbit.attributes = camera.attributes
 orbit.environment = camera.environment
 orbit.make_current()
 game.presentation.add_child(pivot)
 pivot.process_mode = Node.PROCESS_MODE_ALWAYS
 pivot.global_position = game.character.spin_root.global_position
 pivot.scale = Vector3.ONE * pose.radius
 pose.inspect(true)
 if not embedded: game.hud.hide()
 pivot.add_child(shell)
 var sphere := SphereMesh.new()
 sphere.radius = 1.0
 sphere.height = 2.0
 sphere.radial_segments = 32
 sphere.rings = 16
 shell.mesh = sphere
 shell.material_override = game.character.spin_surface
 shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 pivot.add_child(art)
 art.add_child(held)

func _load_models() -> void:
 if pose.sage:
  sage = Pose.Sage.new()
  art.add_child(sage)
  sage.prepare_gameplay()
  sage.scale = Vector3.ONE / sage.ball_radius
  return
 if is_instance_valid(pose.runners_roll):
  curl = pose.runners_roll.duplicate()
  curl.transform = Transform3D.IDENTITY
  art.add_child(curl)
  if pose.trailing_tails:
   trailing_tails = pose.trailing_tails.duplicate()
   pivot.add_child(trailing_tails)
  tricks = pose.tricks
 source_radius = pose.motion_fit.get("runners_source_radius", 1.0)
 if pose.motion_rig or not embedded: rig = Assets.animated_scene(pose.character)
 if rig != null:
  art.add_child(rig)
  player = rig.find_child("AnimationPlayer", true, false)
  if player:
   player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
   for clip in player.get_animation_list():
    player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func _label(parent: Control, caption: String, size_px := 16) -> Label:
 var label := Label.new()
 label.text = caption
 label.add_theme_font_size_override("font_size", size_px)
 parent.add_child(label)
 return label

func _build_controls() -> void:
 if not embedded:
  _label(panel, "%s spin preview" % pose.character.capitalize(), 24)
 _label(panel, "Animation")
 panel.add_child(picker)
 var clips := _available_clips()
 for clip: String in clips:
  if clip == roll_clip or (sage and sage.animated) or (clip in trick_names and not tricks.is_empty()) or (player and player.has_animation(clip)):
   picker.add_item(clips[clip])
   picker.set_item_metadata(picker.item_count - 1, clip)
 picker.item_selected.connect(_select_clip)
 _build_view_controls()

func _available_clips() -> Dictionary:
 var clips := {}
 if sage:
  clips[roll_clip] = roll_clip
  if sage.animated:
   for clip: String in sage.CLIPS: clips[clip] = clip
  return clips
 for sonic_clip: String in CLIPS:
  var clip := sonic_clip.replace("sn_", str(Assets.PREFIX.get(pose.character, "")) + "_")
  if sonic_clip == "sn_ball_loop": clip = roll_clip
  clips[clip] = CLIPS[sonic_clip]
  if clip == roll_clip and Assets.FLIGHT_CLIPS.has(pose.character): clips[Assets.FLIGHT_CLIPS[pose.character]] = "Flight"
 if pose.character == "tails": clips["tl_jump_cannonball_loop"] = "Cannonball"
 if Assets.POWER_DIVE.has(pose.character): clips[Assets.POWER_DIVE[pose.character]] = "Table Smash · power dive"
 if embedded and not Assets.CURLS.has(pose.character):
  clips = {roll_clip: "Spin ball"}
  if player and Assets.BOOST.has(pose.character): clips[Assets.BOOST[pose.character]] = "Boost run"
 return clips

func _build_view_controls() -> void:
 _label(panel, "Table camera")
 panel.add_child(cameras)
 for preset: int in game.PLAY_CAMERAS: cameras.add_item(TablePresentation.CAMERA_NAMES[preset], preset)
 cameras.select(cameras.get_item_index(game.presentation.camera_preset))
 cameras.item_selected.connect(_select_camera)
 _slider("zoom", "Inspection zoom", 0.5, 10.0, 0.05)
 _slider("model", "%s model size" % pose.character.capitalize(), 0.25, 2.0, 0.01)
 _slider("ball", "Ball shell size", 0.25, 2.0, 0.01)
 _slider("blur", "Spin blur", 0.0, 1.0, 0.01)
 _slider("speed", "Spin speed", 0.0, 8.0, 0.05)
 _slider("boost", "Boost speed", 0.25, 3.0, 0.05)
 _slider("opacity", "Core opacity" if sage else "Shell opacity", 0.0, 1.0, 0.01)
 shell_on_poses.text = "Show shell on other animations"
 panel.add_child(shell_on_poses)
 if sage:
  for id: String in ["model", "ball", "blur", "speed", "boost"]: sliders[id].get_parent().hide()
  shell_on_poses.hide()
 shell_on_poses.toggled.connect(func(_on: bool): _update_preview())
 var buttons := HBoxContainer.new()
 panel.add_child(buttons)
 buttons.add_child(pause_button)
 pause_button.text = "Pause motion"
 pause_button.pressed.connect(_toggle_playback)
 var reset := Button.new()
 reset.text = "Reset preview"
 buttons.add_child(reset)
 reset.pressed.connect(_reset)
 var resume := Button.new()
 resume.text = "Back to table" if embedded else "Resume play"
 panel.add_child(resume)
 resume.pressed.connect(func(): resume_requested.emit())
 hint = _label(panel, "", 14)
 hint.modulate = Color("#afd3df")
 if sage and not sage.animated:
  _label(panel, "Install Sage’s local rig to preview her seven animations.", 14).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 elif not sage and (curl == null or player == null or tricks.is_empty()):
  var note := _label(panel, "Available clips depend on the local Runners model and pose bake.", 14)
  note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _slider(id: String, caption: String, minimum: float, maximum: float, step: float) -> void:
 var group := VBoxContainer.new()
 panel.add_child(group)
 var row := HBoxContainer.new()
 group.add_child(row)
 _label(row, caption).size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var readout := _label(row, "")
 readout.modulate = Color("#80d8ff")
 var slider := HSlider.new()
 if embedded: slider.scrollable = false
 slider.min_value = minimum
 slider.max_value = maximum
 slider.step = step
 match id:
  "zoom": slider.value = 2.5
  "boost": slider.value = pose.boost_speed
  _: slider.value = float(pose.settings[id])
 slider.custom_minimum_size.y = 26
 group.add_child(slider)
 sliders[id] = slider
 var update := func(value: float):
  match id:
   "blur", "opacity": readout.text = "%d%%" % roundi(value * 100)
   _: readout.text = "%.2f×" % value
  if not active_clip.is_empty(): _update_preview()
 slider.value_changed.connect(update)
 update.call(slider.value)

func _select_clip(index: int) -> void:
 var previous := active_clip
 active_clip = picker.get_item_metadata(index)
 var flight_clip: String = "Flight" if sage else Assets.FLIGHT_CLIPS.get(pose.character, "")
 if active_clip == flight_clip:
  flight_heading = pose.flight_heading if pose.flying else pose.initial_flight_heading()
 hint.text = ("Steer with ← / → or the left stick\n" if active_clip == flight_clip else "") + "Drag table to orbit · Wheel to zoom\n" + ("F8 to return to table" if embedded else "C to cycle cameras · F8 to resume")
 var rolling := active_clip == roll_clip
 if sage:
  held.hide()
  shell.hide()
  sage.play(active_clip, not previous.is_empty())
  _update_preview()
  return
 if not previous.is_empty() and (previous == roll_clip) != rolling:
  shell_fade.start(1.0 - shell.transparency if shell.visible else 0.0)
 var trick := trick_names.find(active_clip)
 held.visible = trick >= 0 and not tricks.is_empty()
 if held.visible:
  held.mesh = tricks[trick]
  trick_time = 0.0
 if curl: curl.visible = rolling
 if trailing_tails: trailing_tails.visible = rolling
 if rig:
  rig.visible = not held.visible and not rolling
  if player:
   player.stop()
   if rig.visible and player.has_animation(active_clip):
    rig.scale = Vector3.ONE / source_radius
    Assets.start_clip(rig, player, active_clip)
    if pose.motion != &"" and active_clip == pose.motion_player.current_animation:
     player.seek(pose.motion_player.current_animation_position, true)
 roll_angle = game.character.roll_angle if rolling else 0.0
 _update_preview()

func _update_preview() -> void:
 if sage:
  pose.settings.opacity = sliders.opacity.value
  pose.sage.shell.set_shader_parameter("opacity", sliders.opacity.value)
  sage.shell.set_shader_parameter("opacity", sliders.opacity.value)
  _aim_camera()
  return
 var rolling := active_clip == roll_clip
 art.scale = Vector3.ONE * sliders.model.value
 if trailing_tails: trailing_tails.scale = art.scale
 shell.scale = Vector3.ONE * sliders.ball.value
 var painted_ball := rolling and curl == null
 _draw_shell()
 sliders.opacity.editable = not painted_ball
 if curl: curl.set_instance_shader_parameter("roll_exposure", sliders.blur.value)
 sliders.blur.editable = rolling and curl != null
 sliders.speed.editable = rolling
 var boosting: bool = active_clip == Assets.BOOST.get(pose.character)
 sliders.boost.get_parent().visible = boosting
 sliders.speed.get_parent().visible = not boosting
 if player: Assets.set_playback_speed(player, pose.character, sliders.boost.value, pose.motion == &"loop")
 var values := {}
 for id: String in Pose.DEFAULTS: values[id] = sliders[id].value
 pose.apply_settings(values, sliders.boost.value)
 _aim_camera()

func _draw_shell() -> void:
 var rolling := active_clip == roll_clip
 var strength := float(sliders.opacity.value) if curl else 1.0
 var rest := strength if rolling or shell_on_poses.button_pressed else 0.0
 var opacity := shell_fade.opacity(rest, strength)
 shell.visible = opacity > 0.0
 shell.transparency = 1.0 - opacity

func _aim_camera() -> void:
 var camera: Camera3D = game.presentation.camera
 var base := camera.global_basis.orthonormalized()
 var frame := base.rotated(base.x, pitch).rotated(Vector3.UP, yaw)
 var zoom: float = sliders.zoom.value
 var focus := pivot.global_position
 var distance := maxf(0.01, (camera.global_position - focus).dot(base.z))
 orbit.projection = camera.projection
 orbit.fov = camera.fov
 orbit.size = camera.size / zoom
 if embedded:
  # Frame the character independently of the size of the inspected Act.
  orbit.size = 24.0 * pose.radius / zoom
  if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
   distance = 12.0 * pose.radius / tan(deg_to_rad(camera.fov * 0.5))
 orbit.near = minf(camera.near, pose.radius * 0.1)
 orbit.far = camera.far
 orbit.global_transform = Transform3D(frame, focus + frame.z * (distance / zoom if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else distance))
 _orient_model()

func _select_camera(index: int) -> void:
 game.select_play_camera(cameras.get_item_id(index))
 yaw = 0.0
 pitch = 0.0
 _aim_camera()

func _input(event: InputEvent) -> void:
 if active_clip.is_empty(): return
 if embedded:
  if not event is InputEventMouse or game.is_source_picker_open(): return
  if not game.view_container.get_global_rect().has_point(event.position) or game.lighting_controls.blocks_camera_at(event.position): return
 if event is InputEventMouse and get_global_rect().has_point(event.position): return
 if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
  yaw -= event.relative.x * 0.009
  pitch = clampf(pitch + event.relative.y * 0.009, -1.4, 1.4)
  _aim_camera()
 elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
  sliders.zoom.value *= 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
 elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
  var index := posmod(cameras.selected + (-1 if event.shift_pressed else 1), cameras.item_count)
  cameras.select(index)
  _select_camera(index)
 else: return
 get_viewport().set_input_as_handled()

func _toggle_playback() -> void:
 playing = not playing
 pause_button.text = "Pause motion" if playing else "Play motion"

func view_state() -> Dictionary:
 var values := {}
 for id: String in sliders: values[id] = sliders[id].value
 return {"clip": active_clip, "playing": playing, "sliders": values, "pitch": pitch, "yaw": yaw,
  "angle": roll_angle, "tails": tail_time, "heading": flight_heading, "shell": shell_on_poses.button_pressed,
  "trick_time": trick_time,
  "time": sage.elapsed if sage else (player.current_animation_position if player and player.is_playing() else 0.0)}

func restore_view(saved: Dictionary) -> void:
 if saved.is_empty(): return
 for id: String in saved.sliders: sliders[id].value = saved.sliders[id]
 yaw = saved.yaw
 pitch = saved.pitch
 shell_on_poses.set_pressed_no_signal(saved.shell)
 for index in picker.item_count:
  if picker.get_item_metadata(index) == saved.clip:
   picker.select(index)
   _select_clip(index)
   break
 if player and player.is_playing(): player.seek(saved.time, true)
 if sage: sage.sample(saved.time)
 if playing != saved.playing: _toggle_playback()
 roll_angle = saved.angle
 trick_time = saved.trick_time
 tail_time = saved.tails
 flight_heading = saved.heading
 _update_preview()

func _unhandled_key_input(event: InputEvent) -> void:
 if embedded: return
 if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
  _toggle_playback()
  get_viewport().set_input_as_handled()

func _reset() -> void:
 for key: String in Pose.DEFAULTS: sliders[key].value = Pose.DEFAULTS[key]
 if sage: sliders.opacity.value = sage.CORE_OPACITY
 sliders.boost.value = Assets.BOOST_SPEED
 sliders.zoom.value = 2.5
 shell_on_poses.button_pressed = false
 pitch = 0.0
 yaw = 0.0
 picker.select(0)
 _select_clip(0)
 if not playing: _toggle_playback()

func _process(delta: float) -> void:
 if active_clip.is_empty(): return
 if sage:
  if playing:
   if active_clip == "Flight":
    var steering: float = game.controls.virtual_steering if game.controls.virtual_enabled else Input.get_axis("steer_left", "steer_right")
    if not is_zero_approx(steering): flight_heading = Vector2(signf(steering), 0.0)
   sage.sample(sage.elapsed + delta)
  if embedded: pivot.global_position = game.character.spin_root.global_position
  _aim_camera()
  return
 var rolling := active_clip == roll_clip
 var flying: bool = active_clip == Assets.FLIGHT_CLIPS.get(pose.character, "")
 if playing:
  if shell_fade.elapsed < Pose.ShellFade.DURATION:
   shell_fade.advance(delta)
   _draw_shell()
  if player and rig.visible: player.advance(delta)
  if held.visible: trick_time = fposmod(trick_time + delta, Celebration.MILESTONE_TRICK_SECONDS)
  if flying:
   var steer: float = game.controls.virtual_steering if game.controls.virtual_enabled else Input.get_axis("steer_left", "steer_right")
   if not is_zero_approx(steer): flight_heading = Vector2(signf(steer), 0)
  elif rolling:
   roll_angle = fmod(roll_angle + delta * TAU * float(sliders.speed.value), TAU)
   tail_time = fposmod(tail_time + delta, Assets.TAIL_WEAVE_DURATION)
 if embedded:
  pivot.global_position = game.character.spin_root.global_position
  _aim_camera()
 elif playing: _orient_model()

func _orient_model() -> void:
 if sage:
  if not sage.animated: return
  var view := orbit.global_basis.orthonormalized()
  sage.steer(flight_heading.x if active_clip == "Flight" else 0.0)
  if active_clip == "Ring Dash": view = Pose.spring_basis(orbit, pivot.global_position, pose.motion_direction)
  elif active_clip == "Boost Hover": view = game.character.flat_roll_frame(game.character.roll_heading)
  sage.pose_on_table(view, sage.elapsed)
  return
 var rolling := active_clip == roll_clip
 art.rotation.x = roll_angle if rolling else 0.0
 shell.rotation.x = art.rotation.x
 var frame: Basis
 if rolling:
  # The two exterior tails share the heading. Only the shell and body spin.
  frame = game.character.spin_root.basis.orthonormalized()
  if trailing_tails: Assets.sample_roll_tails(trailing_tails, tail_time)
 elif held.visible:
  frame = Pose.trick_basis(orbit, trick_time / Celebration.MILESTONE_TRICK_SECONDS)
 elif active_clip == Assets.DASH_RING.get(pose.character):
  var direction: Vector2 = pose.motion_direction if pose.motion == &"spring" else Vector2.UP
  frame = Pose.spring_basis(orbit, pivot.global_position, direction)
 elif active_clip == Assets.POWER_DIVE.get(pose.character):
  frame = Pose.smash_basis(game.character.roll_heading)
 elif active_clip == Assets.BOOST.get(pose.character):
  frame = pose.motion_rig.global_basis.orthonormalized() if pose.motion in [&"loop", &"target_boost", &"dash_panel"] else game.character.flat_roll_frame(game.character.roll_heading)
 else:
  var side := 0.0
  if active_clip == Assets.FLIGHT_CLIPS.get(pose.character, ""): side = flight_heading.x
  frame = Pose.player_facing_basis(orbit, side)
 pivot.global_basis = frame.scaled(Vector3.ONE * pose.radius)
 # Lift in table space even when the camera is looking straight down.
 var lift := 0.0
 if rig and rig.visible:
  var fit_yaw := flight_heading.x * Pose.FLIGHT_TURN if active_clip == Assets.FLIGHT_CLIPS.get(pose.character) else atan2(frame.z.x, frame.z.z)
  rig.position = -Assets.pose_center(pose.motion_fit, player, fit_yaw) / source_radius
  var half_height := -rig.position.y * art.global_basis.get_scale().y
  if active_clip == Assets.POWER_DIVE.get(pose.character):
   lift = pose.smash_lift(sliders.model.value)
   art.global_position = pivot.global_position + Vector3.UP * lift
   return
  if active_clip == Assets.BOOST.get(pose.character):
   var offset := half_height - pose.radius
   art.global_position = pivot.global_position + frame.y * (maxf(0.0, offset) if pose.motion == &"loop" else offset)
   return
  var airborne := active_clip in [Assets.FLIGHT_CLIPS.get(pose.character, ""), Assets.DASH_RING.get(pose.character)]
  lift = Pose.flight_lift(half_height, pose.radius) if airborne else maxf(0.0, half_height - pose.radius * 0.82)
 art.global_position = pivot.global_position + Vector3.UP * lift

func finish() -> void:
 if is_instance_valid(orbit): orbit.free()
 if is_instance_valid(pivot): pivot.free()
 if is_instance_valid(game):
  game.presentation.camera.make_current()
  pose.inspect(false)
  if not embedded: game.hud.show()
