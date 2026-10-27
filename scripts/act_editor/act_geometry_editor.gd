extends Control
## Standalone authoring UI. It has no runtime table or gameplay dependencies.
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Canvas = preload("res://scripts/act_editor/geometry_canvas.gd")
const PaletteItem = preload("res://scripts/act_editor/terrain_palette_item.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const GameplayPaletteItem = preload("res://scripts/act_editor/gameplay_palette_item.gd")
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const Banks = preload("res://scripts/act_editor/switch_banks.gd")
const Composite = preload("res://scripts/act_editor/composite_terrain.gd")
const Decor = preload("res://scripts/act_editor/decor_slots.gd")
const DecorScatter = preload("res://scripts/act_editor/decor_scatter.gd")
const Themes = preload("res://scripts/themes/theme_registry.gd")
const EXAMPLE_PATH := "res://data/acts/curve_garden.tres"
const DEFAULT_ACT_DIRECTORY := "res://data/acts"
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
var grid_width_field: SpinBox
var grid_height_field: SpinBox
var file_label: Label
var gameplay_scroll: ScrollContainer
var mechanics_properties: HFlowContainer
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
var rings_scroll: ScrollContainer
var rings_list: VBoxContainer
var ring_fill_field: CheckBox
var ring_radius_fields: Array[SpinBox] = []
var ring_rotation_field: SpinBox
var ring_ellipse_settings: VBoxContainer
var bank_controls: VBoxContainer
var selected_bank_id := ""
var composite_bar: HFlowContainer
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
var decor_frequency_field: SpinBox
var decor_small_percent_field: SpinBox
var decor_medium_percent_label: Label
var decor_position_fields: Array[LineEdit] = []
var decor_visible_field: CheckBox
var decor_snap_field: CheckBox
var decor_info: Label
var inspector: VBoxContainer
var marker_reminders: VBoxContainer
var verify_dialog: AcceptDialog
var _decor_position_text: Array[String] = ["", ""]

func _ready() -> void:
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
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
	ui_theme.default_font_size = 12
	ui_theme.set_color("font_color", "Label", Color("dcebf2"))
	ui_theme.set_color("font_color", "Button", Color("e6f3fa"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("22374a") if state == "normal" else Color("31556a")
		if state == "disabled":
			style.bg_color = Color("172633")
		style.set_corner_radius_all(5)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
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
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	column.add_child(header)
	var brand := Label.new()
	brand.text = "ACT / EDITOR"
	brand.add_theme_font_size_override("font_size", 16)
	brand.add_theme_color_override("font_color", Color("70e5d5"))
	brand.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(brand)
	_button(header, "new", "New Act", func(): request_action("new"), "Ctrl+N")
	_button(header, "load", "Load", func(): request_action("load"), "Ctrl+O")
	_button(header, "save", "Save", _save_current, "Ctrl+S")
	_button(header, "save_as", "Save As", _open_save_dialog, "Ctrl+Shift+S")
	_button(header, "play", "Play", _play_current, "Play the saved Act in a separate game window")
	_button(header, "bake", "Bake", _bake_current, "Bake saved collision and complete visuals for endless streaming")
	file_label = Label.new()
	file_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	file_label.add_theme_color_override("font_color", Color("9cb3c6"))
	file_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(file_label)
	header.move_child(file_label, 1)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	column.add_child(tools)
	_button(tools, "select", "Select / Move", _select_mode, "Esc • click terrain or an object, then drag • Alt-click cycles overlaps")
	_button(tools, "rotate", "Rotate +90°", rotate_active, "R • terrain +90°; gameplay +15° (Shift+R −15°)")
	_button(tools, "flip_h", "Flip H", func(): flip_active(true), "H • mirror across the current screen frame")
	_button(tools, "flip_v", "Flip V", func(): flip_active(false), "V • mirror across the current screen frame")
	_button(tools, "delete", "Delete", delete_selected, "Delete / Backspace")
	tools.add_child(VSeparator.new())
	_button(tools, "undo", "Undo", undo, "Ctrl+Z • up to 100 edits")
	_button(tools, "redo", "Redo", redo, "Ctrl+Y / Ctrl+Shift+Z")
	tools.add_child(VSeparator.new())
	_button(tools, "verify", "Verify", verify_document, "Check saved data and runtime ramp clearance before play")
	_button(tools, "fullscreen", "Fullscreen", _toggle_fullscreen, "F11 • toggle fullscreen")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)
	_button(tools, "fit", "Fit Grid", func(): canvas.fit_view(), "Mouse wheel zooms • middle-drag pans")
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	column.add_child(body)
	var palette := VBoxContainer.new()
	palette.custom_minimum_size.x = 240
	palette.add_theme_constant_override("separation", 4)
	body.add_child(palette)
	palette_tabs = TabBar.new()
	palette_tabs.clip_tabs = false
	palette_tabs.add_theme_font_size_override("font_size", 11)
	for state in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled"]:
		var tab_style := StyleBoxFlat.new()
		tab_style.bg_color = Color("22374a") if state == "tab_selected" else Color("101c29")
		tab_style.content_margin_left = 5
		tab_style.content_margin_right = 5
		tab_style.content_margin_top = 4
		tab_style.content_margin_bottom = 4
		palette_tabs.add_theme_stylebox_override(state, tab_style)
	palette_tabs.add_tab("Terrain")
	palette_tabs.add_tab("Gameplay")
	palette_tabs.add_tab("Markers")
	palette_tabs.add_tab("Decor")
	palette_tabs.add_tab("Rings")
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
	gameplay_scroll = ScrollContainer.new()
	gameplay_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gameplay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gameplay_scroll.visible = false
	palette.add_child(gameplay_scroll)
	gameplay_list = VBoxContainer.new()
	gameplay_list.add_theme_constant_override("separation", 4)
	gameplay_list.visible = false
	gameplay_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gameplay_scroll.add_child(gameplay_list)
	for definition: Dictionary in Objects.definitions():
		var item := GameplayPaletteItem.new()
		item.configure(definition)
		item.pressed.connect(choose_gameplay.bind(definition.id))
		gameplay_list.add_child(item)
		gameplay_buttons[definition.id] = item
	bank_controls = VBoxContainer.new()
	gameplay_list.add_child(bank_controls)
	gameplay_list.move_child(bank_controls, 0)
	rings_scroll = ScrollContainer.new()
	rings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rings_scroll.visible = false
	palette.add_child(rings_scroll)
	rings_list = VBoxContainer.new()
	rings_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rings_scroll.add_child(rings_list)
	_button(rings_list, "rings", "Trail / Line Draw", choose_rings, "Click for one ring; drag in any direction for a trail. Alt frees endpoints.")
	_button(rings_list, "ring_circle", "Circle / Ellipse Draw", choose_ring_circle, "Drag opposite bounds corners; release to commit one undo action.")
	var ring_settings := HBoxContainer.new()
	rings_list.add_child(ring_settings)
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
	ring_ellipse_settings = VBoxContainer.new()
	rings_list.add_child(ring_ellipse_settings)
	ring_fill_field = CheckBox.new()
	ring_fill_field.text = "Fill interior (hex rows)"
	ring_fill_field.toggled.connect(func(value: bool): _change_ring_pattern("fill", value))
	ring_ellipse_settings.add_child(ring_fill_field)
	for axis in 2:
		var row := HBoxContainer.new()
		ring_ellipse_settings.add_child(row)
		var label := Label.new()
		label.text = "Radius " + ("X" if axis == 0 else "Y")
		row.add_child(label)
		var field := SpinBox.new()
		field.min_value = 1.0
		field.max_value = 10000.0
		field.step = 0.01
		field.suffix = "px"
		field.value = 50.0
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.value_changed.connect(func(value: float): _change_ring_radius(axis, value))
		row.add_child(field)
		ring_radius_fields.append(field)
	ring_rotation_field = SpinBox.new()
	ring_rotation_field.min_value = -36000
	ring_rotation_field.max_value = 36000
	ring_rotation_field.step = 0.1
	ring_rotation_field.suffix = "degrees"
	ring_rotation_field.value_changed.connect(func(value: float): _change_ring_pattern("rotation_degrees", value))
	ring_ellipse_settings.add_child(ring_rotation_field)
	var ring_hint := Label.new()
	ring_hint.text = "Drag bounds to size an ellipse.\nEqual radii make a circle.\nSpacing controls ring count.\nAlt: free bounds. One gesture: one Undo."
	ring_hint.add_theme_font_size_override("font_size", 12)
	rings_list.add_child(ring_hint)
	var object_hint := Label.new()
	object_hint.text = "Snap to grid intersections.\nHold Alt for exact placement.\n\nCyan: bumpers / sling\nYellow: flippers / ring trails\nCrosshair: anchor / pivot"
	object_hint.add_theme_color_override("font_color", Color("9cb3c6"))
	object_hint.add_theme_font_size_override("font_size", 13)
	gameplay_list.add_child(object_hint)
	marker_list = VBoxContainer.new()
	marker_list.add_theme_constant_override("separation", 4)
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
	workspace.add_theme_constant_override("separation", 4)
	body.add_child(workspace)
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.custom_minimum_size.x = 300
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(inspector_scroll)
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 8)
	inspector_scroll.add_child(inspector)
	var inspector_title := Label.new()
	inspector_title.text = "PROPERTIES / PLACEMENT PREVIEW"
	inspector.add_child(inspector_title)
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
	grid_label.text = "Cells"
	settings.add_child(grid_label)
	grid_width_field = SpinBox.new()
	grid_height_field = SpinBox.new()
	for field: SpinBox in [grid_width_field, grid_height_field]:
		field.min_value = 1
		field.max_value = 256
		field.allow_greater = true
		field.step = 1
		field.custom_minimum_size.x = 70
		field.tooltip_text = "Act dimensions in cells. Resize keeps existing content at its original coordinates."
		settings.add_child(field)
		if field == grid_width_field:
			var separator := Label.new()
			separator.text = "×"
			settings.add_child(separator)
	_button(settings, "resize_grid", "Resize", _resize_grid, "Apply width × height as one undoable edit; content is not scaled or deleted")
	var cell_label := Label.new()
	cell_label.text = "Cell size"
	settings.add_child(cell_label)
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
	connectors.add_theme_constant_override("separation", 4)
	inspector.add_child(connectors)
	connector_summary = Label.new()
	connector_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connector_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	connector_summary.add_theme_font_size_override("font_size", 13)
	connector_summary.add_theme_color_override("font_color", Color("76edab"))
	connector_summary.visible = false
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
	composite_bar = HFlowContainer.new()
	composite_bar.add_theme_constant_override("separation", 6)
	inspector.add_child(composite_bar)
	_button(composite_bar, "merge", "Merge", func(): preview_composite("merge"), "Ctrl-click filled terrain to select two or more pieces, then preview their union")
	_button(composite_bar, "smooth", "Smooth", func(): preview_composite("smooth"), "Preview conservative corner smoothing on one filled terrain piece or composite")
	_button(composite_bar, "merge_smooth", "Merge + Smooth", func(): preview_composite("merge_smooth"), "Union selected filled terrain, then smooth the resulting outline")
	_button(composite_bar, "composite_apply", "Apply", apply_composite, "Replace the selected sources in one undo step")
	_button(composite_bar, "composite_cancel", "Cancel", cancel_composite_preview, "Discard the preview; original terrain stays unchanged")
	_button(composite_bar, "composite_clear_pins", "Clear pins", _clear_composite_pins, "Release all manually protected corners in this preview")
	var sculpt_settings := VBoxContainer.new()
	sculpt_settings.add_theme_constant_override("separation", 4)
	inspector.add_child(sculpt_settings)
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
	inspector.add_child(composite_hint)
	canvas = Canvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(canvas)
	marker_reminders = VBoxContainer.new()
	marker_reminders.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	marker_reminders.offset_left = -185
	marker_reminders.offset_top = 8
	marker_reminders.offset_right = -8
	canvas.add_child(marker_reminders)
	_button(marker_reminders, "entry", "Entry: unset", func(): choose_connector("entry"), "Set the bottom entry connector")
	_button(marker_reminders, "exit", "Exit: unset", func(): choose_connector("exit"), "Set the top exit connector")
	_button(marker_reminders, "activation_reminder", "Activation trigger: unset", func(): choose_marker("activation"), "Set the activation trigger")
	_button(marker_reminders, "spawn_reminder", "Spawn point: unset", func(): choose_marker("spawn"), "Set the spawn point")
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
	canvas.preview_scale_requested.connect(_scale_preview)
	var object_properties := VBoxContainer.new()
	object_properties.add_theme_constant_override("separation", 4)
	inspector.add_child(object_properties)
	mode_label = Label.new()
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mode_label.custom_minimum_size.y = 20
	mode_label.add_theme_color_override("font_color", Color("70e5d5"))
	object_properties.add_child(mode_label)
	var angle_label := Label.new()
	angle_label.text = "Angle °"
	object_properties.add_child(angle_label)
	angle_field = LineEdit.new()
	angle_field.custom_minimum_size.x = 80
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
	mechanics_properties = HFlowContainer.new()
	mechanics_properties.add_theme_constant_override("h_separation", 10)
	inspector.add_child(mechanics_properties)
	canvas.rail_points_changed.connect(set_rail_points)
	detail_label = Label.new()
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.add_theme_color_override("font_color", Color("b5c8d6"))
	detail_label.visible = false
	inspector.add_child(detail_label)
	status_label = Label.new()
	status_label.custom_minimum_size.y = 20
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(status_label)
	var help := Label.new()
	help.text = "Ctrl-click terrain multi-select   R rotate   H / V terrain flip   Ctrl+D duplicate   Alt free move / cycle overlaps   Wheel zoom   Middle-drag pan"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color("8aa5ba"))
	help.visible = false
	status_label.tooltip_text = help.text
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
		if id == "resize_grid":
			action.call()
			canvas.grab_focus()
			return
		cell_size_field.apply()
		composite_strength.apply()
		composite_angle.apply()
		ring_spacing_field.apply()
		_commit_gameplay_angle()
		_commit_title()
		if id in ["select", "rotate", "angle_minus", "angle_plus", "flip_h", "flip_v", "delete", "duplicate", "undo", "redo", "fit", "verify"]:
			canvas.grab_focus()
		action.call())
	parent.add_child(button)
	buttons[id] = button

