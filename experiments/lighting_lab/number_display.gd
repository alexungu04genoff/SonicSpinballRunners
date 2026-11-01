extends RefCounted
## Keep the idle display consistent without rounding values or text being edited.
static func install(number: SpinBox) -> void:
 var edit := number.get_line_edit()
 edit.focus_mode = Control.FOCUS_ALL
 number.select_all_on_focus = true
 var refresh := func():
  if not is_instance_valid(number) or not is_instance_valid(edit) or edit.is_editing(): return
  var text := "%.2f" % number.value
  if not number.prefix.is_empty(): text = number.prefix + " " + text
  if not number.suffix.is_empty(): text += " " + number.suffix
  if edit.text != text: edit.text = text
 number.draw.connect(func(): refresh.call_deferred())
 edit.editing_toggled.connect(func(editing: bool):
  if not editing: refresh.call_deferred()
 )
 edit.text_submitted.connect(func(_text: String): edit.release_focus.call_deferred())
 refresh.call_deferred()
