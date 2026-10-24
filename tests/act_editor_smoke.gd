extends SceneTree
## Run headless for interaction checks, or graphically for test-results/act-editor.png.
## Pointer and shortcut probes pass through Viewport input dispatch, not editor callbacks.

const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const EditorScene = preload("res://scenes/act_geometry_editor.tscn")
const SAVE_PATH := "res://test-results/act-editor-smoke.tres"
var editor: Control
var checks := 0
var failures := 0
var mouse_position := Vector2.ZERO


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS | " + label)
	else:
		failures += 1
		push_error("FAIL | " + label)


func move_pointer(position: Vector2, held := false, viewport: Viewport = null) -> void:
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(position)
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - mouse_position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	# Godot's drag/drop lookup reads Input's mouse position between events.
	# Populate that state as well as dispatching exact viewport-local test coordinates.
	var state_event := event.duplicate()
	state_event.position = root.get_final_transform() * position
	state_event.global_position = state_event.position
	Input.parse_input_event(state_event)
	(viewport if viewport != null else root).push_input(event, true)
	mouse_position = position
	await process_frame


func mouse_button(position: Vector2, pressed: bool, alt := false, viewport: Viewport = null) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.alt_pressed = alt
	(viewport if viewport != null else root).push_input(event, true)
	await process_frame


func click_at(position: Vector2, alt := false, viewport: Viewport = null) -> void:
	await move_pointer(position, false, viewport)
	await mouse_button(position, true, alt, viewport)
	await mouse_button(position, false, alt, viewport)


func click_control(control: Control) -> void:
	await process_frame
	await process_frame
	if control.get_viewport() != root:
		await click_at(control.get_global_rect().get_center() + Vector2(control.get_window().position))
	else:
		await click_at(control.get_global_rect().get_center())


func press_key(code: int, command := false, shift := false, viewport: Viewport = null) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = command
	event.shift_pressed = shift
	(viewport if viewport != null else root).push_input(event, true)
	await process_frame
	event.pressed = false
	(viewport if viewport != null else root).push_input(event, true)
	await process_frame


func type_text(value: String) -> void:
	for character in value:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.pressed = true
		root.push_input(event, true)
		await process_frame
		event.pressed = false
		root.push_input(event, true)


func grid_position(point: Vector2) -> Vector2:
	return editor.canvas.global_position + editor.canvas.grid_to_screen(point)


func show_palette_item(id: String) -> Control:
	var item: Control = editor.palette_buttons[id]
	var parent := item.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if parent is ScrollContainer:
		parent.ensure_control_visible(item)
	await process_frame
	await process_frame
	return item


func choose_palette(id: String) -> void:
	var item: Control = await show_palette_item(id)
	await click_control(item)


func find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label:
		return node
	for child in node.get_children(true):
		var result := find_button(child, label)
		if result != null:
			return result
	return null


func discard_pending() -> void:
	var discard := find_button(editor.unsaved_dialog, "Discard")
	check(discard != null, "Unsaved dialog offers an explicit Discard action")
	if discard != null:
		await click_control(discard)


func close_file_dialog(_dialog: FileDialog) -> void:
	await press_key(KEY_ESCAPE)
	await process_frame


func check_palette_and_overlap() -> void:
	check(editor.document.grid_size == Vector2i(12, 12) and editor.document.placements.is_empty() and not editor.is_dirty(), "New scene edits one clean 12×12 Act")
	check(editor.palette_buttons.size() == 52, "All 52 canonical stamps have visible palette entries")
	var definitions: Array = Shapes.definitions()
	for definition: Dictionary in definitions:
		await choose_palette(definition.id)
		await click_at(grid_position(Vector2(1.2, 1.3)))
	var complete: bool = editor.document.placements.size() == definitions.size()
	if complete:
		for index in definitions.size():
			var placement: Dictionary = editor.document.placements[index]
			complete = complete and placement.shape_id == definitions[index].id and placement.anchor == Vector2i(1, 1)
	check(complete, "Actual palette clicks place every shape at the same snapped anchor; overlaps remain independent")
	check(editor.is_dirty() and editor.file_label.text.contains("Unsaved"), "Placed geometry visibly marks the document dirty")
	var before: String = editor.document.fingerprint()
	await click_control(editor.buttons.new)
	check(editor.unsaved_dialog.visible, "New Act asks before replacing unsaved geometry")
	await click_control(editor.unsaved_dialog.get_cancel_button())
	check(not editor.unsaved_dialog.visible and editor.document.fingerprint() == before, "Cancel preserves every placed shape")
	await press_key(KEY_N, true)
	await discard_pending()
	check(editor.document.placements.is_empty() and editor.undo_stack.is_empty() and editor.redo_stack.is_empty() and not editor.is_dirty(), "Discard then New clears geometry and history")


