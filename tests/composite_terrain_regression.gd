extends SceneTree
## Explicit terrain sculpting, exact persistence, physical solids and final meshes.
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Composite = preload("res://scripts/act_editor/composite_terrain.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const GreenHill = preload("res://experiments/visual_lab/green_hill_presentation.gd")
const SAVE_PATH := "res://test-results/composite-terrain.tres"
const EXACT_PATH := "res://test-results/composite-terrain-exact.bin"
var checks := 0
var failures := 0
var merged_examples: Array[Dictionary] = []


class ObservedGame:
	extends "res://experiments/visual_lab/visual_lab.gd"
	var generator_calls := 0
	func _generate_layout(seed_value: int, preference: int, grid_mode: int = -1, for_zone: bool = false, difficulty_override: int = -2) -> Dictionary:
		generator_calls += 1
		return super._generate_layout(seed_value, preference, grid_mode, for_zone, difficulty_override)


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


func stamp(id: String, anchor: Vector2i, turns := 0, horizontal := false, vertical := false) -> Dictionary:
	return {"shape_id": id, "base_size": Shapes.get_definition(id).size, "anchor": anchor,
		"quarter_turns": turns, "flip_h": horizontal, "flip_v": vertical}


func global_cells(placement: Dictionary) -> PackedVector2Array:
	var points := Shapes.transformed_points(placement)
	for index in points.size():
		points[index] += Vector2(placement.anchor)
	return points


func exact_placement_bytes(placements: Array) -> PackedByteArray:
	# ResourceSaver may reorder dictionary keys; compare every value's native bits
	# in canonical key order rather than treating insertion order as authoring data.
	var ordered: Array = []
	for placement: Dictionary in placements:
		var keys: Array = placement.keys()
		keys.sort()
		var record: Array = []
		for key in keys:
			record.append([key, placement[key]])
		ordered.append(record)
	return var_to_bytes(ordered)


func polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in points.size():
		area += points[index].cross(points[(index + 1) % points.size()])
	return absf(area) * 0.5


func simple_polygon(points: PackedVector2Array) -> bool:
	if points.size() < 3 or Geometry2D.triangulate_polygon(points).is_empty():
		return false
	for first in points.size():
		var first_end := (first + 1) % points.size()
		if not points[first].is_finite() or points[first].distance_to(points[first_end]) < 0.000001:
			return false
		for second in range(first + 1, points.size()):
			var second_end := (second + 1) % points.size()
			if first_end == second or second_end == first:
				continue
			if Geometry2D.segment_intersects_segment(points[first], points[first_end], points[second], points[second_end]) != null:
				return false
	return true


func coverage_matches(sources: Array, merged: Dictionary) -> bool:
	var outlines: Array[PackedVector2Array] = []
	for source: Dictionary in sources:
		outlines.append(global_cells(source))
	var final := global_cells(merged)
	# Off-grid probes distinguish true curved silhouettes from rectangular frames.
	for x in range(0, 80):
		for y in range(0, 80):
			var point := Vector2((x + 0.317) / 8.0, (y + 0.173) / 8.0)
			var inside := false
			for outline in outlines:
				inside = inside or Geometry2D.is_point_in_polygon(point, outline)
			if inside != Geometry2D.is_point_in_polygon(point, final):
				return false
	return true


func check_merge(sources: Array, label: String) -> Dictionary:
	var before := var_to_bytes(sources)
	var result: Dictionary = Composite.merge(sources)
	check(result.error.is_empty() and not result.placement.is_empty(), label + " produces one composite", result.error)
	check(var_to_bytes(sources) == before, label + " preserves every source while preparing the result")
	if result.placement.is_empty():
		return {}
	var placement: Dictionary = result.placement
	check(placement.shape_id == "composite" and simple_polygon(placement.outline) and Composite.validation_error(placement.outline).is_empty(), label + " has a valid triangulatable final outline")
	check(coverage_matches(sources, placement), label + " preserves actual filled coverage, including curved boundaries")
	merged_examples.append(placement)
	return placement


func check_merge_cases() -> void:
	var left := stamp("triangle_2x2", Vector2i(1, 3), 0, true)
	var square := stamp("rectangle_2x2", Vector2i(3, 3))
	var right := stamp("triangle_2x2", Vector2i(5, 3))
	check_merge([left, square], "Triangle + square sharing an edge")
	var landscape := check_merge([left, square, right], "Triangle + square + triangle")
	check_merge([square, stamp("circle_3x3", Vector2i(4, 2))], "Square + overlapping circle")
	check_merge([stamp("slope_3x3", Vector2i(2, 2)), stamp("circle_2x2", Vector2i(2, 3))], "Curved slope + circular bump")
	var overlapping: Array = []
	for x in range(2, 5):
		for y in range(2, 5):
			overlapping.append(stamp("rectangle_2x2", Vector2i(x, y)))
	check_merge(overlapping, "Nine overlapping filled stamps")
	if not landscape.is_empty():
		check_merge([landscape, stamp("oval_2x3", Vector2i(3, 2))], "Composite + primitive")
	var other := check_merge([square, right], "Second composite")
	if not landscape.is_empty() and not other.is_empty():
		check_merge([landscape, other], "Composite + composite")
	check_merge([stamp("s_band_2x3", Vector2i(2, 2)), stamp("rectangle_2x2", Vector2i(2, 4))], "Filled S + overlapping square")
	check_merge([stamp("u_band_3x3", Vector2i(2, 2)), stamp("rectangle_3x3", Vector2i(2, 4))], "Filled U joined across its bottom")
	check_merge([stamp("capsule_2x3", Vector2i(2, 2)), stamp("bump_3x2", Vector2i(2, 3))], "Capsule + filled bump")
	# A bridge may appear after initially disconnected pieces in selection order.
	check_merge([left, right, square], "Late bridge joins earlier separate pieces")


func check_rejections() -> void:
	for id: String in ["wall_1x2", "diagonal_2x2", "corner_2x2", "j_curve_2x2", "u_curve_2x2", "s_curve_2x2"]:
		var result: Dictionary = Composite.merge([stamp("rectangle_3x3", Vector2i(2, 2)), stamp(id, Vector2i(2, 2))])
		check(not result.error.is_empty() and result.placement.is_empty(), "Open " + id + " rejects clearly")
	var islands: Dictionary = Composite.merge([stamp("rectangle_1x1", Vector2i(1, 1)), stamp("rectangle_1x1", Vector2i(6, 6))])
	check(not islands.error.is_empty() and islands.placement.is_empty(), "Disconnected islands reject without replacing terrain")
	var ring: Array = [stamp("rectangle_1x3", Vector2i(2, 2)), stamp("rectangle_1x3", Vector2i(4, 2)),
		stamp("rectangle_1x3", Vector2i(2, 2), 1), stamp("rectangle_1x3", Vector2i(2, 4), 1)]
	var hole: Dictionary = Composite.merge(ring)
	check(not hole.error.is_empty() and hole.placement.is_empty(), "Union containing a hole rejects without silently filling it")
	var point_touch: Dictionary = Composite.merge([stamp("rectangle_1x1", Vector2i(2, 2)), stamp("rectangle_1x1", Vector2i(3, 3))])
	check(not point_touch.error.is_empty() and point_touch.placement.is_empty(), "Point-only contact rejects a non-simple contour")
	for polygon in [PackedVector2Array([Vector2.ZERO, Vector2(2, 2), Vector2(0, 2), Vector2(2, 0)]),
		PackedVector2Array([Vector2.ZERO, Vector2(2, 0), Vector2(2, 0), Vector2(0, 2)]),
		PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(2, 0)]),
		PackedVector2Array([Vector2.ZERO, Vector2(INF, 0), Vector2(0, 2)])]:
		check(not Composite.validation_error(polygon).is_empty(), "Invalid crossing, degenerate or non-finite contour rejects")


