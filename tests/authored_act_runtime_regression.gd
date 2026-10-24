extends SceneTree
## Compiler topology, exact transforms, source immutability and loader lifecycle.
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const SOURCE_PATH := "res://test-results/authored-act-runtime-source.tres"
const AUTOMATIC_PATH := "res://test-results/authored-act-automatic-source.tres"
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String, detail := "") -> void:
	checks += 1
	if condition:
		print("PASS | " + label)
	else:
		failures += 1
		push_error("FAIL | " + label + " | " + detail)


func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame


func stamp(id: String, anchor := Vector2i(2, 2), turns := 0, horizontal := false, vertical := false) -> Dictionary:
	return {"shape_id": id, "base_size": Shapes.get_definition(id).size, "anchor": anchor,
		"quarter_turns": turns, "flip_h": horizontal, "flip_v": vertical}


func new_document() -> Resource:
	var document := ActData.new()
	document.spawn_position = Vector2(300.5, 555.25)
	document.activation_y = 450.125
	document.entry_start_x = 7
	document.entry_width = 2
	document.exit_start_x = 1
	document.exit_width = 3
	return document


func environment() -> Dictionary:
	var world := Node2D.new()
	root.add_child(world)
	var tuning := PhysicsTuning.new()
	world.add_child(tuning)
	var controls := PlaygroundInput.new()
	controls.virtual_enabled = true
	world.add_child(controls)
	var ball := PlaygroundBall.new()
	ball.tuning = tuning
	ball.controls = controls
	ball.position = Vector2(5000, 5000)
	world.add_child(ball)
	ball.teleport_to(Vector2(5000, 5000), Vector2.ZERO, true)
	return {"world": world, "tuning": tuning, "controls": controls, "ball": ball}


func expected_points(placement: Dictionary, cell_size: float) -> PackedVector2Array:
	var definition: Dictionary = Shapes.get_definition(placement.shape_id)
	var w := float(definition.size.x)
	var h := float(definition.size.y)
	var result := PackedVector2Array()
	for source: Vector2 in definition.points:
		var point := source
		match placement.quarter_turns:
			1: point = Vector2(h - source.y, source.x)
			2: point = Vector2(w - source.x, h - source.y)
			3: point = Vector2(source.y, w - source.x)
		var frame := Vector2(w, h) if placement.quarter_turns % 2 == 0 else Vector2(h, w)
		if placement.flip_h: point.x = frame.x - point.x
		if placement.flip_v: point.y = frame.y - point.y
		result.append((point + Vector2(placement.anchor)) * cell_size)
	return result


func same_points(actual: PackedVector2Array, expected: PackedVector2Array) -> bool:
	if actual.size() != expected.size(): return false
	for index in actual.size():
		if actual[index].distance_to(expected[index]) > 0.00008: return false
	return true


func check_compilation() -> void:
	var env := environment()
	var document := new_document()
	document.cell_size = 47.5
	# The spawn stays inside the reduced physical bounds.
	document.spawn_position = Vector2(300.5, 540.25)
	for definition: Dictionary in Shapes.definitions():
		document.placements.append(stamp(definition.id))
	for turns in 4:
		for mirrors in 4:
			document.placements.append(stamp("slope_2x3", Vector2i(7, 6), turns, bool(mirrors & 1), bool(mirrors & 2)))
	var original: String = document.fingerprint()
	var result := Compiler.compile(document, env.tuning, env.controls, env.ball)
	check(result.error.is_empty() and result.root != null, "All canonical stamps and asymmetric transforms compile", result.error)
	if result.root != null:
		check(result.root.get_parent() == null and result.terrain.size() == document.placements.size(), "Compiler returns an unattached root and preserves all independent overlapping placements")
		for index in result.terrain.size():
			var record: Dictionary = result.terrain[index]
			var placement: Dictionary = document.placements[index]
			var expected := expected_points(placement, document.cell_size)
			var definition: Dictionary = Shapes.get_definition(placement.shape_id)
			var topology_ok: bool = record.closed == definition.closed and same_points(record.points, expected)
			if definition.closed:
				topology_ok = topology_ok and record.collision is CollisionPolygon2D and record.collision.build_mode == CollisionPolygon2D.BUILD_SOLIDS and same_points(record.collision.polygon, expected)
			else:
				var segments := PackedVector2Array()
				for point_index in range(expected.size() - 1):
					segments.append(expected[point_index])
					segments.append(expected[point_index + 1])
				topology_ok = topology_ok and record.collision is CollisionShape2D and record.collision.shape is ConcavePolygonShape2D and same_points(record.collision.shape.segments, segments)
			check(topology_ok, "Authoritative silhouette/topology: %s turn%d H%s V%s" % [placement.shape_id, placement.quarter_turns, placement.flip_h, placement.flip_v])
		check(result.timings.terrain_ms >= 0 and result.timings.objects_ms >= 0 and result.timings.total_ms >= result.timings.terrain_ms, "Compiler exposes separate terrain and object timing measurements")
		result.root.free()
	check(document.fingerprint() == original, "Compiling transforms and overlaps never mutates the authoring Resource")
	var incomplete := ActData.new()
	var rejected := Compiler.compile(incomplete, env.tuning, env.controls, env.ball)
	check(rejected.root == null and rejected.error.to_lower().contains("spawn"), "Playable compilation clearly rejects a draft without Spawn")
	env.world.free()
	await frames(2)


