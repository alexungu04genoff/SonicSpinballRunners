extends PanelContainer
## Paused inspection inside the active table, camera viewport and lighting.
signal resume_requested
const Assets = preload("res://experiments/visual_lab/runners_sonic_assets.gd")
const Pose = preload("res://scripts/prototype/sonic_combo_pose.gd")
const CLIPS := {
 "sn_ball_loop": "Spin ball", "sn_jump_trick": "Jump trick 1", "sn_jump_trick_02": "Jump trick 2",
 "sn_jump_trick_03": "Jump trick 3", "sn_run_loop": "Run", "sn_boost_loop": "Boost",
 "sn_stumble_run_loop": "Stumble", "sn_jump_fall_loop": "Fall", "sn_landing": "Landing",
 "sn_springjump_loop": "Spring jump", "sn_dashring_loop": "Dash ring", "sn_damage_miss_loop": "Defeat",
 "sn_ph_astero_start": "Asteroid start", "sn_ph_laser_start": "Laser start", "sn_ph_spin_start": "Drill start",
}
var game: Node
var pose: Pose
var panel := VBoxContainer.new()
var cameras := OptionButton.new()
var orbit := Camera3D.new()
var pivot := Node3D.new()
var shell := MeshInstance3D.new()
var art := Node3D.new()
var curl: MeshInstance3D
var held := MeshInstance3D.new()
var tricks: Array[Mesh] = []
var rig: Node3D
var player: AnimationPlayer
var centers := {}
var source_radius := 1.0
var picker := OptionButton.new()
var pause_button := Button.new()
var shell_on_poses := CheckBox.new()
var sliders := {}
var active_clip := ""
var playing := true
var yaw := 0.0
var pitch := 0.0
var roll_angle := 0.0

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
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
 pose = game.combo_celebration.sonic_pose
 _build_stage()
 _load_models()
 _build_controls()
 _select_clip(0)

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
 game.character.rolling_mesh.hide()
 game.hud.hide()
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
 if is_instance_valid(pose.runners_roll):
  curl = pose.runners_roll.duplicate()
  curl.transform = Transform3D.IDENTITY
  art.add_child(curl)
  tricks = pose.tricks
  var bake: Dictionary = curl.mesh.get_meta("bake", {})
  source_radius = bake.get("runners_source_radius", 1.0)
  centers = bake.get("preview_centers", {})
 var document := GLTFDocument.new()
 var state := Assets.read_state(Assets.ANIMATED, document)
 if state != null:
  rig = document.generate_scene(state)
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
 _label(panel, "Sonic spin preview", 24)
 _label(panel, "Animation")
 panel.add_child(picker)
 for clip: String in CLIPS:
  if clip == "sn_ball_loop" or (clip in Assets.TRICKS and not tricks.is_empty()) or (player and player.has_animation(clip)):
   picker.add_item(CLIPS[clip])
   picker.set_item_metadata(picker.item_count - 1, clip)
 picker.item_selected.connect(_select_clip)
 _label(panel, "Table camera")
 panel.add_child(cameras)
 for preset: int in game.PLAY_CAMERAS: cameras.add_item(TablePresentation.CAMERA_NAMES[preset], preset)
 cameras.select(cameras.get_item_index(game.presentation.camera_preset))
 cameras.item_selected.connect(_select_camera)
 _slider("zoom", "Inspection zoom", 0.5, 10.0, 0.05)
 _slider("model", "Sonic model size", 0.25, 2.0, 0.01)
 _slider("ball", "Ball shell size", 0.25, 2.0, 0.01)
 _slider("blur", "Spin blur", 0.0, 1.0, 0.01)
 _slider("speed", "Spin speed", 0.0, 8.0, 0.05)
 _slider("opacity", "Shell opacity", 0.0, 1.0, 0.01)
 shell_on_poses.text = "Show shell on other animations"
 panel.add_child(shell_on_poses)
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
 resume.text = "Resume play"
 panel.add_child(resume)
 resume.pressed.connect(func(): resume_requested.emit())
 var hint := _label(panel, "Drag table to orbit · Wheel to zoom\nC to cycle cameras · F8 to resume", 14)
 hint.modulate = Color("#afd3df")
 if curl == null or picker.item_count < CLIPS.size():
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
 slider.min_value = minimum
 slider.max_value = maximum
 slider.step = step
 slider.value = 2.5 if id == "zoom" else float(pose.settings[id])
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
 active_clip = picker.get_item_metadata(index)
 var rolling := active_clip == "sn_ball_loop"
 var trick := Assets.TRICKS.find(active_clip)
 held.visible = trick >= 0 and not tricks.is_empty()
 if held.visible: held.mesh = tricks[trick]
 if curl: curl.visible = rolling
 if rig:
  rig.visible = not held.visible and not (rolling and curl)
  if player:
   player.stop()
   if rig.visible and player.has_animation(active_clip):
    var center: Array = centers.get(active_clip, [0, 0.48, 0])
    rig.position = -Vector3(center[0], center[1], center[2]) / source_radius
    rig.scale = Vector3.ONE / source_radius
    player.play(active_clip)
    player.advance(0.0)
 roll_angle = 0.0
 _update_preview()

