extends Node
## Inspect the same rig and playhead in the studio or on the Clover Scoop playfield.
const Actor = preload("res://experiments/visual_lab/sage/actor.gd")
const Run = preload("res://scripts/prototype/zone_run.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const ACT := "res://data/acts/Authored/Clover Scoop.tres"
const STATES := [Actor.BALL] + Actor.CLIPS
const RATES := [0.25, 0.5, 1.0, 1.5, 2.0]
const BALL_PREVIEW_SECONDS := 4.0
const DEFAULT_CAMERA := TablePresentation.CameraPreset.DRAMATIC_PINBALL
const STUDIO := 100

@export_file("*.glb") var model_path := Actor.MODEL
@export_file("*.tres") var act_path := ACT
@onready var clips: ItemList = %Clips
@onready var timeline: HSlider = %Timeline
@onready var cameras: OptionButton = %Cameras
@onready var speed: OptionButton = %Speed

var game: Run
var actor: Actor
var camera: Camera3D
var table_camera: Camera3D
var table_effects: Array[int] = []
var pose_basis: Basis
var view_basis: Basis
var anchor: Vector3
var radius := 1.0
var orbit_yaw := 0.0
var orbit_pitch := 0.0
var zoom := 1.0
var seconds := 0.0
var playhead := 0.0
var playing := true
var inspecting := false
var closing := false

func _ready() -> void:
 if get_window().mode == Window.MODE_WINDOWED: Review.position_review_window(get_window())
 get_window().title = "Sage Lab"
 get_viewport().scaling_3d_scale = 1.0
 get_viewport().msaa_3d = Viewport.MSAA_4X
 get_tree().auto_accept_quit = false
 get_window().close_requested.connect(_close)
 if not FileAccess.file_exists(model_path):
  %Status.text = "Sage’s local rig is missing.\nPlace the prepared GLB at %s and reopen the lab." % model_path.trim_prefix("res://")
  return
 actor = Actor.new()
 actor.process_mode = Node.PROCESS_MODE_ALWAYS
 %Studio.add_child(actor)
 if not actor.prepare(model_path):
  %Status.text = "Sage’s GLB needs a skinned body and all seven study animations.\n" + model_path.trim_prefix("res://")
  return
 _connect_controls()
 inspecting = true
 %Sidebar.show()
 %Loading.hide()
 _select_clip(STATES.find("Hover"))
 _select_camera(cameras.get_item_index(STUDIO))
 print("SAGE_LAB_READY | states=", clips.item_count, " | screen=", get_window().current_screen, " | origin=", DisplayServer.screen_get_position(get_window().current_screen))
 if "--sage-crt" in OS.get_cmdline_user_args(): _start_crt_preview()

func _start_crt_preview() -> void:
 var table_index := cameras.get_item_index(DEFAULT_CAMERA)
 cameras.select(table_index)
 await _load_table()
 if closing or not is_instance_valid(table_camera): return
 %GameFilters.button_pressed = true
 if get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]: %Sidebar.hide()
 zoom = 0.65
 _aim_camera()
 _replay_morph()
 print("SAGE_CRT_PREVIEW | character=", game.specials.character_id, " | screen=", get_window().current_screen, " | size=", get_window().size, " | mode=", get_window().mode, " | filters=", game.retro_filter.display_name(), " | core=", actor.shell.get_shader_parameter("opacity"))

func _load_table() -> void:
 game = Run.new()
 game.run_configuration = Run.RunPlan.Configuration.new([act_path])
 game.run_configuration.single_act_test = true
 game.run_configuration.zone_count = 1
 game.run_configuration.selected_theme_ids = ["green_hill"]
 game.character_id = "sage"
 game.practice_mode = true
 game.replay_seed = 18
 add_child(game)
 move_child(game, 0)
 if game.camera_input_container: game.camera_input_container.hide()
 if game.hud: game.hud.hide()
 while not game.started and game.last_source_error.is_empty() and not closing:
  if is_instance_valid(game.library) and not game.library.error.is_empty(): break
  await get_tree().process_frame
 if closing: return
 if not game.started:
  var reason: String = game.library.error if is_instance_valid(game.library) and not game.library.error.is_empty() else game.last_source_error
  _select_camera(cameras.get_item_index(STUDIO))
  %ViewStatus.text = "Clover Scoop could not load. " + reason
  %ViewStatus.show()
  await game.prepare_to_close()
  game.queue_free()
  game = null
  get_tree().paused = false
  return
 game.select_play_camera(DEFAULT_CAMERA)
 game.presentation.reset_camera(game.ball.position)
 game.character._process(0.0)
 var original: Camera3D = game.presentation.camera
 game.controls.input_blocked = true
 game.ball.freeze = true
 game.process_mode = Node.PROCESS_MODE_DISABLED
 game.character.set_process(false)
 game.character_pose.inspect(true)
 game.character.spin_root.hide()
 game.presentation.ball_visual.hide()
 get_tree().paused = true
 table_effects = game.retro_filter.selected_effects.duplicate()
 _set_table_filters(false)
 table_camera = original.duplicate()
 original.get_parent().add_child(table_camera)
 table_camera.set_orthogonal(1.0, game.character_pose.radius * 0.05, original.far)
 table_camera.make_current()
 %ViewStatus.hide()
 _select_camera(cameras.selected)

