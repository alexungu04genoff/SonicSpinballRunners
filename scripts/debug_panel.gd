class_name PlaygroundDebugPanel
extends CanvasLayer

const ActControls = preload("res://scripts/authored_act/act_controls.gd")

var game: Node
var tuning: PhysicsTuning
var panel: PanelContainer
var act_panel: PanelContainer
var act_summary: Label
var act_hint: Label
var traversal_telemetry: Label
var telemetry: Label
var steering_telemetry: Label
var steering_presets: OptionButton
var camera_presets: OptionButton
var camera_follow: CheckButton
var camera_fields: Dictionary = {}
var score_label: Label
var message_label: Label
var pause_label: Label
var act_controls: Control
var practice_toggle: CheckButton
var values: RichTextLabel
var spinboxes: Dictionary = {}
var _refreshing: bool = false
var _telemetry_elapsed: float = 0.0
var profiles: OptionButton

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 var hud := MarginContainer.new()
 hud.position = Vector2(25, 18)
 hud.size = Vector2(790, 100)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(hud)
 var hud_stack := VBoxContainer.new()
 hud.add_child(hud_stack)
 var title := Label.new()
 title.text = "SPINBALL RUNNERS  /  AUTHORED ACT"
 title.add_theme_font_size_override("font_size", 16)
 title.modulate = Color("73b5cb")
 hud_stack.add_child(title)
 score_label = Label.new()
 score_label.add_theme_font_size_override("font_size", 25)
 hud_stack.add_child(score_label)
 message_label = Label.new()
 message_label.modulate = Color("ffcf52")
 hud_stack.add_child(message_label)
 var help := Label.new()
 help.position = Vector2(25, 843)
 help.text = "Q / E  FLIPPERS     ← / →  STEER     ENTER  ROLL IN     R  RESET\nLB / RB  FLIPPERS     LEFT STICK  STEER     X  ROLL IN     MENU  PAUSE"
 help.add_theme_font_size_override("font_size", 13)
 help.modulate = Color("9bb7c9")
 help.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(help)
 pause_label = Label.new()
 pause_label.position = Vector2(600, 48)
 pause_label.text = "PAUSED\nEscape / Menu to resume"
 pause_label.add_theme_font_size_override("font_size", 14)
 pause_label.visible = false
 add_child(pause_label)
 panel = PanelContainer.new()
 panel.position = Vector2(880, 12)
 panel.size = Vector2(388, 876)
 add_child(panel)
 var padding := MarginContainer.new()
 for side: String in ["left", "right", "top", "bottom"]:
  padding.add_theme_constant_override("margin_" + side, 12)
 panel.add_child(padding)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 7)
 padding.add_child(stack)
 _label(stack, "LIVE PHYSICS LAB", 22)
 _label(stack, "F1 hides panel  •  Changes affect this session", 12)
 profiles = OptionButton.new()
 profiles.add_item("Balanced")
 profiles.add_item("Floaty — longer flight")
 profiles.add_item("Tails — controlled")
 profiles.add_item("Knuckles — heavy impact")
 profiles.add_item("Shadow — positioning")
 profiles.item_selected.connect(func(index: int):
  tuning.select_profile(index)
  refresh_fields()
  game.status_message = "Profile changed. Reset for a comparable start."
  profiles.release_focus()
 )
 stack.add_child(profiles)
 steering_presets = OptionButton.new()
 steering_presets.add_item("Steering: custom values")
 steering_presets.set_item_disabled(0, true)
 for preset: Dictionary in PhysicsTuning.STEERING_PRESETS:
  steering_presets.add_item("Steering: " + preset.name)
 steering_presets.item_selected.connect(func(index: int):
  if index > 0:
   tuning.apply_steering_preset(index - 1)
   refresh_fields()
   game.status_message = "Steering preset applied. Reset for a comparable start."
  steering_presets.release_focus()
 )
 stack.add_child(steering_presets)
 var modifier := CheckButton.new()
 practice_toggle = modifier
 modifier.text = "Practice Chao (replaces equipped Chao)"
 modifier.tooltip_text = "Legacy test: +25% steering acceleration / +15% flip. Starts a fresh run; never stacks with Chao Lab."
 modifier.add_theme_font_size_override("font_size", 13)
 modifier.toggled.connect(func(enabled: bool):
  game.request_replay({"chao": "practice" if enabled else "none"})
  modifier.set_pressed_no_signal(tuning.modifier_enabled)
  modifier.release_focus()
 )
 stack.add_child(modifier)
 var buttons := HBoxContainer.new()
 stack.add_child(buttons)
 _button(buttons, "Roll in", func(): game.launch_ball())
 _button(buttons, "Reset + roll in", func(): game.reset_ball(true))
 _button(buttons, "Pause", func(): game.toggle_pause())
 var reset := Button.new()
 reset.text = "Restore profile defaults"
 reset.pressed.connect(func():
  tuning.overrides.clear()
  tuning.rebuild()
  refresh_fields()
  reset.release_focus()
 )
 stack.add_child(reset)
 var overlays := HBoxContainer.new()
 stack.add_child(overlays)
 var geometry := CheckButton.new()
 geometry.text = "Physics"
 geometry.toggled.connect(func(on: bool):
  game.presentation.physics_overlay.visible = on
  geometry.release_focus()
 )
 overlays.add_child(geometry)
 geometry.tooltip_text = "X-ray outlines of the actual 2D collider footprints on the board surface."
 camera_presets = OptionButton.new()
 for camera_name: String in TablePresentation.CAMERA_NAMES:
  camera_presets.add_item("Camera: " + camera_name)
 camera_presets.select(game.presentation.camera_preset)
 camera_presets.tooltip_text = "Top-down is orthographic; Pinball presets use perspective. Follow mode changes only camera position."
 camera_presets.item_selected.connect(func(index: int):
  game.presentation.set_camera_preset(index)
  camera_presets.release_focus()
 )
 stack.add_child(camera_presets)
 camera_follow = CheckButton.new()
 camera_follow.text = "Follow ball (off: overview)"
 camera_follow.tooltip_text = "Overview: scroll to zoom; hold the middle mouse button and drag to pan. Returning from follow resets the overview."
 camera_follow.button_pressed = game.presentation.camera_follow_enabled
 camera_follow.toggled.connect(func(enabled: bool):
  game.presentation.set_camera_follow(enabled)
  camera_follow.release_focus()
 )
 stack.add_child(camera_follow)
 telemetry = Label.new()
 telemetry.add_theme_font_size_override("font_size", 13)
 stack.add_child(telemetry)
 steering_telemetry = Label.new()
 steering_telemetry.add_theme_font_size_override("font_size", 12)
 steering_telemetry.custom_minimum_size.x = 350
 steering_telemetry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 stack.add_child(steering_telemetry)
 var scroll := ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 stack.add_child(scroll)
 var fields := VBoxContainer.new()
 fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 fields.add_theme_constant_override("separation", 5)
 scroll.add_child(fields)
 var camera_controls := VBoxContainer.new()
 var camera_fold := CheckButton.new()
 camera_fold.text = "Camera follow tuning"
 camera_fold.toggled.connect(func(enabled: bool):
  camera_controls.visible = enabled
  camera_fold.release_focus()
 )
 fields.add_child(camera_fold)
 fields.add_child(camera_controls)
 camera_controls.visible = false
 var camera_specs := {
  "zoom": [0.6, 2.5, 0.1, "Follow zoom [multiplier]"],
  "dead_zone_y": [0.0, 250.0, 5.0, "Vertical dead zone [px]"],
  "dead_zone_x": [0.0, 100.0, 1.0, "Horizontal dead zone [px]"],
  "look_ahead": [0.0, 250.0, 5.0, "Upward look-ahead [px]"],
  "screen_target_y": [0.3, 0.6, 0.01, "Ball vertical screen target [fraction]"],
  "screen_margin_y": [0.1, 0.3, 0.01, "Vertical visibility margin [fraction]"],
  "vertical_response": [0.5, 60.0, 0.5, "Vertical response [1/s]"],
  "horizontal_response": [0.25, 6.0, 0.25, "Horizontal response [1/s]"],
  "max_speed": [400.0, 8000.0, 100.0, "Soft camera speed limit [px/s]"],
 }
 for key: String in camera_specs:
  var spec: Array = camera_specs[key]
  _label(camera_controls, spec[3], 12)
  var spin := SpinBox.new()
  spin.min_value = spec[0]
  spin.max_value = spec[1]
  spin.step = spec[2]
  spin.value = game.presentation.camera_settings[key]
  spin.value_changed.connect(func(value: float): game.presentation.set_camera_value(key, value))
  spin.get_line_edit().text_submitted.connect(func(_text: String): spin.get_line_edit().release_focus())
  camera_controls.add_child(spin)
  camera_fields[key] = spin
 _label(fields, "Base values + session edits (before Chao)", 13)
 for key: String in PhysicsProfile.FIELDS:
  var spec: Array = PhysicsProfile.FIELDS[key]
  _label(fields, "%s  [%s]" % [spec[3], spec[4]], 12)
  var spin := SpinBox.new()
  spin.min_value = spec[0]
  spin.max_value = spec[1]
  spin.step = spec[2]
  spin.allow_greater = false
  spin.allow_lesser = false
  spin.value = tuning.editable_value(key)
  spin.value_changed.connect(func(value: float):
   if not _refreshing:
    tuning.set_value(key, value)
  )
  spin.get_line_edit().text_submitted.connect(func(_text: String): spin.get_line_edit().release_focus())
  fields.add_child(spin)
  spinboxes[key] = spin
 _label(fields, "ACTIVE VALUES (after modifiers and limits)", 13)
 values = RichTextLabel.new()
 values.fit_content = true
 values.scroll_active = false
 values.custom_minimum_size.x = 315
 values.add_theme_font_size_override("normal_font_size", 12)
 fields.add_child(values)
 _label(fields, "Space / A: character special when READY.\nRings and bumpers charge meter.\nEnter commits a field and returns game controls.", 12)
 tuning.changed.connect(refresh_effective)
 game.specials.character_changed.connect(func(_id: String): refresh_fields())
 refresh_effective()
 _build_act_panel()
 act_controls = ActControls.new()
 act_controls.game = game
 add_child(act_controls)

