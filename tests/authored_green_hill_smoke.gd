extends "res://tests/authored_act_runtime_regression.gd"
## Shared-scale/presentation integration. Graphical runs save an exact screenshot
## comparison assembled from the editor and Green Hill frames without retouching.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const COMPARISON := "res://data/acts/scale_comparison.tres"
const LARGE_COMPARISON := "res://test-results/scale-comparison-100.tres"
const SHOWCASE := "res://data/acts/playtest_showcase.tres"
var game: Control
var editor_frame: Image


func comparison_document() -> Resource:
	var document := new_document()
	document.title = "Scale Comparison · 50 px cells"
	document.spawn_position = Vector2(240.5, 440.25)
	document.activation_y = 425.0
	document.entry_start_x = 5
	document.entry_width = 2
	document.exit_start_x = 5
	document.exit_width = 2
	document.placements = [
		stamp("rectangle_1x1", Vector2i(1, 2)),
		stamp("rectangle_1x3", Vector2i(9, 2)),
		stamp("rectangle_2x2", Vector2i(1, 5)),
		stamp("wall_1x3", Vector2i(4, 6), 1),
		stamp("wall_1x2", Vector2i(7, 6), 1),
		stamp("wall_1x3", Vector2i(0, 8)),
		stamp("wall_1x3", Vector2i(11, 8), 0, true),
	]
	document.gameplay_objects = [
		{"type": "round_bumper", "position": Vector2(250.5, 150.25), "rotation_degrees": 0.0},
		{"type": "triangle_bumper", "position": Vector2(350.25, 150.5), "rotation_degrees": 32.0},
		{"type": "left_flipper", "position": Vector2(225.5, 475.25), "rotation_degrees": rad_to_deg(0.32)},
		{"type": "right_flipper", "position": Vector2(374.5, 475.25), "rotation_degrees": rad_to_deg(PI - 0.32)},
	]
	document.ring_trails = [
		{"start": Vector2(225.5, 250.25), "end": Vector2(325.5, 250.25), "spacing": 25.0},
		{"start": Vector2(250.5, 400.25), "end": Vector2(350.5, 325.25), "spacing": 25.0},
	]
	return document


func write_samples() -> void:
	check(comparison_document().save_document(COMPARISON) == OK, "Comparison Act saves through the exact editor format")
	var loaded: Dictionary = ActData.load_document(SHOWCASE)
	check(loaded.document != null, "Existing curved showcase remains loadable")
	if loaded.document != null:
		# The shorter shared paddle still pivots at x440. Put this sample's serve
		# above that paddle; preserve every existing terrain and object placement.
		loaded.document.spawn_position = Vector2(482.5, 960.25)
		check(loaded.document.save_document(SHOWCASE) == OK, "Showcase serve aligns with its compact left paddle")


func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func capture_editor() -> void:
	var editor: Control = load("res://scenes/act_geometry_editor.tscn").instantiate()
	root.add_child(editor)
	await frames(3)
	check(editor.load_from(COMPARISON), "Editor loads the same comparison file used by runtime")
	editor.palette_tabs.current_tab = 1
	editor.canvas.select_gameplay(2)
	editor._refresh()
	await frames(3)
	check(editor.document.fingerprint() == comparison_document().fingerprint(), "Editor reproduces the comparison's exact pivots, trails and metadata")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		editor_frame = root.get_texture().get_image()
		check(editor_frame.save_png("res://test-results/authored-scale-editor.png") == OK, "Editor comparison frame saved")
	editor.queue_free()
	await frames(3)


func expected_rings(document: Resource) -> PackedVector2Array:
	var points := PackedVector2Array()
	for trail: Dictionary in document.ring_trails:
		points.append_array(Rings.positions(trail))
	return points