func _connect_controls() -> void:
 for clip: String in STATES:
  var index := clips.add_item(clip)
  clips.set_item_tooltip(index, "%d · %s" % [index + 1, clip])
 clips.item_selected.connect(_select_clip)
 for rate: float in RATES: speed.add_item("%s×" % str(rate).trim_suffix(".0"))
 speed.select(RATES.find(1.0))
 cameras.add_item("Studio", STUDIO)
 cameras.add_separator("Clover Scoop")
 for preset: int in Run.PLAY_CAMERAS: cameras.add_item(TablePresentation.CAMERA_NAMES[preset], preset)
 cameras.item_selected.connect(_select_camera)
 %GameFilters.toggled.connect(_set_table_filters)
 timeline.value_changed.connect(_scrub)
 %PlayPause.pressed.connect(_toggle_playback)
 %Restart.pressed.connect(_restart)
 %ReplayMorph.pressed.connect(_replay_morph)
 %CoreOpacity.set_value_no_signal(float(actor.shell.get_shader_parameter("opacity")) * 100.0)
 %CoreOpacity.value_changed.connect(func(percent: float): actor.shell.set_shader_parameter("opacity", percent / 100.0))
 %MorphTime.set_value_no_signal(actor.transform_seconds)
 %MorphTime.value_changed.connect(func(duration: float): actor.transform_seconds = duration)
 %ResetView.pressed.connect(_reset_view)
 %StageInput.gui_input.connect(_stage_input)
 %StageInput.resized.connect(_aim_camera)
 var buttons := ButtonGroup.new()
 for i in 3:
  var button := %Steering.get_child(i + 1) as Button
  button.toggle_mode = true
  button.button_group = buttons
  button.pressed.connect(_steer.bind(i - 1))
 _steer(0)

func _select_clip(index: int) -> void:
 clips.select(index)
 var clip: String = STATES[index]
 actor.play(clip, playing)
 %Steering.visible = clip in Actor.STEERED
 %BallSettings.visible = clip == Actor.BALL
 # The shader runs continuously. Give the playhead a four-second inspection range.
 timeline.set_value_no_signal(0.0)
 timeline.max_value = BALL_PREVIEW_SECONDS if clip == Actor.BALL else actor.player.get_animation(clip).length
 seconds = 0.0
 playhead = 0.0
 _show_frame()

func _restart() -> void:
 _select_clip(clips.get_selected_items()[0])

func _replay_morph() -> void:
 actor.play(actor.rig_clip)
 _set_playing(true)
 _select_clip(STATES.find(Actor.BALL))

func _set_playing(enabled: bool) -> void:
 playing = enabled
 %PlayPause.text = "Pause" if playing else "Play"

func _toggle_playback() -> void:
 _set_playing(not playing)

func _scrub(value: float) -> void:
 _set_playing(false)
 actor.morph = false
 seconds = value
 playhead = value
 _show_frame()

func _steer(direction: int) -> void:
 actor.steer(direction)
 (%Steering.get_child(direction + 2) as Button).button_pressed = true
 actor.pose_on_table(pose_basis, seconds)

func _process(delta: float) -> void:
 if inspecting and playing:
  seconds += delta * float(RATES[speed.selected])
  playhead = fposmod(seconds, timeline.max_value)
  _show_frame()

func _show_frame() -> void:
 actor.pose_on_table(pose_basis, seconds)
 actor.sample(seconds, playhead)
 timeline.set_value_no_signal(playhead)
 %Time.text = "%.2f / %.2f s" % [playhead, timeline.max_value]

