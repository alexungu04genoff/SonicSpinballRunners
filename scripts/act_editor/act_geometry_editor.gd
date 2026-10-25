extends Control
## Standalone authoring UI. It has no runtime table or gameplay dependencies.
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Canvas = preload("res://scripts/act_editor/geometry_canvas.gd")
const PaletteItem = preload("res://scripts/act_editor/terrain_palette_item.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const GameplayPaletteItem = preload("res://scripts/act_editor/gameplay_palette_item.gd")
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const Composite = preload("res://scripts/act_editor/composite_terrain.gd")
const Decor = preload("res://scripts/act_editor/decor_slots.gd")
const Themes = preload("res://scripts/themes/theme_registry.gd")
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
var ring_spacing_field: SpinBox
var composite_bar: HBoxContainer
var composite_strength: SpinBox
var composite_preserve_corners: CheckBox
var composite_angle: SpinBox
var composite_only_joins: CheckBox
var composite_allow_reshaping: CheckBox
var composite_whole_contour: CheckBox
var _composite_area_limited := false
var terrain_snap_field: OptionButton
var terrain_scale_field: OptionButton
var _composite_error := ""
var _composite_join_indices := PackedInt32Array()
var _composite_protected_indices := PackedInt32Array()
var composite_hint: Label
var composite_preview_active := false
var composite_preview: Dictionary = {}
var _composite_sources: Array[int] = []
var _composite_base: Dictionary = {}
var _composite_fingerprint := ""
var _composite_operation := ""
var decor_list: VBoxContainer
var decor_scroll: ScrollContainer
var decor_type_field: OptionButton
var decor_hint_field: OptionButton
var decor_theme_field: OptionButton
var decor_variant_field: OptionButton
var _decor_preview_skin: RefCounted
var decor_scale_field: SpinBox
var decor_position_fields: Array[LineEdit] = []
var decor_visible_field: CheckBox
var decor_snap_field: CheckBox
var decor_info: Label
var _decor_position_text: Array[String] = ["", ""]

func _ready() -> void:
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_build_ui()
	_build_dialogs()
	new_document()
	_set_status("Choose Terrain or Gameplay. Terrain supports half-cell snapping and half size; hold Alt for free placement.")

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
	palette_tabs.clip_tabs = false
	palette_tabs.add_theme_font_size_override("font_size", 12)
	palette_tabs.add_tab("Terrain")
	palette_tabs.add_tab("Gameplay")
	palette_tabs.add_tab("Act Markers")
	palette_tabs.add_tab("Decor")
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
	_button(gameplay_list, "rings", "◎  Rings — click / drag", choose_rings, "Click for one ring; drag in any direction for a trail. Alt frees endpoints.")
	var ring_settings := HBoxContainer.new()
	gameplay_list.add_child(ring_settings)
	var ring_label := Label.new()
	ring_label.text = "Spacing"
	ring_settings.add_child(ring_label)
	ring_spacing_field = SpinBox.new()
	ring_spacing_field.min_value = 0.1
	ring_spacing_field.max_value = 4.0
	ring_spacing_field.allow_greater = true
	ring_spacing_field.allow_lesser = true
	ring_spacing_field.step = 0.05
	ring_spacing_field.value = Rings.DEFAULT_SPACING_CELLS
	ring_spacing_field.suffix = "cells"
	ring_spacing_field.tooltip_text = "Maximum center spacing. Equal intervals fit both endpoints. Changes the selected trail, or the next trail."
	ring_spacing_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ring_spacing_field.value_changed.connect(_change_ring_spacing)
	ring_settings.add_child(ring_spacing_field)
	var object_hint := Label.new()
	object_hint.text = "Snap to grid intersections.\nHold Alt for exact placement.\n\nCyan: bumpers / sling\nYellow: flippers / ring trails\nCrosshair: anchor / pivot"
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
	_build_decor_palette(palette)
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
	terrain_snap_field = OptionButton.new()
	terrain_snap_field.add_item("Snap: 1 cell")
	terrain_snap_field.add_item("Snap: ½ cell")
	terrain_snap_field.tooltip_text = "Terrain placement and movement grid. Hold Alt for free positioning."
	terrain_snap_field.item_selected.connect(func(index):
		canvas.terrain_snap_step = 0.5 if index == 1 else 1.0
		canvas.queue_redraw()
		canvas.grab_focus())
	connectors.add_child(terrain_snap_field)
	terrain_scale_field = OptionButton.new()
	terrain_scale_field.add_item("Size: 1×")
	terrain_scale_field.add_item("Size: 0.5×")
	terrain_scale_field.tooltip_text = "Uniform terrain size about the frame's top-left. Applies to the brush or one selected piece."
	terrain_scale_field.item_selected.connect(func(index):
		if not _refreshing: _transform_active("half_size" if index == 1 else "full_size"))
	connectors.add_child(terrain_scale_field)
	composite_bar = HBoxContainer.new()
	composite_bar.add_theme_constant_override("separation", 6)
	workspace.add_child(composite_bar)
	_button(composite_bar, "merge", "Merge", func(): preview_composite("merge"), "Ctrl-click filled terrain to select two or more pieces, then preview their union")
	_button(composite_bar, "smooth", "Smooth", func(): preview_composite("smooth"), "Preview conservative corner smoothing on one filled terrain piece or composite")
	_button(composite_bar, "merge_smooth", "Merge + Smooth", func(): preview_composite("merge_smooth"), "Union selected filled terrain, then smooth the resulting outline")
	_button(composite_bar, "composite_apply", "Apply", apply_composite, "Replace the selected sources in one undo step")
	_button(composite_bar, "composite_cancel", "Cancel", cancel_composite_preview, "Discard the preview; original terrain stays unchanged")
	_button(composite_bar, "composite_clear_pins", "Clear pins", _clear_composite_pins, "Release all manually protected corners in this preview")
	var sculpt_settings := HBoxContainer.new()
	sculpt_settings.add_theme_constant_override("separation", 8)
	workspace.add_child(sculpt_settings)
	var strength_label := Label.new()
	strength_label.text = "Strength"
	sculpt_settings.add_child(strength_label)
	composite_strength = SpinBox.new()
	composite_strength.min_value = 0
	composite_strength.max_value = Composite.MAX_STRENGTH * 100.0
	composite_strength.step = 25
	composite_strength.value = 25
	composite_strength.suffix = "%"
	composite_strength.custom_minimum_size.x = 90
	composite_strength.tooltip_text = "Smoothing strength. Preview changes never add history entries."
	composite_strength.value_changed.connect(func(_value):
		if composite_preview_active and _composite_operation != "merge": _rebuild_composite_preview())
	sculpt_settings.add_child(composite_strength)
	composite_preserve_corners = CheckBox.new()
	composite_preserve_corners.text = "Preserve angle"
	composite_preserve_corners.tooltip_text = "Keep corners matching the chosen angle within 1°. Uses the smaller angle between edges, for either convex corners or concave notches."
	composite_preserve_corners.focus_mode = Control.FOCUS_NONE
	composite_preserve_corners.toggled.connect(func(_pressed):
		if composite_preview_active and _composite_operation != "merge": _rebuild_composite_preview()
		else: _refresh())
	sculpt_settings.add_child(composite_preserve_corners)
	composite_angle = SpinBox.new()
	composite_angle.min_value = 1
	composite_angle.max_value = 179
	composite_angle.step = 1
	composite_angle.value = 90
	composite_angle.suffix = "°"
	composite_angle.custom_minimum_size.x = 90
	composite_angle.tooltip_text = "Protected corner angle. 45° protects a right triangle's acute tips; 90° protects square corners. Tolerance: ±1°."
	composite_angle.value_changed.connect(func(_value):
		if composite_preview_active and _composite_operation != "merge": _rebuild_composite_preview())
	sculpt_settings.add_child(composite_angle)
	composite_only_joins = CheckBox.new()
	composite_only_joins.text = "Only smooth joins"
	composite_only_joins.tooltip_text = "Merge + Smooth only: round boundary transitions between selected pieces. Keep original corners and tips exact. Existing composites do not retain old source seams."
	composite_only_joins.focus_mode = Control.FOCUS_NONE
	composite_only_joins.toggled.connect(func(_pressed):
		if composite_preview_active and _composite_operation == "merge_smooth": _rebuild_composite_preview()
		else: _refresh())
	sculpt_settings.add_child(composite_only_joins)
	composite_allow_reshaping = CheckBox.new()
	composite_allow_reshaping.text = "Allow reshaping"
	composite_allow_reshaping.tooltip_text = "Allow smoothing to change up to 25% of the shape's area instead of 5%. All collision-validity checks still apply."
	composite_allow_reshaping.focus_mode = Control.FOCUS_NONE
	composite_allow_reshaping.toggled.connect(func(_pressed):
		if composite_preview_active and _composite_operation != "merge": _rebuild_composite_preview())
	sculpt_settings.add_child(composite_allow_reshaping)
	composite_whole_contour = CheckBox.new()
	composite_whole_contour.text = "Whole contour"
	composite_whole_contour.tooltip_text = "Round across short outline segments, including previously smoothed corners. Pins remain fixed. Stops at the allowed area change."
	composite_whole_contour.focus_mode = Control.FOCUS_NONE
	composite_whole_contour.toggled.connect(func(pressed):
		if pressed: composite_only_joins.button_pressed = false
		if composite_preview_active: _rebuild_composite_preview()
		else: _refresh())
	sculpt_settings.add_child(composite_whole_contour)
	composite_hint = Label.new()
	composite_hint.add_theme_font_size_override("font_size", 12)
	composite_hint.add_theme_color_override("font_color", Color("9cb3c6"))
	composite_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	workspace.add_child(composite_hint)
	canvas = Canvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(canvas)
	canvas.placement_requested.connect(add_placement)
	canvas.move_requested.connect(move_placement)
	canvas.selection_changed.connect(func(_index): _refresh())
	canvas.terrain_selection_changed.connect(func(_indices): _refresh())
	canvas.composite_preview_cancel_requested.connect(cancel_composite_preview)
	canvas.composite_corner_toggled.connect(_toggle_composite_corner)
	canvas.connector_requested.connect(set_connector)
	canvas.connector_selection_changed.connect(func(_kind): _refresh())
	canvas.gameplay_placement_requested.connect(add_gameplay_placement)
	canvas.gameplay_move_requested.connect(move_gameplay_placement)
	canvas.gameplay_selection_changed.connect(func(_index): _refresh())
	canvas.marker_requested.connect(set_lifecycle_marker)
	canvas.marker_selection_changed.connect(func(_kind): _refresh())
	canvas.ring_requested.connect(set_ring_trail)
	canvas.ring_selection_changed.connect(func(_index): _refresh())
	canvas.decor_requested.connect(set_decor_slot)
	canvas.decor_selection_changed.connect(func(_index): _refresh())
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
	angle_field.tooltip_text = "Exact terrain, gameplay or decor angle in degrees. Enter commits. Alt+R / Alt+Shift+R adjusts by 1°."
	angle_field.text_submitted.connect(func(_text): _commit_gameplay_angle(); canvas.grab_focus())
	angle_field.focus_exited.connect(_commit_gameplay_angle)
	object_properties.add_child(angle_field)
	_button(object_properties, "angle_minus", "−1°", func(): _nudge_active_angle(-1.0), "Rotate by −1° (Alt+Shift+R)")
	_button(object_properties, "angle_plus", "+1°", func(): _nudge_active_angle(1.0), "Rotate by +1° (Alt+R)")
	handedness_field = OptionButton.new()
	handedness_field.add_item("Left flipper")
	handedness_field.add_item("Right flipper")
	handedness_field.tooltip_text = "Change handedness and swing direction; preserve the authored pivot and resting angle."
	handedness_field.item_selected.connect(_change_handedness)
	object_properties.add_child(handedness_field)
	_button(object_properties, "duplicate", "Duplicate", duplicate_selected, "Ctrl+D • duplicate selected terrain, gameplay object or ring trail")
	detail_label = Label.new()
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.add_theme_color_override("font_color", Color("b5c8d6"))
	workspace.add_child(detail_label)
	status_label = Label.new()
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(status_label)
	var help := Label.new()
	help.text = "Ctrl-click terrain multi-select   R rotate   H / V terrain flip   Ctrl+D duplicate   Alt free move / cycle overlaps   Wheel zoom   Middle-drag pan"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color("8aa5ba"))
	column.add_child(help)

