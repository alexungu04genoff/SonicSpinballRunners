extends SceneTree
## Headless shape, transform, validation and fresh-process authoring round-trip checks.

const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const FIXTURE_PATH := "res://test-results/act-geometry-roundtrip.tres"
const EDITED_PATH := "res://test-results/act-geometry-edited.tres"
const INVALID_PATH := "res://test-results/act-geometry-invalid.tres"
const EXPECTED := {
	"wall": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	"corner": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3)],
	"triangle": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	"slope": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3)],
	"j_curve": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3)],
	"rectangle": [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(1, 2), Vector2i(1, 3)],
	"circle": [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)],
	"oval": [Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(2, 3)],
	"bump": [Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)],
	"diagonal": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	"capsule": [Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(2, 3)],
	"outer_corner": [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)],
	"u_curve": [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3)],
}
const OPEN_FAMILIES := ["wall", "corner", "j_curve", "diagonal", "u_curve"]
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL | " + label)


func placement_for(id: String, anchor := Vector2i.ZERO, turns := 0, horizontal := false, vertical := false) -> Dictionary:
	return {
		"shape_id": id,
		"base_size": Shapes.get_definition(id).size,
		"anchor": anchor,
		"quarter_turns": turns,
		"flip_h": horizontal,
		"flip_v": vertical,
	}


func make_fixture() -> Resource:
	var document := Document.new()
	document.title = "Every terrain shape: transforms and intentional overlaps"
	document.cell_size = 47.5
	for definition: Dictionary in Shapes.definitions():
		for turns in 4:
			document.placements.append(placement_for(definition.id, Vector2i(2, 3), turns, turns % 2 == 0, turns >= 2))
	return document


func points_bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func polygon_area(points: PackedVector2Array) -> float:
	var doubled_area := 0.0
	for index in points.size():
		doubled_area += points[index].cross(points[(index + 1) % points.size()])
	return absf(doubled_area) * 0.5


func reference_transform(point: Vector2, size: Vector2i, turns: int, horizontal: bool, vertical: bool) -> Vector2:
	# Rotate about the frame center, then move into the new positive frame.
	# This intentionally does not call the production point-transform helper.
	var result_size := Vector2(size if turns % 2 == 0 else Vector2i(size.y, size.x))
	var result := (point - Vector2(size) * 0.5).rotated(turns * PI * 0.5) + result_size * 0.5
	if horizontal:
		result.x = result_size.x - result.x
	if vertical:
		result.y = result_size.y - result.y
	return result


func check_library() -> void:
	var definitions: Array = Shapes.definitions()
	check(definitions.size() == 52, "All 52 canonical sizes across 13 requested families exist")
	var ids: Dictionary = {}
	for family: String in EXPECTED:
		for size: Vector2i in EXPECTED[family]:
			var id := "%s_%dx%d" % [family, size.x, size.y]
			var definition: Dictionary = Shapes.get_definition(id)
			check(not definition.is_empty(), "Required shape exists: " + id)
			if definition.is_empty():
				continue
			ids[id] = true
			check(definition.size == size, "Canonical frame counts cells exactly: " + id)
			check(not String(definition.label).is_empty() and not String(definition.family).is_empty(), "Readable palette name and family: " + id)
			var closed: bool = definition.closed
			check(closed == not OPEN_FAMILIES.has(family), "Open/closed topology: " + id)
			var points: PackedVector2Array = definition.points
			check(points.size() >= (3 if closed else 2), "Shape contains enough vertices: " + id)
			if points.size() < 2:
				continue
			check(not points[0].is_equal_approx(points[-1]), "No duplicate endpoint introduces accidental closure: " + id)
			var bounds := points_bounds(points)
			if family == "wall":
				check(points.size() == 2 and is_zero_approx(bounds.size.x) and is_equal_approx(bounds.size.y, size.y), "Straight wall remains an open vertical line inside its logical frame: " + id)
			else:
				check(bounds.position.is_equal_approx(Vector2.ZERO) and bounds.size.is_equal_approx(Vector2(size)), "Actual geometry reaches exact frame extents: " + id)
			if closed:
				check(polygon_area(points) > 0.001 and Geometry2D.triangulate_polygon(points).size() > 0, "Closed fill is a valid nonzero polygon: " + id)
			if family == "corner":
				check(points.size() == 3 and is_zero_approx((points[1] - points[0]).dot(points[2] - points[1])), "L corner has exactly two perpendicular segments, no diagonal: " + id)
			if family == "diagonal":
				check(points.size() == 2, "Diagonal has one rail, no triangle boundary: " + id)
			if family == "triangle":
				check(points.size() == 3 and is_equal_approx(polygon_area(points), size.x * size.y * 0.5), "Triangle occupies half its frame: " + id)
			for turns in 4:
				for horizontal in [false, true]:
					for vertical in [false, true]:
						var placement := placement_for(id, Vector2i(4, 6), turns, horizontal, vertical)
						var expected_size: Vector2i = size if turns % 2 == 0 else Vector2i(size.y, size.x)
						check(Shapes.transformed_size(placement) == expected_size, "Quarter-turn frame %s/%d/%s/%s" % [id, turns, horizontal, vertical])
						var transformed: PackedVector2Array = Shapes.transformed_points(placement)
						var matches := transformed.size() == points.size()
						if matches:
							for index in points.size():
								matches = matches and transformed[index].distance_to(reference_transform(points[index], size, turns, horizontal, vertical)) < 0.0001
						check(matches, "Actual points rotate clockwise then mirror on screen axes: %s/%d/%s/%s" % [id, turns, horizontal, vertical])
	for definition: Dictionary in definitions:
		check(ids.has(definition.id), "Catalogue has no unexpected or duplicate substituted sizes: " + str(definition.id))
	check(Shapes.get_definition("missing_shape").is_empty(), "Unknown definitions return no geometry")
	var triangle: Dictionary = Shapes.get_definition("triangle_1x3")
	var original_points: PackedVector2Array = triangle.points.duplicate()
	triangle.points[0] = Vector2(99, 99)
	check(Shapes.get_definition("triangle_1x3").points == original_points, "Callers cannot corrupt shared canonical geometry")
	print("PASS | Canonical library, topology, exact frames and all 16 transforms per shape")


