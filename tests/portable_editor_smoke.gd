extends Node
## Exercise external Act persistence and the actual player in source and exported builds.

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	if "--launch-tube" in OS.get_cmdline_user_args():
		var passed: bool = await preload("res://tests/portable_launch_tube_smoke.gd").run(self)
		print("PORTABLE_LAUNCH_TUBE_SMOKE: ", "PASS" if passed else "FAIL")
		get_tree().quit(0 if passed else 1)
		return
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
	# Qualify the exported format-19 workspace using a disposable external copy.
	editor.canvas.set_object_selection({"gameplay": [2, 3]})
	editor.group_selection()
	var grouped: String = editor.document.editing_fingerprint()
	var original: Vector2 = editor.document.gameplay_objects[2].position
	var workspace: Control = editor.workspace_tools
	workspace.move_x.get_line_edit().text = "12.5"
	workspace.move_y.get_line_edit().text = "-3.25"
	workspace.angle.get_line_edit().text = "0"
	workspace.scale_mode.select(0)
	workspace.scale_value.get_line_edit().text = "100"
	workspace._apply_exact()
	var editing: String = editor.document.editing_fingerprint()
	var workspace_ok: bool = editor.document.editor_groups.size() == 1 and editor.document.gameplay_objects[2].position == original + Vector2(12.5, -3.25)
	editor.undo()
	workspace_ok = workspace_ok and editor.document.editing_fingerprint() == grouped
	editor.redo()
	workspace_ok = workspace_ok and editor.document.editing_fingerprint() == editing
	fingerprint = editor.document.fingerprint()
	if not workspace_ok or not editor.save_to(target) or not editor.load_from(target) or editor.document.editing_fingerprint() != editing:
		print("PORTABLE_EDITOR_SMOKE: external persistence failed: ", editor.error_dialog.dialog_text)
		push_error("External Act save/reload failed")
		get_tree().quit(1)
		return
	workspace.show_checkpoint_dialog()
	workspace.checkpoint_name.text = "Portable qualification"
	workspace._save_checkpoint()
	workspace.checkpoint_dialog.hide()
	var recovery = load("res://scripts/act_editor/editor_recovery.gd")
	if not recovery.entries().any(func(entry): return entry.label == "Portable qualification" and entry.source == target):
		push_error("Portable recovery checkpoint failed")
		get_tree().quit(1)
		return
	print("PORTABLE_WORKSPACE: group, exact transform, complete Undo/Redo, external save/reopen and checkpoint PASS")
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