func _button(parent: Node, id: String, label: String, action: Callable, hint: String) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func():
		if composite_preview_active:
			if id in ["composite_apply", "composite_cancel", "composite_clear_pins", "fit"]:
				composite_strength.apply()
				composite_angle.apply()
				action.call()
			return
		# Toolbar buttons do not take keyboard focus. Commit numeric drafts before
		# an edit refreshes the fields, then give editing shortcuts to the canvas.
		cell_size_field.apply()
		composite_strength.apply()
		composite_angle.apply()
		ring_spacing_field.apply()
		_commit_gameplay_angle()
		_commit_title()
		if id in ["select", "rotate", "angle_minus", "angle_plus", "flip_h", "flip_v", "delete", "duplicate", "undo", "redo", "fit"]:
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

func _build_decor_palette(parent: Node) -> void:
	decor_scroll = ScrollContainer.new()
	decor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	decor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	decor_scroll.follow_focus = true
	decor_scroll.visible = false
	parent.add_child(decor_scroll)
	decor_list = VBoxContainer.new()
	decor_list.add_theme_constant_override("separation", 8)
	decor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decor_list.visible = false
	decor_scroll.add_child(decor_list)
	for type: String in Decor.TYPES:
		_button(decor_list, "decor_" + type, type.capitalize() + " slot", choose_decor.bind(type), "Place a generic visual slot on raised terrain. Free placement by default.")
	decor_type_field = OptionButton.new()
	for type: String in Decor.TYPES: decor_type_field.add_item(type.capitalize())
	decor_type_field.item_selected.connect(func(index): _set_decor_property("slot_type", Decor.TYPES[index]))
	decor_list.add_child(decor_type_field)
	decor_hint_field = OptionButton.new()
	for hint: String in Decor.HINTS: decor_hint_field.add_item("Placement: " + hint)
	decor_hint_field.item_selected.connect(func(index): _set_decor_property("placement_hint", Decor.HINTS[index]))
	decor_hint_field.tooltip_text = "Theme variant hint only. Does not move or snap the slot."
	decor_list.add_child(decor_hint_field)
	decor_theme_field = OptionButton.new()
	for name: String in Themes.NAMES: decor_theme_field.add_item("Preview: " + name)
	decor_theme_field.tooltip_text = "Names and availability for this theme only. The preview theme is not saved in the Act."
	_decor_preview_skin = Themes.create(Themes.IDS[0]).create_decor(null)
	decor_theme_field.item_selected.connect(func(index):
		_decor_preview_skin = Themes.create(Themes.IDS[index]).create_decor(null)
		_refresh())
	decor_list.add_child(decor_theme_field)
	decor_variant_field = OptionButton.new()
	decor_variant_field.fit_to_longest_item = false
	decor_variant_field.tooltip_text = "Auto is deterministic. A numbered variant saves only its generic zero-based index, not a theme asset name."
	decor_variant_field.item_selected.connect(_select_decor_variant)
	decor_list.add_child(decor_variant_field)
	var coordinates := HBoxContainer.new()
	decor_list.add_child(coordinates)
	for axis in 2:
		var axis_label := Label.new()
		axis_label.text = "X" if axis == 0 else "Y"
		coordinates.add_child(axis_label)
		var field := LineEdit.new()
		field.custom_minimum_size.x = 90
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.placeholder_text = "X px" if axis == 0 else "Y px"
		field.tooltip_text = "Exact local " + ("X" if axis == 0 else "Y") + " coordinate in pixels"
		field.text_submitted.connect(func(_text): _commit_decor_position(); canvas.grab_focus())
		field.focus_exited.connect(_commit_decor_position)
		coordinates.add_child(field)
		decor_position_fields.append(field)
	decor_scale_field = SpinBox.new()
	decor_scale_field.min_value = 0.85
	decor_scale_field.max_value = 1.15
	decor_scale_field.step = 0.01
	decor_scale_field.value = 1.0
	decor_scale_field.prefix = "Scale"
	decor_scale_field.value_changed.connect(func(value): _set_decor_property("scale", value))
	decor_list.add_child(decor_scale_field)
	decor_visible_field = CheckBox.new()
	decor_visible_field.text = "Show decor slots"
	decor_visible_field.button_pressed = true
	decor_visible_field.toggled.connect(func(value):
		canvas.show_decor = value
		if not value and (canvas.selected_decor_index >= 0 or not canvas.decor_brush.is_empty()): canvas.select_piece(-1)
		_refresh())
	decor_list.add_child(decor_visible_field)
	decor_snap_field = CheckBox.new()
	decor_snap_field.text = "Snap decor to grid"
	decor_snap_field.toggled.connect(func(value): canvas.decor_snap = value; canvas.queue_redraw())
	decor_list.add_child(decor_snap_field)
	decor_info = Label.new()
	decor_info.custom_minimum_size.x = 250
	decor_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	decor_info.add_theme_font_size_override("font_size", 13)
	decor_info.add_theme_color_override("font_color", Color("d6a8ff"))
	decor_list.add_child(decor_info)

