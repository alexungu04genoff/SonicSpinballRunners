extends CanvasLayer
## User-local drafts and explicit production variants share one live inspector.
const SceneryControls := preload("res://experiments/lighting_lab/scenery_controls.gd")
const EmissionPreview := preload("res://experiments/lighting_lab/emission_preview.gd")
const LightingLooks := preload("res://experiments/lighting_lab/lighting_looks.gd")
# Label, property, kind; numeric rows also carry minimum, maximum and step.
const Fields := preload("res://scripts/atmosphere/fields.gd")
const ColorRanges := preload("res://scripts/atmosphere/color_ranges.gd")
const DirectionalFog := preload("res://scripts/atmosphere/directional_fog.gd")
const FogView := preload("res://experiments/lighting_lab/fog_view.gd")
const RenderingOptions := preload("res://scripts/rendering_options.gd")
const GROUPS := Fields.GROUPS
const PROCEDURAL_SKY_FIELDS := Fields.PROCEDURAL_SKY_FIELDS
var variants: VBoxContainer
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
var smooth_shadows: CheckButton
var performance_label: Label
var fps_overlay: Label
var tabs: TabContainer
var scenery: VBoxContainer
var save_button: Button
var sky_controls: VBoxContainer
var palette_controls: VBoxContainer
var gameplay_controls: VBoxContainer
var color_range_picker: VBoxContainer
var fog_view_note: Label
var fog_fit_button: Button
var palette_fields: Array = []
var sky_fields: Array = []
var sky_material: Material
var show_background_scenery := true
var show_local_scenery := true
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
 fps_overlay = Label.new()
 fps_overlay.name = "LightingLabFPS"
 fps_overlay.position = Vector2(8, 4)
 fps_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
 fps_overlay.add_theme_font_size_override("font_size", 13)
 fps_overlay.add_theme_color_override("font_color", Color.WHITE)
 fps_overlay.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
 fps_overlay.add_theme_constant_override("outline_size", 3)
 fps_overlay.text = "FPS —"
 root.add_child(fps_overlay)
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
 performance_label.text = "Display synchronized" if vsync.button_pressed else "Uncapped rendering"
 performance_row.add_child(performance_label)
 variants = preload("res://experiments/lighting_lab/variant_controls.gd").new()
 variants.install(self, column)
 look_selector = OptionButton.new()
 look_selector.focus_mode = Control.FOCUS_NONE
 look_selector.add_item("Try an atmosphere…")
 look_selector.add_item("Authored atmosphere")
 for look: String in LightingLooks.LOOKS: look_selector.add_item(look)
 look_selector.item_selected.connect(_select_look)
 column.add_child(look_selector)
 compare = CheckButton.new()
 compare.text = "Show original atmosphere"
 compare.tooltip_text = "Compare original lighting, sky and theme palette together. Your tuned draft is preserved."
 compare.focus_mode = Control.FOCUS_NONE
 compare.toggled.connect(func(_enabled: bool): apply_values())
 column.add_child(compare)
 tabs = TabContainer.new()
 tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
 tabs.add_theme_font_size_override("font_size", 12)
 tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(tabs)
 var variant_scroll := ScrollContainer.new()
 variant_scroll.name = "Variants"
 variant_scroll.add_child(variants)
 variants.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 tabs.add_child(variant_scroll)
 var tab_groups := GROUPS.keys()
 tab_groups.insert(tab_groups.find("Palette") + 1, "Gameplay")
 for group: String in tab_groups:
  var scroll := ScrollContainer.new()
  scroll.name = group
  scroll.mouse_force_pass_scroll_events = false
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  tabs.add_child(scroll)
  var controls := VBoxContainer.new()
  controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  controls.add_theme_constant_override("separation", 8)
  scroll.add_child(controls)
  if group == "Glow & Fog":
   var note := Label.new()
   note.text = "Enable Glow for screen halos. Lower Tight halo and raise Wide / soft or Diffuse for a softer look. Emission controls the source; Glow intensity controls the halo. Retro adds its own phosphor halo."
   note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   note.add_theme_font_size_override("font_size", 12)
   controls.add_child(note)
  if group == "Directional Fog":
   var note := Label.new()
   note.text = "Fog builds across the table from the view center. 0° = north, 90° = east. Start offsets the clear area; fade length reaches maximum density. Curve 1 is linear; higher values build later. Independent of ordinary fog."
   note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   note.add_theme_font_size_override("font_size", 12)
   controls.add_child(note)
  if group == "Scenery":
   scenery = SceneryControls.new()
   controls.add_child(scenery)
   scenery.install(self)
  if group == "Shadows":
   smooth_shadows = CheckButton.new()
   smooth_shadows.text = "Smooth shadows · Ultra + FXAA"
   smooth_shadows.tooltip_text = "Reduces soft-shadow speckling using Ultra filtering and FXAA. Costs more GPU time and slightly smooths the 3D image. Saved for this device, including gameplay; independent of atmosphere variants."
   smooth_shadows.focus_mode = Control.FOCUS_NONE
   smooth_shadows.set_pressed_no_signal(RenderingOptions.smooth_shadows_enabled())
   smooth_shadows.toggled.connect(func(enabled: bool):
    var error := RenderingOptions.set_smooth_shadows(enabled)
    if error != OK:
     smooth_shadows.set_pressed_no_signal(RenderingOptions.smooth_shadows_enabled())
     message.text = "Cannot save graphics setting: " + error_string(error)
   )
   controls.add_child(smooth_shadows)
  if group == "Sky": sky_controls = controls
  if group == "Palette": palette_controls = controls
  if group == "Gameplay": gameplay_controls = controls
  if group == "Hue":
   color_range_picker = preload("res://experiments/lighting_lab/color_range_picker.gd").new()
   controls.add_child(color_range_picker)
   color_range_picker.install(self)
   var note := Label.new()
   note.text = "Adjust presentation colors after Palette. Gameplay colors and neutral whites/grays stay protected."
   note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   note.add_theme_font_size_override("font_size", 12)
   controls.add_child(note)
   for spec: Array in ColorRanges.fields(): _field(controls, spec)
   _button(controls, "Reset color ranges", func():
    for spec: Array in ColorRanges.fields(): values[spec[1]] = ColorRanges.neutral(spec[1])
    set_value("ranges/enabled", false)
   )
  for spec: Array in GROUPS.get(group, []):
   if spec[1] == "env/fog_enabled":
    var note := Label.new()
    note.text = "Depth / distance fog: fit start/end to the visible table below. Density is maximum opacity (try 0.5). Exponential fog uses density only. Directional Fog has its own tab."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 12)
    controls.add_child(note)
    fog_view_note = Label.new()
    fog_view_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    fog_view_note.add_theme_font_size_override("font_size", 12)
    controls.add_child(fog_view_note)
    fog_fit_button = _button(controls, "Fit distances to view", _fit_fog_to_view)
   _field(controls, spec)
 var actions := HBoxContainer.new()
 column.add_child(actions)
 save_button = _button(actions, "Save", func():
  if _scenery_tab(): scenery.save()
  elif variants.context.selected != "draft": variants.save_variant()
  else: save_preset()
 )
 _button(actions, "Reload", func():
  if _scenery_tab(): scenery.reload()
  elif variants.context.selected != "draft": variants.revert()
  else: reload_preset()
 )
 _button(actions, "Reset", func():
  if _scenery_tab(): scenery.reset()
  else: reset_values()
 )
 _button(actions, "Open folder", func(): OS.shell_open(ProjectSettings.globalize_path(scenery.act_path if _scenery_tab() else settings_path).get_base_dir()))
 tabs.tab_changed.connect(func(_index: int): variants.refresh())
 message = Label.new()
 message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 message.add_theme_font_size_override("font_size", 12)
 column.add_child(message)
 reopen = _button(root, "Atmosphere · F6", toggle_panel)
 reopen.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 reopen.offset_left = -145
 reopen.offset_right = -10
 reopen.offset_top = 30
 reopen.offset_bottom = 66
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
   preload("res://experiments/lighting_lab/number_display.gd").install(number)
   number.min_value = spec[3]
   number.max_value = spec[4]
   number.step = 0.0 # Typed values are not quantized to the slider increment.
   number.custom_arrow_step = spec[5]
   number.allow_greater = true
   number.allow_lesser = true
   if key.begins_with("directional_fog/") or key.begins_with("env/fog_") or key.begins_with("env/glow_") or key == "surface_halo_spread":
    number.allow_greater = false
    number.allow_lesser = false
   number.value_changed.connect(func(value: float): set_value(key, value))
   field = number
  "color":
   var color := ColorPickerButton.new()
   color.edit_alpha = false
   for component: SpinBox in color.get_picker().find_children("*", "SpinBox", true, false): preload("res://experiments/lighting_lab/number_display.gd").install(component)
   for component: Slider in color.get_picker().find_children("*", "Slider", true, false): component.scrollable = false
   color.color_changed.connect(func(value: Color): set_value(key, value))
   field = color
  "bool":
   var toggle := CheckButton.new()
   toggle.toggled.connect(func(value: bool): set_value(key, value))
   field = toggle
  _:
   var options := OptionButton.new()
   var names := ["Linear", "Reinhard", "Filmic", "ACES", "AgX"] if spec[2] == "tone" else ["1 · Orthogonal", "2 · PSSM", "4 · PSSM"]
   if spec[2] == "fog_mode": names = ["Exponential", "Depth / distance"]
   for title: String in names: options.add_item(title)
   options.item_selected.connect(func(value: int): set_value(key, value))
   field = options
 field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 field.focus_mode = Control.FOCUS_NONE
 row.add_child(field)
 widgets[key] = field
 if key == "surface_halo_spread":
  field.tooltip_text = "Scales the existing floor/edge material halo radius. 1.00 preserves the authored width. This is separate from screen-space Glow."
 if key == "sun/light_angular_distance" and renderer != "forward_plus":
  (field as SpinBox).editable = false
  field.tooltip_text = "Directional soft shadows require Forward+."
 elif key == "sun/light_angular_distance":
  field.tooltip_text = "Sun angular size in degrees. Higher values widen contact shadows and can expose shadow-filter dithering. 0.00 disables contact-hardening softness."
 if spec[2] == "number":
  var slider := HSlider.new()
  slider.scrollable = false
  slider.min_value = spec[3]
  slider.max_value = spec[4]
  slider.step = spec[5]
  slider.focus_mode = Control.FOCUS_NONE
  slider.editable = not (key == "sun/light_angular_distance" and renderer != "forward_plus")
  slider.value_changed.connect(func(value: float): set_value(key, value))
  parent.add_child(slider)
  field.set_meta("slider", slider)

