extends "res://tests/authored_act_runtime_regression.gd"
## Compare the existing chunk constructors and authored compiler under identical
## profiles, dimensions and contact planes. No alternative physics implementation.
const Playfield = preload("res://scripts/playfield_data.gd")


func matched_document() -> Resource:
	var document := new_document()
	document.cell_size = 100.0
	document.spawn_position = Vector2(442.5, 900.25)
	document.placements = [stamp("wall_1x3", Vector2i(8, 6))]
	document.gameplay_objects = [
		{"type": "round_bumper", "position": Vector2(600, 400), "rotation_degrees": 0.0},
		{"type": "triangle_bumper", "position": Vector2(900, 400), "rotation_degrees": 32.0},
		{"type": "left_flipper", "position": Vector2(400, 1000), "rotation_degrees": rad_to_deg(0.32)},
	]
	document.ring_trails = [{"start": Vector2(300, 300), "end": Vector2(400, 300), "spacing": 25.0}]
	return document


func build_source(authored: bool, character: String) -> Dictionary:
	var env := environment()
	env.tuning.use_profile(CharacterSpecials.CHARACTERS[character].profile)
	var document := matched_document()
	if authored:
		var compiled: Dictionary = Compiler.compile(document, env.tuning, env.controls, env.ball)
		check(compiled.error.is_empty(), "Authored comparison geometry compiles for " + character)
		env.world.add_child(compiled.root)
		env.paddle = compiled.flippers[0]
		env.playfield = Playfield.from_authored(document, compiled)
	else:
		var data := ChunkData.new()
		data.grid_dimensions = Vector2i(12, 12)
		data.markers = {"serve": document.spawn_position}
		# The legacy capsule rail extends 12px toward the ball. Move its centerline
		# outward so the actual contact face is x800 in both source constructors.
		data.rails = [PackedVector2Array([Vector2(812, 600), Vector2(812, 900)])]
		data.bumpers = [{"kind": "circle", "position": Vector2(600, 400), "radius": 25.0},
			{"kind": "triangle", "position": Vector2(900, 400), "points": Dimensions.sling_points(100.0), "rotation": deg_to_rad(32.0)}]
		data.rings = PackedVector2Array([Vector2(300, 300), Vector2(325, 300), Vector2(350, 300), Vector2(375, 300), Vector2(400, 300)])
		var chunk := TableChunk.new()
		chunk.data = data
		env.world.add_child(chunk)
		chunk.build()
		chunk.wall_material.bounce = env.tuning.effective.wall_restitution
		var paddle := PlaygroundFlipper.new()
		paddle.ball = env.ball
		paddle.controls = env.controls
		paddle.tuning = env.tuning
		paddle.position = Vector2(400, 1000)
		paddle.length = 65.0
		paddle.radius = 5.0
		env.world.add_child(paddle)
		env.paddle = paddle
		var chunks: Array[TableChunk] = [chunk]
		env.playfield = Playfield.from_generated(chunks, {"bounds": Rect2(0, 0, 1200, 1300)})
	var field := RingField.new()
	field.ball = env.ball
	field.tuning = env.tuning
	field.ring_radius = 9.0
	for point: Vector2 in env.playfield.ring_positions: field.add_ring(point)
	env.world.add_child(field)
	env.rings = field
	return env


func trace(env: Dictionary, start: Vector2, velocity: Vector2, steering: float, ticks: int) -> Dictionary:
	env.controls.virtual_left = false
	env.controls.virtual_steering = 0.0
	env.ball.teleport_to(start, velocity)
	await frames(3)
	env.controls.virtual_steering = steering
	await frames(ticks)
	return {"position": env.ball.position, "velocity": env.ball.linear_velocity, "assist": env.ball.steering_contribution}


