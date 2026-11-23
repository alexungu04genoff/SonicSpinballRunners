extends ScrollContainer
## Object browser, precise edits and local recovery/preferences for the Act editor.
const Selection = preload("res://scripts/act_editor/editor_selection.gd")
const Transform = preload("res://scripts/act_editor/selection_transform.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Act = preload("res://scripts/act_editor/act_geometry.gd")
const Recovery = preload("res://scripts/act_editor/editor_recovery.gd")
const PREFERENCES := "user://act_editor_preferences.cfg"
const VIEW_FIELDS := ["snap_mode", "terrain_snap_step", "pivot_mode", "show_transform_handles", "show_launch_previews", "launch_from_spawn", "launch_timing_variants", "launch_contact_fraction", "trajectory_gravity_scale", "show_terrain", "show_gameplay", "show_decor", "show_rings", "show_markers", "selection_filter", "box_selection_mode"]
var editor: Control
var tabs: TabContainer
var tree: Tree
var search: LineEdit
var filter: OptionButton
var box_mode: OptionButton
var summary: Label
var filter_ids: Array[String] = ["all", "terrain", "gameplay", "decor", "ring", "markers", "bumpers"]
var _rebuilding := false
var _chosen: Dictionary = {}
var _tree_fingerprint := ""
var _tree_cache_key := ""
var move_x: SpinBox
var move_y: SpinBox
var angle: SpinBox
var scale_mode: OptionButton
var scale_value: SpinBox
var columns: SpinBox
var rows: SpinBox
var step_x: SpinBox
var step_y: SpinBox
var recovery_list: ItemList
var recovery_entries: Array[Dictionary] = []
var recovery_status: Label
var autosave_enabled: CheckBox
var checkpoint_dialog: ConfirmationDialog
var checkpoint_name: LineEdit
var _preferences := ConfigFile.new()
var _started := false
var _session_id := ""
var _autosave_fingerprint := ""
var _preferences_fingerprint := ""

func _ready() -> void:
 horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 var column := VBoxContainer.new()
 column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 add_child(column)
 tabs = TabContainer.new()
 column.add_child(tabs)
 var browser := _page("Objects")
 search = LineEdit.new()
 search.placeholder_text = "Search names, types or groups"
 search.text_changed.connect(func(_text): refresh())
 browser.add_child(search)
 filter = OptionButton.new()
 for label: String in ["Select: All", "Select: Terrain", "Select: Hardware", "Select: Decor", "Select: Rings", "Select: Markers", "Select: Bumpers"]: filter.add_item(label)
 for item: Dictionary in Objects.definitions():
  filter_ids.append(item.id)
  filter.add_item("Select: " + item.label)
 filter.item_selected.connect(func(index):
  if _blocked(): return
  editor.canvas.selection_filter = filter_ids[index]
  editor.canvas.select_piece(-1)
  editor._refresh()
  editor.canvas.grab_focus())
 browser.add_child(filter)
 box_mode = OptionButton.new()
 for label: String in ["Box: Touching", "Box: Fully enclosed", "Box: Directional"]: box_mode.add_item(label)
 box_mode.tooltip_text = "Directional: drag right to enclose; drag left to select anything touched. Groups remain whole."
 box_mode.item_selected.connect(func(index):
  if _blocked(): return
  editor.canvas.box_selection_mode = index
  editor.canvas.grab_focus())
 browser.add_child(box_mode)
 _button(browser, "Select matching (Ctrl+A)", func(): editor.select_all_content())
 tree = Tree.new()
 tree.columns = 3
 tree.hide_root = true
 tree.select_mode = Tree.SELECT_ROW
 tree.column_titles_visible = true
 tree.set_column_title(0, "Object / group")
 tree.set_column_title(1, "Show")
 tree.set_column_title(2, "Lock")
 for index in [1, 2]:
  tree.set_column_expand(index, false)
  tree.set_column_custom_minimum_width(index, 44)
 tree.custom_minimum_size.y = 340
 tree.item_selected.connect(_choose_row)
 tree.item_edited.connect(_edit_row)
 tree.item_activated.connect(_frame_row)
 browser.add_child(tree)
 summary = _label(browser, "Double-click to frame. Group names are editable.")
 _button(browser, "Reveal all hidden objects", _reveal_objects)
 _button(browser, "Ungroup chosen group", _ungroup_row)
 var precision := _page("Precision")
 _label(precision, "Exact transforms use the selected pivot. Width/height preserve proportions. Values are local pixels.")
 move_x = _number(precision, "Move X", -1000000, 1000000, 0, 0.01)
 move_y = _number(precision, "Move Y", -1000000, 1000000, 0, 0.01)
 angle = _number(precision, "Rotate °", -36000, 36000, 0, 0.1)
 scale_mode = OptionButton.new()
 for label: String in ["Scale percent", "Target width (px)", "Target height (px)"]: scale_mode.add_item(label)
 precision.add_child(scale_mode)
 # Range steps are relative to the minimum. Align it with the displayed step so
 # 100% remains exactly 100%, and integer target dimensions stay exact too.
 scale_value = _number(precision, "Size", 0.01, 1000000, 100, 0.01)
 scale_mode.item_selected.connect(func(index):
  var bounds := Transform.bounds(editor.document, editor.canvas.object_selection())
  scale_value.value = 100 if index == 0 else maxf(0.001, bounds.size[index - 1]))
 _button(precision, "Apply exact transform", _apply_exact)
 var mirrors := HBoxContainer.new()
 precision.add_child(mirrors)
 _button(mirrors, "Mirror H", func(): editor.flip_active(true))
 _button(mirrors, "Mirror V", func(): editor.flip_active(false))
 _button(precision, "Paste in place (Ctrl+Alt+V)", func(): editor.paste_selected(false, true))
 _button(precision, "Repeat duplicate (Ctrl+Shift+D)", func(): editor.duplicate_selected(true))
 _label(precision, "Duplicate grid includes the original at row 1, column 1. All copies are one Undo step; maximum 256 positions.")
 columns = _number(precision, "Columns", 1, 256, 2, 1)
 rows = _number(precision, "Rows", 1, 256, 2, 1)
 step_x = _number(precision, "Column step", -100000, 100000, 100, 0.01)
 step_y = _number(precision, "Row step", -100000, 100000, 100, 0.01)
 _button(precision, "Use selection size + one cell", func():
  var bounds := Transform.bounds(editor.document, editor.canvas.object_selection())
  step_x.value = bounds.size.x + float(editor.document.cell_size)
  step_y.value = bounds.size.y + float(editor.document.cell_size))
 _button(precision, "Create duplicate grid", func():
  for field: SpinBox in [columns, rows, step_x, step_y]: field.apply()
  editor.duplicate_grid(int(columns.value), int(rows.value), Vector2(step_x.value, step_y.value)))
 var recovery := _page("Recovery")
 autosave_enabled = CheckBox.new()
 autosave_enabled.text = "Autosave recovery copy every 30 seconds"
 autosave_enabled.button_pressed = true
 recovery.add_child(autosave_enabled)
 _label(recovery, "Recovery copies never replace your saved Act. Restore opens an unsaved copy. Named checkpoints are retained separately from autosave.")
 recovery_status = _label(recovery, "Recovery ready.")
 _button(recovery, "Named checkpoint (Ctrl+K)", show_checkpoint_dialog)
 _button(recovery, "Save recovery copy now", func(): _autosave(true))
 recovery_list = ItemList.new()
 recovery_list.custom_minimum_size.y = 250
 recovery_list.item_activated.connect(func(_index): _request_restore())
 recovery.add_child(recovery_list)
 _button(recovery, "Restore selected copy", _request_restore)
 _button(recovery, "Refresh recovery list", _refresh_recovery)
 _refresh_recovery()
 var timer := Timer.new()
 timer.wait_time = 30
 timer.timeout.connect(func(): _autosave())
 add_child(timer)
 timer.start()
 var preferences_timer := Timer.new()
 preferences_timer.wait_time = 5
 preferences_timer.timeout.connect(persist_preferences)
 add_child(preferences_timer)
 preferences_timer.start()
 tabs.tab_changed.connect(func(_index): refresh())
 visibility_changed.connect(func():
  if is_visible_in_tree(): refresh())

func _page(title: String) -> VBoxContainer:
 var page := VBoxContainer.new()
 page.name = title
 tabs.add_child(page)
 return page

func _label(parent: Node, text: String) -> Label:
 var label := Label.new()
 label.text = text
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 parent.add_child(label)
 return label

func _button(parent: Node, text: String, action: Callable) -> void:
 var button := Button.new()
 button.text = text
 button.focus_mode = Control.FOCUS_NONE
 button.pressed.connect(func():
  if not _blocked(): action.call())
 parent.add_child(button)

func _number(parent: Node, title: String, minimum: float, maximum: float, value: float, step: float) -> SpinBox:
 var row := HBoxContainer.new()
 parent.add_child(row)
 var label := Label.new()
 label.text = title
 label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(label)
 var field := SpinBox.new()
 field.min_value = minimum
 field.max_value = maximum
 field.step = step
 field.value = value
 field.custom_minimum_size.x = 130
 row.add_child(field)
 return field

func _blocked() -> bool:
 return editor.document == null or editor.composite_preview_active or editor._transform_gesture_active()

func reveal(page: int) -> void:
 tabs.current_tab = page
 get_parent().current_tab = get_index()
 if page == 1: move_x.get_line_edit().grab_focus()

func refresh() -> void:
 if tree == null or editor.document == null: return
 if not is_visible_in_tree() or tabs.current_tab != 0: return
 _rebuilding = true
 filter.select(maxi(0, filter_ids.find(editor.canvas.selection_filter)))
 box_mode.select(editor.canvas.box_selection_mode)
 var fingerprint: String = editor.document.editing_fingerprint()
 var query := search.text.strip_edges().to_lower()
 summary.text = "%d selected. Double-click a row to frame; edit a group name to rename it." % editor.canvas.selection_count()
 var cache_key := fingerprint + ":" + query
 if cache_key == _tree_cache_key:
  _rebuilding = false
  return
 _tree_cache_key = cache_key
 if fingerprint != _tree_fingerprint:
  _chosen = {}
  _tree_fingerprint = fingerprint
 tree.clear()
 var root := tree.create_item()
 var covered := Selection.empty()
 for index in editor.document.editor_groups.size():
  var group: Dictionary = editor.document.editor_groups[index]
  Selection.merge(covered, group.members)
  var group_matches: bool = query.is_empty() or query in String(group.name).to_lower()
  var matched := group_matches
  for kind: String in Selection.COLLECTIONS:
   for member: int in group.members.get(kind, []):
    if query in _object_name(kind, member).to_lower(): matched = true
  if not matched: continue
  var parent := _row(root, group.name, group.members, index)
  for kind: String in Selection.COLLECTIONS:
   for member: int in group.members.get(kind, []):
    var label := _object_name(kind, member)
    if group_matches or query in label.to_lower(): _row(parent, label, Selection.single(kind, member))
 for kind: String in Selection.COLLECTIONS:
  for index in editor.document.get(Selection.COLLECTIONS[kind]).size():
   if covered[kind].has(index): continue
   var label := _object_name(kind, index)
   if query.is_empty() or query in label.to_lower(): _row(root, label, Selection.single(kind, index))
 for marker: String in ["spawn", "goal", "activation"]:
  if editor.canvas.marker_value(marker) != null and (query.is_empty() or query in marker): _row(root, marker.capitalize(), Selection.single("markers", marker))
 _rebuilding = false
 summary.text = "%d selected. Double-click a row to frame; edit a group name to rename it." % editor.canvas.selection_count()

func _object_name(kind: String, index: int) -> String:
 var item: Dictionary = editor.document.get(Selection.COLLECTIONS[kind])[index]
 match kind:
  "terrain": return "Terrain %d · %s" % [index + 1, Shapes.definition_for_placement(item).get("label", item.shape_id)]
  "gameplay": return "%s %d" % [Objects.get_definition(item.type).get("label", item.type), index + 1]
  "decor": return "Decor %d · %s" % [index + 1, item.slot_type]
  "ring": return "Rings %d · %s" % [index + 1, item.get("kind", "line")]
 return "%s %d" % [kind, index + 1]

func _row(parent: TreeItem, title: String, selection: Dictionary, group := -1) -> TreeItem:
 var row := tree.create_item(parent)
 row.set_text(0, title)
 row.set_metadata(0, {"selection": selection.duplicate(true), "group": group})
 row.set_editable(0, group >= 0)
 for column in [1, 2]:
  row.set_cell_mode(column, TreeItem.CELL_MODE_CHECK)
  row.set_editable(column, true)
 row.set_checked(1, not Selection.intersects(selection, editor.document.editor_hidden))
 row.set_checked(2, Selection.intersects(selection, editor.document.editor_locks))
 row.set_tooltip_text(0, "Group names can be edited. Hidden/locked items can be inspected here; unhide/unlock before moving. A partly hidden or locked group stays protected as a whole.")
 if not _chosen.is_empty() and _chosen == row.get_metadata(0): row.select(0)
 return row

func _choose_row() -> void:
 if _rebuilding or _blocked() or tree.get_selected() == null: return
 _chosen = tree.get_selected().get_metadata(0).duplicate(true)
 var selection: Dictionary = _chosen.selection
 # Browsing a hidden/locked record does not silently change its protection.
 var expanded := Selection.expanded(editor.document, selection, false)
 if Selection.intersects(expanded, editor.document.editor_locks) or Selection.intersects(expanded, editor.document.editor_hidden):
  editor.canvas.select_piece(-1)
  editor._refresh()
  summary.text = "Hidden or locked: use Show / Lock to make this item or group editable. Double-click still frames it."
  return
 for kind: String in Selection.KINDS:
  if not expanded.get(kind, []).is_empty(): editor.canvas.set("show_" + ("rings" if kind == "ring" else kind), true)
 editor.canvas.set_object_selection(expanded)
 editor._refresh()

func _edit_row() -> void:
 if _rebuilding: return
 _tree_cache_key = ""
 if _blocked():
  refresh()
  return
 var row := tree.get_edited()
 if row == null: return
 var data: Dictionary = row.get_metadata(0)
 var column := tree.get_edited_column()
 var candidate: Resource = editor.document.copy_document()
 if column == 0:
  var name := row.get_text(0).strip_edges().left(80)
  if data.group < 0 or name.is_empty():
   refresh()
   return
  candidate.editor_groups[data.group].name = name
 else:
  var field: String = "editor_hidden" if column == 1 else "editor_locks"
  var enabled := not row.is_checked(1) if column == 1 else row.is_checked(2)
  _set_members(candidate.get(field), data.selection, enabled)
 editor.canvas.select_piece(-1)
 editor._commit_candidate(candidate)
 refresh()

func _set_members(into: Dictionary, members: Dictionary, enabled: bool) -> void:
 for kind: String in Selection.KINDS:
  if not into.has(kind): into[kind] = []
  for index: Variant in members.get(kind, []):
   if enabled and not into[kind].has(index): into[kind].append(index)
   elif not enabled: into[kind].erase(index)

func _frame_row() -> void:
 if _chosen.is_empty(): return
 var bounds := Transform.bounds(editor.document, _chosen.selection).grow(float(editor.document.cell_size))
 var canvas: Control = editor.canvas
 var available: Vector2 = (canvas.size - Vector2.ONE * canvas.GRID_MARGIN * 2.0).max(Vector2.ONE)
 canvas._cell_pixels = clampf(minf(available.x / bounds.size.x, available.y / bounds.size.y) * float(editor.document.cell_size), 4.0, canvas.MAX_CELL_PIXELS)
 canvas._view_origin = canvas.size * 0.5 - bounds.get_center() * canvas._cell_pixels / float(editor.document.cell_size)
 canvas._view_adjusted = true
 canvas.queue_redraw()

func _reveal_objects() -> void:
 var candidate: Resource = editor.document.copy_document()
 candidate.editor_hidden = {}
 editor._commit_candidate(candidate)
 editor.show_all_layers()

func _ungroup_row() -> void:
 if _chosen.is_empty() or _chosen.group < 0: return
 var candidate: Resource = editor.document.copy_document()
 Selection.ungroup(candidate, _chosen.selection)
 editor.canvas.select_piece(-1)
 editor._commit_candidate(candidate)

func _apply_exact() -> void:
 if _blocked() or editor.canvas.selection_count() == 0: return
 for field: SpinBox in [move_x, move_y, angle, scale_value]: field.apply()
 var candidate: Resource = editor.document.copy_document()
 var selection: Dictionary = editor.canvas.object_selection()
 var pivot: Vector2 = editor.canvas.transform_pivot()
 if angle.value != 0: Transform.apply(candidate, selection, pivot, 1.0, angle.value)
 var factor := scale_value.value / 100.0
 if scale_mode.selected != 0:
  var bounds := Transform.bounds(candidate, selection)
  var axis := scale_mode.selected - 1
  var size: float = bounds.size[axis]
  if size <= 0.000001:
   editor._set_status("This selection has no extent on that axis.")
   return
  factor = scale_value.value / size
  var previous_factor := 1.0
  var previous_size := size
  var reached := false
  # Some hardware scales its length while retaining a fixed collision radius.
  # Solve against actual bounds instead of silently missing the requested size.
  for _iteration in 8:
   if not is_finite(factor) or factor <= 0.0: break
   var trial: Resource = candidate.copy_document()
   if not is_equal_approx(factor, 1.0): Transform.apply(trial, selection, pivot, factor, 0.0)
   var measured: float = Transform.bounds(trial, selection).size[axis]
   if absf(measured - scale_value.value) <= 0.001:
    candidate = trial
    reached = true
    break
   if is_equal_approx(factor, previous_factor) or is_equal_approx(measured, previous_size): break
   var next_factor := factor + (scale_value.value - measured) * (factor - previous_factor) / (measured - previous_size)
   previous_factor = factor
   previous_size = measured
   factor = next_factor
  if not reached:
   editor._set_status("Could not reach that dimension with uniform scaling. Choose another size or use scale percent.")
   return
 elif not is_equal_approx(factor, 1.0): Transform.apply(candidate, selection, pivot, factor, 0.0)
 if not is_finite(factor) or factor <= 0.0: return
 var offset := Vector2(move_x.value, move_y.value)
 if not offset.is_zero_approx(): Transform.translate(candidate, selection, offset)
 if editor._commit_candidate(candidate):
  if angle.value == 0 and is_equal_approx(factor, 1.0): editor._track_duplicate_movement(selection, offset)
  editor._set_status("Exact transform applied as one edit. No snapping or boundary adjustment was added.")
 editor.canvas.grab_focus()

func modal_open() -> bool:
 return checkpoint_dialog != null and checkpoint_dialog.visible

func show_checkpoint_dialog() -> void:
 if _blocked(): return
 if checkpoint_dialog == null:
  checkpoint_dialog = ConfirmationDialog.new()
  checkpoint_dialog.title = "Named recovery checkpoint"
  checkpoint_name = LineEdit.new()
  checkpoint_name.max_length = 80
  checkpoint_name.placeholder_text = "Before rebuilding the upper loop"
  checkpoint_dialog.add_child(checkpoint_name)
  checkpoint_dialog.confirmed.connect(_save_checkpoint)
  add_child(checkpoint_dialog)
 checkpoint_name.text = ""
 checkpoint_dialog.popup_centered(Vector2i(400, 110))
 checkpoint_name.grab_focus()

func _save_checkpoint() -> void:
 var label := checkpoint_name.text.strip_edges()
 if label.is_empty():
  editor._set_status("Enter a checkpoint name.")
  return
 var result := Recovery.save_copy(editor.document, editor.current_path, _session_id, label, false)
 recovery_status.text = "Checkpoint saved: " + label if result.error.is_empty() else result.error
 editor._set_status(recovery_status.text)
 _refresh_recovery()

func _autosave(force := false) -> void:
 if not _started or _blocked() or (not force and not autosave_enabled.button_pressed): return
 if not force and editor._modal_open(): return
 if not force and not editor.is_dirty(): return
 var fingerprint: String = editor.document.editing_fingerprint()
 if not force and fingerprint == _autosave_fingerprint: return
 var result := Recovery.save_copy(editor.document, editor.current_path, _session_id, "Autosave", true)
 if result.error.is_empty():
  _autosave_fingerprint = fingerprint
  recovery_status.text = "Recovery copy saved. Your authored file is unchanged."
  _refresh_recovery()
 else: recovery_status.text = result.error

func save_before_switch(recovering := false) -> void:
 if autosave_enabled.button_pressed and editor.is_dirty():
  if recovering:
   # Never overwrite the autosave the user just chose to recover.
   var result := Recovery.save_copy(editor.document, editor.current_path, _session_id, "Before recovery", false)
   if not result.error.is_empty(): recovery_status.text = result.error
   _refresh_recovery()
  else: _autosave(true)
 persist_preferences()

func _refresh_recovery() -> void:
 recovery_entries = Recovery.entries()
 recovery_list.clear()
 for entry: Dictionary in recovery_entries:
  var stamp := Time.get_datetime_string_from_unix_time(int(entry.time)).replace("T", " ")
  var source: String = entry.source.get_file() if not entry.source.is_empty() else "Unsaved Act"
  var index := recovery_list.add_item("%s · %s\n%s UTC" % [entry.label, source, stamp])
  recovery_list.set_item_tooltip(index, entry.source + "\n" + entry.path)

func _request_restore() -> void:
 if recovery_list.get_selected_items().is_empty(): return
 var entry: Dictionary = recovery_entries[recovery_list.get_selected_items()[0]]
 editor.request_action("recover:" + entry.path)

func restore_copy(path: String) -> void:
 var loaded := Act.load_document(path)
 if loaded.document == null:
  editor._show_error("Recovery copy could not be opened: " + loaded.error)
  return
 remember_view()
 editor._clear_composite_preview()
 editor.document = loaded.document
 editor._title_edit_recorded = false
 editor._thesis_edit_recorded = false
 editor.review_panel.reset_checklist()
 editor.current_path = ""
 editor.saved_fingerprint = ""
 editor.selected_bank_id = ""
 editor._duplicate_selection.clear()
 editor._last_duplicate_offset = Vector2.ZERO
 editor.undo_stack.clear()
 editor.redo_stack.clear()
 editor.canvas.set_document(editor.document)
 changed_document()
 editor._refresh()
 editor.canvas.call_deferred("fit_view")
 editor._set_status("Recovered as an unsaved copy. Save As chooses its destination; the original file and checkpoint are unchanged.")

func changed_document() -> void:
 _session_id = Objects.new_id()
 _autosave_fingerprint = ""
 _tree_fingerprint = ""
 _tree_cache_key = ""
 _chosen = {}
 if _started: call_deferred("apply_saved_view")

func start_session() -> void:
 _preferences.load(PREFERENCES)
 for field: String in VIEW_FIELDS:
  var value: Variant = _preferences.get_value("editor", field, editor.canvas.get(field))
  if typeof(value) == typeof(editor.canvas.get(field)):
   if typeof(value) == TYPE_FLOAT and not is_finite(value): continue
   editor.canvas.set(field, value)
 editor.canvas.snap_mode = clampi(editor.canvas.snap_mode, 0, 2)
 editor.canvas.pivot_mode = clampi(editor.canvas.pivot_mode, 0, 2)
 editor.canvas.box_selection_mode = clampi(editor.canvas.box_selection_mode, 0, 2)
 if editor.canvas.terrain_snap_step not in [1.0, 0.5, 0.25]: editor.canvas.terrain_snap_step = 1.0
 if editor.canvas.selection_filter not in filter_ids: editor.canvas.selection_filter = "all"
 editor.canvas.launch_contact_fraction = clampf(editor.canvas.launch_contact_fraction, 0.1, 1.0)
 editor.canvas.trajectory_gravity_scale = clampf(editor.canvas.trajectory_gravity_scale, 0.01, 4.0)
 editor.half_size_steps.set_pressed_no_signal(bool(_preferences.get_value("editor", "half_size_steps", true)))
 autosave_enabled.set_pressed_no_signal(bool(_preferences.get_value("editor", "autosave", true)))
 var last_path := str(_preferences.get_value("editor", "last_path", ""))
 if not last_path.is_empty() and FileAccess.file_exists(last_path): editor.load_from(last_path)
 _started = true
 call_deferred("apply_saved_view")
 editor._refresh()
 if not recovery_entries.is_empty(): recovery_status.text = "%d recovery copies available. Restore one to inspect it safely." % recovery_entries.size()

func _view_key() -> String:
 return (editor.current_path.replace("\\", "/").to_lower() if not editor.current_path.is_empty() else "unsaved").sha256_text()

func remember_view() -> void:
 if not _started or not is_instance_valid(editor.canvas) or editor.document == null: return
 _preferences.set_value("views", _view_key(), {"origin": editor.canvas._view_origin, "zoom": editor.canvas._cell_pixels, "cursor": editor.canvas.cursor_pivot})

func apply_saved_view() -> void:
 if not _started: return
 var view: Variant = _preferences.get_value("views", _view_key(), {})
 if not view is Dictionary: return
 var origin: Variant = view.get("origin")
 var zoom: Variant = view.get("zoom")
 if origin is Vector2 and origin.is_finite() and typeof(zoom) in [TYPE_FLOAT, TYPE_INT] and is_finite(zoom):
  editor.canvas._view_origin = origin
  editor.canvas._cell_pixels = clampf(float(zoom), 4, editor.canvas.MAX_CELL_PIXELS)
  editor.canvas._view_adjusted = true
 var cursor: Variant = view.get("cursor")
 if cursor is Vector2 and cursor.is_finite(): editor.canvas.cursor_pivot = cursor
 editor.canvas.queue_redraw()

func persist_preferences() -> void:
 if not _started or not is_instance_valid(editor.canvas) or editor.document == null: return
 remember_view()
 for field: String in VIEW_FIELDS: _preferences.set_value("editor", field, editor.canvas.get(field))
 _preferences.set_value("editor", "half_size_steps", editor.half_size_steps.button_pressed)
 _preferences.set_value("editor", "autosave", autosave_enabled.button_pressed)
 _preferences.set_value("editor", "last_path", editor.current_path)
 var fingerprint := _preferences.encode_to_text().sha256_text()
 if fingerprint == _preferences_fingerprint: return
 if _preferences.save(PREFERENCES) == OK: _preferences_fingerprint = fingerprint
