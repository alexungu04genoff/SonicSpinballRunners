extends VBoxContainer
## One-shot scene sampling; dragging only edits the existing range values.
const Ranges := preload("res://scripts/atmosphere/color_ranges.gd")
var panel: CanvasLayer
var arm: CheckButton
var mode: OptionButton
var swatch: ColorRect
var status: Label
var selected := ""
var busy := false
var dragging := false
var start := Vector2.ZERO
var latest := Vector2.ZERO
var start_value := 0.0
var drag_key := ""

func install(owner_panel: CanvasLayer) -> void:
 panel = owner_panel
 process_mode = Node.PROCESS_MODE_ALWAYS
 var row := HBoxContainer.new()
 add_child(row)
 arm = CheckButton.new()
 arm.text = "Pick in scene"
 arm.tooltip_text = "Samples before Hue and Retro, so previously shifted colors retain their original range. Lighting and Palette edits remain in the sample."
 arm.focus_mode = Control.FOCUS_NONE
 arm.toggled.connect(func(enabled: bool):
  dragging = false
  Input.set_default_cursor_shape(Input.CURSOR_CROSS if enabled else Input.CURSOR_ARROW)
 )
 row.add_child(arm)
 mode = OptionButton.new()
 mode.focus_mode = Control.FOCUS_NONE
 for title: String in ["Hue", "Saturation", "Brightness"]: mode.add_item(title)
 row.add_child(mode)
 var sample_row := HBoxContainer.new()
 add_child(sample_row)
 swatch = ColorRect.new()
 swatch.custom_minimum_size = Vector2(22, 22)
 swatch.color = Color.GRAY
 sample_row.add_child(swatch)
 status = Label.new()
 status.text = "Click a color, then drag left/right."
 status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 status.add_theme_font_size_override("font_size", 12)
 sample_row.add_child(status)
 var note := Label.new()
 note.text = "Shift: fine adjustment · Esc: stop picking."
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 note.add_theme_font_size_override("font_size", 12)
 add_child(note)
 panel.tabs.tab_changed.connect(func(_index: int):
  if panel.tabs.get_current_tab_control().name != "Hue": arm.button_pressed = false
 )

func _input(event: InputEvent) -> void:
 if not arm.button_pressed: return
 if event is InputEventKey:
  var focus := get_viewport().gui_get_focus_owner()
  if focus is LineEdit or focus is TextEdit: return
 if panel.game.is_source_picker_open(): return
 if not panel.panel.visible:
  arm.button_pressed = false
  return
 if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
  arm.button_pressed = false
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and (dragging or busy):
  latest = event.position
  if dragging and not busy: drag_to(latest, event.shift_pressed)
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  if not event.pressed and (dragging or busy):
   dragging = false
   get_viewport().set_input_as_handled()
  elif event.pressed and not busy and not panel.blocks_camera_at(event.position) and panel.game.view_container.get_global_rect().has_point(event.position):
   dragging = true
   start = event.position
   latest = start
   get_viewport().set_input_as_handled()
   pick_at(start)

func pick_at(point: Vector2) -> bool:
 if busy: return false
 var view: SubViewport = panel.game.view
 var holder: Control = panel.game.view_container
 var displayed := displayed_rect(holder.get_global_rect(), view.size)
 if not displayed.has_point(point): return false
 busy = true
 var tree := get_tree()
 var was_paused := tree.paused
 tree.paused = true
 # Keep the current preview visible while sampling the existing viewport with
 # ranges/Retro bypassed. No new viewport, render pass or texture rebake.
 var frozen := TextureRect.new()
 frozen.texture = ImageTexture.create_from_image(view.get_texture().get_image())
 frozen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 frozen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 frozen.mouse_filter = Control.MOUSE_FILTER_IGNORE
 holder.add_child(frozen)
 frozen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var retro_layer: CanvasLayer = panel.game.retro_filter.effect_layer
 var retro_visible := retro_layer.visible
 retro_layer.hide()
 var sample_values: Dictionary = (panel.originals if panel.compare.button_pressed else panel.values).duplicate(true)
 sample_values["ranges/enabled"] = false
 _apply_palette(sample_values)
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 var picture := view.get_texture().get_image()
 var coordinate := Vector2i((point - displayed.position) / displayed.size * Vector2(picture.get_size()))
 var color := Color(0, 0, 0, 0)
 for y in range(-1, 2):
  for x in range(-1, 2): color += picture.get_pixel(clampi(coordinate.x + x, 0, picture.get_width() - 1), clampi(coordinate.y + y, 0, picture.get_height() - 1))
 color /= 9.0
 _apply_palette(panel.originals if panel.compare.button_pressed else panel.values)
 retro_layer.visible = retro_visible
 frozen.queue_free()
 tree.paused = was_paused
 busy = false
 swatch.color = color
 if color.s < 0.06:
  status.text = "Neutral color: pick a more colorful area."
  dragging = false
  return false
 selected = nearest_range(color)
 var property: String = ["hue", "saturation", "brightness"][mode.selected]
 drag_key = "ranges/" + selected + "/" + property
 start_value = float(panel.values[drag_key])
 status.text = selected.capitalize() + " · Drag to adjust " + property
 panel.set_value("ranges/enabled", true)
 if dragging: drag_to(latest, false)
 return true

func _apply_palette(source: Dictionary) -> void:
 var changed_sun: bool = source.get("sun_pitch") != panel.originals.get("sun_pitch") or source.get("sun_yaw") != panel.originals.get("sun_yaw")
 panel.emission.apply_palette(source, panel.game.presentation._key_light, changed_sun)

func drag_to(point: Vector2, fine: bool) -> void:
 if selected.is_empty(): return
 var hue := drag_key.ends_with("/hue")
 var change := (point.x - start.x) / (400.0 if hue else 160.0)
 var control: SpinBox = panel.widgets[drag_key]
 panel.set_value(drag_key, clampf(start_value + change * (0.2 if fine else 1.0), control.min_value, control.max_value))
 status.text = "%s · %s %.2f" % [selected.capitalize(), drag_key.get_slice("/", 2).capitalize(), float(panel.values[drag_key])]

static func nearest_range(color: Color) -> String:
 var best := 0
 var distance := 1.0
 for index in Ranges.IDS.size():
  var delta := absf(wrapf(color.h - Ranges.CENTERS[index], -0.5, 0.5))
  if delta < distance:
   best = index
   distance = delta
 return Ranges.IDS[best]

static func displayed_rect(bounds: Rect2, texture_size: Vector2i) -> Rect2:
 var scale := minf(bounds.size.x / texture_size.x, bounds.size.y / texture_size.y)
 var size := Vector2(texture_size) * scale
 return Rect2(bounds.position + (bounds.size - size) * 0.5, size)

func _exit_tree() -> void:
 if is_instance_valid(arm) and arm.button_pressed: Input.set_default_cursor_shape(Input.CURSOR_ARROW)
