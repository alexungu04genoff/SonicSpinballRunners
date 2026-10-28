extends "res://tests/authored_gimmick_regression.gd"
## Focused swept geometry, saved authoring, and real main-game trajectories.
const Lanes = preload("res://scripts/authored_act/passing_lanes.gd")
const BatchBanks = preload("res://scripts/act_editor/switch_banks.gd")
const BATCH_PATH := "res://test-results/gimmick-batch.tres"
const BATCH_EXAMPLE := "res://data/acts/routing_mechanics_sandbox.tres"
var score_events: Array = []
var ring_events: Array = []
var traversal_events: Array = []

func batch_fixture() -> Resource:
 var act := ActData.new()
 act.title = "Routing Mechanics — Switch, Divert, Light, Dash"
 act.grid_size = Vector2i(12, 20)
 act.spawn_position = Vector2(300, 850)
 act.activation_y = 800.0
 act.entry_start_x = 5
 act.entry_width = 2
 act.exit_start_x = 2
 act.exit_width = 2
 act.gameplay_objects = [
  object("switch_target", "floor_blue", Vector2(220, 790), {"color": "blue", "label": "1", "score_reward": 100.0}),
  object("switch_target", "floor_red", Vector2(380, 790), {"color": "red", "label": "2", "score_reward": 100.0}),
  object("wall_switch", "wall_green", Vector2(30, 740), {"color": "green", "label": "3", "score_reward": 100.0}, 90.0),
  object("diverter", "route", Vector2(300, 640), {"length": 110.0, "state_a_angle": -10.0, "state_b_angle": 60.0}),
  object("lane_barrier", "lanes", Vector2(80, 430), {"points": PackedVector2Array([Vector2.ZERO, Vector2(80, 0), Vector2(160, 0), Vector2(240, 0)]), "lane_reward": 100.0, "completion_bonus": 750.0, "reset_delay": 0.5}),
  object("dash_panel", "dash", Vector2(120, 270), {"width": 65.0, "boost_strength": 600.0, "directional_influence": 70.0}),
  object("left_flipper", "left", Vector2(260, 900), {}, rad_to_deg(0.32)),
  object("right_flipper", "right", Vector2(340, 900), {}, rad_to_deg(PI - 0.32)),
  object("left_flipper", "upper", Vector2(175, 555), {}, rad_to_deg(-0.12)),
  object("spring", "serve_spring", Vector2(300, 850), {"launch_strength": 1100.0, "color": "red"}),
 ]
 act.switch_banks = [{"bank_id": "route_bank", "label": "Route to the Passing Lanes", "members": ["floor_blue", "floor_red", "wall_green"], "gates": [], "actions": [{"object_id": "route", "action": "set_b"}], "completion_bonus": 250.0, "reset_delay": 0.0}]
 # Side walls and two lower return slopes leave a normal center drain.
 for x in [0, 11]:
  act.placements.append({"shape_id": "composite", "base_size": Vector2i(1, 20), "anchor": Vector2i(x, 0), "quarter_turns": 0, "flip_h": false, "flip_v": false,
   "composite_version": 1, "smoothing_strength": 0.0, "outline": PackedVector2Array([Vector2(0.4, 0), Vector2(0.6, 0), Vector2(0.6, 20), Vector2(0.4, 20)])})
 for x in [0, 7]:
  act.placements.append({"shape_id": "composite", "base_size": Vector2i(5, 3), "anchor": Vector2i(x, 17), "quarter_turns": 0, "flip_h": x == 7, "flip_v": false,
   "composite_version": 1, "smoothing_strength": 0.0, "outline": PackedVector2Array([Vector2(0.4, 0), Vector2(5, 1.2), Vector2(5, 1.7), Vector2(0.4, 3)])})
 act.ring_trails = [{"start": Vector2(120, 210), "end": Vector2(120, 50), "spacing": 25.0}]
 return act

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 root.size = Vector2i(1440, 1000)
 root.gui_embed_subwindows = true
 var args := OS.get_cmdline_user_args()
 if "--write-example" in args:
  var example := batch_fixture()
  print(example.validation_errors())
  var error: Error = example.save_document(BATCH_EXAMPLE)
  if error != OK:
   ResourceSaver.save(example._storage_document(), "res://test-results/batch-storage-debug.tres")
   print("SAVE FAILED: ", error, " | ", ActData.load_document("res://test-results/batch-storage-debug.tres"))
  quit(0 if error == OK else 1)
  return
 if "--reopen-batch" in args:
  var result := ActData.load_document(BATCH_PATH)
  quit(0 if result.document != null and result.document.fingerprint() == args[-1] else 1)
  return
 _geometry_checks()
 var act := batch_fixture()
 # Isolate the real ball shots from the sandbox's return slopes and helper paddle.
 act.placements = []
 act.gameplay_objects = act.gameplay_objects.slice(0, 6)
 act.gameplay_objects.append(object("one_way_gate", "gate", Vector2(480, 300)))
 act.switch_banks[0].actions.append({"object_id": "gate", "action": "open"})
 act.gameplay_objects[5].rotation_degrees = 27.123456789012345
 act.gameplay_objects[5].properties.boost_strength = 410.123456789012345
 act.gameplay_objects[4].properties.points[1] = Vector2(80.125, 0.25)
 act.switch_banks[0].completion_bonus = 250.123456789012345
 check(act.validation_errors().is_empty(), "Batch schema validates", str(act.validation_errors()))
 check(act.save_document(BATCH_PATH) == OK, "Format 14 saves new mechanics and explicit actions")
 var loaded_batch := ActData.load_document(BATCH_PATH)
 check(loaded_batch.document != null and loaded_batch.document.fingerprint() == act.fingerprint(), "All new geometry, properties and links persist exactly")
 if loaded_batch.document == null: quit(1); return
 var output: Array = []
 var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/gimmick_batch_regression.gd", "--", "--reopen-batch", act.fingerprint()], output, true)
 check(code == 0, "Format 14 survives a fresh Godot process")
 for path: String in ["res://tests/fixtures/act_format_2.tres", "res://tests/fixtures/act_format_3.tres", "res://data/acts/pinball_mechanics_sandbox.tres", EXAMPLE]:
  check(ActData.load_document(path).document != null, "Old authored Act migrates: " + path)
 var old: Resource = act.copy_document()
 old.format_version = 13
 ResourceSaver.save(old, "res://test-results/batch-wrong-version.tres")
 check(ActData.load_document("res://test-results/batch-wrong-version.tres").document == null, "Format 13 cannot silently contain format 14 mechanics")
 var bad: Resource = act.copy_document()
 bad.switch_banks[0].actions[0].action = "script"
 check(not bad.validation_errors().is_empty(), "Arbitrary bank actions rejected")
 bad = act.copy_document()
 bad.switch_banks[0].actions.append(bad.switch_banks[0].actions[0].duplicate())
 check(not bad.validation_errors().is_empty(), "Duplicate action targets rejected")
 bad = act.copy_document()
 bad.switch_banks[0].gates = false
 bad.gameplay_objects[4].properties.post_radius = "bad"
 check(not bad.validation_errors().is_empty(), "Malformed bank arrays and post dimensions fail without coercion")
 game = ObservedGame.new()
 game.authored_act_path = BATCH_PATH
 root.add_child(game)
 await frames(8)
 check(game.playfield.source == "authored", "Main game loads new authored Act", game.last_source_error)
 if game.playfield.source != "authored": game.free(); quit(1); return
 manager = game.ball.mechanics
 identities = engine_ids()
 manager.mechanic_score.connect(func(kind, id, points): score_events.append([kind, id, points]))
 manager.mechanic_rings.connect(func(kind, id, count): ring_events.append([kind, id, count]))
 manager.traversal_event.connect(func(kind, id, phase): traversal_events.append([kind, id, phase]))
 game.controls.virtual_enabled = true
 game.tuning.set_value("max_downward_speed", 3000.0)
 await _wall_and_bank_checks()
 await _lane_shots()
 await _diverter_shots()
 await _dash_shots()
 await _theme_checks()
 _streaming_checks(act)
 await game.reload_authored_act()
 await frames(6)
 manager = game.ball.mechanics
 check(manager.by_id.route.state == "a" and manager.by_id.route.pending_state == "" and not manager.by_id.wall_green.active and not manager.by_id.lanes.complete, "Reload restores authored states and clears feature progress")
 check(game.ball.get_instance_id() == identities.ball, "All mechanics and reload retain the one authoritative ball")
 await game.request_authored_act(BATCH_EXAMPLE)
 await await_rebuild()
 manager = game.ball.mechanics
 check(manager.by_id.lanes.lanes.size() == 3 and manager.banks[0].actions[0].action == "set_b", "Editable sandbox loads the complete objective")
 await _sandbox_route()
 game.free()
 print("RESULT | Gimmick batch | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func _streaming_checks(act: Resource) -> void:
 var streamed := preload("res://scripts/endless/streamed_act.gd").new()
 streamed.document = act
 streamed.source = Compiler.compile(act, game.tuning, game.controls, game.ball)
 streamed.game = game
 streamed.plan = {"offset": Vector2(600, -1000)}
 var machine := preload("res://scripts/authored_act/pinball_mechanics.gd").new()
 machine.ball = game.ball
 machine.bind_ball_on_ready = false
 streamed.root.add_child(machine)
 streamed.runtime = {"mechanics": machine, "objects": [], "flippers": []}
 for i in streamed.source.objects.size(): streamed._object_step()
 var descriptor: Dictionary = streamed.runtime.objects.filter(func(e): return e.object_id == "lanes")[0]
 check(descriptor.body is StaticBody2D and descriptor.body.get_child_count() == 4 and descriptor.body.position == act.gameplay_objects[4].position + streamed.plan.offset, "Streamed lane chain retains native post colliders and Act offset")
 check(machine.by_id.lanes.posts[1] == Objects.world_posts(act.gameplay_objects[4])[1] + streamed.plan.offset, "Streamed swept gap positions match physical post geometry")
 var recipe := preload("res://scripts/endless/visual_recipe.gd").new()
 recipe.capture(visuals())
 recipe.finish()
 var visual_root := Node3D.new()
 var nodes: Array[Node] = []
 for i in recipe.records.size(): recipe.instantiate_one(i, nodes, visual_root)
 recipe.bind_animations(nodes, game.presentation, machine)
 var source_entry: Dictionary = visuals().gimmicks.filter(func(e): return e.item.object_id == "lanes")[0]
 var streamed_entry: Dictionary = nodes[0].gimmicks.filter(func(e): return e.item.object_id == "lanes")[0]
 check(streamed_entry.item == machine.by_id.lanes and streamed_entry.lights[0] != source_entry.lights[0], "Baked animation binds resident state and private lane-light materials")
 machine.by_id.lanes.lanes[0].lit = true
 Models.update(streamed_entry)
 check(streamed_entry.emitters[0].material_override == streamed_entry.lights[0] and is_equal_approx(streamed_entry.lights[0].emission_energy_multiplier, 1.6), "Streamed lit state updates its rendered material")
 var dash_entry: Dictionary = nodes[0].gimmicks.filter(func(e): return e.item.object_id == "dash")[0]
 check(dash_entry.emitters.all(func(mesh): return mesh.material_override == dash_entry.material), "Streamed dash chevrons share only their own animated material")
 visual_root.free()
 streamed.source.root.free()
 streamed.root.free()
 streamed.visual.free()

func _geometry_checks() -> void:
 for count in range(2, 13):
  var points := PackedVector2Array()
  for i in count: points.append(Vector2(i * 80, 0))
  var item := object("lane_barrier", "test", Vector2.ZERO, {"points": points})
  var manager_test := preload("res://scripts/authored_act/pinball_mechanics.gd").new()
  manager_test.add_object(item, {})
  check(manager_test.by_id.test.lanes.size() == count - 1, "%d posts produce %d lanes" % [count, count - 1])
  manager_test.free()
 var lane := Lanes.make_lane()
 check(Lanes.observe(lane, Vector2(40, 100), Vector2(40, -100), Vector2.ZERO, Vector2(80, 0), 9.0, 7.5), "High-speed full gap crossing registers")
 lane = Lanes.make_lane()
 check(not Lanes.observe(lane, Vector2(10, 100), Vector2(10, -100), Vector2.ZERO, Vector2(80, 0), 9.0, 7.5), "Post / outer-edge clipping cannot score")
 lane = Lanes.make_lane()
 var farmed := false
 for i in 30: farmed = Lanes.observe(lane, Vector2(40, -2), Vector2(40, 2), Vector2.ZERO, Vector2(80, 0), 9.0, 7.5) or farmed
 check(not farmed and lane.passes == 0, "Resting and vibrating in gap cannot farm")
 lane = Lanes.make_lane()
 check(not Lanes.observe(lane, Vector2(40, 50), Vector2(40, 0), Vector2.ZERO, Vector2(80, 0), 9.0, 7.5) and lane.side == 1, "Partial traversal waits for complete ball clearance")
 check(Lanes.observe(lane, Vector2(40, 0), Vector2(40, -50), Vector2.ZERO, Vector2(80, 0), 9.0, 7.5), "Multi-step passage registers only at full departure")
 check(Lanes.observe(lane, Vector2(40, -50), Vector2(40, 50), Vector2.ZERO, Vector2(80, 0), 9.0, 7.5) and lane.passes == 2, "Full departure rearms bidirectional lane")
 var dash := object("dash_panel", "dash", Vector2.ZERO, {"boost_strength": 300.0, "speed_cap": 2400.0})
 for influence: float in [0.0, 50.0, 100.0]:
  dash.properties.directional_influence = influence
  var velocity := Objects.dash_velocity(Vector2(400, 0), dash)
  check(absf(velocity.length() - 700.0) < 0.01 and absf(velocity.angle() + PI / 2.0 * influence / 100.0) < 0.001, "Dash influence preserves speed and blends direction: %d%%" % influence)
 dash.properties.directional_influence = 100.0
 check(Objects.dash_velocity(Vector2.DOWN * 500, dash).is_equal_approx(Vector2.UP * 800), "Opposite dash directions cannot cancel or produce NaNs")
 check(is_equal_approx(Objects.dash_velocity(Vector2.UP * 1500, dash).length(), 1800.0), "Already fast aligned ball gains speed")
 check(is_equal_approx(Objects.dash_velocity(Vector2.UP * 3000, dash).length(), 2400.0), "Dash respects total safety cap")
 var craft := Scorecraft.new()
 check(craft.award_mechanic(&"switch", "wall", 100) == 100 and craft.last_award.kind == "switch", "Switch reward is typed and not clamped to spinner ticks")
 check(craft.award_mechanic(&"lane_set", "lanes", 750) == 750 and craft.chain == 0 and craft.remaining == 0, "Feature bonus remains fixed and cannot refresh combo")
 check(craft.award_mechanic(&"spinner", "spin", 100) == 25, "Spinner retains its own tick cap")
 craft.free()

func _wall_and_bank_checks() -> void:
 await move_in_run(Vector2(5, 740), Vector2(1500, 0))
 await frames(5)
 check(not manager.by_id.wall_green.active, "Wall switch ignores swept back-side impact")
 await move_in_run(Vector2(85, 740), Vector2(-2200, 0))
 await frames(4)
 check(manager.by_id.wall_green.active, "Wall switch accepts exposed-side high-speed contact")
 var entry: Dictionary = visuals().gimmicks.filter(func(e): return e.item.object_id == "wall_green")[0]
 Models.update(entry)
 check(entry.pad.position.y < 0.06 and entry.material.emission_energy_multiplier > 0, "Wall pad presentation follows shared switch state")
 var before: int = game.score
 await move_in_run(Vector2(85, 740), Vector2(-2200, 0))
 await frames(4)
 check(game.score == before, "Pressed wall switch awards once")
 for point: Vector2 in [Vector2(170, 790), Vector2(330, 790)]:
  await move_in_run(point, Vector2(1800, 0))
  await frames(5)
 check(manager.banks[0].complete and manager.by_id.route.state == "b" and manager.by_id.gate.open, "Mixed wall/floor bank dispatches diverter Set B and gate Open")
 check(score_events.any(func(event): return event[0] == &"switch_bank" and event[2] == 250), "Bank completion emits typed feature reward")
 await move_in_run(manager.by_id.floor_blue.position, Vector2.ZERO)
 manager.banks[0].reset_delay = 0.2
 manager.banks[0].reset_remaining = 0.2
 await frames(30)
 check(not manager.by_id.wall_green.active and not manager.banks[0].complete and manager.by_id.gate.open, "Repeatable bank clears switches while gate stays open")
 check(not manager.by_id.floor_blue.active, "Switch reset while overlapping requires departure before another press")
 var score_before: int = game.score
 for id: String in ["floor_blue", "floor_red", "wall_green"]: manager._activate_switch(manager.by_id[id])
 check(manager.banks[0].complete and game.score - score_before == 550 and manager.by_id.gate.open, "Rearmed mixed bank awards explicit member rewards and one bonus without closing gate")
 manager.tick(0.25)
 manager.scoring_active = false
 for id: String in ["floor_blue", "floor_red", "wall_green"]: manager._activate_switch(manager.by_id[id])
 check(not manager.banks[0].complete and not manager.by_id.floor_blue.active, "Inactive resident bank cannot consume a completion")
 manager.scoring_active = true
 manager.reset()

func _lane_shots() -> void:
 var item: Dictionary = manager.by_id.lanes
 var body: Node2D = game.authored_runtime.objects.filter(func(e): return e.object_id == "lanes")[0].body
 check(body is StaticBody2D and body.get_child_count() == 4 and body.get_child(0).shape is CircleShape2D, "Every lane post has a native 2D circle collider")
 await move_in_run(Vector2(80, 480), Vector2(0, -2200))
 await frames(5)
 check(game.ball.linear_velocity.y > 0 and item.lanes.all(func(lane): return lane.passes == 0), "Physical post rebounds ball without registering a lane")
 var before := score_events.size()
 for x in [120, 200, 280]:
  await move_in_run(Vector2(x, 490), Vector2(0, -2200))
  await frames(8)
 check(item.complete and item.completions == 1 and item.lanes.all(func(lane): return lane.lit), "Actual fast shots light all three gaps and complete set")
 check(score_events.size() - before == 4 and game.status_message.contains("LANE SET COMPLETE"), "Three lane rewards and one completion bonus reach main game")
 var frozen: Array = [item.cooldown, item.completions, game.ball.position]
 paused = true
 await frames(20)
 check(frozen == [item.cooldown, item.completions, game.ball.position], "Pause freezes feature reset timer and authoritative ball")
 paused = false
 await move_in_run(Vector2(500, 800), Vector2.ZERO)
 await frames(65)
 check(not item.complete and item.lanes.all(func(lane): return not lane.lit), "Completion delay clears all lights and rearms set")
 for x in [120, 200, 280]:
  await move_in_run(Vector2(x, 490), Vector2(0, -2200))
  await frames(8)
 check(item.completions == 2, "Same lane set can be completed repeatedly")
 manager.reset()
 item.properties.completion_mode = "off"
 item.properties.reward_type = "rings"
 item.properties.lane_reward = 3.0
 var rings: int = game.rings_collected
 await move_in_run(Vector2(120, 490), Vector2(0, -2200))
 await frames(8)
 check(game.rings_collected == rings + 3 and ring_events.back()[0] == &"lane", "Lane ring mode grants configured rings through main game")
 check(not item.complete, "Completion Off never awards a set bonus")
 manager.reset()
 item.properties.completion_mode = "light_all"
 item.properties.reward_type = "score"

func _diverter_shots() -> void:
 var item: Dictionary = manager.by_id.route
 var original_actions: Array = manager.banks[0].actions.duplicate(true)
 for action: String in ["set_b", "set_a", "toggle"]:
  manager.reset()
  await move_in_run(Vector2(500, 700), Vector2.ZERO)
  manager.banks[0].actions = [{"object_id": "route", "action": action}]
  manager.by_id.floor_blue.active = true
  manager.by_id.floor_red.active = true
  manager._activate_switch(manager.by_id.wall_green)
  await frames(2)
  check(item.state == ("a" if action == "set_a" else "b"), "Switch bank diverter action: " + action)
 manager.banks[0].actions = original_actions
 for state: String in ["a", "b"]:
  item.state = state
  item.pending_state = ""
  var normal := Objects.diverter_forward(item, state)
  await move_in_run(item.position + normal * 40.0, -normal * 1200.0)
  await frames(5)
  check(game.ball.linear_velocity.dot(normal) > 0.0, "Diverter state collides and redirects: " + state)
 await move_in_run(item.position, Vector2.ZERO)
 var original: Vector2 = game.ball.position
 manager.request_diverter(item, "set_a")
 await frames(2)
 check(item.state == "b" and item.pending_state == "a" and game.ball.position.distance_to(original) < 2.0 and game.ball.linear_velocity.length() < 100.0, "Overlapping ball delays transition without teleport or launch")
 await move_in_run(Vector2(500, 700), Vector2.ZERO)
 await frames(2)
 check(item.state == "a" and item.pending_state == "", "Pending state applies once full rotation sweep is clear")
 manager.request_diverter(item, "set_b")
 manager._advance_diverters(item.position + Vector2(-150, 0), Vector2(300, 0))
 check(item.state == "a" and item.pending_state == "b", "Incoming high-speed sweep also delays state change")
 manager.reset()
 check(item.state == item.properties.initial_state, "Reset restores authored diverter state")

func _dash_shots() -> void:
 var item: Dictionary = manager.by_id.dash
 item.rotation_degrees = 0.0
 item.properties.boost_strength = 400.0
 item.properties.directional_influence = 70.0
 await move_in_run(Vector2(120, 320), Vector2(0, -900))
 for i in 20:
  if item.launch_count > 0: break
  await frames(1)
 check(item.launch_count == 1 and game.ball.linear_velocity.length() > 1100.0 and not game.ball.on_ramp, "Dash accelerates real ball without capture")
 check(traversal_events.back() == [&"dash_panel", "dash", &"used"], "Actual dash entry emits typed traversal with stable identity")
 for i in 30: await move_in_run(item.position, Vector2.ZERO)
 check(item.launch_count == 1, "Continuous overlap cannot retrigger after cooldown")
 await move_in_run(Vector2(120, 350), Vector2.ZERO)
 await frames(25)
 await move_in_run(Vector2(120, 320), Vector2(0, -2200))
 await frames(5)
 check(item.launch_count == 2 and game.ball.linear_velocity.length() <= 2401.0, "Full departure rearms high-speed dash and respects cap")
 manager.reset()
 await move_in_run(Vector2(120, 380), Vector2(0, -16000))
 await frames(4)
 check(item.launch_count == 1 and game.ball.linear_velocity.length() <= 2401.0, "Single-step high-speed traversal cannot skip dash")
 check(game.ball.get_instance_id() == identities.ball, "Dash uses same ball instance")

func _theme_checks() -> void:
 var states := [manager.by_id.route.state, manager.by_id.wall_green.active, manager.by_id.lanes.completions]
 for theme: String in Models.STYLES:
  check(game.set_theme(theme), "Batch visuals build in theme: " + theme)
  await frames(2)
  check(states == [manager.by_id.route.state, manager.by_id.wall_green.active, manager.by_id.lanes.completions] and visuals().gimmicks.size() == 7, "Theme retains mechanic state and all visual entries: " + theme)

func _sandbox_route() -> void:
 # Instrumented real-ball shots verify objectives; no scripted player controls.
 await move_in_run(Vector2(300, 700), Vector2(0, -1400))
 await frames(12)
 check(game.ball.position.y > 640 and game.ball.linear_velocity.y > 0, "Sandbox initial diverter returns an upward shot to lower court")
 await move_in_run(Vector2(90, 740), Vector2(-1200, 0))
 await frames(6)
 for x in [170, 330]:
  await move_in_run(Vector2(x, 790), Vector2(1200, 0))
  await frames(7)
 check(manager.banks[0].complete and manager.by_id.route.state == "b", "Sandbox bank contacts change routing machinery")
 await move_in_run(Vector2(300, 700), Vector2(0, -1400))
 await frames(10)
 check(game.ball.position.x < 260 and game.ball.linear_velocity.y < 0, "Sandbox changed diverter redirects the same shot toward upper lanes")
 for x in [120, 200, 280]:
  await move_in_run(Vector2(x, 490), Vector2(0, -2000))
  await frames(8)
 check(manager.by_id.lanes.completions == 1, "Sandbox real shots complete passing lane set")
 await move_in_run(Vector2(120, 320), Vector2(0, -900))
 await frames(15)
 check(manager.by_id.dash.launch_count > 0 and game.ball.position.y < 200, "Sandbox dash speeds ball through authored long lane")
 if DisplayServer.get_name() != "headless":
  game.reset_ball(false)
  game.set_theme("green_hill")
  await frames(4)
  game.presentation.set_camera_follow(false)
  game.presentation.set_camera_preset(TablePresentation.CameraPreset.TOP_DOWN)
  game.retro_filter.set_preset(0)
  await frames(5)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/gimmick-batch-main.png")
