extends CanvasLayer
## Native-resolution development controls, outside the filtered world viewport.
const Filter := preload("res://scripts/retro/retro_filter.gd")
const PARAMETERS := {
 Filter.Preset.PIXEL: [
  ["pixel_resolution_divisor", "Resolution divisor", 1, 4, 1],
  ["pixel_color_levels", "Color levels", 4, 64, 1],
  ["pixel_dither_strength", "Dither strength", 0, 1, 0.05]],
 Filter.Preset.N64: [
  ["n64_resolution_divisor", "Resolution divisor", 1, 4, 1],
  ["n64_color_levels", "Color levels", 4, 64, 1],
  ["n64_dither_strength", "Dither strength", 0, 1, 0.05]],
 Filter.Preset.CRT: [
  ["crt_cell_size", "Phosphor cell size [px]", 3, 16, 1],
  ["crt_scanlines", "Scanline strength", 0, 0.6, 0.01],
  ["crt_mask", "RGB mask strength", 0, 0.4, 0.01],
  ["crt_glow", "Phosphor glow", 0, 0.8, 0.01],
  ["crt_glow_radius", "Glow spread [px]", 1, 8, 0.5],
  ["crt_brightness", "Brightness", -0.1, 0.2, 0.005],
  ["crt_vignette", "Vignette", 0, 0.3, 0.01]],
 Filter.Preset.VHS: [
  ["vhs_chroma_offset", "Chroma offset [px]", 0, 2, 0.05],
  ["vhs_chroma_bleed", "Chroma bleed [px]", 0, 3, 0.05],
  ["vhs_wobble", "Wobble", 0, 0.001, 0.00005],
  ["vhs_grain", "Tape grain", 0, 0.05, 0.001],
  ["vhs_tracking", "Tracking", 0, 0.002, 0.0001]],
}
var filter: Filter
var selector: MenuButton
var open_button: Button
var tuning_panel: PanelContainer
var toast: Label
var fields: Dictionary = {}
var values: Dictionary = {}
var checks: Dictionary = {}
var groups: Dictionary = {}
var _defaults: Resource
var _remaining := 0.0

func install(adapter: Filter, debug_stack: Node, toolbar: Node) -> void:
 filter = adapter
 _defaults = filter.settings.duplicate()
 layer = 25
 process_mode = Node.PROCESS_MODE_ALWAYS
 selector = MenuButton.new()
 selector.name = "RetroFilterPreset"
 selector.tooltip_text = "Check multiple effects to stack them. F4 cycles single presets; Shift+F4 opens live tuning."
 var menu := selector.get_popup()
 menu.hide_on_checkable_item_selection = false
 menu.add_item("OFF / clear all", 0)
 for effect in range(1, Filter.NAMES.size()):
  menu.add_check_item(Filter.NAMES[effect], effect)
 menu.add_separator()
 menu.add_item("Live tuning...", 10)
 menu.id_pressed.connect(func(id: int):
  if id == 10:
   toggle_panel()
  elif id == 0:
   filter.set_preset(Filter.Preset.OFF)
  else:
   filter.toggle_effect(id)
 )
 debug_stack.add_child(selector)
 debug_stack.move_child(selector, 2)
 open_button = Button.new()
 open_button.text = "Retro..."
 open_button.tooltip_text = "Stack effects and tune them live (Shift+F4)"
 open_button.focus_mode = Control.FOCUS_NONE
 open_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 # Match the host toolbar without taking ownership of its theme or layout.
 if toolbar.get_child_count() > 0 and toolbar.get_child(0) is Button:
  var reference: Button = toolbar.get_child(0)
  open_button.add_theme_font_size_override("font_size", reference.get_theme_font_size("font_size"))
  for style_name: String in ["normal", "hover", "pressed"]:
   open_button.add_theme_stylebox_override(style_name, reference.get_theme_stylebox(style_name))
 open_button.pressed.connect(toggle_panel)
 toolbar.add_child(open_button)
 _build_panel()
 toast = Label.new()
 toast.name = "RetroPresetToast"
 toast.position = Vector2(350, 24)
 toast.size = Vector2(580, 38)
 toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
 toast.add_theme_font_size_override("font_size", 17)
 var background := StyleBoxFlat.new()
 background.bg_color = Color(0.025, 0.10, 0.12, 0.92)
 background.content_margin_top = 8
 background.content_margin_bottom = 8
 toast.add_theme_stylebox_override("normal", background)
 add_child(toast)
 toast.hide()
 filter.preset_changed.connect(_changed)
 filter.tree_exiting.connect(queue_free)
 _sync_controls()

