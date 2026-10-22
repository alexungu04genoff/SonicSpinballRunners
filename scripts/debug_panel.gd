class_name PlaygroundDebugPanel
extends CanvasLayer

var game: Node
var tuning: PhysicsTuning
var panel: PanelContainer
var generation_panel: PanelContainer
var seed_field: SpinBox
var difficulty_selector: OptionButton
var generation_summary: Label
var generation_hint: Label
var generation_buttons: Array[Button] = []
var telemetry: Label
var steering_telemetry: Label
var steering_presets: OptionButton
var camera_presets: OptionButton
var score_label: Label
var message_label: Label
var pause_label: Label
var values: RichTextLabel
var spinboxes: Dictionary = {}
var _refreshing: bool = false
var _telemetry_elapsed: float = 0.0

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
 title.text = "SPINBALL RUNNERS  /  PHYSICS PLAYGROUND"
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
 help.text = "Q / E  FLIPPERS     ← / →  STEER     ENTER  LAUNCH     R  RESET\nLB / RB  FLIPPERS     LEFT STICK  STEER     X  LAUNCH     MENU  PAUSE"
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
 var profiles := OptionButton.new()
 profiles.add_item("Balanced")
 profiles.add_item("Floaty — longer flight")
 profiles.item_selected.connect(func(index: int):
  tuning.select_profile(index)
  refresh_fields()
  game.status_message = "Profile changed. Reset for a comparable launch."
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
   game.status_message = "Steering preset applied. Reset for a comparable launch."
  steering_presets.release_focus()
 )
 stack.add_child(steering_presets)
 var modifier := CheckButton.new()
 modifier.text = "Chao: +25% normal accel / +15% flip"
 modifier.add_theme_font_size_override("font_size", 13)
 modifier.toggled.connect(func(enabled: bool):
  tuning.modifier_enabled = enabled
  tuning.rebuild()
  modifier.release_focus()
 )
 stack.add_child(modifier)
 var buttons := HBoxContainer.new()
 stack.add_child(buttons)
 _button(buttons, "Launch", func(): game.launch_ball())
 _button(buttons, "Reset + launch", func(): game.reset_ball(true))
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
 var boundaries := CheckButton.new()
 boundaries.text = "Chunks"
 boundaries.toggled.connect(func(on: bool):
  game.presentation.chunk_overlay.visible = on
  boundaries.release_focus()
 )
 overlays.add_child(boundaries)
 var connectors := CheckButton.new()
 connectors.text = "Connectors"
 connectors.add_theme_font_size_override("font_size", 12)
 connectors.toggled.connect(func(on: bool):
  game.presentation.connector_overlay.visible = on
  connectors.release_focus()
 )
 overlays.add_child(connectors)
 camera_presets = OptionButton.new()
 for camera_name: String in TablePresentation.CAMERA_NAMES:
  camera_presets.add_item("Camera: " + camera_name)
 camera_presets.select(game.presentation.camera_preset)
 camera_presets.tooltip_text = "Stationary views. Top-down is orthographic; Pinball presets use perspective. Physics is unchanged."
 camera_presets.item_selected.connect(func(index: int):
  game.presentation.set_camera_preset(index)
  camera_presets.release_focus()
 )
 stack.add_child(camera_presets)
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
 _label(fields, "Space / A: reserved special; no ability yet.\nRings charge meter. New rack after all collected.\nEnter commits a field and returns game controls.", 12)
 tuning.changed.connect(refresh_effective)
 refresh_effective()
 _build_generation_panel()

