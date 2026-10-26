extends SceneTree
## Rendered scene-rebuild smoke test. Run with --rendering-driver opengl3_angle
## or opengl3; this targets driver/resource lifetime, not physics traversal.
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL | " + label)
 else:
  print("PASS | " + label)

func rebuild(path: String, label: String) -> void:
 paused = true
 check(game.request_authored_act(path), "Request " + label)
 await frames(8)
 check(not game.loading_act and game.authored_act_path == path, "Rebuild " + label)
 paused = false
 game.launch_ball()
 await frames(180)
 check(game.ball.position.is_finite() and game.presentation.table_bounds == game.playfield.bounds, "Render and simulate " + label)

func run() -> void:
 print("RENDER_DRIVER | ", RenderingServer.get_current_rendering_driver_name())
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()

 root.add_child(game)
 await frames(30)
 game.launch_ball()
 await frames(180)
 check(game.playfield.source == "authored", "Initial Act renders and launches")
 await rebuild("res://data/endless/third_complex.tres", "Second Simple to Third Complex")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  var filename := "res://test-results/render-transition-%s.png" % RenderingServer.get_current_rendering_driver_name()
  check(root.get_texture().get_image().save_png(filename) == OK, "Capture rendered Act")
 await rebuild("res://data/endless/third_complex.tres", "Third Complex replay")
 await rebuild("res://data/endless/first_try_smooth_decor.tres", "First Try Smooth Decor")
 await rebuild("res://data/endless/second_simple.tres", "Return to Second Simple")
 paused = false
 game.free()
 await frames(4)
 print("RESULT | Render transitions | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