func _build_panel() -> void:
 tuning_panel = PanelContainer.new()
 tuning_panel.name = "RetroLiveTuning"
 add_child(tuning_panel)
 tuning_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 tuning_panel.offset_left = -400
 tuning_panel.offset_right = -20
 tuning_panel.offset_top = 80
 tuning_panel.offset_bottom = 680
 var style := StyleBoxFlat.new()
 style.bg_color = Color("102c35")
 for side: String in ["left", "right", "top", "bottom"]:
  style.set("content_margin_" + side, 12.0)
 tuning_panel.add_theme_stylebox_override("panel", style)
 var stack := VBoxContainer.new()
 tuning_panel.add_child(stack)
 var header := HBoxContainer.new()
 stack.add_child(header)
 var title := Label.new()
 title.text = "RETRO LAB / LIVE"
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title)
 var close := Button.new()
 close.text = "Close"
 close.pressed.connect(toggle_panel)
 header.add_child(close)
 var note := Label.new()
 note.text = "Check effects to stack them. Changes apply instantly."
 note.add_theme_font_size_override("font_size", 12)
 stack.add_child(note)
 var scroll := ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 stack.add_child(scroll)
 var content := VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(content)
 for effect: int in Filter.ORDER:
  var toggle := CheckButton.new()
  toggle.text = Filter.NAMES[effect]
  toggle.toggled.connect(func(_on: bool): filter.toggle_effect(effect))
  content.add_child(toggle)
  checks[effect] = toggle
  var group := VBoxContainer.new()
  content.add_child(group)
  groups[effect] = group
  for spec: Array in PARAMETERS[effect]:
   var key: String = spec[0]
   var caption := Label.new()
   caption.text = spec[1]
   caption.add_theme_font_size_override("font_size", 13)
   group.add_child(caption)
   var row := HBoxContainer.new()
   group.add_child(row)
   var slider := HSlider.new()
   slider.min_value = spec[2]
   slider.max_value = spec[3]
   slider.step = spec[4]
   slider.custom_minimum_size.x = 220
   slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
   slider.focus_mode = Control.FOCUS_NONE
   row.add_child(slider)
   var value := Label.new()
   value.custom_minimum_size.x = 66
   value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
   row.add_child(value)
   fields[key] = slider
   values[key] = value
   slider.value_changed.connect(func(number: float):
    filter.settings.set(key, number)
    filter.apply_settings()
    values[key].text = str(snappedf(number, float(spec[4])))
   )
 var buttons := HBoxContainer.new()
 stack.add_child(buttons)
 var clear := Button.new()
 clear.text = "All OFF"
 clear.pressed.connect(func(): filter.set_preset(Filter.Preset.OFF))
 buttons.add_child(clear)
 var reset := Button.new()
 reset.text = "Reset tuning"
 reset.pressed.connect(reset_tuning)
 buttons.add_child(reset)
 tuning_panel.hide()

func reset_tuning() -> void:
 filter.settings = _defaults.duplicate()
 filter.apply_settings()
 _sync_controls()

func toggle_panel() -> void:
 tuning_panel.visible = not tuning_panel.visible
 get_viewport().gui_release_focus()

func _unhandled_key_input(event: InputEvent) -> void:
 if not is_instance_valid(filter):
  return
 if event is InputEventKey and event.pressed and not event.echo and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
  if event.physical_keycode == KEY_F4 or event.keycode == KEY_F4:
   if event.shift_pressed:
    toggle_panel()
   else:
    filter.cycle()
   get_viewport().set_input_as_handled()

func _sync_controls() -> void:
 var menu := selector.get_popup()
 for effect: int in Filter.ORDER:
  menu.set_item_checked(menu.get_item_index(effect), filter.is_enabled(effect))
  checks[effect].set_pressed_no_signal(filter.is_enabled(effect))
  groups[effect].visible = filter.is_enabled(effect)
 selector.text = "Retro: %d filters" % filter.selected_effects.size() if filter.preset == -1 else "F4  Retro: " + Filter.NAMES[filter.preset]
 for key: String in fields:
  fields[key].set_value_no_signal(filter.settings.get(key))
  values[key].text = str(filter.settings.get(key))

func _changed(_index: int) -> void:
 _sync_controls()
 toast.text = "RETRO  /  " + filter.display_name()
 toast.show()
 _remaining = 2.0

func _process(delta: float) -> void:
 if _remaining > 0.0:
  _remaining -= delta
  if _remaining <= 0.0:
   toast.hide()

func _exit_tree() -> void:
 # These controls were installed in the host UI, outside our own subtree.
 for control: Control in [selector, open_button]:
  if is_instance_valid(control):
   control.queue_free()