func check_smoothing() -> void:
	var changed := false
	for example in merged_examples:
		var before := var_to_bytes(example)
		for strength in [0.0, 0.25, 0.5, 0.75]:
			var result: Dictionary = Composite.smooth(example, strength)
			check(result.error.is_empty() and not result.placement.is_empty(), "Smoothing %.0f%% prepares a valid preview" % (strength * 100), result.error)
			if result.placement.is_empty():
				continue
			var outline: PackedVector2Array = result.placement.outline
			check(simple_polygon(outline) and Composite.validation_error(outline).is_empty(), "Smoothing %.0f%% stays simple and triangulatable" % (strength * 100))
			var area_ratio := polygon_area(outline) / polygon_area(example.outline)
			check(area_ratio >= 0.9 and area_ratio <= 1.1, "Smoothing preserves the authored mass within ten percent")
			if strength == 0.0:
				check(outline == example.outline, "Zero strength preserves exact outline vertices")
			else:
				changed = changed or outline != example.outline
			var repeated: Dictionary = Composite.smooth(example, strength)
			check(var_to_bytes(result.placement) == var_to_bytes(repeated.placement), "Repeated smoothing preview is deterministic")
		check(var_to_bytes(example) == before, "Strength previews never mutate original composite data")
	check(changed, "Nonzero smoothing changes at least one sharp joined outline")


