extends SceneTree
## One engine, two playfield sources. Uses the actual Green Hill application and
## shared physics callbacks; graphical runs capture its ordinary retained HUD.
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
const FIXTURE := "res://test-results/main-engine-act.tres"
const COMPARISON := "res://data/acts/scale_comparison.tres"

class ObservedGame:
	extends "res://experiments/visual_lab/visual_lab.gd"
	var generator_calls := 0
	func _generate_layout(seed_value: int, preference: int, grid_mode: int = -1, for_zone: bool = false, difficulty_override: int = -2) -> Dictionary:
		generator_calls += 1
		return super._generate_layout(seed_value, preference, grid_mode, for_zone, difficulty_override)

var game: Node
var checks := 0
var failures := 0
var identities: Dictionary
var areas: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String, detail := "") -> void:
	checks += 1
	if condition: print("PASS | ", label)
	else:
		failures += 1
		push_error("FAIL | " + label + " | " + detail)


func frames(count := 3) -> void:
	for index in count:
		await physics_frame
		await process_frame


func fixture() -> Resource:
	var document := ActData.new()
	document.title = "Shared main-engine regression"
	document.cell_size = 100.0
	document.spawn_position = Vector2(442.5, 900.25)
	document.activation_y = 600.0
	document.exit_start_x = 5
	document.exit_width = 2
	var wall := {"shape_id": "wall_1x3", "base_size": Vector2i(1, 3), "anchor": Vector2i(8, 6), "quarter_turns": 0, "flip_h": false, "flip_v": false}
	document.placements = [wall]
	document.gameplay_objects = [
		{"type": "round_bumper", "position": Vector2(600, 400), "rotation_degrees": 0.0},
		{"type": "triangle_bumper", "position": Vector2(800, 400), "rotation_degrees": 0.0},
		{"type": "left_flipper", "position": Vector2(400, 1000), "rotation_degrees": rad_to_deg(0.32)},
		{"type": "right_flipper", "position": Vector2(700, 1000), "rotation_degrees": rad_to_deg(PI - 0.32)},
	]
	document.ring_trails = [
		{"start": Vector2(400, 400), "end": Vector2(550, 400), "spacing": 30.0},
		{"start": Vector2(100, 100), "end": Vector2(200, 100), "spacing": 50.0},
	]
	return document


func engine_ids() -> Dictionary:
	var result := {}
	for property in ["ball", "tuning", "controls", "ring_field", "scorecraft", "specials", "debug_panel", "presentation", "character", "lab_ui", "challenge_ui", "view"]:
		result[property] = game.get(property).get_instance_id()
	result.camera = game.presentation.camera.get_instance_id()
	result.environment = game.presentation.find_children("*", "WorldEnvironment", false, false)[0].get_instance_id()
	result.challenge_panel = game.debug_panel.challenge_panel.get_instance_id()
	return result


func check_identity(label: String) -> void:
	check(engine_ids() == identities, label, str(engine_ids()))
	check(game.ball.controls == game.controls and game.ball.tuning == game.tuning and game.ring_field.ball == game.ball and game.specials.game == game and game.character.ball == game.ball and game.character.table == game.presentation, "Retained engine dependencies still point to the same authoritative objects")


func await_rebuild() -> void:
	for tick in 240:
		await frames(1)
		if not game.generation_pending: break
	check(not game.generation_pending, "Deferred source replacement completes")
	await frames(3)


func place(point: Vector2, velocity := Vector2.ZERO) -> void:
	game.specials.reset(true, "Fixture")
	game.controls.virtual_left = false
	game.controls.virtual_right = false
	game.controls.virtual_steering = 0.0
	game.ball.teleport_to(point, velocity)
	await frames(3)


func check_authored_start() -> void:
	check(game.generator_calls == 0 and game.level_source == "authored" and game.chunks.is_empty(), "Direct authored startup invokes neither table nor Zone generation and creates no fake chunks")
	check(game.playfield.source == "authored" and game.playfield.spawn == fixture().spawn_position and game.playfield.bumpers.size() == 2 and game.playfield.terrain_bodies.size() == 1, "The common playfield exposes exact authored spawn, targets and terrain")
	check(game.ball.serve_pending and game.ball.position == game.authored_document.spawn_position and is_equal_approx(game.ball.radius, 14.0), "The normal ball waits at exact authored Spawn with the shared 100px-cell size")
	check(game.presentation.camera_follow_enabled and game.presentation.camera_preset == TablePresentation.CameraPreset.REAL_PINBALL, "Authored startup uses the normal Green Hill follow camera and perspective")
	check(game.debug_panel.challenge_panel != null and game.lab_ui != null and game.character.specials == game.specials, "Normal modes, character HUD and rolling presenter remain the human gameplay shell")
	check(game.presentation.find_children("*", "CollisionObject3D", true, false).is_empty(), "Shared Green Hill remains collisionless")
	check(game.authored_timings.has("total_ms") and float(game.authored_timings.total_ms) > 0, "Main-engine authored loading retains ready-time instrumentation")


