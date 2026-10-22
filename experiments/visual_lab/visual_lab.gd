extends "res://scripts/game.gd"
## Isolated visual experiment; the ordinary playground scene and physics stay unchanged.
const GreenHill := preload("res://experiments/visual_lab/green_hill_presentation.gd")
const SonicPresenter := preload("res://experiments/visual_lab/sonic_presenter.gd")
var character: Node3D
var lab_ui: CanvasLayer
var pose_label: Label
var status_label: Label
var score_label_lab: Label
var view_button: Button
var pose_buttons: Dictionary = {}
var close_view := false
var _pause_before_close := false
var _capture_kind := ""
var _capture_frames := 75
var _frame_count := 0
var _capture_started := false
var _capture_sequence := false
var _sequence_index := 0

func _ready() -> void:
 DisplayServer.window_set_title("Sonic Spinball Runners — Green Hill Visual Lab")
 super._ready()
 if not is_instance_valid(ball):
  return
 process_mode = Node.PROCESS_MODE_ALWAYS
 # Only the visual/UI adapter processes during pause.
 world.process_mode = Node.PROCESS_MODE_PAUSABLE
 ring_field.process_mode = Node.PROCESS_MODE_PAUSABLE
 debug_panel.visible = false
 _build_lab_ui()
 ball.bumper_hit.connect(func(_body: Node): character.show_event("trick", 0.8))
 for flipper: PlaygroundFlipper in flippers:
  flipper.struck.connect(func(): character.show_event("jump", 0.62))
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--capture="):
   _capture_kind = argument.trim_prefix("--capture=")
  elif argument.begins_with("--capture-frames="):
   _capture_frames = maxi(10, int(argument.trim_prefix("--capture-frames=")))
  elif argument == "--sequence":
   _capture_sequence = true
 if not _capture_kind.is_empty():
  get_tree().paused = true
  if _capture_kind == "gameplay":
   character.select_preview("idle")
  else:
   _set_close_view(true)
   _select_pose(_capture_kind if _capture_kind in ["roll", "idle", "jump", "trick"] else "idle")
  if not _capture_sequence:
   character.seek_pose(0.55)
 print("VISUAL_LAB_READY | 1-4 poses | C close-up | Enter launch | Q/E flippers | arrows steer")

func _build_view() -> void:
 var container := SubViewportContainer.new()
 container.name = "GreenHillFullWindowView"
 container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 container.stretch = true
 container.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(container)
 container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 container.offset_bottom = -146.0
 view = SubViewport.new()
 view.name = "CollisionlessVisualLabViewport"
 view.size = Vector2i(1280, 900)
 view.own_world_3d = true
 view.msaa_3d = Viewport.MSAA_4X
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 container.add_child(view)
 _build_presentation()

func _build_presentation() -> void:
 presentation = GreenHill.new()
 presentation.name = "GreenHillPresentation"
 presentation.ball = ball
 presentation.flippers = flippers
 presentation.ring_field = ring_field
 view.add_child(presentation)
 presentation.build(chunks, layout.junctions, layout.bounds)
 character = SonicPresenter.new()
 character.name = "SonicVisualAdapter"
 character.ball = ball
 character.table = presentation
 presentation.add_child(character)

func _panel_style(color: Color, radius: int = 12) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = color
 style.corner_radius_top_left = radius
 style.corner_radius_top_right = radius
 style.corner_radius_bottom_left = radius
 style.corner_radius_bottom_right = radius
 style.content_margin_left = 18.0
 style.content_margin_right = 18.0
 style.content_margin_top = 12.0
 style.content_margin_bottom = 12.0
 return style

func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
 var label := Label.new()
 label.text = text
 label.add_theme_font_size_override("font_size", size)
 label.add_theme_color_override("font_color", color)
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return label

func _button(text: String, callback: Callable) -> Button:
 var button := Button.new()
 button.text = text
 button.focus_mode = Control.FOCUS_NONE
 button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 button.add_theme_font_size_override("font_size", 17)
 button.add_theme_stylebox_override("normal", _panel_style(Color("143b3f"), 8))
 button.add_theme_stylebox_override("hover", _panel_style(Color("236269"), 8))
 button.add_theme_stylebox_override("pressed", _panel_style(Color("397f79"), 8))
 button.pressed.connect(callback)
 return button