func _build_dialogs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEFAULT_ACT_DIRECTORY))
	save_dialog = FileDialog.new()
	save_dialog.title = "Save Act geometry"
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	load_dialog = FileDialog.new()
	load_dialog.title = "Load Act geometry"
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	for dialog in [save_dialog, load_dialog]:
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.filters = PackedStringArray(["*.tres ; Act geometry Resource"])
		dialog.current_dir = _act_directory()
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
	decor_list.add_theme_constant_override("separation", 4)
	decor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decor_list.visible = false
	decor_scroll.add_child(decor_list)
	decor_frequency_field = SpinBox.new()
	decor_frequency_field.min_value = 0
	decor_frequency_field.max_value = DecorScatter.MAX_FREQUENCY
	decor_frequency_field.step = 1
	decor_frequency_field.value = 40
	decor_frequency_field.prefix = "Frequency"
	decor_frequency_field.suffix = "%"
	decor_frequency_field.tooltip_text = "Scatter density from 0–500%, in 1% steps. Above 100% requests denser scatter; available terrain and spacing still limit the count. 0% clears scattered props. Applied when you click Randomize."
	decor_list.add_child(decor_frequency_field)
	var mix_row := HBoxContainer.new()
	decor_list.add_child(mix_row)
	decor_small_percent_field = SpinBox.new()
	decor_small_percent_field.min_value = 0
	decor_small_percent_field.max_value = 100
	decor_small_percent_field.step = 1
	decor_small_percent_field.value = 75
	decor_small_percent_field.prefix = "Small"
	decor_small_percent_field.suffix = "%"
	decor_small_percent_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decor_small_percent_field.tooltip_text = "Share of small props; the rest are medium. 0% means all medium, 100% means all small. Applied when you click Randomize."
	mix_row.add_child(decor_small_percent_field)
	decor_medium_percent_label = Label.new()
	decor_medium_percent_label.text = "Medium 25%"
	mix_row.add_child(decor_medium_percent_label)
	decor_small_percent_field.value_changed.connect(func(value): decor_medium_percent_label.text = "Medium %d%%" % (100 - roundi(value)))
	_button(decor_list, "decor_randomize", "Randomize small / medium", randomize_decor, "Replace scattered decor using the chosen size mix where space permits. Varies scale and rotation; preserves manual props. One Undo step.")
	decor_list.add_child(HSeparator.new())
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
	# A hand edit or duplicate claims a scattered slot as manual decoration.
	value.erase("placement_source")
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

