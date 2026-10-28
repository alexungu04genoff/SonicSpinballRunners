extends "res://tests/authored_main_game_regression.gd"
## Real shared-engine trajectories plus persistence and presentation invariants.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const Contact = preload("res://scripts/authored_act/gimmick_geometry.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const Models = preload("res://scripts/authored_act/gimmick_models.gd")
const EXAMPLE := "res://data/acts/switch_gate_spring.tres"
const RUN_PATH := "res://test-results/gimmick-run.tres"
var manager: Node

func frames(count := 3) -> void:
 for i in count: await physics_frame

func object(type: String, id: String, at: Vector2, properties := {}, angle := 0.0) -> Dictionary:
 var item := Objects.make_placement(type)
 item.object_id = id
 item.position = at
 item.rotation_degrees = angle
 item.properties.merge(properties, true)
 return item

func fixture() -> Resource:
 var act := ActData.new()
 act.title = "Switch Court — Open the Sky Lane"
 act.grid_size = Vector2i(12, 16)
 act.spawn_position = Vector2(300, 710)
 act.exit_start_x = 5
 act.exit_width = 2
 act.activation_y = 270.0
 act.gameplay_objects = [
  object("switch_target", "blue", Vector2(220, 520), {"color": "blue", "label": "1", "score_reward": 25.0}),
  object("switch_target", "red", Vector2(300, 520), {"color": "red", "label": "2", "score_reward": 25.0}),
  object("switch_target", "green", Vector2(380, 520), {"color": "green", "label": "3", "score_reward": 25.0}),
  object("one_way_gate", "sky_gate", Vector2(300, 350), {"width": 100.0}, 180.0),
  object("spring", "sky_spring", Vector2(300, 295), {"launch_strength": 550.0}),
  object("round_bumper", "small", Vector2(160, 610), {"scale": 0.5}),
  object("round_bumper", "large", Vector2(440, 600), {"scale": 1.8}),
  object("triangle_bumper", "sling", Vector2(150, 640), {"scale": 0.7}, -30.0),
  object("left_flipper", "left", Vector2(260, 735), {}, rad_to_deg(0.32)),
  object("right_flipper", "right", Vector2(340, 735), {}, rad_to_deg(PI - 0.32)),
 ]
 act.switch_banks = [{"bank_id": "sky_bank", "label": "Open the Sky Lane", "members": ["blue", "red", "green"], "gates": ["sky_gate"]}]
 for region: Rect2i in [Rect2i(0, 7, 5, 1), Rect2i(7, 7, 5, 1)]:
  act.placements.append({"shape_id": "composite", "base_size": region.size, "anchor": region.position, "quarter_turns": 0, "flip_h": false, "flip_v": false,
   "composite_version": 1, "smoothing_strength": 0.0, "outline": PackedVector2Array([Vector2.ZERO, Vector2(5, 0), Vector2(5, 0.2), Vector2(0, 0.2)])})
 # Authored side walls and return slopes form an actual chamber with a drain gap.
 for x in [0, 11]:
  act.placements.append({"shape_id": "composite", "base_size": Vector2i(1, 16), "anchor": Vector2i(x, 0), "quarter_turns": 0, "flip_h": false, "flip_v": false,
   "composite_version": 1, "smoothing_strength": 0.0, "outline": PackedVector2Array([Vector2(0.4, 0), Vector2(0.6, 0), Vector2(0.6, 16), Vector2(0.4, 16)])})
 for x in [0, 7]:
  act.placements.append({"shape_id": "composite", "base_size": Vector2i(5, 3), "anchor": Vector2i(x, 13), "quarter_turns": 0, "flip_h": x == 7, "flip_v": false,
   "composite_version": 1, "smoothing_strength": 0.0, "outline": PackedVector2Array([Vector2(0.4, 0), Vector2(5, 1.65), Vector2(5, 2.2), Vector2(0.4, 3)])})
 for x in [0, 7]:
  act.placements.append({"shape_id": "composite", "base_size": Vector2i(5, 1), "anchor": Vector2i(x, 0), "quarter_turns": 0, "flip_h": false, "flip_v": false,
   "composite_version": 1, "smoothing_strength": 0.0, "outline": PackedVector2Array([Vector2.ZERO, Vector2(5, 0), Vector2(5, 0.2), Vector2(0, 0.2)])})
 act.ring_trails = [
  {"kind": "ellipse", "start": Vector2(210, 90), "end": Vector2(390, 230), "spacing": 30.0, "rotation_degrees": 0.0, "fill": true},
  {"kind": "ellipse", "start": Vector2(150, 450), "end": Vector2(450, 600), "spacing": 35.0, "rotation_degrees": 0.0, "fill": false},
 ]
 # Preserve the shipped pre-scaling fixture: omitted target scale resolves to 1.0.
 for item: Dictionary in act.gameplay_objects:
  if item.type == "switch_target": item.properties.erase("scale")
 return act

