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
 while (not is_instance_valid(session.game) or not session.game.started) and Time.get_ticks_msec() < until:
  if session.state == "error": return false
  await process_frame
 return is_instance_valid(session.game) and session.game.started

func run() -> void:
 session = Session.new()
 session.settings_path = "user://prototype-regression.cfg"
 root.add_child(session)
 check(session.state == "menu" and session.overlay_root.visible, "Player starts at the menu")
 await capture("menu")
 session.selected_character = "tails"
 session.sound_enabled = false
 session.practice_mode = false
 await session.start_run()
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
 game.toggle_pause()
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
 var choices := ["ring_scout", "ring_scout", "bumper_coach", "bumper_coach", "feature_fox"]
 for index in Session.Run.RunPlan.ACT_COUNT:
  var until := Time.get_ticks_msec() + 180000
  while resident_at(index) == null and Time.get_ticks_msec() < until: await process_frame
  check(game.active_sequence == index and game.act_score == 0 and not game.exit_unlocked, "Act %d starts a fresh local target" % (index + 1))
  check(game.active.plan.zone == index / 3 and game.active.plan.theme == Session.Run.RunPlan.THEMES[index / 3], "Act %d uses its planned Zone and theme" % (index + 1))
  check(game._score_exit != null and not game._score_exit.unlocked and game.active.document.score_target == 0, "Run-owned target installs a physical gate without editing the source Act")
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
   var at: Vector2 = next.plan.offset + Vector2(next.document.spawn_position.x, next.document.activation_y)
   game._observe_authored_motion(at + Vector2.DOWN * 2, at - Vector2.DOWN * 2)
   check(game.active_sequence == index, "Next Act cannot activate below the current target")
  var target: int = game.act_score_target
  game.active.runtime.mechanics.mechanic_score.emit(&"wall_switch", "integration_award", target)
  total += target
  check(game.score == total and game.act_score == target and game.exit_unlocked, "Act %d threshold uses local points and preserves cumulative score" % (index + 1))
  var position: Vector2 = game.ball.position
  await frames(2)
  check(game.ball.position == position and not game.finished, "Unlocking never teleports or completes a run")
  if index == 0:
   game.reset_ball(false)
   await frames()
   check(game.score == total and game.act_score == target and game.exit_unlocked, "Checkpoint retry keeps legitimately earned points and open exit")
   game.ball.serve_pending = false
   game.ball._teleport_pending = false
  if index < Session.Run.RunPlan.ACT_COUNT - 1:
   var at: Vector2 = next.plan.offset + Vector2(next.document.spawn_position.x, next.document.activation_y)
   game._observe_authored_motion(at + Vector2.DOWN * 2, at - Vector2.DOWN * 2)
   check(game.drafting and session.state == "draft" and paused and game.active_sequence == index, "Physical Act clear pauses for a mandatory Buddy choice")
   check(not game.buddies.offers().is_empty() and not game.choose_buddy("unknown"), "Draft offers available upgrades and rejects an invalid ID")
   var before_draft: int = game.score
   game.active.runtime.mechanics.complete_feature(&"switch_bank", "during_draft", 100)
   game.toggle_pause()
   check(paused and game.score == before_draft, "Draft cannot be skipped with pause or score while awaiting a choice")
   await capture("draft")
   var before_choice: Vector2 = game.ball.position
   var velocity_before_choice: Vector2 = game.ball.linear_velocity
   var chosen: String = choices[index]
   var previous_level: int = game.buddies.levels.get(chosen, 0)
   session._choose_buddy(chosen)
   check(not paused and game.active_sequence == index + 1 and game.balls_remaining == 3 and game.ball.position == before_choice and game.ball.linear_velocity == velocity_before_choice, "Buddy choice starts a fresh three-ball Act without changing position or velocity")
   check(game.buddies.levels[chosen] == previous_level + 1 and not game.choose_buddy("bumper_coach"), "Buddy choice upgrades once and cannot be submitted twice")
   if index == 2:
    check(not game.finished and game.active.plan.zone == 1 and game.active_sequence == 3 and game.buddies.levels.ring_scout == 2, "The Zone boundary preserves the build and continues into Chemical Plant")
   # Move the frozen integration fixture to the new Act for camera/retirement checks.
   game.ball.position = game.active.spawn()
   if index == 2: await capture("zone-two")
  else:
   var at: Vector2 = game.active.plan.offset + Vector2((game.active.document.exit_start_x + game.active.document.exit_width * 0.5) * game.active.document.cell_size, 0)
   game._observe_authored_motion(at + Vector2.DOWN * 2, at - Vector2.DOWN * 2)
   game._observe_authored_motion(at + Vector2.DOWN * 2, at - Vector2.DOWN * 2)
 check(game.finished and session.state == "results" and session.last_summary.acts.size() == 6, "Only the sixth physical exit produces the completed two-Zone result")
 await capture("results")
 check(session.last_summary.score == 13500 and game.results.size() == 6, "Results preserve all six separate Act awards exactly once")
 check(game.pending.is_empty() and not game.loading_boundary, "Final exit does not wait for an imaginary seventh Act")
 if "--no-bakes" not in OS.get_cmdline_user_args():
  check(game.library.fallback_builds == 0 and game.library.visual_bake_hits == 6 and game.library.theme_bake_hits == 2, "Both Zones use six disk Act variants and two baked themes without runtime construction")
 game.active.runtime.mechanics.mechanic_score.emit(&"spinner_tick", "late", 5)
 check(game.score == total, "Completed run rejects late mechanic rewards")
 await session.return_to_menu()
 check(session.state == "menu" and session.game == null and not paused, "Return to menu closes the run and restores menu input")
 var settings := ConfigFile.new()
 check(settings.load(session.settings_path) == OK and int(settings.get_value(Session.CHALLENGE_RECORDS, "score", 0)) >= 13500, "Completed two-Zone Challenge personal best is saved separately")
 await session.start_run()
 check(await await_run(), "Replay starts another real run")
 check(session.game.score == 0 and session.game.act_score == 0 and session.game.active_sequence == 0 and not session.game.exit_unlocked, "Replay clears progress and locks the first exit again")
 check(session.game.buddies.levels.is_empty() and session.game.scorecraft.award_bonuses.is_empty(), "Replay clears Buddy levels, bonuses and contribution ledgers")
 session.game.toggle_pause()
 await frames()
 await session.start_run()
 check(await await_run(), "Restart from pause finishes cleanup and starts a fresh run")
 check(not paused and session.game.score == 0, "Restart releases pause and clears score")
 await session.return_to_menu()
 await session.start_run()
 await session.return_to_menu()
 check(session.state == "menu" and session.game == null, "Menu return safely cancels an unfinished startup")
 await session.return_to_menu()
 session.free()
 print("RESULT | Prototype run | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
