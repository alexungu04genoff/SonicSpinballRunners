extends SceneTree
## Seeded Prototype run. Add --capture-dir=<directory> with --fixed-fps 30
## for native stills and a three-second sequence of live gameplay frames.
const Session = preload("res://scripts/prototype/session.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const ACTS := ["res://data/acts/Authored/First Try Smooth Decor.tres",
 "res://data/acts/Authored/Clover Scoop.tres", "res://data/acts/Authored/RampMania.tres"]
var session: Control
var game: Node
var card: Control
var output := ""
var serial := 0
var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func hit(points := 100) -> void:
 serial += 1
 game._on_mechanic_score(&"switch_bank", "review-bank-%d" % serial, points, game.active_scoring_id)

func five() -> void:
 game.scorecraft.reset("Review chain")
 for i in 5: hit()

func settle_ball() -> void:
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.auto_launch_time = -1.0
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)

func still(file: String) -> void:
 for frame in 3: await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output.path_join(file + ".png")) == OK, "Save " + file)

func review_key(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if not is_instance_valid(game) or paused or game.finished or game.closing or is_instance_valid(game.transfer): return
 var key: int = event.keycode
 if key not in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_8, KEY_0, KEY_9, KEY_F9]: return
 settle_ball()
 if key == KEY_F9:
  game.set_celebration_retro(card.get_parent() == game.hud)
 elif key == KEY_9:
  # Top up the real target and take the normal goal/draft transition.
  game._on_mechanic_score(&"switch", "review-target", game.act_score_target, game.active_scoring_id)
  var at: Vector2 = game.active.runtime.goal_ring.center
  game._observe_authored_motion(at, at)
 elif key >= KEY_1 and key <= KEY_4:
  game.specials.select_character(["sonic", "tails", "knuckles", "shadow"][key - KEY_1])
  five()
 else:
  var target := 10 if key == KEY_0 else key - KEY_0
  if game.scorecraft.builder_hits >= target: game.scorecraft.reset("Review chain")
  for i in range(game.scorecraft.builder_hits, target): hit()

func clip() -> void:
 var path := output.path_join("frames")
 DirAccess.make_dir_recursive_absolute(path)
 game.launch_ball()
 var travel := 0.0
 var live_frames := 0
 var previous: Vector2 = game.ball.position
 for frame in 90:
  await process_frame
  if frame == 17:
   game.scorecraft.reset("Review chain")
   for i in 4: hit()
  if frame == 22: hit()
  await RenderingServer.frame_post_draw
  if card.visible:
   live_frames += 1
   travel += previous.distance_to(game.ball.position)
  previous = game.ball.position
  var image := root.get_texture().get_image()
  check(image.save_jpg(path.path_join("%03d.jpg" % frame), 0.95) == OK, "Save movie frame")
 check(live_frames >= 24 and travel > game.ball.radius * 2, "Ball travels during the cut-in")
 print("COMBO_CLIP | visible frames=", live_frames, " | Ball distance=", travel)

