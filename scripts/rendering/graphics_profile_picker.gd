extends HBoxContainer
## Shared machine-local quality selector for the game and authoring Lab.
const Options := preload("res://scripts/rendering_options.gd")
const LABELS := ["Desktop", "Laptop · 85%", "Laptop · 75%"]
signal applied(error: Error)
var persist := true
var picker := OptionButton.new()
var status := Label.new()

func _ready() -> void:
 var label := Label.new()
 label.text = "Graphics profile"
 add_child(label)
 picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 for title: String in LABELS: picker.add_item(title)
 picker.add_item("Custom")
 picker.set_item_disabled(LABELS.size(), true)
 add_child(picker)
 status.hide()
 add_child(status)
 picker.item_selected.connect(_choose)
 sync()

func _settings(index: int) -> Dictionary:
 if index == 0: return Options.defaults()
 var settings := Options.LAPTOP.duplicate()
 if index == 2: settings.scale_percent = 75
 return settings

func sync() -> void:
 var settings := Options.quality()
 for i in LABELS.size():
  if settings == _settings(i):
   picker.select(i)
   return
 picker.select(LABELS.size())

func _choose(index: int) -> void:
 if index < 0 or index >= LABELS.size(): return
 var error := Options.update_quality(_settings(index), persist)
 sync()
 status.visible = error != OK
 if error != OK: status.text = error_string(error)
 applied.emit(error)
