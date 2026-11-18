extends SceneTree
## Deferred regression coverage for the scalable editor pass. No rendering required.
const Act = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Decor = preload("res://scripts/act_editor/decor_slots.gd")
const EnemyRuntime = preload("res://scripts/enemies/enemy_runtime.gd")
const EditorScene = preload("res://scenes/act_geometry_editor.tscn")
var editor: Control
var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func fixture() -> void:
 editor.new_document()
 var piece := {"shape_id": "rectangle_1x1", "base_size": Vector2i.ONE, "anchor": Vector2i(4, 4), "quarter_turns": 0, "flip_h": false, "flip_v": false}
 editor.document.placements.append(piece)
 var spring := Objects.make_placement("spring")
 spring.position = Vector2(350, 275)
 editor.document.gameplay_objects.append(spring)
 var decor := Decor.make_slot("small")
 decor.position = Vector2(400, 400)
 editor.document.decor_slots.append(decor)
 editor.document.ring_trails.append({"start": Vector2(400, 200), "end": Vector2(450, 200), "spacing": 25.0})
 editor.document.spawn_position = Vector2(100, 100)
 editor.document.goal_position = Vector2(150, 150)
 editor.document.activation_y = 500.0
 editor.canvas.set_document(editor.document)
 editor._refresh()

func mouse(at: Vector2, pressed: bool, shift := false) -> void:
 var event := InputEventMouseButton.new()
 event.position = editor.canvas.local_pixels_to_screen(at)
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = pressed
 event.shift_pressed = shift
 editor.canvas._gui_input(event)

func motion(at: Vector2, shift := false) -> void:
 var event := InputEventMouseMotion.new()
 event.position = editor.canvas.local_pixels_to_screen(at)
 event.shift_pressed = shift
 editor.canvas._gui_input(event)

func run() -> void:
 root.size = Vector2i(1440, 1000)
 editor = EditorScene.instantiate()
 root.add_child(editor)
 await process_frame
 await process_frame
 editor.choose_shape("rectangle_1x1")
 check(editor.canvas.brush.terrain_scale == 0.5, "New terrain starts at half size")
 editor._scale_active(2.0)
 check(editor.canvas.brush.terrain_scale == 1.0 and editor.document.placements.is_empty(), "Double-size changes only the brush")
 check(editor.canvas.show_launch_previews and not editor.canvas.launch_from_spawn, "Launch-strength previews start enabled without needing Spawn")
 fixture()
 editor.canvas.show_decor = false
 editor.canvas.show_gameplay = false
 editor.select_all_content()
 check(editor.canvas.selection_count() == 7 and editor.canvas.show_decor and editor.canvas.show_gameplay, "Select All reveals and includes every content layer and lifecycle marker")
 var before: String = editor.document.fingerprint()
 mouse(Vector2(210, 210), true)
 motion(Vector2(223.25, 217.5))
 mouse(Vector2(223.25, 217.5), false)
 check(editor.document.spawn_position.is_equal_approx(Vector2(113.25, 107.5)) and editor.document.goal_position.is_equal_approx(Vector2(163.25, 157.5)) and is_equal_approx(editor.document.activation_y, 507.5), "Default group drag preserves fractional offsets through release and carries markers")
 check(editor.undo_stack.size() == 1, "A whole-level drag is one undo step")
 editor.undo()
 check(editor.document.fingerprint() == before and editor.canvas.selected_markers.size() == 3, "Undo restores exact content and marker selection")
 mouse(Vector2(210, 210), true, true)
 motion(Vector2(246, 246), true)
 mouse(Vector2(246, 246), false)
 check(editor.document.spawn_position == Vector2(150, 150), "Shift snaps a group and releasing it at mouse-up preserves the preview")
 editor.undo()
 editor.transform_selection(1.1, 15.0)
 check(editor.document.validation_errors().is_empty() and editor.document.gameplay_objects[0].rotation_degrees == 15.0 and is_equal_approx(editor.document.gameplay_objects[0].properties.launch_strength, 300.0), "Mixed transforms rotate and scale physical dimensions without scaling strength")
 editor.undo()
 check(editor.document.fingerprint() == before, "Mixed transformation undoes atomically")
 editor.canvas.select_piece(0)
 editor.set_terrain_scale(2.0)
 check(Shapes.placement_position(editor.document.placements[0]) == Vector2(3.5, 3.5) and Shapes.scaled_size(editor.document.placements[0]) == Vector2(2, 2), "Single terrain sizing preserves the configured center pivot and exceeds original size")
 editor.undo()
 editor.canvas.select_ring(0)
 editor.transform_selection(1.0, 90.0)
 check(editor.document.ring_trails[0].start.is_equal_approx(Vector2(425, 175)) and editor.document.ring_trails[0].end.is_equal_approx(Vector2(425, 225)), "Line-ring rotation preserves its center")
 editor.undo()
 editor.toggle_boundary_tool()
 mouse(Vector2(600, 300), true)
 motion(Vector2(700, 300))
 mouse(Vector2(700, 300), false)
 check(editor.document.grid_size == Vector2i(14, 12) and editor.document.spawn_position == Vector2(100, 100), "Right boundary handle changes whole columns without moving content")
 editor.undo()
 before = editor.document.fingerprint()
 editor.resize_grid(Vector2i(2, 2))
 check(editor.document.fingerprint() == before, "Invalid boundary shrink preserves the entire document")
 editor.canvas.select_piece(0)
 editor.set_terrain_scale(0.5 * 1.1 * 1.1)
 var path := "user://editor-scalability-regression.tres"
 before = editor.document.fingerprint()
 check(editor.document.save_document(path) == OK, "Fractional terrain scale saves")
 var loaded := Act.load_document(path)
 check(loaded.document != null and loaded.document.fingerprint() == before, "Fractional scale reloads without float drift")
 var enemy := Objects.make_placement("buzz_bomber")
 enemy.position = Vector2(100, 100)
 enemy.rotation_degrees = 90.0
 var runtime := EnemyRuntime.new()
 runtime.add(enemy)
 runtime.tick(EnemyRuntime.PATROL_PAUSE_SECONDS + 0.25)
 check(is_equal_approx(enemy.position.x, 100.0) and enemy.position.y > 100.0, "Rotated Buzz patrol moves on the authored axis")
 var hit := EnemyRuntime.swept_contact(enemy, enemy.position + Vector2(-30, 0), enemy.position + Vector2(30, 0), 1.0)
 check(not hit.is_empty(), "Rotated Buzz retains its authoritative swept sensor")
 editor.free()
 print("EDITOR SCALABILITY | %d checks | %d failures" % [checks, failures])
 quit(failures)