func bind_theme() -> void:
 variants.syncing = true
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
 light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
 game.presentation.theme_definition.configure_environment(game.presentation)
 var rooftop = game.get("rooftop_materials")
 if game.theme_id == "rooftop_run" and is_instance_valid(rooftop): rooftop.apply_lighting()
 Fields.apply_shadow_defaults(light)
 _bind_sky(environment)
 emission.collect(game.presentation, game.theme_id, sky_material)
 _bind_palette()
 preset_key = renderer + "/" + game.theme_id
 originals.clear()
 for group: Array in GROUPS.values():
  for spec: Array in group: originals[spec[1]] = _read_value(spec[1])
 for spec: Array in sky_fields: originals[spec[1]] = _read_value(spec[1])
 originals.merge(emission.palette_originals)
 values = originals.duplicate(true)
 var stored: Dictionary = drafts.get(preset_key, saved.get_value(preset_key, "values", {}))
 for key: String in originals:
  if stored.has(key) and typeof(stored[key]) == typeof(originals[key]): values[key] = stored[key]
 compare.set_pressed_no_signal(false)
 look_selector.select(0)
 _sync_widgets()
 apply_values()
 caption.text = "ATMOSPHERE / " + {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "ANGLE"}.get(renderer, renderer)
 message.text = "Lab preset: " + game.presentation.theme_definition.display_name + "\nSave keeps these values for this renderer only."

 scenery.bind_context()
 variants.syncing = false
 variants.bind_theme()

