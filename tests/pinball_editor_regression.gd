extends SceneTree
const EditorScene = preload("res://scenes/act_geometry_editor.tscn")
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const PATH := "res://test-results/pinball-editor.tres"
var editor: Control
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL | " + label)
 else: print("PASS | " + label)

func pointer(point: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT, shift := false) -> void:
 var event := InputEventMouseButton.new()
 event.position = editor.canvas.local_pixels_to_screen(point)
 event.button_index = button
 event.pressed = pressed
 event.alt_pressed = true
 event.shift_pressed = shift
 editor.canvas._gui_input(event)

func run() -> void:
 if "--reopen" in OS.get_cmdline_user_args():
  var args := OS.get_cmdline_user_args()
  var loaded := ActData.load_document(PATH)
  quit(0 if loaded.document != null and loaded.document.fingerprint() == args[-1] else 1)
  return
 root.size = Vector2i(1280, 900)
 root.gui_embed_subwindows = true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 editor = EditorScene.instantiate()
 root.add_child(editor)
 await process_frame
 var canvas = editor.canvas
 for type: String in ["spinner", "magnetic_field"]:
  canvas.set_gameplay_brush(Objects.make_placement(type))
  pointer(Vector2(155.25, 180.75), true)
  pointer(Vector2(155.25, 180.75), false)
 check(editor.document.gameplay_objects.size() == 2, "Spinner and magnetic field place through canvas gestures")
 check(editor.document.gameplay_objects[0].position.distance_to(Vector2(155.25, 180.75)) < 0.001, "Alt placement retains exact off-grid position")
 canvas.select_gameplay(0)
 editor.set_gameplay_property("width", 51.123456789012345)
 editor.set_gameplay_angle(27.123456789012345)
 var spinner_id: String = editor.document.gameplay_objects[0].object_id
 editor.duplicate_selected()
 check(editor.document.gameplay_objects[2].object_id != spinner_id, "Duplicate gets a fresh stable ID")
 editor.undo()
 check(editor.document.gameplay_objects.size() == 2, "Duplicate is one undo action")
 canvas.set_gameplay_brush(Objects.make_placement("elevated_rail"))
 for point: Vector2 in [Vector2(100.25, 400.75), Vector2(100.25, 300.5), Vector2(280.5, 210.125)]:
  pointer(point, true)
  pointer(point, false)
  # Real clicks have rendered previews between them; drawing must not edit the draft.
  await process_frame
  await process_frame
  check(canvas._rail_draft.properties.points[0] == Vector2.ZERO, "Rendered rail preview preserves its entry control point")
 check(editor.document.gameplay_objects.size() == 2 and canvas._rail_draft.properties.points.size() == 3, "Rail gesture stays a draft until Enter")
 var draft_points: PackedVector2Array = canvas._rail_draft.properties.points
 check(draft_points[1].distance_to(Vector2(0, -100.25)) < 0.001 and draft_points[2].distance_to(Vector2(180.25, -190.625)) < 0.001, "Second and third rail clicks remain at their authored positions")
 var enter := InputEventKey.new()
 enter.pressed = true
 enter.keycode = KEY_ENTER
 canvas._gui_input(enter)
 check(editor.document.gameplay_objects.size() == 3, "Enter commits one path object")
 canvas.select_gameplay(2)
 canvas.rail_edit = true
 editor._refresh()
 var original: Dictionary = editor.document.gameplay_objects[2].duplicate(true)
 pointer(Vector2(100.25, 300.5), true)
 var motion := InputEventMouseMotion.new()
 motion.position = canvas.local_pixels_to_screen(Vector2(135.375, 290.875))
 motion.alt_pressed = true
 canvas._gui_input(motion)
 pointer(Vector2(135.375, 290.875), false)
 check(editor.document.gameplay_objects[2].properties.points[1].distance_to(Vector2(35.125, -109.875)) < 0.001, "Control-point drag changes exact local path coordinates")
 editor.undo()
 check(editor.document.gameplay_objects[2] == original, "Point drag undoes in one step")
 editor.redo()
 canvas.rail_edit = true
 pointer(Vector2(220, 250), true, MOUSE_BUTTON_LEFT, true)
 pointer(Vector2(220, 250), false, MOUSE_BUTTON_LEFT, true)
 check(editor.document.gameplay_objects[2].properties.points.size() == 4, "Shift-click inserts a control point")
 pointer(Vector2(220, 250), true, MOUSE_BUTTON_RIGHT)
 check(editor.document.gameplay_objects[2].properties.points.size() == 3, "Right-click removes a control point")
 var fingerprint: String = editor.document.fingerprint()
 check(editor.document.save_document(PATH) == OK, "Edited objects save with exact numeric properties")
 var loaded := ActData.load_document(PATH)
 check(loaded.document != null and loaded.document.fingerprint() == fingerprint, "Reload preserves transforms, IDs and edited path exactly")
 var output: Array = []
 var exit_code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/pinball_editor_regression.gd", "--", "--reopen", fingerprint], output, true)
 check(exit_code == 0, "Fresh Godot process preserves exact properties and path bits")
 if DisplayServer.get_name() != "headless":
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/pinball-editor.png")
 editor.queue_free()
 await process_frame
 editor = EditorScene.instantiate()
 root.add_child(editor)
 await process_frame
 editor.load_from(PATH)
 check(editor.document.fingerprint() == fingerprint, "Fresh editor instance reopens the exact authored document")
 editor.queue_free()
 await process_frame
 print("RESULT | Pinball editor | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