func check_shared_dimensions(cell_size: float) -> void:
	var document := comparison_document()
	document.cell_size = cell_size
	var path := COMPARISON if cell_size == 50 else LARGE_COMPARISON
	if cell_size != 50:
		check(document.save_document(path) == OK, "100px-cell comparison preserves exact original positions while scaling dimensions")
	check(game.load_act(path), "Authored Green Hill loads the %.0fpx-cell Act directly" % cell_size)
	await frames(5)
	check(not game.debug_2d and game.green_hill.visible and not game.view.disable_3d and not game.presentation.visible, "Green Hill is the default view; the 2D renderer remains available")
	check(game.green_hill.authored_mode and game.green_hill.authored_cell_size == cell_size, "Shared presentation receives authored descriptors and explicit cell scale")
	check(game.green_hill.find_children("*", "CollisionObject3D", true, false).is_empty() and game.character.find_children("*", "CollisionObject3D", true, false).is_empty(), "Green Hill scenery and rolling character remain entirely collisionless")
	check(game.green_hill.camera_preset == TablePresentation.CameraPreset.REAL_PINBALL, "Authored Green Hill retains the normal Real Pinball camera")
	check(game.green_hill.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE) and is_equal_approx(TablePresentation.map_point(Vector2(cell_size, 0)).length(), TablePresentation.map_point(Vector2(0, cell_size)).length()), "World geometry uses one uniform X/Y map rather than viewport stretching")
	check(is_equal_approx(game.ball.radius, Dimensions.BALL_RADIUS_CELLS * cell_size) and is_equal_approx(game.ball.get_child(0).shape.radius, game.ball.radius) and game.ball.radius < Dimensions.ROUND_RADIUS_CELLS * cell_size, "The real ball scales with authored cells and remains smaller than a bumper")
	check(game.find_children("*", "TableChunk", true, false).is_empty(), "Authored rendering instantiates no generated or fake TableChunk nodes")
	var floor_cap: MeshInstance3D = game.green_hill.terrain_root.get_node("AuthoredPlayfieldFloor/GrassCap")
	var floor_aabb := floor_cap.get_aabb()
	var floor_bounds := Rect2(TablePresentation.unmap_point(floor_aabb.position), TablePresentation.unmap_point(floor_aabb.size))
	check(floor_bounds.is_equal_approx(document.terrain_bounds()) and is_equal_approx(floor_aabb.position.y, -0.003), "Continuous grass floor covers the exact Act at gameplay height and stops before the drain gutter")
	var floor_probe := PhysicsPointQueryParameters2D.new()
	floor_probe.position = Vector2(document.terrain_bounds().get_center().x, document.terrain_bounds().end.y - cell_size * 0.3)
	floor_probe.collision_mask = 1
	check(game.ball.get_world_2d().direct_space_state.intersect_point(floor_probe).is_empty(), "Empty grass floor remains traversable without an added terrain collider")
	var framed := true
	var screen := Rect2(Vector2.ZERO, Vector2(game.view.size))
	var extent: Vector2 = document.red_gutter_bounds().end
	for point in [Vector2.ZERO, Vector2(extent.x, 0), extent, Vector2(0, extent.y)]:
		var world := TablePresentation.map_point(point)
		framed = framed and not game.green_hill.camera.is_position_behind(world) and screen.has_point(game.green_hill.camera.unproject_position(world))
	check(framed, "The perspective camera frames every corner of the complete Act and drain gutter")
	var exact_anchors := true
	for index in document.gameplay_objects.size():
		var authored: Dictionary = document.gameplay_objects[index]
		var record: Dictionary = game.runtime.objects[index]
		exact_anchors = exact_anchors and record.body.position == authored.position and record.rotation_degrees == authored.rotation_degrees
	check(exact_anchors and game.ball.position == document.spawn_position, "Dimension changes never shift saved centers, sling origins, flipper pivots or Spawn")
	var circle: Dictionary = game.runtime.objects[0]
	var circle_preview := Objects.local_points(document.gameplay_objects[0], cell_size)
	check(circle.radius == cell_size * 0.25 and circle.body.get_child(0).shape.radius == circle_preview[0].x, "Editor and physical bumper both measure exactly half a cell in diameter")
	var sling: Dictionary = game.runtime.objects[1]
	check(sling.points == Objects.local_points(document.gameplay_objects[1], cell_size) and sling.body.get_child(0).polygon == sling.points, "Editor and physical sling use the same compact polygon about the same anchor")
	var circle_visual: Node3D = game.green_hill.bumper_visuals[circle.body.get_instance_id()]
	var circle_mesh: CylinderMesh = circle_visual.get_child(0).mesh
	check(is_equal_approx(circle_mesh.top_radius, circle.radius * TablePresentation.SCALE) and is_equal_approx(circle_mesh.bottom_radius, circle.radius * TablePresentation.SCALE) and TablePresentation.unmap_point(circle_visual.global_position).distance_to(circle.position) < 0.001, "Actual Green Hill bumper mesh keeps the shared radius and exact center")
	var sling_visual: Node3D = game.green_hill.bumper_visuals[sling.body.get_instance_id()]
	var sling_mesh: MeshInstance3D = sling_visual.get_child(0)
	var matching_sling := true
	var seen_corners: Array[int] = []
	for surface in sling_mesh.mesh.get_surface_count():
		var vertices: PackedVector3Array = sling_mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var actual := TablePresentation.unmap_point(sling_mesh.to_global(vertex))
			var found := false
			for index in sling.points.size():
				var expected: Vector2 = sling.position + sling.points[index].rotated(deg_to_rad(sling.rotation_degrees))
				if actual.distance_to(expected) < 0.001:
					found = true
					if not seen_corners.has(index): seen_corners.append(index)
			matching_sling = matching_sling and found
	check(matching_sling and seen_corners.size() == sling.points.size(), "Every vertex of the rendered sling footprint matches its rotated physical polygon")
	for index in game.runtime.flippers.size():
		var paddle: PlaygroundFlipper = game.runtime.flippers[index]
		var visual: Node3D = game.green_hill.flipper_visuals[index]
		var points := Objects.local_points(document.gameplay_objects[index + 2], cell_size)
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point: Vector2 in points: bounds = bounds.expand(point)
		check(is_equal_approx(paddle.length + 2 * paddle.radius, bounds.size.x) and paddle.length == cell_size * 0.65 and paddle.radius == cell_size * 0.05, "Editor and runtime flipper body have the same 0.75-cell overall length")
		check(TablePresentation.unmap_point(visual.global_position).distance_to(paddle.position) < 0.001 and TablePresentation.unmap_point(visual.to_global(Vector3(paddle.length * TablePresentation.SCALE, 0, 0))).distance_to(paddle.tip()) < 0.001, "Green Hill paddle visual preserves the exact physical pivot and tip")
	var ring_points := expected_rings(document)
	var matching_rings: bool = game.ring_field is RingField and game.ring_field.rings.size() == ring_points.size() and game.green_hill.ring_visuals.size() == ring_points.size()
	for index in ring_points.size():
		matching_rings = matching_rings and game.ring_field.rings[index].home == ring_points[index]
		matching_rings = matching_rings and TablePresentation.unmap_point(game.green_hill.ring_visuals[index].position).distance_to(ring_points[index]) < 0.001
	check(matching_rings and game.ring_field.ring_radius == cell_size * 0.09, "Existing ring gameplay and presentation retain every exact authored trail center at shared scale")
	check(is_equal_approx(game.green_hill.ball_visual.mesh.radius, game.ball.radius * TablePresentation.SCALE), "The shared ball mesh matches the real authored ball radius")
	check(game.character.spin_root.visible and game.character.spin_root.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(game.character.spin_root.get_child(0).mesh.radius, game.ball.radius * TablePresentation.SCALE) and TablePresentation.unmap_point(game.character.spin_root.position).distance_to(game.ball.position) < 0.001, "Visible rolling Sonic mesh matches the physical ball radius and center")
	check(game.document.fingerprint() == document.fingerprint(), "Building Green Hill leaves all source authoring records unchanged")
	check_ring_contact_scale(cell_size)


