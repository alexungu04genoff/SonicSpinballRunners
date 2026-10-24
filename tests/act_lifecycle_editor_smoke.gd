extends "res://tests/act_gameplay_editor_smoke.gd"
## Reuses the actual Viewport input helpers, without running the gameplay suite.
## Run graphically to capture act-lifecycle-editor.png; a child verifies restart.

const LIFECYCLE_SAVE := "res://test-results/act-lifecycle-editor.tres"
const LIFECYCLE_REOPEN := "res://test-results/act-lifecycle-editor-reopened.tres"
const DRAFT_SAVE := "res://test-results/act-lifecycle-draft.tres"


func choose_marker(kind: String) -> void:
	await choose_tab(2)
	await click_control(editor.marker_buttons[kind])


func selected_kind() -> String:
	if not editor.canvas.selected_marker.is_empty():
		return editor.canvas.selected_marker
	if editor.canvas.selected_gameplay_index >= 0:
		return "gameplay"
	if editor.canvas.selected_index >= 0:
		return "terrain"
	return ""


func select_marker_at(kind: String, point: Vector2) -> void:
	await click_at(local_position(point))
	for attempt in 6:
		if editor.canvas.selected_marker == kind:
			return
		await set_alt(true)
		await click_at(local_position(point))
		await set_alt(false)


func check_lifecycle_creation() -> void:
	check(editor.document.activation_y == null and editor.document.spawn_position == null, "A new Act starts with optional activation and spawn markers unset")
	check(editor.document.grid_size == Vector2i(12, 12) and ActData.RED_GUTTER_CELLS == 1, "System gutter leaves the authored terrain grid at exactly twelve rows")
	check(editor.document.terrain_bounds() == Rect2(0, 0, 600, 600) and editor.document.red_gutter_bounds() == Rect2(0, 600, 600, 50), "Shared bounds put the one-cell red gutter strictly below terrain")
	check(editor.palette_tabs.get_tab_title(2) == "Act Markers" and editor.marker_buttons.size() == 4, "Act Markers exposes Entry, Exit, Activation and Spawn without a red-zone tool")
	check(editor.save_to(DRAFT_SAVE), "An incomplete draft with no connectors or lifecycle markers can be saved")
	var draft: Dictionary = ActData.load_document(DRAFT_SAVE)
	check(draft.document != null and draft.document.activation_y == null and draft.document.spawn_position == null, "Incomplete lifecycle metadata remains unset after loading")
	await choose_marker("entry")
	await drag(grid_position(Vector2(7.2, 12)), grid_position(Vector2(8.8, 12)))
	await choose_marker("exit")
	await drag(grid_position(Vector2(1.2, 0)), grid_position(Vector2(3.8, 0)))
	check(editor.document.entry_start_x == 7 and editor.document.entry_width == 2 and editor.document.exit_start_x == 1 and editor.document.exit_width == 3, "Marker palette preserves connectors on the original bottom and top terrain boundaries")
	await choose_marker("activation")
	await click_at(local_position(Vector2(175, 510.2)))
	check(editor.document.activation_y == 500.0, "Activation placement snaps its Y coordinate and spans the Act independently of X")
	await choose_marker("spawn")
	await click_at(local_position(Vector2(324.2, 524.3)))
	check(editor.document.spawn_position == Vector2(300, 500), "Spawn placement snaps to grid intersections by default")
	await choose_marker("spawn")
	await set_alt(true)
	await click_at(local_position(Vector2(438.5, 471.25)))
	await set_alt(false)
	check(close_to(editor.document.spawn_position, Vector2(438.5, 471.25)), "Choosing Spawn again replaces the one marker and Alt retains fractional local coordinates")
	check(editor.document.placements.is_empty() and editor.document.gameplay_objects.is_empty(), "Lifecycle tools create metadata without terrain tiles or gameplay object records")
	await press_key(KEY_ESCAPE)