func _build_generation_panel() -> void:
 generation_panel = PanelContainer.new()
 generation_panel.position = Vector2(18, 148)
 generation_panel.size.x = 204
 add_child(generation_panel)
 var margin := MarginContainer.new()
 for side: String in ["left", "right", "top", "bottom"]:
  margin.add_theme_constant_override("margin_" + side, 10)
 generation_panel.add_child(margin)
 var stack := VBoxContainer.new()
 stack.custom_minimum_size.x = 184
 stack.add_theme_constant_override("separation", 8)
 margin.add_child(stack)
 _label(stack, "TABLE GENERATOR", 16)
 _label(stack, "Seed (generator v%d)" % TableGenerator.VERSION, 12)
 seed_field = SpinBox.new()
 seed_field.min_value = 0
 seed_field.max_value = 2147483647
 seed_field.step = 1
 seed_field.get_line_edit().text_submitted.connect(func(_text: String): seed_field.get_line_edit().release_focus())
 stack.add_child(seed_field)
 _label(stack, "Preference (apply on build)", 12)
 difficulty_selector = OptionButton.new()
 for difficulty_name: String in TableGenerator.DIFFICULTY_NAMES:
  difficulty_selector.add_item(difficulty_name)
 difficulty_selector.item_selected.connect(func(_index: int): difficulty_selector.release_focus())
 stack.add_child(difficulty_selector)
 generation_buttons.append(_button(stack, "Build seed + preference", func():
  seed_field.apply()
  game.request_generation(int(seed_field.value), difficulty_selector.selected)
 ))
 generation_buttons.append(_button(stack, "Next seed", func(): game.request_generation((game.generation_seed + 1) % 2147483648, difficulty_selector.selected)))
 generation_buttons.append(_button(stack, "Repeat current layout", func(): game.request_generation(game.generation_seed, game.generation_difficulty)))
 generation_summary = _label(stack, "", 12)
 generation_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 generation_summary.custom_minimum_size.x = 184
 generation_hint = _label(stack, "", 12)
 generation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 generation_hint.modulate = Color("ffcf52")
 refresh_generation()

func refresh_generation() -> void:
 seed_field.value = game.generation_seed
 difficulty_selector.select(game.generation_difficulty)
 var upper: ChunkData = game.layout.upper
 var estimate: Dictionary = game.layout.difficulty_estimate
 generation_summary.text = "CURRENT SEED  %d\nUpper: %s\nMirror: %s   Shift: %d cell\nLower: launch_deck (fixed)\nPreference: %s\nEstimate: %s %.1f / 100\n%s\nFallback: %s\nRough geometry estimate" % [game.generation_seed, upper.chunk_id, "yes" if upper.mirrored else "no", upper.horizontal_shift_cells, TableGenerator.DIFFICULTY_NAMES[game.generation_difficulty], TableGenerator.DIFFICULTY_NAMES[estimate.band], estimate.score, "\n".join(estimate.reasons), "yes" if game.layout.used_fallback else "no"]
 if estimate.band != game.generation_difficulty:
  generation_summary.text += "\nPreference differs; best effort."

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
 _refreshing = true
 for key: String in spinboxes:
  spinboxes[key].value = tuning.editable_value(key)
 _refreshing = false

func refresh_effective() -> void:
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
 var focus: Control = get_viewport().gui_get_focus_owner()
 game.controls.input_blocked = focus is LineEdit
 pause_label.visible = get_tree().paused
 _telemetry_elapsed += delta
 if _telemetry_elapsed < 0.10:
  return
 _telemetry_elapsed = 0.0
 var safe: bool = game.can_regenerate()
 for button: Button in generation_buttons:
  button.disabled = not safe
 generation_hint.text = "Ready to build. Resets score, rings and ball; keeps tuning." if safe else "Pause (Escape / Menu) to generate safely."
 var velocity: Vector2 = game.ball.linear_velocity
 score_label.text = "%06d   /   %02d RINGS   /   BALL %02d" % [game.score, game.rings_collected, game.ball_number]
 message_label.text = game.status_message
 telemetry.text = "Position   %7.1f, %7.1f px\nVelocity   %7.1f, %7.1f px/s\nSpeed      %7.1f    Assist %6.1f\nSpecial    %3.0f%%   |   Physics 120 Hz" % [game.ball.position.x, game.ball.position.y, velocity.x, velocity.y, velocity.length(), game.ball.steering_contribution, game.special_meter]
 var paused: bool = get_tree().paused
 var reason: String = "Paused" if paused else game.ball.steering_block_reason
 var activity: String = "active" if absf(game.ball.steering_impulse_applied) > 0.00001 and not paused else "no impulse"
 steering_telemetry.text = "STEERING  |  %s / %s\nRaw %+.2f   Command %+.2f   vx %+.1f\nApplied a: %+.1f px/s²\nImpulse X: %+.3f kg·px/s per tick\nContribution: %+.1f / target %+.1f px/s\nTarget reached: %s\nCondition: %s\nLast reset: %s (%.2f s ago)" % [game.ball.steering_mode, activity, game.controls.raw_steering, game.controls.steering, velocity.x, 0.0 if paused else game.ball.steering_acceleration_applied, 0.0 if paused else game.ball.steering_impulse_applied, game.ball.steering_contribution, game.ball.steering_target, "yes" if game.ball.steering_at_limit else "no", "none" if reason.is_empty() else reason, game.ball.steering_last_reset, game.ball.steering_reset_age]