func check_edit_gestures() -> void:
	await choose_palette("triangle_1x3")
	await click_at(grid_position(Vector2(1.2, 2.2)))
	await click_at(grid_position(Vector2(3.1, 2.1)))
	check(editor.document.placements.size() == 2 and editor.document.placements[0].anchor == Vector2i(1, 2), "Repeated stamps snap to nearest integer grid anchors")
	await press_key(KEY_R)
	await press_key(KEY_H)
	await press_key(KEY_V)
	await click_at(grid_position(Vector2(5.2, 1.1)))
	check(editor.document.placements.size() == 3, "Transformed brush places a third independent stamp")
	if editor.document.placements.size() < 3:
		return
	var placed: Dictionary = editor.document.placements[2]
	check(placed.quarter_turns == 1 and placed.flip_h and placed.flip_v and Shapes.transformed_size(placed) == Vector2i(3, 1), "R/H/V shortcuts transform actual placement and swap 1×3 to 3×1")
	await press_key(KEY_ESCAPE)
	var center := Vector2(placed.anchor) + Vector2(2.0, 2.0 / 3.0)
	await click_at(grid_position(center))
	check(editor.canvas.selected_index == 2, "Clicking actual triangle fill selects the placed shape")
	await click_control(editor.buttons.rotate)
	await click_control(editor.buttons.flip_h)
	await click_control(editor.buttons.flip_v)
	placed = editor.document.placements[2]
	check(placed.quarter_turns == 2 and not placed.flip_h and not placed.flip_v and Shapes.transformed_size(placed) == Vector2i(1, 3), "Toolbar transforms selected geometry and footprint")
	center = Vector2(placed.anchor) + Vector2(2.0 / 3.0, 1.0)
	var drag_start := grid_position(center)
	var old_anchor: Vector2i = placed.anchor
	var history_size: int = editor.undo_stack.size()
	await move_pointer(drag_start)
	await mouse_button(drag_start, true)
	await move_pointer(grid_position(center + Vector2(0.7, 0.8)), true)
	await move_pointer(grid_position(center + Vector2(1.6, 2.3)), true)
	check(editor.document.placements[2].anchor == old_anchor, "Drag preview leaves saved authoring data untouched until release")
	await mouse_button(grid_position(center + Vector2(1.6, 2.3)), false)
	check(editor.document.placements[2].anchor == old_anchor + Vector2i(2, 2) and editor.undo_stack.size() == history_size + 1, "Drag snaps once on release and creates one undo step")
	await press_key(KEY_Z, true)
	check(editor.document.placements[2].anchor == old_anchor, "Ctrl+Z restores the entire drag")
	await press_key(KEY_Y, true)
	check(editor.document.placements[2].anchor == old_anchor + Vector2i(2, 2), "Ctrl+Y restores the snapped move")
	await press_key(KEY_LEFT)
	check(editor.document.placements[2].anchor == old_anchor + Vector2i(1, 2), "Arrow key moves selected terrain exactly one cell")
	var before_delete: String = editor.document.fingerprint()
	await press_key(KEY_DELETE)
	check(editor.document.placements.size() == 2, "Delete shortcut removes selected terrain")
	await press_key(KEY_Z, true)
	check(editor.document.fingerprint() == before_delete, "Undo restores deleted shape and exact transforms")
	await choose_palette("rectangle_1x1")
	var count: int = editor.document.placements.size()
	await click_at(editor.canvas.global_position + Vector2(6, 6))
	check(editor.document.placements.size() == count, "Clicks outside the Act grid do not place stamps")
	await click_at(grid_position(Vector2(11.9, 11.9)))
	check(editor.document.placements[-1].anchor == Vector2i(11, 11), "Bottom/right placement clamps to a legal integer anchor")
	await choose_palette("triangle_1x3")
	await click_control(editor.buttons.flip_h)
	await click_control(editor.buttons.rotate)
	var transformed: PackedVector2Array = Shapes.transformed_points(editor.canvas.brush)
	check(transformed == PackedVector2Array([Vector2(3, 1), Vector2.ZERO, Vector2(0, 1)]), "Rotate after one horizontal mirror still turns the visible asymmetric shape clockwise")
	await press_key(KEY_ESCAPE)


