extends SceneTree
const Session = preload("res://scripts/prototype/session.gd")
var session: Control
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func frames(count := 3) -> void:
 for i in count: await process_frame

func press(label: String) -> void:
 var button: Button
 for candidate: Node in session.overlay_root.find_children("*", "Button", true, false):
  if candidate.text.begins_with(label) or candidate.tooltip_text.begins_with(label): button = candidate; break
 check(button != null, "Visible action exists: " + label)
 if button == null: return
 var old_panel: Control = session.overlay_root
 button.pressed.emit()
 check(is_instance_valid(button), "Action emitter survives signal dispatch: " + label)
 if old_panel != session.overlay_root:
  check(is_instance_valid(old_panel) and old_panel.is_queued_for_deletion() and not old_panel.visible, "Replaced panel is hidden and retired after signal dispatch")

func await_transition() -> void:
 var until := Time.get_ticks_msec() + 180000
 while session.transitioning and Time.get_ticks_msec() < until: await process_frame
 check(not session.transitioning, "Button transition completes")

func resident_at(sequence: int) -> RefCounted:
 for act: RefCounted in session.game.resident:
  if act.plan.sequence == sequence: return act
 return null

func capture(label: String) -> void:
 if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
 await frames(5)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/prototype-" + label + ".png")

func await_run() -> bool:
 var until := Time.get_ticks_msec() + 180000
 while (session.transitioning or not is_instance_valid(session.game) or not session.game.started) and Time.get_ticks_msec() < until:
  if session.state == "error": return false
  await process_frame
 return is_instance_valid(session.game) and session.game.started