func run() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
 if not output.is_empty() and DisplayServer.get_name() == "headless":
  push_error("Captures require a graphical display.")
  quit(1)
  return
 if DisplayServer.get_name() != "headless":
  root.size = Vector2i(1280, 900)
  Review.position_review_window(root)
  print("REVIEW_SCREEN | ", root.current_screen, " | origin=", DisplayServer.screen_get_position(root.current_screen))
 var local := "res://test-results/combo-celebration-review/%d" % OS.get_process_id()
 DirAccess.make_dir_recursive_absolute(local)
 var config := Session.Run.RunPlan.Configuration.new(ACTS)
 config.selected_theme_ids = ["green_hill"]
 config.zone_count = 1
 session = Session.new()
 session.settings_path = local.path_join("session.cfg")
 session.archive_directory = local.path_join("telemetry")
 session.run_configuration = config
 root.add_child(session)
 session.sound_enabled = false
 while session.setup_menu.checking: await process_frame
 if session.start_button.disabled:
  push_error(session.setup_menu.reason.text)
  await close()
  quit(1)
  return
 await session._start_configured_run(config, "sonic", true, 18)
 game = session.game
 var deadline := Time.get_ticks_msec() + 90000
 while is_instance_valid(game) and not game.started and session.state != "error" and Time.get_ticks_msec() < deadline:
  await process_frame
 if not is_instance_valid(game) or not game.started:
  push_error("Could not start the review. Bake the three Green Hill Act recipes first.")
  await close()
  quit(1)
  return
 card = game.combo_celebration
 check(game.library.fallback_builds == 0, "Review runs the disk-backed Prototype")
 if "--interactive" in OS.get_cmdline_user_args():
  settle_ball()
  root.title = "Combo review   |   1–4 Character   5 / 8 / 0 Hits   Enter Pause   9 Goal   F9 Retro"
  root.window_input.connect(review_key)
  return
 preload("res://tests/render_profile_support.gd").disable_native_input(session)
 game.controls.input_blocked = true
 if not output.is_empty():
  await clip()
  # A natural drain at the tail of the clip can already own the Ball.
  if is_instance_valid(game.transfer): game.transfer._process(game.transfer.DURATION)
  game.reset_ball()
  for frame in 3: await physics_frame
 settle_ball()
 # Lock the camera and shader clock only for matched stills and callback checks.
 Engine.time_scale = 0.0
 game.presentation.reset_camera(game.ball.position)
 var scoring: Scorecraft = game.scorecraft
 for id: String in ["sonic", "tails", "knuckles", "shadow"]:
  game.specials.select_character(id)
  check(not card.visible and card.milestone == 0, "Character selection clears the previous pose")
  for i in 4: hit()
  check(scoring.builder_hits == 4 and scoring.multiplier == 4 and not card.visible, "Four builders use ordinary HUD feedback")
  var before: int = game.score
  hit()
  check(scoring.multiplier == 4 and card.visible and card.character == id and card.milestone == 5 and card.points == game.score - before, "Fifth builder displays the selected pose and exact award")
  card._process(0.3)
  if not output.is_empty(): await still(id)
  if id == "sonic" and not output.is_empty():
   game.set_celebration_retro(true)
   await still("sonic-retro")
   game.set_celebration_retro(false)
 var age: float = card.age
 game._on_mechanic_score(&"switch_bank", "review-bank-%d" % serial, 100, game.active_scoring_id)
 scoring.award_ring("loose-ring")
 scoring.award_spinner(5)
 scoring.support_combo(&"spring", "review")
 scoring.builder_hit_resolved.emit(5, 999)
 check(scoring.builder_hits == 5 and card.age == age and card.points == 100, "Repeats, supports, ticks and ordinary Rings cannot advance or restart a card")
 for i in 2: hit()
 check(card.milestone == 5, "Six and seven preserve the displayed milestone")
 hit()
 check(card.milestone == 8 and card.age == age, "Eight upgrades the existing card in place")
 hit()
 hit(125)
 check(card.milestone == 10 and card.points == 125 and card.age == age, "Ten upgrades without extending the original deadline")
 card._process(card.DURATION - age + 0.001)
 scoring.builder_hit_resolved.emit(10, 125)
 check(not card.visible and not card.is_processing(), "Expired card sleeps and ignores a duplicate receipt")
 for i in 4: hit()
 check(not card.visible, "Hits eleven through fourteen keep the cut-in hidden")
 hit(0)
 check(card.milestone == 15 and card.visible and card.points == 0, "Fifteen can celebrate a zero-point builder without borrowing another award")
 game.toggle_pause()
 check(paused and not card.visible, "Pause dismisses an active pose")
 game.toggle_pause()
 check(not paused and not card.visible, "Resume cannot revive the pose")
 scoring.reset("Review chain")
 hit()
 for i in scoring.config.rings_per_link: scoring.award_ring("link-ring-%d" % i)
 check(scoring.builder_hits == 2, "One completed Ring Link counts as one builder")
 hit()
 hit()
 var bumper := Node2D.new()
 game.world.add_child(bumper)
 var bonuses := scoring.award_bonuses
 scoring.award_bonuses = {"review": {"kinds": ["bumper"], "percent": 0.25}}
 var ledger_before: int = game.score
 scoring.award_bumper(bumper)
 check(card.points == 500 and game.score - ledger_before == card.points, "Card receives the exact bumper award including the Buddy contribution")
 scoring.award_bumper(bumper)
 scoring.award_bonuses = bonuses
 bumper.free()
 scoring._physics_process(scoring.config.combo_window)
 check(scoring.multiplier == 3 and scoring.builder_hits == 5, "A repeat bumper and tier decay preserve hit count")
 scoring.award_homing(&"bumper", "review-finish", 100)
 check(scoring.builder_hits == 0 and not card.visible, "Target Dash cash-out ends the hit streak")
 five()
 game._on_retry_requested()
 check(is_instance_valid(game.transfer) and not card.visible and scoring.builder_hits == 0, "Retry clears the cut-in and hit count")
 game.transfer._process(game.transfer.DURATION)
 settle_ball()
 five()
 game._on_ball_drained()
 check(is_instance_valid(game.transfer) and not card.visible, "Drain clears the cut-in")
 game.transfer._process(game.transfer.DURATION)
 settle_ball()
 five()
 var at: Vector2 = game.active.runtime.goal_ring.center
 game._observe_authored_motion(at, at)
 check(game.drafting and not card.visible, "Crossing the open goal dismisses the pose before the Act draft")
 if game.drafting:
  game.choose_buddy(game.buddies.offers()[0].id)
  game.transfer._process(game.transfer.DURATION)
  settle_ball()
  check(game.active_sequence == 1 and not card.visible and card.milestone == 0, "New Act starts with an empty cut-in")
 five()
 game._finish_run(false)
 check(session.state == "results" and not card.visible, "Results dismisses the active cut-in")
 var old_card: WeakRef = weakref(card)
 await close()
 check(old_card.get_ref() == null, "Session teardown releases the card")
 print("RESULT | Combo celebration | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func close() -> void:
 Engine.time_scale = 1.0
 session.archive_attempted = true
 await session._close_run("combo_review")
 session.free()
 for frame in 3: await process_frame