func randomize_decor() -> void:
	if composite_preview_active: return
	canvas.cancel_gesture()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var generated := DecorScatter.generate(document, decor_frequency_field.value, rng.randi(), decor_small_percent_field.value)
	var kept: Array = []
	for slot: Dictionary in document.decor_slots:
		if not DecorScatter.is_scattered(slot): kept.append(slot)
	if generated.is_empty() and kept.size() == document.decor_slots.size():
		_set_status("No free raised terrain for this frequency. Manual decor stays unchanged.")
		return
	_record_edit()
	if document.decor_seed.is_empty() and not generated.is_empty(): document.decor_seed = Decor.new_id()
	document.decor_slots = kept + generated
	canvas.select_piece(-1)
	canvas.show_decor = true
	var small_count := 0
	for slot: Dictionary in generated:
		if slot.slot_type == "small": small_count += 1
	_set_status("Scattered %d small + %d medium props. Manual decor kept. Randomize rerolls; Undo restores. Edit a scattered prop to keep it." % [small_count, generated.size() - small_count])
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
	decor_frequency_field.editable = not composite_preview_active
	decor_small_percent_field.editable = not composite_preview_active
	buttons.decor_randomize.disabled = composite_preview_active
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
		if DecorScatter.is_scattered(slot):
			decor_info.text = "Scattered prop: Randomize replaces it.\nEdit or duplicate it to keep it manually.\n\n" + decor_info.text
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
	gameplay_scroll.visible = index == 1
	gameplay_list.visible = index == 1
	marker_list.visible = index == 2
	decor_list.visible = index == 3
	decor_scroll.visible = index == 3
	rings_scroll.visible = index == 4
	palette_heading.text = ["TERRAIN LIBRARY  /  %d stamps" % Shapes.definitions().size(), "GAMEPLAY  /  %d objects" % Objects.definitions().size(), "ACT MARKERS  /  4 tools", "DECOR  /  4 generic slots", "RINGS  /  Line + Circle"][index]
	if index == 3 and canvas.selected_decor_index >= 0: _refresh()
	else: _select_mode()

