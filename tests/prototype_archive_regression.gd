extends SceneTree
const Session = preload("res://scripts/prototype/session.gd")
const Archive = preload("res://scripts/prototype/telemetry_archive.gd")
var session: Control
var checks := 0
var failures := 0
var directory := "user://telemetry/runs/_validation/archive-%d" % Time.get_ticks_usec()

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func files() -> Array:
 var result: Array = []
 for file: String in DirAccess.get_files_at(directory):
  if file.ends_with(".json"): result.append(directory.path_join(file))
 return result

func saved() -> Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string(session.archive_result.path))

func start(practice := false) -> void:
 while is_instance_valid(session.setup_menu) and session.setup_menu.checking: await process_frame
 session.practice_mode = practice
 session.run_configuration.zone_count = 1
 session.run_configuration.selected_theme_ids = ["green_hill"]
 session.run_configuration.selected_act_paths = session.available_act_paths.slice(0, 3)
 await session.start_run()
 var deadline := Time.get_ticks_msec() + 180000
 while not session.game.started and session.state != "error" and Time.get_ticks_msec() < deadline: await process_frame
 check(session.game.started, "Real archived run starts")
 session.game.set_physics_process(false)
 session.game.ring_field.set_physics_process(false)
 session.game.ball.freeze = true
 session.game.ball.serve_pending = false
 session.game.auto_launch_time = -1.0

func win() -> void:
 var game: Node = session.game
 for index in 3:
  game.ball.freeze = true
  game.ball.serve_pending = false
  game.auto_launch_time = -1.0
  game.ball.position = game.active.spawn()
  game.active.runtime.mechanics.mechanic_score.emit(&"wall_switch", "archive_fixture", game.act_score_target)
  var deadline := Time.get_ticks_msec() + 180000
  while game._has_next_act() and not game._next_ready() and Time.get_ticks_msec() < deadline: await process_frame
  var goal: Vector2 = game.active.runtime.goal_ring.center
  game._observe_authored_motion(goal, goal)
  if index < 2:
   game.choose_buddy(game.buddies.offers()[0].id)
   while is_instance_valid(game.transfer): await process_frame

func run() -> void:
 print("TELEMETRY_DIRECTORY | ", ProjectSettings.globalize_path(Archive.DIRECTORY))
 session = Session.new()
 session.settings_path = "user://archive-regression-%d.cfg" % Time.get_ticks_usec()
 session.archive_directory = directory
 root.add_child(session)
 await start()
 await win()
 check(files().size() == 1 and saved().won and saved().completed and saved().termination_reason == "completed", "Challenge win archives exactly one JSON")
 check(session.run_feel.text.is_empty() and saved().run_feel.is_empty(), "Run feel starts empty")
 check(saved().run_configuration.zone_count == 1 and saved().course.size() == 3 and saved().acts.size() == 3 and saved().course[2].target == 2000, "Saved configuration and full generated course match play")
 var first_path: String = session.archive_result.path
 session.run_feel.text = "Fast and fun, but the last ramp felt frustrating.\nTry gentler pacing."
 session.run_feel.text_changed.emit()
 await create_timer(0.9, true).timeout
 check(files().size() == 1 and saved().run_feel == session.run_feel.text, "Run feel autosaves into the same file")
 if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/archive-run-feel.png")
 session._copy_run_data()
 check(FileAccess.get_file_as_string(first_path) == session.run_data_json(), "Saved and copied JSON are byte-for-byte identical")
 if DisplayServer.get_name() != "headless":
  await process_frame
  check(DisplayServer.clipboard_get().replace("\r\n", "\n") == session.run_data_json(), "Copy still writes the OS clipboard")
 var same_json: String = session.run_data_json()
 var collision := Archive.save(same_json, session.last_export, directory)
 check(collision.error.is_empty() and collision.path != first_path and FileAccess.get_file_as_string(first_path) == same_json, "Identical timestamps and metadata get a suffix without overwriting")
 var external := Archive.update_notes(collision.path, "unexpected contents", same_json)
 check(not external.error.is_empty() and FileAccess.get_file_as_string(collision.path) == same_json, "Note updates refuse to overwrite an externally changed archive")
 DirAccess.remove_absolute(collision.path)
 session._on_completed(session.last_summary)
 await session.return_to_menu()
 check(files().size() == 1 and session.state == "menu", "Redisplaying Results, Copy and Return to menu do not duplicate the archive")
 await start()
 session.game.balls_remaining = 1
 session.game._on_ball_drained()
 check(files().size() == 2 and not saved().won and saved().termination_reason == "out_of_balls", "Challenge loss archives exactly one JSON")
 session.run_feel.text = "Could not recover after the left flipper."
 session.run_feel.text_changed.emit()
 await session.return_to_menu()
 check(JSON.parse_string(FileAccess.get_file_as_string(session.archive_result.path)).run_feel == "Could not recover after the left flipper.", "Leaving Results flushes notes without waiting for debounce")
 await start(true)
 await win()
 check(files().size() == 3 and saved().mode == "practice" and saved().won, "Practice completion archives one JSON")
 await session.return_to_menu()
 await start()
 session.game.active.runtime.mechanics.mechanic_score.emit(&"wall_switch", "partial", 75)
 await session.return_to_menu()
 check(files().size() == 4 and session.state == "results" and not saved().won and not saved().completed and saved().termination_reason == "returned_to_menu" and saved().acts.size() == 1 and not saved().acts[0].cleared, "Abandonment preserves the partial Act and opens distinct Results")
 session.run_feel.text = "Abandoned because I got stuck."
 session.run_feel.text_changed.emit()
 var abandoned_path: String = session.archive_result.path
 await start()
 check(JSON.parse_string(FileAccess.get_file_as_string(abandoned_path)).run_feel == "Abandoned because I got stuck.", "Replay flushes abandoned-run feedback")
 await session.start_run()
 check(files().size() == 5, "Explicit Restart archives the prior run once")
 var restarted := false
 for path: String in files(): restarted = restarted or JSON.parse_string(FileAccess.get_file_as_string(path)).termination_reason == "restarted"
 check(restarted, "Restart is distinct from an ordinary loss")
 # Cancel the new loading run as well; an unstarted attempt is labeled explicitly.
 await session.return_to_menu()
 check(not saved().started and saved().acts.is_empty(), "Abandoning startup produces an honest empty partial snapshot")
 await session.return_to_menu()
 await start()
 var blocker := directory.path_join("not-a-directory")
 FileAccess.open(blocker, FileAccess.WRITE).store_string("fixture")
 session.archive_directory = blocker.path_join("runs")
 session.game.balls_remaining = 1
 session.game._on_ball_drained()
 check(session.state == "results" and session.game.finished and not session.archive_result.error.is_empty(), "Write failure preserves Results and game completion")
 session.run_feel.text = "Disk unavailable; retain these notes in Copy."
 session.run_feel.text_changed.emit()
 check(JSON.parse_string(session.run_data_json()).run_feel == session.run_feel.text, "Clipboard JSON remains available after archive failure")
 session.archive_directory = directory
 await session.return_to_menu()
 DirAccess.remove_absolute(blocker)
 await start()
 await session._quit()
 check(saved().termination_reason == "quit" and not saved().completed, "Explicit Quit archives the active partial run")
 for path: String in files():
  check(JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary, "Archived JSON parses: " + path.get_file())
  DirAccess.remove_absolute(path)
 DirAccess.remove_absolute(directory)
 DirAccess.remove_absolute(session.settings_path)
 print("RESULT | Prototype archive | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
