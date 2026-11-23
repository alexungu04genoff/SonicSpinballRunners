extends "res://tests/pinball_editor_regression.gd"
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Decor = preload("res://scripts/act_editor/decor_slots.gd")
const Preview = preload("res://scripts/act_editor/launch_preview.gd")

func mouse(at: Vector2, pressed: bool, alt := false, shift := false, button := MOUSE_BUTTON_LEFT, ctrl := false) -> void:
 var event := InputEventMouseButton.new()
 event.position = editor.canvas.local_pixels_to_screen(at)
 event.button_index = button
 event.pressed = pressed
 event.alt_pressed = alt
 event.shift_pressed = shift
 event.ctrl_pressed = ctrl
 editor.canvas._gui_input(event)

func motion(at: Vector2, alt := false, ctrl := false) -> void:
 var event := InputEventMouseMotion.new()
 event.position = editor.canvas.local_pixels_to_screen(at)
 event.alt_pressed = alt
 event.ctrl_pressed = ctrl
 event.button_mask = MOUSE_BUTTON_MASK_LEFT
 editor.canvas._gui_input(event)

func alt_key(pressed: bool) -> void:
 var event := InputEventKey.new()
 event.keycode = KEY_ALT
 event.pressed = pressed
 event.alt_pressed = pressed
 editor.canvas._gui_input(event)

func wheel(direction := 1.0) -> void:
 mouse(Vector2(250, 250), true, false, true, MOUSE_BUTTON_WHEEL_UP if direction > 0 else MOUSE_BUTTON_WHEEL_DOWN)