func check_ring_contact_scale(cell_size: float) -> void:
	# Exercise the real RingField contact predicate without motion integration or
	# terrain nearby. Adjacent outside/inside probes catch a retained pixel radius.
	var field := RingField.new()
	var probe := PlaygroundBall.new()
	probe.radius = Dimensions.BALL_RADIUS_CELLS * cell_size
	field.ball = probe
	field.ring_radius = Dimensions.RING_RADIUS_CELLS * cell_size
	field.tuning = game.tuning
	var previous_magnet: float = game.tuning.effective.ring_magnet_radius
	game.tuning.effective.ring_magnet_radius = 0.0
	field.add_ring(Vector2.ZERO)
	probe.serve_pending = false
	var contact: float = probe.radius + field.ring_radius
	probe.position = Vector2(contact + 0.01, 0)
	field.previous_ball_position = probe.position
	field._physics_process(0)
	check(field.rings[0].active, "%.0fpx cells: ring contact excludes a point just beyond the combined radii" % cell_size)
	probe.position = Vector2(contact - 0.01, 0)
	field._physics_process(0)
	check(not field.rings[0].active, "%.0fpx cells: ring contact includes the physical ball plus ring radius" % cell_size)
	field.reset_rings()
	field.previous_ball_position = Vector2(-100, 0)
	probe.teleport_to(Vector2(100, 0))
	field._physics_process(0)
	check(field.rings[0].active and field.previous_ball_position == Vector2(100, 0), "%.0fpx cells: teleporting across a trail awards no swept pickup" % cell_size)
	game.tuning.effective.ring_magnet_radius = previous_magnet
	field.free()
	probe.free()


