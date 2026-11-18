extends SceneTree
## Real editor ownership, atomic edits, input routing and restart/recovery checks.
const Fixture = preload("res://tests/editor_qualification_fixture.gd")
const Selection = Fixture.Selection
const Transform = Fixture.Transform
const Shapes = Fixture.Shapes
const Objects = Fixture.Objects
const Act = Fixture.Act
const Recovery = preload("res://scripts/act_editor/editor_recovery.gd")
const Assemblies = preload("res://scripts/act_editor/assembly_library.gd")
const Clipboard = preload("res://scripts/act_editor/selection_clipboard.gd")
const Workspace = preload("res://scripts/act_editor/editor_workspace_tools.gd")
const Scene = preload("res://scenes/act_geometry_editor.tscn")
var editor: Control
var checks := 0
var failures := 0
var failed: Array[String] = []

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  failed.append(message)
  push_error(message)

func reset(document: Resource = null) -> void:
 editor.new_document()
 editor.document = Fixture.linked() if document == null else document
 editor.canvas.set_document(editor.document)
 editor.canvas.snap_mode = 0
 editor.canvas.pivot_mode = 0
 editor.canvas.selection_filter = "all"
 editor.canvas.terrain_snap_step = 1.0
 editor.show_all_layers()
 editor.canvas.fit_view()
 editor._refresh()
 editor.undo_stack.clear()
 editor.redo_stack.clear()
 editor.workspace_tools.autosave_enabled.button_pressed = false

func key(code: Key, ctrl := false, shift := false, alt := false) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.pressed = true
 event.ctrl_pressed = ctrl
 event.shift_pressed = shift
 event.alt_pressed = alt
 editor.canvas.grab_focus()
 editor._unhandled_key_input(event)

func pointer(at: Vector2, pressed: bool, ctrl := false, shift := false, alt := false) -> void:
 var event := InputEventMouseButton.new()
 event.position = editor.canvas.local_pixels_to_screen(at)
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = pressed
 event.ctrl_pressed = ctrl
 event.shift_pressed = shift
 event.alt_pressed = alt
 editor.canvas._gui_input(event)

func motion(at: Vector2, shift := false, alt := false) -> void:
 var event := InputEventMouseMotion.new()
 event.position = editor.canvas.local_pixels_to_screen(at)
 event.button_mask = MOUSE_BUTTON_MASK_LEFT
 event.shift_pressed = shift
 event.alt_pressed = alt
 editor.canvas._gui_input(event)

func axis(code: Key) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.pressed = true
 editor.canvas._gui_input(event)

func exact(offset := Vector2.ZERO, angle := 0.0, size := 100.0, mode := 0) -> void:
 var workspace: Control = editor.workspace_tools
 workspace.move_x.get_line_edit().text = str(offset.x)
 workspace.move_y.get_line_edit().text = str(offset.y)
 workspace.angle.get_line_edit().text = str(angle)
 workspace.scale_mode.select(mode)
 workspace.scale_value.get_line_edit().text = str(size)
 workspace._apply_exact()

