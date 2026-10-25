extends "res://tests/authored_act_runtime_regression.gd"
## Uses the production ball, bumper response, flippers and physics server.
## Each trajectory has one initial condition, followed by ordinary fixed ticks.


func physical_environment(document: Resource) -> Dictionary:
	var env := environment()
	env.tuning.effective.gravity_scale = 0.0
	env.tuning.effective.rolling_acceleration = 0.0
	env.tuning.effective.rolling_drag = 0.0
	env.tuning.effective.wall_restitution = 0.7
	env.runtime = Compiler.compile(document, env.tuning, env.controls, env.ball)
	if env.runtime.root != null:
		env.world.add_child(env.runtime.root)
	await frames(3)
	return env


func has_solid_at(env: Dictionary, position: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = position
	query.collision_mask = 1
	return not env.world.get_world_2d().direct_space_state.intersect_point(query).is_empty()


func check_solid_regions() -> void:
	var probes := [
		{"id": "triangle_2x2", "inside": Vector2(110, 185), "outside": Vector2(185, 110), "turns": 0, "flip": false},
		{"id": "u_band_2x2", "inside": Vector2(110, 180), "outside": Vector2(150, 180), "turns": 0, "flip": false},
		{"id": "s_band_2x3", "inside": Vector2(110, 200), "outside": Vector2(190, 120), "turns": 0, "flip": false},
		{"id": "triangle_2x2", "inside": Vector2(185, 110), "outside": Vector2(110, 185), "turns": 1, "flip": true},
	]
	for probe: Dictionary in probes:
		var document := new_document()
		document.placements = [stamp(probe.id, Vector2i(2, 2), probe.turns, probe.flip)]
		var env := await physical_environment(document)
		check(env.runtime.error.is_empty() and has_solid_at(env, probe.inside) and not has_solid_at(env, probe.outside), "Physics filled/empty regions match actual %s silhouette (turn%d mirror%s)" % [probe.id, probe.turns, probe.flip], env.runtime.error)
		env.world.free()
		await frames(2)


func trajectory(placements: Array, start: Vector2, velocity: Vector2, ticks: int, objects: Array = [], cell_size: float = 50.0) -> Dictionary:
	var document := new_document()
	document.cell_size = cell_size
	document.placements = placements.duplicate(true)
	document.gameplay_objects = objects.duplicate(true)
	var env := await physical_environment(document)
	var original: String = document.fingerprint()
	var result := {"position": start, "velocity": velocity, "maximum_speed": 0.0, "sweeps": 0, "bumper_hits": 0, "immutable": false}
	env.ball.teleport_to(start, velocity)
	for tick in ticks:
		await frames(1)
		result.maximum_speed = maxf(result.maximum_speed, env.ball.linear_velocity.length())
	result.position = env.ball.position
	result.velocity = env.ball.linear_velocity
	result.sweeps = env.ball.sweep_rebounds
	result.bumper_hits = env.ball.bumper_hit_count
	result.immutable = original == document.fingerprint()
	env.world.free()
	await frames(2)
	return result


func check_terrain_contacts() -> void:
	var filled := await trajectory([stamp("rectangle_2x2")], Vector2(50, 150), Vector2(600, 0), 18)
	check(filled.velocity.x < -350 and filled.position.x < 100 and filled.immutable, "Production ball rebounds from filled terrain without entering the frame", str(filled))
	var open_corner := await trajectory([stamp("corner_2x2")], Vector2(190, 150), Vector2(-600, 0), 12)
	check(open_corner.position.x < 145 and open_corner.velocity.x < -590, "Open L has no fake diagonal closing wall", str(open_corner))
	var closed_triangle := await trajectory([stamp("triangle_2x2")], Vector2(190, 150), Vector2(-600, 0), 12)
	check(closed_triangle.velocity.distance_to(Vector2(-600, 0)) > 200 and closed_triangle.position.y < 145, "Filled triangle collides on the real slanted edge that the open L leaves empty", str(closed_triangle))
	var open_u := await trajectory([stamp("u_curve_2x2")], Vector2(150, 60), Vector2(0, 600), 14)
	check(open_u.position.y > 115 and open_u.velocity.y > 590, "Open U mouth has no invented top closing segment", str(open_u))
	# Stop after crossing the hypothetical bottom wall, before the ball radius
	# reaches the nearby real curved segment farther inside the frame.
	var u_bottom := await trajectory([stamp("u_curve_2x2")], Vector2(110, 225), Vector2(0, -600), 6)
	check(u_bottom.position.y < 205 and u_bottom.velocity.y < -590, "Open U has no invented frame-bottom wall", str(u_bottom))
	var solid_u_bottom := await trajectory([stamp("u_band_2x2")], Vector2(110, 225), Vector2(0, -600), 9)
	check(solid_u_bottom.velocity.y > 350, "Filled U's authored bottom closes its solid wing and rebounds the ball", str(solid_u_bottom))
	var transformed := await trajectory([stamp("wall_1x3", Vector2i(2, 2), 1, false, true)], Vector2(175, 60), Vector2(0, 600), 22)
	check(transformed.velocity.y < -350 and transformed.position.y < 150, "Rotated and mirrored wall collides at its exact transformed path", str(transformed))
	var duplicate := await trajectory([stamp("rectangle_2x2"), stamp("rectangle_2x2")], Vector2(50, 150), Vector2(600, 0), 18)
	check(duplicate.velocity.distance_to(filled.velocity) < 2.0 and duplicate.maximum_speed <= 601.0 and duplicate.sweeps <= filled.sweeps + 1, "Coincident overlapping solids do not multiply rebound impulses or add energy", str(duplicate))
	var circle := await trajectory([stamp("circle_2x2")], Vector2(170, 50), Vector2(0, 600), 22)
	var overlap := await trajectory([stamp("circle_2x2"), stamp("slope_2x2", Vector2i(3, 2))], Vector2(170, 50), Vector2(0, 600), 22)
	check(overlap.velocity.is_finite() and overlap.velocity.distance_to(circle.velocity) < 3.0 and overlap.maximum_speed <= 601.0 and overlap.sweeps <= circle.sweeps + 1, "Circle over curved slope preserves the outer bump response without internal-seam impulse duplication", str(overlap))


func check_bumper_contacts() -> void:
	for cell_size in [50.0, 100.0]:
		var center := Vector2(250.5, 200.25)
		var round_bumper := [{"type": "round_bumper", "position": center, "rotation_degrees": 32.0}]
		var round_hit := await trajectory([], center - Vector2(0, 2 * cell_size), Vector2(0, 12 * cell_size), 22, round_bumper, cell_size)
		check(round_hit.bumper_hits == 1 and round_hit.velocity.y < -600 * PhysicsTuning.BALANCED.bumper_rebound_multiplier and round_hit.immutable, "Compact round bumper fires once at the exact fractional center with %.0f-pixel cells" % cell_size, str(round_hit))
		var triangle := [{"type": "triangle_bumper", "position": center, "rotation_degrees": 32.0}]
		var axis := Vector2.DOWN.rotated(deg_to_rad(32))
		var sling_hit := await trajectory([], center + Vector2(-0.10, -1.5).rotated(deg_to_rad(32)) * cell_size, axis * 12 * cell_size, 22, triangle, cell_size)
		check(sling_hit.bumper_hits == 1 and sling_hit.velocity.dot(axis) < -200 and sling_hit.immutable, "Compact rotated sling fires from its exact anchor with %.0f-pixel cells" % cell_size, str(sling_hit))
		var wall := await trajectory([stamp("wall_1x3")], Vector2(1, 3) * cell_size, Vector2(8000, 0), 5, [], cell_size)
		check(wall.velocity.x < 0 and wall.position.x < 2 * cell_size and wall.sweeps > 0, "Actual authored ball radius protects fast open-rail collision with %.0f-pixel cells" % cell_size, str(wall))


func check_flipper_contacts() -> void:
	for cell_size in [50.0, 100.0]:
		await check_flipper_contacts_at_scale(cell_size)
	var baseline := PlaygroundFlipper.new()
	var rotated := PlaygroundFlipper.new()
	for side in [1.0, -1.0]:
		baseline.side = side
		rotated.side = side
		rotated.authored_rest_angle = baseline.rest_angle() + PI * 0.5
		baseline.rotation = baseline.rest_angle() - side * 0.35
		rotated.rotation = baseline.rotation + PI * 0.5
		check(baseline.strike_direction(0.65).rotated(PI * 0.5).distance_to(rotated.strike_direction(0.65)) < 0.000001, "Authored orientation rotates the complete existing biased strike direction for both hands")
	baseline.free()
	rotated.free()


func check_flipper_contacts_at_scale(cell_size: float) -> void:
	for side in [1.0, -1.0]:
		for offset in [0.0, PI * 0.5]:
			var document := new_document()
			document.cell_size = cell_size
			var default_angle: float = 0.32 if side > 0 else PI - 0.32
			document.gameplay_objects = [{"type": "left_flipper" if side > 0 else "right_flipper", "position": Vector2(300.5, 300.25), "rotation_degrees": rad_to_deg(default_angle + offset)}]
			var env := await physical_environment(document)
			var paddle: PlaygroundFlipper = env.runtime.flippers[0]
			var origin: Vector2 = paddle.position
			var shot := {"count": 0, "impulse": Vector2.ZERO}
			paddle.shot_fired.connect(func(_point: Vector2, impulse: Vector2, _fraction: float): shot.count += 1; shot.impulse = impulse)
			env.ball.teleport_to(origin + Vector2(side * 0.4225, -0.10).rotated(offset) * cell_size, Vector2(0, 2 * cell_size).rotated(offset))
			await frames(2)
			env.controls.virtual_left = side > 0
			env.controls.virtual_right = side < 0
			await frames(16)
			check(shot.count == 1 and shot.impulse.dot(Vector2.UP.rotated(offset)) > env.tuning.effective.flipper_launch_strength * (600.0 / 1050.0) and paddle.position == origin, "Compact %s flipper strikes once at its exact pivot with %.0f-pixel cells and %.0f° offset" % ["left" if side > 0 else "right", cell_size, rad_to_deg(offset)], str(shot))
			await frames(20)
			check(shot.count == 1, "Holding an authored flipper cannot repeat its powered strike")
			env.world.free()
			await frames(2)
	var distant_document := new_document()
	distant_document.cell_size = cell_size
	distant_document.gameplay_objects = [{"type": "left_flipper", "position": Vector2(300.5, 300.25), "rotation_degrees": rad_to_deg(0.32)}]
	var distant_env := await physical_environment(distant_document)
	var distant_paddle: PlaygroundFlipper = distant_env.runtime.flippers[0]
	var axis := Vector2.RIGHT.rotated(distant_paddle.rotation)
	var normal := Vector2(axis.y, -axis.x)
	distant_env.ball.teleport_to(distant_paddle.tip() + axis * 0.4 * cell_size + normal * 0.04 * cell_size)
	await frames(2)
	distant_env.controls.virtual_left = true
	await frames(16)
	check(distant_paddle.strikes == 0, "Scaled contact allowance cannot strike a ball outside the compact paddle's reach")
	distant_env.world.free()
	await frames(2)


func check_showcase_spawn() -> void:
	var loaded: Dictionary = ActData.load_document("res://data/acts/playtest_showcase.tres")
	check(loaded.document != null, "Development showcase loads through the editor format", loaded.error)
	if loaded.document == null: return
	var env := await physical_environment(loaded.document)
	var shape := CircleShape2D.new()
	shape.radius = env.ball.radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, loaded.document.spawn_position)
	query.collision_mask = 1
	check(env.world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "Showcase Spawn has physical clearance for the real ball radius")
	env.tuning.effective.gravity_scale = 1.0
	env.ball.teleport_to(loaded.document.spawn_position)
	var fired := false
	var below_paddles := false
	for tick in 180:
		for paddle: PlaygroundFlipper in env.runtime.flippers:
			var nearest := Geometry2D.get_closest_point_to_segment(env.ball.position, paddle.position, paddle.tip())
			if env.ball.linear_velocity.y > 0 and env.ball.position.distance_to(nearest) < paddle.radius + env.ball.radius + 15.0 * env.ball.radius / PlaygroundBall.RADIUS:
				if paddle.side > 0: env.controls.virtual_left = true
				else: env.controls.virtual_right = true
		await frames(1)
		for paddle: PlaygroundFlipper in env.runtime.flippers:
			fired = fired or paddle.strikes > 0
		below_paddles = below_paddles or env.ball.position.y > 1110
		if fired and env.ball.linear_velocity.y < -200: break
	check(fired and not below_paddles, "Showcase's real falling serve reaches a paddle and can be launched with normal timing")
	env.world.free()
	await frames(2)


func run() -> void:
	await check_solid_regions()
	await check_terrain_contacts()
	await check_bumper_contacts()
	await check_flipper_contacts()
	await check_showcase_spawn()
	print("RESULT | Authored Act physics | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