func check_open_hits_and_palette_drag() -> void:
	# Keep these probes away from earlier triangles so empty frame regions are unambiguous.
	await choose_palette("corner_2x3")
	await click_at(grid_position(Vector2(0, 7)))
	await press_key(KEY_ESCAPE)
	await click_at(grid_position(Vector2(1.2, 8)))
	check(editor.canvas.selected_index == -1, "Open L corner interior and missing diagonal do not act like a filled rectangle")
	await click_at(grid_position(Vector2(0, 8)))
	check(editor.canvas.selected_index == editor.document.placements.size() - 1, "Open wall remains selectable on its visible segments")
	await choose_palette("rectangle_2x2")
	await click_at(grid_position(Vector2(3, 7)))
	await choose_palette("circle_2x2")
	await click_at(grid_position(Vector2(3, 7)))
	await press_key(KEY_ESCAPE)
	var top_index: int = editor.document.placements.size() - 1
	await click_at(grid_position(Vector2(4, 8)))
	check(editor.canvas.selected_index == top_index, "Overlap click selects the visible topmost shape")
	await click_at(grid_position(Vector2(4, 8)), true)
	check(editor.canvas.selected_index == top_index - 1, "Alt-click reaches terrain underneath an overlapping shape")
	var anchor_before: Vector2i = editor.document.placements[top_index - 1].anchor
	var start := grid_position(Vector2(4, 8))
	await mouse_button(start, true, true)
	await move_pointer(grid_position(Vector2(5.2, 8.4)), true)
	await press_key(KEY_ESCAPE)
	await mouse_button(grid_position(Vector2(5.2, 8.4)), false)
	check(editor.document.placements[top_index - 1].anchor == anchor_before, "Esc cancels an unfinished drag without mutating geometry")
	var item: Control = await show_palette_item("bump_1x2")
	var palette_start := item.get_global_rect().get_center()
	var before: int = editor.document.placements.size()
	await move_pointer(palette_start)
	await mouse_button(palette_start, true)
	await move_pointer(palette_start + Vector2(20, 0), true)
	await move_pointer(grid_position(Vector2(9.2, 7.2)), true)
	await mouse_button(grid_position(Vector2(9.2, 7.2)), false)
	check(editor.document.placements.size() == before + 1 and editor.document.placements[-1].shape_id == "bump_1x2" and editor.document.placements[-1].anchor == Vector2i(9, 7), "Dragging a palette preview onto the grid places its actual terrain stamp")
	await click_at(grid_position(Vector2(10.1, 7.1)))
	check(editor.document.placements.size() == before + 2, "Palette drop leaves the same brush ready for repeated placement")
	await press_key(KEY_ESCAPE)