func run() -> void:
 session = Session.new()
 session.settings_path = "user://prototype-regression.cfg"
 session.archive_directory = "user://telemetry/runs/_validation/prototype_run_regression"
 root.add_child(session)
 check(session.state == "menu" and session.overlay_root.visible, "Player starts at the menu")
 await capture("menu")
 session.selected_character = "tails"
 session.sound_enabled = false
 session.practice_mode = false
 while session.setup_menu.checking: await process_frame
 press("Start run")
 check(await await_run(), "Menu starts the real streamed six-Act run")
 if not session.game.started:
  await session.return_to_menu()
  quit(1)
  return
 var game: Node = session.game
 check(game.character_id == "tails" and game.act_score_target == 1000 and not game.exit_unlocked, "Character choice and first Act gate apply at startup")
 await capture("playing")
 game.toggle_pause()
 await frames()
 check(session.state == "paused" and paused, "Pause opens player session controls")
 await capture("pause")
 press("Resume")
 await frames()
 check(session.state == "playing" and not paused, "Resume restores the same run")
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.set_physics_process(false)
 # This fixture controls awards explicitly. Tails can otherwise collect a nearby
 # rack ring while the deliberately frozen ball waits through rendered frames.
 game.ring_field.set_physics_process(false)
 var total := 0
 for index in Session.Run.RunPlan.ACT_COUNT:
  var until := Time.get_ticks_msec() + 180000
  while resident_at(index) == null and Time.get_ticks_msec() < until: await process_frame
  check(game.active_sequence == index and game.act_score == 0 and not game.exit_unlocked, "Act %d starts a fresh local target" % (index + 1))
  check(game.active.plan.zone == index / 3 and game.active.plan.theme == game.run_plan[index].theme, "Act %d uses its planned Zone and theme" % (index + 1))
  check(game.active.runtime.has("goal_ring") and not game.active.runtime.goal_ring.unlocked and game.active.document.score_target == 0, "Run-owned target locks the mandatory goal without editing the source Act")
  check(game.active.runtime.root.find_children("ActScoreExit", "", true, false).is_empty(), "Prototype connector has no blocking score wall")
  var warning: Node3D = game.active.runtime.exit_warning
  check(warning.visible == (index > 0) and warning.find_children("*", "CollisionObject2D", true, false).is_empty(), "Cleared seam warning appears only after advancement and has no collisions")
  check(warning.position.z > TablePresentation.map_point(game.active.plan.offset + game.active.document.terrain_bounds().end).z, "Warning sits below the cleared connector, outside the new Act")
  if index == 1 and "--capture-seam" in OS.get_cmdline_user_args():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/cleared-seam.png")
  var next: RefCounted = resident_at(index + 1)
  if index < Session.Run.RunPlan.ACT_COUNT - 1:
   until = Time.get_ticks_msec() + 180000
   while (next == null or not game._zone_ready(next.plan.zone)) and Time.get_ticks_msec() < until:
    await process_frame
    next = resident_at(index + 1)
   if next == null:
    check(false, "Next Act becomes ready before the deadline")
    await session.return_to_menu()
    quit(1)
    return
   var at: Vector2 = game.active.runtime.goal_ring.center
   game._observe_authored_motion(at + Vector2.DOWN * 2, at - Vector2.DOWN * 2)
   check(game.active_sequence == index, "Next Act cannot activate below the current target")
  await sample_play_time()
  var target: int = game.act_score_target
  game.active.runtime.mechanics.mechanic_score.emit(&"wall_switch", "integration_award", target)
  if not game.scorecraft.last_award.has("total"):
   check(false, "Controlled integration award reaches Scorecraft after transfer")
   await session.return_to_menu()
   session.free()
   quit(1)
   return
  total += int(game.scorecraft.last_award.total)
  check(game.score == total and game.act_score >= target and game.exit_unlocked, "Act %d threshold uses local points and preserves cumulative score" % (index + 1))
  await sample_play_time()
  var position: Vector2 = game.ball.position
  await frames(2)
  check(game.ball.position == position and not game.finished, "Unlocking never teleports or completes a run")
  if index == 0:
   game.reset_ball(false)
   await frames()
   check(game.score == total and game.act_score >= target and game.exit_unlocked, "Checkpoint retry keeps legitimately earned points and open exit")
   game.ball.serve_pending = false
   game.ball._teleport_pending = false
  if index < Session.Run.RunPlan.ACT_COUNT - 1:
   var at: Vector2 = game.active.runtime.goal_ring.center
   game.ball.position = at - Vector2.DOWN * 2
   game._observe_authored_motion(at + Vector2.DOWN * 2, at - Vector2.DOWN * 2)
   check(game.drafting and session.state == "draft" and paused and game.active_sequence == index, "Physical Act clear pauses for a mandatory Buddy choice")
   check(not game.buddies.offers().is_empty() and not game.choose_buddy("unknown"), "Draft offers available upgrades and rejects an invalid ID")
   var before_draft: int = game.score
   game.active.runtime.mechanics.complete_feature(&"switch_bank", "during_draft", 100)
   game.toggle_pause()
   check(paused and game.score == before_draft, "Draft cannot be skipped with pause or score while awaiting a choice")
   await capture("draft")
   var chosen: String = game.buddies.offers()[0].id
   var previous_level: int = game.buddies.levels.get(chosen, 0)
   press(str(Session.Run.Buddies.CATALOG[chosen].name))
   check(not paused and game.active_sequence == index + 1 and game.balls_remaining == game.starting_balls and is_instance_valid(game.transfer) and game.ball.freeze and game.ball.linear_velocity == Vector2.ZERO, "Buddy choice starts a protected transfer with a fresh Buddy-adjusted budget")
   if index == 0 and "--capture" in OS.get_cmdline_user_args():
    while is_instance_valid(game.transfer) and game.transfer.elapsed < 0.55: await process_frame
    await capture("act-transfer")
   var transfer_started := Time.get_ticks_msec()
   var transfer_deadline := transfer_started + 180000
   var active_seconds := 0.0
   # Transfer advances on process delta, which Godot clamps during shader stalls.
   # Check its simulation-time allowance separately from the loading watchdog.
   var transfer_budget: float = Session.Run.SpawnTransfer.DURATION + 1.0
   while is_instance_valid(game.transfer) and active_seconds < transfer_budget and Time.get_ticks_msec() < transfer_deadline:
    await process_frame
    if not paused: active_seconds += root.get_process_delta_time()
   var arrived: bool = not is_instance_valid(game.transfer) and game.ball.position.distance_to(game.active.spawn()) < 1.0 and not game.controls.input_blocked
   if not arrived:
    print("PROTOTYPE_TRANSFER_FAILED | ", JSON.stringify({"act": index + 2, "wall_ms": Time.get_ticks_msec() - transfer_started,
     "active_seconds": active_seconds, "transfer_elapsed": game.transfer.elapsed if is_instance_valid(game.transfer) else -1.0,
     "paused": paused, "loading_boundary": game.loading_boundary, "library_stage": game.library.profile_stage,
     "library_error": game.library.error, "spawn_distance": game.ball.position.distance_to(game.active.spawn()), "controls_blocked": game.controls.input_blocked}))
   check(arrived, "Act transfer arrives at the authored spawn and releases controls")
   if not arrived:
    await session.return_to_menu()
    session.free()
    quit(1)
    return
   game.ball.freeze = true
   game.ball.serve_pending = false
   game.ball._teleport_pending = false
   check(game.buddies.levels[chosen] == previous_level + 1 and not game.choose_buddy(chosen), "Buddy choice upgrades once and cannot be submitted twice")
   if index == 2:
    check(not game.finished and game.active.plan.zone == 1 and game.active_sequence == 3 and not game.buddies.levels.is_empty(), "The Zone boundary preserves the build and continues into Chemical Plant")
   # Move the frozen integration fixture to the new Act for camera/retirement checks.
   game.ball.position = game.active.spawn()
   if index == 2: await capture("zone-two")
  else:
   var at: Vector2 = game.active.runtime.goal_ring.center
   game._observe_authored_motion(at + Vector2.DOWN * 2, at - Vector2.DOWN * 2)
   game._observe_authored_motion(at + Vector2.DOWN * 2, at - Vector2.DOWN * 2)
 check(game.finished and session.state == "results" and session.last_summary.acts.size() == 6, "Only the sixth physical exit produces the completed two-Zone result")
 await capture("results")
 var copied: String = session.run_data_json()
 var data = JSON.parse_string(copied)
 check(data is Dictionary and data.won and data.acts.size() == 6 and data.total_score == session.last_summary.score, "Successful run exports all six Acts as plain JSON")
 check(data.run_configuration == JSON.parse_string(JSON.stringify(game.effective_configuration().snapshot())) and data.configuration_fingerprint == game.effective_configuration().fingerprint() and data.course == JSON.parse_string(JSON.stringify(game.course_snapshot())), "Copied JSON includes effective configuration, fingerprint and full course")
 var identities_match := true
 for i in data.acts.size():
  identities_match = identities_match and data.acts[i].theme == data.course[i].theme and data.acts[i].source == data.course[i].source and data.acts[i].target == data.course[i].target
 check(identities_match, "Each telemetry Act retains actual theme, source and target")
 press("Copy run data")
 check(session.copy_status.visible and session.copy_status.text == "Run data copied", "Copy action confirms telemetry export")
 if DisplayServer.get_name() != "headless":
  check(DisplayServer.clipboard_get().replace("\r\n", "\n") == copied, "OS clipboard contains the exact pretty-printed run JSON")
 if "--telemetry-sample" in OS.get_cmdline_user_args():
  FileAccess.open("res://test-results/run-telemetry-success.json", FileAccess.WRITE).store_string(DisplayServer.clipboard_get())
 check(session.last_summary.score == total and session.last_summary.normal_score == 13500 and game.results.size() == 6, "Results preserve all six separate Act awards exactly once")
 check(game.pending.is_empty() and not game.loading_boundary, "Final exit does not wait for an imaginary seventh Act")
 if "--no-bakes" not in OS.get_cmdline_user_args():
  check(game.library.fallback_builds == 0 and game.library.visual_bake_hits == 6 and game.library.theme_bake_hits == 2, "Both Zones use six disk Act variants and two baked themes without runtime construction")
 game.active.runtime.mechanics.mechanic_score.emit(&"spinner_tick", "late", 5)
 check(game.score == total, "Completed run rejects late mechanic rewards")
 var settings := ConfigFile.new()
 check(settings.load(session.settings_path) == OK and int(settings.get_value(Session.CHALLENGE_RECORDS, "score", 0)) >= 13500, "Completed two-Zone Challenge personal best is saved separately")
 press("Play again")
 check(await await_run(), "Replay starts another real run")
 check(session.game.score == 0 and session.game.act_score == 0 and session.game.active_sequence == 0 and not session.game.exit_unlocked, "Replay clears progress and locks the first exit again")
 check(session.game.buddies.levels.is_empty() and session.game.scorecraft.award_bonuses.is_empty(), "Replay clears Buddy levels, bonuses and contribution ledgers")
 session.game.toggle_pause()
 await frames()
 press("Restart run")
 check(await await_run(), "Restart from pause finishes cleanup and starts a fresh run")
 check(not paused and session.game.score == 0, "Restart releases pause and clears score")
 session.game.toggle_pause()
 await frames()
 press("Return to menu")
 await await_transition()
 check(session.state == "results" and session.game == null and not paused, "Abandoning closes the run and opens partial Results")
 press("Return to menu")
 await await_transition()
 check(session.state == "menu", "Leaving abandoned Results restores the menu")
 while session.setup_menu.checking: await process_frame
 press("Start run")
 await session.return_to_menu()
 check(session.state == "results" and session.game == null, "Abandoning safely cancels an unfinished startup")
 await session.return_to_menu()
 session.free()
 print("RESULT | Prototype run | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func sample_play_time() -> void:
 if "--telemetry-sample" not in OS.get_cmdline_user_args(): return
 var game: Node = session.game
 game.auto_launch_time = -1.0
 game.ball.position = game.active.runtime.goal_ring.center + Vector2(0, -100)
 game.previous_goal_position = game.ball.position
 game._goal_motion_ready = false
 game.set_physics_process(true)
 await create_timer(0.35).timeout
 game.set_physics_process(false)