func check_validation() -> void:
	var document := make_fixture()
	check(document.validation_errors().is_empty(), "Intentional overlapping instances are accepted independently")
	check(document.placements.size() == 208, "Every shape appears in all four rotation states")
	var independent: Resource = document.copy_document()
	independent.placements[0].anchor = Vector2i(8, 8)
	check(document.placements[0].anchor == Vector2i(2, 3), "Snapshot placements are independent deep copies")
	var invalid_changes := [
		{"shape_id": "unknown_tile"},
		{"base_size": Vector2i(4, 4)},
		{"anchor": Vector2(1.25, 2.5)},
		{"quarter_turns": 4},
		{"quarter_turns": -1},
		{"quarter_turns": 0.5},
		{"flip_h": 1},
		{"flip_v": "false"},
	]
	for change: Dictionary in invalid_changes:
		var invalid: Resource = document.copy_document()
		invalid.placements[0].merge(change, true)
		check(not invalid.validation_errors().is_empty(), "Malformed placement rejected: " + str(change))
	var incomplete: Resource = document.copy_document()
	incomplete.placements[0].erase("anchor")
	check(not incomplete.validation_errors().is_empty(), "Missing required placement field rejected")
	for field: String in ["format_version", "library_version"]:
		var future: Resource = document.copy_document()
		future.set(field, 99)
		check(not future.validation_errors().is_empty(), "Unsupported " + field + " rejected")
		check(ResourceSaver.save(future, INVALID_PATH) == OK, "Unsupported version fixture written")
		var loaded: Dictionary = Document.load_document(INVALID_PATH)
		check(loaded.document == null and not loaded.error.is_empty(), "Loading unsupported " + field + " reports an error")
	var wrong_type := Resource.new()
	check(ResourceSaver.save(wrong_type, INVALID_PATH) == OK, "Wrong-resource-type fixture written")
	check(Document.load_document(INVALID_PATH).document == null, "Non-Act resource is rejected without replacing the document")
	var malformed: Resource = document.copy_document()
	malformed.placements[0].anchor = Vector2(1.5, 2.5)
	check(ResourceSaver.save(malformed, INVALID_PATH) == OK, "Malformed placement fixture written")
	check(Document.load_document(INVALID_PATH).document == null, "Loading malformed placement fails explicitly")
	check(Document.load_document("res://test-results/nonexistent-act-file.tres").document == null, "Missing file reports a load failure")
	for header_change: Dictionary in [
		{"format_version": true}, {"library_version": 1.5}, {"grid_size": Vector2(12, 12)},
		{"title": 23}, {"cell_size": "50"}, {"placements": [1]}, {"placements": "not an array"},
	]:
		var invalid_header := Document.new()
		for field: String in header_change:
			invalid_header.set(field, header_change[field])
		check(not invalid_header.validation_errors().is_empty(), "Malformed document header rejected: " + str(header_change))
		check(ResourceSaver.save(invalid_header, INVALID_PATH) == OK, "Malformed header fixture written without model validation")
		var invalid_load: Dictionary = Document.load_document(INVALID_PATH)
		check(invalid_load.document == null and not invalid_load.error.is_empty(), "Loading malformed header cannot coerce it into valid authoring data: " + str(header_change))
	print("PASS | Placement validation, overlap acceptance and explicit load failures")


