extends SceneTree
## Render the actual authored player and its scoring hardware in three example Acts.
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count: await process_frame

func run() -> void:
 for name: String in ["classic_pinball", "switch_spinner", "speedway_lane"]:
  var game: Node = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
  game.authored_act_path = "res://data/acts/scoring/" + name + ".tres"
  root.add_child(game)
  await frames(12)
  if game.playfield == null or not is_instance_valid(game._score_exit):
   failures += 1
   game.free()
   continue
  paused = true
  game.presentation.set_camera_follow(false)
  game.presentation.reset_camera(game.ball.position)
  await frames(4)
  if not game.score_label_lab.text.contains("TOTAL") or game.exit_unlocked: failures += 1
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/scoring-" + name + ".png")
  # A theme rebuild must retain exactly one scoring overlay and its live state.
  var count: int = game.presentation.find_children("ActScoringFeedback", "", false, false).size()
  game.set_theme("casino_night")
  await frames(3)
  if count != 1 or game.presentation.find_children("ActScoringFeedback", "", false, false).size() != 1: failures += 1
  game.scorecraft.award_mechanic(&"switch_bank", "render_probe", game.act_score_target)
  await frames(3)
  if not game.exit_unlocked or game._score_exit.label.text != "EXIT OPEN": failures += 1
  game.free()
  paused = false
  await frames(3)
 print("RESULT | Scoring presentation | 3 real Acts | %d failures" % failures)
 quit(1 if failures else 0)