func check_object_mapping() -> void:
	var env := environment()
	var document := new_document()
	document.gameplay_objects = [
		{"type": "round_bumper", "position": Vector2(130.5, 150.25), "rotation_degrees": 32.0},
		{"type": "triangle_bumper", "position": Vector2(430.5, 150.25), "rotation_degrees": 12.3456789},
		{"type": "left_flipper", "position": Vector2(140.5, 500.25), "rotation_degrees": -23.125},
		{"type": "right_flipper", "position": Vector2(450.5, 500.25), "rotation_degrees": 205.5},
	]
	var original: String = document.fingerprint()
	var result := Compiler.compile(document, env.tuning, env.controls, env.ball)
	check(result.error.is_empty() and result.objects.size() == 4 and result.flippers.size() == 2, "Four gameplay records compile into the real bumper and flipper implementations", result.error)
	if result.root == null:
		env.world.free()
		return
	env.world.add_child(result.root)
	await frames(3)
	for index in result.objects.size():
		var object: Dictionary = result.objects[index]
		var authored: Dictionary = document.gameplay_objects[index]
		check(object.position == authored.position and object.rotation_degrees == authored.rotation_degrees and object.body.position == authored.position and absf(object.body.rotation - deg_to_rad(authored.rotation_degrees)) < 0.000001, "Exact metadata and engine transforms preserve %s anchor and rest orientation" % authored.type)
	check(result.objects[0].body.has_meta("bumper") and result.objects[0].body.get_child(0).shape is CircleShape2D and result.objects[0].body.get_child(0).shape.radius == 38.0, "Round bumper uses the real 38-pixel collider rather than the compact editor preview")
	check(result.objects[1].body.has_meta("bumper") and result.objects[1].body.get_child(0).polygon == PackedVector2Array([Vector2(-40, 35), Vector2(-15, -55), Vector2(45, 35)]), "Sling collider preserves the runtime polygon around its authored origin")
	for index in result.flippers.size():
		var paddle: PlaygroundFlipper = result.flippers[index]
		var authored: Dictionary = document.gameplay_objects[index + 2]
		check(paddle is PlaygroundFlipper and paddle.length == 130.0 and paddle.get_child(0).shape is CapsuleShape2D and paddle.get_child(0).shape.radius == 13.0 and absf(paddle.active_angle() - paddle.rest_angle() + paddle.side * 0.8) < 0.000001, "Runtime flipper keeps its physical dimensions and handed swing about the authored pivot")
		check(paddle.position == authored.position and absf(paddle.rest_angle() - deg_to_rad(authored.rotation_degrees)) < 0.00000001, "Authored flipper rest angle overrides the default without moving its pivot")
	env.controls.virtual_left = true
	env.controls.virtual_right = true
	await frames(14)
	check(absf(result.flippers[0].rotation - result.flippers[0].active_angle()) < 0.001 and absf(result.flippers[1].rotation - result.flippers[1].active_angle()) < 0.001, "Both real input channels swing independently oriented authored flippers")
	check(document.fingerprint() == original, "Runtime flipper movement leaves every authored transform unchanged")
	env.world.free()
	await frames(2)