func polygon_area(points: PackedVector2Array) -> float:
	var result := 0.0
	for index in points.size(): result += points[index].cross(points[(index + 1) % points.size()])
	return absf(result) * 0.5


func check_catalogue_meshes() -> void:
	var document := new_document()
	document.grid_size = Vector2i(36, 36)
	document.spawn_position = Vector2(25, 1775)
	var definitions: Array = Shapes.definitions()
	for index in definitions.size():
		document.placements.append(stamp(definitions[index].id, Vector2i((index % 9) * 4, (index / 9) * 4)))
	var path := "res://test-results/authored-visual-catalogue.tres"
	check(document.save_document(path) == OK and game.load_act(path), "All 77 catalogue shapes compile into one direct authored presentation")
	await frames(3)
	var triangles: Array[PackedVector2Array] = []
	var raised := true
	var wall_style := true
	for node: Node in game.green_hill.terrain_root.get_children():
		if not node is MeshInstance3D or not str(node.name).begins_with("SolidTerrainObstacle"): continue
		var top: Material = node.mesh.surface_get_material(0)
		var side: Material = node.mesh.surface_get_material(1)
		wall_style = wall_style and top is ShaderMaterial and side is ShaderMaterial
		if top is ShaderMaterial and side is ShaderMaterial:
			wall_style = wall_style and top == game.green_hill.terrain_top_material() and side == game.green_hill.terrain_side_material() and top.get_shader_parameter("raised_turf") == true
		# Surface zero is the blocking silhouette's cap; exclude its vertical sides
		# and the separate traversable floor from projected coverage measurements.
		for surface in 1:
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices: raised = raised and vertex.y > game.green_hill.ball_height()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for index in vertices.size(): indices.append(index)
			for start in range(0, indices.size(), 3):
				var points := PackedVector2Array()
				for offset in 3: points.append(TablePresentation.unmap_point(node.to_global(vertices[indices[start + offset]])))
				triangles.append(points)
	var expected_area := 0.0
	var rendered_area := 0.0
	for record: Dictionary in game.runtime.terrain:
		if record.closed: expected_area += polygon_area(record.points)
	for triangle in triangles: rendered_area += polygon_area(triangle)
	check(absf(expected_area - rendered_area) < 2.0, "Actual raised-wall cap triangles cover the complete solid catalogue with no missing band caps")
	check(raised, "Solid blockers render above the ball center instead of impersonating flat playable grass")
	check(wall_style, "Authored solid caps and sides share textured grass and checker-soil materials with generated rails")
	var correct_coverage := true
	var solid_bands := 0
	for record: Dictionary in game.runtime.terrain:
		if not record.closed: continue
		if str(record.shape_id).begins_with("u_band_") or str(record.shape_id).begins_with("s_band_"): solid_bands += 1
		var bounds := Rect2(record.points[0], Vector2.ZERO)
		for point: Vector2 in record.points: bounds = bounds.expand(point)
		var nearby: Array[PackedVector2Array] = []
		for triangle in triangles:
			if bounds.grow(0.01).has_point((triangle[0] + triangle[1] + triangle[2]) / 3.0): nearby.append(triangle)
		for x in 9:
			for y in 9:
				var point := bounds.position + bounds.size * Vector2((x + 0.37) / 9.0, (y + 0.23) / 9.0)
				var covered := false
				for triangle in nearby: covered = covered or Geometry2D.is_point_in_polygon(point, triangle)
				correct_coverage = correct_coverage and covered == Geometry2D.is_point_in_polygon(point, record.points)
	check(correct_coverage and solid_bands == 9, "Actual rendered caps preserve filled interiors and voids across all solids, including all nine U/S ribbons")