func selection_checks() -> void:
 reset()
 pointer(Vector2(250, 400), true)
 pointer(Vector2(250, 400), false)
 check(editor.canvas.selected_gameplay_indices == [0], "Pointer selects one ungrouped object")
 pointer(Vector2(470, 400), true, true)
 pointer(Vector2(470, 400), false, true)
 check(editor.canvas.selected_gameplay_indices.size() == 2, "Ctrl-click adds another object")
 for filter: String in ["terrain", "gameplay", "decor", "ring", "markers", "bumpers", "spring", "buzz_bomber"]:
  editor.canvas.selection_filter = filter
  editor.select_all_content()
  var selected: Dictionary = editor.canvas.object_selection()
  check(editor.canvas.selection_count() > 0, "Select All finds filter " + filter)
  for kind: String in Selection.KINDS:
   for index: Variant in selected[kind]:
    # Whole groups intentionally expand beyond the requested family.
    check(editor.canvas.selection_allowed(kind, index) or editor.document.editor_groups.any(func(group): return group.members.get(kind, []).has(index)), "Filter selects a match or a complete group: " + filter)
 reset()
 editor.document.editor_groups = []
 var count: int = editor.undo_stack.size()
 var fingerprint: String = editor.document.editing_fingerprint()
 for layer: String in ["terrain", "gameplay", "decor", "rings", "markers"]:
  editor.toggle_layer(layer)
  check(not editor.canvas.get("show_" + layer), "Layer can hide: " + layer)
  editor.solo_layer(layer)
  check(editor.canvas.get("show_" + layer), "Solo reveals only its layer: " + layer)
  editor.solo_layer(layer)
  check(not editor.canvas.get("show_" + layer), "Solo restores previous visibility: " + layer)
  editor.toggle_layer(layer)
 check(editor.document.editing_fingerprint() == fingerprint and editor.undo_stack.size() == count, "Layer preferences neither dirty the Act nor add Undo")
 editor.canvas.selection_filter = "gameplay"
 var left := Vector2(250, 399)
 var right := Vector2(290, 430)
 for mode in [0, 1, 2]:
  editor.canvas.box_selection_mode = mode
  for backwards in [false, true]:
   editor.canvas._box_start = editor.canvas.local_pixels_to_screen(right if backwards else left)
   editor.canvas._box_end = editor.canvas.local_pixels_to_screen(left if backwards else right)
   editor.canvas._box_additive = false
   editor.canvas._finish_box_selection()
   var expected: bool = mode == 0 or (mode == 2 and backwards)
   check(editor.canvas.selected_gameplay_indices.has(0) == expected, "Marquee touching/enclosed/directional mode %d backwards %s" % [mode, backwards])
 reset(Fixture.dense())
 editor.workspace_tools.reveal(0)
 editor.workspace_tools.refresh()
 var root_item: TreeItem = editor.workspace_tools.tree.get_root()
 editor.workspace_tools.refresh()
 check(editor.workspace_tools.tree.get_root() == root_item, "Unchanged browser refresh preserves Tree items")
 editor.workspace_tools.reveal(1)
 editor.document.title += " changed"
 editor.workspace_tools.refresh()
 check(editor.workspace_tools.tree.get_root() == root_item, "Inactive browser does not scan/rebuild its tree")
 editor.workspace_tools.reveal(0)
 editor.workspace_tools.refresh()
 check(editor.workspace_tools._tree_fingerprint == editor.document.editing_fingerprint(), "Returning to Objects updates the changed document")
 editor.workspace_tools._chosen = {"selection": editor.document.editor_groups[0].members, "group": 0}
 editor.workspace_tools._frame_row()
 check(editor.canvas._view_adjusted and editor.canvas._cell_pixels > 0, "Object browser frames a complete group")
 editor.workspace_tools._reveal_objects()
 check(editor.document.editor_hidden.is_empty(), "Browser reveal removes per-object hiding")
 editor.canvas.set_object_selection(Selection.single("gameplay", 5))
 editor.lock_selection()
 check(Selection.count(editor.document.editor_locks) >= 7 and editor.canvas.selection_count() == 0, "Group lock protects every member and clears selection")
 editor.canvas.set_object_selection(Selection.single("gameplay", 6))
 check(editor.canvas.selection_count() == 0, "Locked group cannot be half-selected")
 editor.unlock_all()
 editor.canvas.set_object_selection(Selection.single("gameplay", 5))
 editor.ungroup_selection()
 check(editor.document.editor_groups.is_empty(), "Ungroup is an explicit undoable edit")
 editor.undo()
 check(editor.document.editor_groups.size() == 1, "Undo restores group membership")
 editor.canvas.set_object_selection(Selection.single("gameplay", 5))
 editor.delete_selected()
 check(editor.document.editor_groups.is_empty() and editor.document.validation_errors().is_empty(), "Group deletion prunes membership and bank links coherently")