func choose_rings() -> void:
	canvas.grab_focus()
	canvas.ring_kind = "line"
	canvas.set_ring_tool()
	_set_status("Rings: click for one; drag in any direction for a trail. Alt frees endpoints. One drag = one undo.")
	_refresh()

func choose_ring_circle() -> void:
	canvas.grab_focus()
	canvas.ring_kind = "ellipse"
	canvas.set_ring_tool()
	_set_status("Circle / Ellipse: drag opposite bounds corners. Fill uses deterministic hex rows. Release commits one edit.")
	_refresh()

func _change_ring_pattern(key: String, value: Variant) -> void:
	if _refreshing: return
	if key == "fill": canvas.ring_fill = value
	else: canvas.ring_rotation = value
	if canvas.selected_ring_index >= 0:
		var trail: Dictionary = document.ring_trails[canvas.selected_ring_index].duplicate(true)
		if trail.get("kind") == "ellipse":
			trail[key] = value
			set_ring_trail(canvas.selected_ring_index, trail)
	canvas.queue_redraw()

func _change_ring_radius(axis: int, value: float) -> void:
	if _refreshing: return
	canvas.ring_radii[axis] = value
	if canvas.selected_ring_index < 0: return
	var trail: Dictionary = document.ring_trails[canvas.selected_ring_index].duplicate(true)
	if trail.get("kind") != "ellipse": return
	var center: Vector2 = (trail.start + trail.end) * 0.5
	var radii: Vector2 = (trail.end - trail.start).abs() * 0.5
	radii[axis] = value
	trail.start = center - radii
	trail.end = center + radii
	set_ring_trail(canvas.selected_ring_index, trail)

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
	_set_status("%d rings in one pattern. Select / Move to drag the group or its bounds handles." % Rings.positions(trail).size())
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
	_set_status("Ctrl-click selects terrain for Merge or switches for a Bank. Alt-click cycles overlaps. Drag to move.")
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
	placement = placement.duplicate(true)
	placement["object_id"] = Objects.new_id()
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
	if canvas.selected_gameplay_indices.size() > 1: return {}
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
		var indices: Array[int] = canvas.selected_gameplay_indices.duplicate()
		var ids: Array = []
		for index: int in indices: ids.append(Objects.identity(document.gameplay_objects[index], index))
		Banks.remove_objects(document.switch_banks, ids)
		indices.sort()
		indices.reverse()
		for index: int in indices: document.gameplay_objects.remove_at(index)
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
		"gameplay_selection": canvas.selected_gameplay_indices.duplicate(), "bank": selected_bank_id,
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
	selected_bank_id = snapshot.get("bank", "")
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
		var indices: Array[int] = []
		indices.assign(snapshot.get("gameplay_selection", [snapshot.gameplay]))
		canvas.set_gameplay_selection(indices)
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
	selected_bank_id = ""
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
	selected_bank_id = ""
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
		"load":
			load_dialog.current_dir = _act_directory()
			load_dialog.popup_centered()
		"quit": get_tree().quit()
		"example", "gimmicks":
			if load_from("res://data/acts/switch_gate_spring.tres" if action == "gimmicks" else EXAMPLE_PATH):
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
		save_dialog.current_dir = _act_directory()
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