func check_topology_and_toggle() -> void:
	var source_bytes := FileAccess.get_file_as_bytes(SHOWCASE)
	check(game.load_act(SHOWCASE), "Curved and overlapping showcase loads without generator adaptation")
	await frames(4)
	var paths: Array = []
	for record: Dictionary in game.runtime.terrain:
		if not record.closed: paths.append(record.points)
	check(paths == game.green_hill.authored_open_paths, "Green Hill preserves every open authored curve as its exact unclosed path")
	var coverage_matches := true
	for x in range(25, 1200, 50):
		for y in range(25, 1200, 50):
			var point := Vector2(x, y)
			var physical_fill := false
			var visual_fill := false
			for record: Dictionary in game.runtime.terrain:
				physical_fill = physical_fill or (record.closed and Geometry2D.is_point_in_polygon(point, record.points))
			for polygon: PackedVector2Array in game.green_hill.authored_terrain_polygons:
				visual_fill = visual_fill or Geometry2D.is_point_in_polygon(point, polygon)
			coverage_matches = coverage_matches and physical_fill == visual_fill
	check(coverage_matches, "Presentation-only overlap merging preserves filled/empty coverage of actual curved silhouettes")
	var fingerprint: String = game.document.fingerprint()
	var ball_position: Vector2 = game.ball.position
	await key(KEY_F2)
	check(game.debug_2d and game.presentation.visible and game.view.disable_3d and game.document.fingerprint() == fingerprint and game.ball.position == ball_position, "F2 reveals existing 2D debug geometry without changing physics or source data")
	await key(KEY_F2)
	check(not game.debug_2d and game.green_hill.visible and not game.view.disable_3d, "F2 restores Green Hill on the same live Act")
	check(FileAccess.get_file_as_bytes(SHOWCASE) == source_bytes, "Presentation and mode changes never rewrite the source Act")


func check_inset_floor() -> void:
	var document := new_document()
	document.spawn_position = Vector2(300, 550)
	for row in [0, 3, 6, 9]:
		document.placements.append(stamp("rectangle_1x3", Vector2i(3, row)))
		document.placements.append(stamp("rectangle_1x3", Vector2i(9, row)))
	document.placements.append(stamp("s_band_3x3", Vector2i(0, 3), 0, true))
	document.placements.append(stamp("circle_1x1", Vector2i(6, 5)))
	var path := "res://test-results/authored-inset-floor.tres"
	check(document.save_document(path) == OK and game.load_act(path), "Connected side-wall fixture loads through the normal authored compiler")
	await frames(3)
	var outline: PackedVector2Array = game.green_hill.authored_floor_outline
	check(not Geometry2D.is_point_in_polygon(Vector2(130, 25), outline) and not Geometry2D.is_point_in_polygon(Vector2(510, 300), outline), "Deck excludes the exterior shelf beyond both inset side walls")
	check(not Geometry2D.is_point_in_polygon(Vector2(10, 175), outline) and Geometry2D.is_point_in_polygon(Vector2(100, 275), outline), "Deck follows the curved outside wall instead of flattening it to a rectangle")
	check(Geometry2D.is_point_in_polygon(Vector2(300, 300), outline) and not Geometry2D.is_point_in_polygon(Vector2(300, 625), outline), "Interior floor stays continuous around small obstacles and stops before the gutter")
	var floor: MeshInstance3D = game.green_hill.terrain_root.get_node("AuthoredPlayfieldFloor/GrassCap")
	var area := 0.0
	var vertices: PackedVector3Array = floor.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for index in range(0, vertices.size(), 3):
		area += polygon_area(PackedVector2Array([TablePresentation.unmap_point(vertices[index]), TablePresentation.unmap_point(vertices[index + 1]), TablePresentation.unmap_point(vertices[index + 2])]))
	check(absf(area - polygon_area(outline)) < 1.0 and game.document.fingerprint() == document.fingerprint(), "Rendered deck triangulates the inferred contour without changing any authored records")
	# A sculpted lower wall can share its upper edge with ordinary stamps, as in
	# First Try Smooth. The floor must recognize the complete connected boundary.
	var composite = preload("res://scripts/act_editor/composite_terrain.gd")
	var mixed: Array = [document.placements[0], document.placements[1]]
	for column in [3, 9]:
		mixed.append(composite.merge([
			stamp("rectangle_1x3", Vector2i(column, 3)),
			stamp("rectangle_1x3", Vector2i(column, 6)),
			stamp("rectangle_1x3", Vector2i(column, 9)),
		]).placement)
	mixed.append_array(document.placements.slice(8))
	document.placements = mixed
	check(document.save_document(path) == OK and game.load_act(path), "Mixed composite and stamped side walls load through the authored compiler")
	await frames(3)
	var mixed_outline: PackedVector2Array = game.green_hill.authored_floor_outline
	var coverage_matches := true
	for x in range(5, 600, 10):
		for y in range(5, 600, 10):
			var point := Vector2(x, y)
			coverage_matches = coverage_matches and Geometry2D.is_point_in_polygon(point, outline) == Geometry2D.is_point_in_polygon(point, mixed_outline)
	check(coverage_matches, "Sculpting connected side walls does not restore rectangular exterior ground")
	var exact_composites: Array[PackedVector2Array] = []
	for record: Dictionary in game.runtime.terrain:
		if record.shape_id == "composite": exact_composites.append(record.points)
	check(game.green_hill.authored_composite_polygons == exact_composites and game.document.fingerprint() == document.fingerprint(), "Floor inference leaves authoritative composite contours and saved geometry unchanged")


