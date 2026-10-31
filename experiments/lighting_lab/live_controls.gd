extends CanvasLayer
## Lab-only values. No production settings, source resources, or bake files are saved.
const EmissionPreview := preload("res://experiments/lighting_lab/emission_preview.gd")
const LightingLooks := preload("res://experiments/lighting_lab/lighting_looks.gd")
# Label, property, kind; numeric rows also carry minimum, maximum and step.
const GROUPS := {
 "Light": [
  ["Exposure", "env/tonemap_exposure", "number", 0.05, 4.0, 0.01],
  ["Tonemapper", "env/tonemap_mode", "tone"],
  ["Ambient energy", "env/ambient_light_energy", "number", 0.0, 3.0, 0.01],
  ["Ambient color", "env/ambient_light_color", "color"],
  ["Sky contribution", "env/ambient_light_sky_contribution", "number", 0.0, 1.0, 0.01],
  ["Sun energy", "sun/light_energy", "number", 0.0, 4.0, 0.01],
  ["Sun color", "sun/light_color", "color"],
  ["Sun elevation", "sun_pitch", "number", -90.0, 0.0, 0.5],
  ["Sun azimuth", "sun_yaw", "number", -180.0, 180.0, 0.5],
  ["Sun specular", "sun/light_specular", "number", 0.0, 2.0, 0.01],
  ["Color adjustment", "env/adjustment_enabled", "bool"],
  ["Contrast", "env/adjustment_contrast", "number", 0.5, 1.5, 0.01],
  ["Saturation", "env/adjustment_saturation", "number", 0.0, 2.0, 0.01],
 ],
 "Glow & Fog": [
  ["Glow enabled", "env/glow_enabled", "bool"],
  ["Glow intensity", "env/glow_intensity", "number", 0.0, 2.0, 0.01],
  ["Bloom", "env/glow_bloom", "number", 0.0, 1.0, 0.005],
  ["Glow threshold", "env/glow_hdr_threshold", "number", 0.0, 4.0, 0.01],
  ["Emission multiplier", "emission", "number", 0.0, 3.0, 0.01],
  ["Sky / clear brightness", "env/background_energy_multiplier", "number", 0.0, 3.0, 0.01],
  ["Fog enabled", "env/fog_enabled", "bool"],
  ["Fog density", "env/fog_density", "number", 0.0, 0.1, 0.0005],
  ["Fog color", "env/fog_light_color", "color"],
  ["Fog brightness", "env/fog_light_energy", "number", 0.0, 3.0, 0.01],
  ["Fog sky influence", "env/fog_sky_affect", "number", 0.0, 1.0, 0.01],
 ],
 "Shadows": [
  ["Shadows enabled", "sun/shadow_enabled", "bool"],
  ["Opacity", "sun/shadow_opacity", "number", 0.0, 1.0, 0.01],
  ["Softness (Forward+)", "sun/light_angular_distance", "number", 0.0, 5.0, 0.05],
  ["Depth bias", "sun/shadow_bias", "number", 0.0, 2.0, 0.01],
  ["Normal bias", "sun/shadow_normal_bias", "number", 0.0, 8.0, 0.05],
  ["Shadow distance", "sun/directional_shadow_max_distance", "number", 10.0, 500.0, 1.0],
  ["Shadow maps", "sun/directional_shadow_mode", "shadow"],
 ],
}
var settings_path := "user://lighting_lab_presets.cfg"
var game: Node
var panel: PanelContainer
var caption: Label
var message: Label
var compare: CheckButton
var reopen: Button
var pause_button: Button
var retro: CheckButton
var vsync: CheckButton
var performance_label: Label
var look_selector: OptionButton
var _performance_elapsed := 0.0
var _performance_frames := 0
var widgets := {}
var drafts := {}
var originals := {}
var values := {}
var preset_key := ""
var renderer := ""
var emission := EmissionPreview.new()
var saved := ConfigFile.new()

func install(owner_game: Node) -> void:
 game = owner_game
 layer = 140
 process_mode = Node.PROCESS_MODE_ALWAYS
 renderer = RenderingServer.get_current_rendering_method()
 var error := saved.load(settings_path)
 if error not in [OK, ERR_FILE_NOT_FOUND]: push_warning("Cannot load lighting lab presets: " + error_string(error))
 _build_ui()
 bind_theme()
 game.retro_filter.preset_changed.connect(func(_index: int): retro.set_pressed_no_signal(not game.retro_filter.selected_effects.is_empty()))

