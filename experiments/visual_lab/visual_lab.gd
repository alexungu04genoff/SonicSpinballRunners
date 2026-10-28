extends "res://scripts/game.gd"
## Authored Act player with selectable themes and development tools.
const ThemedPresentation := preload("res://scripts/themes/themed_presentation.gd")
const ThemeRegistry := preload("res://scripts/themes/theme_registry.gd")
const SonicPresenter := preload("res://experiments/visual_lab/sonic_presenter.gd")
const RetroFilter := preload("res://scripts/retro/retro_filter.gd")
const RetroControls := preload("res://scripts/retro/retro_controls.gd")
var retro_filter: RetroFilter
var retro_controls: CanvasLayer
var view_container: SubViewportContainer
var debug_open := false
var play_buttons: HBoxContainer
var study_buttons: HBoxContainer
var overview_button: Button
var character: Node3D
var lab_ui: CanvasLayer
var act_ui: CanvasLayer
var pose_label: Label
var status_label: Label
var score_label_lab: Label
var score_header_lab: Label
var score_feedback_lab: Label
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
var load_act_button: Button
var reload_act_button: Button
var act_picker: FileDialog
var source_note: Label
var _source_previous_pause := false
var _source_switch_pending := false
var fullscreen_button: Button
var _windowed_mode := DisplayServer.WINDOW_MODE_WINDOWED
var _windowed_size := Vector2i.ZERO
var _windowed_position := Vector2i.ZERO
var player_view := false
var development_footer: PanelContainer
var development_subtitle: Label
var player_hint: Label
var _development_state: Dictionary = {}
var _development_visibility: Dictionary = {}
var _overlay_visibility: Array[bool] = []
@export var theme_id := "green_hill"
var theme_selector: OptionButton
var theme_label: Label

func _ready() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--theme="):
   var requested_theme := argument.trim_prefix("--theme=")
   if requested_theme in ThemeRegistry.IDS:
    theme_id = requested_theme
  elif argument.begins_with("--character="):
   var requested := argument.trim_prefix("--character=")
   if CharacterSpecials.CHARACTERS.has(requested):
    character_id = requested
 super._ready()
 if not is_instance_valid(ball):
  return
 process_mode = Node.PROCESS_MODE_ALWAYS
 # Only the visual/UI adapter processes during pause.
 world.process_mode = Node.PROCESS_MODE_PAUSABLE
 ring_field.process_mode = Node.PROCESS_MODE_PAUSABLE
 debug_panel.visible = false
 _build_lab_ui()
 _refresh_theme_ui()
 _attach_act_ui()
 retro_filter = RetroFilter.new()
 retro_filter.name = "RetroFilter"
 add_child(retro_filter)
 retro_filter.attach(view_container, view)
 retro_controls = RetroControls.new()
 retro_controls.name = "RetroControls"
 add_child(retro_controls)
 retro_controls.install(retro_filter, debug_panel.camera_presets.get_parent(), play_buttons)
 get_viewport().size_changed.connect(_position_player_hud)
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--capture="):
   _capture_kind = argument.trim_prefix("--capture=")
  elif argument.begins_with("--capture-frames="):
   _capture_frames = maxi(10, int(argument.trim_prefix("--capture-frames=")))
  elif argument == "--sequence":
   _capture_sequence = true
 if not _capture_kind.is_empty():
  get_tree().paused = true
  if _capture_kind in ["gameplay", "overview"]:
   character.resume_gameplay()
   if _capture_kind == "overview":
    presentation.set_camera_follow(false)
  else:
   _set_close_view(true)
   _select_pose(_capture_kind if _capture_kind in ["roll", "idle", "jump", "trick", "homing", "impact", "fly"] else "idle")
  if not _capture_sequence:
   character.seek_pose(0.55)
 print("GREEN_HILL_READY | Enter roll in | Q/E flippers | arrows steer | F1 physics tuning | F4 retro filter | O overview | C study")

func _build_view() -> void:
 view_container = SubViewportContainer.new()
 camera_input_container = view_container
 var container := view_container
 container.name = "GreenHillFullWindowView"
 container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 container.stretch = true
 container.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(container)
 container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 container.offset_bottom = -210.0
 view = SubViewport.new()
 view.name = "CollisionlessVisualLabViewport"
 view.size = Vector2i(1280, 900)
 view.own_world_3d = true
 view.msaa_3d = Viewport.MSAA_4X
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 container.add_child(view)
 _build_presentation()

