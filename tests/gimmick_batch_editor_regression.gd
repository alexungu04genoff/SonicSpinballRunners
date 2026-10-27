extends "res://tests/pinball_editor_regression.gd"
const BATCH_EDITOR_PATH := "res://test-results/gimmick-batch-editor.tres"

func click(point: Vector2, alt := false, shift := false, button := MOUSE_BUTTON_LEFT) -> void:
 for pressed: bool in [true, false]:
  var event := InputEventMouseButton.new()
  event.position = editor.canvas.local_pixels_to_screen(point)
  event.button_index = button
  event.pressed = pressed
  event.alt_pressed = alt
  event.shift_pressed = shift
  editor.canvas._gui_input(event)

func key(code: Key) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.pressed = true
 editor.canvas._gui_input(event)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 root.size = Vector2i(1440, 1000)
 root.gui_embed_subwindows = true
 editor = EditorScene.instantiate()
 root.add_child(editor)
 await process_frame
 var canvas = editor.canvas
 editor.choose_gameplay("lane_barrier")
 click(Vector2(105, 301))
 key(KEY_ENTER)
 check(editor.document.gameplay_objects.is_empty(), "One-post draft cannot commit")
 click(Vector2(203.125, 300.25), true)
 click(Vector2(300, 300))
 await process_frame
 key(KEY_ENTER)
 check(editor.document.gameplay_objects.size() == 1 and canvas._rail_draft.is_empty(), "Three clicks and Enter commit one chain")
 var chain: Dictionary = editor.document.gameplay_objects[0]
 check(chain.position == Vector2(100, 300) and chain.properties.points[1].distance_to(Vector2(103.125, 0.25)) < 0.0001, "Normal post snap and Alt exact coordinates coexist")
 check(chain.properties.points.size() == 3, "Draft survives rendered preview without extra posts")
 editor.undo()
 check(editor.document.gameplay_objects.is_empty(), "Whole chain is one undo action")
 editor.redo()
 canvas.select_gameplay(0)
 canvas.rail_edit = true
 click(Vector2(250, 303.125), true, true)
 chain = editor.document.gameplay_objects[0]
 check(chain.properties.points.size() == 4 and chain.properties.points[2] == Vector2(150, 3.125), "Shift-click inserts between nearest posts")
 click(Vector2(250, 303.125), true, false, MOUSE_BUTTON_RIGHT)
 check(chain.properties.points.size() == 3, "Right-click removes selected post")
 click(Vector2(100, 300), true, false, MOUSE_BUTTON_RIGHT)
 click(Vector2(203.125, 300.25), true, false, MOUSE_BUTTON_RIGHT)
 check(chain.properties.points.size() == 2, "Post removal keeps minimum two")
 var post: Vector2 = chain.position + chain.properties.points[-1]
 var down := InputEventMouseButton.new()
 down.position = canvas.local_pixels_to_screen(post)
 down.button_index = MOUSE_BUTTON_LEFT
 down.pressed = true
 canvas._gui_input(down)
 var drag := InputEventMouseMotion.new()
 drag.position = canvas.local_pixels_to_screen(Vector2(310.125, 327.75))
 drag.alt_pressed = true
 canvas._gui_input(drag)
 down.position = drag.position
 down.alt_pressed = true
 down.pressed = false
 canvas._gui_input(down)
 check(chain.properties.points[-1] == Vector2(210.125, 27.75), "Post drag preserves exact Alt coordinates")
 canvas.rail_edit = false
 var geometry: PackedVector2Array = chain.properties.points.duplicate()
 editor.set_gameplay_angle(31.123456789012345)
 editor.move_gameplay_placement(0, Vector2(125.25, 310.5))
 check(chain.properties.points == geometry, "Moving / rotating chain retains ordered internal geometry")
 editor.set_gameplay_property("reward_type", "rings")
 editor.set_gameplay_property("lane_reward", 3.0)
 editor.set_gameplay_property("completion_bonus", 1234.123456789012345)
 editor.set_gameplay_property("reset_delay", 1.123456789012345)
 editor.choose_gameplay("lane_barrier")
 click(Vector2(100, 100))
 click(Vector2(200, 100))
 key(KEY_ESCAPE)
 check(editor.document.gameplay_objects.size() == 1 and canvas._rail_draft.is_empty(), "Escape cancels unfinished chain")
 click(Vector2(100, 100))
 click(Vector2(200, 100))
 click(Vector2(200, 100), false, false, MOUSE_BUTTON_RIGHT)
 check(editor.document.gameplay_objects.size() == 1 and canvas._rail_draft.is_empty(), "Right-click cancels unfinished creation")
 for type: String in ["wall_switch", "switch_target", "diverter", "dash_panel", "one_way_gate"]:
  editor.choose_gameplay(type)
  click(Vector2(150 + 50 * editor.document.gameplay_objects.size(), 450), true)
 check(editor.document.gameplay_objects.size() == 6, "All four mechanics appear and place from gameplay palette")
 var selected: Array[int] = [1, 2]
 canvas.set_gameplay_selection(selected)
 editor.create_switch_bank()
 var bank: Dictionary = editor.document.switch_banks[0]
 var route_id: String = editor.document.gameplay_objects[3].object_id
 editor.set_bank_action(bank.bank_id, route_id, "toggle")
 editor.set_bank_action(bank.bank_id, editor.document.gameplay_objects[5].object_id, "open")
 check(bank.actions.size() == 2 and bank.members.size() == 2 and editor.document.validation_errors().is_empty(), "Mixed switch bank links explicit gate and diverter actions")
 editor.undo()
 check(editor.document.switch_banks[0].actions.size() == 1, "Bank action edit supports undo")
 editor.redo()
 canvas.select_gameplay(4)
 editor.set_gameplay_angle(68.123456789012345)
 editor.set_gameplay_property("boost_strength", 520.123456789012345)
 editor.set_gameplay_property("directional_influence", 63.123456789012345)
 editor.document.spawn_position = Vector2(300, 550)
 var fingerprint: String = editor.document.fingerprint()
 check(editor.save_to(BATCH_EDITOR_PATH), "Act Editor saves complete mechanic batch")
 check(editor.load_from(BATCH_EDITOR_PATH) and editor.document.fingerprint() == fingerprint, "Act Editor reload retains exact new transforms, properties, posts and actions")
 canvas.select_gameplay(3)
 editor.delete_selected()
 check(editor.document.switch_banks[0].actions.size() == 1 and editor.document.validation_errors().is_empty(), "Deleting diverter prunes generic action links")
 editor.undo()
 check(editor.document.fingerprint() == fingerprint, "Undo restores deleted diverter and exact bank relationships")
 if DisplayServer.get_name() != "headless":
  editor.palette_tabs.current_tab = 1
  editor._change_palette_tab(1)
  canvas.select_gameplay(0)
  editor._refresh()
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/gimmick-batch-editor.png")
 editor.free()
 print("RESULT | Gimmick batch editor | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
