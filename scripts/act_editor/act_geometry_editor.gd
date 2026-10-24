extends Control
## Standalone authoring UI. It has no runtime table or gameplay dependencies.
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Canvas = preload("res://scripts/act_editor/geometry_canvas.gd")
const PaletteItem = preload("res://scripts/act_editor/terrain_palette_item.gd")
const EXAMPLE_PATH := "res://data/acts/curve_garden.tres"
const HISTORY_LIMIT := 100

var document: Resource
var canvas: Control
var current_path := ""
var saved_fingerprint := ""
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var palette_buttons: Dictionary = {}
var buttons: Dictionary = {}
var save_dialog: FileDialog
var load_dialog: FileDialog
var unsaved_dialog: ConfirmationDialog
var error_dialog: AcceptDialog
var title_field: LineEdit
var cell_size_field: SpinBox
var file_label: Label
var detail_label: Label
var status_label: Label
var mode_label: Label
var search_field: LineEdit
var family_filter: OptionButton
var palette_list: VBoxContainer
var pending_action := ""
var _refreshing := false
var _title_edit_recorded := false
var _previous_auto_quit := true
var grid_label: Label

func _ready() -> void:
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_build_ui()
	_build_dialogs()
	new_document()
	_set_status("Choose a terrain stamp. Every placement snaps to the grid; overlaps are welcome.")

func _exit_tree() -> void:
	get_tree().auto_accept_quit = _previous_auto_quit

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		request_action("quit")

func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 14
	ui_theme.set_color("font_color", "Label", Color("dcebf2"))
	ui_theme.set_color("font_color", "Button", Color("e6f3fa"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("22374a") if state == "normal" else Color("31556a")
		if state == "disabled":
			style.bg_color = Color("172633")
		style.set_corner_radius_all(5)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		ui_theme.set_stylebox(state, "Button", style)
	theme = ui_theme
	var background := ColorRect.new()
	background.color = Color("0b1420")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var brand := Label.new()
	brand.text = "ACT / GEOMETRY"
	brand.add_theme_font_size_override("font_size", 23)
	brand.add_theme_color_override("font_color", Color("70e5d5"))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	_button(header, "new", "New Act", func(): request_action("new"), "Ctrl+N")
	_button(header, "load", "Load", func(): request_action("load"), "Ctrl+O")
	_button(header, "save", "Save", _save_current, "Ctrl+S")
	_button(header, "save_as", "Save As", _open_save_dialog, "Ctrl+Shift+S")
	_button(header, "example", "Example", func(): request_action("example"), "Open the example as a new editable copy")
	_button(header, "quit", "Close", func(): request_action("quit"), "Close with an unsaved-changes check")
	file_label = Label.new()
	file_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	file_label.add_theme_color_override("font_color", Color("9cb3c6"))
	column.add_child(file_label)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	column.add_child(tools)
	_button(tools, "select", "Select / Move", _select_mode, "Esc • click a shape, then drag • Alt-click cycles overlaps")
	_button(tools, "rotate", "Rotate +90°", rotate_active, "R • clockwise quarter-turns only")
	_button(tools, "flip_h", "Flip Horizontal", func(): flip_active(true), "H • mirror across the current screen frame")
	_button(tools, "flip_v", "Flip Vertical", func(): flip_active(false), "V • mirror across the current screen frame")
	_button(tools, "delete", "Delete", delete_selected, "Delete / Backspace")
	_button(tools, "undo", "Undo", undo, "Ctrl+Z • up to 100 edits")
	_button(tools, "redo", "Redo", redo, "Ctrl+Y / Ctrl+Shift+Z")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)
	_button(tools, "fit", "Fit Grid", func(): canvas.fit_view(), "Mouse wheel zooms • middle-drag pans")
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	var palette := VBoxContainer.new()
	palette.custom_minimum_size.x = 264
	palette.add_theme_constant_override("separation", 8)
	body.add_child(palette)
	var palette_heading := Label.new()
	palette_heading.text = "TERRAIN LIBRARY  /  52 stamps"
	palette_heading.add_theme_color_override("font_color", Color("70e5d5"))
	palette.add_child(palette_heading)
	search_field = LineEdit.new()
	search_field.placeholder_text = "Find a shape or size…"
	search_field.text_changed.connect(func(_text): _filter_palette())
	palette.add_child(search_field)
	family_filter = OptionButton.new()
	family_filter.add_item("All terrain families")
	family_filter.item_selected.connect(func(_index): _filter_palette())
	palette.add_child(family_filter)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette.add_child(scroll)
	palette_list = VBoxContainer.new()
	palette_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_list.add_theme_constant_override("separation", 5)
	scroll.add_child(palette_list)
	var families: Array[String] = []
	for definition: Dictionary in Shapes.definitions():
		if not families.has(definition.family):
			families.append(definition.family)
			family_filter.add_item(definition.family)
		var item := PaletteItem.new()
		item.configure(definition)
		item.pressed.connect(choose_shape.bind(definition.id))
		palette_list.add_child(item)
		palette_buttons[definition.id] = item
	var workspace := VBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 8)
	body.add_child(workspace)
	var settings := HBoxContainer.new()
	workspace.add_child(settings)
	var title_label := Label.new()
	title_label.text = "Act name"
	settings.add_child(title_label)
	title_field = LineEdit.new()
	title_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_field.focus_entered.connect(func(): _title_edit_recorded = false)
	title_field.text_changed.connect(_edit_title)
	title_field.text_submitted.connect(func(_text): _commit_title(); title_field.release_focus())
	title_field.focus_exited.connect(func(): _commit_title(); _title_edit_recorded = false)
	settings.add_child(title_field)
	grid_label = Label.new()
	settings.add_child(grid_label)
	cell_size_field = SpinBox.new()
	cell_size_field.min_value = 0.01
	cell_size_field.max_value = 512
	cell_size_field.allow_greater = true
	cell_size_field.allow_lesser = true
	cell_size_field.step = 0.01
	cell_size_field.suffix = "px"
	cell_size_field.custom_minimum_size.x = 110
	cell_size_field.value_changed.connect(_change_cell_size)
	settings.add_child(cell_size_field)
	canvas = Canvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(canvas)
	canvas.placement_requested.connect(add_placement)
	canvas.move_requested.connect(move_placement)
	canvas.selection_changed.connect(func(_index): _refresh())
	canvas.status_changed.connect(_set_status)
	mode_label = Label.new()
	mode_label.add_theme_color_override("font_color", Color("70e5d5"))
	workspace.add_child(mode_label)
	detail_label = Label.new()
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.add_theme_color_override("font_color", Color("b5c8d6"))
	workspace.add_child(detail_label)
	status_label = Label.new()
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(status_label)
	var help := Label.new()
	help.text = "R rotate   H / V flip   Delete remove   Ctrl+Z undo   Esc select   Alt-click overlap   Wheel zoom   Middle-drag pan"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color("8aa5ba"))
	column.add_child(help)