func check_transforms() -> void:
	if merged_examples.is_empty(): return
	var source := merged_examples[0]
	var original := var_to_bytes(source)
	for turns in 4:
		for mirrors in 4:
			var placed := source.duplicate(true)
			placed.anchor = Vector2i(2, 3)
			placed.quarter_turns = turns
			placed.flip_h = bool(mirrors & 1)
			placed.flip_v = bool(mirrors & 2)
			var expected := PackedVector2Array()
			var frame := Vector2(placed.base_size)
			for point: Vector2 in source.outline:
				var transformed := point
				match turns:
					1: transformed = Vector2(frame.y - point.y, point.x)
					2: transformed = frame - point
					3: transformed = Vector2(point.y, frame.x - point.x)
				var rotated_frame := Vector2(frame.y, frame.x) if turns % 2 else frame
				if placed.flip_h: transformed.x = rotated_frame.x - transformed.x
				if placed.flip_v: transformed.y = rotated_frame.y - transformed.y
				expected.append(transformed)
			check(Shapes.transformed_points(placed) == expected, "Composite rotation %d and mirrors %d preserve exact stored points" % [turns, mirrors])
			var document := Document.new()
			document.placements = [placed]
			check(document.validation_errors().is_empty(), "Transformed composite remains valid authoring data", str(document.validation_errors()))
	check(var_to_bytes(source) == original, "Rotation and mirroring never rewrite the source outline")


func check_storage() -> Resource:
	if merged_examples.is_empty(): return null
	var document := Document.new()
	document.title = "Composite terrain exact round trip"
	document.spawn_position = Vector2(525.5, 525.25)
	for example in merged_examples:
		var smooth: Dictionary = Composite.smooth(example, 0.5)
		if not smooth.placement.is_empty():
			document.placements.append(smooth.placement)
	var exact := exact_placement_bytes(document.placements)
	check(document.validation_errors().is_empty(), "Composite collection passes the versioned Act schema", str(document.validation_errors()))
	check(document.save_document(SAVE_PATH) == OK, "Composite document saves through staged and verified persistence")
	var loaded: Dictionary = Document.load_document(SAVE_PATH)
	check(loaded.document != null, "Composite document reloads", loaded.error)
	if loaded.document == null: return null
	check(loaded.document.fingerprint() == document.fingerprint() and exact_placement_bytes(loaded.document.placements) == exact,
		"Save/reload preserves every outline bit, transform and smoothing field")
	var exact_file := FileAccess.open(EXACT_PATH, FileAccess.WRITE)
	exact_file.store_buffer(exact)
	exact_file.close()
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/composite_terrain_regression.gd", "--", "--reload"], output, true)
	check(code == 0, "Fresh Godot process loads identical composite bytes after restart", "\n".join(output))
	var edited: Dictionary = Composite.merge([loaded.document.placements[0], stamp("rectangle_2x2", Vector2i(3, 3))])
	check(edited.error.is_empty() and not edited.placement.is_empty(), "Reloaded composite supports further sculpting", edited.error)
	var malformed: Resource = document.copy_document()
	malformed.placements[0].outline = PackedVector2Array([Vector2.ZERO, Vector2(1, 1), Vector2(0, 1), Vector2(1, 0)])
	check(not malformed.validation_errors().is_empty() and malformed.save_document(SAVE_PATH) == ERR_INVALID_DATA,
		"Invalid stored outline cannot overwrite a valid saved Act")
	check_storage_rejections(document)
	return loaded.document


