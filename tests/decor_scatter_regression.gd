extends "res://tests/act_gameplay_editor_smoke.gd"
const Slots = preload("res://scripts/act_editor/decor_slots.gd")
const Scatter = preload("res://scripts/act_editor/decor_scatter.gd")
const SAVE := "res://test-results/decor-scatter.tres"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	var act := ActData.new()
	for y in 4:
		for x in 4:
			act.placements.append({"shape_id": "rectangle_3x3", "base_size": Vector2i(3, 3), "anchor": Vector2i(x * 3, y * 3), "quarter_turns": 0, "flip_h": false, "flip_v": false})
	for type: String in Slots.TYPES:
		var slot := Slots.make_slot(type)
		slot.position = Vector2(100 + act.decor_slots.size() * 100, 100)
		act.decor_slots.append(slot)
	check(act.validation_errors().is_empty(), "Scatter fixture is valid")
	var original := act.fingerprint()
	var generated := Scatter.generate(act, 40, 123)
	check(not generated.is_empty() and generated == Scatter.generate(act, 40, 123), "Same seed produces repeatable scatter")
	check(act.fingerprint() == original, "Scatter does not mutate source data")
	check(generated != Scatter.generate(act, 40, 124), "Another seed changes positions and transforms")
	var medium := 0
	var angles: Dictionary = {}
	var scales: Dictionary = {}
	var valid := true
	var spaced := true
	var occupied: Array = act.decor_slots.duplicate(true)
	for slot: Dictionary in generated:
		if slot.slot_type == "medium": medium += 1
		valid = valid and Slots.validation_error(slot).is_empty() and slot.slot_type in ["small", "medium"]
		valid = valid and slot.rotation_degrees >= 0 and slot.rotation_degrees < 360
		angles[slot.rotation_degrees] = true
		scales[slot.scale] = true
		for other: Dictionary in occupied:
			spaced = spaced and slot.position.distance_to(other.position) >= Scatter.radius(slot, act.cell_size) + Scatter.radius(other, act.cell_size)
		occupied.append(slot)
	check(valid and angles.size() > 4 and scales.size() > 4, "Generated small/medium slots have varied valid scale and rotation")
	check(absf(float(medium) / generated.size() - .25) < .02, "Roomy terrain receives the 75/25 mix, rounded to whole props")
	check(spaced, "Scatter respects clearance from manual and generated props")
	check(Scatter.generate(act, 15, 123).size() < generated.size() and Scatter.generate(act, 80, 123).size() > generated.size(), "Frequency controls population")
	check(Scatter.generate(act, 0, 123).is_empty() and Scatter.generate(ActData.new(), 100, 123).is_empty(), "Zero density and empty terrain generate nothing")
	for percent: int in [0, 20, 50, 80, 100]:
		var mixed := Scatter.generate(act, 20, 123, percent)
		var small_count := mixed.filter(func(slot): return slot.slot_type == "small").size()
		check(not mixed.is_empty() and absi(small_count - roundi(mixed.size() * percent / 100.0)) <= 1, "Configurable mix honors %d%% small, including single-size endpoints" % percent)
	var dense := Scatter.generate(act, 500, 123, 100)
	check(dense.size() > Scatter.generate(act, 100, 123, 100).size() and dense.size() <= Scatter.MAX_SLOTS, "Frequency above 100% fills more available space within the prop limit")
	var dense_clear := true
	occupied = act.decor_slots.duplicate(true)
	for slot: Dictionary in dense:
		var clearance := Scatter.radius(slot, act.cell_size)
		dense_clear = dense_clear and act.terrain_bounds().grow(-clearance).has_point(slot.position)
		for other: Dictionary in occupied:
			dense_clear = dense_clear and slot.position.distance_to(other.position) >= clearance + Scatter.radius(other, act.cell_size) + act.cell_size * .08
		occupied.append(slot)
	check(dense_clear, "Maximum frequency retains terrain and prop clearance")
	var curved: Resource = ActData.load_document("res://data/acts/decor_loop_court.tres").document
	var on_terrain := true
	var curved_scatter := Scatter.generate(curved, 80, 99)
	var curved_medium := 0
	for slot: Dictionary in curved_scatter:
		if slot.slot_type == "medium": curved_medium += 1
		for side in 32:
			var point: Vector2 = slot.position + Vector2.from_angle(TAU * side / 32.0) * Scatter.radius(slot, curved.cell_size)
			on_terrain = on_terrain and Slots.supported_in_document(point, curved)
	check(not curved_scatter.is_empty() and on_terrain, "Curved and disconnected terrain supports each scattered footprint")
	check(curved_medium <= roundi(curved_scatter.size() * .25), "Crowded islands keep the small-prop majority")
	var old := act._storage_document()
	old.format_version = 11
	ResourceSaver.save(old, SAVE)
	var bytes := FileAccess.get_file_as_bytes(SAVE)
	check(ActData.load_document(SAVE).document.fingerprint() == original and bytes == FileAccess.get_file_as_bytes(SAVE), "Format 11 migrates without rewriting or treating manual props as scatter")
	old.decor_slots.append(generated[0])
	ResourceSaver.save(old, SAVE)
	check(ActData.load_document(SAVE).document == null, "Old formats cannot claim scatter ownership")
	var invalid: Dictionary = generated[0].duplicate(true)
	invalid.placement_source = true
	check(not Slots.validation_error(invalid).is_empty(), "Malformed ownership rejects")
	root.gui_embed_subwindows = true
	editor = EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.document = act
	editor.canvas.set_document(act)
	editor._refresh()
	await choose_tab(3)
	var manual := var_to_bytes(act.decor_slots)
	var history: int = editor.undo_stack.size()
	await click_control(editor.buttons.decor_randomize)
	check(editor.document.decor_slots.size() > 4 and editor.undo_stack.size() == history + 1, "Randomize button scatters in one undo step")
	var first: String = editor.document.fingerprint()
	var first_count: int = editor.document.decor_slots.size()
	await click_control(editor.buttons.decor_randomize)
	check(editor.document.fingerprint() != first and editor.document.decor_slots.size() <= first_count + 4, "A second click rerolls instead of accumulating props")
	check(var_to_bytes(editor.document.decor_slots.slice(0, 4)) == manual, "All four manual sizes remain byte-identical")
	var second: String = editor.document.fingerprint()
	editor.undo()
	check(editor.document.fingerprint() == first, "Undo restores the complete previous scatter")
	editor.redo()
	check(editor.document.fingerprint() == second, "Redo restores the exact reroll")
	check(editor.save_to(SAVE) and editor.load_from(SAVE) and editor.document.fingerprint() == second, "Save/reload preserves scatter ownership and transforms")
	var edited: Dictionary = editor.document.decor_slots[4].duplicate(true)
	edited.rotation_degrees += 5
	editor.set_decor_slot(4, edited)
	var protected_id: String = edited.slot_id
	check(not editor.document.decor_slots[4].has("placement_source"), "Editing a scattered slot makes it manual")
	await click_control(editor.buttons.decor_randomize)
	check(editor.document.decor_slots[4].slot_id == protected_id, "Reroll preserves the hand-edited prop")
	editor.decor_frequency_field.value = 0
	await click_control(editor.buttons.decor_randomize)
	check(editor.document.decor_slots.size() == 5, "Zero frequency clears only scatter, retaining all manual props")
	editor.undo()
	check(editor.document.decor_slots.size() > 5, "Clear scatter can be undone")
	var before_settings: String = editor.document.fingerprint()
	editor.decor_frequency_field.value = 237
	editor.decor_small_percent_field.value = 100
	check(editor.decor_frequency_field.value == 237 and editor.decor_medium_percent_label.text == "Medium 0%" and editor.document.fingerprint() == before_settings, "Fine frequency and complementary mix controls wait for Randomize")
	await click_control(editor.buttons.decor_randomize)
	check(editor.document.decor_slots.slice(5).all(func(slot): return slot.slot_type == "small"), "Randomize uses the chosen all-small mix")
	editor.decor_small_percent_field.value = 0
	await click_control(editor.buttons.decor_randomize)
	check(editor.document.decor_slots.size() > 5 and editor.document.decor_slots.slice(5).all(func(slot): return slot.slot_type == "medium"), "Randomize uses the chosen all-medium mix")
	editor.composite_preview_active = true
	editor._refresh()
	var blocked: String = editor.document.fingerprint()
	editor.randomize_decor()
	check(editor.buttons.decor_randomize.disabled and not editor.decor_small_percent_field.editable and editor.document.fingerprint() == blocked, "Pending terrain preview blocks randomization and mix editing")
	editor.composite_preview_active = false
	if DisplayServer.get_name() != "headless":
		editor.load_from("res://data/acts/decor_loop_court.tres")
		# Show hand-authored landmarks with scattered small dressing. Only this
		# in-memory capture draft changes; the saved example is untouched.
		editor.document.decor_slots = editor.document.decor_slots.filter(func(slot): return slot.slot_type in ["large", "landmark"])
		editor.decor_frequency_field.value = 150
		editor.decor_small_percent_field.value = 65
		editor.randomize_decor()
		await choose_tab(3)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-results/decor-scatter-editor.png") == OK, "Scatter editor screenshot saved")
	editor.free()
	await process_frame
	print("RESULT | Decor scatter | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