func check_file_workflow() -> void:
	var before: String = editor.document.fingerprint()
	await click_control(editor.buttons.load)
	check(editor.unsaved_dialog.visible and not editor.load_dialog.visible, "Load protects unsaved edits before opening the file picker")
	await click_control(editor.unsaved_dialog.get_cancel_button())
	check(editor.document.fingerprint() == before, "Cancel Load leaves geometry intact")
	await click_control(editor.buttons.quit)
	check(editor.unsaved_dialog.visible and editor.pending_action == "quit", "Close also protects unsaved changes")
	await click_control(editor.unsaved_dialog.get_cancel_button())
	editor.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await process_frame
	check(editor.unsaved_dialog.visible and not auto_accept_quit, "Operating-system close notification reaches the same unsaved-changes guard")
	await click_control(editor.unsaved_dialog.get_cancel_button())
	await click_control(editor.buttons.save_as)
	check(editor.save_dialog.visible, "Save As opens an Act resource file picker")
	# FileDialog emits file_selected after the user accepts a path; invoke that public
	# boundary to avoid platform-native file picker differences in headless runs.
	editor.save_dialog.hide()
	editor.save_dialog.file_selected.emit(ProjectSettings.globalize_path(SAVE_PATH))
	await process_frame
	check(FileAccess.file_exists(SAVE_PATH) and not editor.is_dirty() and editor.file_label.text.contains("act-editor-smoke.tres"), "Accepted Save As writes authoring data and shows the current clean file")
	await press_key(KEY_N, true)
	check(editor.document.placements.is_empty() and not editor.unsaved_dialog.visible, "New on a clean document proceeds without a discard prompt")
	await press_key(KEY_O, true)
	check(editor.load_dialog.visible, "Ctrl+O opens Load")
	editor.load_dialog.hide()
	editor.load_dialog.file_selected.emit(ProjectSettings.globalize_path(SAVE_PATH))
	await process_frame
	check(editor.document.fingerprint() == before and not editor.is_dirty(), "Loaded editor layout matches saved transforms and metadata exactly")
	await choose_palette("oval_2x3")
	await click_at(grid_position(Vector2(7, 7)))
	await press_key(KEY_S, true)
	var edited: Dictionary = ActData.load_document(SAVE_PATH)
	check(edited.document != null and edited.document.fingerprint() == editor.document.fingerprint() and not editor.is_dirty(), "Ctrl+S persists new edits made after loading the same file")
	before = editor.document.fingerprint()
	check(not editor.load_from("res://test-results/missing-act.tres") and editor.document.fingerprint() == before, "Failed load preserves the current editor document")
	await click_control(editor.error_dialog.get_ok_button())
	await choose_palette("wall_1x1")
	await click_at(grid_position(Vector2(6, 9)))
	await press_key(KEY_N, true)
	await click_control(editor.unsaved_dialog.get_ok_button())
	check(editor.document.placements.is_empty() and not editor.is_dirty(), "Save in unsaved-changes dialog writes the current file, then continues New")
	await choose_palette("triangle_1x2")
	await click_at(grid_position(Vector2(5, 5)))
	before = editor.document.fingerprint()
	await press_key(KEY_N, true)
	await click_control(editor.unsaved_dialog.get_ok_button())
	check(editor.save_dialog.visible, "Save before New on an untitled Act asks for a filename")
	await close_file_dialog(editor.save_dialog)
	check(not editor.save_dialog.visible and editor.document.fingerprint() == before and editor.is_dirty() and editor.pending_action.is_empty(), "Canceling Save As cancels the destructive pending action and retains edits")
	await press_key(KEY_N, true)
	await discard_pending()