func check_storage_rejections(document: Resource) -> void:
	var invalid_path := "res://test-results/composite-malformed.tres"
	var valid_payload := var_to_bytes(document.placements[0].outline)
	var extra: PackedByteArray = valid_payload.duplicate()
	extra.append(0)
	var forged_count: PackedByteArray = valid_payload.duplicate()
	forged_count.encode_u32(4, 4294967295)
	var payloads: Array[PackedByteArray] = [PackedByteArray([0]), var_to_bytes({"outline": "wrong container"}),
		valid_payload.slice(0, valid_payload.size() - 1), extra, forged_count]
	for payload in payloads:
		var stored: Resource = document._storage_document()
		stored.placements[0].outline = payload
		check(ResourceSaver.save(stored, invalid_path) == OK, "Malformed outline fixture reaches disk")
		var rejected: Dictionary = Document.load_document(invalid_path)
		check(rejected.document == null and rejected.error.to_lower().contains("outline"), "Malformed composite payload rejects before entering authoring/runtime data", rejected.error)
	var wrong_strength: Resource = document._storage_document()
	wrong_strength.placements[0].smoothing_strength = var_to_bytes("not a number")
	check(ResourceSaver.save(wrong_strength, invalid_path) == OK, "Malformed strength fixture reaches disk")
	var rejected_strength: Dictionary = Document.load_document(invalid_path)
	check(rejected_strength.document == null and rejected_strength.error.to_lower().contains("strength"), "Malformed composite strength payload rejects clearly")
	var legacy := Document.new()
	legacy.spawn_position = Vector2(100.25, 400.5)
	legacy.placements = [stamp("circle_2x2", Vector2i(2, 2))]
	legacy.ring_trails = [{"start": Vector2(110.25, 230.5), "end": Vector2(310.75, 230.5), "spacing": 12.3456789012345}]
	var expected: String = legacy.fingerprint()
	var old_storage: Resource = legacy._storage_document()
	old_storage.format_version = 5
	var legacy_path := "res://test-results/composite-legacy-v5.tres"
	check(ResourceSaver.save(old_storage, legacy_path) == OK, "Legacy format 5 fixture retains a nonempty exact ring trail")
	var legacy_bytes := FileAccess.get_file_as_bytes(legacy_path)
	var upgraded: Dictionary = Document.load_document(legacy_path)
	check(upgraded.document != null and upgraded.document.format_version == 6 and upgraded.document.fingerprint() == expected,
		"Format 5 migrates in memory without discarding rings, terrain or Spawn", upgraded.error)
	check(FileAccess.get_file_as_bytes(legacy_path) == legacy_bytes, "Loading old Acts never rewrites their source file")
	var fake_legacy: Resource = document._storage_document()
	fake_legacy.format_version = 5
	check(ResourceSaver.save(fake_legacy, invalid_path) == OK, "Composite-in-old-format fixture reaches disk")
	var rejected_legacy: Dictionary = Document.load_document(invalid_path)
	check(rejected_legacy.document == null and rejected_legacy.error.contains("Previous Act formats"), "Old format cannot smuggle composite fields past migration")


