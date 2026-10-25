extends SceneTree
## Actual pointer/key authoring checks. Run graphically for act-gameplay-editor.png.
## A child Godot process verifies that the editor can reopen and edit the saved file.

const EditorScene = preload("res://scenes/act_geometry_editor.tscn")
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const SAVE_PATH := "res://test-results/act-gameplay-editor.tres"
const REOPEN_PATH := "res://test-results/act-gameplay-editor-reopened.tres"
var editor: Control
var checks := 0
var failures := 0
var pointer := Vector2.ZERO
var alt_down := false


func _initialize() -> void:
	call_deferred("_run_with_test_viewport")


func _run_with_test_viewport() -> void:
	# Headless windows default to 64x64 even when project content is 1280x900.
	# Match the authored viewport so native cursor polling and pushed UI events use
	# the same pixel scale, including exact off-grid palette drag/drop assertions.
	root.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width", 1280), ProjectSettings.get_setting("display/window/size/viewport_height", 900))
	await process_frame
	await run()


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS | " + label)
	else:
		failures += 1
		push_error("FAIL | " + label)


func move_pointer(position: Vector2, held := false) -> void:
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(position)
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - pointer
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	event.alt_pressed = alt_down
	# Native drag/drop also consults Input's current cursor between event dispatches.
	var native_event := event.duplicate()
	native_event.position = root.get_final_transform() * position
	native_event.global_position = native_event.position
	Input.parse_input_event(native_event)
	root.push_input(event, true)
	pointer = position
	await process_frame


func mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.alt_pressed = alt_down
	root.push_input(event, true)
	await process_frame


func click_at(position: Vector2) -> void:
	await move_pointer(position)
	await mouse_button(position, true)
	await mouse_button(position, false)


func click_control(control: Control) -> void:
	await process_frame
	await process_frame
	var position := control.get_global_rect().get_center()
	if control.get_viewport() != root:
		position += Vector2(control.get_window().position)
	await click_at(position)