func browser_edit_checks() -> void:
 reset(Fixture.dense())
 var workspace: Control = editor.workspace_tools
 workspace.reveal(0)
 workspace.refresh()
 await process_frame
 var tree: Tree = workspace.tree
 var original: String = editor.document.editing_fingerprint()
 var gameplay: String = editor.document.fingerprint()
 tree.get_root().get_first_child().select(0)
 check(tree.edit_selected(true), "Group row opens its native Tree text editor")
 await process_frame
 var field: LineEdit
 for child: Node in tree.find_children("*", "LineEdit", true, false):
  if child.has_focus(): field = child
 check(field != null, "Group rename routes typing into the focused text field")
 if field == null: return
 field.text = "  Qualification renamed group  "
 field.text_submitted.emit(field.text)
 await process_frame
 check(editor.document.editor_groups[0].name == "Qualification renamed group" and editor.undo_stack.size() == 1 and editor.document.fingerprint() == gameplay, "Browser rename trims whitespace and commits one metadata-only edit")
 var renamed: String = editor.document.editing_fingerprint()
 editor.undo()
 check(editor.document.editing_fingerprint() == original, "Browser rename Undo restores the complete document")
 editor.redo()
 check(editor.document.editing_fingerprint() == renamed, "Browser rename Redo restores the complete document")
 editor.undo()
 for column in [1, 2]:
  var row: TreeItem = tree.get_root().get_first_child().get_first_child()
  row.select(column)
  check(tree.edit_selected(true), "Object browser checkbox edits column %d" % column)
  await process_frame
  var protection: Dictionary = editor.document.editor_hidden if column == 1 else editor.document.editor_locks
  check(protection.get("terrain", []).has(0) and Selection.count(Selection.expanded(editor.document, Selection.single("gameplay", 5))) == 0 and editor.document.fingerprint() == gameplay, "Individual browser protection blocks its whole group without affecting gameplay")
  editor.undo()
  check(editor.document.editing_fingerprint() == original, "Browser checkbox Undo restores all metadata")
 tree.get_root().get_first_child().select(0)
 check(tree.edit_selected(true), "Group rename can be reopened after protection edits")
 await process_frame
 for child: Node in tree.find_children("*", "LineEdit", true, false):
  if child.has_focus():
   child.text = "   "
   child.text_submitted.emit(child.text)
   break
 await process_frame
 check(editor.document.editing_fingerprint() == original and editor.undo_stack.is_empty(), "Blank group names reject without a partial edit or Undo record")

