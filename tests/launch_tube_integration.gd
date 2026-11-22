extends SceneTree
## Real Prototype and Endless retry/streaming checks through current disk bakes.
const Act = preload("res://scripts/act_editor/act_geometry.gd")
const Session = preload("res://scripts/prototype/session.gd")
const WORKSHOP := "res://data/acts/Experiments/Launch Tube Workshop.tres"
const ORDINARY := "res://test-results/launch-tube/ordinary.tres"
const TUNNEL := "res://test-results/launch-tube/tunnel.tres"
var checks := 0
var failures := 0

class Stream extends "res://scripts/endless/endless_game.gd":
 func _source_paths() -> Array:
  return ["res://data/acts/Experiments/Launch Tube Workshop.tres", "res://test-results/launch-tube/ordinary.tres", "res://test-results/launch-tube/tunnel.tres"]
 func _next_planned_zone(documents: Array) -> Array[Dictionary]:
  planner.themes = ["green_hill"]
  var entries: Array[Dictionary] = planner.next_zone(documents)
  # Identical dimensions/connectors retain the real planner's offsets. Fix only
  # fixture order to put the ordinary Act between two resident tube Acts.
  for index in entries.size(): entries[index].id = index
  return entries

func _initialize() -> void:
 run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)

func frames(count: int) -> void:
 for index in count:
  await physics_frame
  await process_frame

func key(code: Key, pressed: bool) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.pressed = pressed
 Input.parse_input_event(event)

func until(condition: Callable, seconds := 10.0) -> bool:
 var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
 while Time.get_ticks_msec() < deadline:
  await frames(1)
  if condition.call(): return true
 return false

func prepare() -> void:
 var source: Resource = Act.load_document(WORKSHOP).document
 var ordinary: Resource = source.copy_document()
 ordinary.title = "Ordinary retry parity fixture"
 ordinary.gameplay_objects.remove_at(0)
 check(ordinary.save_document(ORDINARY) == OK, "Ordinary fixture saves without a Launch Tube")
 var tunnel: Resource = source.copy_document()
 tunnel.title = "Tunnel streaming fixture"
 tunnel.gameplay_objects[0].properties.presentation = "tunnel"
 check(tunnel.save_document(TUNNEL) == OK, "Tunnel fixture saves through the ordinary Act format")

func hits_terrain(game: Node, point: Vector2) -> bool:
 var query := PhysicsPointQueryParameters2D.new()
 query.position = game.active.plan.offset + point
 query.collision_mask = 1
 return not game.ball.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()

func check_moving_roll(game: Node, phase: String) -> void:
 var angle: float = game.character.roll_angle
 await frames(2)
 check(not is_equal_approx(angle, game.character.roll_angle) and game.ball.linear_velocity.is_zero_approx(), "%s animates during %s while physically contained" % [game.character.character_id, phase])

func launch(game: Node, check_character := false) -> void:
 game.controls.virtual_launch = false
 await frames(3)
 game.controls.virtual_launch = true
 var tube: Node = game.ball.launch_tube
 check(await until(func(): return tube.charge >= 0.98), "Player-controlled hold charges the active tube")
 if check_character: await check_moving_roll(game, "charge")
 game.controls.virtual_launch = false
 if check_character:
  check(await until(func(): return tube.phase == tube.Phase.OUTBOUND), "Launch enters traversal")
  await check_moving_roll(game, "outbound travel")
 check(await until(func(): return not tube.contained), "Player release exits into ordinary gameplay")