func _build_presentation() -> void:
 presentation = ThemedPresentation.new()
 presentation.set_theme_definition(ThemeRegistry.create(theme_id))
 presentation.name = "ThemedPresentation"
 presentation.camera_preset = TablePresentation.CameraPreset.DRAMATIC_PINBALL
 presentation.camera_settings.zoom = 2.0
 presentation.ball = ball
 presentation.flippers = flippers
 presentation.ring_field = ring_field
 view.add_child(presentation)
 presentation.rebuild_playfield(playfield)
 _add_playfield_feedback()
 character = SonicPresenter.new()
 character.name = "SonicVisualAdapter"
 character.set_meta("keep_on_playfield_rebuild", true)
 character.ball = ball
 character.table = presentation
 character.specials = specials
 presentation.add_child(character)

func _rebuild_presentation() -> void:
 super._rebuild_presentation()
 character.refresh_playfield()
 if player_view:
  for overlay: Node3D in _development_overlays():
   overlay.hide()

func set_theme(requested_id: String) -> bool:
 if requested_id not in ThemeRegistry.IDS:
  return false
 if requested_id == theme_id:
  return true
 if loading_act or close_view or is_source_picker_open():
  return false
 # This rebuild touches only disposable visuals. Preserve the live camera's
 # damping state as well as its pose; the shared level rebuild normally serves it.
 var camera_state := {
  "transform": presentation.camera.global_transform,
  "focus": presentation.camera_focus, "target": presentation.camera_target,
  "offset": presentation._camera_offset, "viewport": presentation._camera_viewport_size,
  "follow": presentation.camera_follow_enabled, "preset": presentation.camera_preset,
  "settings": presentation.camera_settings.duplicate(true),
  "projection": presentation.camera.projection, "fov": presentation.camera.fov,
  "size": presentation.camera.size,
 }
 var pickup_state := presentation.ring_pickups.duplicate(true)
 var bumper_flashes := presentation.flash_times.duplicate()
 var ball_transform := presentation.ball_visual.transform
 var ring_transforms: Array[Transform3D] = []
 var ring_visibility: Array[bool] = []
 for ring: MeshInstance3D in presentation.ring_visuals:
  ring_transforms.append(ring.transform)
  ring_visibility.append(ring.visible)
 theme_id = requested_id
 presentation.set_theme_definition(ThemeRegistry.create(theme_id))
 _rebuild_presentation()
 presentation.camera_focus = camera_state.focus
 presentation.camera_target = camera_state.target
 presentation._camera_offset = camera_state.offset
 presentation._camera_viewport_size = camera_state.viewport
 presentation.camera_follow_enabled = camera_state.follow
 presentation.camera_preset = camera_state.preset
 presentation.camera_settings = camera_state.settings
 presentation.camera.projection = camera_state.projection
 presentation.camera.fov = camera_state.fov
 presentation.camera.size = camera_state.size
 presentation.camera.global_transform = camera_state.transform
 # Pickup flights and bumper flashes use only scalar/vector state. Their new
 # meshes can resume those effects without changing collected rings or scores.
 presentation.ring_pickups = pickup_state
 presentation.flash_times = bumper_flashes
 presentation.ball_visual.transform = ball_transform
 for index in presentation.ring_visuals.size():
  presentation.ring_visuals[index].transform = ring_transforms[index]
  presentation.ring_visuals[index].visible = ring_visibility[index]
 _refresh_theme_ui()
 return true

func _select_theme(index: int) -> void:
 set_theme(str(theme_selector.get_item_metadata(index)))
 _refresh_theme_ui()
 get_viewport().gui_release_focus()

func _refresh_theme_ui() -> void:
 var title: String = presentation.theme_definition.display_name
 DisplayServer.window_set_title("Sonic Spinball Runners — " + title)
 if is_instance_valid(theme_label):
  theme_label.text = title.to_upper()
 if is_instance_valid(theme_selector):
  theme_selector.select(ThemeRegistry.IDS.find(theme_id))