func _button(parent: Node, id: String, label: String, action: Callable, hint: String) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func():
		# Toolbar buttons do not take keyboard focus. Commit numeric drafts before
		# an edit refreshes the fields, then give editing shortcuts to the canvas.
		cell_size_field.apply()
		_commit_title()
		if id in ["select", "rotate", "flip_h", "flip_v", "delete", "undo", "redo", "fit"]:
			canvas.grab_focus()
		action.call())
	parent.add_child(button)
	buttons[id] = button

func _build_dialogs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://acts"))
	save_dialog = FileDialog.new()
	save_dialog.title = "Save Act geometry"
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	load_dialog = FileDialog.new()
	load_dialog.title = "Load Act geometry"
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	for dialog in [save_dialog, load_dialog]:
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.filters = PackedStringArray(["*.tres ; Act geometry Resource"])
		dialog.current_dir = ProjectSettings.globalize_path("user://acts")
		dialog.size = Vector2i(850, 560)
		dialog.canceled.connect(func(): pending_action = "")
		add_child(dialog)
	save_dialog.file_selected.connect(_save_selected)
	load_dialog.file_selected.connect(func(path): load_from(path))
	unsaved_dialog = ConfirmationDialog.new()
	unsaved_dialog.title = "Save your Act before continuing?"
	unsaved_dialog.dialog_text = "This Act has unsaved changes. Save them, discard them, or cancel to keep editing."
	unsaved_dialog.ok_button_text = "Save"
	unsaved_dialog.add_button("Discard", false, "discard")
	unsaved_dialog.confirmed.connect(_save_current)
	unsaved_dialog.custom_action.connect(func(action):
		if action == "discard":
			unsaved_dialog.hide()
			_continue_action())
	unsaved_dialog.canceled.connect(func(): pending_action = "")
	add_child(unsaved_dialog)
	error_dialog = AcceptDialog.new()
	error_dialog.title = "Act geometry"
	add_child(error_dialog)