func snap_and_transform_checks() -> void:
 reset()
 editor.canvas.select_gameplay(0)
 var unchanged: String = editor.document.editing_fingerprint()
 exact()
 check(editor.document.editing_fingerprint() == unchanged and editor.undo_stack.is_empty(), "Default exact fields are a true no-op")
 reset()
 var origin := Vector2(103.25, 107.75)
 var target := origin + Vector2(38, 27)
 for mode in [0, 1, 2]:
  for step in [1.0, 0.5, 0.25]:
   editor.canvas.snap_mode = mode
   editor.canvas.terrain_snap_step = step
   var expected := target
   if mode == 1: expected = origin + (target - origin).snapped(Vector2.ONE * 50.0 * step)
   elif mode == 2: expected = target.snapped(Vector2.ONE * 50.0 * step)
   check(editor.canvas.movement_position(target, origin, false).is_equal_approx(expected), "Snap mode %d at %.2f cells" % [mode, step])
   check(editor.canvas.movement_position(target, origin, true) == target, "Alt bypasses mode %d at %.2f cells" % [mode, step])
 editor.canvas.snap_mode = 0
 editor.canvas.terrain_snap_step = 1.0
 editor.canvas._shift_held = true
 check(editor.canvas.movement_position(target, origin, false) == origin + Vector2(50, 50), "Shift temporarily enables Relative Grid")
 editor.canvas._shift_held = false
 for code in [KEY_X, KEY_Y]:
  reset()
  var before: Vector2 = editor.document.gameplay_objects[0].position
  pointer(before, true)
  motion(before + Vector2(13.25, 27.75))
  axis(code)
  pointer(before + Vector2(13.25, 27.75), false)
  var expected := before + (Vector2(13.25, 0) if code == KEY_X else Vector2(0, 27.75))
  check(editor.document.gameplay_objects[0].position.distance_to(expected) < 0.001 and editor.canvas.drag_axis.is_empty(), "Axis-locked drag commits and releases %d" % code)
  editor.undo()
  check(editor.document.gameplay_objects[0].position == before, "Axis drag is one reversible edit")
  pointer(before, true)
  motion(before + Vector2(45, 60))
  axis(code)
  editor.canvas.cancel_gesture()
  check(editor.document.gameplay_objects[0].position == before and editor.canvas.drag_axis.is_empty(), "Cancel clears axis and leaves source untouched")
 reset()
 editor.document.placements[2].anchor = Vector2i(12, 22)
 editor.document.editor_groups.clear()
 editor.canvas.set_object_selection({"gameplay": [0, 9], "ring": [1, 2], "decor": [1], "terrain": [2]})
 for mode in [0, 1, 2]:
  editor.canvas.pivot_mode = mode
  editor.canvas.cursor_pivot = Vector2(600.25, 750.75)
  var expected: Vector2 = Transform.bounds(editor.document, editor.canvas.object_selection()).get_center() if mode == 0 else (editor.canvas.selection_anchor() if mode == 1 else editor.canvas.cursor_pivot)
  check(editor.canvas.transform_pivot() == expected, "Transform pivot mode %d resolves correctly" % mode)
 editor.canvas.pivot_mode = 0
 var before: Resource = editor.document.copy_document()
 var selection: Dictionary = editor.canvas.object_selection()
 var pivot: Vector2 = editor.canvas.transform_pivot()
 exact(Vector2(-12.75, 17.25), 17.0, 110.0)
 var after: Vector2 = editor.document.gameplay_objects[0].position
 var expected_position := pivot + (Vector2(before.gameplay_objects[0].position) - pivot).rotated(deg_to_rad(17.0)) * 1.1 + Vector2(-12.75, 17.25)
 print("EXACT ORDER | actual=", after, " expected=", expected_position, " undo=", editor.undo_stack.size(), " fields=", Vector3(editor.workspace_tools.move_x.value, editor.workspace_tools.move_y.value, editor.workspace_tools.angle.value), " size=", editor.workspace_tools.scale_value.value, " | ", editor.status_label.text)
 check(after.distance_to(expected_position) < 0.001 and editor.undo_stack.size() == 1, "Exact order is rotation, uniform scale, translation in one Undo")
 editor.undo()
 check(editor.document.editing_fingerprint() == before.editing_fingerprint(), "Exact mixed edit undoes to the complete editing fingerprint")
 editor.canvas.set_object_selection(selection)
 var baseline: String = editor.document.editing_fingerprint()
 exact(Vector2(-100000, 0), 0, 110)
 check(editor.document.editing_fingerprint() == baseline and editor.undo_stack.is_empty(), "Boundary-crossing exact transform rejects atomically")
 for index in [0, 2, 9, 12]:
  reset()
  editor.canvas.select_gameplay(index)
  var width: float = Transform.bounds(editor.document, editor.canvas.object_selection()).size.x
  exact(Vector2.ZERO, 0, width * 1.25, 1)
  var target_width: float = editor.workspace_tools.scale_value.value
  var measured: float = Transform.bounds(editor.document, editor.canvas.object_selection()).size.x
  print("EXACT WIDTH | ", index, " | requested=", width * 1.25, " field=", target_width, " measured=", measured, " | ", editor.status_label.text)
  check(absf(measured - target_width) < 0.001, "Exact width reaches the entered target for " + editor.document.gameplay_objects[index].type)
  editor.undo()
  baseline = editor.document.editing_fingerprint()
  exact(Vector2.ZERO, 0, 0.001, 1)
  print("EXACT INVALID | ", index, " | field=", editor.workspace_tools.scale_value.value, " undo=", editor.undo_stack.size(), " | ", editor.status_label.text)
  check(editor.document.editing_fingerprint() == baseline and editor.undo_stack.is_empty(), "Impossible target dimension rejects without Undo for object %d" % index)
 reset()
 editor.canvas.select_gameplay(9)
 key(KEY_BRACKETRIGHT)
 check(is_equal_approx(editor.document.gameplay_objects[9].properties.width, Fixture.linked().gameplay_objects[9].properties.width * 1.1), "Bracket scaling uses proportional sizing")
 key(KEY_R)
 check(is_equal_approx(editor.document.gameplay_objects[9].rotation_degrees, 38.0), "Keyboard R rotates selected hardware fifteen degrees")
 editor._preview_gizmo(1.2, 15.0, editor.canvas.transform_pivot())
 check(editor.canvas.gizmo_document != null and editor.canvas.gizmo_error.is_empty(), "Valid handle preview owns a separate candidate")
 baseline = editor.document.editing_fingerprint()
 editor._preview_gizmo(100000, 0, editor.canvas.transform_pivot())
 check(editor.canvas.gizmo_document == null and not editor.canvas.gizmo_error.is_empty() and editor.document.editing_fingerprint() == baseline, "Invalid handle preview cannot mutate source")

