extends Control
## One saved authored Act, using existing authoritative gameplay physics.
signal act_activated
signal exit_reached
signal drained
signal act_loaded(path: String)
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const Lifecycle = preload("res://scripts/authored_act/act_lifecycle.gd")
const Presentation = preload("res://scripts/authored_act/playtest_presentation.gd")
const SAMPLE_PATH := "res://data/acts/playtest_showcase.tres"

var document: Resource
var runtime: Dictionary = {}
var ball: PlaygroundBall
var controls: PlaygroundInput
var tuning: PhysicsTuning
var activation_count := 0
var exit_count := 0
var drain_count := 0
var current_path := ""
var last_error := ""
var timings: Dictionary = {}
var view: SubViewport
var camera: Camera2D
var simulation: Node2D
var presentation: Node2D
var picker: FileDialog
var title_label: Label
var path_label: Label
var status_label: Label
var events_label: Label
var metrics_label: Label
var pause_button: Button
var _previous_position := Vector2.ZERO
var _motion_ready := false
var _auto_launch := -1.0
var _dialog_was_paused := false
var _previous_tree_pause := false

func _ready() -> void:
 _previous_tree_pause = get_tree().paused
 process_mode = Node.PROCESS_MODE_ALWAYS
 tuning = PhysicsTuning.new()
 tuning.name = "SharedPhysicsTuning"
 add_child(tuning)
 controls = PlaygroundInput.new()
 controls.name = "SharedInput"
 add_child(controls)
 controls.launch_requested.connect(launch_ball)
 controls.reset_requested.connect(reset_ball)
 controls.pause_requested.connect(toggle_pause)
 _build_ui()
 var args := OS.get_cmdline_user_args()
 var index := args.find("--act")
 if index >= 0:
  if index + 1 < args.size():
   load_act(args[index + 1])
  else:
   _error("--act requires a saved Act .tres path.")
 else:
  _set_status("Choose Load Act or Example. Spawn is required; Enter releases the ball into normal gravity.")

func _build_ui() -> void:
 var background := ColorRect.new()
 background.color = Color("0b1420")
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(background)
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side: String in ["left", "top", "right", "bottom"]:
  margin.add_theme_constant_override("margin_" + side, 16)
 add_child(margin)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 8)
 margin.add_child(column)
 var toolbar := HBoxContainer.new()
 column.add_child(toolbar)
 title_label = Label.new()
 title_label.text = "AUTHORED ACT / PLAYTEST"
 title_label.add_theme_font_size_override("font_size", 22)
 title_label.add_theme_color_override("font_color", Color("70e5d5"))
 title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 toolbar.add_child(title_label)
 _button(toolbar, "Load Act", open_picker)
 _button(toolbar, "Example", func(): load_act(SAMPLE_PATH))
 _button(toolbar, "Reload", func():
  if not current_path.is_empty(): load_act(current_path)
 )
 _button(toolbar, "Serve", launch_ball)
 _button(toolbar, "Reset", reset_ball)
 pause_button = _button(toolbar, "Pause", toggle_pause)
 path_label = Label.new()
 path_label.text = "No Act loaded"
 path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 column.add_child(path_label)
 events_label = Label.new()
 column.add_child(events_label)
 var container := SubViewportContainer.new()
 container.stretch = true
 container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 container.size_flags_vertical = Control.SIZE_EXPAND_FILL
 container.custom_minimum_size = Vector2(400, 300)
 container.mouse_filter = Control.MOUSE_FILTER_IGNORE
 column.add_child(container)
 view = SubViewport.new()
 view.name = "PlayfieldViewport"
 view.disable_3d = true
 view.world_2d = World2D.new()
 view.process_mode = Node.PROCESS_MODE_PAUSABLE
 view.size = Vector2i(1000, 650)
 container.add_child(view)
 camera = Camera2D.new()
 view.add_child(camera)
 camera.make_current()
 container.resized.connect(func(): call_deferred("_fit_camera"))
 metrics_label = Label.new()
 metrics_label.add_theme_font_size_override("font_size", 12)
 metrics_label.add_theme_color_override("font_color", Color("a5bbcb"))
 column.add_child(metrics_label)
 status_label = Label.new()
 status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 status_label.custom_minimum_size.y = 24
 column.add_child(status_label)
 var help := Label.new()
 help.text = "Q / E: flippers   ← / →: steer   Enter / gamepad X: serve   R: reset   Esc: pause\nActual runtime object sizes · Exact saved positions · No procedural generation · Source file is read-only"
 help.add_theme_font_size_override("font_size", 13)
 help.add_theme_color_override("font_color", Color("a5bbcb"))
 column.add_child(help)
 picker = FileDialog.new()
 picker.title = "Load an authored Act"
 picker.access = FileDialog.ACCESS_FILESYSTEM
 picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
 picker.filters = PackedStringArray(["*.tres ; Authored Act Resource"])
 var saved_folder := ProjectSettings.globalize_path("user://acts")
 picker.current_dir = saved_folder if DirAccess.dir_exists_absolute(saved_folder) else ProjectSettings.globalize_path("res://data/acts")
 picker.file_selected.connect(func(path: String):
  load_act(path)
  _finish_picker()
 )
 picker.canceled.connect(_finish_picker)
 add_child(picker)
 _refresh_events()