func _add_playfield_feedback() -> void:
 _add_area_feedback()
 # The physics playground keeps its lightweight CharacterFeedback placeholder.
 # Green Hill supplies its own character, target and special feedback below.

func _attach_act_ui() -> void:
 # Keep Act replay and session loadout controls outside the hidden debug HUD.
 act_ui = CanvasLayer.new()
 act_ui.name = "AuthoredActOverlay"
 act_ui.layer = 22
 add_child(act_ui)
 debug_panel.act_controls.reparent(act_ui)
 _position_act_ui()

func _position_act_ui() -> void:
 var panel: Control = debug_panel.act_controls
 var row := panel.get_child(0) as HBoxContainer
 row.position = Vector2(25, 108) if debug_open else Vector2(24, 140)
 panel.hint.visible = debug_open
 panel.character_panel.position = Vector2(625, 155) if debug_open else Vector2(1005, 140)

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
 button.add_theme_font_size_override("font_size", 16)
 button.add_theme_stylebox_override("normal", _panel_style(Color("143b3f"), 8))
 button.add_theme_stylebox_override("hover", _panel_style(Color("236269"), 8))
 button.add_theme_stylebox_override("pressed", _panel_style(Color("397f79"), 8))
 for style_name: String in ["normal", "hover", "pressed"]:
  var style: StyleBoxFlat = button.get_theme_stylebox(style_name)
  style.content_margin_top = 6.0
  style.content_margin_bottom = 6.0
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
 theme_label = _label("GREEN HILL", 31, Color("ffe373"))
 title_stack.add_child(theme_label)
 development_subtitle = _label("A U T H O R E D   A C T", 12, Color("ffffff"))
 title_stack.add_child(development_subtitle)
 var score_panel := PanelContainer.new()
 score_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 score_panel.position = Vector2(-324, 24)
 score_panel.size = Vector2(300, 98)
 score_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.13, 0.16, 0.91)))
 score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 root.add_child(score_panel)
 var scores := VBoxContainer.new()
 score_panel.add_child(scores)
 score_header_lab = _label("RINGS / SCORE", 12, Color("a4e5e3"))
 scores.add_child(score_header_lab)
 score_label_lab = _label("00 / 000000", 25, Color("ffe373"))
 scores.add_child(score_label_lab)
 score_feedback_lab = _label("", 13, Color("a4e5e3"))
 score_feedback_lab.custom_minimum_size.x = 270
 score_feedback_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 scores.add_child(score_feedback_lab)
 var footer := PanelContainer.new()
 development_footer = footer
 footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 footer.offset_left = 24
 footer.offset_right = -24
 footer.offset_top = -196
 footer.offset_bottom = -14
 footer.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.13, 0.16, 0.94)))
 root.add_child(footer)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 8)
 footer.add_child(stack)
 var top_row := HBoxContainer.new()
 top_row.add_theme_constant_override("separation", 10)
 stack.add_child(top_row)
 pose_label = _label("ROLL / READY TO ROLL IN", 14, Color("ffe373"))
 pose_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 top_row.add_child(pose_label)
 status_label = _label("", 12, Color("a4e5e3"))
 top_row.add_child(status_label)
 var source_row := HBoxContainer.new()
 source_row.add_theme_constant_override("separation", 8)
 stack.add_child(source_row)
 load_act_button = _button("Load Act…", _open_act_picker)
 source_row.add_child(load_act_button)
 reload_act_button = _button("Reload Act", reload_authored_act)
 reload_act_button.tooltip_text = "F5: reload the current saved Act from disk and return to serve. Keeps development presentation settings."
 source_row.add_child(reload_act_button)
 source_row.add_child(_label("THEME", 12, Color("a4e5e3")))
 theme_selector = OptionButton.new()
 theme_selector.name = "ThemeSelector"
 theme_selector.focus_mode = Control.FOCUS_NONE
 theme_selector.custom_minimum_size.x = 165
 theme_selector.tooltip_text = "Reskin the same live level; geometry, physics and score stay unchanged."
 for index in ThemeRegistry.IDS.size():
  theme_selector.add_item(ThemeRegistry.NAMES[index])
  theme_selector.set_item_metadata(index, ThemeRegistry.IDS[index])
 theme_selector.item_selected.connect(_select_theme)
 source_row.add_child(theme_selector)
 source_note = _label("", 12, Color("a4e5e3"))
 source_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 source_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 source_row.add_child(source_note)
 fullscreen_button = _button("F11  Play View", toggle_fullscreen)
 fullscreen_button.tooltip_text = "Fullscreen Player View; F11 restores the development window and tools."
 source_row.add_child(fullscreen_button)
 play_buttons = HBoxContainer.new()
 play_buttons.add_theme_constant_override("separation", 8)
 stack.add_child(play_buttons)
 play_buttons.add_child(_button("Enter  Roll in", launch_ball))
 play_buttons.add_child(_button("F1  Physics tuning", toggle_debug))
 overview_button = _button("O  Overview", _toggle_overview)
 overview_button.tooltip_text = "Overview: scroll to zoom; hold the middle mouse button and drag to pan. Reload Act keeps the view; switching to follow and back resets it."
 play_buttons.add_child(overview_button)
 study_buttons = HBoxContainer.new()
 study_buttons.add_theme_constant_override("separation", 8)
 study_buttons.visible = false
 stack.add_child(study_buttons)
 var buttons := study_buttons
 var labels := ["1  Rolling", "2  Idle", "3  Jump", "4  Trick", "5  Special", "6  Impact"]
 var poses := ["roll", "idle", "jump", "trick", "special", "impact"]
 for i in poses.size():
  var value: String = poses[i]
  var button := _button(labels[i], func(): _select_pose(value))
  pose_buttons[value] = button
  buttons.add_child(button)
 var space := Control.new()
 space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 buttons.add_child(space)
 view_button = _button("C  Character close-up", func(): _set_close_view(not close_view))
 top_row.add_child(view_button)
 stack.add_child(_label("Q / E  Flippers    SPACE  Special    ← / →  Steer    ESC  Pause    R  Reset    O  Overview    F1  Tuning    F4  Retro filter    •    Pause or wait at serve to replay", 13, Color("cce5e0")))
 player_hint = _label("", 16, Color("ffe373"))
 root.add_child(player_hint)
 player_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 player_hint.offset_top = -40
 player_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 player_hint.hide()
 act_picker = FileDialog.new()
 act_picker.title = "Load an authored Act"
 act_picker.access = FileDialog.ACCESS_FILESYSTEM
 act_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
 act_picker.filters = PackedStringArray(["*.tres ; Authored Act Resource"])
 act_picker.current_dir = ProjectSettings.globalize_path("res://data/acts")
 act_picker.file_selected.connect(_load_selected_act)
 act_picker.canceled.connect(_finish_source_switch)
 add_child(act_picker)