func check_marker_movement_and_history() -> void:
	await select_marker_at("activation", Vector2(75, 500))
	check(editor.canvas.selected_marker == "activation", "Activation line is directly selectable away from the spawn marker")
	var history: int = editor.undo_stack.size()
	await mouse_button(local_position(Vector2(75, 500)), true)
	await move_pointer(local_position(Vector2(320, 451.2)), true)
	check(editor.document.activation_y == 500.0, "Activation drag previews without mutating the saved document")
	await mouse_button(local_position(Vector2(320, 451.2)), false)
	check(editor.document.activation_y == 450.0 and editor.undo_stack.size() == history + 1, "Activation drag moves vertically and records one history operation")
	await press_key(KEY_Z, true)
	check(editor.document.activation_y == 500.0, "Undo restores the whole activation drag")
	await press_key(KEY_Y, true)
	check(editor.document.activation_y == 450.0, "Redo restores the activation position")
	await mouse_button(local_position(Vector2(320, 450)), true)
	await move_pointer(local_position(Vector2(280, 440)), true)
	await set_alt(true)
	await move_pointer(local_position(Vector2(280, 432.125)), true)
	await set_alt(false)
	await mouse_button(local_position(Vector2(280, 432.125)), false)
	check(absf(editor.document.activation_y - 432.125) < 0.0002, "Alt enables fine activation movement and releasing Alt alone preserves its endpoint")
	var fine_y: float = editor.document.activation_y
	await press_key(KEY_LEFT)
	check(editor.document.activation_y == fine_y, "Horizontal arrow keys cannot move a horizontal activation line")
	await set_alt(true)
	await press_key(KEY_UP)
	await set_alt(false)
	check(editor.document.activation_y == fine_y - 1.0, "Alt-arrow moves activation by one local pixel")
	await press_key(KEY_DOWN)
	check(editor.document.activation_y == fine_y + 49.0, "Normal activation arrow movement advances by one cell")
	await select_marker_at("spawn", editor.document.spawn_position)
	check(editor.canvas.selected_marker == "spawn", "Spawn marker is selectable at its authored point")
	var before: Vector2 = editor.document.spawn_position
	history = editor.undo_stack.size()
	await drag(local_position(before), local_position(Vector2(365.2, 365.1)))
	check(editor.document.spawn_position == Vector2(350, 350) and editor.undo_stack.size() == history + 1, "Spawn drag snaps and commits one history operation")
	await mouse_button(local_position(Vector2(350, 350)), true)
	await move_pointer(local_position(Vector2(370, 360)), true)
	await set_alt(true)
	await move_pointer(local_position(Vector2(381.5, 361.25)), true)
	await set_alt(false)
	await mouse_button(local_position(Vector2(381.5, 361.25)), false)
	check(close_to(editor.document.spawn_position, Vector2(381.5, 361.25)), "Spawn supports Alt pressed mid-drag and retains free coordinates after Alt release")
	before = editor.document.spawn_position
	await set_alt(true)
	await press_key(KEY_RIGHT)
	await set_alt(false)
	check(editor.document.spawn_position == before + Vector2.RIGHT, "Alt-arrow nudges spawn by one local pixel")
	await press_key(KEY_DOWN)
	check(editor.document.spawn_position == before + Vector2(1, 50), "Normal spawn arrow movement advances by one cell")
	before = editor.document.spawn_position
	history = editor.undo_stack.size()
	await mouse_button(local_position(before), true)
	await move_pointer(local_position(Vector2(200, 200)), true)
	await press_key(KEY_ESCAPE)
	await mouse_button(local_position(Vector2(200, 200)), false)
	check(editor.document.spawn_position == before and editor.undo_stack.size() == history, "Escape cancels an unfinished spawn drag without adding history")
	await select_marker_at("spawn", before)
	await press_key(KEY_DELETE)
	check(editor.document.spawn_position == null and editor.document.activation_y != null, "Delete removes only the selected spawn marker")
	await press_key(KEY_Z, true)
	check(editor.document.spawn_position == before, "Undo restores the exact fractional spawn position")
	await press_key(KEY_Y, true)
	check(editor.document.spawn_position == null, "Redo reapplies spawn deletion")
	await press_key(KEY_Z, true)
	await select_marker_at("activation", Vector2(50, editor.document.activation_y))
	fine_y = editor.document.activation_y
	await press_key(KEY_DELETE)
	check(editor.document.activation_y == null and editor.document.spawn_position == before, "Activation deletion leaves the spawn marker intact")
	await press_key(KEY_Z, true)
	check(editor.document.activation_y == fine_y, "Undo restores activation independently from spawn")
	await press_key(KEY_ESCAPE)