func choose_decor(type: String) -> void:
	canvas.set_decor_brush(Decor.make_slot(type))
	canvas.grab_focus()
	_set_status("Place decor on raised terrain. Free position; any numeric angle. Esc selects; Ctrl+D duplicates.")
	_refresh()

func _active_decor() -> Dictionary:
	if not canvas.decor_brush.is_empty(): return canvas.decor_brush
	if canvas.selected_decor_index >= 0: return document.decor_slots[canvas.selected_decor_index]
	return {}

func set_decor_slot(index: int, slot: Dictionary) -> void:
	if composite_preview_active or index < -1 or index >= document.decor_slots.size(): return
	var value := slot.duplicate(true)
	if index == -1: value.slot_id = Decor.new_id()
	var error: String = Decor.validation_error(value)
	if not error.is_empty():
		_set_status(error)
		return
	if index >= 0 and document.decor_slots[index] == value: return
	_record_edit()
	if document.decor_seed.is_empty(): document.decor_seed = Decor.new_id()
	if index == -1: document.decor_slots.append(value)
	else: document.decor_slots[index] = value
	_set_status("Decor slot saved in the draft. Theme chooses its visual; no gameplay collision.")
	_refresh()

func _set_decor_property(key: String, value: Variant) -> void:
	if _refreshing or composite_preview_active: return
	var active := _active_decor()
	if active.is_empty(): return
	var slot := active.duplicate(true)
	slot[key] = value
	var error: String = Decor.validation_error(slot)
	if not error.is_empty():
		_set_status(error)
		_refresh()
		return
	canvas.cancel_gesture()
	if canvas.decor_brush.is_empty(): set_decor_slot(canvas.selected_decor_index, slot)
	else:
		canvas.decor_brush = slot
		_refresh()