func _build_act_panel() -> void:
 act_panel = PanelContainer.new()
 act_panel.position = Vector2(18, 148)
 act_panel.size = Vector2(204, 680)
 add_child(act_panel)
 var margin := MarginContainer.new()
 for side: String in ["left", "right", "top", "bottom"]:
  margin.add_theme_constant_override("margin_" + side, 10)
 act_panel.add_child(margin)
 var stack := VBoxContainer.new()
 stack.custom_minimum_size.x = 184
 stack.add_theme_constant_override("separation", 8)
 margin.add_child(stack)
 _label(stack, "AUTHORED ACT", 16)
 var grid_toggle := CheckButton.new()
 grid_toggle.text = "Authoring grid"
 grid_toggle.toggled.connect(func(on: bool):
  game.presentation.construction_grid_overlay.visible = on
  grid_toggle.release_focus()
 )
 stack.add_child(grid_toggle)
 traversal_telemetry = _label(stack, "", 12)
 traversal_telemetry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 act_summary = _label(stack, "", 12)
 act_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 act_summary.custom_minimum_size.x = 184
 act_hint = _label(stack, "Reload this saved Act using Replay Act or F5 in the themed player.", 12)
 act_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 refresh_act()

func refresh_act() -> void:
 var document: Resource = game.authored_document
 act_summary.text = "%s\n\nGrid: %d × %d\nCell: %.1f px\nTerrain: %d\nObjects: %d\nRing trails: %d\n\n%s" % [document.title, document.grid_size.x, document.grid_size.y, document.cell_size, document.placements.size(), document.gameplay_objects.size(), document.ring_trails.size(), game.authored_act_path]