func _select_camera(index: int) -> void:
 cameras.select(index)
 var studio := cameras.get_item_id(index) == STUDIO
 if not studio and not is_instance_valid(table_camera):
  %ViewStatus.text = "Loading %s…" % act_path.get_file().get_basename()
  %ViewStatus.show()
  if not is_instance_valid(game): _load_table()
  return
 %ViewStatus.hide()
 %Studio.visible = studio
 %GameFilters.visible = not studio
 if is_instance_valid(game) and game.camera_input_container: game.camera_input_container.visible = not studio
 var host: Node3D
 if studio:
  host = %Studio
  camera = %Studio.get_node("Camera")
  pose_basis = Basis.IDENTITY
  view_basis = Basis(Vector3.UP, deg_to_rad(12.0)) * Basis(Vector3.RIGHT, deg_to_rad(-6.0))
  radius = actor.ball_radius
  anchor = Vector3.UP * (Actor.HEIGHT * 0.5 + 0.085)
 else:
  host = game.presentation
  camera = table_camera
  game.select_play_camera(cameras.get_item_id(index))
  game.presentation.reset_camera(game.ball.position)
  camera.projection = game.presentation.camera.projection
  camera.fov = game.presentation.camera.fov
  view_basis = game.presentation.camera.global_basis.orthonormalized()
  pose_basis = view_basis
  radius = game.character_pose.radius
  anchor = game.character.spin_root.global_position
 if actor.get_parent() != host:
  var held_pose := actor.player.current_animation_position
  actor.reparent(host, false)
  actor.player.play(actor.rig_clip)
  actor.player.advance(0.0)
  actor.player.seek(held_pose, true)
 actor.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius / actor.ball_radius), anchor)
 camera.make_current()
 _reset_view()
 _show_frame()

func _set_table_filters(enabled: bool) -> void:
 game.retro_filter.set_effects(table_effects if enabled else [])

func _reset_view() -> void:
 zoom = 1.0
 orbit_yaw = 0.0
 orbit_pitch = 0.0
 _aim_camera()

func _aim_camera() -> void:
 if not inspecting or not camera: return
 var axes := view_basis.rotated(view_basis.x, orbit_pitch).rotated(Vector3.UP, orbit_yaw)
 var studio := camera != table_camera
 var focus := anchor + Vector3.UP * radius * (0.65 if studio else 0.34)
 camera.size = (4.35 if studio else 4.8) * radius / zoom
 # Center the rig in the stage area to the right of the panel.
 var viewport_size := get_viewport().get_visible_rect().size
 var span := viewport_size.y if camera.keep_aspect == Camera3D.KEEP_HEIGHT else viewport_size.x
 if %Sidebar.visible: focus -= axes.x * camera.size * %Sidebar.get_global_rect().end.x * 0.5 / maxf(1.0, span)
 var distance := radius * 14.0
 if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
  distance = camera.size * 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
 camera.global_transform = Transform3D(axes, focus + axes.z * distance)

func _stage_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
  orbit_yaw -= event.relative.x * 0.007
  orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.005, -1.2, 1.2)
 elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
  zoom = clampf(zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.25, 2.2)
 else: return
 _aim_camera()
 %StageInput.accept_event()

func _input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode == KEY_ESCAPE: _close()
 elif not inspecting: return
 elif event.keycode == KEY_F11:
  var window := get_window()
  window.mode = Window.MODE_FULLSCREEN if window.mode == Window.MODE_WINDOWED else Window.MODE_WINDOWED
  if window.mode == Window.MODE_WINDOWED: Review.position_review_window(window)
 elif event.keycode == KEY_TAB and not event.ctrl_pressed:
  %Sidebar.visible = not %Sidebar.visible
  get_viewport().gui_release_focus()
  _aim_camera()
 elif get_viewport().gui_get_focus_owner() is LineEdit: return
 elif event.keycode >= KEY_1 and event.keycode <= KEY_8: _select_clip(event.keycode - KEY_1)
 elif event.keycode == KEY_SPACE: _toggle_playback()
 elif event.keycode == KEY_R and actor.action == Actor.BALL: _replay_morph()
 elif event.keycode in [KEY_LEFT, KEY_RIGHT] and actor.action in Actor.STEERED and not timeline.has_focus():
  _steer(-1 if event.keycode == KEY_LEFT else 1)
 else: return
 get_viewport().set_input_as_handled()

func _close() -> void:
 if closing: return
 closing = true
 inspecting = false
 if is_instance_valid(game): await game.prepare_to_close()
 get_tree().paused = false
 get_tree().quit()