func isolated_fixture() -> Resource:
 var act := ActData.new()
 act.title = "Gimmick regression"
 act.grid_size = Vector2i(20, 20)
 act.spawn_position = Vector2(500, 900)
 act.gameplay_objects = [
  object("one_way_gate", "gate", Vector2(500, 400), {"width": 200.0}),
  object("one_way_gate", "open_gate", Vector2(800, 400), {"width": 120.0, "initial_state": "open"}),
  object("switch_target", "s1", Vector2(300, 600), {"color": "yellow", "score_reward": 25.0}),
  object("switch_target", "s2", Vector2(450, 600), {"color": "red", "score_reward": 25.0}),
  object("spring", "spring", Vector2(700, 650), {"launch_strength": 850.123456789, "color": "blue"}, 27.123456789),
 ]
 for i in 3:
  var scale_value: float = [0.35, 1.0, 2.5][i]
  act.gameplay_objects.append(object("round_bumper", "round_%d" % i, Vector2(100 + 140 * i, 150), {"scale": scale_value}))
  act.gameplay_objects.append(object("triangle_bumper", "triangle_%d" % i, Vector2(100 + 140 * i, 800), {"scale": scale_value}))
 act.switch_banks = [{"bank_id": "bank", "label": "Test bank", "members": ["s1", "s2"], "gates": ["gate", "open_gate"]}]
 return act

func move_in_run(point: Vector2, velocity: Vector2) -> void:
 # Instrumented shot placement preserves the run state under test.
 game.ball._teleport_position = point
 game.ball._teleport_velocity = velocity
 game.ball._teleport_pending = true
 game.ball.serve_pending = false
 game.ball.release_pending = false
 await frames(2)

func visuals() -> Node:
 return game.presentation.get_node("AuthoredPinballVisuals")

