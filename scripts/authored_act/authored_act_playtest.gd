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
const GreenHill = preload("res://experiments/visual_lab/green_hill_presentation.gd")
const SonicPresenter = preload("res://experiments/visual_lab/sonic_presenter.gd")
const Dimensions = preload("res://scripts/act_dimensions.gd")
const RingTrails = preload("res://scripts/act_editor/ring_trails.gd")
const SAMPLE_PATH := "res://data/acts/playtest_showcase.tres"
const COMPARISON_PATH := "res://data/acts/scale_comparison.tres"

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
var green_hill: TablePresentation
var character: Node3D
var ring_field: RingField
var rings_collected := 0
var debug_2d := false
var marker_overlay: Node3D
var view_button: Button
var guides_button: Button
var guides_visible := false
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
 _button(toolbar, "Compare", func(): load_act(COMPARISON_PATH))
 _button(toolbar, "Reload", func():
  if not current_path.is_empty(): load_act(current_path)
 )
 _button(toolbar, "Serve", launch_ball)
 _button(toolbar, "Reset", reset_ball)
 pause_button = _button(toolbar, "Pause", toggle_pause)
 view_button = _button(toolbar, "F2: Debug 2D", toggle_view)
 guides_button = _button(toolbar, "F3: Guides", toggle_guides)
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
 view.own_world_3d = true
 view.msaa_3d = Viewport.MSAA_4X
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
 help.text = "Q / E: flippers   ← / →: steer   Enter / gamepad X: serve   R: reset   Esc: pause   F2: view   F3: guides\nShared editor/runtime proportions · Exact saved positions · Authoritative 2D physics · Green Hill presentation"
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
 var rings_started := Time.get_ticks_usec()
 var next_rings := RingField.new()
 next_rings.name = "AuthoredRingField"
 next_rings.ball = candidate_ball
 next_rings.tuning = tuning
 next_rings.ring_radius = Dimensions.RING_RADIUS_CELLS * float(candidate.cell_size)
 next_rings.previous_ball_position = candidate.spawn_position
 for trail: Dictionary in candidate.ring_trails:
  for point: Vector2 in RingTrails.positions(trail):
   next_rings.add_ring(point)
 next_simulation.add_child(next_rings)
 var rings_ms := (Time.get_ticks_usec() - rings_started) / 1000.0
 var presentation_started := Time.get_ticks_usec()
 var next_presentation := Presentation.new()
 next_presentation.name = "CollisionlessDebugPresentation"
 next_presentation.document = candidate
 next_presentation.runtime = compiled
 next_presentation.ball = candidate_ball
 next_presentation.ring_field = next_rings
 next_simulation.add_child(next_presentation)
 # Construct and validate the replacement before removing a currently playable Act.
 if is_instance_valid(simulation):
  view.remove_child(simulation)
  simulation.queue_free()
 document = candidate
 runtime = compiled
 simulation = next_simulation
 ball = candidate_ball
 ring_field = next_rings
 presentation = next_presentation
 view.add_child(simulation)
 green_hill = GreenHill.new()
 green_hill.name = "AuthoredGreenHill"
 green_hill.ball = ball
 green_hill.flippers = runtime.flippers
 green_hill.ring_field = ring_field
 simulation.add_child(green_hill)
 green_hill.build_authored(runtime, Rect2(Vector2.ZERO, document.red_gutter_bounds().end), float(document.cell_size))
 character = SonicPresenter.new()
 character.name = "AuthoredSonicVisual"
 character.study_enabled = false
 character.ball = ball
 character.table = green_hill
 green_hill.add_child(character)
 _build_guides()
 _apply_view()
 var presentation_ms := (Time.get_ticks_usec() - presentation_started) / 1000.0
 current_path = path
 last_error = ""
 activation_count = 0
 exit_count = 0
 drain_count = 0
 rings_collected = 0
 ball.bumper_hit.connect(func(_collider: Node): _refresh_events())
 ball.bumper_hit.connect(green_hill.flash_bumper)
 ring_field.collected.connect(func(_position: Vector2):
  rings_collected += 1
  _refresh_events()
 )
 reset_ball()
 _fit_camera()
 timings = {"load_ms": load_ms, "terrain_ms": compiled.timings.terrain_ms,
  "objects_ms": compiled.timings.objects_ms + rings_ms, "presentation_ms": presentation_ms,
  "total_ms": (Time.get_ticks_usec() - started) / 1000.0}
 title_label.text = "ACT / " + str(document.title)
 path_label.text = path
 path_label.tooltip_text = path
 metrics_label.text = "Load %.2f ms · Terrain %.2f ms · Objects %.2f ms · Green Hill %.2f ms · Act ready %.2f ms" % [timings.load_ms, timings.terrain_ms, timings.objects_ms, timings.presentation_ms, timings.total_ms]
 _refresh_events()
 print("AUTHORED_ACT_READY | ", metrics_label.text, " | terrain=", document.placements.size(), " objects=", document.gameplay_objects.size(), " rings=", ring_field.rings.size())
 act_loaded.emit(path)
 return true

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo or picker.visible:
  return
 if event.keycode == KEY_F2:
  toggle_view()
  get_viewport().set_input_as_handled()
 elif event.keycode == KEY_F3:
  toggle_guides()
  get_viewport().set_input_as_handled()

