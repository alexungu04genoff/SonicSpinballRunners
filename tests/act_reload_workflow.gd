extends "res://tests/authored_main_game_regression.gd"
## Main-game edit/save/reload loop, including live play and failed disk reads.
const Slots = preload("res://scripts/act_editor/decor_slots.gd")
const Composite = preload("res://scripts/act_editor/composite_terrain.gd")
const RELOAD_PATH := "res://test-results/reload-workflow.tres"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	root.gui_embed_subwindows = true
	var document := fixture()
	check(document.save_document(RELOAD_PATH) == OK, "Reload fixture saves")
	game = ObservedGame.new()
	game.authored_act_path = RELOAD_PATH
	root.add_child(game)
	await frames(5)
	identities = engine_ids()
	check(game.set_theme("chemical_plant"), "Choose Chemical Plant before reloading")
	game.presentation.set_camera_follow(false)
	game.presentation.set_camera_value("zoom", 1.7)
	game.retro_filter.set_preset(2)
	var preferences: Array = [game.theme_id, game.presentation.camera_follow_enabled, game.presentation.camera_preset, game.presentation.camera_settings.duplicate(true), game.retro_filter.preset, game.player_view, DisplayServer.window_get_mode()]
	var mass: Dictionary = Composite.smooth({"shape_id": "rectangle_3x3", "base_size": Vector2i(3, 3), "anchor": Vector2i(1, 1), "quarter_turns": 0, "flip_h": false, "flip_v": false}, 1.0).placement
	document.placements.append(mass)
	document.gameplay_objects[0].position = Vector2(640.25, 450.75)
	document.gameplay_objects[1].rotation_degrees = 22.125
	document.ring_trails = [{"start": Vector2(500, 500), "end": Vector2(650, 500), "spacing": 25.0}]
	document.spawn_position = Vector2(525.25, 900.75)
	document.activation_y = 555.5
	document.exit_start_x = 6
	document.decor_seed = "reload-variants"
	for index in [0, 1, 0]:
		var slot := Slots.make_slot("small")
		slot.position = Vector2(150 + document.decor_slots.size() * 65, 200)
		slot.placement_hint = "surface"
		slot.variant_mode = "fixed"
		slot["variant_index"] = index
		document.decor_slots.append(slot)
	check(document.save_document(RELOAD_PATH) == OK, "Editor-style save updates geometry, objects, rings, markers and decor on disk")
	var saved_bytes := FileAccess.get_file_as_bytes(RELOAD_PATH)
	var old_root: Node = game._authored_root
	game.score = 123
	game.special_meter = 50
	game.launch_ball()
	await frames(3)
	check(not game.ball.serve_pending and not paused, "Reload begins during live play")
	await click(game.reload_act_button)
	await await_rebuild()
	check(not game.act_picker.visible and not paused and not game.controls.input_blocked, "Reload button rebuilds without a picker and restores live pause/input state")
	check(not is_instance_valid(old_root) and game.authored_document.fingerprint() == document.fingerprint(), "Reload reads the latest disk contents and replaces the old geometry")
	check(game.authored_runtime.terrain.size() == 2 and game.presentation.authored_composite_polygons.size() == 1, "Terrain and exact composites rebuild through the active theme")
	check(game.authored_runtime.objects[0].position == document.gameplay_objects[0].position and game.authored_runtime.objects[1].rotation_degrees == 22.125, "Gameplay objects rebuild with saved positions and angles")
	check(game.playfield.ring_positions.size() == 7 and game.ring_field.rings.size() == 7 and game.ring_field.rings.all(func(ring): return ring.active), "Changed ring trail rebuilds as seven uncollected rings")
	check(game.playfield.spawn == document.spawn_position and game.authored_document.activation_y == 555.5 and game.authored_document.exit_start_x == 6, "Reload reads lifecycle and exit markers")
	var variants: Array = []
	for prop in game.presentation.decor_root.get_children(): variants.append(prop.get_meta("decor_variant"))
	check(variants == ["beacon", "valve", "beacon"], "Reload resolves fixed indices through Chemical Plant")
	check(game.ball.serve_pending and game.ball.position == document.spawn_position and game.score == 0 and game.special_meter == 0, "Reload cleanly resets and serves the ball")
	check(preferences == [game.theme_id, game.presentation.camera_follow_enabled, game.presentation.camera_preset, game.presentation.camera_settings, game.retro_filter.preset, game.player_view, DisplayServer.window_get_mode()], "Reload preserves theme, camera settings, overview, retro preset and window state")
	check_identity("Reload retains the authoritative engine, camera and HUD")
	check(FileAccess.get_file_as_bytes(RELOAD_PATH) == saved_bytes, "Reload never writes back to the Act")
	game.set_theme("green_hill")
	document.decor_slots[0].variant_index = 2
	check(document.save_document(RELOAD_PATH) == OK, "Save a generic variant missing from Green Hill")
	paused = true
	await key(KEY_F5)
	await await_rebuild()
	check(paused and not game.controls.input_blocked and game.authored_document.decor_slots[0].variant_index == 2, "F5 reloads while preserving an existing pause")
	check(game.presentation.decor_warnings.size() == 1 and game.presentation.decor_root.get_child_count() == 3 and game.source_note.tooltip_text.contains("using Auto"), "Missing theme variant falls back and reports its warning in the main HUD")
	var stable_root: Node = game._authored_root
	var stable_fingerprint: String = game.authored_document.fingerprint()
	var invalid: Resource = document.copy_document()
	invalid.spawn_position = null
	check(invalid.save_document(RELOAD_PATH) == OK, "An incomplete editor draft can temporarily omit Spawn")
	game.score = 91
	await key(KEY_F5)
	await await_rebuild()
	check(game._authored_root == stable_root and game.authored_document.fingerprint() == stable_fingerprint and game.score == 91 and game.last_source_error.to_lower().contains("spawn"), "Invalid saved draft preserves the playable scene and reports the error")
	check(paused and not game.controls.input_blocked and not game.is_source_picker_open(), "Failed reload restores input and previous pause state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RELOAD_PATH))
	paused = false
	await key(KEY_F5)
	await await_rebuild()
	check(game._authored_root == stable_root and not paused and not game.last_source_error.is_empty(), "Missing file preserves the current Act and restores live state")
	check(document.save_document(RELOAD_PATH) == OK, "Restore the valid saved Act")
	game.toggle_fullscreen()
	await frames(5)
	var view_state := [game.player_view, DisplayServer.window_get_mode(), game.debug_open, game.presentation.camera_follow_enabled, game.presentation.camera_settings.duplicate(true), game.retro_filter.preset]
	await key(KEY_F5)
	await await_rebuild()
	check(game.last_source_error.is_empty() and view_state == [game.player_view, DisplayServer.window_get_mode(), game.debug_open, game.presentation.camera_follow_enabled, game.presentation.camera_settings, game.retro_filter.preset], "F5 works in fullscreen Player View without changing view, camera or retro preferences")
	game.toggle_fullscreen()
	await frames(5)
	check(root.get_visible_rect().encloses(game.reload_act_button.get_global_rect()) and root.get_visible_rect().encloses(game.theme_selector.get_global_rect()) and root.get_visible_rect().encloses(game.fullscreen_button.get_global_rect()), "Reload and neighboring controls fit the development window")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/reload-act-workflow.png") == OK, "Main-game Reload Act control captured")
	game.free()
	paused = false
	await frames(2)
	print("RESULT | Act reload workflow | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