func press_key(code: int, command := false, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = command
	event.shift_pressed = shift
	event.alt_pressed = alt_down
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame


func set_alt(held: bool) -> void:
	alt_down = held
	var event := InputEventKey.new()
	event.keycode = KEY_ALT
	event.pressed = held
	event.alt_pressed = held
	Input.parse_input_event(event)
	root.push_input(event, true)
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


func local_position(position: Vector2) -> Vector2:
	return editor.canvas.global_position + editor.canvas.local_pixels_to_screen(position)


func grid_position(position: Vector2) -> Vector2:
	return editor.canvas.global_position + editor.canvas.grid_to_screen(position)


func choose_tab(index: int) -> void:
	await click_at(editor.palette_tabs.global_position + editor.palette_tabs.get_tab_rect(index).get_center())
	await process_frame


func choose_gameplay(id: String) -> void:
	await choose_tab(1)
	await click_control(editor.gameplay_buttons[id])


func choose_terrain(id: String) -> void:
	await choose_tab(0)
	var item: Control = editor.palette_buttons[id]
	var parent := item.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if parent is ScrollContainer:
		parent.ensure_control_visible(item)
	await process_frame
	await click_control(item)


func enter_angle(text_value: String) -> void:
	await click_control(editor.angle_field)
	await press_key(KEY_A, true)
	await type_text(text_value)
	await press_key(KEY_ENTER)


func select_gameplay(index: int) -> void:
	var position: Vector2 = editor.document.gameplay_objects[index].position
	await click_at(local_position(position))
	for attempt in editor.document.gameplay_objects.size() + editor.document.placements.size():
		if editor.canvas.selected_gameplay_index == index:
			return
		await set_alt(true)
		await click_at(local_position(position))
		await set_alt(false)


func drag(from: Vector2, to: Vector2) -> void:
	await move_pointer(from)
	await mouse_button(from, true)
	await move_pointer(to, true)
	await mouse_button(to, false)


func close_to(actual: Vector2, expected: Vector2) -> bool:
	# Screen-to-local mouse conversion uses Vector2 float32 arithmetic. Persistence
	# below compares the resulting data exactly; this tolerance only concerns input.
	return actual.distance_to(expected) < 0.0002


func check_initial_placement() -> void:
	check(editor.document.gameplay_objects.is_empty() and editor.document.placements.is_empty(), "New Act keeps separate empty terrain and gameplay arrays")
	check(editor.gameplay_buttons.size() == 7 and editor.palette_tabs.get_tab_title(0) == "Terrain" and editor.palette_tabs.get_tab_title(1) == "Gameplay", "Seven gameplay types have a separate discoverable palette tab")
	var probes := [
		{"id": "round_bumper", "cursor": Vector2(119.3, 129.9), "position": Vector2(100, 150)},
		{"id": "triangle_bumper", "cursor": Vector2(217.4, 123.6), "position": Vector2(200, 100)},
		{"id": "left_flipper", "cursor": Vector2(119.3, 429.9), "position": Vector2(100, 450)},
		{"id": "right_flipper", "cursor": Vector2(469.6, 430.1), "position": Vector2(450, 450)},
	]
	for probe: Dictionary in probes:
		await choose_gameplay(probe.id)
		await click_at(local_position(probe.cursor))
	var correct: bool = editor.document.gameplay_objects.size() == 4
	if correct:
		for index in probes.size():
			var placed: Dictionary = editor.document.gameplay_objects[index]
			correct = correct and placed.type == probes[index].id and placed.position == probes[index].position
			correct = correct and placed.rotation_degrees == Objects.make_placement(probes[index].id).rotation_degrees
	check(correct, "Actual palette clicks snap bumper anchors and flipper pivots while preserving their default resting angles")
	check(editor.document.placements.is_empty() and editor.is_dirty(), "Gameplay placement dirties the document without adding terrain records")
	check(editor.find_children("*", "CollisionObject2D", true, false).is_empty() and editor.find_children("*", "CollisionObject3D", true, false).is_empty(), "Authoring scene contains no physics bodies or collision objects")
	await choose_gameplay("round_bumper")
	await set_alt(true)
	await click_at(local_position(Vector2(438.5, 271.25)))
	await set_alt(false)
	check(editor.document.gameplay_objects.size() == 5 and close_to(editor.document.gameplay_objects[4].position, Vector2(438.5, 271.25)), "Alt places a round bumper at fractional local pixels; releasing Alt does not snap it back")
	await choose_gameplay("triangle_bumper")
	await set_alt(true)
	await click_at(local_position(Vector2(238.5, 271.25)))
	await set_alt(false)
	check(editor.document.gameplay_objects.size() == 6 and close_to(editor.document.gameplay_objects[5].position, Vector2(238.5, 271.25)), "Triangle bumper supports the same free-placement anchor rule")
	await press_key(KEY_ESCAPE)


func check_movement() -> void:
	if editor.document.gameplay_objects.size() < 6:
		return
	await click_at(local_position(Vector2(100, 150)))
	check(editor.canvas.selected_gameplay_index == 0 and editor.canvas.selected_index == -1, "Clicking round bumper selects gameplay without selecting terrain")
	var before: Vector2 = editor.document.gameplay_objects[0].position
	var history: int = editor.undo_stack.size()
	await mouse_button(local_position(before), true)
	await move_pointer(local_position(Vector2(141.8, 198.1)), true)
	check(editor.document.gameplay_objects[0].position == before, "Gameplay drag preview does not mutate authoring data before release")
	await mouse_button(local_position(Vector2(141.8, 198.1)), false)
	check(editor.document.gameplay_objects[0].position == Vector2(150, 200) and editor.undo_stack.size() == history + 1, "Normal drag snaps once and records one history operation")
	await press_key(KEY_Z, true)
	check(editor.document.gameplay_objects[0].position == before, "Undo restores the complete gameplay drag")
	await press_key(KEY_Y, true)
	check(editor.document.gameplay_objects[0].position == Vector2(150, 200), "Redo restores the snapped gameplay drag")
	history = editor.undo_stack.size()
	await mouse_button(local_position(Vector2(150, 200)), true)
	await move_pointer(local_position(Vector2(180, 230)), true)
	await set_alt(true)
	await move_pointer(local_position(Vector2(187.5, 238.25)), true)
	check((editor.status_label.text + editor.mode_label.text).to_upper().contains("FREE"), "Alt drag reports free movement in the editor")
	await set_alt(false)
	await mouse_button(local_position(Vector2(187.5, 238.25)), false)
	check(close_to(editor.document.gameplay_objects[0].position, Vector2(187.5, 238.25)) and editor.undo_stack.size() == history + 1, "Pressing Alt mid-drag enables fine movement; releasing Alt without movement preserves the fractional endpoint")
	before = editor.document.gameplay_objects[0].position
	await drag(local_position(before), local_position(before + Vector2(12, 12)))
	check(editor.document.gameplay_objects[0].position == Vector2(200, 250), "A later normal movement resumes snapping an earlier freely placed object")
	await set_alt(true)
	await press_key(KEY_RIGHT)
	await set_alt(false)
	check(editor.document.gameplay_objects[0].position == Vector2(201, 250), "Alt-arrow nudges selected gameplay by one local pixel")
	await press_key(KEY_RIGHT)
	check(editor.document.gameplay_objects[0].position == Vector2(251, 250), "Normal arrow nudges by one cell without silently normalizing an authored offset")
	await click_at(local_position(Vector2(100, 450)))
	check(editor.canvas.selected_gameplay_index == 2, "Flipper selects at its physical pivot")
	await set_alt(true)
	await drag(local_position(Vector2(100, 450)), local_position(Vector2(318.5, 501.25)))
	await set_alt(false)
	check(close_to(editor.document.gameplay_objects[2].position, Vector2(318.5, 501.25)), "Alt fine-adjustment moves the flipper pivot in exact local coordinates")


func check_angles_handedness_and_history() -> void:
	if editor.document.gameplay_objects.size() < 6:
		return
	await click_at(local_position(Vector2(200, 100)))
	check(editor.canvas.selected_gameplay_index == 1, "Triangle bumper remains independently selectable")
	await press_key(KEY_R)
	check(editor.document.gameplay_objects[1].rotation_degrees == 15.0, "Gameplay R rotates by 15 degrees")
	await press_key(KEY_R, false, true)
	check(editor.document.gameplay_objects[1].rotation_degrees == 0.0, "Gameplay Shift+R reverses by 15 degrees")
	await enter_angle("32")
	check(editor.document.gameplay_objects[1].rotation_degrees == 32.0, "Numeric triangle-bumper angle accepts an exact non-quarter-turn value")
	var history: int = editor.undo_stack.size()
	await enter_angle("12.3456789")
	check(editor.document.gameplay_objects[1].rotation_degrees == 12.3456789 and editor.undo_stack.size() == history + 1, "Fine numeric angle preserves all authored digits and creates one history operation")
	await set_alt(true)
	await press_key(KEY_R)
	await set_alt(false)
	check(editor.document.gameplay_objects[1].rotation_degrees == 13.3456789, "Alt R provides one-degree gameplay rotation")
	await press_key(KEY_Z, true)
	check(editor.document.gameplay_objects[1].rotation_degrees == 12.3456789, "Undo restores the exact fine angle")
	await select_gameplay(2)
	await enter_angle("-23.125")
	check(editor.document.gameplay_objects[2].rotation_degrees == -23.125, "Flipper resting orientation supports a signed fine angle")
	var pivot: Vector2 = editor.document.gameplay_objects[2].position
	await click_control(editor.handedness_field)
	await press_key(KEY_DOWN)
	await press_key(KEY_DOWN)
	await press_key(KEY_ENTER)
	check(editor.document.gameplay_objects[2].type == "right_flipper" and editor.document.gameplay_objects[2].position == pivot and editor.document.gameplay_objects[2].rotation_degrees == -23.125, "Handedness changes swing direction without moving the pivot or resetting its rest angle")
	await click_control(editor.buttons.undo)
	check(editor.document.gameplay_objects[2].type == "left_flipper" and editor.document.gameplay_objects[3].type == "right_flipper", "Undo restores handedness while retaining the independent opposite flipper")
	var original: Dictionary = editor.document.gameplay_objects[2].duplicate(true)
	var count: int = editor.document.gameplay_objects.size()
	await press_key(KEY_D, true)
	check(editor.document.gameplay_objects.size() == count + 1 and editor.canvas.selected_gameplay_index == count, "Ctrl+D duplicates and selects the new gameplay object")
	if editor.document.gameplay_objects.size() == count + 1:
		var duplicate: Dictionary = editor.document.gameplay_objects[-1]
		check(duplicate.type == original.type and duplicate.rotation_degrees == original.rotation_degrees and duplicate.position == original.position + Vector2.ONE * editor.document.cell_size, "Duplicate preserves handedness, exact angle and fractional offset")
	var duplicated: String = editor.document.fingerprint()
	await press_key(KEY_DELETE)
	check(editor.document.gameplay_objects.size() == count, "Delete removes only the selected gameplay object")
	await press_key(KEY_Z, true)
	check(editor.document.fingerprint() == duplicated, "Undo restores the exact duplicated object")
	await press_key(KEY_Y, true)
	check(editor.document.gameplay_objects.size() == count, "Redo reapplies gameplay deletion")


func check_overlaps_and_terrain() -> void:
	await choose_terrain("rectangle_2x2")
	await set_alt(true)
	await click_at(grid_position(Vector2(0.24, 5.22)))
	await set_alt(false)
	check(editor.document.placements.size() == 1 and close_to(Shapes.placement_position(editor.document.placements[0]), Vector2(0.24, 5.22)), "Alt places terrain at the exact fractional-cell position")
	await choose_gameplay("round_bumper")
	await click_at(local_position(Vector2(50, 300)))
	var round_index: int = editor.document.gameplay_objects.size() - 1
	await choose_gameplay("triangle_bumper")
	await click_at(local_position(Vector2(50, 300)))
	var triangle_index: int = editor.document.gameplay_objects.size() - 1
	await press_key(KEY_ESCAPE)
	await click_at(local_position(Vector2(50, 300)))
	check(editor.canvas.selected_gameplay_index == triangle_index, "Newest overlapping gameplay object is selected first")
	await set_alt(true)
	await click_at(local_position(Vector2(50, 300)))
	await set_alt(false)
	check(editor.canvas.selected_gameplay_index == round_index, "Alt-click cycles to the underlying gameplay object")
	await set_alt(true)
	await click_at(local_position(Vector2(50, 300)))
	await set_alt(false)
	check(editor.canvas.selected_index == 0 and editor.canvas.selected_gameplay_index == -1, "Overlap cycling also reaches underlying terrain")
	await set_alt(true)
	await click_at(local_position(Vector2(50, 300)))
	await click_at(local_position(Vector2(50, 300)))
	await drag(local_position(Vector2(50, 300)), local_position(Vector2(68.5, 326.25)))
	await set_alt(false)
	check(editor.canvas.selected_gameplay_index == round_index and close_to(editor.document.gameplay_objects[round_index].position, Vector2(68.5, 326.25)) and editor.document.gameplay_objects[triangle_index].position == Vector2(50, 300), "Alt-drag preserves the chosen overlapping object instead of cycling to another layer")
	await click_at(local_position(Vector2(17, 266)))
	check(editor.canvas.selected_index == 0, "Terrain remains selectable beside gameplay objects")
	await set_alt(true)
	await drag(local_position(Vector2(17, 266)), local_position(Vector2(52.75, 327.25)))
	await set_alt(false)
	check(close_to(Shapes.placement_position(editor.document.placements[0]) * float(editor.document.cell_size), Vector2(47.75, 322.25)), "Alt terrain drag preserves the exact free position")
	await press_key(KEY_R)
	check(editor.document.placements[0].quarter_turns == 1, "Terrain rotation stays at quarter-turn increments")
	await click_control(editor.buttons.entry)
	await drag(grid_position(Vector2(7.2, 12)), grid_position(Vector2(8.8, 12)))
	await click_control(editor.buttons.exit)
	await drag(grid_position(Vector2(1.2, 0)), grid_position(Vector2(3.8, 0)))
	check(editor.document.entry_start_x == 7 and editor.document.entry_width == 2 and editor.document.exit_start_x == 1 and editor.document.exit_width == 3, "Gameplay authoring preserves independent boundary connector tools")
	await press_key(KEY_ESCAPE)


func check_palette_drag() -> void:
	await choose_tab(1)
	await select_gameplay(2)
	await click_control(editor.angle_field)
	await press_key(KEY_A, true)
	await type_text("-22.625")
	var item: Control = editor.gameplay_buttons.round_bumper
	var from := item.get_global_rect().get_center()
	var count: int = editor.document.gameplay_objects.size()
	# Native drag/drop polls the OS cursor, whose screen coordinates are integers.
	# Choose that target explicitly, then retain its fractional Act coordinates.
	var drop_point := local_position(Vector2(475.5, 105.25)).floor()
	var expected_position: Vector2 = editor.canvas.screen_to_local_pixels(drop_point - editor.canvas.global_position)
	await move_pointer(from)
	await mouse_button(from, true)
	await move_pointer(from + Vector2(20, 0), true)
	await set_alt(true)
	await move_pointer(drop_point, true)
	await mouse_button(drop_point, false)
	await set_alt(false)
	if editor.document.gameplay_objects.size() != count + 1 or not close_to(editor.document.gameplay_objects[-1].position, expected_position):
		print("DROP DIAGNOSTIC | screen=", drop_point, " expected=", expected_position, " actual=", editor.document.gameplay_objects[-1].position, " transform=", root.get_final_transform(), " canvas=", editor.canvas.global_position, " viewport=", root.size, " window=", DisplayServer.window_get_size())
	check(editor.document.gameplay_objects.size() == count + 1 and editor.document.gameplay_objects[-1].type == "round_bumper" and close_to(editor.document.gameplay_objects[-1].position, expected_position) and expected_position.distance_to(expected_position.snapped(Vector2.ONE * editor.document.cell_size)) > 1.0, "Actual gameplay palette drag/drop preserves the exact off-grid cursor position with Alt")
	check(editor.document.gameplay_objects[2].rotation_degrees == -22.625, "Gameplay palette drop commits a pending numeric angle before changing the selected object")
	await click_at(local_position(Vector2(525.5, 175.25)))
	check(editor.document.gameplay_objects.size() == count + 2 and editor.document.gameplay_objects[-1].position == Vector2(550, 200), "Palette drop leaves its gameplay brush ready; future placement resumes normal snapping")
	await press_key(KEY_ESCAPE)
	await choose_tab(0)
	await select_gameplay(2)
	await click_control(editor.angle_field)
	await press_key(KEY_A, true)
	await type_text("-20.875")
	item = editor.palette_buttons.rectangle_2x2
	from = item.get_global_rect().get_center()
	var terrain_count: int = editor.document.placements.size()
	await move_pointer(from)
	await mouse_button(from, true)
	await move_pointer(from + Vector2(20, 0), true)
	await set_alt(true)
	await move_pointer(grid_position(Vector2(8.24, 7.22)), true)
	await mouse_button(grid_position(Vector2(8.24, 7.22)), false)
	await set_alt(false)
	check(editor.document.placements.size() == terrain_count + 1 and close_to(Shapes.placement_position(editor.document.placements[-1]), Vector2(8.24, 7.22)), "Actual terrain palette drop preserves fractional coordinates while Alt is held")
	check(editor.document.gameplay_objects[2].rotation_degrees == -20.875, "Terrain palette drop commits a pending gameplay angle before changing the editing tool")
	await press_key(KEY_ESCAPE)


func check_persistence() -> void:
	await select_gameplay(1)
	var untouched: float = editor.document.gameplay_objects[1].rotation_degrees
	await click_control(editor.angle_field)
	await click_at(local_position(Vector2(550, 550)))
	check(editor.document.gameplay_objects[1].rotation_degrees == untouched, "Focusing and blurring an untouched fine angle cannot round its stored value")
	await select_gameplay(2)
	await click_control(editor.angle_field)
	await press_key(KEY_A, true)
	await type_text("-21.5625")
	await press_key(KEY_S, true)
	check(editor.document.gameplay_objects[2].rotation_degrees == -21.5625, "Ctrl+S commits pending angle text without requiring Enter")
	check(editor.save_dialog.visible, "Gameplay edits save through the existing file workflow")
	editor.save_dialog.hide()
	editor.save_dialog.file_selected.emit(ProjectSettings.globalize_path(SAVE_PATH))
	await process_frame
	check(not editor.is_dirty() and FileAccess.file_exists(SAVE_PATH), "Combined geometry, connectors and gameplay document saves cleanly")
	var expected: Resource = editor.document.copy_document()
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/act_gameplay_editor_smoke.gd", "--", "--reload-gameplay-fixture", expected.fingerprint()
	]), output, true)
	for line in output:
		print(String(line).strip_edges())
	check(exit_code == 0, "A fresh Godot process reopens the authored scene, preserves exact data, then edits and saves again")
	var reopened: Dictionary = ActData.load_document(REOPEN_PATH)
	check(reopened.document != null and reopened.document.gameplay_objects.size() == expected.gameplay_objects.size() + 1, "Fresh-process continuation writes a usable edited Act")
	if reopened.document != null:
		check(reopened.document.gameplay_objects.slice(0, expected.gameplay_objects.size()) == expected.gameplay_objects and reopened.document.placements == expected.placements and reopened.document.get_connector("entry") == expected.get_connector("entry") and reopened.document.get_connector("exit") == expected.get_connector("exit"), "Re-saved continuation preserves every existing fractional position, angle, hand, terrain placement and connector exactly")
	editor.queue_free()
	await process_frame
	editor = EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	await press_key(KEY_O, true)
	editor.load_dialog.hide()
	editor.load_dialog.file_selected.emit(ProjectSettings.globalize_path(SAVE_PATH))
	await process_frame
	check(editor.document.fingerprint() == expected.fingerprint() and not editor.is_dirty(), "Recreated editor loads the exact original layout through its file dialog")
	await press_key(KEY_ESCAPE)
	await select_gameplay(2)
	await enter_angle("-31.0625")
	await press_key(KEY_S, true)
	var final_document: Dictionary = ActData.load_document(SAVE_PATH)
	check(final_document.document != null and final_document.document.fingerprint() == editor.document.fingerprint() and final_document.document.gameplay_objects[2].rotation_degrees == -31.0625, "Loaded gameplay objects remain editable and Save updates the same file")


