extends "res://tests/authored_main_game_regression.gd"
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Mechanics = preload("res://scripts/authored_act/pinball_mechanics.gd")
const RailPath = preload("res://scripts/authored_act/rail_path.gd")
const SANDBOX := "res://data/acts/pinball_mechanics_sandbox.tres"
var ticks := 0

func frames(count := 3) -> void:
 # Count simulation steps, independent of rendered frames or headless catch-up.
 for i in count: await physics_frame

func object(type: String, at: Vector2, properties: Dictionary = {}) -> Dictionary:
 var item := Objects.make_placement(type)
 item.object_id = "sandbox_" + type
 item.position = at
 item.properties.merge(properties, true)
 return item

func fixture() -> Resource:
 var act := ActData.new()
 act.title = "Pinball Mechanics - Spinner, Magnet, Raised Crossover"
 act.grid_size = Vector2i(12, 12)
 act.cell_size = 50.0
 act.spawn_position = Vector2(280, 470)
 act.gameplay_objects = [
  object("spinner", Vector2(280, 450), {"width": 60.0}),
  object("magnetic_field", Vector2(300, 415), {"radius": 60.0, "strength": 140.0}),
  object("elevated_rail", Vector2(280, 380), {"points": PackedVector2Array([Vector2.ZERO, Vector2(0, -40), Vector2(90, -60), Vector2(180, -40), Vector2(180, 80)]), "width": 60.0, "height": 50.0, "drag": 0.0}),
  object("left_flipper", Vector2(240, 530)),
  object("right_flipper", Vector2(330, 530)),
 ]
 # Two lower rails bound a horizontal ring lane beneath the elevated crossover.
 act.placements = [
  {"shape_id": "wall_1x2", "base_size": Vector2i(1, 2), "anchor": Vector2i(7, 5), "offset": Vector2(0, 0.5), "quarter_turns": 1, "flip_h": false, "flip_v": false},
  {"shape_id": "wall_1x2", "base_size": Vector2i(1, 2), "anchor": Vector2i(7, 6), "offset": Vector2(0, 0.5), "quarter_turns": 1, "flip_h": false, "flip_v": false},
  {"shape_id": "wall_1x3", "base_size": Vector2i(1, 3), "anchor": Vector2i(2, 7), "quarter_turns": 0, "flip_h": false, "flip_v": false},
 ]
 act.ring_trails = [{"start": Vector2(350, 300), "end": Vector2(440, 300), "spacing": 25.0}]
 return act