func _select_decor_variant(index: int) -> void:
	if _refreshing or composite_preview_active or _active_decor().is_empty(): return
	var slot := _active_decor().duplicate(true)
	var variant_index := int(decor_variant_field.get_item_metadata(index))
	slot["variant_mode"] = "auto" if variant_index < 0 else "fixed"
	if variant_index < 0: slot.erase("variant_index")
	else: slot["variant_index"] = variant_index
	canvas.cancel_gesture()
	if canvas.decor_brush.is_empty(): set_decor_slot(canvas.selected_decor_index, slot)
	else:
		canvas.decor_brush = slot
		_refresh()

func _commit_decor_position() -> void:
	if _refreshing or canvas.selected_decor_index < 0: return
	var position: Vector2 = _active_decor().position
	for axis in 2:
		var value := decor_position_fields[axis].text.strip_edges()
		if value == _decor_position_text[axis]: continue
		if not value.is_valid_float() or not is_finite(value.to_float()):
			_set_status("Decor position must be finite local pixels.")
			_refresh()
			return
		position[axis] = value.to_float()
	_set_decor_property("position", position)

func _refresh_decor_controls() -> void:
	var slot := _active_decor()
	var active := not slot.is_empty() and not composite_preview_active
	decor_type_field.disabled = not active
	decor_hint_field.disabled = not active
	decor_variant_field.disabled = not active
	decor_theme_field.disabled = composite_preview_active
	decor_variant_field.clear()
	decor_variant_field.add_item("Auto")
	decor_variant_field.set_item_metadata(0, -1)
	decor_scale_field.editable = active
	decor_visible_field.set_pressed_no_signal(canvas.show_decor)
	decor_snap_field.set_pressed_no_signal(canvas.decor_snap)
	for axis in 2:
		_decor_position_text[axis] = var_to_str(slot.position[axis]) if active and canvas.selected_decor_index >= 0 else ""
		decor_position_fields[axis].text = _decor_position_text[axis]
		decor_position_fields[axis].editable = active and canvas.selected_decor_index >= 0
	decor_info.text = "Auto or fixed variant · theme-independent\nFree movement · exact Angle ° below\nR / Shift+R: ±15° · Ctrl+D: duplicate\nArrows: 1 px (snap: 1 cell)\n\nPlace anchors on raised terrain. Unsupported slots remain editable but do not spawn in play."
	if active:
		if slot.slot_type == "landmark":
			decor_info.text = "Landmark 1: upright; 2: span / gateway.\nBoth are about 3 cells along the angle tick.\nVariant 3: circular, about 1.6 cells across.\nAuto keeps the long roles across themes.\n\n" + decor_info.text
		var choices: Array = _decor_preview_skin.variants_for(slot)
		for index in choices.size():
			decor_variant_field.add_item("Variant %d — %s" % [index + 1, str(choices[index]).capitalize()])
			decor_variant_field.set_item_metadata(index + 1, index)
		if slot.get("variant_mode", "auto") == "fixed":
			var selected: int = slot.variant_index
			if selected >= choices.size():
				decor_variant_field.add_item("Variant %d — unavailable (Auto)" % [selected + 1])
				decor_variant_field.set_item_metadata(decor_variant_field.item_count - 1, selected)
				decor_variant_field.select(decor_variant_field.item_count - 1)
			else: decor_variant_field.select(selected + 1)
		var warning: String = _decor_preview_skin.variant_warning(slot)
		if not warning.is_empty(): decor_info.text = warning + "\n\n" + decor_info.text
		decor_type_field.select(Decor.TYPES.find(slot.slot_type))
		decor_hint_field.select(Decor.HINTS.find(slot.placement_hint))
		decor_scale_field.set_value_no_signal(float(slot.get("scale", 1.0)))
		if canvas.selected_decor_index >= 0:
			decor_info.text += "\n\n" + ("On raised terrain." if Decor.supported_in_document(slot.position, document) else "No raised terrain under anchor: move onto an island or wall to spawn.")

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
	decor_list.visible = index == 3
	decor_scroll.visible = index == 3
	palette_heading.text = ["TERRAIN LIBRARY  /  %d stamps" % Shapes.definitions().size(), "GAMEPLAY  /  4 objects + Rings", "ACT MARKERS  /  4 tools", "DECOR  /  4 generic slots"][index]
	if index == 3 and canvas.selected_decor_index >= 0: _refresh()
	else: _select_mode()

func choose_rings() -> void:
	canvas.grab_focus()
	canvas.set_ring_tool()
	_set_status("Rings: click for one; drag in any direction for a trail. Alt frees endpoints. One drag = one undo.")
	_refresh()

func set_ring_trail(index: int, trail: Dictionary) -> void:
	if index < -1 or index >= document.ring_trails.size():
		return
	var error: String = Rings.validation_error(trail)
	if not error.is_empty():
		_set_status(error)
		return
	if index >= 0 and document.ring_trails[index] == trail:
		return
	_record_edit()
	if index < 0:
		document.ring_trails.append(trail.duplicate(true))
	else:
		document.ring_trails[index] = trail.duplicate(true)
	_set_status("%d rings in one trail. Select / Move to drag the group or its small endpoint handles." % Rings.positions(trail).size())
	_refresh()

func _change_ring_spacing(value: float) -> void:
	if _refreshing or canvas == null:
		return
	if not is_finite(value) or value <= 0:
		_set_status("Ring spacing must be finite and greater than zero.")
		_refresh()
		return
	if canvas.selected_ring_index >= 0:
		var trail: Dictionary = document.ring_trails[canvas.selected_ring_index].duplicate(true)
		trail.spacing = value * document.cell_size
		set_ring_trail(canvas.selected_ring_index, trail)
	canvas.ring_spacing_cells = value
	canvas.queue_redraw()

func choose_gameplay(id: String) -> void:
	var placement: Dictionary = Objects.make_placement(id)
	if placement.is_empty():
		return
	canvas.grab_focus()
	canvas.set_gameplay_brush(placement)
	_set_status("Place %s. SNAP ON · hold Alt for FREE MOVE. R / Shift+R adjusts the angle." % Objects.get_definition(id).label)
	_refresh()

func _select_mode() -> void:
	if composite_preview_active:
		cancel_composite_preview()
		return
	canvas.grab_focus()
	canvas.select_piece(-1)
	_set_status("Click to select; Ctrl-click toggles terrain for Merge. Alt-click cycles overlaps. Drag a single selection to move.")
	_refresh()

func _terrain_selection() -> Array[int]:
	var indices: Array[int] = []
	for index: int in canvas.selected_indices:
		if index >= 0 and index < document.placements.size() and not indices.has(index):
			indices.append(index)
	return indices