func _filter_palette() -> void:
	var query := search_field.text.strip_edges().to_lower().replace("×", "x")
	var family := family_filter.get_item_text(family_filter.selected)
	for id: String in palette_buttons:
		var definition: Dictionary = Shapes.get_definition(id)
		var searchable: String = (definition.label + " " + definition.family).to_lower().replace("×", "x")
		palette_buttons[id].visible = (family_filter.selected == 0 or definition.family == family) and (query.is_empty() or searchable.contains(query))

func choose_shape(id: String) -> void:
	var definition: Dictionary = Shapes.get_definition(id)
	if definition.is_empty():
		return
	canvas.grab_focus()
	canvas.set_brush({"shape_id": id, "base_size": definition.size, "anchor": Vector2i.ZERO,
		"quarter_turns": 0, "flip_h": false, "flip_v": false})
	_set_status("Click the grid to place %s. Keep clicking to repeat; Esc returns to selection." % definition.label)
	_refresh()

func _select_mode() -> void:
	canvas.grab_focus()
	canvas.select_piece(-1)
	_set_status("Click visible terrain to select it. Drag to move; Alt-click cycles overlapping pieces.")
	_refresh()

func add_placement(placement: Dictionary) -> void:
	var candidate: Resource = document.copy_document()
	candidate.placements.append(placement.duplicate(true))
	if not candidate.validation_errors().is_empty():
		_set_status("Placement is outside the Act or has an invalid shape transform.")
		return
	_record_edit()
	document.placements.append(placement.duplicate(true))
	_set_status("Placed %s. %d independent terrain pieces." % [Shapes.get_definition(placement.shape_id).label, document.placements.size()])
	_refresh()

func move_placement(index: int, anchor: Vector2i) -> void:
	if index < 0 or index >= document.placements.size():
		return
	var placement: Dictionary = document.placements[index]
	anchor = _clamp_anchor(placement, anchor)
	if anchor == placement.anchor:
		return
	_record_edit()
	placement.anchor = anchor
	_refresh()

func _clamp_anchor(placement: Dictionary, anchor: Vector2i) -> Vector2i:
	var frame: Vector2i = Shapes.transformed_size(placement)
	return Vector2i(clampi(anchor.x, 0, document.grid_size.x - frame.x), clampi(anchor.y, 0, document.grid_size.y - frame.y))

func rotate_active() -> void:
	_transform_active("rotation")

func flip_active(horizontal: bool) -> void:
	_transform_active("flip_h" if horizontal else "flip_v")

func _transform_active(operation: String) -> void:
	canvas.grab_focus()
	canvas.cancel_gesture()
	var placement: Dictionary
	if not canvas.brush.is_empty():
		placement = canvas.brush.duplicate(true)
	elif canvas.selected_index >= 0:
		placement = document.placements[canvas.selected_index].duplicate(true)
	else:
		return
	if operation == "rotation":
		placement.quarter_turns = (placement.quarter_turns + 1) % 4
		# Keep the visible operation a clockwise turn after previous screen-axis flips.
		var previous_h: bool = placement.flip_h
		placement.flip_h = placement.flip_v
		placement.flip_v = previous_h
	else:
		placement[operation] = not placement[operation]
	var frame: Vector2i = Shapes.transformed_size(placement)
	if frame.x > document.grid_size.x or frame.y > document.grid_size.y:
		_set_status("This rotated footprint does not fit inside the Act.")
		return
	placement.anchor = _clamp_anchor(placement, placement.anchor)
	if not canvas.brush.is_empty():
		canvas.set_brush(placement)
	else:
		_record_edit()
		document.placements[canvas.selected_index] = placement
	_refresh()

func delete_selected() -> void:
	if canvas.selected_index < 0:
		return
	canvas.cancel_gesture()
	_record_edit()
	document.placements.remove_at(canvas.selected_index)
	canvas.select_piece(-1)
	_refresh()

func _snapshot() -> Dictionary:
	return {"document": document.copy_document(), "selected": canvas.selected_index}

