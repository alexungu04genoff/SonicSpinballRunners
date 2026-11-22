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

func screen_bounds(model: MeshInstance3D) -> Rect2:
 var camera: Camera3D = game.presentation.camera
 var to_screen := Vector2(root.size) / camera.get_viewport().get_visible_rect().size
 var bounds := Rect2()
 for surface in model.mesh.get_surface_count():
  var vertices: PackedVector3Array = model.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
  for i in vertices.size():
   var p := camera.unproject_position(model.to_global(vertices[i])) * to_screen
   bounds = Rect2(p, Vector2.ZERO) if surface == 0 and i == 0 else bounds.expand(p)
 return bounds

func review_key(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if not is_instance_valid(game) or paused or game.finished or game.closing or is_instance_valid(game.transfer): return
 var key: int = event.keycode
 if key not in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_0, KEY_9, KEY_F9]: return
 settle_ball()
 if key == KEY_F9:
  game.set_celebration_retro(card.get_parent() == game.hud)
 elif key == KEY_9:
  # Top up the real target and take the normal goal/draft transition.
  game._on_mechanic_score(&"switch", "review-target", game.act_score_target, game.active_scoring_id)
  var at: Vector2 = game.active.runtime.goal_ring.center
  game._observe_authored_motion(at, at)
 elif key >= KEY_1 and key <= KEY_7 and not event.shift_pressed:
  game.specials.select_character(CharacterSpecials.CHARACTER_IDS[key - KEY_1])
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
 var posed_frames := 0
 var seen_tricks := {}
 var follows_ball := true
 var collision_layer: int = game.ball.collision_layer
 var collision_mask: int = game.ball.collision_mask
 var previous: Vector2 = game.ball.position
 for frame in 90:
  await process_frame
  if frame == 12:
   game.scorecraft.reset("Review chain")
   for i in 2: hit()
  if frame in [18, 26, 35]: hit()
  if "--review-trick-cycle" in OS.get_cmdline_user_args():
   if frame == 45:
    for i in 3: hit()
   if frame == 54:
    for i in 2: hit()
  await RenderingServer.frame_post_draw
  if card.visible:
   live_frames += 1
   travel += previous.distance_to(game.ball.position)
  if card.character_pose.is_visible_in_tree():
   seen_tricks[card.milestone] = true
   posed_frames += 1
   var offset: Vector3 = card.character_pose.global_position - game.character.spin_root.global_position
   follows_ball = follows_ball and not game.character.rolling_mesh.visible and Vector2(offset.x, offset.z).length() < 0.001
   follows_ball = follows_ball and not game.ball.freeze and game.ball.collision_mask == collision_mask and game.ball.collision_layer == collision_layer
  previous = game.ball.position
  var image := root.get_texture().get_image()
  check(image.save_jpg(path.path_join("%03d.jpg" % frame), 0.95) == OK, "Save movie frame")
 check(live_frames >= 24 and travel > game.ball.radius * 2, "Ball travels during the cut-in")
 check(posed_frames >= 18 and follows_ball, "The pose replaces the rolling mesh on the moving, colliding Ball")
 check(seen_tricks.has_all([2, 3, 4, 5]), "The moving Ball shows every early trick and the five-hit milestone")
 check(not card.character_pose.visible and game.character.rolling_mesh.visible, "The original roll returns after the moving pose")
 print("COMBO_CLIP | visible frames=", live_frames, " | posed frames=", posed_frames, " | Ball distance=", travel)