func _update_preview() -> void:
 var rolling := active_clip == "sn_ball_loop"
 art.scale = Vector3.ONE * sliders.model.value
 var half_height := 0.0
 if held.visible: half_height = -held.mesh.get_aabb().position.y
 elif rig and rig.visible: half_height = -rig.position.y
 art.position.y = maxf(0.0, half_height * float(sliders.model.value) - 0.82)
 shell.scale = Vector3.ONE * sliders.ball.value
 shell.visible = (rolling or shell_on_poses.button_pressed) and sliders.opacity.value > 0.0
 shell.transparency = 1.0 - sliders.opacity.value
 if curl: curl.set_instance_shader_parameter("roll_exposure", sliders.blur.value)
 sliders.blur.editable = rolling and curl != null
 pivot.rotation = Vector3(roll_angle, 0, 0) if rolling else Vector3(0, roll_angle, 0)
 var values := {}
 for id: String in Pose.DEFAULTS: values[id] = sliders[id].value
 pose.apply_settings(values)
 _aim_camera()

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
 orbit.near = minf(camera.near, pose.radius * 0.1)
 orbit.far = camera.far
 orbit.global_transform = Transform3D(frame, focus + frame.z * (distance / zoom if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else distance))

func _select_camera(index: int) -> void:
 game.select_play_camera(cameras.get_item_id(index))
 yaw = 0.0
 pitch = 0.0
 _aim_camera()

func _input(event: InputEvent) -> void:
 if active_clip.is_empty(): return
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

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
  _toggle_playback()
  get_viewport().set_input_as_handled()

func _reset() -> void:
 for key: String in Pose.DEFAULTS: sliders[key].value = Pose.DEFAULTS[key]
 sliders.zoom.value = 2.5
 shell_on_poses.button_pressed = false
 pitch = 0.0
 yaw = 0.0
 picker.select(0)
 _select_clip(0)
 if not playing: _toggle_playback()

func _process(delta: float) -> void:
 if active_clip.is_empty() or not playing: return
 if player and rig.visible: player.advance(delta)
 roll_angle = fmod(roll_angle + delta * TAU * float(sliders.speed.value), TAU)
 if active_clip == "sn_ball_loop": pivot.rotation.x = roll_angle
 else: pivot.rotation.y = roll_angle

func finish() -> void:
 if is_instance_valid(orbit): orbit.free()
 if is_instance_valid(pivot): pivot.free()
 if is_instance_valid(game):
  game.presentation.camera.make_current()
  game.character.rolling_mesh.show()
  game.hud.show()