func _scenery_tab() -> bool:
 return tabs.get_current_tab_control().name == "Scenery"

func preview_scenery(selected: Dictionary) -> void:
 restore_original()
 game.presentation.rebuild_local_scenery(selected)
 emission.collect(game.presentation, game.theme_id, sky_material)
 _bind_palette()
 originals.merge(emission.palette_originals, true)
 for key: String in emission.palette_originals:
  if not values.has(key): values[key] = emission.palette_originals[key]
 _sync_widgets()
 apply_values()
 set_scenery_visible("far", show_background_scenery)
 set_scenery_visible("local", show_local_scenery)

func _bind_sky(environment: Environment) -> void:
 for spec: Array in sky_fields: widgets.erase(spec[1])
 for child: Node in sky_controls.get_children():
  sky_controls.remove_child(child)
  child.queue_free()
 sky_fields = [["Background brightness", "env/background_energy_multiplier", "number", 0.0, 3.0, 0.01]]
 sky_material = environment.sky.sky_material if environment.sky != null else null
 var description := "Background brightness is available; this background has no supported palette controls."
 if environment.background_mode == Environment.BG_SKY and sky_material is ProceduralSkyMaterial:
  # Tune only a private copy of the theme-created Sky and material. Source
  # resources, custom shader code and other presentation instances stay intact.
  environment.sky = environment.sky.duplicate()
  sky_material = sky_material.duplicate()
  environment.sky.sky_material = sky_material
  sky_fields.append_array(PROCEDURAL_SKY_FIELDS)
  description = "Procedural sky · Colors and horizon blends save with the atmosphere. Inspect far scenery and local framing separately below."
 elif environment.background_mode == Environment.BG_COLOR:
  sky_fields.append(["Background color", "env/background_color", "color"])
  description = "Solid background · Color applies behind scenery. Magma, cavern and crystal colors are in Palette."
 elif environment.background_mode == Environment.BG_SKY and sky_material is ShaderMaterial:
  environment.sky = environment.sky.duplicate()
  sky_material = sky_material.duplicate()
  environment.sky.sky_material = sky_material
  description = "Custom sky · Horizon, stars and aurora colors are in Palette. Radiance updates when those values change, then stays cached."
 var note := Label.new()
 note.text = description
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 note.add_theme_font_size_override("font_size", 13)
 sky_controls.add_child(note)
 for kind: String in ["far", "local"]:
  var scenery := CheckButton.new()
  scenery.text = "Show far environment" if kind == "far" else "Show local framing"
  scenery.tooltip_text = "Inspection only; not saved in atmosphere presets."
  scenery.focus_mode = Control.FOCUS_NONE
  scenery.set_pressed_no_signal(show_background_scenery if kind == "far" else show_local_scenery)
  scenery.toggled.connect(func(enabled: bool): set_scenery_visible(kind, enabled))
  sky_controls.add_child(scenery)
 set_scenery_visible("far", show_background_scenery)
 set_scenery_visible("local", show_local_scenery)
 for spec: Array in sky_fields: _field(sky_controls, spec)
 for spec: Array in PROCEDURAL_SKY_FIELDS:
  if spec[2] == "number" and widgets.has(spec[1]):
   # Curve setters expect a positive blend range, unlike free-form light energy.
   var number: SpinBox = widgets[spec[1]]
   number.allow_greater = false
   number.allow_lesser = false