func copy_checks() -> void:
 reset()
 editor.canvas.set_object_selection(Selection.single("gameplay", 5))
 var before: String = editor.document.editing_fingerprint()
 var hardware_count: int = editor.document.gameplay_objects.size()
 key(KEY_C, true)
 key(KEY_V, true, false, true)
 check(editor.document.gameplay_objects.size() == hardware_count + 4 and editor.document.validation_errors().is_empty(), "Ctrl+C / Ctrl+Alt+V copies the complete linked group")
 check(editor.document.gameplay_objects[hardware_count].position == editor.document.gameplay_objects[5].position, "Paste-in-place preserves exact coordinates")
 editor.undo()
 check(editor.document.editing_fingerprint() == before, "Paste undoes to exact source")
 key(KEY_X, true)
 check(editor.document.gameplay_objects.size() == hardware_count - 4 and editor.document.validation_errors().is_empty(), "Ctrl+X removes complete group and prunes outside links")
 editor.undo()
 check(editor.document.editing_fingerprint() == before, "Cut restores IDs, links and metadata through Undo")
 editor.canvas.select_gameplay(0)
 key(KEY_D, true)
 var first_offset: Vector2 = editor._last_duplicate_offset
 editor.move_selected_objects(Vector2(25.25, -10.75))
 var repeat: Vector2 = first_offset + Vector2(25.25, -10.75)
 check(editor._last_duplicate_offset == repeat, "Moving the duplicate sets repeat spacing")
 editor.undo()
 check(editor._last_duplicate_offset == first_offset, "Undo restores preceding duplicate spacing")
 editor.redo()
 check(editor._last_duplicate_offset == repeat, "Redo restores adjusted duplicate spacing")
 var origin: Vector2 = editor.document.gameplay_objects[-1].position
 key(KEY_D, true, true)
 check(editor.document.gameplay_objects[-1].position.distance_to(origin + repeat) < 0.001, "Ctrl+Shift+D repeats the learned offset")
 reset()
 editor.canvas.select_piece(2)
 before = editor.document.editing_fingerprint()
 editor.duplicate_grid(3, 2, Vector2(75, 100))
 check(editor.document.placements.size() == 10 and editor.undo_stack.size() == 1, "Grid produces five copies as one edit")
 editor.undo()
 check(editor.document.editing_fingerprint() == before, "Grid Undo restores full state")
 editor.duplicate_grid(3, 1, Vector2(75, 0))
 check(editor.document.placements.size() == 7, "Row creates exactly two new placements")
 editor.undo()
 editor.duplicate_grid(2, 2, Vector2(-5000, 100))
 check(editor.document.editing_fingerprint() == before and editor.undo_stack.is_empty(), "Partially fitting grid rejects all copies")
 editor.duplicate_grid(257, 1, Vector2.ONE)
 check(editor.document.editing_fingerprint() == before and editor.undo_stack.is_empty(), "Grid position guard rejects more than 256 positions")
 var copied := Clipboard.capture(editor.document, editor.canvas.object_selection())
 copied.count = 20001
 editor._duplicate_copies(copied, [Vector2.ONE])
 check(editor.document.editing_fingerprint() == before and editor.undo_stack.is_empty(), "20,000-object guard rejects before allocating copies")
 reset()
 editor.canvas.select_gameplay(0)
 key(KEY_C, true)
 editor.canvas._cursor_position = editor.canvas.local_pixels_to_screen(Vector2(600.25, 700.75))
 key(KEY_V, true, true)
 check(editor.document.gameplay_objects[-1].position.distance_to(Vector2(600.25, 700.75)) < 0.001, "Ctrl+Shift+V centers the copied object at the cursor")
 editor.undo()
 key(KEY_V, true)
 check(editor.document.gameplay_objects[-1].position == editor.document.gameplay_objects[0].position + Vector2(100, 100), "Ordinary paste advances its session paste offset")