func _label(parent: Node, text: String, font_size: int) -> Label:
 var label := Label.new()
 label.text = text
 label.add_theme_font_size_override("font_size", font_size)
 parent.add_child(label)
 return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
 var button := Button.new()
 button.text = text
 button.add_theme_font_size_override("font_size", 13)
 button.pressed.connect(func():
  callback.call()
  button.release_focus()
 )
 parent.add_child(button)
 return button

func refresh_fields() -> void:
 profiles.select(PhysicsTuning.PROFILES.find(tuning.base))
 _refreshing = true
 for key: String in spinboxes:
  spinboxes[key].value = tuning.editable_value(key)
 _refreshing = false

func refresh_effective() -> void:
 profiles.select(PhysicsTuning.PROFILES.find(tuning.base))
 practice_toggle.set_pressed_no_signal(tuning.modifier_enabled)
 if not is_instance_valid(values):
  return
 var text: String = ""
 for key: String in tuning.effective:
  text += "%s: %.3f\n" % [key, tuning.effective[key]]
 values.text = text
 steering_presets.select(0)
 for i in PhysicsTuning.STEERING_PRESETS.size():
  var matches: bool = true
  for key: String in PhysicsTuning.STEERING_PRESETS[i].values:
   if not is_equal_approx(tuning.editable_value(key), PhysicsTuning.STEERING_PRESETS[i].values[key]):
    matches = false
  if matches:
   steering_presets.select(i + 1)
   break

