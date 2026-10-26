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
	if not editor.load_from("res://data/acts/curve_garden.tres"):
		print("PORTABLE_EDITOR_SMOKE: bundled Act load failed: ", editor.error_dialog.dialog_text)
		get_tree().quit(1)
		return
	var fingerprint: String = editor.document.fingerprint()
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
	var game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
	game.authored_act_path = target
	root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var passed: bool = is_instance_valid(game.ball) and is_instance_valid(game.retro_filter) and game.authored_document.fingerprint() == fingerprint
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_user_data_dir().path_join("portable-player.png"))
	game.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(target)
	print("PORTABLE_EDITOR_SMOKE: ", "PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)