func set_scenery_visible(kind: String, enabled: bool) -> void:
 if kind == "far": show_background_scenery = enabled
 else: show_local_scenery = enabled
 for child: Node3D in game.presentation.scenery_root.get_children():
  if child.get_meta("atmosphere_scenery", "far") == kind: child.visible = enabled

func _bind_palette() -> void:
 var halo: SpinBox = widgets["surface_halo_spread"]
 halo.get_parent().visible = not emission.halo_parameters.is_empty()
 halo.get_meta("slider").visible = halo.get_parent().visible
 for spec: Array in palette_fields: widgets.erase(spec[1])
 for container: VBoxContainer in [palette_controls, gameplay_controls]:
  for child: Node in container.get_children():
   container.remove_child(child)
   child.queue_free()
 palette_fields = []
 for spec: Array in ColorRanges.fields(): emission.palette_originals[spec[1]] = ColorRanges.neutral(spec[1])
 for spec: Array in ColorRanges.stack_fields(game.theme_id): emission.palette_originals[spec[1]] = true
 for spec: Array in Fields.HUE_FIELDS:
  emission.palette_originals[spec[1]] = spec[1].begins_with("link/") if spec[2] == "bool" else (1.0 if (spec[1].begins_with("saturation/") or spec[1].begins_with("brightness/")) else 0.0)
  if spec[1].ends_with("/foliage") and not emission.has_foliage(): continue
  var controls := gameplay_controls if spec[1].ends_with("/ramps") else palette_controls
  palette_fields.append(spec)
  _field(controls, spec)
  if spec[1].begins_with("brightness/"):
   var stack := ["Stack with Hue", "stack/" + spec[1].trim_prefix("brightness/"), "bool"]
   palette_fields.append(stack)
   _field(controls, stack)
 widgets["link/terrain_trim"].tooltip_text = "Linked: Borders drives all three groups. Unlinked: Edges affect the outer floor rim, Borders affect trim around terrain bases, and Ledges affect upper trim. Independent values are retained while linked."
 var hardware_keys := {}
 for field: Array in EmissionPreview.Palette.HARDWARE_FIELDS: hardware_keys["palette/" + field[1]] = true
 for spec: Array in EmissionPreview.Palette.fields(game.theme_id):
  if not emission.palette_originals.has(spec[1]): continue
  var controls := gameplay_controls if hardware_keys.has(spec[1]) else palette_controls
  var hardware_heading: String = {"palette/hardware_rubber": "Pinball Hardware", "palette/mechanism_body": "Mechanisms", "palette/spinner_frame": "Spinner", "palette/dash_chassis": "Dash Panel"}.get(spec[1], "")
  if not hardware_heading.is_empty():
   var heading := Label.new()
   heading.text = hardware_heading
   controls.add_child(heading)
  palette_fields.append(spec)
  _field(controls, spec)
  if spec[2] == "color":
   var stack := ["Stack with Hue", "stack/" + spec[1], "bool"]
   palette_fields.append(stack)
   _field(controls, stack)
  if spec[2] == "number":
   var number: SpinBox = widgets[spec[1]]
   number.allow_greater = false
   number.allow_lesser = false