func _resize_grid() -> void:
	if _refreshing or document == null or composite_preview_active:
		return
	grid_width_field.apply()
	grid_height_field.apply()
	var dimensions := Vector2i(int(grid_width_field.value), int(grid_height_field.value))
	if dimensions == document.grid_size:
		return
	var candidate: Resource = document.copy_document()
	candidate.grid_size = dimensions
	var errors: PackedStringArray = candidate.validation_errors()
	if not errors.is_empty():
		_refresh()
		_set_status("Grid size unchanged: " + errors[0])
		return
	canvas.cancel_gesture()
	_record_edit()
	document.grid_size = dimensions
	_refresh()
	canvas.fit_view()
	_set_status("Act resized to %d × %d cells. Existing content remains at its original coordinates." % [dimensions.x, dimensions.y])

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
	grid_width_field.set_value_no_signal(document.grid_size.x)
	grid_height_field.set_value_no_signal(document.grid_size.y)
	_refresh_reminders()
	_refresh_file_state()
	buttons.undo.disabled = undo_stack.is_empty()
	buttons.redo.disabled = redo_stack.is_empty()
	buttons.delete.disabled = canvas.selected_decor_index < 0 and canvas.selected_index < 0 and canvas.selected_gameplay_index < 0 and canvas.selected_ring_index < 0 and canvas.selected_connector.is_empty() and canvas.selected_marker.is_empty()
	buttons.duplicate.disabled = canvas.selected_decor_index < 0 and canvas.selected_gameplay_index < 0 and canvas.selected_ring_index < 0 and _terrain_selection().size() != 1
	if canvas.selected_gameplay_indices.size() > 1: buttons.duplicate.disabled = true
	var ring_spacing: float = document.ring_trails[canvas.selected_ring_index].spacing / float(document.cell_size) if canvas.selected_ring_index >= 0 else canvas.ring_spacing_cells
	ring_spacing_field.set_value_no_signal(ring_spacing)
	var selected_pattern: Dictionary = document.ring_trails[canvas.selected_ring_index] if canvas.selected_ring_index >= 0 else {}
	ring_ellipse_settings.visible = selected_pattern.get("kind", canvas.ring_kind) == "ellipse"
	ring_fill_field.set_pressed_no_signal(selected_pattern.get("fill", canvas.ring_fill))
	ring_rotation_field.set_value_no_signal(selected_pattern.get("rotation_degrees", canvas.ring_rotation))
	var radii: Vector2 = (selected_pattern.end - selected_pattern.start).abs() * 0.5 if selected_pattern.get("kind") == "ellipse" else canvas.ring_radii
	for axis in 2: ring_radius_fields[axis].set_value_no_signal(radii[axis])
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
	handedness_field.visible = not handedness_field.disabled
	handedness_field.select(1 if not gameplay.is_empty() and gameplay.type == "right_flipper" else 0)
	if not decor.is_empty():
		mode_label.text = ("PLACE" if not canvas.decor_brush.is_empty() else "SELECTED") + " · " + decor.slot_type.capitalize() + " decor"
		var variant := "Variant %d" % (int(decor.get("variant_index", 0)) + 1) if decor.get("variant_mode", "auto") == "fixed" else "Auto variant"
		detail_label.text = "%s px · %s° · %s · %s · Presentation only" % [decor.position, var_to_str(decor.rotation_degrees), decor.placement_hint, variant]
	elif canvas.ring_tool or canvas.selected_ring_index >= 0:
		mode_label.text = "DRAW RINGS" if canvas.ring_tool else "SELECTED  ·  Ring pattern"
		detail_label.text = "Click / drag · Alt frees bounds · Generated rings never snap · Select pattern to move or resize · Delete removes pattern"
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
	elif canvas.selected_gameplay_indices.size() > 1:
		mode_label.text = "%d GAMEPLAY OBJECTS SELECTED" % canvas.selected_gameplay_indices.size()
		detail_label.text = "Ctrl-click toggles selection · Gameplay palette: Create Switch Bank · Delete removes selected objects"
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
	mode_label.tooltip_text = detail_label.text
	_refresh_composite_controls()
	_refresh_decor_controls()
	_refresh_mechanics_properties()
	_refresh_banks()
	canvas.queue_redraw()
	_refreshing = false

func _refresh_composite_controls() -> void:
	var terrain_context: bool = composite_preview_active or not _active_terrain().is_empty() or (palette_tabs.current_tab == 0 and _active_gameplay().is_empty() and canvas.selected_gameplay_indices.is_empty() and canvas.selected_ring_index < 0)
	composite_bar.visible = terrain_context
	composite_strength.get_parent().visible = terrain_context
	composite_hint.visible = terrain_context
	terrain_snap_field.visible = terrain_context
	terrain_scale_field.visible = terrain_context
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
	grid_width_field.editable = not composite_preview_active
	grid_height_field.editable = not composite_preview_active
	buttons.resize_grid.disabled = composite_preview_active
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
	return (verify_dialog != null and verify_dialog.visible) or save_dialog.visible or load_dialog.visible or unsaved_dialog.visible or error_dialog.visible

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
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

func set_gameplay_property(key: String, value: Variant) -> void:
	var placement := _active_gameplay()
	if placement.is_empty(): return
	var candidate := placement.duplicate(true)
	candidate["properties"] = Objects.properties(placement)
	candidate.properties[key] = value
	var errors := Objects.property_errors(candidate)
	if not errors.is_empty():
		_set_status(" ".join(errors))
		return
	if candidate.properties == placement.get("properties", {}): return
	if canvas.gameplay_brush.is_empty(): _record_edit()
	placement["properties"] = candidate.properties
	_refresh()

func set_rail_points(points: PackedVector2Array) -> void:
	set_gameplay_property("points", points)