func toggle_view() -> void:
 debug_2d = not debug_2d
 _apply_view()

func _apply_view() -> void:
 if is_instance_valid(presentation):
  presentation.visible = debug_2d
 if is_instance_valid(green_hill):
  green_hill.visible = not debug_2d
 view.disable_3d = debug_2d
 view_button.text = "F2: Green Hill" if debug_2d else "F2: Debug 2D"

func toggle_guides() -> void:
 guides_visible = not guides_visible
 if is_instance_valid(marker_overlay):
  marker_overlay.visible = guides_visible
  green_hill.construction_grid_overlay.visible = guides_visible
 guides_button.text = "F3: Hide guides" if guides_visible else "F3: Guides"

func _build_guides() -> void:
 marker_overlay = Node3D.new()
 marker_overlay.name = "AuthoredGuides"
 green_hill.add_child(marker_overlay)
 marker_overlay.visible = guides_visible
 green_hill.construction_grid_overlay.visible = guides_visible
 var bounds: Rect2 = document.terrain_bounds()
 var cell := float(document.cell_size)
 var trigger_material := green_hill.debug_material(Color("62eee3"))
 var connector_material := green_hill.debug_material(Color("71efa4"))
 var spawn_material := green_hill.debug_material(Color("f4aedd"))
 var drain_material := green_hill.debug_material(Color("ff647e"))
 var radius := cell * TablePresentation.SCALE * 0.007
 var height := TablePresentation.OVERLAY_HEIGHT
 if document.activation_y != null:
  var trigger_y := float(document.activation_y)
  green_hill.line(Vector2(0, trigger_y), Vector2(bounds.end.x, trigger_y), radius * 1.5, height, trigger_material, marker_overlay)
  _guide_label("ACTIVATION", Vector2(cell * 0.2, trigger_y - cell * 0.15), Color("62eee3"))
 for kind: String in ["entry", "exit"]:
  var span: Dictionary = document.get_connector(kind)
  if span.width == 0: continue
  var y := bounds.end.y if kind == "entry" else 0.0
  var a := Vector2(span.start_x * cell, y)
  var b := Vector2((span.start_x + span.width) * cell, y)
  green_hill.line(a, b, radius * 2.0, height, connector_material, marker_overlay)
  _guide_label(kind.to_upper(), (a + b) * 0.5 + Vector2(0, cell * 0.18), Color("71efa4"))
 var gutter: Rect2 = document.red_gutter_bounds()
 green_hill.line(Vector2(0, gutter.end.y), gutter.end, radius * 2.0, height, drain_material, marker_overlay)
 _guide_label("DRAIN", gutter.get_center(), Color("ff647e"))
 var spawn: Vector2 = document.spawn_position
 var marker_size := cell * 0.12
 green_hill.line(spawn - Vector2(marker_size, 0), spawn + Vector2(marker_size, 0), radius * 1.5, height, spawn_material, marker_overlay)
 green_hill.line(spawn - Vector2(0, marker_size), spawn + Vector2(0, marker_size), radius * 1.5, height, spawn_material, marker_overlay)
 _guide_label("SPAWN", spawn + Vector2(cell * 0.3, -cell * 0.2), Color("f4aedd"))

func _guide_label(text: String, point: Vector2, color: Color) -> void:
 var label := Label3D.new()
 label.text = text
 label.font_size = 32
 label.outline_size = 4
 label.pixel_size = float(document.cell_size) * TablePresentation.SCALE * 0.01
 label.modulate = color
 label.no_depth_test = true
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.position = TablePresentation.map_point(point, TablePresentation.OVERLAY_HEIGHT)
 marker_overlay.add_child(label)

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
 if is_instance_valid(ring_field):
  ring_field.previous_ball_position = document.spawn_position
  ring_field.reset_rings()
 if is_instance_valid(green_hill):
  green_hill.reset_camera(document.spawn_position)
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
 events_label.text = "Activation: %s   |   Exit: %s   |   Drains: %d   |   Bumper hits: %d   |   Rings: %d" % [activation, exit, drain_count, ball.bumper_hit_count, rings_collected]

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