func _read_value(key: String) -> Variant:
 if DirectionalFog.DEFAULTS.has(key): return DirectionalFog.DEFAULTS[key]
 if key in ["emission", "surface_halo_spread"]: return 1.0
 if key == "sun_pitch": return game.presentation._key_light.rotation_degrees.x
 if key == "sun_yaw": return game.presentation._key_light.rotation_degrees.y
 if key.begins_with("sky/"): return sky_material.get(key.get_slice("/", 1))
 var target: Object = game.presentation._world_environment.environment if key.begins_with("env/") else game.presentation._key_light
 return target.get(key.substr(key.find("/") + 1))

func set_value(key: String, value: Variant) -> void:
 if not originals.has(key): return
 values[key] = value
 if variants == null or variants.context.is_empty() or variants.context.selected == "draft": drafts[preset_key] = values.duplicate(true)
 compare.set_pressed_no_signal(false)
 look_selector.select(0)
 _sync_widgets()
 apply_values()
 message.text = "Unsaved atmosphere · " + game.presentation.theme_definition.display_name

func _sync_widgets() -> void:
 for key: String in widgets:
  var field: Control = widgets[key]
  if field is Range:
   field.set_value_no_signal(float(values[key]))
   if field.has_meta("slider"): field.get_meta("slider").set_value_no_signal(float(values[key]))
  elif field is ColorPickerButton: field.color = values[key]
  elif field is OptionButton: field.select(int(values[key]))
  elif field is CheckButton: field.set_pressed_no_signal(bool(values[key]))
 var linked: bool = values.get("link/terrain_trim", true)
 for group: String in ["terrain_edges", "terrain_ledges"]:
  for prefix: String in ["override/", "hue/", "saturation/", "brightness/", "stack/"]:
   var field: Control = widgets.get(prefix + group)
   if field is SpinBox:
    field.editable = not linked
    field.get_meta("slider").editable = not linked
   elif field is CheckButton: field.disabled = linked