func collect_dependencies(path: String, found: Dictionary) -> void:
	if found.has(path): return
	found[path] = true
	# Godot reports external scene/resource references but omits GDScript preloads.
	if path.ends_with(".gd"):
		var script: Script = load(path)
		for value: Variant in script.get_script_constant_map().values():
			if value is Resource and not value.resource_path.is_empty():
				collect_dependencies(value.resource_path, found)
	for dependency: String in ResourceLoader.get_dependencies(path):
		var target := dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		if target.begins_with("res://"):
			collect_dependencies(target, found)


func collect_node_dependencies(node: Node, found: Dictionary) -> void:
	# Globally registered classes such as PlaygroundBall have no preload constant.
	var script: Script = node.get_script()
	if script != null and not script.resource_path.is_empty():
		collect_dependencies(script.resource_path, found)
	for child: Node in node.get_children():
		collect_node_dependencies(child, found)


func check_runtime_loader() -> void:
	var scene_path := "res://scenes/authored_act_playtest.tscn"
	var scene = load(scene_path)
	check(scene != null, "Standalone authored-Act playtest scene loads")
	if scene == null: return
	var document := new_document()
	document.placements = [stamp("triangle_2x2"), stamp("u_curve_2x2", Vector2i(6, 2))]
	document.gameplay_objects = [{"type": "round_bumper", "position": Vector2(438.5, 271.25), "rotation_degrees": 32.0}]
	check(document.save_document(SOURCE_PATH) == OK, "Runtime fixture saves using the editor's exact format")
	var source_bytes := FileAccess.get_file_as_bytes(SOURCE_PATH)
	var fingerprint: String = document.fingerprint()
	var game: Control = scene.instantiate()
	root.add_child(game)
	await frames(3)
	check(game.load_act(SOURCE_PATH), "Runtime file loader compiles the chosen Act")
	await frames(3)
	game.set_physics_process(false)
	check(game.document.fingerprint() == fingerprint and game.ball is PlaygroundBall and game.ball.position == document.spawn_position and game.ball.serve_pending, "Authoritative ball waits at the exact authored Spawn while all source data remains intact")
	var activations: int = game.activation_count
	var exits: int = game.exit_count
	var drains: int = game.drain_count
	game.process_motion(Vector2(400, 620), Vector2(400, 590))
	check(game.activation_count == activations, "Crossing Entry upward does not activate the Act")
	game.process_motion(Vector2(300, 400), Vector2(300, 500))
	game.process_motion(Vector2(650, 500), Vector2(650, 400))
	check(game.activation_count == activations, "Activation ignores downward and horizontally out-of-bounds crossings")
	game.process_motion(Vector2(300, 500), Vector2(300, 400))
	check(game.activation_count == activations + 1, "Upward full-width activation crossing emits the separate activation event")
	game.process_motion(Vector2(400, 10), Vector2(400, -10))
	game.process_motion(Vector2(100, -10), Vector2(100, 10))
	check(game.exit_count == exits, "Exit rejects upward misses and downward crossings")
	game.process_motion(Vector2(300, 100), Vector2(0, -100))
	check(game.exit_count == exits + 1, "Exit uses interpolated crossing X inside the exact authored span")
	game.process_motion(Vector2(300, 610), Vector2(300, 640))
	check(game.drain_count == drains, "The recovery gutter does not drain at the Entry boundary")
	game.ball.teleport_to(Vector2(400, 645), Vector2(123, 500))
	await frames(2)
	game.process_motion(Vector2(400, 640), Vector2(400, 651))
	await frames(3)
	check(game.drain_count == drains + 1 and game.ball.position == document.spawn_position and game.ball.linear_velocity == Vector2.ZERO and game.ball.serve_pending and game.ball.steering_contribution == 0.0, "Crossing the gutter threshold resets velocity and transient steering at authored Spawn")
	check(game.document.fingerprint() == fingerprint and FileAccess.get_file_as_bytes(SOURCE_PATH) == source_bytes, "Loading, activating, exiting and draining leave both source Resource and source bytes unchanged")
	var dependencies := {}
	collect_dependencies(scene_path, dependencies)
	collect_dependencies("res://scripts/authored_act/act_runtime_compiler.gd", dependencies)
	collect_node_dependencies(game, dependencies)
	# Require known shared dependencies so an empty dependency walk cannot pass.
	var generator_free: bool = dependencies.has("res://scripts/ball.gd") and dependencies.has("res://scripts/act_editor/terrain_shapes.gd")
	for path: String in dependencies:
		generator_free = generator_free and not path.ends_with("zone_generator.gd") and not path.ends_with("table_generator.gd")
	check(generator_free, "Runtime compiler and playtest dependency graph contains shared physics/geometry and no procedural generator", str(dependencies.keys()))
	game.queue_free()
	await frames(3)


