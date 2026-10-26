extends "res://tests/pinball_editor_regression.gd"
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const SAVE_PATH := "res://test-results/gimmick-editor.tres"

func click_select(point: Vector2, control := false) -> void:
 for pressed: bool in [true, false]:
  var event := InputEventMouseButton.new()
  event.position = editor.canvas.local_pixels_to_screen(point)
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = pressed
  event.ctrl_pressed = control
  editor.canvas._gui_input(event)

func drag_to(point: Vector2) -> void:
 var event := InputEventMouseMotion.new()
 event.position = editor.canvas.local_pixels_to_screen(point)
 event.alt_pressed = true
 editor.canvas._gui_input(event)

func run() -> void:
 root.size = Vector2i(1440, 1000)
 root.gui_embed_subwindows = true
 editor = EditorScene.instantiate()
 root.add_child(editor)
 await process_frame
 var canvas = editor.canvas
 for entry: Array in [["switch_target", Vector2(100, 300)], ["switch_target", Vector2(200, 300)], ["one_way_gate", Vector2(150, 150)], ["one_way_gate", Vector2(350, 150)], ["spring", Vector2(350, 400)]]:
  editor.choose_gameplay(entry[0])
  pointer(entry[1], true)
  pointer(entry[1], false)
 check(editor.document.gameplay_objects.size() == 5, "New gameplay objects place through ordinary canvas gestures")
 canvas.select_gameplay(4)
 editor.set_gameplay_angle(71.123456789012345)
 editor.set_gameplay_property("launch_strength", 745.123456789012345)
 editor.set_gameplay_property("color", "yellow")
 check(editor.document.gameplay_objects[4].rotation_degrees == 71.123456789012345 and editor.document.gameplay_objects[4].properties.color == "yellow", "Spring inspector retains exact angle, strength and chosen color")
 canvas.select_gameplay(0)
 editor.set_gameplay_property("color", "green")
 editor.set_gameplay_property("label", "First switch")
 editor.set_gameplay_property("score_reward", 15.0)
 editor._select_mode()
 click_select(Vector2(100, 300))
 click_select(Vector2(200, 300), true)
 check(canvas.selected_gameplay_indices == [0, 1], "Ctrl-click multi-selects switch targets")
 var count: int = editor.undo_stack.size()
 editor.create_switch_bank()
 check(editor.document.switch_banks.size() == 1 and editor.undo_stack.size() == count + 1, "Create Switch Bank is one grouping/history action")
 var bank_id: String = editor.document.switch_banks[0].bank_id
 var gate_ids: Array = [editor.document.gameplay_objects[2].object_id, editor.document.gameplay_objects[3].object_id]
 editor.set_bank_gates(bank_id, gate_ids)
 check(editor.document.switch_banks[0].gates == gate_ids, "Bank links to multiple stable gate IDs")
 editor.undo()
 check(editor.document.switch_banks[0].gates.is_empty(), "Undo restores previous bank links")
 editor.redo()
 check(editor.document.switch_banks[0].gates == gate_ids and canvas.selected_gameplay_indices == [0, 1], "Redo restores links and multi-selection")
 canvas.select_gameplay(2)
 editor.delete_selected()
 check(editor.document.switch_banks[0].gates.size() == 1 and editor.document.validation_errors().is_empty(), "Deleting a linked gate prunes dangling links")
 editor.undo()
 check(editor.document.switch_banks[0].gates == gate_ids, "Undo gate deletion restores exact relationship")
 var member_indices: Array[int] = [0, 1]
 canvas.set_gameplay_selection(member_indices)
 editor.delete_selected()
 check(editor.document.switch_banks.is_empty() and editor.document.gameplay_objects.size() == 3, "Deleting all members dissolves empty bank in the same edit")
 editor.undo()
 check(editor.document.switch_banks.size() == 1 and canvas.selected_gameplay_indices == [0, 1], "Undo restores deleted members, bank and selection")
 canvas.select_gameplay(0)
 editor.duplicate_selected()
 check(editor.document.gameplay_objects[-1].object_id != editor.document.gameplay_objects[0].object_id and editor.document.switch_banks[0].members.size() == 2, "Duplicated switch gets a fresh identity without silently joining a bank")
 editor.undo()
 editor.choose_gameplay("round_bumper")
 editor.set_gameplay_property("scale", 0.35)
 pointer(Vector2(100.25, 450.75), true)
 pointer(Vector2(100.25, 450.75), false)
 check(editor.document.gameplay_objects[-1].properties.scale == 0.35, "Bumper brush scale persists into placement")
 canvas.select_gameplay(editor.document.gameplay_objects.size() - 1)
 var previous: Dictionary = editor.document.gameplay_objects[-1].duplicate(true)
 editor.set_gameplay_property("scale", 0.01)
 check(editor.document.gameplay_objects[-1] == previous, "Inspector rejects unsafe bumper scale")
 check(not canvas.gameplay_hit_indices_at(canvas.local_pixels_to_screen(Vector2(125, 450))).has(editor.document.gameplay_objects.size() - 1), "Small bumper excludes the scale probe")
 editor.set_gameplay_property("scale", 2.5)
 check(canvas.gameplay_hit_indices_at(canvas.local_pixels_to_screen(Vector2(125, 450))).has(editor.document.gameplay_objects.size() - 1), "Scaled silhouette also updates canvas hit selection")
 editor._change_palette_tab(4)
 editor.choose_ring_circle()
 editor._change_ring_pattern("fill", true)
 await process_frame
 await process_frame
 count = editor.undo_stack.size()
 pointer(Vector2(220.25, 210.5), true)
 drag_to(Vector2(380.75, 330.25))
 await process_frame
 var preview: Dictionary = canvas._ring_preview.duplicate(true)
 var positions := Rings.positions(preview)
 check(preview.kind == "ellipse" and preview.fill and positions.size() > 10 and editor.document.ring_trails.is_empty(), "Filled ellipse previews before committing")
 pointer(Vector2(380.75, 330.25), false)
 if editor.document.ring_trails[0] != preview: print("PREVIEW / COMMIT | ", preview, " / ", editor.document.ring_trails[0])
 check(editor.document.ring_trails.size() == 1 and editor.document.ring_trails[0] == preview and editor.undo_stack.size() == count + 1, "One ellipse draw gesture commits one exact undo action")
 editor.undo()
 check(editor.document.ring_trails.is_empty(), "Undo removes entire ellipse pattern")
 editor.redo()
 check(Rings.positions(editor.document.ring_trails[0]) == positions and canvas.ring_kind == "ellipse", "Redo reproduces exact generated positions and keeps draw mode")
 canvas.select_ring(0)
 editor._change_ring_pattern("fill", false)
 editor._change_ring_pattern("rotation_degrees", 31.123456789012345)
 editor._change_ring_radius(0, 94.125)
 check(editor.document.ring_trails[0].fill == false and is_equal_approx(absf(editor.document.ring_trails[0].end.x - editor.document.ring_trails[0].start.x) * 0.5, 94.125), "Contextual ellipse properties edit fill, angle and radii")
 var fingerprint: String = editor.document.fingerprint()
 check(editor.save_to(SAVE_PATH), "Editor saves all new authoring data")
 editor.new_document()
 check(editor.load_from(SAVE_PATH) and editor.document.fingerprint() == fingerprint, "Editor reload restores bank IDs, colors, links, scales and ring authoring")
 var example := ActData.load_document("res://data/acts/switch_gate_spring.tres")
 editor.request_action("gimmicks")
 check(editor.document.fingerprint() == example.document.fingerprint() and editor.current_path.is_empty(), "Pinball Example opens the shipped objective as an editable copy")
 check(editor.document.switch_banks.size() == 1 and editor.document.ring_trails.size() == 2, "Example exposes its switch links and editable ring patterns")
 editor._change_palette_tab(1)
 canvas.select_gameplay(4)
 editor._refresh()
 if DisplayServer.get_name() != "headless":
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/gimmick-editor.png")
  var example_members: Array[int] = [0, 1, 2]
  canvas.set_gameplay_selection(example_members)
  editor.selected_bank_id = "sky_bank"
  editor._refresh()
  await process_frame
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/gimmick-editor-banks.png")
  editor._change_palette_tab(4)
  canvas.select_ring(0)
  editor._refresh()
  await process_frame
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/gimmick-editor-rings.png")
 editor.free()
 await process_frame
 print("RESULT | Gimmick editor | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