func check_persistence() -> void:
	var document := make_fixture()
	check(document.save_document(FIXTURE_PATH) == OK, "Full authoring fixture saves")
	var saved_text := FileAccess.get_file_as_string(FIXTURE_PATH)
	check(not saved_text.contains("PackedVector2Array") and not saved_text.contains("\"points\""), "Save stores instances and metadata, not duplicated canonical geometry")
	check(saved_text.contains("format_version = 1") and saved_text.contains("library_version = 1"), "Persistent file explicitly records both supported versions")
	for field: String in ["format_version", "library_version"]:
		var missing_version := FileAccess.open(INVALID_PATH, FileAccess.WRITE)
		missing_version.store_string(saved_text.replace(field + " = 1\n", ""))
		missing_version.close()
		check(Document.load_document(INVALID_PATH).document == null, "Missing serialized " + field + " is rejected instead of silently assuming a version")
	var invalid: Resource = document.copy_document()
	invalid.placements[0].quarter_turns = 9
	check(invalid.save_document(FIXTURE_PATH) != OK and FileAccess.get_file_as_string(FIXTURE_PATH) == saved_text, "Rejected save preserves an existing valid file")
	var output: Array = []
	var result := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/act_geometry_regression.gd", "--", "--reload-fixture"
	]), output, true)
	for line in output:
		print(String(line).strip_edges())
	check(result == 0, "A fresh Godot process reloads identical authoring data, edits it and saves again")
	var edited: Dictionary = Document.load_document(EDITED_PATH)
	check(edited.document != null, "Parent can reopen child-edited file without a stale resource cache")
	if edited.document != null:
		document.placements[0].anchor = Vector2i(7, 8)
		document.placements[0].quarter_turns = 3
		document.placements[0].flip_h = false
		check(edited.document.fingerprint() == document.fingerprint(), "Re-saved edits preserve every untouched placement and metadata field")
	var integer_size := Document.new()
	integer_size.cell_size = 50
	check(integer_size.save_document(EDITED_PATH) == OK, "Integer cell size equal to the default float survives ResourceSaver normalization")
	var integer_loaded: Dictionary = Document.load_document(EDITED_PATH)
	check(integer_loaded.document != null and integer_loaded.document.cell_size == 50 and integer_loaded.document.fingerprint() == integer_size.fingerprint(), "Equivalent integer and float cell sizes retain the same authoring fingerprint")


func reload_in_fresh_process() -> void:
	var loaded: Dictionary = Document.load_document(FIXTURE_PATH)
	check(loaded.document != null and loaded.error.is_empty(), "Fresh process loads persistent Act resource")
	if loaded.document != null:
		var expected := make_fixture()
		var actual: Resource = loaded.document
		check(actual.placements == expected.placements, "Fresh process restores every ID, frame, anchor, rotation and mirror exactly")
		check(actual.title == expected.title and actual.grid_size == Vector2i(12, 12) and actual.cell_size == 47.5 and actual.format_version == 1 and actual.library_version == 1, "Fresh process restores document and version metadata")
		check(actual.fingerprint() == expected.fingerprint(), "Fresh process fingerprint matches original data")
		actual.placements[0].anchor = Vector2i(7, 8)
		actual.placements[0].quarter_turns = 3
		actual.placements[0].flip_h = false
		check(actual.save_document(EDITED_PATH) == OK, "Loaded document remains editable and saves again")
	print("RESULT | Fresh-process reload | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	if OS.get_cmdline_user_args().has("--reload-fixture"):
		reload_in_fresh_process()
		return
	check_library()
	check_validation()
	check_persistence()
	print("RESULT | Act geometry | %d checks | %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