func check_automatic_lifecycle() -> void:
	var document := new_document()
	document.spawn_position = Vector2(100, 1)
	document.activation_y = 0.5
	check(document.save_document(AUTOMATIC_PATH) == OK, "Automatic lifecycle fixture saves in the unchanged authoring format")
	var source_bytes := FileAccess.get_file_as_bytes(AUTOMATIC_PATH)
	var game: Control = load("res://scenes/authored_act_playtest.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	check(game.load_act(AUTOMATIC_PATH), "Automatic lifecycle scene loads its own isolated fixture")
	game.controls.virtual_enabled = true
	game.tuning.effective.gravity_scale = 0.0
	await frames(4)
	check(game.ball.serve_pending and game._motion_ready and game._previous_position == document.spawn_position, "Waiting serve arms the swept detector at Spawn for the very first live motion")
	# Supply one initial test impulse through the real ball's launch event. No
	# subsequent position or velocity edits occur during the crossing trajectory.
	game.ball.launched.connect(func(_impulse: Vector2): game.ball.apply_central_impulse(Vector2(0, -600)), CONNECT_ONE_SHOT)
	game.launch_ball()
	await frames(5)
	check(game.ball.position.y < 0 and game.activation_count == 1 and game.exit_count == 1, "The first launched physics motion automatically detects upward Activation and Exit crossings")
	var paused_position: Vector2 = game.ball.position
	var paused_activations: int = game.activation_count
	var paused_exits: int = game.exit_count
	game.toggle_pause()
	await frames(10)
	check(paused and game.ball.position == paused_position and game.activation_count == paused_activations and game.exit_count == paused_exits, "Pause freezes the actual ball and automatic crossing events")
	game.toggle_pause()
	await frames(3)
	check(not paused and game.ball.position.y < paused_position.y, "Resume continues ordinary ball motion without a reset")
	game.ball.teleport_to(Vector2(400, 640), Vector2(0, 900))
	var initial_drains: int = game.drain_count
	for tick in 24:
		await frames(1)
		if game.drain_count > initial_drains:
			break
	await frames(3)
	check(game.drain_count == initial_drains + 1 and game.ball.serve_pending and game.ball.position == document.spawn_position and game.ball.linear_velocity == Vector2.ZERO, "Real physics motion through the gutter automatically drains and returns to exact Spawn")
	check(game.activation_count == paused_activations and game.exit_count == paused_exits, "Drain teleport does not create synthetic Activation or Exit crossings")
	var remaining_delay: float = game._auto_launch
	game.toggle_pause()
	await frames(40)
	check(game.ball.serve_pending and game._auto_launch == remaining_delay and game.drain_count == initial_drains + 1, "Pause also freezes the automatic re-serve delay without repeated drain events")
	game.toggle_pause()
	await frames(40)
	check(not game.ball.serve_pending and game.drain_count == initial_drains + 1 and game.ball.position == document.spawn_position, "After resume the existing serve behavior releases the reset ball once")
	check(game.document.fingerprint() == document.fingerprint() and FileAccess.get_file_as_bytes(AUTOMATIC_PATH) == source_bytes, "Automatic play, pause, drain and re-serve never rewrite source data")
	game.queue_free()
	await frames(3)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	await check_compilation()
	await check_object_mapping()
	await check_runtime_loader()
	await check_automatic_lifecycle()
	print("RESULT | Authored Act runtime | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