func apply_values() -> void:
 _apply(originals if compare.button_pressed else values)
 if is_instance_valid(variants): variants.capture()

func sync_fog_controls() -> void:
 var source: Dictionary = originals if compare.button_pressed else values
 var depth_mode: bool = int(source.get("env/fog_mode", 0)) == Environment.FOG_MODE_DEPTH
 for key: String in ["env/fog_depth_begin", "env/fog_depth_end", "env/fog_depth_curve"]:
  var control: SpinBox = widgets[key]
  control.editable = depth_mode
  control.get_meta("slider").editable = depth_mode
  control.tooltip_text = "Depth mode only. Distances are from the camera; 1 unit = 100 table pixels. Higher curve values delay buildup."
 widgets["env/fog_density"].tooltip_text = "Exponential: density per distance. Depth: maximum opacity (0–1); try 0.5 for a visible starting point."
 fog_fit_button.disabled = not depth_mode
 _sync_fog_view(source)

func _sync_fog_view(source: Dictionary) -> void:
 var span := FogView.table_distances(game.presentation.camera)
 var margin := maxf(0.1, (span.y - span.x) * 0.1)
 fog_view_note.text = "Visible table: %.2f–%.2f units from camera. Sliders follow this view; saved distances stay fixed. Type a distance to go outside the view." % [span.x, span.y]
 for key: String in ["env/fog_depth_begin", "env/fog_depth_end"]:
  var slider: HSlider = widgets[key].get_meta("slider")
  slider.set_block_signals(true)
  slider.min_value = maxf(0.0, span.x - margin)
  slider.max_value = span.y + margin
  slider.step = 0.01
  var distance := float(source.get(key, 0.0))
  slider.value = slider.max_value if key == "env/fog_depth_end" and is_zero_approx(distance) else distance
  slider.set_block_signals(false)

func _fit_fog_to_view() -> void:
 var span := FogView.table_distances(game.presentation.camera)
 set_value("env/fog_depth_begin", snappedf(lerpf(span.x, span.y, 0.1), 0.01))
 set_value("env/fog_depth_end", snappedf(span.y, 0.01))
 message.text = "Fog distances fitted to the current view. Save to keep."