func prototype_check() -> void:
 var session := Session.new()
 session.settings_path = "user://launch-tube-integration.cfg"
 session.archive_directory = "user://telemetry/runs/_validation/launch_tube"
 session.configure_act_test(WORKSHOP)
 session.run_configuration.single_act_use_bakes = true
 session.run_configuration.selected_theme_ids = ["green_hill"]
 session.practice_mode = false
 session.sound_enabled = false
 root.add_child(session)
 await session.start_run()
 check(await until(func(): return is_instance_valid(session.game) and session.game.started, 180.0), "Real Prototype starts the baked Launch Tube Act")
 var game: Node = session.game
 if not is_instance_valid(game) or not game.started:
  session.free()
  return
 game.controls.virtual_enabled = true
 var tube: Node = game.ball.launch_tube
 check(is_instance_valid(tube) and tube.contained and game.ball.serve_pending, "Prototype initially docks instead of auto-launching")
 check(game.library.fallback_builds == 0 and game.library.visual_bake_hits == 1, "Prototype uses the current disk recipe with zero fallback")
 await frames(2)
 check(not hits_terrain(game, Vector2(115, 348)), "The baked bore cuts through the Workshop wall collision")
 check(hits_terrain(game, Vector2(75, 348)) and hits_terrain(game, Vector2(155, 348)), "Both terrain banks still collide beside the lane")
 check(not game.ring_field.scoring_enabled and not game._accept_scoring(game.active_scoring_id), "Contained Prototype suppresses ring and gameplay scoring")
 check(not game.specials.can_use(), "Contained Prototype cannot use a character action")
 game.controls.virtual_enabled = false
 key(KEY_ENTER, true)
 await frames(3)
 check(paused and not game.controls.launch_held() and tube.charge == 0.0, "Prototype Enter still pauses and cannot become a tube charge")
 key(KEY_ENTER, false)
 key(KEY_ENTER, true)
 key(KEY_ENTER, false)
 await frames(3)
 check(not paused, "Prototype Enter resumes through the unchanged Session control")
 key(KEY_X, true)
 check(await until(func(): return tube.charge >= 0.15), "The real Prototype X binding holds a charge")
 key(KEY_X, false)
 check(await until(func(): return tube.phase == tube.Phase.RETURNING), "Releasing the real X binding fires a weak rollback")
 await check_moving_roll(game, "rollback")
 check(await until(func(): return tube.phase == tube.Phase.DOCKED), "Real keyboard weak launch re-docks safely")
 game.controls.virtual_enabled = true
 await launch(game, true)
 check(game.ring_field.scoring_enabled and game._accept_scoring(game.active_scoring_id), "Successful exit restores scoring")
 game.ball.freeze = true
 game.set_physics_process(false)
 var manager: Node = game.active.runtime.mechanics
 manager._activate_switch(manager.by_id.workshop_switch)
 manager.by_id.workshop_spinner.goal_ticks = 7
 manager.by_id.workshop_spinner.tick_rotation = 0.25
 manager.by_id.workshop_spinner.spin = 2.0
 manager.by_id.workshop_spinner.cooldown = 2.75
 var score: int = game.score
 var identity: int = game.ball.get_instance_id()
 var balls: int = game.balls_remaining
 var target_time: Variant = game.telemetry.target_at
 game.controls.virtual_launch = true
 game._on_ball_drained()
 check(is_instance_valid(game.transfer) and game.balls_remaining == balls - 1, "Actual drain spends one Ball and retains the existing transfer")
 check(await until(func(): return not is_instance_valid(game.transfer)), "Death transfer finishes normally")
 await frames(90)
 check(game.ball.get_instance_id() == identity and game.ball.position.distance_to(tube.dock_position()) < 0.1, "Death returns the same real ball to the active tube dock")
 check(tube.contained and tube.charge == 0.0 and tube.require_release and game.auto_launch_time < 0.0, "Holding Launch through death cannot charge or auto-relaunch")
 check(manager.by_id.workshop_switch.active and manager.by_id.workshop_spinner.goal_ticks == 7, "Death-to-dock preserves switch and spinner objective progress")
 check(manager.by_id.workshop_spinner.spin == 0.0 and manager.by_id.workshop_spinner.tick_rotation == 0.25 and manager.by_id.workshop_spinner.cooldown == 2.75, "Death-to-dock keeps partial rotation and exact cooldown, while stopping inertia")
 check(game.score == score and game.telemetry.target_at == target_time, "Death-to-dock preserves score and target telemetry")
 game.controls.virtual_launch = false
 await frames(5)
 check(tube.contained and tube.charge == 0.0 and not tube.require_release, "Release after death only arms a fresh charge")
 game.specials.select_character("tails")
 await launch(game, true)
 game.ball.freeze = true
 manager._activate_switch(manager.by_id.workshop_switch)
 check(game.score == score, "Preserved switch does not pay a duplicate reward after relaunch")
 var watched: WeakRef = weakref(tube)
 await session._close_run("validation")
 session.free()
 await frames(4)
 check(watched.get_ref() == null, "Prototype close releases the tube owner")