func check_roll_heading() -> void:
 var actor = game.character
 var ball: PlaygroundBall = game.ball
 var velocity := ball.linear_velocity
 var dt := 1.0 / 60.0
 for travel: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2(1, 1), Vector2(-1, -1), Vector2.DOWN]:
  ball.linear_velocity = travel.normalized() * ball.radius * 28.0
  var phase: float = actor.roll_angle
  actor._process(dt)
  var facing := Vector3(travel.x, 0, travel.y).normalized()
  var heading: Basis = actor.spin_root.global_basis.orthonormalized()
  var axle: Vector3 = actor.rolling_mesh.global_basis.x.normalized()
  check(heading.y.is_equal_approx(Vector3.UP) and heading.z.is_equal_approx(facing) and axle.is_equal_approx(Vector3.UP.cross(facing)), "The character turns upright through " + str(travel))
  check(is_equal_approx(angle_difference(phase, actor.roll_angle), 28.0 * 2.0 * dt), "The shell and curl advance at twice the base spin rate")
  var tails: MeshInstance3D = game.combo_celebration.character_pose.trailing_tails
  if tails:
   var offset := tails.global_basis * tails.mesh.get_aabb().get_center()
   check(offset.dot(facing) < 0.0, "The exterior tails point behind the current travel direction")
   var before := tails.global_transform
   actor._process(dt)
   check(tails.global_transform.is_equal_approx(before), "Rolling around the axle leaves the two tails in place")
   var pose = game.combo_celebration.character_pose
   var start_time: float = pose.tail_time
   pose._process(dt)
   var frame: float = fposmod((start_time + dt) * 7.0, 8.0)
   var target := clampi(roundi(frame), 1, 7)
   check(tails.get_blend_shape_count() == 7 and is_equal_approx(tails.get_blend_shape_value(target - 1), maxf(0.0, 1.0 - absf(frame - target))), "Live tails interpolate through seven authored shapes per second")
 var last_heading: Basis = actor.spin_root.basis
 ball.linear_velocity = Vector2.ZERO
 actor._process(dt)
 check(last_heading.is_equal_approx(actor.spin_root.basis), "The character holds the last heading at an apex")
 ball.has_track_frame = true
 var loop_path = preload("res://scripts/authored_act/loop_path.gd")
 ball.track_frame = loop_path.local_frame(loop_path.LEAD + loop_path.ARC * 0.5, true)
 for speed: float in [240.0, -240.0]:
  ball.track_speed = speed
  actor._process(dt)
  var frame: Basis = actor.spin_root.basis.orthonormalized()
  var axle: Vector3 = actor.rolling_mesh.global_basis.x.normalized()
  check(frame.y.is_equal_approx(ball.track_frame.y) and frame.z.is_equal_approx(-ball.track_frame.z * signf(speed)) and is_zero_approx(axle.dot(frame.y)), "The curl follows the Loop surface and signed traversal")
  var tails: MeshInstance3D = game.combo_celebration.character_pose.trailing_tails
  if tails: check(tails.global_basis.orthonormalized().is_equal_approx(frame), "Tails follow signed Loop travel independently of the body spin")
 ball.has_track_frame = false
 ball.track_speed = 0.0
 ball.track_frame = Basis.IDENTITY
 ball.linear_velocity = Vector2.RIGHT * 180.0
 actor._process(dt)
 check(actor.spin_root.global_basis.y.normalized().is_equal_approx(Vector3.UP) and is_zero_approx(actor.rolling_mesh.global_basis.x.y), "Leaving an inverted Loop restores upright rolling immediately")
 ball.linear_velocity = velocity

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
 if "--require-sonic-model" in OS.get_cmdline_user_args():
  check(card.character_pose.mesh is ArrayMesh, "Capture uses the baked Runners model")
 var pose = card.character_pose
 if "--require-runners-set" in OS.get_cmdline_user_args():
  check(is_instance_valid(pose.runners_roll) and pose.tricks.size() == 3, "Original curled Sonic and all three tricks loaded")
 if "--interactive" in OS.get_cmdline_user_args():
  settle_ball()
  root.title = "Combo review   |   1–7 Character   Shift+5 / 8 / 0 Hits   Enter Pause   9 Goal   F9 Retro"
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
 check_roll_heading()
 game.presentation.reset_camera(game.ball.position)
 var scoring: Scorecraft = game.scorecraft
 var fallback := preload("res://scripts/prototype/sonic_combo_pose.gd").new()
 fallback.prepare(game.character, card.POSES.sonic, local.path_join("missing.glb"))
 game.character.add_child(fallback)
 fallback.start_trick()
 check(fallback.mesh is QuadMesh and fallback.visible and not game.character.rolling_mesh.visible, "The shared Sonic artwork takes the Ball's place when the local model is absent")
 fallback.restore_ball()
 fallback.free()
 for id: String in CharacterSpecials.CHARACTER_IDS:
  game.specials.select_character(id)
  if id == "tails": check_roll_heading()
  if is_instance_valid(pose.runners_roll):
   var shell: MeshInstance3D = game.character.rolling_mesh
   check(shell.mesh is SphereMesh and pose.runners_roll.visible and shell.transparency > 0.0, "The selected Runners character wears a translucent shell")
  else:
   check(is_zero_approx(game.character.rolling_mesh.transparency), "The procedural shell stays opaque without a Runners model")
  for cached: Dictionary in pose.sets.values():
   if cached.has("roll"): check(cached.roll.visible == (cached.roll == pose.runners_roll), "Only the selected character's curl can appear")
  check(not card.visible and card.milestone == 0, "Character selection clears the previous pose")
  var unfolds := id == "sonic" or pose.runners_roll != null
  hit()
  check(not card.visible and not pose.visible, "The first builder leaves the Ball rolling")
  for tier: int in [2, 3, 4]:
   var start_score: int = game.score
   hit()
   check(scoring.multiplier == tier and card.visible and card.milestone == tier and card.points == game.score - start_score, "%s gets the exact receipt at ×%d" % [id, tier])
   var duration: float = [0.20, 0.25, 0.30][tier - 2]
   card._process(duration - 0.001)
   check(pose.visible == unfolds and game.character.rolling_mesh.visible != unfolds, "The ×%d trick holds for its full beat" % tier)
   card._process(0.002)
   check(not pose.visible and game.character.rolling_mesh.visible and card.visible, "The ×%d trick restores the Ball while the receipt stays readable" % tier)
  var before: int = game.score
  hit()
  check(scoring.multiplier == 4 and card.visible and card.character == id and card.milestone == 5 and card.points == game.score - before, "Fifth builder displays the selected pose and exact award")
  card._process(0.3)
  check(card.character_pose.visible == unfolds and game.character.rolling_mesh.visible != unfolds and not card.visible, "A late fifth hit holds its own pose through the receipt deadline")
  if pose.trailing_tails: check(not pose.trailing_tails.visible, "Tricks use only their own authored tails")
  card._process(0.101)
  check(not pose.visible and game.character.rolling_mesh.visible and not card.is_processing(), "The five-hit trick ends at 0.40 seconds and the hidden card sleeps")
  five()
  card._process(0.2)
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
 check(card.visible and card.milestone == 8 and card.age == age, "Eight upgrades the existing card in place")
 hit()
 hit(125)
 check(card.milestone == 10 and card.points == 125 and card.age == age, "Ten upgrades without extending the original receipt deadline")
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
 game.specials.select_character("sonic")
 if is_instance_valid(pose.runners_roll):
  if not output.is_empty(): await still("runners-roll")
  var curl_bounds := screen_bounds(pose.runners_roll)
  print("ROLL_SIZE | ", curl_bounds)
  var previous_index: int = pose.trick_index
  var expected: int = previous_index
  var reached := 0
  for target: int in [2, 3, 4, 5, 8, 10, 15]:
   for i in range(reached, target): hit()
   reached = target
   expected = (expected + 1) % 3
   check(card.milestone == target and pose.trick_index == expected and pose.mesh == pose.tricks[expected], "Each earned Sonic milestone advances one original trick")
   card._process(0.10)
   var trick_bounds := screen_bounds(pose)
   check(pose.global_basis.get_scale().is_equal_approx(pose.runners_roll.global_basis.get_scale()), "Trick %d uses the curled model's character scale" % (expected + 1))
   check(pose.visible and not game.character.rolling_mesh.visible, "Rapid scoring cuts directly to the latest earned trick")
   print("TRICK_SIZE | ", expected + 1, " | ", trick_bounds)
   if not output.is_empty(): await still("runners-trick-%d" % (expected + 1))
  var ball: PlaygroundBall = game.ball
  var velocity := ball.linear_velocity
  ball.linear_velocity = Vector2.ZERO
  pose._process(0.0)
  check(is_zero_approx(pose.runners_roll.get_instance_shader_parameter("roll_exposure")), "Curled Sonic keeps sharp textures at rest")
  check(is_equal_approx(1.0 - game.character.rolling_mesh.transparency, 0.3) and is_zero_approx(pose.runners_roll.transparency), "Sonic's shell is 30 percent opaque at rest")
  ball.linear_velocity = Vector2.RIGHT * ball.radius * 40
  pose._process(0.0)
  check(is_equal_approx(pose.runners_roll.get_instance_shader_parameter("roll_exposure"), 1.0), "Fast free roll reaches full directional exposure")
  check(is_equal_approx(1.0 - game.character.rolling_mesh.transparency, 0.3), "The shell stays 30 percent opaque at full blur")
  ball.has_track_frame = true
  ball.track_speed = -ball.radius * 18
  pose._process(0.0)
  check(is_equal_approx(pose.runners_roll.get_instance_shader_parameter("roll_exposure"), smoothstep(5.0, 32.0, 18.0)), "Track exposure follows signed track speed in either direction")
  ball.has_track_frame = false
  ball.track_speed = 0.0
  ball.linear_velocity = velocity
 five()
 card._process(0.3)
 game.toggle_pause()
 check(not card.character_pose.visible and game.character.rolling_mesh.visible, "Pause restores Sonic's roll immediately")
 game.toggle_pause()
 five()
 card._process(card.DURATION)
 check(not card.character_pose.visible and game.character.rolling_mesh.visible, "Natural expiry restores Sonic's roll")
 scoring.reset("Review chain")
 hit()
 for i in scoring.config.rings_per_link: scoring.award_ring("link-ring-%d" % i)
 check(scoring.builder_hits == 2 and card.milestone == 2 and pose.visible, "A completed Ring Link earns the two-hit trick")
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
 card._process(0.3)
 game._on_retry_requested()
 check(is_instance_valid(game.transfer) and not card.visible and scoring.builder_hits == 0, "Retry clears the cut-in and hit count")
 check(not card.character_pose.visible and game.transfer.proxy.get_child(0).visible, "The checkpoint transfer borrows the restored rolling mesh")
 game.transfer._process(game.transfer.DURATION * 0.15)
 check(game.transfer.proxy.basis.y.normalized().is_equal_approx(Vector3.UP) and is_zero_approx(game.transfer.upright_roll.global_basis.x.normalized().y), "The checkpoint return rolls on a level axle")
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
 var old_pose: WeakRef = weakref(card.character_pose)
 await close()
 check(old_card.get_ref() == null and old_pose.get_ref() == null, "Session teardown releases the card and on-table pose")
 print("RESULT | Combo celebration | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func close() -> void:
 Engine.time_scale = 1.0
 session.archive_attempted = true
 await session._close_run("combo_review")
 session.free()
 for frame in 3: await process_frame