func _composite_selection_error(operation: String) -> String:
	var indices := _terrain_selection()
	if operation == "smooth" and composite_only_joins.button_pressed:
		return "Only smooth joins needs Merge + Smooth on multiple selected pieces. Turn it off to smooth one outline."
	if operation == "smooth" and indices.size() != 1:
		return "Smooth needs one filled terrain piece. Use Merge + Smooth for multiple pieces."
	if operation != "smooth" and indices.size() < 2:
		return "Ctrl-click two or more filled terrain pieces to merge."
	for index: int in indices:
		var definition := Shapes.definition_for_placement(document.placements[index])
		if definition.is_empty() or not definition.closed:
			return "Filled terrain only: deselect open walls / rails. Open-path joining is not supported."
	return ""

func preview_composite(operation: String) -> void:
	if composite_preview_active or operation not in ["merge", "smooth", "merge_smooth"]:
		return
	var error := _composite_selection_error(operation)
	if not error.is_empty():
		_set_status(error)
		return
	canvas.cancel_gesture()
	_composite_sources = _terrain_selection()
	_composite_sources.sort()
	var sources: Array = []
	for index: int in _composite_sources:
		sources.append(document.placements[index].duplicate(true))
	var result: Dictionary = {"placement": sources[0], "error": ""} if operation == "smooth" else Composite.merge(sources)
	if not result.error.is_empty():
		_set_status(result.error)
		return
	_composite_base = result.placement
	_composite_protected_indices.clear()
	_composite_join_indices = result.get("join_indices", PackedInt32Array())
	_composite_operation = operation
	_composite_fingerprint = document.fingerprint()
	composite_preview_active = true
	canvas.grab_focus()
	_rebuild_composite_preview()

func _rebuild_composite_preview() -> void:
	var result: Dictionary = {"placement": _composite_base.duplicate(true), "error": ""}
	if _composite_operation != "merge":
		var joins: Variant = _composite_join_indices if composite_only_joins.button_pressed and _composite_operation == "merge_smooth" else null
		result = Composite.smooth(_composite_base, composite_strength.value / 100.0, composite_preserve_corners.button_pressed, composite_angle.value, joins, _composite_protected_indices, composite_allow_reshaping.button_pressed, composite_whole_contour.button_pressed)
	_composite_area_limited = result.get("area_limited", false)
	_composite_error = result.error
	composite_preview = result.placement
	canvas.set_composite_preview(composite_preview, true)
	canvas.set_smoothing_corners(_composite_base if _composite_operation != "merge" else {}, _composite_protected_indices)
	_refresh()
	if not result.error.is_empty():
		_set_status(result.error + " Reduce strength or Cancel. Nothing has been changed.")
	else:
		_set_status("Preview: the bright contour is the final collision silhouette. Apply replaces %d source piece(s); Cancel keeps them." % _composite_sources.size())

func _toggle_composite_corner(index: int) -> void:
	if not composite_preview_active or _composite_operation == "merge": return
	var offset := _composite_protected_indices.find(index)
	if offset >= 0:
		_composite_protected_indices.remove_at(offset)
	else:
		_composite_protected_indices.append(index)
	_rebuild_composite_preview()

func _clear_composite_pins() -> void:
	if not composite_preview_active: return
	_composite_protected_indices.clear()
	_rebuild_composite_preview()

func apply_composite() -> void:
	if not composite_preview_active or composite_preview.is_empty():
		return
	if document.fingerprint() != _composite_fingerprint:
		cancel_composite_preview()
		_set_status("The document changed during preview. Select the pieces and preview again.")
		return
	var candidate: Resource = document.copy_document()
	for offset in range(_composite_sources.size() - 1, -1, -1):
		candidate.placements.remove_at(_composite_sources[offset])
	var inserted: int = _composite_sources[0]
	candidate.placements.insert(inserted, composite_preview.duplicate(true))
	var errors: PackedStringArray = candidate.validation_errors()
	if not errors.is_empty():
		_set_status(errors[0] + " Preview not applied.")
		return
	if candidate.fingerprint() == document.fingerprint():
		_clear_composite_preview()
		_refresh()
		_set_status("The composite is unchanged. No undo step was added.")
		return
	_record_edit()
	document.placements = candidate.placements
	_clear_composite_preview()
	canvas.select_piece(inserted)
	_refresh()
	_set_status("CompositeTerrain applied as one edit. Ctrl+Z restores every source piece; merge this composite again to keep sculpting.")

func _clear_composite_preview() -> void:
	composite_preview_active = false
	composite_preview = {}
	_composite_sources.clear()
	_composite_base = {}
	_composite_join_indices.clear()
	_composite_protected_indices.clear()
	_composite_fingerprint = ""
	_composite_operation = ""
	_composite_error = ""
	canvas.set_composite_preview({}, false)

func cancel_composite_preview() -> void:
	if not composite_preview_active:
		return
	_clear_composite_preview()
	_refresh()
	_set_status("Preview canceled. Original terrain and undo history are unchanged.")

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
	_set_status("Placed %s. %d independent terrain pieces." % [Shapes.definition_for_placement(placement).label, document.placements.size()])
	_refresh()

func move_placement(index: int, anchor: Vector2) -> void:
	if index < 0 or index >= document.placements.size():
		return
	var placement: Dictionary = document.placements[index]
	anchor = _clamp_anchor(placement, anchor)
	if anchor == Shapes.placement_position(placement):
		return
	_record_edit()
	Shapes.set_placement_position(placement, anchor)
	_refresh()

func _clamp_anchor(placement: Dictionary, anchor: Vector2) -> Vector2:
	return anchor.clamp(Vector2.ZERO, (Vector2(document.grid_size) - Shapes.scaled_size(placement)).max(Vector2.ZERO))

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
	if not _active_decor().is_empty(): _set_decor_property("rotation_degrees", text_value.to_float())
	elif not _active_gameplay().is_empty(): set_gameplay_angle(text_value.to_float())
	else: set_terrain_angle(text_value.to_float())
	_refresh()

func _active_terrain() -> Dictionary:
	if not canvas.brush.is_empty(): return canvas.brush
	if _terrain_selection().size() == 1: return document.placements[canvas.selected_index]
	return {}

func _nudge_active_angle(degrees: float) -> void:
	if composite_preview_active: return
	if not _active_decor().is_empty():
		_set_decor_property("rotation_degrees", float(_active_decor().rotation_degrees) + degrees)
	elif not _active_gameplay().is_empty(): rotate_gameplay(degrees)
	elif not _active_terrain().is_empty(): set_terrain_angle(Shapes.angle_degrees(_active_terrain()) + degrees)

