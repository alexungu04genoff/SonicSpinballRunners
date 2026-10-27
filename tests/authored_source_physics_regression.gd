extends "res://tests/authored_act_runtime_regression.gd"
## Compare baked and freshly compiled authored collisions under identical
## profiles, dimensions and contact planes. No alternative physics implementation.
const Playfield = preload("res://scripts/playfield_data.gd")
const Bake = preload("res://scripts/endless/geometry_bake.gd")


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
	var compiled: Dictionary = Compiler.compile(document, env.tuning, env.controls, env.ball)
	check(compiled.error.is_empty(), "Authored comparison geometry compiles for " + character)
	if not authored:
		var baked: Array = []
		for item: Dictionary in compiled.terrain:
			var shapes: Array = []
			for owner: int in item.body.get_shape_owners():
				for index in item.body.shape_owner_get_shape_count(owner):
					shapes.append({"shape": item.body.shape_owner_get_shape(owner, index), "transform": item.body.shape_owner_get_transform(owner)})
			baked.append(shapes)
		compiled.root.free()
		var receipt := Bake.new()
		receipt.source_fingerprint = document.fingerprint()
		receipt.theme_id = "green_hill"
		receipt.pipeline_fingerprint = Bake.pipeline_hash(receipt.theme_id)
		receipt.physics_validated = true
		receipt.collisions = baked
		compiled = Compiler.compile_baked(document, env.tuning, env.controls, env.ball, receipt, receipt.pipeline_fingerprint)
		check(compiled.error.is_empty(), "Baked comparison physics compiles for " + character)
	env.world.add_child(compiled.root)
	env.paddle = compiled.flippers[0]
	env.playfield = Playfield.from_authored(document, compiled)
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


func run() -> void:
	for character: String in CharacterSpecials.CHARACTER_IDS:
		var baked := await sample_source(false, character)
		var authored := await sample_source(true, character)
		check(baked.tuning == authored.tuning and baked.mass == authored.mass, character + ": source constructors share the exact profile and mass")
		check(baked.paddle_geometry == authored.paddle_geometry and authored.paddle_geometry.pivot == Vector2(400, 1000) and authored.paddle_geometry.length == 65.0 and authored.paddle_geometry.radius == 5.0, character + ": source constructors preserve the same compact paddle pivot and dimensions")
		for kind in ["gravity", "steering", "countersteering"]:
			check(baked[kind].position.distance_to(authored[kind].position) < 0.02 and baked[kind].velocity.distance_to(authored[kind].velocity) < 0.02 and absf(baked[kind].assist - authored[kind].assist) < 0.001, character + ": identical " + kind + " trajectory across baked and authored collision paths", str([baked[kind], authored[kind]]))
		check(baked.wall.velocity.distance_to(authored.wall.velocity) < 0.5 and baked.wall.velocity.x < 0 and authored.wall.velocity.x < 0, character + ": matched real wall faces produce the same rebound", str([baked.wall, authored.wall]))
		check(baked.bumper_hits == 1 and authored.bumper_hits == 1 and baked.bumper.velocity.distance_to(authored.bumper.velocity) < 0.5, character + ": the same bumper contact applies the same normal impulse", str([baked.bumper, authored.bumper]))
		check(baked.sling_hits == 1 and authored.sling_hits == 1 and baked.sling.velocity.distance_to(authored.sling.velocity) < 0.5, character + ": the same rotated sling contact produces the same response", str([baked.sling, authored.sling]))
		check(baked.shot.count == 1 and authored.shot.count == 1 and baked.shot.impulse.distance_to(authored.shot.impulse) < 0.01 and baked.flipper_velocity.distance_to(authored.flipper_velocity) < 0.5, character + ": equal paddle geometry produces the same real strike and launch velocity", str([baked.shot, authored.shot]))
		check(baked.rings == authored.rings and authored.rings.count == 5 and authored.rings.score == 125, character + ": equal rings use the same collection contacts and Scorecraft awards", str([baked.rings, authored.rings]))
		check(baked.serve.position.distance_to(authored.serve.position) < 0.02 and baked.serve.velocity.distance_to(authored.serve.velocity) < 0.02 and not authored.serve.pending, character + ": normal serve behavior is independent of the source")
	print("RESULT | Authored source physics | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
