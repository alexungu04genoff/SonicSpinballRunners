extends "res://tests/authored_act_runtime_regression.gd"
## Exercise the standalone UI and capture the real rendered simulation with ANGLE.
var game: Control
const SAMPLE := "res://data/acts/playtest_showcase.tres"


func button_named(label: String) -> Button:
	for node in game.find_children("*", "Button", true, false):
		if node.text == label:
			return node
	return null


func click_button(label: String) -> void:
	var button := button_named(label)
	check(button != null, "Toolbar has " + label)
	if button == null: return
	var point := button.get_global_rect().get_center()
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


func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://test-results/authored-act-" + name + ".png") == OK, "Rendered " + name + " capture saved")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	root.gui_embed_subwindows = true
	game = load("res://scenes/authored_act_playtest.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	check(game.document == null, "Standalone scene starts with explicit file choice")
	await click_button("Example")
	await frames(4)
	check(game.current_path == SAMPLE and game.ball.serve_pending, "Example toolbar loads the representative Act and waits at Spawn")
	var original_bytes := FileAccess.get_file_as_bytes(SAMPLE)
	var original: String = game.document.fingerprint()
	var playfield: Rect2 = game.view.get_parent().get_global_rect()
	check(root.get_visible_rect().encloses(playfield), "Complete playfield panel fits the window")
	var visible_world := Rect2(game.camera.position - Vector2(game.view.size) / game.camera.zoom * 0.5, Vector2(game.view.size) / game.camera.zoom)
	check(visible_world.encloses(Rect2(Vector2.ZERO, game.document.red_gutter_bounds().end)), "Camera includes all authored terrain and the entire gutter")
	await capture("ready")
	await click_button("Load Act")
	check(game.picker.visible and paused and game.controls.input_blocked, "File picker suspends gameplay and input")
	game.picker.hide()
	game.picker.canceled.emit()
	await frames(2)
	check(not paused and not game.controls.input_blocked, "Cancel restores the preceding play state")
	await click_button("Load Act")
	game.picker.hide()
	game.picker.file_selected.emit(ProjectSettings.globalize_path(SAMPLE))
	await frames(3)
	check(game.document.fingerprint() == original and not paused, "File-picker selection loads exact data and resumes the previous pause state")
	await key(KEY_ENTER)
	await frames(8)
	check(not game.ball.serve_pending and game.ball.position.y > game.document.spawn_position.y, "Enter uses the shared input adapter to release the real ball into gravity")
	await key(KEY_ESCAPE)
	var paused_position: Vector2 = game.ball.position
	await frames(8)
	check(paused and game.ball.position == paused_position, "Escape pauses the real simulation")
	await click_button("Resume")
	await frames(3)
	check(not paused and game.ball.position != paused_position, "Resume toolbar restarts the simulation")
	await key(KEY_R)
	await frames(3)
	check(game.ball.serve_pending and game.ball.position == game.document.spawn_position, "R resets to exact Spawn through the normal input path")
	game.controls.virtual_enabled = true
	await key(KEY_ENTER)
	for tick in 360:
		for paddle: PlaygroundFlipper in game.runtime.flippers:
			var nearest := Geometry2D.get_closest_point_to_segment(game.ball.position, paddle.position, paddle.tip())
			var pressed: bool = game.ball.linear_velocity.y > 0 and game.ball.position.distance_to(nearest) < 55
			if paddle.side > 0: game.controls.virtual_left = pressed
			else: game.controls.virtual_right = pressed
		await frames(1)
		if game.activation_count > 0: break
	check(game.runtime.flippers[0].strikes + game.runtime.flippers[1].strikes > 0 and game.activation_count > 0, "Normal serve and timed flipper controls physically reach the Activation Trigger")
	await capture("playing")
	var active_simulation: Node2D = game.simulation
	var incomplete := ActData.new()
	var invalid_path := "res://test-results/authored-act-no-spawn.tres"
	check(incomplete.save_document(invalid_path) == OK, "Spawnless authoring draft fixture saves")
	check(not game.load_act(invalid_path) and game.last_error.to_lower().contains("spawn") and game.simulation == active_simulation, "Invalid replacement reports missing Spawn and preserves the current playable table")
	await click_button("Reload")
	await frames(4)
	check(game.last_error.is_empty() and game.ball.serve_pending and game.document.fingerprint() == original, "Reload restores the source Act after play and clears the previous load error")
	check(FileAccess.get_file_as_bytes(SAMPLE) == original_bytes, "UI load, play, reset and reload never write the sample source")
	game.queue_free()
	await frames(3)
	print("RESULT | Authored Act scene | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