func set_terrain_angle(value: float) -> void:
	if composite_preview_active or not is_finite(value): return
	var active := _active_terrain()
	if active.is_empty() or Shapes.angle_degrees(active) == value: return
	var placement := active.duplicate(true)
	var center := Shapes.placement_position(placement) + Shapes.scaled_size(placement) * 0.5
	var residual := value - float(placement.quarter_turns) * 90.0
	if residual == 0.0: placement.erase("fine_rotation_degrees")
	else: placement["fine_rotation_degrees"] = residual
	var frame := Shapes.scaled_size(placement)
	if frame.x > document.grid_size.x or frame.y > document.grid_size.y:
		_refresh()
		_set_status("This rotated terrain footprint does not fit inside the Act.")
		return
	canvas.cancel_gesture()
	Shapes.set_placement_position(placement, _clamp_anchor(placement, center - frame * 0.5))
	if not canvas.brush.is_empty(): canvas.set_brush(placement)
	else:
		_record_edit()
		document.placements[canvas.selected_index] = placement
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
	if composite_preview_active:
		return
	if canvas.selected_decor_index >= 0:
		var slot: Dictionary = document.decor_slots[canvas.selected_decor_index].duplicate(true)
		slot.position += Vector2.ONE * float(document.cell_size) * 0.5
		set_decor_slot(-1, slot)
		canvas.select_decor(document.decor_slots.size() - 1)
		_refresh()
		return
	if _terrain_selection().size() == 1:
		var terrain: Dictionary = document.placements[canvas.selected_index].duplicate(true)
		Shapes.set_placement_position(terrain, _clamp_anchor(terrain, Shapes.placement_position(terrain) + Vector2.ONE * canvas.terrain_snap_step))
		canvas.cancel_gesture()
		add_placement(terrain)
		canvas.select_piece(document.placements.size() - 1)
		_refresh()
		return
	if canvas.selected_ring_index >= 0:
		var trail: Dictionary = document.ring_trails[canvas.selected_ring_index].duplicate(true)
		trail.start += Vector2.ONE * document.cell_size
		trail.end += Vector2.ONE * document.cell_size
		set_ring_trail(-1, trail)
		canvas.select_ring(document.ring_trails.size() - 1)
		_refresh()
		return
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
	if not _active_decor().is_empty():
		_set_decor_property("rotation_degrees", float(_active_decor().rotation_degrees) + 15.0)
	elif not _active_gameplay().is_empty():
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
	if composite_preview_active or _terrain_selection().size() > 1:
		return
	canvas.grab_focus()
	canvas.cancel_gesture()
	var placement: Dictionary
	if not canvas.brush.is_empty():
		placement = canvas.brush.duplicate(true)
	elif canvas.selected_index >= 0:
		placement = document.placements[canvas.selected_index].duplicate(true)
	else:
		return
	var original_center := Shapes.placement_position(placement) + Shapes.scaled_size(placement) * 0.5
	if operation == "rotation":
		placement.quarter_turns = (placement.quarter_turns + 1) % 4
		# Keep the visible operation a clockwise turn after previous screen-axis flips.
		var previous_h: bool = placement.flip_h
		placement.flip_h = placement.flip_v
		placement.flip_v = previous_h
	elif operation in ["half_size", "full_size"]:
		var scale_value := 0.5 if operation == "half_size" else 1.0
		if float(placement.get("terrain_scale", 1.0)) == scale_value: return
		if scale_value == 1.0: placement.erase("terrain_scale")
		else: placement["terrain_scale"] = scale_value
	else:
		placement[operation] = not placement[operation]
		if placement.has("fine_rotation_degrees"):
			placement.fine_rotation_degrees = -float(placement.fine_rotation_degrees)
	var frame := Shapes.scaled_size(placement)
	if frame.x > document.grid_size.x or frame.y > document.grid_size.y:
		_refresh()
		_set_status("This terrain footprint does not fit inside the Act.")
		return
	var position := original_center - frame * 0.5 if placement.has("fine_rotation_degrees") else Shapes.placement_position(placement)
	Shapes.set_placement_position(placement, _clamp_anchor(placement, position))
	if not canvas.brush.is_empty():
		canvas.set_brush(placement)
	else:
		_record_edit()
		document.placements[canvas.selected_index] = placement
	_refresh()

func delete_selected() -> void:
	if composite_preview_active:
		return
	if canvas.selected_decor_index >= 0:
		canvas.cancel_gesture()
		_record_edit()
		document.decor_slots.remove_at(canvas.selected_decor_index)
		canvas.select_decor(-1)
		_refresh()
		return
	if canvas.selected_ring_index >= 0:
		canvas.cancel_gesture()
		_record_edit()
		document.ring_trails.remove_at(canvas.selected_ring_index)
		canvas.select_ring(-1)
		_refresh()
		return
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
	var indices := _terrain_selection()
	indices.sort()
	indices.reverse()
	for index: int in indices:
		document.placements.remove_at(index)
	canvas.select_piece(-1)
	_refresh()

func _snapshot() -> Dictionary:
	return {"document": document.copy_document(), "selected": canvas.selected_index,
		"terrain_selection": _terrain_selection(),
		"connector": canvas.selected_connector, "gameplay": canvas.selected_gameplay_index,
		"marker": canvas.selected_marker, "ring": canvas.selected_ring_index, "decor": canvas.selected_decor_index}

func _record_edit() -> void:
	undo_stack.append(_snapshot())
	if undo_stack.size() > HISTORY_LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()

func undo() -> void:
	if composite_preview_active:
		cancel_composite_preview()
		return
	canvas.cancel_gesture()
	if undo_stack.is_empty():
		return
	redo_stack.append(_snapshot())
	_restore_snapshot(undo_stack.pop_back())
	_set_status("Undid one edit.")

func redo() -> void:
	if composite_preview_active:
		cancel_composite_preview()
		return
	canvas.cancel_gesture()
	if redo_stack.is_empty():
		return
	undo_stack.append(_snapshot())
	_restore_snapshot(redo_stack.pop_back())
	_set_status("Redid one edit.")