func _build_lab_ui() -> void:
 lab_ui = CanvasLayer.new()
 lab_ui.layer = 20
 lab_ui.name = "VisualLabOverlay"
 add_child(lab_ui)
 var root := Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 lab_ui.add_child(root)
 var title_panel := PanelContainer.new()
 title_panel.position = Vector2(24, 24)
 title_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.13, 0.16, 0.91)))
 title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 root.add_child(title_panel)
 var title_stack := VBoxContainer.new()
 title_stack.add_theme_constant_override("separation", 2)
 title_panel.add_child(title_stack)
 title_stack.add_child(_label("SONIC SPINBALL RUNNERS", 13, Color("a4e5e3")))
 title_stack.add_child(_label("GREEN HILL", 31, Color("ffe373")))
 title_stack.add_child(_label("V I S U A L   L A B", 12, Color("ffffff")))
 var score_panel := PanelContainer.new()
 score_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 score_panel.position = Vector2(-250, 24)
 score_panel.size = Vector2(226, 98)
 score_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.13, 0.16, 0.91)))
 score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 root.add_child(score_panel)
 var scores := VBoxContainer.new()
 score_panel.add_child(scores)
 scores.add_child(_label("RINGS / SCORE", 12, Color("a4e5e3")))
 score_label_lab = _label("00 / 000000", 25, Color("ffe373"))
 scores.add_child(score_label_lab)
 var footer := PanelContainer.new()
 footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 footer.offset_left = 24
 footer.offset_right = -24
 footer.offset_top = -132
 footer.offset_bottom = -22
 footer.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.13, 0.16, 0.94)))
 root.add_child(footer)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 8)
 footer.add_child(stack)
 var top_row := HBoxContainer.new()
 top_row.add_theme_constant_override("separation", 10)
 stack.add_child(top_row)
 pose_label = _label("IDLE / READY TO LAUNCH", 14, Color("ffe373"))
 pose_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 top_row.add_child(pose_label)
 status_label = _label("", 12, Color("a4e5e3"))
 top_row.add_child(status_label)
 var buttons := HBoxContainer.new()
 buttons.add_theme_constant_override("separation", 8)
 stack.add_child(buttons)
 var labels := ["1  Rolling", "2  Idle", "3  Jump", "4  Trick"]
 var poses := ["roll", "idle", "jump", "trick"]
 for i in poses.size():
  var value: String = poses[i]
  var button := _button(labels[i], func(): _select_pose(value))
  pose_buttons[value] = button
  buttons.add_child(button)
 var space := Control.new()
 space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 buttons.add_child(space)
 view_button = _button("C  Character close-up", func(): _set_close_view(not close_view))
 buttons.add_child(view_button)
 stack.add_child(_label("ENTER  Launch     Q / E  Flippers     ← / →  Steer     ESC  Pause     R  Reset     1  Resume automatic poses", 13, Color("cce5e0")))

func _select_pose(value: String) -> void:
 character.capture_hold = false
 character.select_preview(value)
 get_viewport().gui_release_focus()

func _set_close_view(enabled: bool) -> void:
 close_view = enabled
 if enabled:
  _pause_before_close = get_tree().paused
  get_tree().paused = true
 else:
  get_tree().paused = _pause_before_close
  character.select_preview("roll")
 character.set_close_view(enabled)
 if is_instance_valid(view_button):
  view_button.text = "C  Back to playfield" if enabled else "C  Character close-up"
 get_viewport().gui_release_focus()

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo:
  return
 match event.physical_keycode:
  KEY_1: _select_pose("roll")
  KEY_2: _select_pose("idle")
  KEY_3: _select_pose("jump")
  KEY_4: _select_pose("trick")
  KEY_C: _set_close_view(not close_view)

func toggle_pause() -> void:
 if close_view:
  _set_close_view(false)
 else:
  super.toggle_pause()

func _physics_process(delta: float) -> void:
 if not get_tree().paused:
  super._physics_process(delta)

func _process(_delta: float) -> void:
 if not is_instance_valid(character) or not is_instance_valid(pose_label):
  return
 debug_panel.visible = false
 var context := "CHARACTER STUDY" if close_view else ("PAUSED" if get_tree().paused else ("READY TO LAUNCH" if ball.serve_pending else "LIVE PLAY"))
 pose_label.text = "%s / %s" % [character.pose.to_upper(), context]
 score_label_lab.text = "%02d / %06d" % [rings_collected, score]
 status_label.text = character.model_status
 for value: String in pose_buttons:
  pose_buttons[value].modulate = Color("ffe373") if character.pose == value else Color.WHITE
 if not _capture_kind.is_empty():
  _frame_count += 1
  if _frame_count >= _capture_frames and not _capture_started:
   _capture_started = true
   _save_capture()

func _save_capture() -> void:
 # Root viewport includes the UI and exact camera composition shown during play.
 await RenderingServer.frame_post_draw
 var directory := ProjectSettings.globalize_path("res://experiments/visual_lab/captures")
 DirAccess.make_dir_recursive_absolute(directory)
 var ignore := FileAccess.open(directory.path_join(".gdignore"), FileAccess.WRITE)
 if ignore != null:
  ignore.close()
 var file := _capture_kind + (("_%03d" % _sequence_index) if _capture_sequence else "") + ".png"
 var result := get_viewport().get_texture().get_image().save_png(directory.path_join(file))
 print("VISUAL_LAB_CAPTURE | ", file, " | ", error_string(result))
 if _capture_sequence and _sequence_index < 47:
  _sequence_index += 1
  if _capture_kind == "reel" and _sequence_index % 12 == 0:
   _select_pose(["idle", "jump", "trick", "roll"][_sequence_index / 12])
  _frame_count = _capture_frames - 4
  _capture_started = false
 else:
  get_tree().quit(0 if result == OK else 1)