func reload_in_fresh_process() -> void:
	var args := OS.get_cmdline_user_args()
	var expected_hash: String = args[args.find("--reload-gameplay-fixture") + 1]
	check(editor.load_from(SAVE_PATH), "Fresh editor process opens the combined Act")
	check(editor.document.fingerprint() == expected_hash, "Fresh editor process restores the exact authoring fingerprint")
	check(editor.document.gameplay_objects[1].rotation_degrees == 12.3456789 and editor.document.gameplay_objects[2].type == "left_flipper" and editor.document.gameplay_objects[3].type == "right_flipper", "Fine angles and both flipper hands survive process restart")
	var count: int = editor.document.gameplay_objects.size()
	await choose_gameplay("round_bumper")
	await set_alt(true)
	await click_at(local_position(Vector2(425.5, 125.25)))
	await set_alt(false)
	check(editor.document.gameplay_objects.size() == count + 1 and close_to(editor.document.gameplay_objects[-1].position, Vector2(425.5, 125.25)), "Fresh editor can continue free-position authoring")
	check(editor.save_to(REOPEN_PATH), "Fresh editor saves its continued work")
	print("RESULT | Fresh gameplay editor | %d checks | %d failures" % [checks, failures])
	editor.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func capture() -> void:
	await choose_tab(1)
	await select_gameplay(2)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/act-gameplay-editor.png") == OK, "Gameplay editor screenshot captures terrain, connectors, bumpers and flipper pivot previews")