func shortcut(code: Key) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.pressed = true
 event.ctrl_pressed = true
 root.push_input(event, true)
 await process_frame

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 root.size = Vector2i(1440, 1000)
 root.gui_embed_subwindows = true
 editor = EditorScene.instantiate()
 root.add_child(editor)
 await process_frame
 await process_frame
 for definition: Dictionary in Objects.definitions():
  editor.new_document()
  var type: String = definition.id
  editor.choose_gameplay(type)
  var original: Dictionary = editor.canvas.gameplay_brush.duplicate(true)
  var zoom: float = editor.canvas._cell_pixels
  wheel()
  check(editor.canvas.gameplay_brush.properties != original.properties and editor.document.gameplay_objects.is_empty() and editor.canvas._cell_pixels == zoom, type + ": Shift-wheel sizes the brush without placement or zoom")
  var at := Vector2(200.25, 250.75)
  mouse(at, true, true)
  if type == "drop_target_bank": motion(at + Vector2(130, 0), true)
  mouse(at + Vector2(130, 0) if type == "drop_target_bank" else at, false, true)
  if type in ["elevated_rail", "lane_barrier", "launch_tube"]:
   mouse(at + Vector2(100.5, -60.25), true, true)
   mouse(at + Vector2(100.5, -60.25), false, true)
   var enter := InputEventKey.new()
   enter.keycode = KEY_ENTER
   enter.pressed = true
   editor.canvas._gui_input(enter)
  check(editor.document.gameplay_objects.size() == 1, type + ": actual placement gesture commits")
  if editor.document.gameplay_objects.is_empty(): continue
  var placed: Dictionary = editor.document.gameplay_objects[0].duplicate(true)
  var expected := at + Vector2(65, 0) if type == "drop_target_bank" else at
  check(placed.position.distance_to(expected) < 0.001, type + ": Alt placement keeps fractional coordinates")
  editor._select_mode()
  editor.canvas.select_gameplay(0)
  editor.canvas.pivot_mode = 1 # Anchor-specific check; the default center pivot can move asymmetric anchors.
  var history: int = editor.undo_stack.size()
  wheel()
  check(editor.document.gameplay_objects[0].properties != placed.properties and editor.document.gameplay_objects[0].position == placed.position and editor.document.gameplay_objects[0].object_id == placed.object_id, type + ": placed sizing preserves anchor and identity")
  check(editor.undo_stack.size() == history + 1, type + ": sizing is one undo step")
  editor.undo()
  check(editor.document.gameplay_objects[0] == placed, type + ": undo restores exact properties")
  var destination: Vector2 = placed.position + Vector2(13.125, 17.875)
  mouse(placed.position, true)
  motion(destination)
  alt_key(true)
  alt_key(false)
  mouse(destination, false)
  check(editor.document.gameplay_objects[0].position.distance_to(destination) < 0.001, type + ": late Alt frees drag and release preserves position")
  check(editor.document.validation_errors().is_empty(), type + ": edited record validates")
 check_size_buttons_and_palette()
 check_cell_center_placement()
 await check_handles()
 await check_clipboard()
 check_guides()
 await captures()
 editor.free()
 await process_frame
 print("RESULT | Editor interaction | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func check_size_buttons_and_palette() -> void:
 editor.new_document()
 var basics := PackedStringArray()
 for button: Button in editor.palette_list.get_children():
  basics.append(button.get_meta("shape_id"))
 check(basics.slice(0, 11) == PackedStringArray(["triangle_1x1", "triangle_1x2", "triangle_1x3", "triangle_2x2", "triangle_3x2", "triangle_3x3", "rectangle_1x1", "rectangle_2x2", "rectangle_3x3", "rectangle_1x2", "rectangle_1x3"]), "Filled triangles, squares and rectangles lead the terrain palette")
 editor.half_size_steps.button_pressed = true
 editor.choose_shape("rectangle_1x1")
 editor.buttons.size_up.pressed.emit()
 editor.buttons.size_up.pressed.emit()
 check(is_equal_approx(editor.canvas.brush.terrain_scale, 1.5), "Two Size + clicks take a new 0.5× terrain brush to 1.5×")
 editor.buttons.size_down.pressed.emit()
 check(is_equal_approx(editor.canvas.brush.terrain_scale, 1.0), "Size − subtracts exactly 0.5×")
 editor.set_terrain_scale(1.25)
 editor.buttons.size_up.pressed.emit()
 check(is_equal_approx(editor.canvas.brush.terrain_scale, 1.75), "A custom scale keeps its fractional offset")
 editor.set_terrain_scale(Shapes.MIN_SCALE)
 editor.buttons.size_down.pressed.emit()
 check(is_equal_approx(editor.canvas.brush.terrain_scale, Shapes.MIN_SCALE), "Size − respects the terrain minimum")
 editor.half_size_steps.button_pressed = false
 editor.buttons.size_up.pressed.emit()
 check(is_equal_approx(editor.canvas.brush.terrain_scale, Shapes.MIN_SCALE * 1.1), "Unchecking restores proportional button sizing")
 editor.half_size_steps.button_pressed = true
 editor.choose_gameplay("spring")
 editor.buttons.size_up.pressed.emit()
 editor.buttons.size_up.pressed.emit()
 check(is_equal_approx(editor.canvas.gameplay_brush.properties.width, 80.0), "Hardware steps use half of its original physical size")
 editor.choose_gameplay("round_bumper")
 mouse(Vector2(250, 250), true, true)
 editor._select_mode()
 editor.canvas.select_gameplay(0)
 var original: Dictionary = editor.document.gameplay_objects[0].duplicate(true)
 editor.buttons.size_up.pressed.emit()
 check(is_equal_approx(editor.document.gameplay_objects[0].properties.scale, 1.5) and editor.document.gameplay_objects[0].position == original.position, "A placed bumper grows half a step at its anchor")
 editor.undo()
 check(editor.document.gameplay_objects[0] == original, "One undo restores a size button edit")
 editor.choose_shape("triangle_1x1")
 var triangle: Dictionary = editor.canvas.brush.duplicate(true)
 triangle.anchor = Vector2i(5,5)
 editor.add_placement(triangle)
 editor._select_mode()
 editor.canvas.set_object_selection({"gameplay":[0], "terrain":[0]})
 editor.canvas.active_target = {"kind":"terrain","index":0}
 editor.buttons.size_up.pressed.emit()
 check(is_equal_approx(editor.document.placements[0].terrain_scale, 1.0) and is_equal_approx(editor.document.gameplay_objects[0].properties.scale, 2.0), "A mixed selection scales proportionally from its active triangle")
 editor.undo()
 check(editor.document.gameplay_objects[0] == original and editor.document.placements[0] == triangle, "One undo restores the whole group")
 editor.choose_marker("goal")
 editor.document.goal_diameter_cells = 1.275
 editor.buttons.size_up.pressed.emit()
 check(is_equal_approx(editor.document.goal_diameter_cells, 1.775), "Goal button steps preserve an exact loaded diameter")
 editor.new_document()

func check_cell_center_placement() -> void:
 editor.new_document()
 var canvas = editor.canvas
 var old_mode: int = canvas.snap_mode
 var old_step: float = canvas.terrain_snap_step
 var cell := float(editor.document.cell_size)
 var cursor := Vector2(3.2, 4.8) * cell
 var center := Vector2(3.5, 4.5) * cell
 canvas.terrain_snap_step = 1.0
 editor.choose_gameplay("round_bumper")
 for mode in [canvas.Snap.Mode.FREE, canvas.Snap.Mode.RELATIVE, canvas.Snap.Mode.ABSOLUTE]:
  canvas.snap_mode = mode
  motion(cursor, false, true)
  var preview: Vector2 = canvas.placement_position(cursor, false)
  mouse(cursor, true, false, false, MOUSE_BUTTON_LEFT, true)
  check(preview == center and editor.document.gameplay_objects.back().position == preview, "Ctrl-click matches the centered bumper preview in " + canvas.Snap.LABELS[mode])
 mouse(cursor, true)
 check(editor.document.gameplay_objects.back().position == Vector2(3, 5) * cell, "Releasing Ctrl restores grid intersection placement")
 mouse(cursor, true, true, false, MOUSE_BUTTON_LEFT, true)
 check(Vector2(editor.document.gameplay_objects.back().position).is_equal_approx(cursor), "Alt retains precise placement when Ctrl is held")
 for step: float in [0.5, 0.25]:
  canvas.terrain_snap_step = step
  motion(cursor, false, true)
  canvas._drop_data(canvas.local_pixels_to_screen(cursor), {"gameplay_stamp": canvas.gameplay_brush})
  var expected := Vector2(3.25, 4.75) if step == 0.5 else Vector2(3.125, 4.875)
  check(editor.document.gameplay_objects.back().position == expected * cell, "Ctrl palette drop uses the center of the %s-cell subdivision" % step)
 canvas.terrain_snap_step = 1.0
 editor.choose_shape("rectangle_1x2")
 var stamp: Dictionary = canvas.brush.duplicate(true)
 stamp.quarter_turns = 1
 canvas.set_brush(stamp)
 mouse(cursor, true, false, false, MOUSE_BUTTON_LEFT, true)
 var terrain: Dictionary = editor.document.placements.back()
 check(Shapes.placement_position(terrain) + Shapes.scaled_size(terrain) * 0.5 == center / cell, "Ctrl centers a rotated half-size terrain footprint")
 stamp.terrain_scale = 2.0
 canvas._drop_data(canvas.grid_to_screen(Vector2(0.05, 0.05)), {"terrain_stamp": stamp})
 check(Shapes.placement_position(editor.document.placements.back()) == Vector2.ZERO and editor.document.validation_errors().is_empty(), "Ctrl terrain drop keeps a large footprint inside the first cell's Act border")
 editor.choose_decor("small")
 mouse(cursor, true, false, false, MOUSE_BUTTON_LEFT, true)
 check(editor.document.decor_slots.back().position == center, "Ctrl centers a decor slot")
 editor.choose_marker("goal")
 mouse(cursor, true, false, false, MOUSE_BUTTON_LEFT, true)
 check(editor.document.goal_center() == center, "Ctrl centers the goal ring")
 editor.choose_rings()
 var end := Vector2(7.9, 4.1) * cell
 mouse(cursor, true, false, false, MOUSE_BUTTON_LEFT, true)
 motion(end, false, true)
 mouse(end, false, false, false, MOUSE_BUTTON_LEFT, true)
 var trail: Dictionary = editor.document.ring_trails.back()
 check(trail.start == center and trail.end == Vector2(7.5, 4.5) * cell, "Ctrl drag places both ring trail endpoints at cell centers")
 editor.undo()
 check(editor.document.ring_trails.is_empty(), "A centered ring trail undoes as one edit")
 editor._select_mode()
 mouse(Vector2(0.5, 0.5) * cell, true, false, false, MOUSE_BUTTON_LEFT, true)
 check(canvas.selected_indices == [1], "Ctrl-click in Select / Move still toggles the terrain selection")
 canvas.snap_mode = old_mode
 canvas.terrain_snap_step = old_step
 editor.new_document()

func check_handles() -> void:
 editor.new_document()
 editor.choose_gameplay("drop_target_bank")
 var bank_start := Vector2(100.25, 230.5)
 var bank_end := Vector2(281.875, 230.5)
 mouse(bank_start, true, true)
 motion(bank_end)
 alt_key(true)
 alt_key(false)
 mouse(bank_end, false)
 check(editor.document.gameplay_objects[0].position.distance_to((bank_start + bank_end) * 0.5) < 0.001, "Drag-placed Bank keeps the exact span when Alt is released first")
 for type in ["teleporter", "buzz_bomber", "elevated_rail", "lane_barrier", "launch_tube"]:
  editor.new_document()
  var item := Objects.make_placement(type)
  item.position = Vector2(180, 320)
  editor.add_gameplay_placement(item)
  editor._select_mode()
  editor.canvas.select_gameplay(0)
  var props := Objects.properties(item)
  var at: Vector2 = item.position
  if type == "teleporter": at = Objects.teleporter_exit(item)
  elif type == "buzz_bomber": at += Vector2(props.patrol_right, 0)
  else:
   editor.canvas.rail_edit = true
   at += props.points[-1]
  var destination := at + Vector2(17.375, -13.625)
  mouse(at, true)
  motion(destination)
  alt_key(true)
  alt_key(false)
  mouse(destination, false)
  var actual: Dictionary = editor.document.gameplay_objects[0]
  if type == "teleporter": check(Objects.teleporter_exit(actual).distance_to(destination) < 0.001, "Teleporter OUT keeps late-Alt position after Alt release")
  elif type == "buzz_bomber": check(is_equal_approx(actual.properties.patrol_right, destination.x - item.position.x), "Patrol endpoint keeps late-Alt position after Alt release")
  else: check((actual.position + actual.properties.points[-1]).distance_to(destination) < 0.001, type + ": control point keeps late-Alt position after Alt release")
 editor.new_document()
 editor.choose_shape("rectangle_1x1")
 wheel(-1)
 mouse(Vector2(100.25, 200.75), true, true)
 mouse(Vector2(100.25, 200.75), false, true)
 editor._select_mode()
 editor.canvas.select_piece(0)
 check(is_equal_approx(editor.document.placements[0].terrain_scale, 0.5 / 1.1), "Terrain starts at half size and Shift-wheel scales continuously")
 mouse(Vector2(110.25, 210.75), true)
 motion(Vector2(128.625, 231.125))
 alt_key(true)
 alt_key(false)
 mouse(Vector2(128.625, 231.125), false)
 check((Shapes.placement_position(editor.document.placements[0]) * 50.0).distance_to(Vector2(118.625, 221.125)) < 0.001, "Terrain supports late Alt and preserves fractional movement")
 wheel()
 check(is_equal_approx(editor.document.placements[0].terrain_scale, 0.5), "Opposite Shift-wheel restores the placed terrain size")
 var slot := Decor.make_slot("small")
 slot.position = Vector2(350, 350)
 editor.set_decor_slot(-1, slot)
 editor.canvas.select_decor(0)
 editor.canvas.decor_snap = true
 mouse(slot.position, true)
 motion(slot.position + Vector2(13.125, 17.875))
 alt_key(true)
 alt_key(false)
 mouse(slot.position + Vector2(13.125, 17.875), false)
 check(editor.document.decor_slots[0].position.distance_to(slot.position + Vector2(13.125, 17.875)) < 0.001, "Decor supports late Alt with snap enabled")
 wheel()
 check(is_equal_approx(editor.document.decor_slots[0].scale, 1.1), "Placed decor supports proportional Shift-wheel size")
 editor.set_ring_trail(-1, {"start": Vector2(100, 400), "end": Vector2(200, 400), "spacing": 25.0})
 editor.canvas.select_ring(0)
 wheel()
 check(editor.document.ring_trails[0].start.distance_to(Vector2(95, 400)) < 0.001 and editor.document.ring_trails[0].end.distance_to(Vector2(205, 400)) < 0.001, "Ring pattern scales around its center")
 editor.choose_marker("goal")
 var size_before: float = editor.document.goal_diameter_cells
 wheel()
 check(is_equal_approx(editor.document.goal_diameter_cells, size_before * 1.1), "Goal diameter supports proportional Shift-wheel")
 editor.set_connector("entry", 1, 2)
 wheel()
 check(editor.document.entry_width == 3, "Connector width supports Shift-wheel in structural cells")

func check_clipboard() -> void:
 editor.new_document()
 editor.choose_shape("rectangle_1x1")
 var terrain: Dictionary = editor.canvas.brush.duplicate(true)
 Shapes.set_placement_position(terrain, Vector2(1.25, 1.5))
 editor.add_placement(terrain)
 for type in ["switch_target", "wall_switch", "one_way_gate", "diverter"]:
  var item := Objects.make_placement(type)
  item.position = Vector2(120.125 + editor.document.gameplay_objects.size() * 90, 220.75)
  editor.add_gameplay_placement(item)
 var ids: Array = editor.document.gameplay_objects.map(func(item): return item.object_id)
 editor.document.switch_banks = [{"bank_id": "source_bank", "label": "Copied objective", "members": [ids[0], ids[1]], "gates": [ids[2]], "actions": [{"object_id": ids[3], "action": "toggle"}]}]
 var slot := Decor.make_slot("small")
 slot.position = Vector2(80.25, 80.75)
 editor.set_decor_slot(-1, slot)
 editor.set_ring_trail(-1, {"start": Vector2(180, 300), "end": Vector2(280, 320), "spacing": 25.0})
 editor._select_mode()
 editor.canvas.pivot_mode = 0
 var selection := {"terrain": [0], "gameplay": [0, 1, 2, 3], "decor": [0], "ring": [0], "markers": []}
 editor.canvas.set_object_selection(selection)
 editor.canvas.grab_focus()
 var before: String = editor.document.fingerprint()
 var history: int = editor.undo_stack.size()
 wheel()
 check(editor.document.gameplay_objects[0].properties.scale > 1.0 and editor.document.decor_slots[0].scale > 1.0 and editor.document.ring_trails[0].start != Vector2(180, 300) and editor.undo_stack.size() == history + 1, "Mixed selection sizes every category as one edit")
 editor.undo()
 check(editor.document.fingerprint() == before and editor.canvas.object_selection() == selection, "Mixed sizing undo restores exact records and selection")
 await shortcut(KEY_C)
 check(editor.document.fingerprint() == before and editor.undo_stack.size() == history, "Ctrl+C copies mixed selection without an edit")
 await shortcut(KEY_V)
 check(editor.canvas.selection_count() == 7 and editor.document.gameplay_objects.size() == 8 and editor.undo_stack.size() == history + 1, "Ctrl+V through viewport pastes all categories as one edit")
 if editor.document.gameplay_objects.size() != 8: return
 var pasted: Dictionary = editor.document.gameplay_objects[4]
 check(pasted.position.distance_to(editor.document.gameplay_objects[0].position + Vector2(50, 50)) < 0.001 and pasted.object_id != ids[0], "Paste offsets exact positions and assigns fresh object IDs")
 check(editor.document.decor_slots[1].slot_id != editor.document.decor_slots[0].slot_id and editor.document.ring_trails[1].pattern_id != editor.document.ring_trails[0].pattern_id, "Decor and ring identities are fresh")
 var bank: Dictionary = editor.document.switch_banks[1]
 check(bank.bank_id != "source_bank" and bank.members == [pasted.object_id, editor.document.gameplay_objects[5].object_id] and bank.gates == [editor.document.gameplay_objects[6].object_id] and bank.actions[0].object_id == editor.document.gameplay_objects[7].object_id, "Copied switch membership, gates and diverter actions remap internally")
 var pasted_fingerprint: String = editor.document.fingerprint()
 editor.undo()
 check(editor.document.fingerprint() == before and editor.canvas.object_selection() == selection, "One undo restores source document and selection")
 editor.redo()
 check(editor.document.fingerprint() == pasted_fingerprint, "Redo restores exact pasted identities")
 await shortcut(KEY_V)
 check(editor.document.gameplay_objects[8].position.distance_to(editor.document.gameplay_objects[0].position + Vector2(100, 100)) < 0.001, "Repeated paste offsets each new copy")
 check(editor.save_to("res://test-results/editor-interactions.tres") and editor.load_from("res://test-results/editor-interactions.tres"), "Edited selection saves and reloads with valid links")
 editor.title_field.grab_focus()
 var count: int = editor.document.gameplay_objects.size()
 if DisplayServer.get_name() == "headless":
  var paste := InputEventKey.new()
  paste.keycode = KEY_V
  paste.pressed = true
  paste.ctrl_pressed = true
  editor._unhandled_key_input(paste)
 else: await shortcut(KEY_V)
 check(editor.document.gameplay_objects.size() == count, "Ctrl+V in text fields never pastes objects")
 editor.canvas.set_object_selection({"gameplay": [0, 1]})
 editor.copy_selected()
 editor.new_document()
 editor.paste_selected()
 check(editor.document.gameplay_objects.size() == 2 and editor.document.switch_banks.size() == 1 and editor.document.switch_banks[0].gates.is_empty() and editor.document.switch_banks[0].actions.is_empty(), "Clipboard survives New Act without linking to uncopied original targets")
 check(editor.document.validation_errors().is_empty(), "Pasted document validates")
 editor.document.gameplay_objects.append({"type": "round_bumper", "position": Vector2(100.25, 200.5), "rotation_degrees": 0.0})
 editor.canvas.select_gameplay(2)
 wheel()
 check(editor.document.validation_errors().is_empty() and is_equal_approx(editor.document.gameplay_objects[2].properties.scale, 1.1), "Sizing migrates a legacy object without invalid dictionary key types")
 editor.copy_selected()
 editor.new_document()
 editor.paste_selected()
 check(editor.document.gameplay_objects.size() == 1 and editor.document.gameplay_objects[0].has("object_id") and editor.document.validation_errors().is_empty(), "Legacy object clipboard creates a valid fresh identity")

func check_guides() -> void:
 for definition: Dictionary in Objects.definitions():
  if definition.id in ["left_flipper", "right_flipper"]: continue # Existing production-probe regression covers both hands.
  var item := Objects.make_placement(definition.id)
  item.position = Vector2(200.25, 400.75)
  item.rotation_degrees = 23.0
  var original := item.duplicate(true)
  var shots := Preview.shots(item, 50.0)
  var finite := not shots.is_empty()
  for shot: Dictionary in shots:
   var path := Preview.trajectory(shot)
   finite = finite and path.size() >= 2
   for point: Vector2 in path: finite = finite and point.is_finite()
  check(finite and item == original, definition.id + ": finite guide without mutating authored data")
 var sling := Objects.make_placement("slingshot")
 sling.rotation_degrees = 47
 sling.properties.strength = 525
 var shot: Dictionary = Preview.shots(sling, 50.0)[0]
 check(shot.velocity.is_equal_approx(Objects.forward(sling) * 525), "Slingshot guide matches fixed-speed active-face launch")
 var dash := Objects.make_placement("dash_panel")
 shot = Preview.shots(dash, 50.0)[1]
 check(shot.velocity.is_equal_approx(Objects.dash_velocity(Objects.forward(dash) * Preview.SAMPLE_SPEED, dash)), "Dash guide uses runtime direction and cap helper")
 var field := Objects.make_placement("magnetic_field")
 var attract := Preview.trajectory(Preview.shots(field, 50.0)[0])
 field.properties.mode = "repel"
 check(attract != Preview.trajectory(Preview.shots(field, 50.0)[0]), "Magnetic mode changes the curved flyby")
 var spring := Objects.make_placement("spring")
 var balanced := Preview.trajectory(Preview.shots(spring, 50.0)[0])
 var floaty := Preview.trajectory(Preview.shots(spring, 50.0, PhysicsTuning.resolve(PhysicsTuning.FLOATY, {}, []))[0])
 check(floaty != balanced, "Guide follows the selected physics profile")
 for type in ["rectangle_1x1", "wall_1x2", "triangle_2x2"]:
  var placement := {"shape_id": type, "base_size": Shapes.get_definition(type).size, "anchor": Vector2i(2, 5), "quarter_turns": 0, "flip_h": false, "flip_v": false}
  var shots := Preview.shots({"type": "terrain", "placement": placement}, 50.0)
  check(not shots.is_empty() and Preview.trajectory(shots[0]).size() > 2, type + ": terrain has a representative rebound guide")

func captures() -> void:
 if DisplayServer.get_name() == "headless": return
 editor.new_document()
 editor.document.spawn_position = Vector2(300, 100)
 for type in ["slingshot", "magnetic_field", "elevated_rail"]:
  editor.new_document()
  var item := Objects.make_placement(type)
  item.position = Vector2(230, 440)
  if type == "slingshot":
   item.properties.strength = 300.0
   item.rotation_degrees = 24.0
  editor.add_gameplay_placement(item)
  editor._change_palette_tab(1)
  editor._select_mode()
  editor.canvas.select_gameplay(0)
  editor._refresh()
  await process_frame
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/editor-guide-" + type + ".png")