func run() -> void:
 root.gui_embed_subwindows = true
 root.size = Vector2i(1280, 900)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var document := fixture()
 check(document.validation_errors().is_empty(), "Sandbox schema validates", str(document.validation_errors()))
 check(document.save_document(SANDBOX) == OK, "Sandbox saves through ordinary Act persistence")
 var restored: Dictionary = ActData.load_document(SANDBOX)
 check(restored.document != null and restored.document.fingerprint() == document.fingerprint(), "Exact IDs, properties and path survive disk reload", restored.error)
 if restored.document == null: quit(1); return
 var bad: Resource = document.copy_document()
 bad.gameplay_objects[1].object_id = bad.gameplay_objects[0].object_id
 check(not bad.validation_errors().is_empty(), "Duplicate stable IDs rejected")
 bad = document.copy_document()
 bad.gameplay_objects[1].properties.strength = INF
 check(not bad.validation_errors().is_empty(), "Nonfinite field strength rejected")
 var field: Dictionary = document.gameplay_objects[1]
 check(Mechanics.magnetic_acceleration(field, field.position) == Vector2.ZERO, "Field center has no singularity")
 var attract := Mechanics.magnetic_acceleration(field, field.position + Vector2(30, 0))
 field.properties.mode = "repel"
 check(Mechanics.magnetic_acceleration(field, field.position + Vector2(30, 0)).is_equal_approx(-attract), "Attract and repel have opposite bounded force")
 field.properties.mode = "attract"
 game = ObservedGame.new()
 game.authored_act_path = SANDBOX
 root.add_child(game)
 await frames(6)
 check(game.level_source == "authored", "Sandbox starts in the main game", game.last_source_error)
 if game.level_source != "authored": game.queue_free(); quit(1); return
 identities = engine_ids()
 game.controls.virtual_enabled = true
 game.ring_field.set_physics_process(false)
 var manager: Node = game.ball.mechanics
 game.launch_ball()
 var composed := false
 var completed_route := false
 for i in 720:
  game.controls.virtual_left = game.ball.position.y > 526 and game.ball.linear_velocity.y > 0
  await frames(1)
  composed = composed or game.ball.on_ramp
  if composed and not game.ball.on_ramp:
   completed_route = game.ball.position.x > 440
   break
 check(composed and completed_route and game.score > 0, "Ordinary flipper input composes spinner, magnet, complete rail and tangent exit", str([composed, completed_route, game.ball.position, game.score]))
 game.reset_ball(false)
 await frames(2)
 manager.scoring_tick.connect(func(_id: String, _points: int): ticks += 1)
 # Cross the spinner once, then move away without resetting its stored spin.
 await place(Vector2(280, 470), Vector2(0, -900))
 await frames(20)
 check(float(manager.items[0].spin) != 0.0 and ticks > 0 and game.score > 0, "Swept spinner crossing imparts spin and controlled Scorecraft ticks")
 var previous_spin: float = absf(manager.items[0].spin)
 await frames(10)
 check(absf(manager.items[0].spin) < previous_spin, "Spinner spins down after crossing")
 game.reset_ball(false)
 await frames(2)
 check(manager.items[0].spin == 0.0 and manager.items[0].tick_rotation == 0.0, "Reset clears spinner energy and fractional ticks")
 manager.items[0].spin = 1e12
 var before := ticks
 manager.tick(1.0 / 120.0)
 check(ticks - before <= Mechanics.MAX_TICKS_PER_STEP and manager.items[0].tick_rotation < PI, "Extreme spin cannot emit unbounded ticks or retain backlog")
 manager.reset()
 # With normal gravity, an off-axis field produces measurable horizontal momentum.
 await place(Vector2(260, 415), Vector2.ZERO)
 await frames(10)
 check(game.ball.linear_velocity.x > 0.1 and game.ball.position.x > 260.0, "Magnet bends the physical ball trajectory through additive force")
 var first_field_motion: Array = [game.ball.position, game.ball.linear_velocity]
 await place(Vector2(260, 415), Vector2.ZERO)
 await frames(10)
 check(game.ball.position.distance_to(first_field_motion[0]) < 0.001 and game.ball.linear_velocity.distance_to(first_field_motion[1]) < 0.001 and Engine.physics_ticks_per_second == 120, "Repeated field trajectory is deterministic at 120 Hz")
 paused = true
 var field_frozen: Array = [game.ball.position, game.ball.linear_velocity]
 await frames(5)
 check(field_frozen == [game.ball.position, game.ball.linear_velocity], "Pause freezes magnetic force and ball motion")
 paused = false
 # A strong forward entry crosses lower collision geometry on this same ball.
 await enter_rail()
 check(game.ball.on_ramp and game.ball.collision_mask == 0 and game.ball.collision_layer == 0, "Forward mouth crossing enters explicit elevated state")
 var ball_id: int = game.ball.get_instance_id()
 game.ring_field.set_physics_process(true)
 game.tuning.set_value("ring_magnet_radius", 0.0)
 var saw_crossing := false
 var camera_followed := true
 for i in 200:
  await frames(1)
  if game.ball.on_ramp:
   var screen: Vector2 = game.presentation.camera.unproject_position(game.presentation.map_point(game.ball.position, game.presentation.ball_height()))
   camera_followed = camera_followed and Rect2(Vector2.ZERO, Vector2(game.view.size)).has_point(screen)
  if game.ball.on_ramp and game.ball.position.x > 310 and game.ball.position.x < 435:
   saw_crossing = saw_crossing or game.ball.ramp_height >= 45.0
  if not game.ball.on_ramp: break
 check(game.rings_collected == 0, "Elevated traversal cannot collect rings on the lower table")
 check(camera_followed, "Existing follow camera keeps the elevated ball on screen")
 check(saw_crossing, "Raised ball traverses above the lower lane and collision rails")
 check(not game.ball.on_ramp and game.ball.collision_layer == 2 and game.ball.collision_mask == 1 and not game.ball.custom_integrator, "Exit restores original collision and integration state")
 check(game.ball.get_instance_id() == ball_id and game.ball.position.x > 440 and game.ball.linear_velocity.y > 0, "Same ball exits with forward tangent momentum")
 await enter_rail()
 if DisplayServer.get_name() != "headless":
  for i in 12: await frames(1)
  game.retro_filter.set_preset(0)
  game.presentation.set_camera_follow(false)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/pinball-crossover.png")
 paused = true
 var frozen := [game.ball.position, manager.progress, manager.items[0].angle, game.ball.ramp_height]
 await frames(8)
 check(frozen == [game.ball.position, manager.progress, manager.items[0].angle, game.ball.ramp_height], "Pause freezes rail, spinner and physical ball")
 paused = false
 await process_frame
 game.reset_ball(false)
 await frames(2)
 check(not game.ball.on_ramp and game.ball.collision_mask == 1 and game.ball.ramp_height == 0.0, "Reset from rail restores the normal table state")
 await place(Vector2(280, 365), Vector2(0, 220))
 check(not game.ball.on_ramp, "Backward entry cannot capture the ball")
 await place(Vector2(250, 380), Vector2(900, 0))
 check(not game.ball.on_ramp, "Side entry cannot capture the ball")
 await place(Vector2(280, 384), Vector2(0, -150))
 var weak_entered: bool = game.ball.on_ramp
 for i in 480:
  if weak_entered and not game.ball.on_ramp: break
  await frames(1)
  weak_entered = weak_entered or game.ball.on_ramp
 check(weak_entered and not game.ball.on_ramp and game.ball.linear_velocity.y > 0.0, "Weak uphill shot rolls back and leaves at the entry tangent", str([weak_entered, game.ball.on_ramp, game.ball.position, game.ball.linear_velocity, manager.speed]))
 await enter_rail()
 game.ball.position = Vector2(280, 720)
 game._physics_process(1.0 / 120.0)
 check(not game.ball.on_ramp and game.ball.collision_mask == 1 and manager.items[0].spin == 0.0, "Drain cancels elevated ownership and spinner state immediately")
 game.reset_ball(false)
 await frames(2)
 await enter_rail()
 var bad_document := fixture()
 bad_document.gameplay_objects[2].position = Vector2(450, 390)
 bad_document.cell_size = 60.0
 var bad_path := "res://test-results/blocked-rail.tres"
 check(bad_document.save_document(bad_path) == OK, "Obstructed rail remains a saveable editor draft")
 paused = true
 check(game.request_authored_act(bad_path), "Invalid replacement reaches runtime validation")
 await await_rebuild()
 check(game.last_source_error.contains("Rail") and game.ball.on_ramp and game.ball.mechanics == manager and is_equal_approx(game.ball.radius, 7.0), "Unsafe ramp mouth is rejected without changing the live rail or ball scale", str([game.last_source_error, game.ball.on_ramp, game.ball.mechanics == manager, game.ball.radius]))
 paused = false
 game.reload_authored_act()
 await await_rebuild()
 check_identity("Act reload retains the same main engine and camera")
 check(not is_instance_valid(manager) and not game.ball.on_ramp and game.ball.mechanics != null, "Reload removes old forces and rail ownership")
 await enter_rail()
 paused = true
 check(game.request_generated_source(), "Paused source switch is accepted")
 await await_rebuild()
 check(game.level_source == "generated" and not game.ball.on_ramp and game.ball.mechanics == null and game.ball.collision_mask == 1, "Source switch destroys mechanics and restores ordinary physics")
 check_identity("Source switch preserves authoritative ball and systems")
 paused = false
 game.queue_free()
 await frames(3)
 print("RESULT | Pinball mechanics | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func enter_rail() -> void:
 await place(Vector2(280, 395), Vector2(0, -900))
 for i in 12:
  if game.ball.on_ramp: break
  await frames(1)
