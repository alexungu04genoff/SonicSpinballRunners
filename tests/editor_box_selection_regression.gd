extends "res://tests/pinball_editor_regression.gd"
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Decor = preload("res://scripts/act_editor/decor_slots.gd")

func button_at(point: Vector2, pressed: bool, additive := false, free_move := false) -> void:
 var event := InputEventMouseButton.new()
 event.position = editor.canvas.local_pixels_to_screen(point)
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = pressed
 event.ctrl_pressed = additive
 event.alt_pressed = free_move
 editor.canvas._gui_input(event)

func drag_box(from: Vector2, to: Vector2, additive := false, free_move := false) -> void:
 button_at(from, true, additive, free_move)
 var motion := InputEventMouseMotion.new()
 motion.position = editor.canvas.local_pixels_to_screen(to)
 motion.button_mask = MOUSE_BUTTON_MASK_LEFT
 motion.ctrl_pressed = additive
 motion.alt_pressed = free_move
 editor.canvas._gui_input(motion)
 button_at(to, false, additive, free_move)

func viewport_drag(from: Vector2, to: Vector2) -> void:
 var start: Vector2 = editor.canvas.global_position + editor.canvas.local_pixels_to_screen(from)
 var finish: Vector2 = editor.canvas.global_position + editor.canvas.local_pixels_to_screen(to)
 var event := InputEventMouseButton.new()
 event.position = start
 event.global_position = start
 event.button_index = MOUSE_BUTTON_LEFT
 event.button_mask = MOUSE_BUTTON_MASK_LEFT
 event.pressed = true
 root.push_input(event, true)
 await process_frame
 var motion := InputEventMouseMotion.new()
 motion.position = finish
 motion.global_position = finish
 motion.relative = finish - start
 motion.button_mask = MOUSE_BUTTON_MASK_LEFT
 root.push_input(motion, true)
 await process_frame
 event.position = finish
 event.global_position = finish
 event.button_mask = 0
 event.pressed = false
 root.push_input(event, true)
 await process_frame

