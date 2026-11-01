extends VBoxContainer
## Drafts survive Act changes. Only explicit Save/Delete writes project data.
const Registry := preload("res://scripts/atmosphere/variants.gd")
var registry := Registry.new()
var panel: CanvasLayer
var contexts := {}
var theme_id := ""
var context := {}
var selector: OptionButton
var title: LineEdit
var enabled: CheckBox
var weight: SpinBox
var status: Label
var syncing := false

func install(owner_panel: CanvasLayer, parent: Node) -> void:
 panel = owner_panel
 selector = OptionButton.new()
 selector.item_selected.connect(func(index: int):
  capture()
  context.selected = selector.get_item_metadata(index)
  load_selected()
 )
 parent.add_child(selector)
 var row := HBoxContainer.new()
 add_child(row)
 panel._button(row, "New", func(): create(false))
 panel._button(row, "Duplicate", func(): create(true))
 panel._button(row, "Delete", remove_selected)
 title = LineEdit.new()
 title.placeholder_text = "Variant name (edit to rename)"
 title.max_length = 64
 title.text_changed.connect(func(_text: String): capture())
 add_child(title)
 row = HBoxContainer.new()
 add_child(row)
 enabled = CheckBox.new()
 enabled.text = "Enabled"
 enabled.toggled.connect(func(_value: bool): capture())
 row.add_child(enabled)
 weight = SpinBox.new()
 weight.prefix = "Weight "
 preload("res://experiments/lighting_lab/number_display.gd").install(weight)
 weight.custom_minimum_size.x = 170
 weight.max_value = 1000000
 weight.step = 0.1
 weight.value_changed.connect(func(_value: float): capture())
 row.add_child(weight)
 row = HBoxContainer.new()
 add_child(row)
 panel._button(row, "Save Variant", save_variant)
 panel._button(row, "Revert", revert)
 panel._button(row, "Playtest args", func():
  DisplayServer.clipboard_set("-Atmosphere " + theme_id + ":" + context.selected)
  panel.message.text = "Copied Prototype playtest override. Save the variant before launching."
 )
 status = Label.new()
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 add_child(status)
 var note := Label.new()
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 note.text = "Edit Default or duplicate it for another look, then Save Variant. Show original atmosphere compares with the authored theme. Lab draft saves stay user-local."
 add_child(note)

func bind_theme() -> void:
 theme_id = panel.game.theme_id
 if not contexts.has(theme_id):
  var records := registry.read(theme_id)
  contexts[theme_id] = {"records": records, "revision": registry.revision(theme_id), "selected": "draft", "drafts": {}}
 context = contexts[theme_id]
 load_selected()

func selected_record() -> Dictionary:
 if context.selected == "draft": return {}
 if context.drafts.has(context.selected): return context.drafts[context.selected]
 for record: Dictionary in context.records:
  if record.id == context.selected: return record
 return Registry.baseline()

func capture() -> void:
 if syncing or context.is_empty(): return
 if context.selected != "draft":
  var record := selected_record().duplicate(true)
  record.name = "Default" if record.id == "default" else title.text
  record.enabled = enabled.button_pressed
  record.weight = weight.value
  record.values = {}
  for key: String in panel.values:
   if panel.values[key] != panel.originals.get(key): record.values[key] = panel.values[key]
  context.drafts[record.id] = record
 refresh()

func refresh() -> void:
 syncing = true
 selector.clear()
 selector.add_item("Lab draft (user-local)")
 selector.set_item_metadata(0, "draft")
 var records: Array = context.records.duplicate(true)
 for id: String in context.drafts:
  var found := false
  for i in records.size():
   if records[i].id == id:
    records[i] = context.drafts[id]
    found = true
  if not found: records.append(context.drafts[id])
 for record: Dictionary in records:
  var modified := true
  for saved: Dictionary in context.records:
   if saved == record: modified = false
  selector.add_item(record.name + (" *" if modified else ""))
  selector.set_item_metadata(selector.item_count - 1, record.id)
  if record.id == context.selected: selector.select(selector.item_count - 1)
 var record := selected_record()
 title.editable = context.selected not in ["default", "draft"]
 enabled.disabled = context.selected == "draft"
 weight.editable = context.selected != "draft"
 if not record.is_empty():
  if title.text != record.name: title.text = record.name
  enabled.set_pressed_no_signal(record.enabled)
  weight.set_value_no_signal(record.weight)
 status.text = "User-local draft; Duplicate to promote explicitly." if record.is_empty() else "ID: %s · Approx. chance: %.2f%%\n%s" % [record.id, Registry.chance(records, record.id) * 100.0, "Default appearance is editable; its name and entry are fixed." if record.id == "default" else "* marks unsaved changes. Rename with the name field."]
 panel.sync_fog_controls()
 panel.save_button.text = "Save scenery" if panel._scenery_tab() else ("Save lab draft" if context.selected == "draft" else "Save Variant")
 syncing = false

func load_selected() -> void:
 syncing = true
 panel.values = panel.originals.duplicate(true)
 var stored: Dictionary = panel.drafts.get(panel.preset_key, panel.saved.get_value(panel.preset_key, "values", {})) if context.selected == "draft" else selected_record().values
 for key: String in stored:
  if panel.values.has(key): panel.values[key] = stored[key]
 panel.compare.set_pressed_no_signal(false)
 panel._sync_widgets()
 panel.apply_values()
 syncing = false
 refresh()
 panel.message.text = "User-local Lab draft." if context.selected == "draft" else "Production variant · " + selected_record().name + " · Save Variant writes project data."

func create(duplicate_current: bool) -> void:
 capture()
 var id := "variant_" + str(Time.get_ticks_usec())
 var values := {}
 if duplicate_current:
  for key: String in panel.values:
   if panel.values[key] != panel.originals.get(key): values[key] = panel.values[key]
 context.drafts[id] = {"id": id, "name": "New variant " + str(context.drafts.size() + 1), "enabled": true, "weight": 1.0, "values": values}
 context.selected = id
 load_selected()
 title.grab_focus()
 title.select_all()

func save_variant() -> void:
 if context.selected == "draft":
  panel.message.text = "Duplicate the Lab draft to create a production variant."
  return
 capture()
 var records: Array[Dictionary] = []
 var selected := selected_record().duplicate(true)
 selected.name = selected.name.strip_edges()
 for record: Dictionary in context.records:
  if record.id != selected.id: records.append(record)
 records.append(selected)
 if not registry.save(theme_id, records, context.revision):
  panel.message.text = registry.error
  return
 context.records = registry.read(theme_id)
 context.revision = registry.revision(theme_id)
 context.drafts.erase(selected.id)
 refresh()
 panel.message.text = "Saved production variant: " + selected.name

func revert() -> void:
 context.drafts.erase(context.selected)
 context.records = registry.read(theme_id)
 context.revision = registry.revision(theme_id)
 if context.selected != "draft" and not context.records.any(func(record: Dictionary): return record.id == context.selected): context.selected = "default"
 load_selected()

func remove_selected() -> void:
 if context.selected in ["default", "draft"]:
  panel.message.text = "Default and Lab draft cannot be deleted."
  return
 var records: Array[Dictionary] = []
 for record: Dictionary in context.records:
  if record.id != context.selected: records.append(record)
 if not registry.save(theme_id, records, context.revision):
  panel.message.text = registry.error
  return
 context.drafts.erase(context.selected)
 context.selected = "default"
 revert()
