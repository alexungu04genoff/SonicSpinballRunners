extends RefCounted
## Keep the idle display consistent without rounding values or text being edited.
static func install(number: SpinBox) -> void:
 var edit := number.get_line_edit()
 edit.focus_mode = Control.FOCUS_ALL
 number.select_all_on_focus = true
 var owner := weakref(number) as WeakRef
 var refresh := func():
  # Theme switches and Lab teardown can free the control before this idle call.
  var spin := owner.get_ref() as SpinBox
  if spin == null: return
  var line := spin.get_line_edit()
  if line.is_editing(): return
  var text := "%.2f" % spin.value
  if not spin.prefix.is_empty(): text = spin.prefix + " " + text
  if not spin.suffix.is_empty(): text += " " + spin.suffix
  if line.text != text: line.text = text
 number.draw.connect(refresh, CONNECT_DEFERRED)
 edit.editing_toggled.connect(func(editing: bool):
  if not editing: refresh.call_deferred()
 )
 edit.text_submitted.connect(func(_text: String): edit.release_focus.call_deferred())
 refresh.call_deferred()