func _record_edit() -> void:
	undo_stack.append(_snapshot())
	if undo_stack.size() > HISTORY_LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()

func undo() -> void:
	canvas.cancel_gesture()
	if undo_stack.is_empty():
		return
	redo_stack.append(_snapshot())
	_restore_snapshot(undo_stack.pop_back())
	_set_status("Undid one edit.")

func redo() -> void:
	canvas.cancel_gesture()
	if redo_stack.is_empty():
		return
	undo_stack.append(_snapshot())
	_restore_snapshot(redo_stack.pop_back())
	_set_status("Redid one edit.")

func _restore_snapshot(snapshot: Dictionary) -> void:
	var active_brush: Dictionary = canvas.brush.duplicate(true)
	document = snapshot.document
	_title_edit_recorded = false
	canvas.set_document(document, false)
	if not active_brush.is_empty():
		canvas.set_brush(active_brush)
	else:
		canvas.select_piece(snapshot.selected if snapshot.selected < document.placements.size() else -1)
	_refresh()

func is_dirty() -> bool:
	return document != null and (document.fingerprint() != saved_fingerprint or title_field.text != document.title)

func new_document() -> void:
	document = ActData.new()
	_title_edit_recorded = false
	current_path = ""
	undo_stack.clear()
	redo_stack.clear()
	saved_fingerprint = document.fingerprint()
	canvas.set_document(document)
	_refresh()
	canvas.call_deferred("fit_view")
	_set_status("New Act: 12 columns × 12 rows. Choose a terrain stamp to begin.")

func save_to(path: String) -> bool:
	cell_size_field.apply()
	_commit_title()
	if path.get_extension().to_lower() != "tres":
		path += ".tres"
	var result: Error = document.save_document(path)
	if result != OK:
		_show_error("Could not save this Act (%s). Your edits are still open.\n%s" % [error_string(result), path])
		return false
	current_path = path
	saved_fingerprint = document.fingerprint()
	_set_status("Saved %d terrain pieces to %s" % [document.placements.size(), path])
	_refresh()
	return true

func load_from(path: String) -> bool:
	var result: Dictionary = ActData.load_document(path)
	if result.document == null:
		_show_error("Could not load this Act. Your current edits are still open.\n" + result.error)
		return false
	document = result.document
	_title_edit_recorded = false
	current_path = path
	saved_fingerprint = document.fingerprint()
	undo_stack.clear()
	redo_stack.clear()
	canvas.set_document(document)
	_refresh()
	canvas.call_deferred("fit_view")
	_set_status("Loaded %d terrain pieces. Continue editing or choose a new stamp." % document.placements.size())
	return true

func request_action(action: String) -> void:
	if _modal_open():
		return
	cell_size_field.apply()
	_commit_title()
	canvas.cancel_gesture()
	pending_action = action
	if is_dirty():
		unsaved_dialog.popup_centered(Vector2i(540, 150))
	else:
		_continue_action()

func _continue_action() -> void:
	var action := pending_action
	pending_action = ""
	match action:
		"new": new_document()
		"load": load_dialog.popup_centered()
		"quit": get_tree().quit()
		"example":
			if load_from(EXAMPLE_PATH):
				current_path = ""
				saved_fingerprint = ""
				_refresh()
				_set_status("Example opened as a copy. Save As chooses your own persistent file.")

func _save_current() -> void:
	if current_path.is_empty():
		_open_save_dialog()
	elif save_to(current_path):
		_continue_action()
	else:
		pending_action = ""

func _open_save_dialog() -> void:
	cell_size_field.apply()
	_commit_title()
	canvas.cancel_gesture()
	if not current_path.is_empty():
		save_dialog.current_path = ProjectSettings.globalize_path(current_path)
	else:
		save_dialog.current_file = document.title.validate_filename() + ".tres"
	save_dialog.popup_centered()

func _save_selected(path: String) -> void:
	if save_to(path):
		_continue_action()
	else:
		pending_action = ""

func _commit_title() -> void:
	if _refreshing or document == null:
		return
	var value := title_field.text.strip_edges()
	if value.is_empty():
		value = "Untitled Act"
	if value != document.title:
		if not _title_edit_recorded:
			_record_edit()
		document.title = value
	_refreshing = true
	title_field.text = value
	_refreshing = false
	_refresh()

