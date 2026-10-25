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


func move_pointer(position: Vector2, mask: int = 0, alt: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - mouse_position
	event.button_mask = mask
	event.alt_pressed = alt
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


func check_join_controls() -> void:
	editor.new_document()
	var left := stamp("triangle_2x2", Vector2i(1, 3))
	left.flip_h = true
	editor.add_placement(left)
	editor.add_placement(stamp("rectangle_2x2", Vector2i(3, 3)))
	editor.add_placement(stamp("triangle_2x2", Vector2i(5, 3)))
	var selected: Array[int] = [0, 1, 2]
	editor.canvas.set_terrain_selection(selected)
	editor.composite_preserve_corners.button_pressed = false
	editor._refresh()
	await click_control(editor.composite_only_joins)
	check(editor.composite_only_joins.button_pressed and editor.buttons.smooth.disabled, "Join-only mode requires Merge + Smooth instead of guessing a single outline's old seams")
	var before: String = editor.document.fingerprint()
	var history_size: int = editor.undo_stack.size()
	editor.composite_strength.get_line_edit().text = "500"
	await click_control(editor.buttons.merge_smooth)
	check(editor.composite_preview_active and not editor.composite_preview.is_empty() and editor.composite_strength.value == 500, "Merge + Smooth commits typed strength without Enter and previews the actual 500% join-only result")
	check(editor.composite_preview.outline.has(Vector2(0, 2)) and editor.composite_preview.outline.has(Vector2(6, 2)), "500% editor preview keeps both original triangle tips exact")
	await click_control(editor.composite_preserve_corners)
	editor.composite_angle.value = 135
	await process_frame
	check(editor.composite_angle.editable and editor.composite_preview.outline == editor._composite_base.outline, "Editable preserved angle can protect the 135-degree connection corners too")
	editor.composite_angle.value = 45
	await process_frame
	check(editor.composite_preview.outline != editor._composite_base.outline and editor.composite_preview.outline.has(Vector2(0, 2)), "Changing protected angle rebuilds the preview while preserving untouched tips")
	check(editor.document.fingerprint() == before and editor.undo_stack.size() == history_size, "Join and angle settings never add preview history")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/join-only-smoothing-preview.png") == OK, "500% join-only preview capture saved")
	var expected: Dictionary = editor.composite_preview.duplicate(true)
	await click_control(editor.buttons.composite_apply)
	check(editor.document.placements.size() == 1 and editor.document.placements[0] == expected and editor.undo_stack.size() == history_size + 1, "Join-only Apply commits one exact composite in one history step")
	check(editor.save_to(SAVE_PATH) and editor.load_from(SAVE_PATH) and editor.document.placements[0] == expected, "500% join-only result saves and reloads exactly without source seams")
	editor.composite_only_joins.button_pressed = false
	editor.composite_preserve_corners.button_pressed = false
	editor.composite_angle.value = 90


func check_corner_pins() -> void:
	editor.new_document()
	var square := stamp("rectangle_3x3", Vector2i(4, 4))
	square.quarter_turns = 1
	square.flip_h = true
	editor.add_placement(square)
	editor.canvas.select_piece(0)
	editor.composite_strength.value = 200
	editor.composite_only_joins.button_pressed = false
	editor.composite_preserve_corners.button_pressed = false
	editor._refresh()
	var before: String = editor.document.fingerprint()
	var history_size: int = editor.undo_stack.size()
	var canonical: PackedVector2Array = Shapes.get_definition(square.shape_id).points
	var transformed: PackedVector2Array = Shapes.transformed_points(square)
	await click_control(editor.buttons.smooth)
	var unpinned: Dictionary = editor.composite_preview.duplicate(true)
	await click_at(grid_position(transformed[0] + Vector2(square.anchor)))
	check(editor._composite_protected_indices == PackedInt32Array([0]) and editor.composite_preview.outline.has(canonical[0]), "Pointer pins the correct transformed square corner in the smoothing preview")
	check(not editor.composite_preview.outline.has(canonical[1]), "Pinning one square corner leaves other corners free to round")
	await click_at(grid_position(transformed[0] + Vector2(square.anchor)))
	check(editor._composite_protected_indices.is_empty() and editor.composite_preview == unpinned, "Clicking a pin again restores the identical unprotected preview")
	editor.composite_strength.value = 500
	await process_frame
	check(editor.composite_preview.is_empty() and editor.canvas._smoothing_corners.size() == 4, "Rejected smoothing still exposes original corner handles for repair")
	await click_at(grid_position(transformed[0] + Vector2(square.anchor)))
	await click_at(grid_position(transformed[1] + Vector2(square.anchor)))
	check(not editor.composite_preview.is_empty() and editor.composite_preview.outline.has(canonical[0]) and editor.composite_preview.outline.has(canonical[1]), "Pins can repair an excessive-area preview without lowering strength")
	await click_at(grid_position(Vector2(5, 5)), false, false, MOUSE_BUTTON_WHEEL_UP)
	check(editor.canvas.smoothing_corner_at(editor.canvas.grid_to_screen(transformed[0] + Vector2(square.anchor))) == 0, "Corner hit testing follows zoom without changing index identity")
	await click_at(grid_position(Vector2(10, 10)))
	check(editor._composite_protected_indices.size() == 2, "Empty-space clicks do not create arbitrary smoothing pins")
	editor.composite_strength.value = 200
	await process_frame
	check(editor._composite_protected_indices.size() == 2 and editor.composite_preview.outline.has(canonical[0]), "Protected points survive strength changes")
	check(editor.document.fingerprint() == before and editor.undo_stack.size() == history_size, "Pin edits leave document geometry and history untouched")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/pinned-smoothing-preview.png") == OK, "Pinned smoothing preview capture saved")
	var expected: Dictionary = editor.composite_preview.duplicate(true)
	await click_control(editor.buttons.composite_apply)
	check(editor.document.placements[0] == expected and editor.undo_stack.size() == history_size + 1 and editor.canvas._smoothing_corners.is_empty(), "Apply saves exactly the pinned contour in one edit and clears handles")
	editor.undo()
	check(editor.document.fingerprint() == before, "Undo restores the exact source after applying manually pinned smoothing")
	editor.redo()
	check(editor.document.placements[0] == expected, "Redo restores the exact contour with its protected corners")
	check(editor.save_to(SAVE_PATH) and editor.load_from(SAVE_PATH) and editor.document.placements[0] == expected, "The pinned contour survives exact save and reload")
	# Loading resets history; start a fresh preview to test clear and cancel.
	editor.canvas.select_piece(0)
	editor._refresh()
	await click_control(editor.buttons.smooth)
	check(editor._composite_protected_indices.is_empty(), "New smoothing operations start with no stale source indices")
	var corner: Vector2 = editor.canvas._smoothing_corners[0]
	await click_at(grid_position(corner))
	await click_control(editor.buttons.composite_clear_pins)
	check(editor._composite_protected_indices.is_empty() and editor.buttons.composite_clear_pins.disabled, "Clear pins releases all manual protection")
	await click_at(grid_position(corner))
	await press_key(KEY_ESCAPE)
	check(not editor.composite_preview_active and editor._composite_protected_indices.is_empty() and editor.canvas._smoothing_corners.is_empty(), "Cancel discards pins and removes corner handles")


func check_fine_terrain() -> void:
	editor.new_document()
	editor.add_placement(stamp("triangle_1x2", Vector2i(3, 3)))
	editor.canvas.select_piece(0)
	editor.composite_strength.value = 500
	editor.composite_preserve_corners.button_pressed = false
	editor.composite_only_joins.button_pressed = false
	editor.composite_allow_reshaping.button_pressed = false
	editor._refresh()
	await click_control(editor.buttons.smooth)
	check(editor.buttons.composite_apply.disabled and editor.composite_hint.text.contains("5%"), "Rejected 500% triangle explains why Apply is disabled beside the controls")
	await click_control(editor.composite_allow_reshaping)
	check(not editor.composite_preview.is_empty() and not editor.buttons.composite_apply.disabled, "Allow reshaping makes the valid 500% single triangle applicable")
	await click_control(editor.buttons.composite_apply)
	check(editor.document.placements[0].shape_id == "composite", "Strong single-shape smoothing applies successfully")
	editor.undo()
	editor.composite_allow_reshaping.button_pressed = false
	editor.terrain_snap_field.select(1)
	editor.terrain_snap_field.item_selected.emit(1)
	editor.terrain_scale_field.select(1)
	editor.terrain_scale_field.item_selected.emit(1)
	await process_frame
	check(Shapes.scaled_size(editor.document.placements[0]) == Vector2(0.5, 1.0), "Half-size control scales the selected triangle's actual frame")
	var start := grid_position(Vector2(3.15, 3.75))
	var end: Vector2 = start + Vector2(0.63, 0.56) * editor.canvas._cell_pixels
	await move_pointer(start)
	await mouse_button(start, true)
	await move_pointer(end, MOUSE_BUTTON_MASK_LEFT)
	await mouse_button(end, false)
	check(Shapes.placement_position(editor.document.placements[0]) == Vector2(3.5, 3.5), "Terrain drag snaps to half-cell intersections")
	start = grid_position(Vector2(3.65, 4.25))
	end = start + Vector2(0.237, 0.319) * editor.canvas._cell_pixels
	await move_pointer(start)
	await mouse_button(start, true, false, true)
	await move_pointer(end, MOUSE_BUTTON_MASK_LEFT, true)
	var preview_position: Vector2 = editor.canvas._drag_anchor
	await mouse_button(end, false, false, false)
	var placement: Dictionary = editor.document.placements[0]
	check(Shapes.placement_position(placement) == preview_position and preview_position.distance_to(Vector2(3.737, 3.819)) < 0.0001, "Alt-drag moves terrain freely and releasing Alt alone does not snap it")
	var before_rotation := Shapes.placement_position(placement)
	editor.rotate_active()
	check(Shapes.placement_position(editor.document.placements[0]) == before_rotation and Shapes.scaled_size(editor.document.placements[0]) == Vector2(1.0, 0.5), "Rotation retains a free position and the half-size footprint")
	var exact: Dictionary = editor.document.placements[0].duplicate(true)
	check(editor.save_to(SAVE_PATH) and editor.load_from(SAVE_PATH) and editor.document.placements[0] == exact, "Free half-size terrain saves and reloads exactly")
	editor.canvas.select_piece(0)
	editor._refresh()
	editor.duplicate_selected()
	check(editor.document.placements.size() == 2 and Shapes.placement_position(editor.document.placements[1]) == Shapes.placement_position(exact) + Vector2(0.5, 0.5), "Duplicate preserves free coordinates and offsets by the selected subgrid")
	editor.choose_shape("wall_1x2")
	editor.terrain_scale_field.select(1)
	editor.terrain_scale_field.item_selected.emit(1)
	await click_at(grid_position(Vector2(6.26, 6.26)))
	var wall: Dictionary = editor.document.placements.back()
	check(wall.shape_id == "wall_1x2" and Shapes.placement_position(wall) == Vector2(6.5, 6.5) and Shapes.scaled_size(wall) == Vector2(0.5, 1.0), "Half-size open wall stamps on the half-cell grid")
	await click_at(grid_position(Vector2(8.137, 7.283)), false, true)
	check(Shapes.placement_position(editor.document.placements.back()).distance_to(Vector2(8.137, 7.283)) < 0.0001, "Alt stamping bypasses the half-cell grid for open terrain too")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/fine-terrain-editor.png") == OK, "Half-grid and half-size controls captured")
	editor.terrain_snap_field.select(0)
	editor.terrain_snap_field.item_selected.emit(0)


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
	await check_join_controls()
	await check_corner_pins()
	await check_fine_terrain()
	await capture_preview()
	print("RESULT | Composite editor UI | %d checks | %d failures" % [checks, failures])
	editor.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