func _process(delta: float) -> void:
 practice_toggle.disabled = not game.can_reload_act()
 var focus: Control = get_viewport().gui_get_focus_owner()
 var source_modal: bool = game.has_method("is_source_picker_open") and game.is_source_picker_open()
 game.controls.input_blocked = focus is LineEdit or source_modal
 pause_label.visible = get_tree().paused
 _telemetry_elapsed += delta
 if _telemetry_elapsed < 0.10:
  return
 _telemetry_elapsed = 0.0
 traversal_telemetry.text = "Camera: %s\nTarget: %.0f, %.0f px\nActivation crossings: %d\nExit crossings: %d" % ["Follow" if game.presentation.camera_follow_enabled else "Overview", game.presentation.camera_target.x, game.presentation.camera_target.y, game.authored_activation_count, game.authored_exit_count]
 traversal_telemetry.text += "\n\n" + game.scoring_breakdown_text()
 var velocity: Vector2 = game.ball.linear_velocity
 score_label.text = "ACT %s   /   TOTAL %d   /   %02d RINGS" % [game.act_score_text(), game.score, game.rings_collected]
 message_label.text = game.status_message
 telemetry.text = "Position   %7.1f, %7.1f px\nVelocity   %7.1f, %7.1f px/s\nSpeed      %7.1f    Assist %6.1f\nSpecial    %3.0f%%   |   Physics 120 Hz" % [game.ball.position.x, game.ball.position.y, velocity.x, velocity.y, velocity.length(), game.ball.steering_contribution, game.special_meter]
 var paused: bool = get_tree().paused
 var reason: String = "Paused" if paused else game.ball.steering_block_reason
 var activity: String = "active" if absf(game.ball.steering_impulse_applied) > 0.00001 and not paused else "no impulse"
 steering_telemetry.text = "STEERING  |  %s / %s\nRaw %+.2f   Command %+.2f   vx %+.1f\nApplied a: %+.1f px/s²\nImpulse X: %+.3f kg·px/s per tick\nContribution: %+.1f / target %+.1f px/s\nTarget reached: %s\nCondition: %s\nLast reset: %s (%.2f s ago)" % [game.ball.steering_mode, activity, game.controls.raw_steering, game.controls.steering, velocity.x, 0.0 if paused else game.ball.steering_acceleration_applied, 0.0 if paused else game.ball.steering_impulse_applied, game.ball.steering_contribution, game.ball.steering_target, "yes" if game.ball.steering_at_limit else "no", "none" if reason.is_empty() else reason, game.ball.steering_last_reset, game.ball.steering_reset_age]