func _restore_snapshot(snapshot: Dictionary) -> void:
	var active_decor_brush: Dictionary = canvas.decor_brush.duplicate(true)
	var active_brush: Dictionary = canvas.brush.duplicate(true)
	var active_gameplay_brush: Dictionary = canvas.gameplay_brush.duplicate(true)
	var active_ring_tool: bool = canvas.ring_tool
	document = snapshot.document
	_title_edit_recorded = false
	canvas.set_document(document, false)
	if not active_decor_brush.is_empty():
		canvas.set_decor_brush(active_decor_brush)
	elif snapshot.get("decor", -1) >= 0:
		canvas.select_decor(snapshot.decor)
	elif active_ring_tool:
		canvas.set_ring_tool()
	elif not active_brush.is_empty():
		canvas.set_brush(active_brush)
	elif not active_gameplay_brush.is_empty():
		canvas.set_gameplay_brush(active_gameplay_brush)
	elif not snapshot.get("connector", "").is_empty() and document.get_connector(snapshot.connector).width > 0:
		canvas.select_connector(snapshot.connector)
	elif not snapshot.get("marker", "").is_empty():
		canvas.select_marker(snapshot.marker)
	elif snapshot.get("gameplay", -1) >= 0:
		canvas.select_gameplay(snapshot.gameplay)
	elif snapshot.get("ring", -1) >= 0:
		canvas.select_ring(snapshot.ring)
	else:
		var indices: Array[int] = []
		indices.assign(snapshot.get("terrain_selection", [snapshot.selected] if snapshot.selected >= 0 else []))
		canvas.set_terrain_selection(indices)
	_refresh()

func is_dirty() -> bool:
	return document != null and (document.fingerprint() != saved_fingerprint or title_field.text != document.title)

func new_document() -> void:
	_clear_composite_preview()
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
	_commit_decor_position()
	decor_scale_field.apply()
	ring_spacing_field.apply()
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
	_set_status("Saved %d terrain pieces, %d gameplay objects, %d ring trails and %d decor slots to %s" % [document.placements.size(), document.gameplay_objects.size(), document.ring_trails.size(), document.decor_slots.size(), path])
	_refresh()
	return true

func load_from(path: String) -> bool:
	var result: Dictionary = ActData.load_document(path)
	if result.document == null:
		_show_error("Could not load this Act. Your current edits are still open.\n" + result.error)
		return false
	_clear_composite_preview()
	document = result.document
	_title_edit_recorded = false
	current_path = path
	saved_fingerprint = document.fingerprint()
	undo_stack.clear()
	redo_stack.clear()
	canvas.set_document(document)
	_refresh()
	canvas.call_deferred("fit_view")
	_set_status("Loaded %d terrain pieces, %d gameplay objects, %d ring trails and %d decor slots." % [document.placements.size(), document.gameplay_objects.size(), document.ring_trails.size(), document.decor_slots.size()])
	return true

func request_action(action: String) -> void:
	if composite_preview_active:
		_set_status("Apply or Cancel the composite preview before changing documents or closing.")
		return
	if _modal_open():
		return
	_commit_decor_position()
	decor_scale_field.apply()
	ring_spacing_field.apply()
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
	ring_spacing_field.apply()
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
	for button: Button in buttons.values():
		button.disabled = false
	title_field.text = document.title
	cell_size_field.set_value_no_signal(document.cell_size)
	grid_label.text = "   %d × %d cells    Cell size" % [document.grid_size.x, document.grid_size.y]
	_refresh_file_state()
	buttons.undo.disabled = undo_stack.is_empty()
	buttons.redo.disabled = redo_stack.is_empty()
	buttons.delete.disabled = canvas.selected_decor_index < 0 and canvas.selected_index < 0 and canvas.selected_gameplay_index < 0 and canvas.selected_ring_index < 0 and canvas.selected_connector.is_empty() and canvas.selected_marker.is_empty()
	buttons.duplicate.disabled = canvas.selected_decor_index < 0 and canvas.selected_gameplay_index < 0 and canvas.selected_ring_index < 0 and _terrain_selection().size() != 1
	var ring_spacing: float = document.ring_trails[canvas.selected_ring_index].spacing / float(document.cell_size) if canvas.selected_ring_index >= 0 else canvas.ring_spacing_cells
	ring_spacing_field.set_value_no_signal(ring_spacing)
	connector_summary.text = _connector_description("entry") + "   |   " + _connector_description("exit")
	connector_summary.tooltip_text = connector_summary.text + "\nCompatibility compares width only; horizontal positions may differ."
	marker_summary.text = "Activation: " + ("unset" if document.activation_y == null else "Y %s px" % var_to_str(document.activation_y))
	marker_summary.text += "\nSpawn: " + ("unset" if document.spawn_position == null else "%s px" % document.spawn_position)
	var active: Dictionary = canvas.brush if not canvas.brush.is_empty() else (document.placements[canvas.selected_index] if canvas.selected_index >= 0 else {})
	var gameplay := _active_gameplay()
	var decor := _active_decor()
	var angled := decor if not decor.is_empty() else gameplay
	for key in ["rotate", "flip_h", "flip_v"]:
		buttons[key].disabled = active.is_empty() or _terrain_selection().size() > 1
	buttons.rotate.disabled = (active.is_empty() and angled.is_empty()) or _terrain_selection().size() > 1
	buttons.rotate.text = "Rotate +15°" if not angled.is_empty() else "Rotate +90°"
	angle_field.editable = not angled.is_empty() or not _active_terrain().is_empty()
	buttons.angle_minus.disabled = not angle_field.editable
	buttons.angle_plus.disabled = not angle_field.editable
	_angle_display_text = var_to_str(angled.rotation_degrees) if not angled.is_empty() else (var_to_str(Shapes.angle_degrees(active)) if angle_field.editable else "")
	angle_field.text = _angle_display_text
	angle_field.placeholder_text = "Select a shape"
	handedness_field.disabled = gameplay.is_empty() or gameplay.type not in ["left_flipper", "right_flipper"]
	handedness_field.select(1 if not gameplay.is_empty() and gameplay.type == "right_flipper" else 0)
	if not decor.is_empty():
		mode_label.text = ("PLACE" if not canvas.decor_brush.is_empty() else "SELECTED") + " · " + decor.slot_type.capitalize() + " decor"
		var variant := "Variant %d" % (int(decor.get("variant_index", 0)) + 1) if decor.get("variant_mode", "auto") == "fixed" else "Auto variant"
		detail_label.text = "%s px · %s° · %s · %s · Presentation only" % [decor.position, var_to_str(decor.rotation_degrees), decor.placement_hint, variant]
	elif canvas.ring_tool or canvas.selected_ring_index >= 0:
		mode_label.text = "DRAW RINGS" if canvas.ring_tool else "SELECTED  ·  Ring trail"
		detail_label.text = "Click / drag · Alt frees endpoints · Generated rings never snap · Select trail to move or resize · Delete removes trail"
	elif not canvas.marker_tool.is_empty():
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
	elif _terrain_selection().size() > 1:
		mode_label.text = "SELECTED  ·  %d terrain pieces" % _terrain_selection().size()
		detail_label.text = "Ctrl-click toggles pieces · Merge or Merge + Smooth previews a composite · Delete removes the selection"
	elif active.is_empty():
		mode_label.text = "SELECT / MOVE"
		detail_label.text = "%d terrain pieces · %d gameplay objects · %d ring trails · Alt-click cycles overlaps." % [document.placements.size(), document.gameplay_objects.size(), document.ring_trails.size()]
	else:
		var definition: Dictionary = Shapes.definition_for_placement(active)
		var frame := Shapes.scaled_size(active)
		mode_label.text = ("STAMP  ·  " if not canvas.brush.is_empty() else "SELECTED  ·  ") + definition.label
		detail_label.text = "Frame %s × %s cells · %s° · H %s / V %s · Alt: free move%s" % [frame.x, frame.y, Shapes.angle_degrees(active), "on" if active.flip_h else "off", "on" if active.flip_v else "off", " · Position %s" % Shapes.placement_position(active) if canvas.brush.is_empty() else " · Click to place"]
	_refresh_composite_controls()
	_refresh_decor_controls()
	canvas.queue_redraw()
	_refreshing = false

