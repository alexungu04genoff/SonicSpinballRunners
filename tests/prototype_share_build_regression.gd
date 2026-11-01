extends SceneTree
## Run with --main-pack <exported executable> and an isolated APPDATA directory.
const Session = preload("res://scripts/prototype/session.gd")
const THEMES := ["casino_night", "chemical_plant", "green_hill", "rooftop_run"]
var checks := 0
var failures := 0
var session: Control

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("user://" + label + ".png")

func run() -> void:
 check(ProjectSettings.get_setting("application/config/name") == "Sonic Spinball Runners ABro", "ABro package has its own preferences directory")
 check(FileAccess.file_exists(Session.EXPORT_DEFAULTS_PATH), "Default settings are embedded in the package")
 session = Session.new()
 session.settings_path = "user://share-build-verification.cfg"
 session.archive_directory = "user://telemetry/verification"
 DirAccess.remove_absolute(session.settings_path)
 root.add_child(session)
 check(session.selected_character == "sonic" and session.practice_mode and not session.sound_enabled, "Fresh package starts with Sonic, Practice and scoring sounds off")
 check(session.run_configuration.zone_count == 3 and session.run_configuration.snapshot().selected_themes == THEMES, "Three Zones use exactly the requested four-theme pool")
 check(session.available_act_paths.size() >= 3 and session.run_configuration.selected_act_paths == session.available_act_paths, "All %d production Acts are packaged and selected" % session.available_act_paths.size())
 var deadline := Time.get_ticks_msec() + 180000
 while session.setup_menu.checking and Time.get_ticks_msec() < deadline: await process_frame
 check(not session.setup_menu.checking and not session.start_button.disabled, "Packaged menu validates every selected Act/theme bake")
 await capture("abro-menu")
 if session.start_button.disabled:
  session.free()
  quit(1)
  return
 session.start_button.pressed.emit()
 deadline = Time.get_ticks_msec() + 240000
 while (session.transitioning or not is_instance_valid(session.game) or not session.game.started) and Time.get_ticks_msec() < deadline and session.state != "error": await process_frame
 var started: bool = is_instance_valid(session.game) and session.game.started
 check(started, "Exported executable starts the real baked Prototype")
 if not started:
  print("STARTUP_ERROR | ", session.state)
  quit(1)
  return
 var game: Node = session.game
 check(game.character_id == "sonic" and game.practice_mode and game.run_plan.size() == 9, "Running game applies Sonic, unlimited retries and nine Acts")
 var muted := false
 for child: Node in game.get_children():
  if child.get_script() == Session.Sounds: muted = not child.enabled
 check(muted, "Runtime scoring audio is disabled")
 var seen_themes: Array = []
 var seen_sources: Array = []
 for entry: Dictionary in game.run_plan:
  if entry.theme not in seen_themes: seen_themes.append(entry.theme)
  var path: String = game.effective_configuration().selected_act_paths[entry.id]
  if path not in seen_sources: seen_sources.append(path)
 check(seen_themes.size() == 3 and seen_themes.all(func(theme: String): return theme in THEMES) and seen_sources.size() == mini(9, session.available_act_paths.size()), "Nine-Act course balances the Act pool across three distinct allowed themes")
 await capture("abro-playing")
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 for sequence in 9:
  game.ball.freeze = true
  game.ball.serve_pending = false
  game.ball._teleport_pending = false
  game.auto_launch_time = -1.0
  game.ball.position = game.active.spawn()
  game.active.runtime.mechanics.mechanic_score.emit(&"wall_switch", "share_build_award", game.act_score_target)
  deadline = Time.get_ticks_msec() + 180000
  while game._has_next_act() and not game._next_ready() and Time.get_ticks_msec() < deadline: await process_frame
  check(game.active_sequence == sequence and game.act_score >= game.act_score_target, "Packaged Act %d reaches its target" % (sequence + 1))
  var goal: Vector2 = game.active.runtime.goal_ring.center
  game._observe_authored_motion(goal, goal)
  if sequence < 8:
   check(game.drafting and not game.finished, "Act %d opens its Buddy draft" % (sequence + 1))
   if not game.drafting: break
   var offers: Array = game.buddies.offers()
   if offers.is_empty():
    session._choose_buddy("")
   else:
    var choice: Button = session.overlay_root.find_child("Buddy_" + str(offers[0].id), true, false)
    if choice != null: choice.pressed.emit()
   check(not game.drafting and session.state == "playing", "Buddy button advances the packaged course")
   deadline = Time.get_ticks_msec() + 180000
   while is_instance_valid(game.transfer) and Time.get_ticks_msec() < deadline: await process_frame
   if is_instance_valid(game.transfer):
    check(false, "Spawn transfer completes")
    break
 check(game.finished and session.last_summary.get("won", false) and session.last_summary.get("acts", []).size() == 9, "All three Zones complete successfully")
 check(game.library.fallback_builds == 0, "Packaged run never rebuilds geometry at runtime")
 await capture("abro-results")
 await game.prepare_to_close()
 session.free()
 paused = false
 print("RESULT | Share build | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