func _build_ui() -> void:
 var root := Control.new()
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(root)
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel = PanelContainer.new()
 panel.mouse_filter = Control.MOUSE_FILTER_STOP
 panel.mouse_force_pass_scroll_events = false
 root.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
 panel.offset_left = -395
 panel.offset_right = -10
 panel.offset_top = 30
 panel.offset_bottom = -215
 var style := StyleBoxFlat.new()
 style.bg_color = Color("142330")
 style.set_content_margin_all(12)
 style.set_corner_radius_all(8)
 panel.add_theme_stylebox_override("panel", style)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 8)
 panel.add_child(column)
 var heading := HBoxContainer.new()
 column.add_child(heading)
 caption = Label.new()
 caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_child(caption)
 _button(heading, "Hide · F6", toggle_panel)
 var hint := Label.new()
 hint.text = "Wheel: zoom · Middle-drag: pan · O: follow"
 hint.add_theme_font_size_override("font_size", 13)
 column.add_child(hint)
 var row := HBoxContainer.new()
 column.add_child(row)
 pause_button = _button(row, "Pause play", func(): game.toggle_pause())
 _button(row, "Frame Act", func():
  game.presentation.set_camera_follow(true)
  game.presentation.set_camera_follow(false)
 )
 retro = CheckButton.new()
 retro.text = "Retro"
 retro.focus_mode = Control.FOCUS_NONE
 retro.set_pressed_no_signal(not game.retro_filter.selected_effects.is_empty())
 retro.toggled.connect(func(enabled: bool): game.retro_filter.set_effects(game.retro_filter.settings.default_effects if enabled else []))
 row.add_child(retro)
 var performance_row := HBoxContainer.new()
 column.add_child(performance_row)
 vsync = CheckButton.new()
 vsync.text = "VSync"
 vsync.tooltip_text = "Off: uncapped rendering. On: synchronize to your display. Physics stays at 120 Hz."
 vsync.focus_mode = Control.FOCUS_NONE
 vsync.set_pressed_no_signal(DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
 vsync.toggled.connect(_set_vsync)
 performance_row.add_child(vsync)
 performance_label = Label.new()
 performance_label.add_theme_font_size_override("font_size", 13)
 performance_row.add_child(performance_label)
 look_selector = OptionButton.new()
 look_selector.focus_mode = Control.FOCUS_NONE
 look_selector.add_item("Try a lighting look…")
 look_selector.add_item("Authored lighting")
 for look: String in LightingLooks.LOOKS: look_selector.add_item(look)
 look_selector.item_selected.connect(_select_look)
 column.add_child(look_selector)
 compare = CheckButton.new()
 compare.text = "Show original lighting"
 compare.focus_mode = Control.FOCUS_NONE
 compare.toggled.connect(func(_enabled: bool): apply_values())
 column.add_child(compare)
 var tabs := TabContainer.new()
 tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(tabs)
 for group: String in GROUPS:
  var scroll := ScrollContainer.new()
  scroll.name = group
  scroll.mouse_force_pass_scroll_events = false
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  tabs.add_child(scroll)
  var controls := VBoxContainer.new()
  controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  controls.add_theme_constant_override("separation", 8)
  scroll.add_child(controls)
  for spec: Array in GROUPS[group]: _field(controls, spec)
  if group == "Glow & Fog":
   var note := Label.new()
   note.text = "Emission: standard materials + exposed shader scales.\nFixed shader highlights keep their authored values.\nSky brightness does not dim scenery meshes."
   note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   note.add_theme_font_size_override("font_size", 12)
   controls.add_child(note)
 var actions := HBoxContainer.new()
 column.add_child(actions)
 _button(actions, "Save", save_preset)
 _button(actions, "Reload", reload_preset)
 _button(actions, "Reset", reset_values)
 _button(actions, "Open folder", func(): OS.shell_open(ProjectSettings.globalize_path(settings_path).get_base_dir()))
 message = Label.new()
 message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 message.add_theme_font_size_override("font_size", 12)
 column.add_child(message)
 reopen = _button(root, "Lighting · F6", toggle_panel)
 reopen.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 reopen.position = Vector2(-145, 30)
 reopen.hide()

func _button(parent: Node, title: String, callback: Callable) -> Button:
 var button := Button.new()
 button.text = title
 button.focus_mode = Control.FOCUS_NONE
 button.pressed.connect(callback)
 parent.add_child(button)
 return button

func _field(parent: Node, spec: Array) -> void:
 var key: String = spec[1]
 var row := HBoxContainer.new()
 parent.add_child(row)
 var label := Label.new()
 label.text = spec[0]
 label.custom_minimum_size.x = 165
 label.add_theme_font_size_override("font_size", 13)
 row.add_child(label)
 var field: Control
 match spec[2]:
  "number":
   var number := SpinBox.new()
   number.min_value = spec[3]
   number.max_value = spec[4]
   number.step = spec[5]
   number.allow_greater = true
   number.allow_lesser = true
   number.value_changed.connect(func(value: float): set_value(key, value))
   field = number
  "color":
   var color := ColorPickerButton.new()
   color.edit_alpha = false
   color.color_changed.connect(func(value: Color): set_value(key, value))
   field = color
  "bool":
   var toggle := CheckButton.new()
   toggle.toggled.connect(func(value: bool): set_value(key, value))
   field = toggle
  _:
   var options := OptionButton.new()
   var names := ["Linear", "Reinhard", "Filmic", "ACES", "AgX"] if spec[2] == "tone" else ["1 · Orthogonal", "2 · PSSM", "4 · PSSM"]
   for title: String in names: options.add_item(title)
   options.item_selected.connect(func(value: int): set_value(key, value))
   field = options
 field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 field.focus_mode = Control.FOCUS_NONE
 row.add_child(field)
 widgets[key] = field
 if key == "sun/light_angular_distance" and renderer != "forward_plus":
  (field as SpinBox).editable = false
  field.tooltip_text = "Directional soft shadows require Forward+."
 if spec[2] == "number":
  var slider := HSlider.new()
  slider.min_value = spec[3]
  slider.max_value = spec[4]
  slider.step = spec[5]
  slider.focus_mode = Control.FOCUS_NONE
  slider.editable = not (key == "sun/light_angular_distance" and renderer != "forward_plus")
  slider.value_changed.connect(func(value: float): set_value(key, value))
  parent.add_child(slider)
  field.set_meta("slider", slider)

func bind_theme() -> void:
 # Themes configure a subset of Environment fields. Start from a fresh resource
 # so, for example, Chemical's exposure or Rooftop's fog cannot become the next
 # theme's "original" merely because it was inspected first.
 var environment := Environment.new()
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color("a6d1ed")
 environment.ambient_light_energy = 0.45
 game.presentation._world_environment.environment = environment
 var light: DirectionalLight3D = game.presentation._key_light
 light.light_specular = 1.0
 light.shadow_enabled = true
 light.shadow_opacity = 1.0
 light.light_angular_distance = 0.0
 light.shadow_bias = 0.1
 light.shadow_normal_bias = 2.0
 light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
 game.presentation.theme_definition.configure_environment(game.presentation)
 var rooftop = game.get("rooftop_materials")
 if game.theme_id == "rooftop_run" and is_instance_valid(rooftop): rooftop.apply_lighting()
 preset_key = renderer + "/" + game.theme_id
 originals.clear()
 for group: Array in GROUPS.values():
  for spec: Array in group: originals[spec[1]] = _read_value(spec[1])
 emission.collect(game.presentation)
 values = originals.duplicate(true)
 var stored: Dictionary = drafts.get(preset_key, saved.get_value(preset_key, "values", {}))
 for key: String in originals:
  if stored.has(key) and typeof(stored[key]) == typeof(originals[key]): values[key] = stored[key]
 compare.set_pressed_no_signal(false)
 look_selector.select(0)
 _sync_widgets()
 apply_values()
 caption.text = "LIGHTING / " + {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "ANGLE"}.get(renderer, renderer)
 message.text = "Lab preset: " + game.presentation.theme_definition.display_name + "\nSave keeps these values for this renderer only."

func _read_value(key: String) -> Variant:
 if key == "emission": return 1.0
 if key == "sun_pitch": return game.presentation._key_light.rotation_degrees.x
 if key == "sun_yaw": return game.presentation._key_light.rotation_degrees.y
 var target: Object = game.presentation._world_environment.environment if key.begins_with("env/") else game.presentation._key_light
 return target.get(key.get_slice("/", 1))

func set_value(key: String, value: Variant) -> void:
 values[key] = value
 drafts[preset_key] = values.duplicate(true)
 compare.set_pressed_no_signal(false)
 look_selector.select(0)
 _sync_widgets()
 apply_values()
 message.text = "Unsaved lighting · " + game.presentation.theme_definition.display_name

func _sync_widgets() -> void:
 for key: String in widgets:
  var field: Control = widgets[key]
  if field is Range:
   field.set_value_no_signal(float(values[key]))
   if field.has_meta("slider"): field.get_meta("slider").set_value_no_signal(float(values[key]))
  elif field is ColorPickerButton: field.color = values[key]
  elif field is OptionButton: field.select(int(values[key]))
  elif field is CheckButton: field.set_pressed_no_signal(bool(values[key]))

func apply_values() -> void:
 _apply(originals if compare.button_pressed else values)

func _apply(source: Dictionary) -> void:
 for key: String in source:
  if key == "emission": emission.apply(float(source[key]))
  elif key == "sun_pitch": game.presentation._key_light.rotation_degrees.x = float(source[key])
  elif key == "sun_yaw": game.presentation._key_light.rotation_degrees.y = float(source[key])
  else:
   var target: Object = game.presentation._world_environment.environment if key.begins_with("env/") else game.presentation._key_light
   target.set(key.get_slice("/", 1), source[key])

func restore_original() -> void:
 _apply(originals)
 emission.restore()

func save_preset() -> void:
 # Another renderer's lab window may have saved since this one was opened.
 # Merge only this theme/renderer section instead of overwriting its presets.
 var latest := ConfigFile.new()
 var load_error := latest.load(settings_path)
 if load_error not in [OK, ERR_FILE_NOT_FOUND]:
  message.text = "Save stopped: cannot read presets (" + error_string(load_error) + ")"
  return
 saved = latest
 saved.set_value(preset_key, "values", values)
 saved.set_value("format", "version", 1)
 var error := saved.save(settings_path)
 message.text = ("Saved " + game.presentation.theme_definition.display_name + " · " + renderer) if error == OK else ("Save failed: " + error_string(error))
 message.tooltip_text = ProjectSettings.globalize_path(settings_path)

func reload_preset() -> void:
 var fresh := ConfigFile.new()
 var error := fresh.load(settings_path)
 if error not in [OK, ERR_FILE_NOT_FOUND]:
  message.text = "Reload failed: " + error_string(error)
  return
 saved = fresh
 drafts.erase(preset_key)
 restore_original()
 bind_theme()

func reset_values() -> void:
 values = originals.duplicate(true)
 drafts[preset_key] = values.duplicate(true)
 compare.set_pressed_no_signal(false)
 look_selector.select(1)
 _sync_widgets()
 apply_values()
 message.text = "Original values restored. Save to replace the saved preset."

func toggle_panel() -> void:
 panel.visible = not panel.visible
 reopen.visible = not panel.visible

func blocks_camera_at(point: Vector2) -> bool:
 return visible and ((panel.is_visible_in_tree() and panel.get_global_rect().has_point(point)) or (reopen.is_visible_in_tree() and reopen.get_global_rect().has_point(point)))

func _set_vsync(enabled: bool) -> void:
 Engine.max_fps = 0
 if DisplayServer.get_name() != "headless":
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
 vsync.set_pressed_no_signal(DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)

func _select_look(index: int) -> void:
 if index == 0: return
 var title := look_selector.get_item_text(index)
 values = originals.duplicate(true) if index == 1 else LightingLooks.create(title, originals)
 drafts[preset_key] = values.duplicate(true)
 compare.set_pressed_no_signal(false)
 _sync_widgets()
 apply_values()
 message.text = title + " · Unsaved preview. Save to keep."

func _process(delta: float) -> void:
 if not is_instance_valid(game): return
 # Some local visual-lab versions already draw a one-second FPS counter.
 # Avoid showing two different averaging windows while this inspector is open.
 var inherited_fps = game.get("fps_label")
 if is_instance_valid(inherited_fps):
  var show_inherited: bool = not (visible and panel.visible)
  if inherited_fps.visible != show_inherited: inherited_fps.visible = show_inherited
 var pause_text := "Resume play" if get_tree().paused else "Pause play"
 if pause_button.text != pause_text: pause_button.text = pause_text
 # The existing player owns layout/fullscreen. Reserve space only in lab view.
 if not game.debug_open and not game.player_view:
  var target_offset := -405.0 if panel.visible else 0.0
  if not is_equal_approx(game.view_container.offset_right, target_offset):
   game.view_container.offset_right = target_offset
 _performance_elapsed += delta
 _performance_frames += 1
 if _performance_elapsed >= 0.5:
  performance_label.text = "%d FPS · %.1f ms/frame" % [roundi(_performance_frames / _performance_elapsed), 1000.0 * _performance_elapsed / _performance_frames]
  _performance_elapsed = 0.0
  _performance_frames = 0
