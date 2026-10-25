extends CanvasLayer
## Native-resolution development controls, outside the filtered world viewport.
const Filter := preload("res://scripts/retro/retro_filter.gd")
var filter: Filter
var selector: OptionButton
var toast: Label
var _remaining := 0.0

func install(adapter: Filter, debug_stack: Node) -> void:
 filter = adapter
 layer = 25
 process_mode = Node.PROCESS_MODE_ALWAYS
 selector = OptionButton.new()
 selector.name = "RetroFilterPreset"
 selector.tooltip_text = "World only. F4 cycles presets. Tune data/retro_settings.tres; settings are experimental."
 for label: String in Filter.NAMES:
  selector.add_item("F4  Retro: " + label)
 debug_stack.add_child(selector)
 debug_stack.move_child(selector, 2)
 selector.item_selected.connect(func(index: int):
  filter.set_preset(index)
  selector.release_focus()
 )
 toast = Label.new()
 toast.name = "RetroPresetToast"
 toast.position = Vector2(470, 24)
 toast.size = Vector2(340, 38)
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

func _unhandled_key_input(event: InputEvent) -> void:
 if not is_instance_valid(filter):
  return
 if event is InputEventKey and event.pressed and not event.echo and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
  if event.physical_keycode == KEY_F4 or event.keycode == KEY_F4:
   filter.cycle()
   get_viewport().set_input_as_handled()

func _changed(index: int) -> void:
 selector.select(index)
 toast.text = "RETRO  ·  %s  ·  F4" % Filter.NAMES[index]
 toast.show()
 _remaining = 2.0

func _process(delta: float) -> void:
 if _remaining > 0.0:
  _remaining -= delta
  if _remaining <= 0.0:
   toast.hide()

func _exit_tree() -> void:
 # This control was installed in the host debug panel, outside our own subtree.
 if is_instance_valid(selector):
  selector.queue_free()