func _refresh_mechanics_properties() -> void:
	if mechanics_properties == null: return
	for child in mechanics_properties.get_children():
		mechanics_properties.remove_child(child)
		child.queue_free()
	var item := _active_gameplay()
	mechanics_properties.visible = not item.is_empty() and canvas.selected_gameplay_indices.size() <= 1
	if not mechanics_properties.visible: return
	for axis: String in ["x", "y"]:
		_mechanic_number(axis.to_upper() + " px", item.position[axis], func(value: float):
			var at: Vector2 = item.position
			at[axis] = value
			if canvas.gameplay_brush.is_empty(): move_gameplay_placement(canvas.selected_gameplay_index, at)
			else:
				item.position = at
				_refresh())
	if not canvas.gameplay_brush.is_empty():
		var hint := Label.new()
		hint.text = "Preview only · click the map to place.\nShift + wheel resizes supported objects."
		hint.add_theme_font_size_override("font_size", 11)
		mechanics_properties.add_child(hint)
	if item.type in ["left_flipper", "right_flipper", "round_bumper", "triangle_bumper"]:
		var baseline := Label.new()
		var profile: Resource = preload("res://data/balanced.tres")
		baseline.text = "Sonic: tip assist %.0f · upward cap %.0f*" % [profile.flipper_launch_strength, profile.flipper_upward_speed_limit] if item.type in ["left_flipper", "right_flipper"] else "Sonic rebound: %.0f–%.0f px/s" % [profile.bumper_launch_speed * profile.bumper_rebound_multiplier, profile.bumper_speed_limit * profile.bumper_rebound_multiplier]
		baseline.tooltip_text = "Base Sonic, no modifiers. Flipper upward cap additionally scales with the square root of ball size. Runtime retains the selected character and session tuning."
		baseline.add_theme_font_size_override("font_size", 11)
		mechanics_properties.add_child(baseline)
	if item.type in ["left_flipper", "right_flipper"]:
		var guide := OptionButton.new()
		guide.name = "LaunchGuideMode"
		guide.add_item("Guide: Drop from spawn")
		guide.add_item("Guide: Typical catch")
		guide.select(0 if canvas.launch_from_spawn else 1)
		guide.item_selected.connect(func(index: int):
			canvas.launch_from_spawn = index == 0
			_refresh_mechanics_properties()
			canvas.queue_redraw())
		mechanics_properties.add_child(guide)
		if canvas.launch_from_spawn:
			var contact := OptionButton.new()
			contact.name = "LaunchContactPosition"
			for percent in range(10, 101, 10):
				contact.add_item("Contact: %d%%%s" % [percent, " (tip)" if percent == 100 else (" (middle)" if percent == 50 else "")])
			contact.select(clampi(roundi(canvas.launch_contact_fraction * 10.0) - 1, 0, 9))
			contact.tooltip_text = "Let the ball land and move along the flipper, then press near this position. The guide reports the actual strike position; unreachable contacts show no arc. No steering is applied."
			contact.item_selected.connect(func(index: int):
				canvas.launch_contact_fraction = (index + 1) / 10.0
				canvas.queue_redraw())
			mechanics_properties.add_child(contact)
		else:
			var timings := CheckButton.new()
			timings.text = "Early / late timing"
			timings.button_pressed = canvas.launch_timing_variants
			timings.tooltip_text = "Show two timing variants alongside the typical falling catch. These are example contacts, not guaranteed range limits."
			timings.toggled.connect(func(value: bool):
				canvas.launch_timing_variants = value
				canvas.queue_redraw())
			mechanics_properties.add_child(timings)
	var properties := Objects.properties(item)
	var identity := Label.new()
	identity.text = "ID"
	identity.tooltip_text = str(item.get("object_id", "Unsaved brush")) + "\nStable object ID used by switch banks. Duplicating creates a new identity."
	identity.add_theme_font_size_override("font_size", 11)
	mechanics_properties.add_child(identity)
	for key: String in Objects.property_limits(item.type):
		_mechanic_number(key.replace("_", " ").capitalize(), float(properties[key]), func(value: float): set_gameplay_property(key, value))
	if item.type == "one_way_gate":
		_mechanic_choice("Initial", "initial_state", ["closed", "open"], properties.initial_state)
		var visual := Label.new()
		visual.text = "Theme: Auto · Arrow: allowed direction"
		mechanics_properties.add_child(visual)
	if item.type in ["switch_target", "wall_switch", "spring"]:
		_mechanic_choice("Color", "color", ["red", "yellow", "blue"] if item.type == "spring" else ["blue", "red", "yellow", "green"], properties.color)
	if item.type in ["switch_target", "wall_switch"]:
		var label := LineEdit.new()
		label.placeholder_text = "Optional switch label"
		label.text = properties.label
		label.max_length = 80
		label.custom_minimum_size.x = 140
		label.text_submitted.connect(func(value: String): set_gameplay_property("label", value); canvas.grab_focus())
		label.focus_exited.connect(func():
			if label.text != properties.label: set_gameplay_property("label", label.text))
		mechanics_properties.add_child(label)
	if item.type == "spring":
		var profile := OptionButton.new()
		profile.add_item("Arc: Balanced")
		profile.add_item("Arc: Floaty")
		profile.select(1 if is_equal_approx(canvas.trajectory_gravity_scale, preload("res://data/floaty.tres").gravity_scale) else 0)
		profile.item_selected.connect(func(index: int):
			var selected_profile: Resource = load("res://data/floaty.tres" if index == 1 else "res://data/balanced.tres")
			canvas.trajectory_gravity_scale = selected_profile.gravity_scale
			canvas.queue_redraw())
		mechanics_properties.add_child(profile)
		detail_label.text = "Instant launch · Color is cosmetic · Arc: 2 seconds, no collisions / steering / modifiers · Dots every 0.25 s"
	if item.type == "magnetic_field":
		var mode := OptionButton.new()
		mode.add_item("Attract")
		mode.add_item("Repel")
		mode.select(1 if properties.mode == "repel" else 0)
		mode.item_selected.connect(func(index: int): set_gameplay_property("mode", "repel" if index == 1 else "attract"))
		mechanics_properties.add_child(mode)
	if item.type == "lane_barrier":
		_mechanic_choice("Reward", "reward_type", ["score", "rings"], properties.reward_type)
		_mechanic_choice("Completion", "completion_mode", ["off", "light_all"], properties.completion_mode)
	if item.type == "diverter":
		_mechanic_choice("Initial", "initial_state", ["a", "b"], properties.initial_state)
		detail_label.text = "Physical routing arm · Bank links: Set A / Set B / Toggle · Changes wait for a clear ball sweep."
	if item.type == "dash_panel":
		detail_label.text = "Adds speed on entry · Influence 0% preserves direction; 100% follows arrow · Full departure rearms · Cap applies to total speed."
	if item.type == "wall_switch":
		detail_label.text = "Anchor on wall face · Arrow faces exposed side · Front impacts only · Shares floor-switch banks."
	if item.type in ["elevated_rail", "lane_barrier"]:
		var edit := CheckButton.new()
		edit.text = "Edit posts" if item.type == "lane_barrier" else "Edit path points"
		edit.disabled = not canvas.gameplay_brush.is_empty()
		edit.set_pressed_no_signal(canvas.rail_edit)
		edit.toggled.connect(func(enabled: bool): canvas.rail_edit = enabled; canvas.queue_redraw(); canvas.grab_focus())
		mechanics_properties.add_child(edit)
		detail_label.text = "Click posts (2–12); Enter commits; Esc / right-click cancels. Edit posts: drag, click appends, Shift-click inserts, right-click removes. Alt frees coordinates." if item.type == "lane_barrier" else "Click entry and path points; Enter finishes. Edit path: drag points, click appends, Shift-click inserts, right-click removes. Alt frees placement."