func _apply(source: Dictionary) -> void:
 DirectionalFog.apply(game.presentation.camera, source)
 sync_fog_controls()
 for key: String in source:
  if key.begins_with("directional_fog/"): continue
  if key.begins_with("palette/") or key.begins_with("hue/") or key.begins_with("saturation/") or key.begins_with("override/") or key.begins_with("brightness/") or key.begins_with("ranges/") or key.begins_with("stack/") or key.begins_with("link/"): continue
  if key == "emission": emission.apply(float(source[key]))
  elif key == "surface_halo_spread": continue # Applied with the bound material controls below.
  elif key == "sun_pitch": game.presentation._key_light.rotation_degrees.x = float(source[key])
  elif key == "sun_yaw": game.presentation._key_light.rotation_degrees.y = float(source[key])
  elif key.begins_with("sky/"):
   if sky_material is ProceduralSkyMaterial: sky_material.set(key.get_slice("/", 1), source[key])
  else:
   var target: Object = game.presentation._world_environment.environment if key.begins_with("env/") else game.presentation._key_light
   target.set(key.substr(key.find("/") + 1), source[key])
 var changed_sun: bool = source.get("sun_pitch") != originals.get("sun_pitch") or source.get("sun_yaw") != originals.get("sun_yaw")
 emission.apply_palette(source, game.presentation._key_light, changed_sun)

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
 var version := int(saved.get_value("format", "version", 1))
 if version > 2:
  message.text = "Save stopped: this preset file uses a newer format."
  return
 if version == 1 and FileAccess.file_exists(settings_path) and not FileAccess.file_exists(settings_path + ".v1-backup"):
  var backup_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(settings_path), ProjectSettings.globalize_path(settings_path + ".v1-backup"))
  if backup_error != OK:
   message.text = "Save stopped: could not back up v1 presets (" + error_string(backup_error) + ")"
   return
 var merged_values: Dictionary = saved.get_value(preset_key, "values", {}).duplicate(true)
 merged_values.merge(values, true)
 saved.set_value(preset_key, "values", merged_values)
 # Additive v2: v1 light/sky keys keep their values; missing palette keys use
 # the authored baseline. Preserve all other renderer/theme sections.
 saved.set_value("format", "version", 2)
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
 if variants.context.is_empty() or variants.context.selected == "draft": drafts[preset_key] = values.duplicate(true)
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
 performance_label.text = "Display synchronized" if vsync.button_pressed else "Uncapped rendering"

func _select_look(index: int) -> void:
 if index == 0: return
 var title := look_selector.get_item_text(index)
 values = originals.duplicate(true) if index == 1 else LightingLooks.create(title, originals, game.theme_id)
 if variants.context.is_empty() or variants.context.selected == "draft": drafts[preset_key] = values.duplicate(true)
 compare.set_pressed_no_signal(false)
 _sync_widgets()
 apply_values()
 message.text = title + " · Unsaved preview. Save to keep."

func _process(delta: float) -> void:
 if not is_instance_valid(game): return
 # Own one consistent counter, including when the inspector is hidden. Some
 # local visual-lab versions have a separate counter with a different interval.
 var inherited_fps = game.get("fps_label")
 if is_instance_valid(inherited_fps) and inherited_fps.visible: inherited_fps.hide()
 var pause_text := "Resume play" if get_tree().paused else "Pause play"
 if pause_button.text != pause_text: pause_button.text = pause_text
 panel.offset_top = 10.0 if game.player_view else 30.0
 panel.offset_bottom = -10.0 if game.player_view else -215.0
 # The existing player owns layout/fullscreen. Reserve space only in lab view.
 if not game.debug_open and not game.player_view:
  var target_offset := -405.0 if panel.visible else 0.0
  if not is_equal_approx(game.view_container.offset_right, target_offset):
   game.view_container.offset_right = target_offset
 _performance_elapsed += delta
 _performance_frames += 1
 if _performance_elapsed >= 0.5:
  if panel.visible and tabs.get_current_tab_control().name == "Glow & Fog": _sync_fog_view(originals if compare.button_pressed else values)
  fps_overlay.text = "%d FPS · %.1f ms/frame" % [roundi(_performance_frames / _performance_elapsed), 1000.0 * _performance_elapsed / _performance_frames]
  _performance_elapsed = 0.0
  _performance_frames = 0