func check_metadata_and_loaded_frames() -> void:
	await click_control(editor.title_field)
	await press_key(KEY_A, true)
	await type_text("Precision Act")
	check(editor.document.title == "Precision Act" and editor.is_dirty() and editor.file_label.text.contains("Unsaved"), "Typing an Act title updates dirty state before focus leaves the field")
	await choose_palette("triangle_1x3")
	await click_at(grid_position(Vector2(4, 4)))
	check(editor.document.title == "Precision Act", "Palette and canvas edits retain a typed title")
	await click_control(editor.cell_size_field.get_line_edit())
	await press_key(KEY_A, true)
	await type_text("47.5")
	await click_control(editor.buttons.save_as)
	check(is_equal_approx(editor.document.cell_size, 47.5), "Save As commits fractional cell-size text without requiring Enter")
	editor.save_dialog.hide()
	editor.save_dialog.file_selected.emit(ProjectSettings.globalize_path(SAVE_PATH))
	await process_frame
	var loaded: Dictionary = ActData.load_document(SAVE_PATH)
	check(loaded.document != null and loaded.document.title == "Precision Act" and loaded.document.cell_size == 47.5, "Saved file retains typed title and fractional cell size exactly")
	await click_control(editor.cell_size_field.get_line_edit())
	await press_key(KEY_A, true)
	await type_text("48.25")
	await press_key(KEY_S, true)
	loaded = ActData.load_document(SAVE_PATH)
	check(loaded.document != null and loaded.document.cell_size == 48.25 and not editor.is_dirty(), "Ctrl+S saves an unapplied fractional value while the cell-size field keeps focus")
	await click_control(editor.title_field)
	await press_key(KEY_A, true)
	await type_text("Precision Act Updated")
	await press_key(KEY_S, true)
	loaded = ActData.load_document(SAVE_PATH)
	check(loaded.document != null and loaded.document.title == "Precision Act Updated" and not editor.is_dirty(), "Ctrl+S saves the title while its text field keeps focus")
	await click_control(editor.buttons.select)
	await click_at(grid_position(Vector2(4.2, 5.5)))
	await click_control(editor.cell_size_field.get_line_edit())
	await press_key(KEY_A, true)
	await type_text("47.75")
	await click_control(editor.buttons.delete)
	check(editor.document.cell_size == 47.75 and editor.document.placements.is_empty(), "Delete commits pending cell-size text before refreshing the inspector")
	await click_control(editor.buttons.undo)
	check(editor.document.cell_size == 47.75 and editor.document.placements.size() == 1, "Undo restores deleted terrain without losing its preceding cell-size edit")
	await click_control(editor.cell_size_field.get_line_edit())
	await press_key(KEY_A, true)
	await type_text("49.25")
	await click_control(editor.buttons.undo)
	check(editor.document.cell_size == 47.75 and editor.document.placements.size() == 1, "Toolbar Undo handles a pending cell-size edit before earlier terrain history")
	var small := ActData.new()
	small.grid_size = Vector2i(1, 3)
	small.cell_size = 47.12345
	small.placements.append({"shape_id": "wall_1x3", "base_size": Vector2i(1, 3), "anchor": Vector2i.ZERO, "quarter_turns": 0, "flip_h": false, "flip_v": false})
	var small_path := "res://test-results/act-editor-small-grid.tres"
	check(small.save_document(small_path) == OK and editor.load_from(small_path), "Valid nondefault grid loads through the same authoring workflow")
	await process_frame
	await process_frame
	var loaded_fingerprint: String = editor.document.fingerprint()
	check(editor.save_to(small_path) and editor.document.fingerprint() == loaded_fingerprint, "Loading and saving an untouched high-precision cell size does not round authoring data")
	await click_at(grid_position(Vector2(0, 1)))
	var before: String = editor.document.fingerprint()
	await click_control(editor.buttons.rotate)
	check(editor.document.fingerprint() == before and editor.document.validation_errors().is_empty(), "Rotation that cannot fit a loaded narrow grid leaves the original valid placement intact")
	editor.document.grid_size = Vector2i(1000000, 1000000)
	editor.canvas.fit_view()
	await process_frame
	await process_frame
	check(editor.canvas.size.x > 0, "Very large loaded grid redraws without iterating a million offscreen lines")
	editor.new_document()
	await process_frame


func capture_example() -> void:
	if FileAccess.file_exists("res://data/acts/curve_garden.tres"):
		await click_control(editor.buttons.example)
		await process_frame
		check(editor.document.placements.size() > 0 and editor.current_path.is_empty() and editor.is_dirty(), "Example opens as an editable copy")
	else:
		# The capture remains useful before the project example has been authored.
		for entry in [{"id": "slope_3x3", "at": Vector2(0, 2)}, {"id": "circle_1x1", "at": Vector2(1, 4)}, {"id": "triangle_1x3", "at": Vector2(10, 2)}, {"id": "u_curve_3x3", "at": Vector2(4, 7)}, {"id": "bump_2x3", "at": Vector2(8, 7)}]:
			await choose_palette(entry.id)
			await click_at(grid_position(entry.at))
	await choose_palette("slope_3x3")
	await move_pointer(grid_position(Vector2(5.1, 3.1)))
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(editor.canvas.get_global_rect()), "Grid canvas fits inside the application viewport")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/act-editor.png") == OK, "Rendered editor capture saved")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	root.gui_embed_subwindows = true
	editor = EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	await check_palette_and_overlap()
	await check_edit_gestures()
	await check_open_hits_and_palette_drag()
	await check_file_workflow()
	await check_metadata_and_loaded_frames()
	await capture_example()
	print("RESULT | Act editor UI | %d checks | %d failures" % [checks, failures])
	editor.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
