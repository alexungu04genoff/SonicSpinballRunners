extends Node
## Exercise external Act persistence and the actual player in source and exported builds.

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var root := get_tree().root
	var editor = load("res://scenes/act_geometry_editor.tscn").instantiate()
	root.add_child(editor)
	await get_tree().process_frame
	var folder: String = editor._act_directory()
	if not DirAccess.dir_exists_absolute(folder):
		push_error("Act directory does not exist")
		get_tree().quit(1)
		return
	var target := OS.get_user_data_dir().path_join("portable-smoke-%d.tres" % Time.get_ticks_usec())
	if not editor.load_from("res://tests/fixtures/traversal_diagnostic.tres"):
		print("PORTABLE_EDITOR_SMOKE: bundled Act load failed: ", editor.error_dialog.dialog_text)
		get_tree().quit(1)
		return
	var fingerprint: String = editor.document.fingerprint()
	editor.canvas.select_gameplay(4)
	editor.set_gameplay_property("length_multiplier", 1.5)
	var inspector_ok: bool = editor.document.gameplay_objects[4].properties.length_multiplier == 1.5
	editor.undo()
	editor.canvas.select_gameplay(1)
	editor.set_gameplay_property("terrain_clearance", false)
	inspector_ok = inspector_ok and not editor.document.gameplay_objects[1].properties.terrain_clearance
	editor.undo()
	editor.set_teleporter_exit(5, Vector2(400, -300))
	inspector_ok = inspector_ok and editor.document.gameplay_objects[5].properties.exit_x == 400.0
	editor.undo()
	if not inspector_ok or editor.document.fingerprint() != fingerprint:
		push_error("Traversal inspector edits or Undo failed")
		get_tree().quit(1)
		return
	if not editor.save_to(target) or not editor.load_from(target) or editor.document.fingerprint() != fingerprint:
		print("PORTABLE_EDITOR_SMOKE: external persistence failed: ", editor.error_dialog.dialog_text)
		push_error("External Act save/reload failed")
		get_tree().quit(1)
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_user_data_dir().path_join("portable-editor.png"))
	editor.queue_free()
	await get_tree().process_frame
	var session = load("res://scripts/prototype/session.gd").new()
	session.settings_path = OS.get_user_data_dir().path_join("portable-smoke-unused.cfg")
	session.configure_act_test(target)
	root.add_child(session)
	await session.start_run()
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(session.game) and (session.game.started or not session.game.last_source_error.is_empty()): break
		await get_tree().process_frame
	var game: Node = session.game
	var passed: bool = is_instance_valid(game) and game.started and is_instance_valid(game.ball) and game.active.document.fingerprint() == fingerprint
	if passed:
		passed = game.active.runtime.flippers.size() == 3 and is_equal_approx(game.active.runtime.flippers[2].length, 65.0) and game.active.runtime.mechanics.by_id.has("diagnostic_teleporter")
		game.ball.teleport_to(Vector2(80, 440), Vector2.ZERO)
		for frame in 8: await get_tree().physics_frame
		passed = passed and game.ball.position.x > 450.0 and game.telemetry.teleporters.transfers == 1
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_user_data_dir().path_join("portable-player.png"))
	await session._close_run("test_finished")
	session.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(target)
	print("PORTABLE_EDITOR_SMOKE: ", "PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)
