extends Control
## Standalone authoring UI. It has no runtime table or gameplay dependencies.
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Canvas = preload("res://scripts/act_editor/geometry_canvas.gd")
const PaletteItem = preload("res://scripts/act_editor/terrain_palette_item.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const GameplayPaletteItem = preload("res://scripts/act_editor/gameplay_palette_item.gd")
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
var connector_summary: Label
var palette_tabs: TabBar
var gameplay_buttons: Dictionary = {}
var gameplay_list: VBoxContainer
var terrain_scroll: ScrollContainer
var palette_heading: Label
var angle_field: LineEdit
var handedness_field: OptionButton
var _angle_display_text := ""
var marker_buttons: Dictionary = {}
var marker_list: VBoxContainer
var marker_summary: Label

func _ready() -> void:
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_build_ui()
	_build_dialogs()
	new_document()
	_set_status("Choose Terrain or Gameplay. Gameplay anchors snap to the grid; hold Alt for free placement.")

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
	brand.text = "ACT / EDITOR"
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
	_button(tools, "select", "Select / Move", _select_mode, "Esc • click terrain or an object, then drag • Alt-click cycles overlaps")
	_button(tools, "rotate", "Rotate +90°", rotate_active, "R • terrain +90°; gameplay +15° (Shift+R −15°)")
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
	palette_tabs = TabBar.new()
	palette_tabs.add_tab("Terrain")
	palette_tabs.add_tab("Gameplay")
	palette_tabs.add_tab("Act Markers")
	palette_tabs.tab_changed.connect(_change_palette_tab)
	palette.add_child(palette_tabs)
	palette_heading = Label.new()
	palette_heading.text = "TERRAIN LIBRARY  /  %d stamps" % Shapes.definitions().size()
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
	terrain_scroll = scroll
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
	gameplay_list = VBoxContainer.new()
	gameplay_list.add_theme_constant_override("separation", 8)
	gameplay_list.visible = false
	palette.add_child(gameplay_list)
	for definition: Dictionary in Objects.definitions():
		var item := GameplayPaletteItem.new()
		item.configure(definition)
		item.pressed.connect(choose_gameplay.bind(definition.id))
		gameplay_list.add_child(item)
		gameplay_buttons[definition.id] = item
	var object_hint := Label.new()
	object_hint.text = "Snap to grid intersections.\nHold Alt for exact placement.\n\nCyan: bumpers / sling\nYellow: flippers\nCrosshair: anchor / pivot"
	object_hint.add_theme_color_override("font_color", Color("9cb3c6"))
	object_hint.add_theme_font_size_override("font_size", 13)
	gameplay_list.add_child(object_hint)
	marker_list = VBoxContainer.new()
	marker_list.add_theme_constant_override("separation", 8)
	marker_list.visible = false
	palette.add_child(marker_list)
	_button(marker_list, "marker_entry", "Entry Connector", func(): choose_connector("entry"), "Physical connection on the bottom border; width determines compatibility")
	_button(marker_list, "marker_exit", "Exit Connector", func(): choose_connector("exit"), "Physical connection on the top border; width determines compatibility")
	_button(marker_list, "marker_activation", "Activation Trigger", func(): choose_marker("activation"), "Place a horizontal guide. Future upward crossing changes the active checkpoint.")
	_button(marker_list, "marker_spawn", "Spawn Point", func(): choose_marker("spawn"), "Place the future launch / respawn point. Hold Alt for an exact local position.")
	for kind: String in ["entry", "exit", "activation", "spawn"]:
		marker_buttons[kind] = buttons["marker_" + kind]
	marker_summary = Label.new()
	marker_summary.add_theme_color_override("font_color", Color("9bdedb"))
	marker_summary.add_theme_font_size_override("font_size", 13)
	marker_list.add_child(marker_summary)
	var marker_hint := Label.new()
	marker_hint.text = "Entry / Exit: physical connection\nActivation: upward checkpoint line\nSpawn: launch / respawn point\n\nThe red gutter is system-owned.\nIt adds no terrain cells.\n\nMarkers may remain unset.\nNo gameplay runs in this editor."
	marker_hint.add_theme_color_override("font_color", Color("9cb3c6"))
	marker_hint.add_theme_font_size_override("font_size", 13)
	marker_list.add_child(marker_hint)
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
	var connectors := HBoxContainer.new()
	connectors.add_theme_constant_override("separation", 8)
	workspace.add_child(connectors)
	_button(connectors, "entry", "Entry (bottom)", func(): choose_connector("entry"), "Drag contiguous cells along the bottom border to create or replace Entry")
	_button(connectors, "exit", "Exit (top)", func(): choose_connector("exit"), "Drag contiguous cells along the top border to create or replace Exit")
	connector_summary = Label.new()
	connector_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connector_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	connector_summary.add_theme_font_size_override("font_size", 13)
	connector_summary.add_theme_color_override("font_color", Color("76edab"))
	connectors.add_child(connector_summary)
	canvas = Canvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(canvas)
	canvas.placement_requested.connect(add_placement)
	canvas.move_requested.connect(move_placement)
	canvas.selection_changed.connect(func(_index): _refresh())
	canvas.connector_requested.connect(set_connector)
	canvas.connector_selection_changed.connect(func(_kind): _refresh())
	canvas.gameplay_placement_requested.connect(add_gameplay_placement)
	canvas.gameplay_move_requested.connect(move_gameplay_placement)
	canvas.gameplay_selection_changed.connect(func(_index): _refresh())
	canvas.marker_requested.connect(set_lifecycle_marker)
	canvas.marker_selection_changed.connect(func(_kind): _refresh())
	canvas.status_changed.connect(_set_status)
	var object_properties := HBoxContainer.new()
	object_properties.add_theme_constant_override("separation", 8)
	workspace.add_child(object_properties)
	mode_label = Label.new()
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mode_label.add_theme_color_override("font_color", Color("70e5d5"))
	object_properties.add_child(mode_label)
	var angle_label := Label.new()
	angle_label.text = "Angle °"
	object_properties.add_child(angle_label)
	angle_field = LineEdit.new()
	angle_field.custom_minimum_size.x = 120
	angle_field.tooltip_text = "Gameplay resting orientation in degrees. Enter commits the exact number. R / Shift+R changes it by 15°."
	angle_field.text_submitted.connect(func(_text): _commit_gameplay_angle(); canvas.grab_focus())
	angle_field.focus_exited.connect(_commit_gameplay_angle)
	object_properties.add_child(angle_field)
	handedness_field = OptionButton.new()
	handedness_field.add_item("Left flipper")
	handedness_field.add_item("Right flipper")
	handedness_field.tooltip_text = "Change handedness and swing direction; preserve the authored pivot and resting angle."
	handedness_field.item_selected.connect(_change_handedness)
	object_properties.add_child(handedness_field)
	_button(object_properties, "duplicate", "Duplicate", duplicate_selected, "Ctrl+D • duplicate the selected gameplay object, offset by one cell")
	detail_label = Label.new()
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.add_theme_color_override("font_color", Color("b5c8d6"))
	workspace.add_child(detail_label)
	status_label = Label.new()
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(status_label)
	var help := Label.new()
	help.text = "R rotate   Shift+R object −15°   H / V terrain flip   Ctrl+D duplicate object   Alt free move / cycle overlaps   Wheel zoom   Middle-drag pan"
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
		_commit_gameplay_angle()
		_commit_title()
		if id in ["select", "rotate", "flip_h", "flip_v", "delete", "duplicate", "undo", "redo", "fit"]:
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

func _change_palette_tab(index: int) -> void:
	var terrain := index == 0
	search_field.visible = terrain
	family_filter.visible = terrain
	terrain_scroll.visible = terrain
	gameplay_list.visible = index == 1
	marker_list.visible = index == 2
	palette_heading.text = ["TERRAIN LIBRARY  /  %d stamps" % Shapes.definitions().size(), "GAMEPLAY  /  4 objects", "ACT MARKERS  /  4 tools"][index]
	_select_mode()

func choose_gameplay(id: String) -> void:
	var placement: Dictionary = Objects.make_placement(id)
	if placement.is_empty():
		return
	canvas.grab_focus()
	canvas.set_gameplay_brush(placement)
	_set_status("Place %s. SNAP ON · hold Alt for FREE MOVE. R / Shift+R adjusts the angle." % Objects.get_definition(id).label)
	_refresh()

func _select_mode() -> void:
	canvas.grab_focus()
	canvas.select_piece(-1)
	_set_status("Click terrain, gameplay or Act markers. Drag to move; Alt frees object / marker position. Alt-click cycles overlaps.")
	_refresh()

func choose_connector(kind: String) -> void:
	if kind not in ["entry", "exit"]:
		return
	canvas.grab_focus()
	canvas.set_connector_tool(kind)
	_set_status("Drag contiguous cells along the %s border to create or replace %s. Esc cancels." % ["bottom" if kind == "entry" else "top", kind.capitalize()])
	_refresh()

func choose_marker(kind: String) -> void:
	if kind not in ["activation", "spawn"]:
		return
	canvas.grab_focus()
	canvas.set_marker_tool(kind)
	_set_status("Click inside the Act to place %s. Snap is on; hold Alt for fine position. The red gutter is outside the Act." % ("the Activation Trigger" if kind == "activation" else "the Spawn Point"))
	_refresh()

func set_lifecycle_marker(kind: String, value: Variant) -> void:
	if kind not in ["activation", "spawn"]:
		return
	var field := "activation_y" if kind == "activation" else "spawn_position"
	var candidate: Resource = document.copy_document()
	candidate.set(field, value)
	var errors: PackedStringArray = candidate.validation_errors()
	if not errors.is_empty():
		_set_status(errors[0] + " Marker unchanged.")
		return
	if document.get(field) != value:
		_record_edit()
		document.set(field, value)
	canvas.select_marker(kind if value != null else "")
	_set_status(("Activation Trigger" if kind == "activation" else "Spawn Point") + (" removed. Incomplete drafts can still be saved." if value == null else " set. Drag to move; Delete removes; Alt allows fine position."))
	_refresh()

func set_connector(kind: String, start_x: int, width: int) -> void:
	if kind not in ["entry", "exit"]:
		return
	var candidate: Resource = document.copy_document()
	candidate.set(kind + "_start_x", start_x)
	candidate.set(kind + "_width", width)
	if not candidate.validation_errors().is_empty():
		_set_status("A connector must use contiguous integer cells inside its boundary.")
		return
	var previous: Dictionary = document.get_connector(kind)
	if previous.start_x != start_x or previous.width != width:
		_record_edit()
		document.set(kind + "_start_x", start_x)
		document.set(kind + "_width", width)
	if width > 0:
		canvas.select_connector(kind)
		_set_status("%s set. Drag its middle to move, drag either endpoint to resize, or press Delete." % kind.capitalize())
	else:
		canvas.select_piece(-1)
		_set_status("%s removed. Drafts can be saved without connectors." % kind.capitalize())
	_refresh()

func _connector_description(kind: String) -> String:
	var connector: Dictionary = document.get_connector(kind)
	if connector.width == 0:
		return kind.capitalize() + ": unset"
	return "%s: width %d · cells %d–%d" % [kind.capitalize(), connector.width, connector.start_x, connector.start_x + connector.width - 1]

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

func add_gameplay_placement(placement: Dictionary) -> void:
	var candidate: Resource = document.copy_document()
	candidate.gameplay_objects.append(placement.duplicate(true))
	if not candidate.validation_errors().is_empty():
		_set_status("Gameplay objects require a known type, finite local position and finite angle.")
		return
	_record_edit()
	document.gameplay_objects.append(placement.duplicate(true))
	_set_status("Placed %s at %s px. %d gameplay objects." % [Objects.get_definition(placement.type).label, placement.position, document.gameplay_objects.size()])
	_refresh()

func move_gameplay_placement(index: int, position: Vector2) -> void:
	if index < 0 or index >= document.gameplay_objects.size() or not position.is_finite():
		return
	var placement: Dictionary = document.gameplay_objects[index]
	if placement.position == position:
		return
	_record_edit()
	# Snapping belongs to the gesture. Stored positions are never normalized.
	placement.position = position
	_refresh()

func _active_gameplay() -> Dictionary:
	if not canvas.gameplay_brush.is_empty():
		return canvas.gameplay_brush
	if canvas.selected_gameplay_index >= 0 and canvas.selected_gameplay_index < document.gameplay_objects.size():
		return document.gameplay_objects[canvas.selected_gameplay_index]
	return {}

func set_gameplay_angle(value: float) -> void:
	var placement := _active_gameplay()
	if placement.is_empty() or not is_finite(value) or placement.rotation_degrees == value:
		return
	canvas.cancel_gesture()
	if canvas.gameplay_brush.is_empty():
		_record_edit()
	placement.rotation_degrees = value
	_refresh()

func _commit_gameplay_angle() -> void:
	if _refreshing or angle_field == null or not angle_field.editable:
		return
	var text_value := angle_field.text.strip_edges()
	# A displayed decimal may be shorter than its underlying binary float. Merely
	# focusing the field or using another toolbar action must never round that value.
	if text_value == _angle_display_text:
		return
	if not text_value.is_valid_float() or not is_finite(text_value.to_float()):
		_set_status("Enter a finite angle in degrees.")
		angle_field.text = _angle_display_text
		return
	set_gameplay_angle(text_value.to_float())
	_refresh()

func _change_handedness(index: int) -> void:
	if _refreshing:
		return
	var placement := _active_gameplay()
	if placement.is_empty() or placement.type not in ["left_flipper", "right_flipper"]:
		return
	var type := "left_flipper" if index == 0 else "right_flipper"
	if placement.type == type:
		return
	canvas.cancel_gesture()
	if canvas.gameplay_brush.is_empty():
		_record_edit()
	placement.type = type
	_refresh()

func duplicate_selected() -> void:
	var index: int = canvas.selected_gameplay_index
	if index < 0 or index >= document.gameplay_objects.size():
		return
	canvas.cancel_gesture()
	var placement: Dictionary = document.gameplay_objects[index].duplicate(true)
	placement.position += Vector2.ONE * float(document.cell_size)
	add_gameplay_placement(placement)
	canvas.select_gameplay(document.gameplay_objects.size() - 1)
	_refresh()

func rotate_active() -> void:
	if not _active_gameplay().is_empty():
		rotate_gameplay(15.0)
	else:
		_transform_active("rotation")

func rotate_gameplay(degrees: float) -> void:
	var placement := _active_gameplay()
	if not placement.is_empty():
		set_gameplay_angle(float(placement.rotation_degrees) + degrees)

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
	if not canvas.selected_marker.is_empty():
		set_lifecycle_marker(canvas.selected_marker, null)
		return
	if not canvas.selected_connector.is_empty():
		set_connector(canvas.selected_connector, 0, 0)
		return
	if canvas.selected_gameplay_index >= 0:
		canvas.cancel_gesture()
		_record_edit()
		document.gameplay_objects.remove_at(canvas.selected_gameplay_index)
		canvas.select_gameplay(-1)
		_refresh()
		return
	if canvas.selected_index < 0:
		return
	canvas.cancel_gesture()
	_record_edit()
	document.placements.remove_at(canvas.selected_index)
	canvas.select_piece(-1)
	_refresh()

func _snapshot() -> Dictionary:
	return {"document": document.copy_document(), "selected": canvas.selected_index,
		"connector": canvas.selected_connector, "gameplay": canvas.selected_gameplay_index,
		"marker": canvas.selected_marker}

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
	var active_gameplay_brush: Dictionary = canvas.gameplay_brush.duplicate(true)
	document = snapshot.document
	_title_edit_recorded = false
	canvas.set_document(document, false)
	if not active_brush.is_empty():
		canvas.set_brush(active_brush)
	elif not active_gameplay_brush.is_empty():
		canvas.set_gameplay_brush(active_gameplay_brush)
	elif not snapshot.get("connector", "").is_empty() and document.get_connector(snapshot.connector).width > 0:
		canvas.select_connector(snapshot.connector)
	elif not snapshot.get("marker", "").is_empty():
		canvas.select_marker(snapshot.marker)
	elif snapshot.get("gameplay", -1) >= 0:
		canvas.select_gameplay(snapshot.gameplay)
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
	_commit_gameplay_angle()
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
	_set_status("Saved %d terrain pieces and %d gameplay objects to %s" % [document.placements.size(), document.gameplay_objects.size(), path])
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
	_set_status("Loaded %d terrain pieces and %d gameplay objects. Continue editing or choose a palette item." % [document.placements.size(), document.gameplay_objects.size()])
	return true

func request_action(action: String) -> void:
	if _modal_open():
		return
	_commit_gameplay_angle()
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
	_commit_gameplay_angle()
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
	var candidate: Resource = document.copy_document()
	candidate.cell_size = value
	var errors: PackedStringArray = candidate.validation_errors()
	if not errors.is_empty():
		cell_size_field.set_value_no_signal(document.cell_size)
		_set_status("Cell size unchanged: " + errors[0])
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
	buttons.delete.disabled = canvas.selected_index < 0 and canvas.selected_gameplay_index < 0 and canvas.selected_connector.is_empty() and canvas.selected_marker.is_empty()
	buttons.duplicate.disabled = canvas.selected_gameplay_index < 0
	connector_summary.text = _connector_description("entry") + "   |   " + _connector_description("exit")
	connector_summary.tooltip_text = connector_summary.text + "\nCompatibility compares width only; horizontal positions may differ."
	marker_summary.text = "Activation: " + ("unset" if document.activation_y == null else "Y %s px" % var_to_str(document.activation_y))
	marker_summary.text += "\nSpawn: " + ("unset" if document.spawn_position == null else "%s px" % document.spawn_position)
	var active: Dictionary = canvas.brush if not canvas.brush.is_empty() else (document.placements[canvas.selected_index] if canvas.selected_index >= 0 else {})
	var gameplay := _active_gameplay()
	for key in ["rotate", "flip_h", "flip_v"]:
		buttons[key].disabled = active.is_empty()
	buttons.rotate.disabled = active.is_empty() and gameplay.is_empty()
	buttons.rotate.text = "Rotate +15°" if not gameplay.is_empty() else "Rotate +90°"
	angle_field.editable = not gameplay.is_empty()
	_angle_display_text = var_to_str(gameplay.rotation_degrees) if not gameplay.is_empty() else ""
	angle_field.text = _angle_display_text
	angle_field.placeholder_text = "Gameplay only"
	handedness_field.disabled = gameplay.is_empty() or gameplay.type not in ["left_flipper", "right_flipper"]
	handedness_field.select(1 if not gameplay.is_empty() and gameplay.type == "right_flipper" else 0)
	if not canvas.marker_tool.is_empty():
		mode_label.text = "PLACE  ·  " + ("Activation Trigger" if canvas.marker_tool == "activation" else "Spawn Point")
		detail_label.text = "Inside terrain bounds only · grid snap / Alt free position · red gutter is system-owned"
	elif not canvas.selected_marker.is_empty():
		mode_label.text = "SELECTED  ·  " + ("Activation Trigger" if canvas.selected_marker == "activation" else "Spawn Point")
		detail_label.text = ("Y %s px · Full Act width · Future upward crossing activates the checkpoint" % var_to_str(document.activation_y) if canvas.selected_marker == "activation" else "Position %s px · Future launch / respawn point" % document.spawn_position) + " · Delete removes"
	elif not canvas.connector_tool.is_empty():
		mode_label.text = "AUTHOR %s  ·  %s border only" % [canvas.connector_tool.to_upper(), "bottom" if canvas.connector_tool == "entry" else "top"]
		detail_label.text = "Click or drag across boundary cells to set the span. Green spans are authoring markers; terrain remains unchanged."
	elif not canvas.selected_connector.is_empty():
		mode_label.text = "SELECTED CONNECTOR  ·  " + _connector_description(canvas.selected_connector)
		var next_width: int = document.exit_width
		detail_label.text = "Drag middle to move · endpoint handles resize · Delete removes · Left/Right nudge" + (" · Next entry width: %d" % next_width if next_width > 0 else "")
	elif not gameplay.is_empty():
		var definition: Dictionary = Objects.get_definition(gameplay.type)
		mode_label.text = ("PLACE  ·  " if not canvas.gameplay_brush.is_empty() else "SELECTED  ·  ") + definition.label
		var anchor_label := "Pivot" if gameplay.type in ["left_flipper", "right_flipper"] else "Anchor"
		detail_label.text = "%s %s px · %s° · Alt: free position · Arrows: 1 cell / Alt: 1 px" % [anchor_label, gameplay.position, var_to_str(gameplay.rotation_degrees)]
	elif active.is_empty():
		mode_label.text = "SELECT / MOVE"
		detail_label.text = "%d terrain pieces · %d gameplay objects · Click to select; Alt-click cycles overlaps." % [document.placements.size(), document.gameplay_objects.size()]
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
			KEY_D:
				if typing: return
				duplicate_selected()
			_: return
	elif typing:
		return
	else:
		match event.keycode:
			KEY_ESCAPE: _select_mode()
			KEY_R:
				if event.shift_pressed and not _active_gameplay().is_empty(): rotate_gameplay(-15.0)
				else: rotate_active()
			KEY_H: flip_active(true)
			KEY_V: flip_active(false)
			KEY_DELETE, KEY_BACKSPACE: delete_selected()
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				if canvas.selected_index >= 0:
					var direction: Vector2i = {KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN}[event.keycode]
					move_placement(canvas.selected_index, document.placements[canvas.selected_index].anchor + direction)
			_: return
	get_viewport().set_input_as_handled()