func run() -> void:
 root.size = Vector2i(1440, 1000)
 root.gui_embed_subwindows = true
 editor = EditorScene.instantiate()
 root.add_child(editor)
 await process_frame
 await process_frame
 var canvas = editor.canvas
 editor.choose_shape("rectangle_1x1")
 var terrain: Dictionary = canvas.brush.duplicate(true)
 Shapes.set_placement_position(terrain, Vector2(2, 2))
 editor.add_placement(terrain)
 for position: Vector2 in [Vector2(200, 120), Vector2(500, 450)]:
  var item := Objects.make_placement("round_bumper")
  item.position = position
  editor.add_gameplay_placement(item)
 var slot := Decor.make_slot("small")
 slot.position = Vector2(120, 220)
 editor.set_decor_slot(-1, slot)
 editor.document.decor_slots[0].placement_source = "scatter"
 editor.set_ring_trail(-1, {"start": Vector2(200, 220), "end": Vector2(250, 220), "spacing": 25.0})
 editor._select_mode()
 var fingerprint: String = editor.document.fingerprint()
 var history: int = editor.undo_stack.size()
 drag_box(Vector2(60, 60), Vector2(275, 250))
 check(canvas.selection_count() == 4 and canvas.selected_indices == [0] and canvas.selected_gameplay_indices == [0] and canvas.selected_decor_indices == [0] and canvas.selected_ring_indices == [0], "Box selects terrain, gameplay, decor and whole ring patterns")
 check(editor.document.fingerprint() == fingerprint and editor.undo_stack.size() == history, "Selection never edits the Act or undo history")
 check(editor.buttons.duplicate.disabled and editor.buttons.rotate.disabled and editor.buttons.merge.disabled and not editor.angle_field.editable, "Mixed selection disables single-object transforms and terrain merging")
 drag_box(Vector2(450, 400), Vector2(550, 500), true)
 check(canvas.selection_count() == 5, "Ctrl-drag adds to the existing selection")
 button_at(Vector2(500, 450), true, true)
 button_at(Vector2(500, 450), false, true)
 check(canvas.selection_count() == 4 and canvas.selected_gameplay_indices == [0], "Ctrl-click toggles one member without dropping other categories")
 var selected: Dictionary = canvas.object_selection()
 drag_box(Vector2(120, 120), Vector2(145, 145), false, true)
 check(Shapes.placement_position(editor.document.placements[0]).is_equal_approx(Vector2(2.5, 2.5)) and editor.document.gameplay_objects[0].position.is_equal_approx(Vector2(225, 145)) and editor.document.decor_slots[0].position.is_equal_approx(Vector2(145, 245)) and editor.document.ring_trails[0].start.is_equal_approx(Vector2(225, 245)), "Dragging a member moves the entire mixed selection by one shared offset")
 check(editor.undo_stack.size() == history + 1 and not editor.document.decor_slots[0].has("placement_source"), "Group move is one undo step and claims scattered decor as manual")
 editor.undo()
 check(editor.document.fingerprint() == fingerprint and canvas.object_selection() == selected, "Undo restores exact geometry, decor ownership and mixed selection")
 editor.redo()
 check(canvas.object_selection() == selected and editor.document.gameplay_objects[1].position == Vector2(500, 450), "Redo preserves selection and leaves unselected objects unchanged")
 editor.undo()
 drag_box(Vector2(120, 120), Vector2(-100, -100), false, true)
 check(Shapes.placement_position(editor.document.placements[0]).is_equal_approx(Vector2.ZERO) and editor.document.gameplay_objects[0].position.is_equal_approx(Vector2(100, 20)), "Group movement clamps as a unit at terrain bounds")
 editor.undo()
 editor.delete_selected()
 check(editor.document.placements.is_empty() and editor.document.decor_slots.is_empty() and editor.document.ring_trails.is_empty() and editor.document.gameplay_objects.size() == 1, "Delete removes all selected categories together")
 editor.undo()
 check(editor.document.fingerprint() == fingerprint and canvas.object_selection() == selected, "Undo restores a deleted mixed group and its selection")
 editor.canvas_decor_visible_field.button_pressed = false
 editor.gameplay_visible_field.button_pressed = false
 check(canvas.selection_count() == 1 and canvas.selected_indices == [0] and not editor.decor_visible_field.button_pressed, "Toolbar toggles deselect hidden objects and sync the decor inspector")
 check(canvas.mixed_hit_indices_at(canvas.local_pixels_to_screen(Vector2(120, 220))).is_empty() and canvas.gameplay_hit_indices_at(canvas.local_pixels_to_screen(Vector2(200, 120))).is_empty() and canvas.marker_hits_at(canvas.local_pixels_to_screen(editor.document.goal_center())).is_empty(), "Hidden decor, gameplay and lifecycle markers cannot intercept clicks")
 drag_box(Vector2(275, 250), Vector2(60, 60))
 check(canvas.selection_count() == 1 and canvas.selected_indices == [0], "Reverse-direction box selection ignores hidden layers")
 check(editor.document.fingerprint() == fingerprint, "Visibility leaves saved Act data unchanged")
 editor.decor_visible_field.button_pressed = true
 check(editor.canvas_decor_visible_field.button_pressed, "Decor inspector synchronizes the toolbar toggle")
 editor.choose_gameplay("spring")
 check(canvas.show_gameplay and editor.gameplay_visible_field.button_pressed, "Choosing a gameplay brush reveals its layer")
 editor._select_mode()
 drag_box(Vector2(275, 250), Vector2(60, 60))
 check(canvas.selection_count() == 4, "Reverse-direction drag selects all visible categories")
 var key := InputEventKey.new()
 key.keycode = KEY_RIGHT
 key.pressed = true
 key.alt_pressed = true
 canvas._gui_input(key)
 check(editor.document.decor_slots[0].position.is_equal_approx(Vector2(121, 220)) and editor.document.gameplay_objects[0].position.is_equal_approx(Vector2(201, 120)), "Alt-arrow nudges the whole group by one pixel")
 editor.undo()
 button_at(Vector2(60, 60), true)
 key.keycode = KEY_ESCAPE
 canvas._gui_input(key)
 button_at(Vector2(275, 250), false)
 check(not canvas._box_selecting and canvas.selection_count() == 0 and editor.document.fingerprint() == fingerprint, "Escape cancels a selection gesture without editing")
 # Exercise geometry crossing, not only anchors or bounding boxes.
 check(canvas._box_hits_points(Rect2(10, 10, 20, 20), PackedVector2Array([Vector2(0, 20), Vector2(40, 20)]), false), "Box detects an open wall crossing with both endpoints outside")
 check(not canvas._box_hits_points(Rect2(25, 25, 5, 5), PackedVector2Array([Vector2.ZERO, Vector2(40, 0), Vector2(0, 40)]), true), "Box rejects empty space inside a triangle's bounding rectangle")
 await process_frame
 await process_frame
 await viewport_drag(Vector2(60, 60), Vector2(275, 250))
 check(canvas.selection_count() == 4, "Viewport-dispatched mouse events select a mixed group")
 button_at(Vector2(120, 120), true, false, true)
 var free_motion := InputEventMouseMotion.new()
 free_motion.position = canvas.local_pixels_to_screen(Vector2(133.25, 127.5))
 free_motion.alt_pressed = true
 canvas._gui_input(free_motion)
 button_at(Vector2(133.25, 127.5), false)
 check(editor.document.decor_slots[0].position.is_equal_approx(Vector2(133.25, 227.5)), "Releasing Alt before group mouse-up preserves the last free offset")
 editor.undo()
 editor.canvas_decor_visible_field.button_pressed = false
 editor.gameplay_visible_field.button_pressed = false
 var adjacent := terrain.duplicate(true)
 Shapes.set_placement_position(adjacent, Vector2(3, 2))
 editor.add_placement(adjacent)
 editor._select_mode()
 drag_box(Vector2(60, 60), Vector2(225, 175))
 check(canvas.selected_indices == [0, 1] and not editor.buttons.merge.disabled, "Box-selected terrain remains available to the existing Merge tool")
 editor.preview_composite("merge")
 check(editor.composite_preview_active and not editor.composite_preview.is_empty() and editor.gameplay_visible_field.disabled, "Merge preview remains valid and locks layer toggles")
 editor.apply_composite()
 check(editor.document.placements.size() == 1, "Merge applies to the box-selected terrain in one edit")
 editor.undo()
 check(editor.document.placements.size() == 2 and canvas.selected_indices == [0, 1], "Undo restores merged terrain and its box selection")
 editor.undo()
 editor.canvas_decor_visible_field.button_pressed = true
 editor.gameplay_visible_field.button_pressed = true
 if DisplayServer.get_name() != "headless":
  drag_box(Vector2(60, 60), Vector2(275, 250))
  await process_frame
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/editor-box-selection.png")
 editor.free()
 print("RESULT | Editor box selection | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