func check_runtime(saved: Resource) -> void:
	if saved == null or saved.placements.is_empty(): return
	var document: Resource = saved.copy_document()
	# One explicitly merged object must become exactly one collision body and prism.
	document.placements = [saved.placements[1] if saved.placements.size() > 1 else saved.placements[0]]
	document.grid_size = Vector2i(9, 8)
	document.spawn_position = Vector2(225, 350)
	var before: String = document.fingerprint()
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
	ball.teleport_to(ball.position, Vector2.ZERO, true)
	var result: Dictionary = Compiler.compile(document, tuning, controls, ball)
	check(result.error.is_empty() and result.root != null and result.terrain.size() == 1, "Runtime compiles one composite directly to one terrain body", result.error)
	if result.root == null:
		world.free()
		return
	world.add_child(result.root)
	await frames(3)
	var terrain: Dictionary = result.terrain[0]
	var expected := Shapes.transformed_points(document.placements[0])
	for index in expected.size():
		expected[index] = expected[index] * float(document.cell_size) + Vector2(document.placements[0].anchor) * float(document.cell_size)
	check(terrain.shape_id == "composite" and terrain.closed and terrain.points == expected and terrain.collision is CollisionPolygon2D
		and terrain.collision.build_mode == CollisionPolygon2D.BUILD_SOLIDS and terrain.collision.polygon == expected,
		"Runtime descriptor and solid collider use the editor's identical final transformed outline")
	var convex_count := 0
	var valid_solids := true
	for owner_id in terrain.body.get_shape_owners():
		for shape_index in terrain.body.shape_owner_get_shape_count(owner_id):
			var shape: Shape2D = terrain.body.shape_owner_get_shape(owner_id, shape_index)
			valid_solids = valid_solids and shape is ConvexPolygonShape2D and shape.points.size() >= 3
			convex_count += 1
	check(valid_solids and convex_count > 0, "CollisionPolygon creates real convex physics shapes after entering the tree")
	var physical_matches := true
	for x in range(20):
		for y in range(20):
			var query := PhysicsPointQueryParameters2D.new()
			query.position = Vector2((x + 0.317) * 25, (y + 0.173) * 25)
			query.collision_mask = 1
			var hit := not world.get_world_2d().direct_space_state.intersect_point(query).is_empty()
			physical_matches = physical_matches and hit == Geometry2D.is_point_in_polygon(query.position, expected)
	check(physical_matches, "Real physics-space queries reproduce the final editor silhouette")
	var rings := RingField.new()
	rings.ball = ball
	rings.tuning = tuning
	world.add_child(rings)
	var presentation := GreenHill.new()
	presentation.ball = ball
	presentation.ring_field = rings
	root.add_child(presentation)
	presentation.build_authored(result, Rect2(Vector2.ZERO, document.red_gutter_bounds().end), float(document.cell_size))
	check(presentation.authored_terrain_polygons.size() == 1 and presentation.authored_terrain_polygons[0] == expected
		and presentation.authored_composite_polygons[0] == expected, "Green Hill consumes stored composite points without runtime union or smoothing")
	var obstacles: Array[MeshInstance3D] = []
	for child in presentation.terrain_root.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("SolidTerrainObstacle"):
			obstacles.append(child)
	check(obstacles.size() == 1 and presentation.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"One merged mass renders as one collisionless Green Hill obstacle")
	if obstacles.size() == 1:
		check_mesh(obstacles[0], expected)
	if DisplayServer.get_name() != "headless":
		await frames(4)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/composite-green-hill.png") == OK,
			"Graphical Green Hill composite extrusion capture saved")
	check(document.fingerprint() == before, "Physics and presentation preserve exact stored authoring geometry")
	presentation.free()
	world.free()
	await frames(2)
	await check_main_game(document, expected)