func _edit_title(value: String) -> void:
	if _refreshing or document == null:
		return
	if value == document.title:
		return
	if not _title_edit_recorded:
		_record_edit()
		_title_edit_recorded = true
	document.title = value
	_refresh_file_state()
	buttons.undo.disabled = undo_stack.is_empty()
	buttons.redo.disabled = redo_stack.is_empty()

func _change_cell_size(value: float) -> void:
	if _refreshing or document == null or is_equal_approx(value, document.cell_size):
		return
	if not is_finite(value) or value <= 0.0:
		cell_size_field.set_value_no_signal(document.cell_size)
		_set_status("Cell size must be greater than zero.")
		return
	_record_edit()
	document.cell_size = value
	_refresh()

func _refresh() -> void:
	if document == null:
		return
	_refreshing = true
	title_field.text = document.title
	cell_size_field.set_value_no_signal(document.cell_size)
	grid_label.text = "   %d × %d cells    Cell size" % [document.grid_size.x, document.grid_size.y]
	_refresh_file_state()
	buttons.undo.disabled = undo_stack.is_empty()
	buttons.redo.disabled = redo_stack.is_empty()
	buttons.delete.disabled = canvas.selected_index < 0
	var active: Dictionary = canvas.brush if not canvas.brush.is_empty() else (document.placements[canvas.selected_index] if canvas.selected_index >= 0 else {})
	for key in ["rotate", "flip_h", "flip_v"]:
		buttons[key].disabled = active.is_empty()
	if active.is_empty():
		mode_label.text = "SELECT / MOVE  ·  %d pieces" % document.placements.size()
		detail_label.text = "Click terrain to select it. Arrow keys move a selected piece by one cell."
	else:
		var definition: Dictionary = Shapes.get_definition(active.shape_id)
		var frame: Vector2i = Shapes.transformed_size(active)
		mode_label.text = ("STAMP  ·  " if not canvas.brush.is_empty() else "SELECTED  ·  ") + definition.label
		detail_label.text = "Frame %d × %d cells  ·  %d°  ·  H %s / V %s%s" % [frame.x, frame.y, active.quarter_turns * 90, "on" if active.flip_h else "off", "on" if active.flip_v else "off", "  ·  Anchor (%d, %d)" % [active.anchor.x, active.anchor.y] if canvas.brush.is_empty() else "  ·  Click to place; Esc to select"]
	canvas.queue_redraw()
	_refreshing = false

func _refresh_file_state() -> void:
	var dirty := is_dirty()
	var state := "● Unsaved changes" if dirty else ("Saved" if not current_path.is_empty() else "New document")
	file_label.text = state + "  |  " + (current_path if not current_path.is_empty() else "New Act — choose Save to create a file")
	file_label.tooltip_text = file_label.text
	DisplayServer.window_set_title("%s%s — Act Geometry Editor" % ["* " if dirty else "", document.title])

func _set_status(message: String) -> void:
	status_label.text = message
	status_label.tooltip_text = message

func _show_error(message: String) -> void:
	error_dialog.dialog_text = message
	error_dialog.popup_centered(Vector2i(680, 180))
	_set_status(message.get_slice("\n", 0))

func _modal_open() -> bool:
	return save_dialog.visible or load_dialog.visible or unsaved_dialog.visible or error_dialog.visible

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _modal_open():
		return
	var focus := get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit or focus is TextEdit
	var command: bool = event.ctrl_pressed or event.meta_pressed
	if command:
		match event.keycode:
			KEY_S:
				if event.shift_pressed: _open_save_dialog()
				else: _save_current()
			KEY_O: request_action("load")
			KEY_N: request_action("new")
			KEY_Z:
				if typing: return
				if event.shift_pressed: redo()
				else: undo()
			KEY_Y:
				if typing: return
				redo()
			_: return
	elif typing:
		return
	else:
		match event.keycode:
			KEY_ESCAPE: _select_mode()
			KEY_R: rotate_active()
			KEY_H: flip_active(true)
			KEY_V: flip_active(false)
			KEY_DELETE, KEY_BACKSPACE: delete_selected()
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				if canvas.selected_index >= 0:
					var direction: Vector2i = {KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN}[event.keycode]
					move_placement(canvas.selected_index, document.placements[canvas.selected_index].anchor + direction)
			_: return
	get_viewport().set_input_as_handled()