func _refresh_composite_controls() -> void:
	var merge_error := _composite_selection_error("merge")
	var smooth_error := _composite_selection_error("smooth")
	buttons.merge.disabled = not merge_error.is_empty()
	buttons.merge_smooth.disabled = not merge_error.is_empty()
	buttons.smooth.disabled = not smooth_error.is_empty()
	buttons.merge.tooltip_text = merge_error if not merge_error.is_empty() else "Preview the geometric union of selected filled silhouettes"
	buttons.merge_smooth.tooltip_text = buttons.merge.tooltip_text
	buttons.smooth.tooltip_text = smooth_error if not smooth_error.is_empty() else "Preview conservative corner smoothing on the selected outline"
	buttons.composite_apply.visible = composite_preview_active
	buttons.composite_cancel.visible = composite_preview_active
	var terrain: Dictionary = canvas.brush if not canvas.brush.is_empty() else (document.placements[canvas.selected_index] if canvas.selected_index >= 0 else {})
	terrain_snap_field.disabled = composite_preview_active
	terrain_scale_field.disabled = composite_preview_active or terrain.is_empty() or _terrain_selection().size() > 1
	terrain_scale_field.select(1 if not terrain.is_empty() and float(terrain.get("terrain_scale", 1.0)) == 0.5 else 0)
	buttons.composite_clear_pins.visible = composite_preview_active and _composite_operation != "merge"
	composite_strength.editable = not composite_preview_active or _composite_operation != "merge"
	composite_preserve_corners.disabled = composite_preview_active and _composite_operation == "merge"
	composite_angle.editable = composite_preserve_corners.button_pressed and not composite_preserve_corners.disabled
	composite_only_joins.disabled = composite_whole_contour.button_pressed or (composite_preview_active and _composite_operation != "merge_smooth")
	composite_allow_reshaping.disabled = composite_preview_active and _composite_operation == "merge"
	composite_whole_contour.disabled = composite_preview_active and _composite_operation == "merge"
	composite_hint.text = merge_error if not merge_error.is_empty() else "%d filled pieces selected. Preview before applying; no source changes until Apply." % _terrain_selection().size()
	if _terrain_selection().size() == 1 and smooth_error.is_empty():
		composite_hint.text = "Smooth this piece, or Ctrl-click more filled terrain to merge."
	if composite_preview_active:
		for id: String in buttons:
			buttons[id].disabled = id not in ["fit", "composite_apply", "composite_cancel", "composite_clear_pins"]
		buttons.composite_clear_pins.disabled = _composite_protected_indices.is_empty()
		buttons.composite_apply.disabled = composite_preview.is_empty()
		angle_field.editable = false
		handedness_field.disabled = true
		mode_label.text = "COMPOSITE PREVIEW  ·  Apply / Cancel"
		detail_label.text = "Gold outline = final collision boundary · Original pieces remain unchanged until Apply · Esc cancels"
		composite_hint.text = "Preview only. Adjust strength, then Apply or Cancel. Other editing is paused."
		if _composite_operation != "merge":
			composite_hint.text = "Click corner dots to protect/release. Pink = do not smooth · %d pinned · Apply / Cancel" % _composite_protected_indices.size()
		if not _composite_error.is_empty():
			composite_hint.text = _composite_error
		elif _composite_area_limited:
			composite_hint.text = "Reached %d%% area-change limit · Pins stay fixed · %s" % [25 if composite_allow_reshaping.button_pressed else 5, "Apply / Cancel" if composite_allow_reshaping.button_pressed else "Enable Allow reshaping for more rounding"]
		buttons.composite_apply.tooltip_text = _composite_error if not _composite_error.is_empty() else "Apply the displayed contour in one undo step"
	composite_hint.tooltip_text = composite_hint.text
	title_field.editable = not composite_preview_active
	cell_size_field.editable = not composite_preview_active
	ring_spacing_field.editable = not composite_preview_active
	for item: Button in palette_buttons.values():
		item.disabled = composite_preview_active
	for item: Button in gameplay_buttons.values():
		item.disabled = composite_preview_active
	for index in palette_tabs.tab_count:
		palette_tabs.set_tab_disabled(index, composite_preview_active)

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
	if composite_preview_active:
		if event.keycode == KEY_ESCAPE:
			cancel_composite_preview()
		get_viewport().set_input_as_handled()
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
				if event.alt_pressed: _nudge_active_angle(-1.0 if event.shift_pressed else 1.0)
				elif event.shift_pressed and not _active_decor().is_empty(): _set_decor_property("rotation_degrees", float(_active_decor().rotation_degrees) - 15.0)
				elif event.shift_pressed and not _active_gameplay().is_empty(): rotate_gameplay(-15.0)
				else: rotate_active()
			KEY_H: flip_active(true)
			KEY_V: flip_active(false)
			KEY_DELETE, KEY_BACKSPACE: delete_selected()
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				if _terrain_selection().size() == 1:
					var direction: Vector2i = {KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN}[event.keycode]
					var distance: float = 1.0 / float(document.cell_size) if event.alt_pressed else canvas.terrain_snap_step
					move_placement(canvas.selected_index, Shapes.placement_position(document.placements[canvas.selected_index]) + Vector2(direction) * distance)
			_: return
	get_viewport().set_input_as_handled()
