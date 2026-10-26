extends SceneTree
const Preview = preload("res://scripts/act_editor/launch_preview.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func check(value: bool, label: String) -> void:
 if not value:
  failures += 1
  push_error(label)
func run() -> void:
 var left := Preview.shots(Objects.make_placement("left_flipper"), 50.0)
 var right := Preview.shots(Objects.make_placement("right_flipper"), 50.0)
 check(left.size() == 12 and right.size() == 12, "Swing and contact samples exist")
 for i in left.size():
  check(is_equal_approx(left[i].velocity.x, -right[i].velocity.x) and is_equal_approx(left[i].velocity.y, right[i].velocity.y), "Handedness mirrors launch")
  check(-left[i].velocity.y <= Preview.Profile.flipper_upward_speed_limit * sqrt(0.5) + 0.01, "Authored ball size caps upward speed")
 var bumper := Objects.make_placement("round_bumper")
 var shots := Preview.shots(bumper, 50.0)
 check(is_equal_approx(shots[0].velocity.length(), 170.0) and is_equal_approx(shots[1].velocity.length(), 200.0), "Bumper min/max use base Sonic rebound")
 var path := Preview.trajectory(shots[0])
 check(path[0].is_equal_approx(shots[0].origin) and is_equal_approx(path[-1].y, path[0].y), "Ballistic flight returns to launch height")
 var scene: Control = load("res://scenes/act_geometry_editor.tscn").instantiate()
 root.add_child(scene)
 for dimensions in [Vector2i(1280, 900), Vector2i(1920, 1080)]:
  root.size = dimensions
  await process_frame
  await process_frame
  check(scene.size.x <= dimensions.x + 1, "Editor fits window width")
  check(scene.canvas.size.y > dimensions.y * 0.6, "Map receives most of window height")
  var original_rect: Rect2 = scene.canvas.get_global_rect()
  for kind in ["spring", "elevated_rail", "round_bumper", "left_flipper"]:
   scene.choose_gameplay(kind)
   await process_frame
   await process_frame
   check(scene.canvas.get_global_rect().is_equal_approx(original_rect), "Canvas stays fixed at " + str(dimensions))
  scene._select_mode()
 check(not scene.buttons.has("example") and not scene.buttons.has("gimmicks") and not scene.buttons.has("quit"), "Requested toolbar buttons removed")
 var rect: Rect2 = scene.canvas.get_global_rect()
 for kind in ["spring", "elevated_rail", "left_flipper", "round_bumper"]:
  scene.choose_gameplay(kind)
  scene._set_status("Long status text ".repeat(40))
  await process_frame
  await process_frame
  check(scene.canvas.get_global_rect().is_equal_approx(rect), "Properties and status do not move the canvas")
 check(scene.document.gameplay_objects.is_empty(), "Brush preview does not place objects")
 for kind in ["one_way_gate", "spinner", "switch_target", "magnetic_field", "round_bumper", "triangle_bumper"]:
  scene.choose_gameplay(kind)
  var key: String = {"one_way_gate": "width", "spinner": "width", "switch_target": "scale", "magnetic_field": "radius", "round_bumper": "scale", "triangle_bumper": "scale"}[kind]
  var previous: float = scene._active_gameplay().properties[key]
  var zoom: float = scene.canvas._cell_pixels
  var wheel := InputEventMouseButton.new()
  wheel.button_index = MOUSE_BUTTON_WHEEL_UP
  wheel.pressed = true
  wheel.shift_pressed = true
  scene.canvas._gui_input(wheel)
  check(scene._active_gameplay().properties[key] > previous and scene.canvas._cell_pixels == zoom, "Shift wheel scales " + kind + " without zooming")
  check(scene.document.gameplay_objects.is_empty(), "Scaling a brush does not place it")
 var target := Objects.make_placement("switch_target")
 target.properties.scale = 2.0
 check(is_equal_approx(Objects.local_points(target, 50.0)[0].length(), 36.0), "Target preview uses shared scaled collision radius")
 var old_target := Objects.make_placement("switch_target")
 old_target.properties.erase("scale")
 check(Objects.switch_radius(old_target) == 18.0, "Existing target files retain original radius")
 var stored := preload("res://scripts/act_editor/act_geometry.gd").new()
 stored.gameplay_objects.append(target)
 var target_path := "res://test-results/scaled-target.tres"
 check(stored.save_document(target_path) == OK, "Scaled target saves")
 var loaded := preload("res://scripts/act_editor/act_geometry.gd").load_document(target_path)
 check(loaded.document != null and Objects.switch_radius(loaded.document.gameplay_objects[0]) == 36.0, "Scaled target round-trips")
 scene.choose_gameplay("spring")
 check(scene._active_gameplay().properties.launch_strength == 300.0, "New spring defaults to 300")
 scene.set_gameplay_property("launch_strength", 350.0)
 check(scene._active_gameplay().properties.launch_strength == 350.0 and scene.document.gameplay_objects.is_empty(), "Properties edit before placement")
 check(not scene.verification_report().errors.is_empty(), "Verify catches missing spawn")
 scene.document.spawn_position = Vector2(100, 100)
 scene.document.cell_size = 100.0
 var rail := Objects.make_placement("elevated_rail")
 rail.position = Vector2(300, 300)
 rail.properties.width = 18.0
 scene.document.gameplay_objects.append(rail)
 var fingerprint: String = scene.document.fingerprint()
 check(" ".join(scene.verification_report().errors).contains("width"), "Verify uses runtime rail clearance")
 check(scene.document.fingerprint() == fingerprint, "Verify does not mutate the document")
 rail.properties.width = 40.0
 scene.document.gameplay_objects[0] = rail
 check(scene.verification_report().errors.is_empty(), "Verify accepts a clear ramp")
 scene._refresh()
 check(scene.buttons.spawn_reminder.text == "Spawn point: set" and scene.buttons.entry.text == "Entry: unset", "Floating reminders track marker state")
 scene.load_from("res://data/acts/curve_garden.tres")
 var paddle := Objects.make_placement("left_flipper")
 paddle.position = Vector2(220, 480)
 scene.add_gameplay_placement(paddle)
 scene.canvas.select_gameplay(scene.document.gameplay_objects.size() - 1)
 scene._refresh()
 await process_frame
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/editor-clean-layout.png")
 scene.queue_free()
 await process_frame
 print("EDITOR LAUNCH PREVIEW: %d failures" % failures)
 quit(failures)


