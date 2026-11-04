extends SceneTree
## Exercise the editor's --act launch through the real Prototype session.
## Run with: -- --act res://data/acts/Experiments/Lockbox.tres
const Session = preload("res://scripts/prototype/session.gd")
var checks := 0
var failures := 0
var session: Control

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func wait_started() -> bool:
 var deadline := Time.get_ticks_msec() + 120000
 while Time.get_ticks_msec() < deadline:
  if is_instance_valid(session.game):
   if session.game.started: return true
   if not session.game.last_source_error.is_empty(): return false
  await process_frame
 return false

func run() -> void:
 if "--act" not in OS.get_cmdline_user_args():
  push_error("Pass -- --act res://data/acts/Experiments/Lockbox.tres")
  quit(1)
  return
 root.size = Vector2i(1280, 900)
 session = Session.new()
 session.settings_path = "user://act-test-regression-%d.cfg" % Time.get_ticks_usec()
 session.archive_directory = "user://act-test-regression-telemetry"
 root.add_child(session)
 var started := await wait_started()
 check(started, "Editor --act starts the saved Act in Prototype without pre-baking")
 if started:
  var game: Node = session.game
  game.set_physics_process(false)
  game.ball.freeze = true
  game.auto_launch_time = -1.0
  var goal: Node3D = game.active.runtime.goal_ring
  check(game.run_plan.size() == 1 and game.resident.size() == 1 and game.practice_mode, "One-Act Practice uses only the requested source")
  # Exercise a nondefault authored value without rewriting the experimental source.
  game.active.document.authored_difficulty = 4
  var partial: Dictionary = game._act_result(false).telemetry
  check(partial.authored_difficulty == game.active.document.authored_difficulty and partial.authored_difficulty_label == game.active.document.difficulty_label() and partial.act_fingerprint == game.active.document.fingerprint(), "Partial Act telemetry captures authored difficulty and exact document revision")
  check(goal.is_visible_in_tree() and goal.center == game.active.document.goal_center() and not goal.unlocked, "Authored Goal is rendered at its saved position and starts locked")
  game._observe_authored_motion(goal.center, goal.center)
  check(not game.finished, "Goal cannot complete before the Prototype score target")
  game.ball.serve_pending = false
  game.active.runtime.mechanics.mechanic_score.emit(&"wall_switch", "act_test_award", game.act_score_target)
  check(game.act_score_target == 1000 and goal.unlocked, "Prototype scoring unlocks the gold Goal at 1,000 points")
  if DisplayServer.get_name() != "headless":
   game.ball.position = goal.center + Vector2(0, 60)
   game.presentation.reset_camera(game.ball.position)
   for frame in 30: await process_frame
   await RenderingServer.frame_post_draw
   DirAccess.make_dir_recursive_absolute("res://test-results")
   root.get_texture().get_image().save_png("res://test-results/prototype-act-goal.png")
  game._observe_authored_motion(goal.center - Vector2(40, 0), goal.center + Vector2(40, 0))
  check(game.finished and session.state == "results" and session.last_summary.won and session.last_summary.acts.size() == 1, "Goal contact completes the Act through the Prototype results screen")
  var exported: Dictionary = preload("res://scripts/prototype/run_telemetry.gd").export_run(session.last_summary)
  var copied: Dictionary = JSON.parse_string(JSON.stringify(exported))
  check(copied.telemetry_format_version == 3 and copied.acts[0].authored_difficulty == partial.authored_difficulty and copied.acts[0].act_fingerprint == partial.act_fingerprint, "Completed Act exports difficulty and fingerprint in telemetry v3")
  var archived: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(session.archive_result.path))
  check(archived.telemetry_format_version == 3 and archived.acts[0].authored_difficulty == 4 and archived.acts[0].authored_difficulty_label == "Hard", "Automatic local archive retains the nondefault authored rating")
  check(session.best_score == 0 and session.practice_best_score == 0 and not FileAccess.file_exists(session.settings_path), "Act tests do not overwrite normal run preferences or records")
  await session.start_run()
  started = await wait_started()
  check(started and session.game.act_score == 0 and not session.game.active.runtime.goal_ring.unlocked, "Restart reloads the saved Act with fresh score and Goal state")
  await session._close_run("test_finished")
  session._show_menu()
  check(session.start_button.text == "Play Act" and not is_instance_valid(session.setup_menu), "Act-test menu retains a single source with theme selection")
 else:
  await session._close_run("test_failed")
 session.free()
 paused = false
 print("RESULT | Prototype Act playtest | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