func is_source_picker_open() -> bool:
 return _source_switch_pending or (is_instance_valid(act_picker) and act_picker.visible)

func _begin_source_switch() -> void:
 _source_previous_pause = get_tree().paused
 _source_switch_pending = true
 get_tree().paused = true
 controls.input_blocked = true

func _finish_source_switch() -> void:
 _source_switch_pending = false
 get_tree().paused = _source_previous_pause
 controls.input_blocked = false
 get_viewport().gui_release_focus()

func _open_act_picker() -> void:
 if loading_act or close_view or is_source_picker_open():
  return
 _begin_source_switch()
 if not authored_act_path.is_empty():
  act_picker.current_dir = ProjectSettings.globalize_path(authored_act_path).get_base_dir()
 act_picker.popup_centered(Vector2i(900, 620))

func _load_selected_act(path: String) -> void:
 if request_authored_act(path):
  while loading_act:
   await get_tree().process_frame
 _finish_source_switch()

func reload_authored_act() -> void:
 if authored_act_path.is_empty() or loading_act or close_view or is_source_picker_open(): return
 if debug_panel.act_controls.chao_lab.visible: return
 # The shared source loader validates and compiles before replacing the live Act.
 # Pause even during live play, then restore the caller's pause and view state.
 _begin_source_switch()
 if request_authored_act(authored_act_path):
  while loading_act:
   await get_tree().process_frame
 _finish_source_switch()

func _select_pose(value: String) -> void:
 if not close_view:
  return
 character.capture_hold = false
 character.select_preview(("fly" if character_id == "tails" else "homing") if value == "special" else value)
 get_viewport().gui_release_focus()