func _button(parent: Control, text: String, action: Callable) -> Button:
 var button := Button.new()
 button.text = text
 button.focus_mode = Control.FOCUS_NONE
 button.pressed.connect(action)
 parent.add_child(button)
 return button

func open_picker() -> void:
 _dialog_was_paused = get_tree().paused
 _set_paused(true)
 controls.input_blocked = true
 picker.popup_centered(Vector2i(900, 620))

func _finish_picker() -> void:
 controls.input_blocked = false
 _set_paused(_dialog_was_paused)

func load_act(path: String) -> bool:
 var started := Time.get_ticks_usec()
 var loaded: Dictionary = ActData.load_document(path)
 var load_ms := (Time.get_ticks_usec() - started) / 1000.0
 if loaded.document == null:
  return _error(loaded.error)
 var candidate: Resource = loaded.document
 var candidate_ball := PlaygroundBall.new()
 candidate_ball.name = "AuthoritativeBall"
 candidate_ball.tuning = tuning
 candidate_ball.controls = controls
 var compiled: Dictionary = Compiler.compile(candidate, tuning, controls, candidate_ball)
 if not compiled.error.is_empty():
  candidate_ball.free()
  return _error(compiled.error)
 var next_simulation := Node2D.new()
 next_simulation.name = "AuthoredActPhysics"
 candidate_ball.position = candidate.spawn_position
 candidate_ball.serve_position = candidate.spawn_position
 next_simulation.add_child(candidate_ball)
 next_simulation.add_child(compiled.root)
 var presentation_started := Time.get_ticks_usec()
 var next_presentation := Presentation.new()
 next_presentation.name = "CollisionlessDebugPresentation"
 next_presentation.document = candidate
 next_presentation.runtime = compiled
 next_presentation.ball = candidate_ball
 next_simulation.add_child(next_presentation)
 var presentation_ms := (Time.get_ticks_usec() - presentation_started) / 1000.0
 # Construct and validate the replacement before removing a currently playable Act.
 if is_instance_valid(simulation):
  view.remove_child(simulation)
  simulation.queue_free()
 document = candidate
 runtime = compiled
 simulation = next_simulation
 ball = candidate_ball
 presentation = next_presentation
 view.add_child(simulation)
 current_path = path
 last_error = ""
 activation_count = 0
 exit_count = 0
 drain_count = 0
 ball.bumper_hit.connect(func(_collider: Node): _refresh_events())
 reset_ball()
 _fit_camera()
 timings = {"load_ms": load_ms, "terrain_ms": compiled.timings.terrain_ms,
  "objects_ms": compiled.timings.objects_ms, "presentation_ms": presentation_ms,
  "total_ms": (Time.get_ticks_usec() - started) / 1000.0}
 title_label.text = "ACT / " + str(document.title)
 path_label.text = path
 path_label.tooltip_text = path
 metrics_label.text = "Load %.2f ms · Terrain %.2f ms · Objects %.2f ms · Presentation %.2f ms · Act ready %.2f ms" % [timings.load_ms, timings.terrain_ms, timings.objects_ms, timings.presentation_ms, timings.total_ms]
 _refresh_events()
 print("AUTHORED_ACT_READY | ", metrics_label.text, " | terrain=", document.placements.size(), " objects=", document.gameplay_objects.size())
 act_loaded.emit(path)
 return true