func run() -> void:
 root.size = Vector2i(1280, 900)
 root.gui_embed_subwindows = true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 if "--write-example" in OS.get_cmdline_user_args():
  var example := fixture()
  print(example.validation_errors())
  quit(0 if example.save_document(EXAMPLE) == OK else 1)
  return
 if "--reopen" in OS.get_cmdline_user_args():
  var loaded := ActData.load_document(RUN_PATH)
  quit(0 if loaded.document != null and loaded.document.fingerprint() == OS.get_cmdline_user_args()[-1] else 1)
  return
 var act := isolated_fixture()
 check(act.validation_errors().is_empty(), "New object and bank schema validates", str(act.validation_errors()))
 check(act.save_document(RUN_PATH) == OK, "New objects save through ordinary Act persistence")
 var loaded := ActData.load_document(RUN_PATH)
 check(loaded.document != null and loaded.document.fingerprint() == act.fingerprint(), "Exact angle, strength, color, IDs and multi-gate links survive save/load")
 var output: Array = []
 var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/authored_gimmick_regression.gd", "--", "--reopen", act.fingerprint()], output, true)
 check(code == 0, "New properties survive a fresh Godot process")
 for fixture_path: String in ["res://tests/fixtures/act_format_2.tres", "res://tests/fixtures/act_format_3.tres", "res://data/acts/pinball_mechanics_sandbox.tres"]:
  check(ActData.load_document(fixture_path).document != null, "Legacy format loads: " + fixture_path)
 var old_act := ActData.new()
 old_act.format_version = 12
 old_act.gameplay_objects = [{"type": "round_bumper", "position": Vector2(120, 200), "rotation_degrees": 0.0}]
 var old_path := "res://test-results/gimmick-legacy-12.tres"
 ResourceSaver.save(old_act, old_path)
 var old_loaded := ActData.load_document(old_path)
 check(old_loaded.document != null and old_loaded.document.format_version == ActData.FORMAT_VERSION and old_loaded.document.switch_banks.is_empty(), "Format 12 migrates with empty banks")
 check(Objects.properties(old_loaded.document.gameplay_objects[0]).scale == 1.0 and FileAccess.get_file_as_string(old_path).contains("format_version = 12"), "Legacy bumper defaults to unit scale without rewriting the source")
 old_act.gameplay_objects.append(object("spring", "unsupported", Vector2(200, 200)))
 ResourceSaver.save(old_act, old_path)
 check(ActData.load_document(old_path).document == null, "Old format cannot silently contain new gimmicks")
 old_act.gameplay_objects.pop_back()
 old_act.ring_trails = [{"kind": "ellipse", "start": Vector2.ZERO, "end": Vector2(100, 100), "spacing": 20.0, "fill": false, "rotation_degrees": 0.0}]
 ResourceSaver.save(old_act, old_path)
 check(ActData.load_document(old_path).document == null, "Old format cannot silently contain ring ellipses")
 var bad: Resource = act.copy_document()
 bad.switch_banks[0].gates.append("missing")
 check(not bad.validation_errors().is_empty(), "Missing gate link is rejected")
 bad = act.copy_document()
 bad.switch_banks[0].members = ["gate"]
 check(not bad.validation_errors().is_empty(), "Wrong-type bank member is rejected")
 _ring_checks()
 _scale_checks()
 game = ObservedGame.new()
 game.authored_act_path = RUN_PATH
 root.add_child(game)
 await frames(6)
 check(game.playfield.source == "authored", "Main game loads new authored mechanics", game.last_source_error)
 if game.playfield.source != "authored": game.free(); quit(1); return
 identities = engine_ids()
 manager = game.ball.mechanics
 game.controls.virtual_enabled = true
 game.tuning.set_value("max_downward_speed", 3000.0)
 game.ring_field.set_physics_process(false)
 await _bumper_contacts()
 # Allowed upward pass, then opposite downward contact at high speed.
 await move_in_run(Vector2(500, 440), Vector2(0, -2200))
 await frames(6)
 check(game.ball.position.y < 390 and game.ball.linear_velocity.y < 0, "Allowed direction crosses a closed gate at speed", str(game.ball.position))
 manager.reset()
 await move_in_run(Vector2(500, 350), Vector2(0, 2200))
 await frames(5)
 check(game.ball.position.y < 400 and game.ball.linear_velocity.y < 0, "Blocked direction rebounds at speed", str([game.ball.position, game.ball.linear_velocity]))
 manager.reset()
 await move_in_run(Vector2(460, 370), Vector2(1100, 1500))
 await frames(5)
 check(game.ball.position.y < 400 and game.ball.linear_velocity.y < 0 and game.ball.linear_velocity.x > 1000, "Oblique gate contact preserves tangential motion")
 manager.reset()
 manager.by_id.gate.rotation_degrees = 90.0
 await move_in_run(Vector2(540, 400), Vector2(-1800, 0))
 await frames(5)
 check(game.ball.position.x > 500 and game.ball.linear_velocity.x > 0, "Rotated gate blocks in its local direction")
 manager.by_id.gate.rotation_degrees = 0.0
 await move_in_run(Vector2(800, 360), Vector2(0, 1200))
 await frames(7)
 check(game.ball.position.y > 430 and manager.by_id.open_gate.open, "Initially open gate permits opposite-direction passage")
 manager.reset()
 await move_in_run(Vector2(250, 600), Vector2(700, 0))
 await frames(8)
 check(manager.by_id.s1.active and not manager.by_id.s2.active and not manager.by_id.gate.open, "Real ball hit presses one switch; incomplete bank stays closed")
 var score_after_first: int = game.score
 await move_in_run(Vector2(300, 600), Vector2.ZERO)
 await frames(4)
 check(manager.by_id.s1.active and game.score == score_after_first, "Pressed switch persists and cannot award duplicate score")
 var switch_visual: Dictionary = visuals().gimmicks.filter(func(entry): return entry.item.object_id == "s1")[0]
 Models.update(switch_visual)
 check(switch_visual.pad.position.y < 0.06 and switch_visual.material.emission_energy_multiplier > 0 and switch_visual.material.emission == Objects.COLORS.yellow, "Pressed pad depresses and emits its assigned color")
 await move_in_run(Vector2(410, 600), Vector2(700, 0))
 await frames(8)
 check(manager.by_id.s2.active and manager.banks[0].complete and manager.by_id.gate.open and manager.by_id.open_gate.open, "All switches complete bank and open multiple gates")
 await move_in_run(Vector2(500, 360), Vector2(0, 1200))
 await frames(7)
 check(game.ball.position.y > 430, "Bank-opened gate permits formerly blocked passage")
 # Reskin the live activated run; behavior/state and authoritative ball must persist.
 var theme_styles: Dictionary = {}
 for theme_id: String in Models.STYLES:
  check(game.set_theme(theme_id), "Theme loads with gimmicks: " + theme_id)
  await frames(2)
  var gate_visual: Dictionary = visuals().gimmicks.filter(func(entry): return entry.item.object_id == "gate")[0]
  Models.update(gate_visual)
  theme_styles[gate_visual.root.get_meta("gate_style")] = true
  check(not gate_visual.panel.visible and manager.by_id.s1.active and game.ball.get_instance_id() == identities.ball, "Reskin retains pressed/open state and authoritative ball: " + theme_id)
 check(theme_styles.size() == 8, "Eight distinct gate presentations share one physics path")
 manager.reset()
 check(not manager.by_id.s1.active and not manager.by_id.gate.open and manager.by_id.open_gate.open and not manager.banks[0].complete, "Reset restores switch, bank and authored gate initial states")
 # Launch strength and angle checked at the first integration that reports a hit.
 var spring: Dictionary = manager.by_id.spring
 var spring_events: Array = []
 manager.traversal_event.connect(func(kind, id, phase): spring_events.append([kind, id, phase]))
 var direction := Objects.forward(spring)
 await move_in_run(spring.position + direction * 35.0, -direction * 800.0)
 for i in 20:
  if spring.launch_count > 0: break
  await frames(1)
 check(spring.launch_count == 1 and game.ball.linear_velocity.normalized().dot(direction) > 0.999, "Spring responds immediately with its authored angle")
 check(spring_events == [[&"spring", "spring", &"used"]], "Actual spring launch emits one typed traversal event with stable identity")
 check(absf(game.ball.linear_velocity.length() - float(spring.properties.launch_strength)) < 4.0 and not game.ball.on_ramp, "Spring uses exact launch strength with no capture state", str(game.ball.linear_velocity))
 var original_cooldown: float = spring.cooldown
 paused = true
 var frozen := [game.ball.position, game.ball.linear_velocity, spring.cooldown, spring.pulse]
 await frames(8)
 check(frozen == [game.ball.position, game.ball.linear_velocity, spring.cooldown, spring.pulse], "Pause freezes spring cooldown and ball trajectory")
 paused = false
 # Hold the actual ball inside the pad longer than its cooldown. Contact latch,
 # not the timer alone, must prevent repeated launches.
 for i in 25:
  await move_in_run(spring.position, Vector2.ZERO)
 check(spring.launch_count == 1 and original_cooldown > 0.0, "Continuous overlap cannot retrigger after cooldown expires")
 await move_in_run(spring.position + direction * 60.0, Vector2.ZERO)
 await frames(16)
 await move_in_run(spring.position + direction * 30.0, -direction * 800.0)
 await frames(4)
 check(spring.launch_count == 2, "Leaving and returning rearms spring")
 manager.reset()
 spring.rotation_degrees = 0.0
 spring.properties.launch_strength = 500.0
 await move_in_run(spring.position + Vector2(0, -30), Vector2(0, 600))
 for i in 15:
  if spring.launch_count > 0: break
  await frames(1)
 var start: Vector2 = game.ball.position
 var velocity: Vector2 = game.ball.linear_velocity
 await frames(30)
 var t := 30.0 / Engine.physics_ticks_per_second
 var expected := start + velocity * t + Vector2.DOWN * 700.0 * float(game.tuning.effective.gravity_scale) * t * t * 0.5
 check(game.ball.position.distance_to(expected) < 6.0, "Ballistic editor arc agrees with free-flight spring motion", str([game.ball.position, expected]))
 var preview := Objects.spring_trajectory(spring, game.tuning.effective.gravity_scale)
 check(absf((preview[10].y - preview[0].y) - (-500.0 * 0.25 + 0.5 * 700 * game.tuning.effective.gravity_scale * 0.25 * 0.25)) < 0.001, "Preview uses selected profile gravity and authored launch strength")
 await move_in_run(Vector2(500, 1080), Vector2(0, 500))
 await frames(80)
 check(game.ball.serve_pending and spring.launch_count == 0 and not manager.by_id.s1.active, "Drain clears latch, switch and bank state through shared reset")
 await game.reload_authored_act()
 await frames(4)
 manager = game.ball.mechanics
 check(manager.by_id.spring.launch_count == 0 and manager.by_id.spring.rotation_degrees == act.gameplay_objects[4].rotation_degrees and manager.by_id.open_gate.open, "Reload restores saved spring settings and authored states without a picker")
 var stable_root: Node = game._authored_root
 var saved := FileAccess.get_file_as_bytes(RUN_PATH)
 var file := FileAccess.open(RUN_PATH, FileAccess.WRITE)
 file.store_string("invalid Act")
 file.close()
 print("EXPECTED INVALID RELOAD | malformed resource errors follow")
 await game.reload_authored_act()
 await frames(3)
 check(game._authored_root == stable_root and game.ball.mechanics == manager and not game.act_picker.visible and not game.last_source_error.is_empty(), "Failed reload preserves the current playable Act")
 file = FileAccess.open(RUN_PATH, FileAccess.WRITE)
 file.store_buffer(saved)
 file.close()
 await _demo_checks()
 game.free()
 await frames(2)
 print("RESULT | Authored gimmicks | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func _ring_checks() -> void:
 var ellipse := {"kind": "ellipse", "start": Vector2(-100, -100), "end": Vector2(100, 100), "spacing": 25.0, "fill": false, "rotation_degrees": 0.0}
 var circle := Rings.positions(ellipse)
 check(circle.size() == 26 and Array(circle).all(func(point): return absf(point.length() - 100.0) < 0.01), "Circle perimeter has evenly distributed rings")
 ellipse.end = Vector2(200, 100)
 ellipse.rotation_degrees = 37.123456789
 var positions := Rings.positions(ellipse)
 var center: Vector2 = (ellipse.start + ellipse.end) * 0.5
 check(Array(positions).all(func(point): return absf(((point - center).rotated(-deg_to_rad(ellipse.rotation_degrees)) / Vector2(150, 100)).length() - 1.0) < 0.001), "Rotated ellipse perimeter follows its radii")
 ellipse.fill = true
 positions = Rings.positions(ellipse)
 check(positions.has(center) and positions.size() > 30 and Array(positions).all(func(point): return ((point - center).rotated(-deg_to_rad(ellipse.rotation_degrees)) / Vector2(150, 100)).length() <= 1.0001), "Filled ellipse uses a clipped interior hex distribution")
 check(Rings.positions(ellipse) == positions, "Ring pattern is deterministic")
 var document := ActData.new()
 document.ring_trails = [ellipse]
 var path := "res://test-results/gimmick-rings.tres"
 check(document.save_document(path) == OK and ActData.load_document(path).document.fingerprint() == document.fingerprint(), "Ellipse authoring data preserves exact rotation, fill and positions")
 ellipse.spacing = 0.000001
 check(not Rings.validation_error(ellipse).is_empty(), "Excessive ring patterns are bounded before generation")

func _scale_checks() -> void:
 var ball := PlaygroundBall.new()
 var tuning := PhysicsTuning.new()
 var controls := PlaygroundInput.new()
 for scale_value: float in [0.35, 1.0, 2.5]:
  var document := ActData.new()
  document.spawn_position = Vector2(300, 500)
  document.gameplay_objects = [object("round_bumper", "round", Vector2(200, 200), {"scale": scale_value}), object("triangle_bumper", "triangle", Vector2(400, 200), {"scale": scale_value})]
  var compiled := Compiler.compile(document, tuning, controls, ball)
  check(compiled.error.is_empty(), "Small/default/large bumper compiles: " + str(scale_value))
  var circle: CircleShape2D = compiled.objects[0].body.get_child(0).shape
  var points: PackedVector2Array = compiled.objects[1].body.get_child(0).polygon
  check(is_equal_approx(circle.radius, 12.5 * scale_value) and points == Objects.local_points(document.gameplay_objects[1], 50.0), "Collider dimensions match editor silhouettes at scale " + str(scale_value))
  check(compiled.objects[0].radius == circle.radius and compiled.objects[1].points == points, "Presentation descriptors share exact scaled collision dimensions")
  var path := "res://test-results/gimmick-scale.tres"
  check(document.save_document(path) == OK and ActData.load_document(path).document.fingerprint() == document.fingerprint(), "Bumper scale persists: " + str(scale_value))
  compiled.root.free()
 var bad := object("round_bumper", "bad", Vector2.ZERO, {"scale": 0.0})
 check(not Objects.property_errors(bad).is_empty(), "Zero scale rejected")
 bad.properties.scale = 1000.0
 check(not Objects.property_errors(bad).is_empty(), "Absurd scale rejected")
 ball.free()
 tuning.free()
 controls.free()

func _demo_checks() -> void:
 var loaded := ActData.load_document(EXAMPLE)
 check(loaded.document != null and loaded.document.fingerprint() == fixture().fingerprint(), "Shipped mechanic Act matches verified example")
 await game.request_authored_act(EXAMPLE)
 await await_rebuild()
 manager = game.ball.mechanics
 game.ring_field.set_physics_process(true)
 # A controlled sequence of real ball shots exercises the complete objective.
 await move_in_run(Vector2(300, 400), Vector2(0, -700))
 await frames(12)
 check(game.ball.position.y > 350 and not manager.by_id.sky_gate.open, "Demo upper lane is blocked before the objective")
 await move_in_run(Vector2(175, 520), Vector2(900, 0))
 await frames(30)
 check(manager.by_id.blue.active and manager.by_id.red.active and manager.by_id.green.active and manager.by_id.sky_gate.open, "Demo switch shot completes bank and opens upper lane")
 await move_in_run(Vector2(300, 400), Vector2(0, -650))
 var reached := false
 for i in 150:
  await frames(1)
  if game.authored_exit_count > 0:
   reached = true
   break
 check(manager.by_id.sky_spring.launch_count == 1 and reached, "Open route leads through immediate spring launch to the physical Act exit")
 check(game.ring_field.rings.any(func(ring): return not ring.active), "Spring shot collects rings from the authored bonus pool")
 if DisplayServer.get_name() != "headless":
  game.reset_ball(false)
  game.ring_field.reset_rings()
  game.set_theme("green_hill")
  await frames(4)
  game.presentation.set_camera_follow(false)
  game.presentation.set_camera_preset(TablePresentation.CameraPreset.TOP_DOWN)
  game.retro_filter.set_preset(0)
  await frames(5)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/gimmick-main-game.png")

func _bumper_contacts() -> void:
 for descriptor: Dictionary in game.authored_runtime.objects:
  if descriptor.type not in ["round_bumper", "triangle_bumper"]: continue
  var before: int = game.ball.bumper_hit_count
  var start: Vector2 = descriptor.position + Vector2(-90, 0) if descriptor.type == "round_bumper" else descriptor.position + Vector2(0, -100)
  var velocity := Vector2(1700, 0) if descriptor.type == "round_bumper" else Vector2(0, 1700)
  await move_in_run(start, velocity)
  await frames(18)
  check(game.ball.bumper_hit_count > before and game.ball.position.is_finite() and game.ball.linear_velocity.is_finite(), "Real swept bumper contact remains stable: " + descriptor.object_id)
  var visual: Node3D = game.presentation.bumper_visuals[descriptor.body.get_instance_id()]
  var bounds := AABB()
  var first := true
  for child: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
   var local_bounds: AABB = child.transform * child.get_aabb()
   bounds = local_bounds if first else bounds.merge(local_bounds)
   first = false
  if descriptor.type == "round_bumper":
   check(absf(bounds.size.x - descriptor.radius * 0.02) < 0.0001 and absf(bounds.size.z - descriptor.radius * 0.02) < 0.0001, "Rendered round footprint equals collider diameter: " + descriptor.object_id)
  else:
   var outline := Rect2(descriptor.points[0], Vector2.ZERO)
   for point: Vector2 in descriptor.points: outline = outline.expand(point)
   check(absf(bounds.size.x - outline.size.x * 0.01) < 0.0001 and absf(bounds.size.z - outline.size.y * 0.01) < 0.0001, "Rendered sling footprint equals collider polygon: " + descriptor.object_id)
