extends SceneTree
## Editor resize gestures, preservation, undo, persistence and current steering defaults.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var editor = load("res://scenes/act_geometry_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	var original: String = editor.document.fingerprint()
	editor.grid_width_field.get_line_edit().text = "16"
	editor.grid_height_field.get_line_edit().text = "24"
	editor.buttons.resize_grid.pressed.emit()
	check(editor.document.grid_size == Vector2i(16, 24), "Resize applies typed width and height together")
	editor.undo()
	check(editor.document.fingerprint() == original, "Undo restores the exact original Act")
	editor.redo()
	check(editor.document.grid_size == Vector2i(16, 24), "Redo restores resized dimensions")
	editor.document.spawn_position = Vector2(700, 1100)
	var before: String = editor.document.fingerprint()
	var history: int = editor.undo_stack.size()
	editor.grid_width_field.value = 12
	editor.grid_height_field.value = 12
	editor.buttons.resize_grid.pressed.emit()
	check(editor.document.fingerprint() == before and editor.undo_stack.size() == history, "Invalid shrink preserves content and history")
	var path := "user://grid-resize-regression.tres"
	check(editor.save_to(path), "Resized Act saves")
	check(editor.load_from(path) and editor.document.grid_size == Vector2i(16, 24) and editor.document.spawn_position == Vector2(700, 1100), "Dimensions and content survive reload")
	DirAccess.remove_absolute(path)
	for profile: PhysicsProfile in PhysicsTuning.PROFILES:
		check(is_equal_approx(profile.steering_strength, 0.05), "Every shipped profile has half steering strength")
		var current := PhysicsTuning.resolve(profile, {}, [])
		var previous := current.duplicate()
		previous.steering_strength = 0.1
		for velocity: float in [0.0, -500.0]:
			var light := PlaygroundBall.steering_step(0.0, 1.0, current, 1.0 / 120.0, velocity)
			var full := PlaygroundBall.steering_step(0.0, 1.0, previous, 1.0 / 120.0, velocity)
			check(is_equal_approx(light * 2.0, full), "Steering and counter-steering are halved before saturation")
	editor.queue_free()
	await process_frame
	print("GRID_RESIZE_REGRESSION: %d failures" % failures)
	quit(0 if failures == 0 else 1)
