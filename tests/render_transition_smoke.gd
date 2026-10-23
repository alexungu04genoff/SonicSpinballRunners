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

func rebuild(mode: int, label: String) -> void:
 paused = true
 game.debug_panel.challenge_panel.mode_selector.select(mode)
 check(game.debug_panel.challenge_panel.start_run(), "Request " + label)
 await frames(8)
 check(not game.generation_pending and game.chunks.size() == (9 if mode == 2 else 3), "Rebuild " + label)
 paused = false
 game.launch_ball()
 await frames(180)
 check(game.ball.position.is_finite() and game.presentation.table_bounds == game.layout.bounds, "Render and simulate " + label)

func run() -> void:
 print("RENDER_DRIVER | ", RenderingServer.get_current_rendering_driver_name())
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.generation_seed = 18
 root.add_child(game)
 await frames(30)
 game.launch_ball()
 await frames(180)
 check(game.chunks.size() == 3, "Initial Free Play renders and launches")
 await rebuild(2, "Free Play to Zone")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  var filename := "res://test-results/render-transition-%s.png" % RenderingServer.get_current_rendering_driver_name()
  check(root.get_texture().get_image().save_png(filename) == OK, "Capture rendered Zone")
 await rebuild(2, "Zone replay")
 await rebuild(1, "Zone to Score Attack")
 await rebuild(0, "Score Attack to Free Play")
 paused = false
 game.free()
 await frames(4)
 print("RESULT | Render transitions | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