func _fit_camera() -> void:
 if document == null or view == null:
  return
 var size: Vector2 = document.red_gutter_bounds().end
 camera.position = size * 0.5
 var available := Vector2(view.size).max(Vector2.ONE)
 var zoom_factor := minf(available.x / (size.x + 100), available.y / (size.y + 120))
 camera.zoom = Vector2.ONE * maxf(zoom_factor, 0.001)
 if is_instance_valid(presentation):
  presentation.units_per_pixel = 1.0 / camera.zoom.x

func launch_ball() -> void:
 if not is_instance_valid(ball) or get_tree().paused or picker.visible:
  return
 ball.launch()
 _auto_launch = -1.0
 _set_status("Playing this authored Act. Q/E flip; arrow keys steer.")

func reset_ball(relaunch: bool = false) -> void:
 if not is_instance_valid(ball):
  return
 ball.teleport_to(document.spawn_position, Vector2.ZERO, true)
 _previous_position = document.spawn_position
 _motion_ready = false
 _auto_launch = 0.25 if relaunch else -1.0
 _set_status("Ready at authored Spawn. Press Enter / Serve to release into normal gravity.")

func _physics_process(delta: float) -> void:
 if not is_instance_valid(ball) or get_tree().paused:
  return
 if _auto_launch >= 0:
  _auto_launch -= delta
  if _auto_launch <= 0:
   launch_ball()
 if ball._teleport_pending or ball.serve_pending:
  _previous_position = document.spawn_position
  _motion_ready = true
  return
 var current := ball.position
 if _motion_ready:
  process_motion(_previous_position, current)
 _previous_position = current
 _motion_ready = not ball._teleport_pending

func process_motion(from: Vector2, to: Vector2) -> Dictionary:
 var events: Dictionary = Lifecycle.crossings(document, from, to)
 if events.activation:
  activation_count += 1
  print("ACT ACTIVATED | upward crossing ", activation_count)
  _set_status("ACT ACTIVATED — upward Activation Trigger crossing.")
  act_activated.emit()
 if events.exit:
  exit_count += 1
  print("ACT EXIT REACHED | upward crossing ", exit_count)
  _set_status("ACT EXIT REACHED — play continues; no next Act is loaded.")
  exit_reached.emit()
 if events.drain:
  drain_count += 1
  print("ACT DRAIN | respawn ", drain_count, " at ", document.spawn_position)
  reset_ball(true)
  _set_status("DRAIN — returned to authored Spawn; serving again shortly.")
  drained.emit()
 _refresh_events()
 return events

func _refresh_events() -> void:
 if events_label == null:
  return
 if document == null:
  events_label.text = "ONE FILE · ONE PLAYABLE ACT"
  return
 var activation := "unset" if document.activation_y == null else ("ACT ACTIVATED ×%d" % activation_count if activation_count > 0 else "waiting for upward crossing")
 var exit := "unset" if document.exit_width == 0 else ("ACT EXIT REACHED ×%d" % exit_count if exit_count > 0 else "waiting for upward crossing")
 events_label.text = "Activation: %s   |   Exit: %s   |   Drains: %d   |   Bumper hits: %d" % [activation, exit, drain_count, ball.bumper_hit_count]

func toggle_pause() -> void:
 if picker.visible:
  return
 _set_paused(not get_tree().paused)

func _set_paused(value: bool) -> void:
 get_tree().paused = value
 if pause_button != null:
  pause_button.text = "Resume" if value else "Pause"

func _error(message: String) -> bool:
 last_error = message
 _set_status("Cannot load Act: " + message)
 print("AUTHORED_ACT_LOAD_FAILED | ", message)
 return false

func _set_status(message: String) -> void:
 if status_label != null:
  status_label.text = message

func _exit_tree() -> void:
 get_tree().paused = _previous_tree_pause