func _set_close_view(enabled: bool) -> void:
 if enabled == close_view:
  return
 if enabled and debug_open:
  toggle_debug()
 close_view = enabled
 if enabled:
  _pause_before_close = get_tree().paused
  get_tree().paused = true
 else:
  get_tree().paused = _pause_before_close
  character.resume_gameplay()
 character.set_close_view(enabled)
 if is_instance_valid(play_buttons):
  play_buttons.visible = not enabled
  study_buttons.visible = enabled
 if is_instance_valid(view_button):
  view_button.text = "C  Back to playfield" if enabled else "C  Character close-up"
 get_viewport().gui_release_focus()

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
  if event.physical_keycode == KEY_F11 or event.keycode == KEY_F11:
   toggle_fullscreen()
   get_viewport().set_input_as_handled()
  elif (event.physical_keycode == KEY_F5 or event.keycode == KEY_F5) and is_instance_valid(ball):
   reload_authored_act()
   get_viewport().set_input_as_handled()
  elif player_view and event.physical_keycode in [KEY_F1, KEY_F4, KEY_C, KEY_O, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]:
   get_viewport().set_input_as_handled()

func toggle_fullscreen() -> void:
 # Modal source/Chao editors own pause and focus until dismissed.
 if is_source_picker_open() or debug_panel.act_controls.chao_lab.visible:
  return
 var window := get_window()
 var challenge: Control = debug_panel.act_controls
 if not player_view:
  _windowed_mode = DisplayServer.window_get_mode()
  _windowed_size = DisplayServer.window_get_size()
  _windowed_position = DisplayServer.window_get_position()
  _development_state = {
   "aspect": window.content_scale_aspect,
   "offsets": Vector4(view_container.offset_left, view_container.offset_top, view_container.offset_right, view_container.offset_bottom),
   "follow": presentation.camera_follow_enabled, "close": close_view,
   "character_position": challenge.character_panel.position,
  }
  if close_view:
   _set_close_view(false)
  _development_visibility.clear()
  for item: Node in [debug_panel, development_footer, development_subtitle, retro_controls, challenge.get_child(0), challenge.character_panel.combo_hud.toggle]:
   _development_visibility[item] = item.visible
   item.visible = false
  _development_visibility[lab_ui] = lab_ui.visible
  lab_ui.visible = true
  _overlay_visibility.clear()
  for overlay: Node3D in _development_overlays():
   _overlay_visibility.append(overlay.visible)
   overlay.hide()
  retro_controls.set_process_unhandled_key_input(false)
  player_view = true
  player_hint.show()
  window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
  view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  if not presentation.camera_follow_enabled:
   presentation.set_camera_follow(true)
  if DisplayServer.get_name() != "headless":
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
  _position_player_hud()
 else:
  player_view = false
  player_hint.hide()
  window.content_scale_aspect = _development_state.aspect
  if DisplayServer.get_name() != "headless":
   DisplayServer.window_set_mode(_windowed_mode)
   if _windowed_mode == DisplayServer.WINDOW_MODE_WINDOWED:
    DisplayServer.window_set_size(_windowed_size)
    DisplayServer.window_set_position(_windowed_position)
  var offsets: Vector4 = _development_state.offsets
  view_container.offset_left = offsets.x
  view_container.offset_top = offsets.y
  view_container.offset_right = offsets.z
  view_container.offset_bottom = offsets.w
  for item: Node in _development_visibility:
   if is_instance_valid(item):
    item.visible = _development_visibility[item]
  var overlays := _development_overlays()
  for index in overlays.size():
   overlays[index].visible = _overlay_visibility[index]
  retro_controls.set_process_unhandled_key_input(true)
  challenge.character_panel.position = _development_state.character_position
  presentation.set_camera_follow(_development_state.follow)
  if _development_state.close:
   _set_close_view(true)
 get_viewport().gui_release_focus()

func _development_overlays() -> Array[Node3D]:
 return [presentation.physics_overlay, presentation.construction_grid_overlay]

func _position_player_hud() -> void:
 if not player_view:
  return
 var available := get_viewport().get_visible_rect().size
 var challenge: Control = debug_panel.act_controls
 challenge.character_panel.position = Vector2(available.x - 275, 140)