func history_and_stress() -> void:
 for operation: String in ["merge", "smooth", "merge_smooth"]:
  var document := Fixture.base("Terrain recovery")
  document.placements = [Fixture.piece(Vector2i(8, 12)), Fixture.piece(Vector2i(9, 12)), Fixture.piece(Vector2i(8, 13)), Fixture.piece(Vector2i(25, 30))]
  reset(document)
  editor.canvas.set_object_selection({"terrain": [0] if operation == "smooth" else [0, 1, 2]})
  var before: String = editor.document.editing_fingerprint()
  editor.preview_composite(operation)
  check(editor.composite_preview_active and not editor.composite_preview.is_empty(), operation + " preview succeeds")
  editor.apply_composite()
  check(editor.document.placements[0].has("editor_sources"), operation + " records sources")
  editor.restore_terrain_sources()
  check(editor.document.editing_fingerprint() == before, operation + " recovers exact unchanged source records")
  editor.undo()
  check(editor.document.placements[0].has("editor_sources"), operation + " recovery Undo restores composite")
  editor.redo()
  check(editor.document.editing_fingerprint() == before, operation + " recovery Redo preserves unrelated placement")
 for operation: String in ["save", "move", "rotate", "scale", "mirror_h", "mirror_v", "paste", "duplicate", "assembly"]:
  reset(Fixture.smoothed())
  editor.canvas.select_piece(0)
  match operation:
   "save":
    check(editor.save_to("user://qualification-history.tres") and editor.load_from("user://qualification-history.tres"), "Transformed history survives editor Save/reopen")
    editor.canvas.select_piece(0)
   "move": editor.move_selected_objects(Vector2(17.25, -24.75))
   "rotate": editor.transform_selection(1.0, 23.0)
   "scale": editor.transform_selection(1.1, 0.0)
   "mirror_h": editor.flip_active(true)
   "mirror_v": editor.flip_active(false)
   "paste":
    editor.copy_selected()
    editor.paste_selected(false, true)
   "duplicate": editor.duplicate_selected()
   "assembly":
    var saved := Assemblies.save_selection(editor.document, editor.canvas.object_selection(), "Recovered terrain assembly")
    check(saved.error.is_empty(), "Transformed history saves as assembly")
    if not saved.error.is_empty(): continue
    var copied := Assemblies.load_copy(saved.path, 50.0)
    editor.canvas.assembly_copy = copied.copied
    editor.canvas.assembly_center = Vector2.ZERO
    editor._place_assembly(Vector2.ZERO)
    editor.canvas.assembly_copy = {}
    editor.canvas.select_piece(2)
  var index: int = editor.canvas.selected_index
  check(index >= 0 and editor.document.placements[index].has("editor_sources"), operation + " keeps recoverable terrain selected")
  if index < 0 or not editor.document.placements[index].has("editor_sources"): continue
  var recovered := Fixture.History.restore(editor.document.placements[index])
  var before: String = editor.document.editing_fingerprint()
  var unrelated: Array = editor.document.placements.duplicate(true)
  unrelated.remove_at(index)
  editor.restore_terrain_sources()
  check(editor.document.placements.slice(index, index + recovered.sources.size()) == recovered.sources, operation + " Unsmooth restores transformed source records")
  var retained: Array = editor.document.placements.duplicate(true)
  for removed in recovered.sources.size(): retained.remove_at(index)
  check(retained == unrelated and editor.document.validation_errors().is_empty(), operation + " Unsmooth preserves every unrelated placement")
  var after: String = editor.document.editing_fingerprint()
  editor.undo()
  check(editor.document.editing_fingerprint() == before, operation + " Unsmooth Undo restores full prior state")
  editor.redo()
  check(editor.document.editing_fingerprint() == after, operation + " Unsmooth Redo restores full recovered state")
 reset(Fixture.base("Deterministic Undo stress"))
 var initial: String = editor.document.editing_fingerprint()
 editor.add_placement(Fixture.piece(Vector2i(8, 12)))
 editor.add_placement(Fixture.piece(Vector2i(9, 12)))
 var item := Objects.make_placement("spring")
 item.position = Vector2(600, 800)
 editor.add_gameplay_placement(item)
 editor.canvas.set_object_selection({"terrain": [0, 1], "gameplay": [0]})
 editor.group_selection()
 editor.lock_selection()
 editor.unlock_all()
 editor.canvas.set_object_selection({"terrain": [0]})
 var hidden: Resource = editor.document.copy_document()
 hidden.editor_hidden = editor.canvas.object_selection()
 editor._commit_candidate(hidden)
 editor.workspace_tools._reveal_objects()
 editor.canvas.set_object_selection({"terrain": [0]})
 editor.move_selected_objects(Vector2(37.25, -11.75))
 exact(Vector2(8.25, 12.75), 13.0, 110)
 editor.flip_active(true)
 editor.duplicate_selected()
 editor.ungroup_selection()
 editor.canvas.select_piece(2)
 editor.preview_composite("smooth")
 editor.apply_composite()
 editor.restore_terrain_sources()
 editor.resize_grid(Vector2i(34, 42))
 editor.canvas.set_object_selection({"terrain": [0], "gameplay": [0]})
 var assembly := Assemblies.save_selection(editor.document, editor.canvas.object_selection(), "Stress assembly")
 check(assembly.error.is_empty(), "Stress assembly persists")
 if assembly.error.is_empty():
  var loaded := Assemblies.load_copy(assembly.path, 50.0)
  editor.canvas.assembly_copy = loaded.copied
  editor.canvas.assembly_copy.assembly_name = "Stress assembly"
  editor.canvas.assembly_center = Vector2(500, 700)
  editor._place_assembly(Vector2(600, 700))
  editor._place_assembly(Vector2(700, 700))
  check(editor.document.editor_groups.size() >= 3 and editor.document.validation_errors().is_empty(), "Repeated assemblies have coherent groups and fresh identities")
  editor.canvas.assembly_copy = {}
 editor.canvas.select_gameplay(0)
 editor.delete_selected()
 var final_fingerprint: String = editor.document.editing_fingerprint()
 var count: int = editor.undo_stack.size()
 check(count >= 16 and editor.document.validation_errors().is_empty(), "Stress sequence contains at least sixteen valid independent edits")
 for index in count: editor.undo()
 check(editor.document.editing_fingerprint() == initial and editor.undo_stack.is_empty(), "Undo stress returns the complete starting document")
 for index in count: editor.redo()
 check(editor.document.editing_fingerprint() == final_fingerprint and editor.redo_stack.is_empty(), "Redo stress returns the complete final document")
 check(editor.save_to("user://qualification-stress.tres"), "Stress result saves through the actual editor")
 check(editor.load_from("user://qualification-stress.tres") and editor.document.editing_fingerprint() == final_fingerprint, "Stress save/reopen preserves complete editing state")
 var connections := {}
 for signal_info: Dictionary in editor.canvas.get_signal_list():
  connections[signal_info.name] = editor.canvas.get_signal_connection_list(signal_info.name).size()
 for iteration in 20: editor._refresh()
 var repeated := {}
 for signal_info: Dictionary in editor.canvas.get_signal_list():
  repeated[signal_info.name] = editor.canvas.get_signal_connection_list(signal_info.name).size()
 check(connections == repeated, "Repeated editor refreshes do not accumulate signal connections")