func _mechanic_number(label_text: String, value: float, action: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	mechanics_properties.add_child(label)
	var field := LineEdit.new()
	var original := var_to_str(value)
	field.text = original
	field.custom_minimum_size.x = 70
	var commit := func():
		var value_text := field.text.strip_edges()
		if value_text == original: return
		if value_text.is_valid_float() and is_finite(value_text.to_float()): action.call(value_text.to_float())
		else: _set_status("Enter a finite numeric value.")
	field.text_submitted.connect(func(_text): commit.call(); canvas.grab_focus())
	field.focus_exited.connect(commit)
	mechanics_properties.add_child(field)

func _mechanic_choice(label_text: String, key: String, choices: Array, value: String) -> void:
	var field := OptionButton.new()
	for choice: String in choices: field.add_item(label_text + ": " + choice.capitalize())
	field.select(choices.find(value))
	field.item_selected.connect(func(index: int): set_gameplay_property(key, choices[index]))
	mechanics_properties.add_child(field)

func _selected_switch_ids() -> Array:
	var result: Array = []
	for index: int in canvas.selected_gameplay_indices:
		var item: Dictionary = document.gameplay_objects[index]
		if item.type not in ["switch_target", "wall_switch"]: return []
		result.append(Objects.identity(item, index))
	return result

func create_switch_bank() -> void:
	var members := _selected_switch_ids()
	if members.size() < 2: return
	_record_edit()
	selected_bank_id = "bank_" + Objects.new_id()
	document.switch_banks.append({"bank_id": selected_bank_id, "label": "Bank %d" % (document.switch_banks.size() + 1), "members": members, "gates": [], "actions": [], "completion_bonus": 0.0, "reset_delay": 0.0})
	_refresh()
	_set_status("Bank created. Link gates or diverters below. Each action runs when every member is pressed.")

func set_bank_action(bank_id: String, object_id: String, action: String) -> void:
	for bank: Dictionary in document.switch_banks:
		if bank.bank_id != bank_id: continue
		var next: Dictionary = bank.duplicate(true)
		next.gates.erase(object_id)
		next["actions"] = next.get("actions", []).filter(func(link): return link.object_id != object_id)
		if not action.is_empty(): next.actions.append({"object_id": object_id, "action": action})
		if next == bank: return
		if not Banks.validation_errors([next], document.gameplay_objects).is_empty(): return
		_record_edit()
		bank.merge(next, true)
		_refresh()
		return

func set_bank_gates(bank_id: String, gates: Array) -> void:
	for bank: Dictionary in document.switch_banks:
		if bank.bank_id != bank_id or bank.gates == gates: continue
		var candidate: Resource = document.copy_document()
		for other: Dictionary in candidate.switch_banks:
			if other.bank_id == bank_id: other.gates = gates.duplicate()
		if not Banks.validation_errors(candidate.switch_banks, candidate.gameplay_objects).is_empty(): return
		_record_edit()
		bank.gates = gates.duplicate()
		_refresh()
		return

func _refresh_banks() -> void:
	for child in bank_controls.get_children():
		bank_controls.remove_child(child)
		child.queue_free()
	var create := Button.new()
	create.text = "Create Switch Bank (%d selected)" % canvas.selected_gameplay_indices.size()
	create.disabled = _selected_switch_ids().size() < 2
	create.tooltip_text = "Select / Move, then Ctrl-click several switches."
	create.pressed.connect(create_switch_bank)
	bank_controls.add_child(create)
	if document.switch_banks.is_empty(): return
	var picker := OptionButton.new()
	picker.add_item("Select a switch bank…")
	var active: Dictionary = {}
	for i in document.switch_banks.size():
		var bank: Dictionary = document.switch_banks[i]
		picker.add_item(bank.label)
		if bank.bank_id == selected_bank_id:
			picker.select(i + 1)
			active = bank
	picker.item_selected.connect(func(index: int):
		selected_bank_id = document.switch_banks[index - 1].bank_id if index > 0 else ""
		_refresh())
	bank_controls.add_child(picker)
	if active.is_empty(): return
	var label := LineEdit.new()
	label.text = active.label
	label.max_length = 80
	var commit_label := func():
		if label.text != active.label:
			_record_edit()
			active.label = label.text
			_refresh()
	label.text_submitted.connect(func(_value: String): commit_label.call(); canvas.grab_focus())
	label.focus_exited.connect(commit_label)
	bank_controls.add_child(label)
	var help := Label.new()
	help.text = "%d switches · Completion actions:" % active.members.size()
	help.add_theme_font_size_override("font_size", 12)
	bank_controls.add_child(help)
	for i in document.gameplay_objects.size():
		var item: Dictionary = document.gameplay_objects[i]
		if item.type not in ["one_way_gate", "diverter"]: continue
		var id := Objects.identity(item, i)
		var target := Label.new()
		target.text = "%s %d · %s" % ["Gate" if item.type == "one_way_gate" else "Diverter", i + 1, item.position]
		target.tooltip_text = id
		bank_controls.add_child(target)
		var action := OptionButton.new()
		var choices: Array = ["", "open"] if item.type == "one_way_gate" else ["", "set_a", "set_b", "toggle"]
		for choice: String in choices: action.add_item("No link" if choice.is_empty() else choice.replace("_", " ").capitalize())
		for link: Dictionary in Banks.actions(active):
			if link.object_id == id: action.select(choices.find(link.action))
		action.item_selected.connect(func(index: int): set_bank_action(active.bank_id, id, choices[index]))
		bank_controls.add_child(action)
	for key: String in ["completion_bonus", "reset_delay"]:
		var row := HBoxContainer.new()
		bank_controls.add_child(row)
		var caption := Label.new()
		caption.text = "Bonus" if key == "completion_bonus" else "Reset seconds (0: off)"
		row.add_child(caption)
		var value := LineEdit.new()
		value.text = str(active.get(key, 0.0))
		value.custom_minimum_size.x = 55
		row.add_child(value)
		var commit := func():
			if not value.text.is_valid_float(): return
			var next: Dictionary = active.duplicate(true)
			next[key] = value.text.to_float()
			if not Banks.validation_errors([next], document.gameplay_objects).is_empty() or next == active: return
			_record_edit()
			active[key] = next[key]
			_refresh()
		value.text_submitted.connect(func(_text): commit.call(); canvas.grab_focus())
		value.focus_exited.connect(commit)
	var replace_members := Button.new()
	replace_members.text = "Use selected switches as members"
	replace_members.disabled = _selected_switch_ids().is_empty()
	replace_members.pressed.connect(func():
		_record_edit()
		active.members = _selected_switch_ids()
		_refresh())
	bank_controls.add_child(replace_members)
	var remove := Button.new()
	remove.text = "Dissolve bank (keep objects)"
	remove.pressed.connect(func():
		_record_edit()
		document.switch_banks.erase(active)
		selected_bank_id = ""
		_refresh())
	bank_controls.add_child(remove)

func _toggle_fullscreen() -> void:
	get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func _refresh_reminders() -> void:
	var values := {
		"entry": ["Entry", document.entry_width > 0],
		"exit": ["Exit", document.exit_width > 0],
		"activation_reminder": ["Activation trigger", document.activation_y != null],
		"spawn_reminder": ["Spawn point", document.spawn_position != null],
	}
	for key: String in values:
		var value: Array = values[key]
		buttons[key].text = value[0] + (": set" if value[1] else ": unset")
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			buttons[key].add_theme_color_override(state, Color("76edab") if value[1] else Color("ff858e"))

func verification_report() -> Dictionary:
	var errors: PackedStringArray = document.validation_errors()
	var warnings := PackedStringArray()
	if document.entry_width == 0: warnings.append("Entry connector is unset.")
	if document.exit_width == 0: warnings.append("Exit connector is unset.")
	if document.activation_y == null: warnings.append("Activation trigger is unset.")
	if not errors.is_empty(): return {"errors": errors, "warnings": warnings}
	var candidate: Resource = document.duplicate(true)
	if candidate.spawn_position == null:
		errors.append("Spawn point is unset: the Act cannot be played.")
		# Still check ramp geometry, without changing the authored document.
		candidate.spawn_position = Vector2.ZERO
	var tuning := PhysicsTuning.new()
	var controls := PlaygroundInput.new()
	var ball := PlaygroundBall.new()
	var compiled := AuthoredActRuntimeCompiler.compile(candidate, tuning, controls, ball)
	if not compiled.error.is_empty():
		var message: String = compiled.error
		for index in document.gameplay_objects.size():
			var item: Dictionary = document.gameplay_objects[index]
			message = message.replace(Objects.identity(item, index), "#%d at %s" % [index + 1, item.position])
		errors.append(message)
	if is_instance_valid(compiled.root): compiled.root.free()
	ball.free()
	controls.free()
	tuning.free()
	return {"errors": errors, "warnings": warnings}

func verify_document() -> void:
	var report := verification_report()
	if verify_dialog == null:
		verify_dialog = AcceptDialog.new()
		verify_dialog.title = "Verify Act"
		verify_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		verify_dialog.get_label().custom_minimum_size.x = 680
		add_child(verify_dialog)
	var lines := PackedStringArray()
	lines.append("Runtime checks passed." if report.errors.is_empty() else "Fix these before playing:")
	lines.append_array(report.errors)
	if not report.warnings.is_empty():
		lines.append("\nAuthoring reminders:")
		lines.append_array(report.warnings)
	lines.append("\nChecks data, switch links and runtime ramp clearance. Does not prove reachability or gameplay difficulty.")
	verify_dialog.dialog_text = "\n".join(lines)
	verify_dialog.popup_centered(Vector2i(720, 360))

func _scale_preview(direction: float) -> void:
	if canvas.gameplay_brush.is_empty(): return
	var item: Dictionary = canvas.gameplay_brush
	var key: String = {"one_way_gate": "width", "spinner": "width", "magnetic_field": "radius", "round_bumper": "scale", "triangle_bumper": "scale", "switch_target": "scale"}.get(item.type, "")
	if key.is_empty(): return
	var limits: Array = Objects.property_limits(item.type)[key]
	var step := 0.1 if key == "scale" else 5.0
	var value := clampf(float(Objects.properties(item)[key]) + step * direction, limits[0], limits[1])
	set_gameplay_property(key, value)
	_set_status("Preview %s: %s %.2f · Shift + wheel resizes; click to place" % [Objects.get_definition(item.type).label, key, value])


func _bake_current() -> void:
	if current_path.is_empty() or is_dirty():
		_set_status("Save your verified Act before baking. Baking never changes the source document.")
		return
	var arguments := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"),
		"res://scenes/act_baker.tscn", "--", "--act=" + ProjectSettings.globalize_path(current_path)])
	if not OS.has_feature("editor"):
		arguments = PackedStringArray(["--", "--portable-bake", "--act=" + ProjectSettings.globalize_path(current_path)])
	var process := OS.create_process(OS.get_executable_path(), arguments)
	_set_status("Baking opened in a separate progress window." if process >= 0 else "Could not open the Act baker.")


func _act_directory() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(DEFAULT_ACT_DIRECTORY)
	var directory := OS.get_executable_path().get_base_dir().path_join("Acts")
	if DirAccess.make_dir_recursive_absolute(directory) == OK:
		return directory
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)


func _play_current() -> void:
	if current_path.is_empty() or is_dirty():
		_set_status("Save your Act before playing, then click Play again.")
		return
	var arguments := PackedStringArray(["--rendering-method", "gl_compatibility",
		"--rendering-driver", "opengl3_angle"])
	if OS.has_feature("editor"):
		arguments.append_array(["--path", ProjectSettings.globalize_path("res://")])
		arguments.append_array(["res://experiments/visual_lab/visual_lab.tscn", "--"])
	else:
		arguments.append_array(["--", "--portable-play"])
	arguments.append_array(["--act", ProjectSettings.globalize_path(current_path)])
	var process := OS.create_process(OS.get_executable_path(), arguments)
	_set_status("Playtest opened. Save edits here, then use Reload Act in the game." if process >= 0 else "Could not open the Act player.")