func check_rings_and_score() -> void:
	game.set_physics_process(false)
	game.specials.select_character("sonic")
	game.controls.virtual_enabled = true
	game.scorecraft.reset("Fixture", true)
	game.score = 0
	game.rings_collected = 0
	game.ring_field.reset_rings()
	var target: Node2D = game.playfield.bumpers[0]
	game._on_bumper_hit(target)
	check(game.score == 100 and game.scorecraft.chain == 1 and game.special_meter == 2, "An authored bumper uses ordinary Scorecraft and special recharge")
	game.tuning.effective.gravity_scale = 0.0
	game.tuning.effective.ring_magnet_radius = 0.0
	game.ball.teleport_to(Vector2(380, 400), Vector2(300, 0))
	await frames(30)
	check(game.rings_collected >= 3 and game.score >= 200 and game.scorecraft.chain == 2 and game.scorecraft.has_ring_link and game.special_meter > 2, "Real authored ring contacts feed the existing score, Scorecraft ring link and special meter", str([game.score, game.rings_collected, game.scorecraft.chain, game.special_meter]))
	var before: int = game.score
	check(not game.ring_field.claim_ring(0) and game.score == before, "A collected authored ring cannot score twice")
	game.tuning.use_profile(game.specials.definition.profile)
	game.reset_ball()
	await frames(3)
	check(game.ball.serve_pending and game.ball.position == game.playfield.spawn and game.scorecraft.chain == 0, "Normal main-game reset clears combo state and returns to authored Spawn")


func check_specials() -> void:
	game.set_physics_process(false)
	game.ring_field.set_physics_process(false)
	game.specials.area_completed.connect(func(source: String, targets: int, rings: int): areas.append({"source": source, "targets": targets, "rings": rings}))
	game.specials.select_character("sonic")
	await place(Vector2(400, 400))
	game.scorecraft.reset("Fixture", true)
	game.score = 0
	game.special_meter = 100
	var bumper: Node2D = game.playfield.bumpers[0]
	check(game.specials.find_target() == bumper and game.specials.activate(), "Shared Sonic homing selects the real authored bumper")
	for tick in 90:
		await frames(1)
		if game.score > 0: break
	check(game.score == 500 and game.specials.pending_target == null and game.special_meter == 2, "Physical authored homing contact awards the normal 5x hit and ordinary recharge", str([game.score, game.special_meter]))
	game.specials.select_character("tails")
	await place(Vector2(300, 500), Vector2(0, 400))
	var gravity: float = game.tuning.effective.gravity_scale
	game.special_meter = 100
	check(game.specials.activate() and game.specials.flight_remaining > 0 and game.tuning.effective.gravity_scale < gravity and game.tuning._temporary.size() == 1, "Shared Tails Flight changes the same live tuning resolver")
	var remaining: float = game.specials.flight_remaining
	var position: Vector2 = game.ball.position
	paused = true
	await frames(5)
	check(game.specials.flight_remaining == remaining and game.ball.position == position, "Normal pause freezes authored physics and special duration")
	paused = false
	await frames(5)
	check(game.ball.linear_velocity.y < 400 and game.specials.flight_remaining < remaining, "The existing Flight impulse and timer resume on the same ball")
	game.specials.reset(false, "Reset")
	check(game.tuning._temporary.is_empty() and is_equal_approx(game.tuning.effective.gravity_scale, gravity), "Reset removes the temporary Flight modifier without a second profile")
	game.specials.select_character("knuckles")
	await place(Vector2(700, 700), Vector2(200, 0))
	game.controls.virtual_steering = 1.0
	await frames(2)
	game.special_meter = 100
	var before_areas := areas.size()
	check(game.specials.activate(), "Shared Knuckles glide starts against an authored side wall")
	for tick in 100:
		await frames(1)
		if areas.size() > before_areas: break
	check(areas.size() == before_areas + 1 and areas.back().source == "shockwave" and areas.back().targets > 0 and game.specials.glide_remaining == 0, "A real authored wall impact triggers the existing shockwave and reaches an authored target", str(areas))
	game.specials.select_character("shadow")
	await place(Vector2(600, 500))
	game.ring_field.reset_rings()
	game.scorecraft.reset("Fixture", true)
	var score_before: int = game.score
	var contacts: int = game.ball.bumper_hit_count
	game.special_meter = 100
	check(game.specials.activate() and areas.back().source == "chaos_blast" and areas.back().targets == 2 and areas.back().rings > 0, "Shared Shadow Chaos Blast finds authored targets and the same RingField", str(areas))
	check(game.score > score_before and game.special_meter == 0 and game.ball.bumper_hit_count == contacts and game.scorecraft.chain == 0, "Authored blast uses normal fixed remote awards without fake physical contacts or meter refill")
	game.ring_field.set_physics_process(true)
	game.set_physics_process(true)
	game.reset_ball()
	await frames(3)