func recovery_and_preferences() -> void:
 reset()
 var workspace: Control = editor.workspace_tools
 var path := "user://qualification-workspace.tres"
 check(editor.save_to(path), "Editor Save creates the source Act")
 var source_hash := FileAccess.get_sha256(path)
 editor.canvas.select_gameplay(0)
 editor.move_selected_objects(Vector2(7.25, 3.75))
 workspace.autosave_enabled.button_pressed = true
 var dirty: String = editor.document.editing_fingerprint()
 # Do not call _autosave: this must be the real 30-second Timer signal.
 var deadline := Time.get_ticks_msec() + 32000
 while Time.get_ticks_msec() < deadline and workspace._autosave_fingerprint != dirty:
  await process_frame
 check(workspace._autosave_fingerprint == dirty, "Real 30-second timer saves committed dirty state")
 var automatic: Array = Recovery.entries().filter(func(entry): return entry.source == path and entry.label == "Autosave")
 check(automatic.size() == 1 and FileAccess.get_sha256(path) == source_hash, "Timer leaves one automatic copy and does not overwrite the source")
 if automatic.is_empty(): return
 var auto_path: String = automatic[0].path
 var auto_time := FileAccess.get_modified_time(auto_path)
 for index in 10: workspace._autosave()
 check(FileAccess.get_modified_time(auto_path) == auto_time, "Unchanged dirty state does not rewrite autosave")
 workspace.autosave_enabled.button_pressed = false
 editor.move_selected_objects(Vector2(2, 3))
 workspace._autosave(true)
 check(workspace._autosave_fingerprint == editor.document.editing_fingerprint(), "Forced recovery works with automatic saving disabled")
 workspace.autosave_enabled.button_pressed = true
 workspace.show_checkpoint_dialog()
 workspace.checkpoint_name.text = "Before destructive test"
 workspace._save_checkpoint()
 workspace.checkpoint_dialog.hide()
 check(Recovery.entries().any(func(entry): return entry.label == "Before destructive test"), "Named checkpoint persists through workspace control")
 editor.move_selected_objects(Vector2(4, 5))
 var before_recovery: String = editor.document.editing_fingerprint()
 editor.request_action("recover:" + auto_path)
 check(Recovery.entries().any(func(entry): return entry.label == "Before recovery" and Act.load_document(entry.path).document.editing_fingerprint() == before_recovery), "Recovery request first protects the dirty document")
 editor.unsaved_dialog.hide()
 editor._continue_action()
 check(editor.current_path.is_empty() and editor.is_dirty() and editor.undo_stack.is_empty(), "Recovery opens an unsaved copy with a fresh history")
 check(FileAccess.get_sha256(path) == source_hash, "Restoring a recovery copy leaves the authored source unchanged")
 check(editor.save_to("user://qualification-recovered-as.tres"), "Recovery supports Save As to a separate destination")
 var bad := Act.new()
 bad.editor_locks = {"terrain": [1234]}
 ResourceSaver.save(bad, "user://qualification-invalid-recovery.tres")
 var intact: String = editor.document.editing_fingerprint()
 workspace.restore_copy("user://qualification-invalid-recovery.tres")
 check(editor.document.editing_fingerprint() == intact, "Invalid recovery preserves the current document")
 editor.error_dialog.hide()
 DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".moved"))
 workspace.restore_copy(auto_path)
 check(editor.current_path.is_empty() and editor.document != null, "Recovery does not depend on the original source still existing")
 check(editor.save_to(path), "Recovered document can be saved after source moved")
 var expected := {"snap_mode": 2, "terrain_snap_step": 0.25, "pivot_mode": 2, "show_transform_handles": false,
  "show_launch_previews": false, "launch_from_spawn": true, "launch_timing_variants": true,
  "launch_contact_fraction": 0.7, "trajectory_gravity_scale": 1.25, "show_terrain": false,
  "show_gameplay": true, "show_decor": false, "show_rings": true, "show_markers": false,
  "selection_filter": "spring", "box_selection_mode": 2}
 var fingerprint: String = editor.document.editing_fingerprint()
 var undo_size: int = editor.undo_stack.size()
 for field: String in expected: editor.canvas.set(field, expected[field])
 editor.canvas._view_origin = Vector2(42.25, -13.75)
 editor.canvas._cell_pixels = 31.5
 editor.canvas.cursor_pivot = Vector2(333.25, 444.75)
 workspace.autosave_enabled.button_pressed = false
 workspace.persist_preferences()
 check(editor.document.editing_fingerprint() == fingerprint and editor.undo_stack.size() == undo_size and not editor.is_dirty(), "All workspace preferences remain outside document and Undo state")
 var receipt := ConfigFile.new()
 receipt.set_value("expected", "fields", expected)
 receipt.set_value("expected", "fingerprint", fingerprint)
 receipt.set_value("expected", "path", path)
 receipt.save("user://qualification-workspace-restart.cfg")

