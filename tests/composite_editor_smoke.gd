extends SceneTree
## Input-dispatch regression for terrain multiselection and explicit sculpting.
## A graphical run also captures the applied composite and its next preview.

const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Composite = preload("res://scripts/act_editor/composite_terrain.gd")
const EditorScene = preload("res://scenes/act_geometry_editor.tscn")
const SAVE_PATH := "res://test-results/composite-editor-smoke.tres"
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


func move_pointer(position: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - mouse_position
	event.button_mask = mask
	# One viewport event is enough here. Re-injecting it through Input would
	# dispatch the same relative pan movement twice; no OS drag lookup is used.
	root.push_input(event, true)
	mouse_position = position
	await process_frame


func mouse_button(position: Vector2, pressed: bool, command: bool = false, alt: bool = false, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.button_mask = (1 << (button - 1)) if pressed else 0
	event.pressed = pressed
	event.ctrl_pressed = command
	event.alt_pressed = alt
	root.push_input(event, true)
	await process_frame


func click_at(position: Vector2, command: bool = false, alt: bool = false, button: int = MOUSE_BUTTON_LEFT) -> void:
	await move_pointer(position)
	await mouse_button(position, true, command, alt, button)
	await mouse_button(position, false, command, alt, button)


func click_control(control: Control) -> void:
	await process_frame
	await process_frame
	await click_at(control.get_global_rect().get_center())


func press_key(code: int, command: bool = false, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = command
	event.shift_pressed = shift
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame


func grid_position(point: Vector2) -> Vector2:
	return editor.canvas.global_position + editor.canvas.grid_to_screen(point)


func stamp(id: String, anchor: Vector2i) -> Dictionary:
	return {"shape_id": id, "base_size": Shapes.get_definition(id).size,
		"anchor": anchor, "quarter_turns": 0, "flip_h": false, "flip_v": false}


func reset_fixture() -> void:
	editor.new_document()
	editor.add_placement(stamp("rectangle_2x2", Vector2i(2, 4)))
	editor.add_placement(stamp("triangle_2x2", Vector2i(4, 4)))
	await process_frame
	await process_frame


func select_sources() -> void:
	await click_at(grid_position(Vector2(2.5, 5)))
	await click_at(grid_position(Vector2(4.3, 5.6)), true)


func check_selection() -> void:
	await reset_fixture()
	editor.add_placement(stamp("rectangle_1x1", Vector2i(2, 4)))
	editor.add_placement(stamp("wall_1x2", Vector2i(7, 4)))
	editor.add_gameplay_placement({"type": "round_bumper", "position": Vector2(400, 400), "rotation_degrees": 0.0})
	await click_at(grid_position(Vector2(2.5, 4.5)))
	check(editor.canvas.selected_indices == [2], "Normal pointer selects only the uppermost filled terrain")
	await click_at(grid_position(Vector2(2.5, 4.5)), true, true)
	check(editor.canvas.selected_indices == [2, 0], "Ctrl+Alt pointer adds a completely covered terrain piece")
	await click_at(grid_position(Vector2(4.3, 5.6)), true)
	check(editor.canvas.selected_indices == [2, 0, 1] and editor.canvas.selected_index == 1, "Ctrl pointer retains all selected highlight indices and updates the primary selection")
	check(editor.mode_label.text.contains("3 terrain pieces") and editor.buttons.rotate.disabled and editor.buttons.duplicate.disabled, "Multiselection UI identifies all three pieces and prevents ambiguous transforms")
	var multiple_before: String = editor.document.fingerprint()
	await press_key(KEY_RIGHT)
	await press_key(KEY_R)
	check(editor.document.fingerprint() == multiple_before, "Nudges and rotation do not partially edit a multiselection")
	await click_at(grid_position(Vector2(4.3, 5.6)), true)
	check(editor.canvas.selected_indices == [2, 0], "Ctrl pointer toggles a selected terrain piece off")
	await click_at(grid_position(Vector2(10, 2)))
	check(editor.canvas.selected_indices.is_empty() and editor.canvas.selected_index == -1, "An empty-space click clears the entire terrain selection")
	await click_at(grid_position(Vector2(7, 4.5)))
	await click_at(grid_position(Vector2(3, 5.5)), true)
	check(editor.canvas.selected_indices == [3, 0] and editor.buttons.merge.disabled and editor.buttons.merge_smooth.disabled, "Open walls remain selectable but disable filled-polygon merging")
	check(editor.composite_hint.text.contains("open walls") and editor.buttons.merge.tooltip_text.contains("Filled terrain only"), "Unsupported open-wall selection gives a useful visible reason")
	await click_at(grid_position(Vector2(8, 8)))
	check(editor.canvas.selected_gameplay_index == 0 and editor.canvas.selected_indices.is_empty(), "Gameplay selection keeps its normal priority and clears terrain multiselection")
	await press_key(KEY_RIGHT)
	check(editor.document.gameplay_objects[0].position == Vector2(450, 400), "Gameplay still uses its existing one-cell movement after terrain multiselection")
	await select_sources()
	await click_at(grid_position(Vector2(3, 5.5)))
	check(editor.canvas.selected_indices == [0], "A normal terrain click collapses multiple pieces to one movable selection")


func check_preview_and_history() -> void:
	await reset_fixture()
	await select_sources()
	var before: String = editor.document.fingerprint()
	var sources: Array = editor.document.placements.duplicate(true)
	var history_size: int = editor.undo_stack.size()
	await click_control(editor.buttons.merge)
	check(editor.composite_preview_active and editor.canvas.preview_active and not editor.composite_preview.is_empty(), "Merge button starts a drawable composite preview")
	check(editor.document.fingerprint() == before and editor.undo_stack.size() == history_size, "Preview leaves source data and undo history untouched")
	check(editor.canvas.composite_preview == editor.composite_preview and editor.buttons.composite_apply.visible and editor.buttons.composite_cancel.visible, "Canvas displays the exact proposed outline with Apply and Cancel controls")
	check(editor.buttons.delete.disabled and editor.buttons.save.disabled and not editor.buttons.fit.disabled, "Preview locks editing controls while retaining Fit Grid")
	for code in [KEY_RIGHT, KEY_R, KEY_H, KEY_DELETE]:
		await press_key(code)
	await press_key(KEY_D, true)
	await press_key(KEY_Z, true)
	var from := grid_position(Vector2(2.5, 5))
	await move_pointer(from)
	await mouse_button(from, true)
	await move_pointer(from + Vector2(30, 15), MOUSE_BUTTON_MASK_LEFT)
	await mouse_button(from + Vector2(30, 15), false)
	check(editor.composite_preview_active and editor.document.fingerprint() == before and editor.undo_stack.size() == history_size, "Preview blocks authoring shortcuts, undo and terrain dragging")
	check(not editor.canvas._can_drop_data(editor.canvas.grid_to_screen(Vector2(2, 4)), {"terrain_stamp": sources[0]}), "Preview rejects incoming palette drops")
	var origin: Vector2 = editor.canvas._view_origin
	from = grid_position(Vector2(8, 3))
	await move_pointer(from)
	await mouse_button(from, true, false, false, MOUSE_BUTTON_MIDDLE)
	await move_pointer(from + Vector2(22, 13), MOUSE_BUTTON_MASK_MIDDLE)
	await mouse_button(from + Vector2(22, 13), false, false, false, MOUSE_BUTTON_MIDDLE)
	check(editor.canvas._view_origin != origin, "Middle-drag pans while the composite preview is active")
	var scale_before: float = editor.canvas._cell_pixels
	await click_at(editor.canvas.get_global_rect().get_center(), false, false, MOUSE_BUTTON_WHEEL_UP)
	check(editor.canvas._cell_pixels > scale_before, "Mouse-wheel zoom remains available during preview")
	await click_control(editor.buttons.composite_cancel)
	check(not editor.composite_preview_active and not editor.canvas.preview_active and editor.canvas.composite_preview.is_empty(), "Cancel clears the overlay and releases editing")
	check(editor.document.fingerprint() == before and editor.document.placements == sources and editor.undo_stack.size() == history_size, "Cancel restores no data because preview never replaced the sources")
	await click_control(editor.buttons.merge)
	await press_key(KEY_ESCAPE)
	check(not editor.composite_preview_active and editor.document.fingerprint() == before, "Esc cancels the preview without changing terrain")
	await click_control(editor.buttons.merge)
	await click_at(editor.canvas.get_global_rect().get_center(), false, false, MOUSE_BUTTON_RIGHT)
	check(not editor.composite_preview_active and editor.document.fingerprint() == before, "Right-click cancels the preview without changing terrain")
	await click_control(editor.buttons.fit)
	await click_control(editor.buttons.merge_smooth)
	check(editor.composite_preview_active and not editor.composite_preview.is_empty(), "Merge + Smooth starts a valid combined preview")
	for strength in [0, 25, 50, 75, 100, 125, 150, 175, 200]:
		editor.composite_strength.value = strength
		await process_frame
		check(editor.composite_preview.is_empty() or Composite.validation_error(editor.composite_preview.outline).is_empty(), "Strength %d%% never exposes an invalid applyable outline" % strength)
	check(editor.undo_stack.size() == history_size and editor.document.fingerprint() == before, "All strength changes stay outside document history")
	check(editor.composite_strength.value == 200 and not editor.composite_preview.is_empty(), "Editor accepts 200% smoothing and prepares a valid preview")
	var unprotected: PackedVector2Array = editor.composite_preview.outline.duplicate()
	await click_control(editor.composite_preserve_corners)
	check(editor.composite_preserve_corners.button_pressed and not editor.composite_preview.is_empty() and editor.composite_preview.outline != unprotected, "Preserve 90 degrees checkbox updates the active preview")
	var corners := PackedVector2Array([Vector2(0, 0), Vector2(0, 2)])
	for corner in corners:
		check(editor.composite_preview.outline.has(corner), "Protected source corner stays exact in the displayed composite")
	check(editor.undo_stack.size() == history_size and editor.document.fingerprint() == before, "Corner protection changes preview without recording edits")
	await click_control(editor.composite_preserve_corners)
	check(editor.composite_preview.outline == unprotected, "Turning corner protection off rebuilds the original preview without accumulating smoothing")
	editor.composite_strength.value = 25
	await process_frame
	var expected: Dictionary = editor.composite_preview.duplicate(true)
	await click_control(editor.buttons.composite_apply)
	check(not editor.composite_preview_active and editor.document.placements.size() == 1 and editor.document.placements[0].shape_id == "composite", "Apply replaces both source pieces with one actual CompositeTerrain")
	check(editor.document.placements[0] == expected and editor.undo_stack.size() == history_size + 1, "Apply commits precisely the displayed outline as one undo entry")
	check(editor.canvas.selected_indices == [0], "Applied composite is the sole selected terrain object")
	var applied: String = editor.document.fingerprint()
	await press_key(KEY_Z, true)
	check(editor.document.fingerprint() == before and editor.document.placements == sources, "Ctrl+Z restores every original source exactly")
	check(editor.canvas.selected_indices == [0, 1], "Undo restores the original terrain multiselection")
	await press_key(KEY_Z, true, true)
	check(editor.document.fingerprint() == applied and editor.document.placements[0] == expected, "Ctrl+Shift+Z recreates the exact stored composite")


func check_composite_edits_and_persistence() -> void:
	if editor.document.placements.size() != 1 or editor.document.placements[0].shape_id != "composite":
		check(false, "Composite fixture exists for editing and persistence checks")
		return
	var original: Dictionary = editor.document.placements[0].duplicate(true)
	var original_outline: PackedVector2Array = original.outline.duplicate()
	await click_at(grid_position(Vector2(3, 5)))
	check(editor.canvas.selected_index == 0, "Composite filled outline participates in normal hit selection")
	await press_key(KEY_D, true)
	check(editor.document.placements.size() == 2 and editor.canvas.selected_index == 1, "Ctrl+D duplicates CompositeTerrain as a selectable second object")
	check(editor.document.placements[1].outline == original_outline and editor.document.placements[1].anchor == original.anchor + Vector2i.ONE, "Duplicate preserves every local vertex and offsets only the snapped anchor")
	await press_key(KEY_Z, true)
	check(editor.document.placements.size() == 1 and editor.document.placements[0] == original, "Undo duplication restores the exact original composite")
	await press_key(KEY_RIGHT)
	check(editor.document.placements[0].anchor == original.anchor + Vector2i.RIGHT and editor.document.placements[0].outline == original_outline, "Composite movement snaps its anchor without resnapping smoothed vertices")
	await press_key(KEY_Z, true)
	await press_key(KEY_R)
	check(editor.document.placements[0].quarter_turns == 1 and editor.document.placements[0].outline == original_outline, "Quarter-turn rotation preserves canonical composite coordinates")
	await press_key(KEY_H)
	await press_key(KEY_V)
	check(editor.document.placements[0].flip_h and editor.document.placements[0].flip_v and editor.document.placements[0].outline == original_outline, "Both mirror transforms preserve the stored final outline")
	check(editor.document.validation_errors().is_empty(), "Transformed composite remains valid authoring data")
	var transformed: String = editor.document.fingerprint()
	check(editor.save_to(SAVE_PATH), "Editor saves a transformed composite document")
	check(editor.load_from(SAVE_PATH), "Editor reloads the saved composite document")
	check(editor.document.fingerprint() == transformed and editor.document.placements[0].outline == original_outline, "Save/reload retains exact outline coordinates and transforms")
	editor.canvas.select_piece(0)
	editor.canvas.grab_focus()
	await press_key(KEY_DELETE)
	check(editor.document.placements.is_empty(), "Delete removes the selected composite")
	await press_key(KEY_Z, true)
	check(editor.document.fingerprint() == transformed, "Undo deletion restores the exact transformed composite")
	var before_smooth: String = editor.document.fingerprint()
	var history_size: int = editor.undo_stack.size()
	await click_control(editor.buttons.smooth)
	check(editor.composite_preview_active and not editor.composite_preview.is_empty(), "Smooth accepts a previously stored and transformed composite")
	await click_control(editor.buttons.composite_apply)
	check(editor.undo_stack.size() == history_size + 1 and editor.document.placements.size() == 1, "Applying Smooth commits one replacement in one undo entry")
	await press_key(KEY_Z, true)
	check(editor.document.fingerprint() == before_smooth, "Undo smoothing restores the exact prior composite")


func check_unchanged_smoothing() -> void:
	await reset_fixture()
	await select_sources()
	await click_control(editor.buttons.merge)
	await click_control(editor.buttons.composite_apply)
	var before: String = editor.document.fingerprint()
	var history_size: int = editor.undo_stack.size()
	editor.composite_strength.value = 0
	await click_control(editor.buttons.smooth)
	check(editor.composite_preview_active and editor.composite_preview == editor.document.placements[0], "Zero-strength smoothing previews an identical unsmoothed composite")
	await click_control(editor.buttons.composite_apply)
	check(editor.document.fingerprint() == before and editor.undo_stack.size() == history_size, "Applying an unchanged smoothing result preserves document data and undo history")
	check(not editor.composite_preview_active and not editor.canvas.preview_active and editor.canvas.selected_indices == [0], "Unchanged Apply exits preview and retains the selected composite")


func check_protected_primitive() -> void:
	editor.new_document()
	editor.add_placement(stamp("rectangle_3x3", Vector2i(2, 3)))
	editor.canvas.select_piece(0)
	editor._refresh()
	var before: String = editor.document.fingerprint()
	editor.composite_strength.value = 200
	editor.composite_preserve_corners.button_pressed = true
	await click_control(editor.buttons.smooth)
	check(editor.composite_preview_active and editor.composite_preview.outline.size() == 4, "Protected 200% Smooth previews a primitive without rounding its four corners")
	await click_control(editor.buttons.composite_apply)
	check(not editor.composite_preview_active and editor.document.placements[0].shape_id == "composite" and editor.document.validation_errors().is_empty(), "Smooth converts a primitive into schema-valid editable CompositeTerrain")
	check(editor.save_to(SAVE_PATH), "Protected high-strength primitive smoothing saves successfully")
	await press_key(KEY_Z, true)
	check(editor.document.fingerprint() == before, "Undo protected smoothing restores the exact primitive")


func capture_preview() -> void:
	await reset_fixture()
	var left := stamp("triangle_2x2", Vector2i(0, 4))
	left.flip_h = true
	editor.add_placement(left)
	editor.add_placement(stamp("circle_2x2", Vector2i(3, 3)))
	var selected: Array[int] = [0, 1, 2, 3]
	editor.canvas.set_terrain_selection(selected)
	editor._refresh()
	editor.composite_strength.value = 200
	await click_control(editor.buttons.merge_smooth)
	check(editor.composite_preview_active and not editor.composite_preview.is_empty(), "Four-piece landscape produces a continuous sculpting preview")
	await move_pointer(grid_position(Vector2(10, 10)))
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(editor.canvas.get_global_rect()), "Composite toolbar and canvas fit inside the application viewport")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/composite-editor-preview.png") == OK, "Rendered gold collision-outline preview capture saved")
	await click_control(editor.buttons.composite_apply)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/composite-editor-applied.png") == OK, "Rendered continuous applied terrain capture saved")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	root.gui_embed_subwindows = true
	editor = EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	await check_selection()
	await check_preview_and_history()
	await check_composite_edits_and_persistence()
	await check_unchanged_smoothing()
	await check_protected_primitive()
	await capture_preview()
	print("RESULT | Composite editor UI | %d checks | %d failures" % [checks, failures])
	editor.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