func endless_check() -> void:
 var game := Stream.new()
 root.add_child(game)
 check(await until(func(): return game.started or not game.last_source_error.is_empty(), 180.0) and game.started, "Real Endless starts the deterministic three-Act disk fixture")
 if not game.started:
  await game.prepare_to_close()
  game.free()
  return
 game.controls.virtual_enabled = true
 var tube: Node = game.ball.launch_tube
 check(is_instance_valid(tube) and tube.contained, "Endless initial active Act owns its tube")
 await launch(game)
 game.ball.freeze = true
 game.active.runtime.mechanics._activate_switch(game.active.runtime.mechanics.by_id.workshop_switch)
 var score: int = game.score
 var identity: int = game.ball.get_instance_id()
 game.controls.virtual_launch = true
 game._on_ball_drained()
 check(await until(func(): return game.respawn_time < 0.0 and tube.contained), "Endless drain returns to dock through the existing reset path")
 await frames(90)
 check(game.ball.get_instance_id() == identity and game.score == score, "Endless retry keeps the real ball and earned score")
 check(game.auto_launch_time < 0.0 and tube.charge == 0.0 and tube.require_release, "Endless held-through-death latch prevents relaunch")
 check(await until(func(): return game.resident.size() >= 3, 180.0), "Both neighboring Acts stream into residency")
 var ordinary: RefCounted
 var tunnel_act: RefCounted
 var next_tube: Node
 for act: RefCounted in game.resident:
  if act.plan.sequence == 1: ordinary = act
  if act.plan.sequence == 2:
   tunnel_act = act
   next_tube = act.runtime.launch_tubes[0]
 check(ordinary != null and is_instance_valid(next_tube), "Ordinary Act is bordered by two independently owned tubes")
 if ordinary != null:
  game._activate(ordinary)
  game.reset_ball(true)
  check(game.ball.launch_tube == null and game.auto_launch_time == 0.25, "Ordinary active Act retains its exact legacy retry delay")
  check(await until(func(): return not game.ball.serve_pending), "Ordinary Act still auto-launches after retry")
  game._on_ball_drained()
  check(await until(func(): return game.respawn_time < 0.0 and not game.ball.serve_pending), "Ordinary Act still auto-launches after a real drain")
  check(game.ball.launch_tube == null and not tube.contained and not next_tube.contained, "Neither resident neighboring tube captures the ordinary Act's retry")
 if tunnel_act != null:
  game._activate(tunnel_act)
  game.reset_ball(false)
  check(game.ball.launch_tube == next_tube and game.ball.position.is_equal_approx(tunnel_act.spawn()), "A later active Act docks at its streamed world offset")
  check(next_tube.properties.presentation == "tunnel", "The independently streamed Tunnel mode retains its authored settings")
  await launch(game)
 check(game.library.fallback_builds == 0, "Endless streaming and retries retain zero runtime fallback builds")
 var watched: WeakRef = weakref(next_tube)
 ordinary = null
 tunnel_act = null
 await game.prepare_to_close()
 game.free()
 await frames(4)
 check(watched.get_ref() == null, "Endless teardown releases neighboring tube ownership")

func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://test-results/launch-tube")
 if "--prepare" in OS.get_cmdline_user_args():
  prepare()
 else:
  await prototype_check()
  paused = false
  await endless_check()
 await process_frame
 print("RESULT | Launch Tube integration | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