func check_invalid_edits_and_gutter() -> void:
	var original: String = editor.document.fingerprint()
	var history: int = editor.undo_stack.size()
	await choose_marker("activation")
	await click_at(local_position(Vector2(125, 590)))
	await set_alt(true)
	await click_at(local_position(Vector2(125, 600)))
	await click_at(local_position(Vector2(125, 625)))
	await set_alt(false)
	check(editor.document.fingerprint() == original and editor.undo_stack.size() == history, "Activation rejects snapped bottom-edge and free gutter positions without clamping or history")
	await choose_marker("spawn")
	await click_at(local_position(Vector2(590, 250)))
	await set_alt(true)
	await click_at(local_position(Vector2(600, 250)))
	await click_at(local_position(Vector2(250, 625)))
	await click_at(local_position(Vector2(-5, 250)))
	await set_alt(false)
	check(editor.document.fingerprint() == original and editor.undo_stack.size() == history, "Spawn rejects snapped right-edge, outside and gutter positions without moving the previous marker")
	await press_key(KEY_ESCAPE)
	await select_marker_at("spawn", editor.document.spawn_position)
	await set_alt(true)
	await drag(local_position(editor.document.spawn_position), local_position(Vector2(250, 625)))
	await set_alt(false)
	check(editor.document.fingerprint() == original and editor.undo_stack.size() == history, "Dragging spawn into the gutter reports an invalid edit and retains its original position")
	await click_control(editor.cell_size_field.get_line_edit())
	await press_key(KEY_A, true)
	await type_text("25")
	await press_key(KEY_ENTER)
	check(editor.document.fingerprint() == original and editor.document.cell_size == 50.0, "A cell-size edit that would strand lifecycle markers outside terrain is rejected")
	await click_control(editor.cell_size_field.get_line_edit())
	await press_key(KEY_A, true)
	await type_text("60")
	await press_key(KEY_ENTER)
	check(editor.document.cell_size == 60.0 and editor.document.red_gutter_bounds() == Rect2(0, 720, 720, 60), "Valid cell-size edits derive the system gutter from the shared one-cell height")
	await click_control(editor.buttons.undo)
	check(editor.document.fingerprint() == original, "Undo restores cell size and exact marker positions together")
	await choose_terrain("rectangle_1x1")
	await click_at(grid_position(Vector2(6, 12.5)))
	check(editor.document.placements.is_empty(), "Terrain stamping is rejected inside the red gutter")
	var item: Control = editor.palette_buttons.rectangle_1x1
	var from := item.get_global_rect().get_center()
	var to := grid_position(Vector2(6, 12.5)).floor()
	await move_pointer(from)
	await mouse_button(from, true)
	await move_pointer(from + Vector2(20, 0), true)
	await move_pointer(to, true)
	await mouse_button(to, false)
	check(editor.document.placements.is_empty() and editor.document.grid_size == Vector2i(12, 12), "Actual terrain palette drop cannot create a thirteenth row in the red gutter")
	await press_key(KEY_ESCAPE)


func check_marker_overlaps() -> void:
	await choose_terrain("rectangle_2x2")
	await click_at(grid_position(Vector2(5, 5)))
	await choose_gameplay("round_bumper")
	await click_at(local_position(Vector2(300, 300)))
	await choose_marker("activation")
	await click_at(local_position(Vector2(300, 300)))
	await choose_marker("spawn")
	await click_at(local_position(Vector2(300, 300)))
	await press_key(KEY_ESCAPE)
	await click_at(local_position(Vector2(300, 300)))
	var found: Array[String] = [selected_kind()]
	for index in 3:
		await set_alt(true)
		await click_at(local_position(Vector2(300, 300)))
		await set_alt(false)
		found.append(selected_kind())
	found.sort()
	check(found == ["activation", "gameplay", "spawn", "terrain"], "Alt-click cycles through both lifecycle markers, gameplay and underlying terrain")
	await select_marker_at("spawn", Vector2(300, 300))
	await set_alt(true)
	await drag(local_position(Vector2(300, 300)), local_position(Vector2(318.5, 321.25)))
	await set_alt(false)
	check(close_to(editor.document.spawn_position, Vector2(318.5, 321.25)) and editor.document.activation_y == 300.0 and editor.document.gameplay_objects[0].position == Vector2(300, 300) and editor.document.placements[0].anchor == Vector2i(5, 5), "Alt-drag moves the chosen overlapping spawn without cycling or disturbing other layers")
	await press_key(KEY_ESCAPE)