func check_ring_pickup() -> void:
	check(game.load_act(COMPARISON), "Comparison reload restores uncollected authored rings")
	await frames(4)
	game.controls.virtual_enabled = true
	game.tuning.effective.gravity_scale = 0.0
	game.tuning.effective.ring_magnet_radius = 0.0
	var first: Vector2 = game.ring_field.rings[0].home
	game.ball.teleport_to(first - Vector2(0, 25), Vector2(0, 600))
	await frames(8)
	check(game.rings_collected > 0 and not game.ring_field.rings[0].active, "The real moving ball collects a saved trail through the existing RingField")
	var count: int = game.rings_collected
	check(not game.ring_field.claim_ring(0) and game.rings_collected == count, "Already-collected authored rings cannot award twice")
	game.reset_ball()
	await frames(4)
	check(game.ring_field.rings[0].active and game.ball.serve_pending and game.rings_collected == count, "Reset restores the authored rack while keeping the session collection counter")


func capture_comparison() -> void:
	if DisplayServer.get_name() == "headless": return
	check(game.load_act(COMPARISON), "Final visual comparison uses the same saved Act as the editor")
	await frames(6)
	await key(KEY_F3)
	await RenderingServer.frame_post_draw
	var green_frame := root.get_texture().get_image()
	check(green_frame.save_png("res://test-results/authored-scale-green-hill.png") == OK, "Green Hill comparison frame saved")
	if editor_frame != null:
		editor_frame.convert(Image.FORMAT_RGBA8)
		green_frame.convert(Image.FORMAT_RGBA8)
		var combined := Image.create(editor_frame.get_width() + green_frame.get_width(), maxi(editor_frame.get_height(), green_frame.get_height()), false, Image.FORMAT_RGBA8)
		combined.fill(Color("0b1420"))
		combined.blit_rect(editor_frame, Rect2i(Vector2i.ZERO, editor_frame.get_size()), Vector2i.ZERO)
		combined.blit_rect(green_frame, Rect2i(Vector2i.ZERO, green_frame.get_size()), Vector2i(editor_frame.get_width(), 0))
		check(combined.save_png("res://test-results/authored-scale-side-by-side.png") == OK, "Exact editor/Green Hill frames combined side by side without resizing geometry")
	await key(KEY_F2)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://test-results/authored-scale-debug-2d.png") == OK, "Underlying 2D comparison remains available")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	if OS.get_cmdline_user_args().has("--write-comparison"):
		write_samples()
		print("RESULT | Comparison samples | %d checks | %d failures" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	await capture_editor()
	game = load("res://scenes/authored_act_playtest.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	await check_shared_dimensions(50.0)
	await check_shared_dimensions(100.0)
	await check_topology_and_toggle()
	await check_catalogue_meshes()
	await check_inset_floor()
	await check_ring_pickup()
	await capture_comparison()
	game.queue_free()
	await frames(3)
	print("RESULT | Authored Green Hill | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
