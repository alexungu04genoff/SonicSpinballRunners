extends SceneTree
const Game = preload("res://scripts/endless/endless_game.gd")
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func run() -> void:
 game = Game.new()
 root.add_child(game)
 var started_at := Time.get_ticks_msec()
 while not game.started and Time.get_ticks_msec() - started_at < 240000:
  await process_frame
 check(game.started, "Opening buffer finishes without preparing every combination")
 if not game.started:
  quit(1)
  return
 var identities := [game.ball.get_instance_id(), game.tuning.get_instance_id(), game.controls.get_instance_id(), game.presentation.camera.get_instance_id()]
 check(game.library.visuals.size() == 2, "Only the opening two variants are cached at startup")
 check(game.resident.size() == 2, "Two Acts resident at startup")
 check(game.ball.mechanics == game.hub, "A single mechanics adapter owns the shared ball")
 check(game.resident[0].runtime.terrain[0].body.get_shape_owners().size() > 0, "Streamed terrain contains collision shapes")
 check(game.resident[0].nodes.all(func(node: Node): return node.process_mode != Node.PROCESS_MODE_DISABLED), "Ready Act visuals restore native processing for particles")
 if "--require-bakes" in OS.get_cmdline_user_args():
  check(game.library.visual_bake_hits == 2 and game.library.fallback_builds == 0, "Opening Acts load complete disk recipes without procedural rebuilding")
 print("ENDLESS_STARTUP_SECONDS | ", (Time.get_ticks_msec() - started_at) / 1000.0)
 await capture("start")
 # An unavailable entrance must park physics until the prepared neighbor returns.
 var neighbor: RefCounted = game.resident[1]
 game.resident.remove_at(1)
 game.ball.position.y = game.active.bounds().position.y + 50.0
 game._physics_process(1.0 / 120.0)
 check(game.loading_boundary and paused, "Unready entrance pauses before crossing")
 var held: Vector2 = game.ball.position
 for i in 3: await process_frame
 check(game.ball.position == held, "Physics remains parked while waiting for readiness")
 game.resident.insert(1, neighbor)
 for i in 3: await process_frame
 check(not game.loading_boundary and not paused, "Readiness automatically resumes play")
 game.reset_ball(false)
 for i in 3: await process_frame
 if "--full-buffer" in OS.get_cmdline_user_args():
  var fill_started := Time.get_ticks_msec()
  var warmed_zones := {}
  while game.resident.size() < 6 and Time.get_ticks_msec() - fill_started < 90000:
   await process_frame
   for zone: int in game.backgrounds:
    var background: Dictionary = game.backgrounds[zone]
    if background.ready or background.warm_until < 0 or warmed_zones.has(zone): continue
    warmed_zones[zone] = true
    check(background.layer.view.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "An invisible upcoming background keeps rendering during warm-up")
    check(is_zero_approx(background.layer.modulate.a), "Background warm-up never shows an unfinished layer")
  check(warmed_zones.has(1), "The next Zone warms its background during gameplay")
  check(game.resident.size() == 6, "Idle lookahead fills the current and next Zone without loading the library")
 game.toggle_tour()
 var parked: Vector2 = game.ball.position
 var max_resident: int = game.resident.size()
 var transitions := 27
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--transitions="): transitions = int(argument.trim_prefix("--transitions="))
 for i in transitions:
  var wait_started := Time.get_ticks_msec()
  while not game._next_ready() and Time.get_ticks_msec() - wait_started < 90000:
   await process_frame
  check(game._next_ready(), "Lookahead finishes within the smoke-test timeout")
  if not game._next_ready():
   quit(1)
   return
  if i == 2:
   var following: Dictionary = game.backgrounds[1]
   var saved_focus: Vector2 = game.presentation.tour_focus
   game.presentation.tour_focus.y = following.entrance_y - 25.0
   game.presentation.camera_focus = game.presentation.tour_focus
   game._update_backgrounds()
   check(game.background_blend > 0.45 and game.background_blend < 0.55, "Background and lighting blend midway through the physical seam")
   check(game.ball.position == parked, "Scenery blending never moves the ball")
   await capture("transition-midpoint")
   game.presentation.tour_focus = saved_focus
  game.jump_tour_boundary()
  for j in 12: await process_frame
  max_resident = maxi(max_resident, game.resident.size())
  check(game.library.visuals.size() <= game.library.MAX_VARIANTS, "Visual cache stays bounded")
  check(game.library.themes.size() <= game.library.MAX_THEMES, "Theme resource cache stays bounded")
  check(game.ball.position == parked, "Camera tour never forces the physics ball through terrain")
  check(game.active_sequence == i + 1, "Checkpoint ownership advances exactly once")
  check(game.ball.mechanics == game.hub, "Loading another Act never steals mechanics ownership")
  check(game.presentation.ring_visuals.size() == game.ring_field.rings.size(), "Ring visuals remain aligned with collection state")
  if i % 3 == 2: await capture("zone-%02d" % (i / 3 + 2))
 check(max_resident <= 8, "Resident Acts remain bounded over nine Zone transitions")
 check(identities == [game.ball.get_instance_id(), game.tuning.get_instance_id(), game.controls.get_instance_id(), game.presentation.camera.get_instance_id()], "Shared engine identities survive streaming")
 game.toggle_tour()
 for i in 6:
  await process_frame
  await physics_frame
 check(game.ball.position.distance_to(game.active.spawn()) < 1.0, "Leaving tour serves safely at the current checkpoint")
 check(not game.ball.mechanics.runtimes.is_empty(), "Resident mechanics remain installed")
 var ready_started := Time.get_ticks_msec()
 while not game._next_ready() and Time.get_ticks_msec() - ready_started < 90000: await process_frame
 check(game._next_ready(), "Next physical seam is ready")
 if game._next_ready():
  var next: RefCounted
  for act: RefCounted in game.resident:
   if act.plan.sequence == game.active_sequence + 1: next = act
  var before_sequence: int = game.active_sequence
  var before_position: Vector2 = game.ball.position
  var line: Vector2 = next.plan.offset + Vector2(next.document.terrain_bounds().size.x * 0.5, next.document.activation_y)
  game._observe_authored_motion(line + Vector2.DOWN * 10, line + Vector2.UP * 10)
  check(game.active_sequence == before_sequence + 1, "Physical activation crossing transfers checkpoint ownership")
  check(game.ball.position == before_position, "Checkpoint activation never teleports the ball")
  game._observe_authored_motion(line + Vector2.DOWN * 10, line + Vector2.UP * 10)
  check(game.active_sequence == before_sequence + 1, "The same crossing cannot advance a second Act")
 game.ball.position.y = game.active.document.red_gutter_bounds().end.y + game.active.plan.offset.y + 1.0
 check(game._at_playfield_drain(), "Drain follows the active checkpoint, not the first Act")
 game.reset_ball(false)
 for i in 3: await physics_frame
 game.launch_ball()
 for i in 10: await physics_frame
 check(not game.ball.serve_pending, "Normal pinball launch still works")
 check(game.ball.position.is_finite(), "Streamed physics stays finite")
 if "--require-bakes" in OS.get_cmdline_user_args():
  check(game.library.fallback_builds == 0, "Every requested Act/theme has a valid full bake")
  check(game.library.theme_bake_hits >= mini(game.active.plan.zone + 1, game.library.Registry.IDS.size()), "Each distinct theme uses its shared background disk bake")
 print("ENDLESS_SCENE_SMOKE | checks=%d failures=%d max_resident=%d max_build_ms=%.2f max_frame_ms=%.2f" % [checks, failures, max_resident, game.max_build_ms, game.max_frame_ms])
 # Stop requesting more work, then let the in-flight asynchronous load release
 # its temporary resources before this test tears down the entire scene tree.
 game.set_process(false)
 game.set_physics_process(false)
 var cleanup_started := Time.get_ticks_msec()
 while game.library.busy and Time.get_ticks_msec() - cleanup_started < 90000: await process_frame
 game.free()
 quit(1 if failures else 0)

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless" or "--captures" not in OS.get_cmdline_user_args(): return
 for i in 3: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/endless-" + label + ".png")
 # GPU readback and PNG compression are test work, not streaming frame time.
 game._last_frame_usec = Time.get_ticks_usec()