func _unhandled_key_input(event: InputEvent) -> void:
 if player_view or is_source_picker_open() or not event is InputEventKey or not event.pressed or event.echo:
  return
 match event.physical_keycode:
  KEY_1: _select_pose("roll")
  KEY_2: _select_pose("idle")
  KEY_3: _select_pose("jump")
  KEY_4: _select_pose("trick")
  KEY_5: _select_pose("special")
  KEY_6:
   if character_id == "sonic":
    _select_pose("impact")
  KEY_C: _set_close_view(not close_view)
  KEY_O: _toggle_overview()

func _toggle_overview() -> void:
 if player_view or close_view:
  return
 presentation.set_camera_follow(not presentation.camera_follow_enabled)
 debug_panel.camera_follow.set_pressed_no_signal(presentation.camera_follow_enabled)
 get_viewport().gui_release_focus()

func toggle_debug() -> void:
 if player_view or is_source_picker_open():
  return
 if close_view:
  _set_close_view(false)
 debug_open = not debug_open
 debug_panel.visible = debug_open
 debug_panel.panel.visible = true
 debug_panel.act_panel.visible = true
 lab_ui.visible = not debug_open
 view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 if debug_open:
  view_container.offset_left = 225
  view_container.offset_top = 85
  view_container.offset_right = -410
  view_container.offset_bottom = -65
 else:
  view_container.offset_bottom = -210
 _position_act_ui()
 get_viewport().gui_release_focus()

func can_reload_act() -> bool:
 return not close_view and super.can_reload_act()

func reset_ball(relaunch: bool = false) -> void:
 super.reset_ball(relaunch)
 if is_instance_valid(character):
  character.resume_gameplay()

func toggle_pause() -> void:
 if is_source_picker_open():
  return
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
 if player_view:
  player_hint.text = "PAUSED · Esc / Menu to resume" if get_tree().paused else ("Enter / X to launch · Q / E flippers · ← / → steer · Space / A special" if ball.serve_pending else "")
  if not last_source_error.is_empty(): player_hint.text = "Act reload failed: " + last_source_error
 var context := "CHARACTER STUDY" if close_view else ("PAUSED" if get_tree().paused else ("READY TO ROLL IN" if ball.serve_pending else "LIVE PLAY"))
 pose_label.text = "%s / %s" % [character.pose.to_upper(), context]
 score_label_lab.text = "%s\n%d TOTAL · %d RINGS" % [act_score_text(), score, rings_collected]
 score_header_lab.text = "ACT SCORE / TARGET"
 score_label_lab.add_theme_font_size_override("font_size", 18)
 score_feedback_lab.text = scoring_feedback_text()
 status_label.text = "Authored Act · %s" % authored_document.title
 status_label.tooltip_text = character.model_status
 if character.BALL_FORM_ONLY:
  status_label.text += " · Ball form"
 elif not character.model_available:
  status_label.text += " · Spin-ball fallback"
 load_act_button.disabled = loading_act or close_view or is_source_picker_open()
 reload_act_button.disabled = load_act_button.disabled or authored_act_path.is_empty() or debug_panel.act_controls.chao_lab.visible
 theme_selector.disabled = loading_act or close_view or is_source_picker_open()
 source_note.text = last_source_error if not last_source_error.is_empty() else authored_act_path.get_file()
 source_note.tooltip_text = last_source_error if not last_source_error.is_empty() else authored_act_path
 if last_source_error.is_empty() and not presentation.decor_warnings.is_empty():
  source_note.text += " · %d decor warning(s)" % presentation.decor_warnings.size()
  source_note.tooltip_text += "\n" + "\n".join(presentation.decor_warnings)
 overview_button.text = "O  Overview" if presentation.camera_follow_enabled else "O  Follow character"
 if respawn_time >= 0.0:
  pose_label.text = "DRAIN / RETURNING TO SERVE"
 elif not close_view:
  pose_label.text += " · TRY %d" % ball_number
 pose_buttons["impact"].visible = character_id == "sonic"
 pose_buttons["special"].text = "5  Flight" if character_id == "tails" else "5  Homing"
 for value: String in pose_buttons:
  var displayed: String = ("fly" if character_id == "tails" else "homing") if value == "special" else value
  pose_buttons[value].modulate = Color("ffe373") if character.pose == displayed else Color.WHITE
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