func check_switches() -> void:
	game.presentation.set_camera_value("look_ahead", 137.0)
	game.presentation.set_camera_value("dead_zone_y", 67.0)
	game.presentation.set_camera_follow(false)
	var camera_settings: Dictionary = game.presentation.camera_settings.duplicate()
	game.specials.select_character("tails")
	await place(Vector2(300, 700), Vector2(0, 200))
	game.special_meter = 100
	game.specials.activate()
	game.score = 777
	game.rings_collected = 7
	game.scorecraft.award_bumper(game.playfield.bumpers[0])
	game.special_meter = 63
	paused = true
	check(game.request_generated_source(), "The same main application accepts an explicit generated source switch")
	await await_rebuild()
	check(game.level_source == "generated" and game.generator_calls == 1 and not game.chunks.is_empty(), "Only the explicit generated-source choice invokes generation")
	check_identity("Authored to generated retains ball, tuning, input, rings, scoring, specials, HUD, presenter, camera and environment identities")
	check(game.score == 0 and game.rings_collected == 0 and game.special_meter == 0 and game.scorecraft.chain == 0 and game.tuning._temporary.is_empty() and game.specials.flight_remaining == 0 and game.ball.serve_pending, "Source switching uses the normal complete run reset")
	check(game.character_id == "tails" and game.specials.definition.profile == game.tuning.base and game.presentation.camera_settings == camera_settings and not game.presentation.camera_follow_enabled, "Source switching retains selected character and explicit camera preferences")
	if DisplayServer.get_name() != "headless":
		game.presentation.set_camera_follow(true)
		await frames(3)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/generated-main-green-hill.png") == OK, "Generated source captured in the same normal main-game HUD")
		game.presentation.set_camera_follow(false)
	check(game.request_authored_act(FIXTURE), "The same application accepts an authored Act after generated play")
	await await_rebuild()
	check(game.level_source == "authored" and game.generator_calls == 1 and game.chunks.is_empty(), "Returning to authored geometry bypasses generation entirely")
	check_identity("Generated to authored preserves every existing engine and human-presentation instance")
	check(game.presentation.camera_settings == camera_settings and not game.presentation.camera_follow_enabled, "Authored replacement preserves overview and camera tuning")
	game.presentation.set_camera_follow(true)
	var fingerprint: String = game.authored_document.fingerprint()
	var root_id: int = game.authored_runtime.root.get_instance_id()
	game.score = 321
	game.special_meter = 47
	game.request_authored_act("res://test-results/does-not-exist.tres")
	await await_rebuild()
	check(game.authored_document.fingerprint() == fingerprint and game.authored_runtime.root.get_instance_id() == root_id and game.score == 321 and game.special_meter == 47, "Failed authored load preserves the complete active world and run state")
	check_identity("Failed replacement also preserves camera, character, HUD and engine identities")
	check(not game.request_authored_act(FIXTURE, {"zone": true}), "Single authored Acts cannot silently invoke Zone generation")
	check(game.request_generation(game.generation_seed), "Ordinary replay stays on the currently selected authored source")
	await await_rebuild()
	check(game.level_source == "authored" and game.generator_calls == 1 and game.score == 0 and game.special_meter == 0, "Replay reloads the exact authored source through the normal reset path")
	paused = false
	game.controls.virtual_enabled = true
	game.reset_ball()
	await frames(3)


func check_lifecycle() -> void:
	game.specials.select_character("sonic")
	var activation_before: int = game.authored_activation_count
	await place(Vector2(500, 610), Vector2(0, -900))
	await frames(5)
	check(game.authored_activation_count == activation_before + 1, "Main game loop observes the authored upward Activation crossing")
	var exits_before: int = game.authored_exit_count
	await place(Vector2(550, 12), Vector2(0, -900))
	await frames(5)
	check(game.authored_exit_count == exits_before + 1 and not paused, "Main game loop reports authored Exit without creating a new Act or score gate")
	await place(Vector2(1100, 1290), Vector2(0, 500))
	await frames(8)
	check(game.respawn_time > 0 and game.ball_number > 1, "Authored gutter feeds the existing automatic drain/retry lifecycle")
	game.reset_ball()
	await frames(3)
	check(game.ball.position == game.playfield.spawn and game.ball.serve_pending, "The normal retry path returns to exact authored Spawn")