func check_bumper_grid_scale() -> void:
	for cell_size: float in [50.0, 100.0]:
		editor.new_document()
		await click_control(editor.cell_size_field.get_line_edit())
		await press_key(KEY_A, true)
		await type_text(str(cell_size))
		await press_key(KEY_ENTER)
		await choose_gameplay("round_bumper")
		for column in [3, 4, 5]:
			await click_at(grid_position(Vector2(column, 3)))
		await press_key(KEY_ESCAPE)
		check(editor.document.cell_size == cell_size and editor.document.gameplay_objects.size() == 3, "Several standard bumpers fit into neighboring chamber cells at cell size " + str(cell_size))
		for index in 3:
			await click_at(grid_position(Vector2(3 + index, 3)))
			check(editor.canvas.selected_gameplay_index == index, "Small bumper remains selectable at its authored center: " + str(index))
		await click_at(grid_position(Vector2(3, 3.7)))
		check(editor.canvas.selected_gameplay_index == -1, "Bumper selection uses the smaller cell-relative silhouette rather than the old radius")
	editor.new_document()
	await process_frame


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	root.gui_embed_subwindows = true
	editor = EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	if OS.get_cmdline_user_args().has("--reload-gameplay-fixture"):
		await reload_in_fresh_process()
		return
	await check_bumper_grid_scale()
	await check_initial_placement()
	await check_movement()
	await check_angles_handedness_and_history()
	await check_overlaps_and_terrain()
	await check_palette_drag()
	await check_persistence()
	await capture()
	print("RESULT | Gameplay editor UI | %d checks | %d failures" % [checks, failures])
	editor.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