func sample_source(authored: bool, character: String) -> Dictionary:
	var env := build_source(authored, character)
	await frames(3)
	var result := {}
	result.tuning = env.tuning.effective.duplicate()
	result.mass = env.ball.mass
	result.paddle_geometry = {"pivot": env.paddle.position, "length": env.paddle.length, "radius": env.paddle.radius, "rest": env.paddle.rest_angle()}
	result.gravity = await trace(env, Vector2(300, 100), Vector2.ZERO, 0.0, 30)
	result.steering = await trace(env, Vector2(300, 100), Vector2(200, -100), 1.0, 30)
	result.countersteering = await trace(env, Vector2(300, 100), Vector2(200, -100), -1.0, 30)
	env.tuning.effective.gravity_scale = 0.0
	result.wall = await trace(env, Vector2(730, 750), Vector2(600, 0), 0.0, 22)
	var contacts: int = env.ball.bumper_hit_count
	result.bumper = await trace(env, Vector2(500, 400), Vector2(600, 0), 0.0, 24)
	result.bumper_hits = env.ball.bumper_hit_count - contacts
	contacts = env.ball.bumper_hit_count
	result.sling = await trace(env, Vector2(800, 400), Vector2(600, 0), 0.0, 24)
	result.sling_hits = env.ball.bumper_hit_count - contacts
	var shot := {"count": 0, "impulse": Vector2.ZERO}
	env.paddle.shot_fired.connect(func(_where: Vector2, impulse: Vector2, _fraction: float): shot.count += 1; shot.impulse = impulse)
	await trace(env, Vector2(442.25, 990), Vector2(0, 200), 0.0, 1)
	env.controls.virtual_left = true
	await frames(16)
	result.shot = shot.duplicate()
	result.flipper_velocity = env.ball.linear_velocity
	env.controls.virtual_left = false
	env.rings.reset_rings()
	var scoring := Scorecraft.new()
	env.world.add_child(scoring)
	var ring_awards := {"score": 0, "count": 0}
	env.rings.scoring_pickup.connect(func(_point: Vector2, _source: String, _multiplier: int): ring_awards.score += scoring.award_ring(); ring_awards.count += 1)
	env.tuning.effective.ring_magnet_radius = 0.0
	await trace(env, Vector2(270, 300), Vector2(300, 0), 0.0, 60)
	result.rings = ring_awards.duplicate()
	env.tuning.use_profile(CharacterSpecials.CHARACTERS[character].profile)
	env.ball.serve_position = env.playfield.spawn
	env.ball.teleport_to(env.playfield.spawn, Vector2.ZERO, true)
	await frames(3)
	env.ball.launch()
	await frames(12)
	result.serve = {"position": env.ball.position, "velocity": env.ball.linear_velocity, "pending": env.ball.serve_pending}
	env.world.free()
	await frames(3)
	return result


func check_common_eligibility() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var chunk := TableChunk.new()
	chunk.data = ChunkData.new()
	world.add_child(chunk)
	var bodies: Array[StaticBody2D] = []
	for kind in ["rail", "rail", "flipper_mount", "gate"]:
		var body := StaticBody2D.new()
		chunk.add_child(body)
		bodies.append(body)
		chunk.descriptors.append({"kind": kind, "body": body, "checkpoint_only": bodies.size() == 2})
	var chunks: Array[TableChunk] = [chunk]
	var field := Playfield.from_generated(chunks, {})
	check(field.terrain_bodies.size() == 4 and field.is_glide_surface(bodies[0]) and not field.is_glide_surface(bodies[1]) and not field.is_glide_surface(bodies[2]) and not field.is_glide_surface(bodies[3]), "Common generated terrain retains material targets but only ordinary rails trigger glide impacts")
	world.free()


func run() -> void:
	check_common_eligibility()
	for character: String in CharacterSpecials.CHARACTER_IDS:
		var legacy := await sample_source(false, character)
		var authored := await sample_source(true, character)
		check(legacy.tuning == authored.tuning and legacy.mass == authored.mass, character + ": source constructors share the exact profile and mass")
		check(legacy.paddle_geometry == authored.paddle_geometry and authored.paddle_geometry.pivot == Vector2(400, 1000) and authored.paddle_geometry.length == 65.0 and authored.paddle_geometry.radius == 5.0, character + ": source constructors preserve the same compact paddle pivot and dimensions")
		for kind in ["gravity", "steering", "countersteering"]:
			check(legacy[kind].position.distance_to(authored[kind].position) < 0.02 and legacy[kind].velocity.distance_to(authored[kind].velocity) < 0.02 and absf(legacy[kind].assist - authored[kind].assist) < 0.001, character + ": identical " + kind + " trajectory across playfield sources", str([legacy[kind], authored[kind]]))
		check(legacy.wall.velocity.distance_to(authored.wall.velocity) < 0.5 and legacy.wall.velocity.x < 0 and authored.wall.velocity.x < 0, character + ": matched real wall faces produce the same rebound", str([legacy.wall, authored.wall]))
		check(legacy.bumper_hits == 1 and authored.bumper_hits == 1 and legacy.bumper.velocity.distance_to(authored.bumper.velocity) < 0.5, character + ": the same bumper contact applies the same normal impulse", str([legacy.bumper, authored.bumper]))
		check(legacy.sling_hits == 1 and authored.sling_hits == 1 and legacy.sling.velocity.distance_to(authored.sling.velocity) < 0.5, character + ": the same rotated sling contact produces the same response", str([legacy.sling, authored.sling]))
		check(legacy.shot.count == 1 and authored.shot.count == 1 and legacy.shot.impulse.distance_to(authored.shot.impulse) < 0.01 and legacy.flipper_velocity.distance_to(authored.flipper_velocity) < 0.5, character + ": equal paddle geometry produces the same real strike and launch velocity", str([legacy.shot, authored.shot]))
		check(legacy.rings == authored.rings and authored.rings.count == 5 and authored.rings.score == 125, character + ": equal rings use the same collection contacts and Scorecraft awards", str([legacy.rings, authored.rings]))
		check(legacy.serve.position.distance_to(authored.serve.position) < 0.02 and legacy.serve.velocity.distance_to(authored.serve.velocity) < 0.02 and not authored.serve.pending, character + ": normal serve behavior is independent of the source")
	print("RESULT | Authored source physics | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