func check_lifecycle_persistence() -> void:
	await choose_marker("activation")
	await set_alt(true)
	await click_at(local_position(Vector2(150, 432.125)))
	await set_alt(false)
	await choose_marker("spawn")
	await set_alt(true)
	await click_at(local_position(Vector2(438.5, 471.25)))
	await set_alt(false)
	await press_key(KEY_ESCAPE)
	check(absf(editor.document.activation_y - 432.125) < 0.0002 and close_to(editor.document.spawn_position, Vector2(438.5, 471.25)), "Lifecycle markers can be replaced with precise authored positions")
	await press_key(KEY_S, true, true)
	check(editor.save_dialog.visible, "Lifecycle metadata uses the existing Save As workflow")
	editor.save_dialog.hide()
	editor.save_dialog.file_selected.emit(ProjectSettings.globalize_path(LIFECYCLE_SAVE))
	await process_frame
	check(not editor.is_dirty() and FileAccess.file_exists(LIFECYCLE_SAVE), "Complete terrain, gameplay, connector and lifecycle state saves cleanly")
	var expected: Resource = editor.document.copy_document()
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/act_lifecycle_editor_smoke.gd", "--", "--reload-lifecycle-fixture", expected.fingerprint()
	]), output, true)
	for line in output:
		print(String(line).strip_edges())
	check(exit_code == 0, "A fresh Godot process reopens exact lifecycle state, edits it and saves again")
	var reopened: Dictionary = ActData.load_document(LIFECYCLE_REOPEN)
	check(reopened.document != null and reopened.document.activation_y == expected.activation_y and reopened.document.placements == expected.placements and reopened.document.gameplay_objects == expected.gameplay_objects and reopened.document.get_connector("entry") == expected.get_connector("entry") and reopened.document.get_connector("exit") == expected.get_connector("exit"), "Fresh-process continuation preserves activation, connectors and authored content exactly")
	check(reopened.document != null and reopened.document.grid_size == Vector2i(12, 12) and close_to(reopened.document.spawn_position, Vector2(425.5, 425.25)), "Continued spawn edits save in local pixels without adding a gutter row")
	editor.queue_free()
	await process_frame
	editor = EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	await press_key(KEY_O, true)
	editor.load_dialog.hide()
	editor.load_dialog.file_selected.emit(ProjectSettings.globalize_path(LIFECYCLE_SAVE))
	await process_frame
	check(editor.document.fingerprint() == expected.fingerprint() and not editor.is_dirty(), "Recreated editor restores all original marker state and fractional coordinates exactly")
	check(editor.find_children("*", "CollisionObject2D", true, false).is_empty() and editor.find_children("*", "CollisionObject3D", true, false).is_empty(), "Lifecycle authoring adds no runtime physics or collision bodies")


func reload_lifecycle_in_fresh_process() -> void:
	var args := OS.get_cmdline_user_args()
	var expected_hash: String = args[args.find("--reload-lifecycle-fixture") + 1]
	check(editor.load_from(LIFECYCLE_SAVE), "Fresh editor opens the authored lifecycle document")
	check(editor.document.fingerprint() == expected_hash, "Fresh editor restores every marker and exact coordinate")
	check(editor.document.grid_size == Vector2i(12, 12) and editor.document.entry_width == 2 and editor.document.exit_width == 3 and editor.document.activation_y != null and editor.document.spawn_position != null, "Restart keeps connectors and lifecycle markers structurally separate from the terrain grid")
	await choose_marker("spawn")
	await set_alt(true)
	await click_at(local_position(Vector2(425.5, 425.25)))
	await set_alt(false)
	check(close_to(editor.document.spawn_position, Vector2(425.5, 425.25)), "Fresh editor can continue precise spawn authoring")
	check(editor.save_to(LIFECYCLE_REOPEN), "Fresh editor saves continued lifecycle work")
	print("RESULT | Fresh lifecycle editor | %d checks | %d failures" % [checks, failures])
	editor.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func capture_lifecycle() -> void:
	await choose_tab(2)
	await select_marker_at("spawn", editor.document.spawn_position)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/act-lifecycle-editor.png") == OK, "Lifecycle screenshot shows separate connectors, activation, spawn and the system red gutter")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	root.gui_embed_subwindows = true
	editor = EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	if editor.canvas == null:
		check(false, "Authoring scene initializes its interactive canvas")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--reload-lifecycle-fixture"):
		await reload_lifecycle_in_fresh_process()
		return
	await check_lifecycle_creation()
	await check_marker_movement_and_history()
	await check_invalid_edits_and_gutter()
	await check_marker_overlaps()
	await check_lifecycle_persistence()
	await capture_lifecycle()
	print("RESULT | Lifecycle editor UI | %d checks | %d failures" % [checks, failures])
	editor.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
