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
 check(is_equal_approx(shots[0].velocity.length(), 210.0) and is_equal_approx(shots[1].velocity.length(), 250.0), "Bumper min/max use base Sonic rebound")
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
 check(not scene.buttons.has("example") and not scene.buttons.has("gimmicks") and not scene.buttons.has("quit"), "Requested toolbar buttons removed")
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