func check_main_game(document: Resource, expected: PackedVector2Array) -> void:
	var path := "res://test-results/composite-main-game.tres"
	check(document.save_document(path) == OK, "Single-composite fixture saves for the normal game source loader")
	var bytes := FileAccess.get_file_as_bytes(path)
	var game := ObservedGame.new()
	game.authored_act_path = path
	root.add_child(game)
	await frames(6)
	check(game.generator_calls == 0 and game.level_source == "authored" and game.chunks.is_empty(),
		"Normal Green Hill application loads a saved composite without procedural generation")
	check(game.authored_document != null and game.authored_document.fingerprint() == document.fingerprint()
		and game.authored_runtime.terrain.size() == 1 and game.authored_runtime.terrain[0].points == expected,
		"Normal source loader preserves the exact saved composite and its physics descriptor")
	check(game.playfield.terrain_bodies.size() == 1 and game.playfield.terrain_bodies[0] == game.authored_runtime.terrain[0].body
		and game.ball.serve_pending and game.ball.position == document.spawn_position,
		"Shared main gameplay uses the composite body and the exact authored Spawn")
	check(game.presentation.authored_composite_polygons.size() == 1 and game.presentation.authored_composite_polygons[0] == expected,
		"Normal Green Hill rendering receives the same final composite outline")
	if DisplayServer.get_name() != "headless":
		game.presentation.camera_follow_enabled = false
		game.presentation.set_camera_preset(TablePresentation.CameraPreset.REAL_PINBALL)
		await frames(4)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/composite-main-game.png") == OK,
			"Graphical composite capture includes the normal gameplay HUD")
	check(FileAccess.get_file_as_bytes(path) == bytes, "Normal gameplay source loading never rewrites the composite file")
	game.free()
	await frames(3)


func check_mesh(obstacle: MeshInstance3D, expected: PackedVector2Array) -> void:
	var mesh := obstacle.mesh
	check(mesh.get_surface_count() == 2, "Composite extrusion has one grass cap and one exterior side surface")
	if mesh.get_surface_count() != 2: return
	var caps: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sides: PackedVector3Array = mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
	var cap_area := 0.0
	for first in range(0, caps.size(), 3):
		var triangle := PackedVector2Array()
		for offset in 3:
			triangle.append(TablePresentation.unmap_point(obstacle.to_global(caps[first + offset])))
		cap_area += polygon_area(triangle)
	check(absf(cap_area - polygon_area(expected)) < 0.2, "Actual grass cap triangles cover the complete final silhouette once")
	var exterior_only := sides.size() == expected.size() * 6
	var seen := PackedInt32Array()
	for first in range(0, sides.size(), 6):
		var a := TablePresentation.unmap_point(obstacle.to_global(sides[first]))
		var b := TablePresentation.unmap_point(obstacle.to_global(sides[first + 1]))
		var found := -1
		for index in expected.size():
			var next := (index + 1) % expected.size()
			if (a.distance_to(expected[index]) < 0.001 and b.distance_to(expected[next]) < 0.001) or (b.distance_to(expected[index]) < 0.001 and a.distance_to(expected[next]) < 0.001):
				found = index
				break
		exterior_only = exterior_only and found >= 0 and not seen.has(found)
		seen.append(found)
	check(exterior_only and seen.size() == expected.size(), "Every cliff quad follows one final outer edge; no source seams or duplicate internal walls remain")


func run() -> void:
	if OS.get_cmdline_user_args().has("--reload"):
		var loaded: Dictionary = Document.load_document(SAVE_PATH)
		check(loaded.document != null, "Fresh process opens saved composite", loaded.error)
		if loaded.document != null:
			check(exact_placement_bytes(loaded.document.placements) == FileAccess.get_file_as_bytes(EXACT_PATH), "Fresh process preserves exact composite bytes")
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
		check_merge_cases()
		check_rejections()
		check_smoothing()
		check_transforms()
		await check_runtime(check_storage())
	print("RESULT | Composite terrain | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