func capture_main_hud() -> void:
	if DisplayServer.get_name() == "headless": return
	paused = true
	game.request_authored_act(COMPARISON)
	await await_rebuild()
	paused = false
	await frames(6)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://test-results/authored-main-green-hill.png") == OK, "Normal Green Hill HUD and authored world captured in the same application")


func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	if DisplayServer.get_name() != "headless": root.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func check_main_controls() -> void:
	check(root.get_visible_rect().encloses(game.load_act_button.get_global_rect()) and root.get_visible_rect().encloses(game.source_selector.get_global_rect()), "Main-game level-source controls fit the existing window")
	check(game.source_selector.selected == 1 and game.debug_panel.challenge_panel.mode_selector.is_item_disabled(1) and game.debug_panel.challenge_panel.mode_selector.is_item_disabled(2), "Normal HUD identifies authored Free Play and explains unavailable multi-Act challenge modes")
	var follow: bool = game.presentation.camera_follow_enabled
	await key(KEY_O)
	check(game.presentation.camera_follow_enabled != follow, "Normal O shortcut toggles authored overview/follow on the retained camera")
	await key(KEY_O)
	await click(game.load_act_button)
	check(game.act_picker.visible and paused and game.controls.input_blocked, "Main HUD Load Act button opens the picker and suspends the existing game")
	var snapshot: String = game.authored_document.fingerprint()
	await key(KEY_ENTER)
	check(game.ball.serve_pending, "The source picker blocks gameplay serve input")
	game.act_picker.hide()
	game.act_picker.canceled.emit()
	await frames(3)
	check(not paused and not game.controls.input_blocked and game.authored_document.fingerprint() == snapshot, "Cancel returns to the preceding play state with the same active Act")
	await click(game.load_act_button)
	game.act_picker.hide()
	game.act_picker.file_selected.emit(ProjectSettings.globalize_path(FIXTURE))
	await await_rebuild()
	check(not paused and not game.controls.input_blocked and game.level_source == "authored" and game.generator_calls == 1, "File-picker selection loads directly into the retained game and restores play state")
	check_identity("Actual main-HUD loading retains all original engine and presentation identities")
	game.score = 222
	game.special_meter = 50
	await click(game.debug_panel.challenge_panel.start_button)
	await await_rebuild()
	check(game.level_source == "authored" and game.generator_calls == 1 and game.score == 0 and game.special_meter == 0 and game.ball.serve_pending, "Actual normal Start/replay button resets the current authored source without invoking generation")
	check_identity("Normal authored Start/replay retains the existing engine, HUD, camera and character")


func check_failed_cli() -> void:
	game = ObservedGame.new()
	root.add_child(game)
	await frames(12)
	check(game.generator_calls == 0 and not game.last_source_error.is_empty() and not is_instance_valid(game.ball), "Failed --act startup reports the source error without falling back to generation")
	check(not game.is_processing() and not game.is_physics_processing(), "Failed CLI startup disables the game loops before any dependent systems run")
	check(not game.is_processing_unhandled_input() and not game.is_processing_unhandled_key_input(), "Failed CLI startup also disables presentation shortcuts")
	for code in [KEY_O, KEY_C, KEY_1]: await key(code)
	check(not is_instance_valid(game.presentation) and not is_instance_valid(game.character) and not game.last_source_error.is_empty(), "O, C and pose shortcuts after failed startup cannot access uninitialized systems")
	var readable := false
	for label: Label in game.find_children("*", "Label", true, false):
		readable = readable or label.text.contains(game.last_source_error)
	check(readable, "Failed CLI startup displays its actionable error in the existing window")
	game.free()
	await frames(3)
	print("RESULT | Authored failed CLI | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	root.gui_embed_subwindows = true
	if OS.get_cmdline_user_args().has("--invalid-cli"):
		await check_failed_cli()
		return
	check(fixture().save_document(FIXTURE) == OK, "Main-engine authored fixture saves")
	var bytes := FileAccess.get_file_as_bytes(FIXTURE)
	game = ObservedGame.new()
	game.generation_enabled = false # Fast existing legacy geometry for source-switch checks.
	game.authored_act_path = FIXTURE
	root.add_child(game)
	await frames(5)
	identities = engine_ids()
	check_authored_start()
	await check_rings_and_score()
	await check_specials()
	await check_switches()
	await check_lifecycle()
	await check_main_controls()
	check(FileAccess.get_file_as_bytes(FIXTURE) == bytes, "Main-game loading, abilities, source switching and retries never rewrite the authored file")
	await capture_main_hud()
	game.free()
	await frames(3)
	print("RESULT | Authored main game | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