func restart_checks() -> void:
 var receipt := ConfigFile.new()
 check(receipt.load("user://qualification-workspace-restart.cfg") == OK, "Fresh process finds workspace receipt")
 check(editor.current_path == receipt.get_value("expected", "path") and editor.document.editing_fingerprint() == receipt.get_value("expected", "fingerprint"), "Fresh process reopens the last saved Act exactly")
 var expected: Dictionary = receipt.get_value("expected", "fields", {})
 for field: String in expected:
  check(editor.canvas.get(field) == expected[field], "Restart restores preference " + field)
 check(editor.canvas._view_origin == Vector2(42.25, -13.75) and editor.canvas._cell_pixels == 31.5 and editor.canvas.cursor_pivot == Vector2(333.25, 444.75), "Restart restores per-Act camera, zoom and cursor pivot")
 check(not editor.workspace_tools.autosave_enabled.button_pressed and not editor.is_dirty() and editor.undo_stack.is_empty(), "Restart restores autosave preference without dirtying the Act")
 check(editor.workspace_tools.recovery_entries.size() >= 3, "Recovery browser persists across process restart")

func run() -> void:
 root.size = Vector2i(1440, 1000)
 root.gui_embed_subwindows = true
 editor = Scene.instantiate()
 root.add_child(editor)
 for index in 5: await process_frame
 if "--restart" in OS.get_cmdline_user_args(): restart_checks()
 else:
  selection_checks()
  await browser_edit_checks()
  snap_and_transform_checks()
  copy_checks()
  history_and_stress()
  await recovery_and_preferences()
 var owned: WeakRef = weakref(editor)
 editor.free()
 for index in 3: await process_frame
 check(owned.get_ref() == null, "Editor owner and child UI close cleanly")
 var output := FileAccess.open("user://qualification-workspace-result.json", FileAccess.WRITE)
 output.store_string(JSON.stringify({"checks": checks, "failures": failures, "failed": failed}, "  "))
 output.close()
 print("EDITOR WORKSPACE | %d checks | %d failures" % [checks, failures])
 quit(failures)
