extends "res://tests/score_attack_regression.gd"
## Presentation observes gravity release and checkpoint states without driving physics.

func run() -> void:
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.zone_enabled = true
 game.generation_seed = 18
 root.add_child(game)
 await frames(6)
 var view: TablePresentation = game.presentation
 check(view.serve_visuals.size() == 3, "Every Act has a transformed floor serve marker")
 var active: Dictionary = {}
 var waiting_hints := 0
 for marker: Dictionary in view.serve_visuals:
  if marker.hint.visible:
   waiting_hints += 1
   active = marker
 check(waiting_hints == 1 and active.serve.is_equal_approx(game.ball.serve_position) and active.hint.text.contains("ROLL IN"), "Only the current serve position shows the roll-in control hint")
 check(game.ball.serve_pending and game.ball.linear_velocity.is_zero_approx(), "Character waits motionless at the marked starting position")
 var cup_segments := 0
 for chunk: TableChunk in game.chunks:
  if not chunk.data.markers.has("serve"):
   continue
  var serve: Vector2 = chunk.data.world_point(chunk.data.markers.serve)
  var cup_area := Rect2(serve + Vector2(-50, -15), Vector2(100, 65))
  for item: Dictionary in chunk.descriptors:
   if item.kind == "rail" and cup_area.has_point(item.a) and cup_area.has_point(item.b):
    cup_segments += 1
 check(cup_segments == 0, "Serve markers add no physical cup or blocking rail beneath the character")
 var retracted := 0
 for checkpoint: Dictionary in view.checkpoint_visuals:
  if checkpoint.guide.visible and not checkpoint.visual.visible:
   retracted += 1
 check(retracted == view.checkpoint_visuals.size() and retracted > 0, "Future checkpoint funnels are visibly retracted to floor guides")
 var disabled_flippers := 0
 var disabled_visuals_match := true
 for index in game.flippers.size():
  if not game.flippers[index].enabled:
   disabled_flippers += 1
   disabled_visuals_match = disabled_visuals_match and not view.flipper_visuals[index].visible and view.flipper_retracted_visuals[index].visible
 check(disabled_flippers == 4 and disabled_visuals_match and view.flipper_visuals.size() == game.flippers.size(), "Both future recovery pairs remain floor guides with stable shared visual indexing")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/serve-ready.png")
 var impulses: Array[Vector2] = []
 game.ball.launched.connect(func(impulse: Vector2): impulses.append(impulse))
 game.launch_ball()
 paused = true
 await frames(4)
 check(game.ball.serve_pending and game.ball.release_pending and impulses.is_empty() and game.ball.linear_velocity.is_zero_approx(), "Pause retains the queued release without moving or applying an impulse")
 paused = false
 await frames(3)
 view._process(0.0)
 check(not game.ball.serve_pending and not game.ball.release_pending and not active.hint.visible, "Roll-in input releases normal physics and removes the waiting hint")
 check(impulses == [Vector2.ZERO] and game.ball.linear_velocity.length() < 60.0, "Release event reports zero impulse and does not snap to a launch velocity")
 var previous: Vector2 = game.ball.position
 var continuous := true
 for tick in 24:
  await frames(1)
  continuous = continuous and game.ball.position.distance_to(previous) < 10.0 and not game.ball._teleport_pending
  previous = game.ball.position
 check(continuous and game.ball.position.y > game.ball.serve_position.y + 5.0 and game.ball.linear_velocity.y > 0.0, "Gravity rolls the character downward continuously from the starting position")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/serve-release.png")
 paused = true
 var paused_position: Vector2 = game.ball.position
 await frames(4)
 check(game.ball.position == paused_position, "Pause freezes the released ball normally")
 paused = false
 game.reset_ball(false)
 await frames(4)
 check(game.ball.serve_pending and active.hint.visible and game.ball.position.is_equal_approx(game.ball.serve_position) and not game.ball.release_pending, "Reset restores the marked waiting position without stale release state")
 print("RESULT | Gravity serve presentation | %d checks | %d failures" % [checks, failures])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
