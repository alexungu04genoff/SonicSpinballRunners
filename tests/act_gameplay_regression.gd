extends SceneTree
## Gameplay authoring stays separate from terrain and retains exact stored transforms.
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const ROOT := "res://test-results/act-gameplay"
const SAVED_PATH := ROOT + "/authored.tres"
const EDITED_PATH := ROOT + "/edited.tres"
const INVALID_PATH := ROOT + "/invalid.tres"
const V2_FIXTURE := "res://tests/fixtures/act_format_2.tres"
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL | " + label)

func object_at(id: String, position: Vector2, angle: Variant = null) -> Dictionary:
 var result: Dictionary = Objects.make_placement(id)
 result.object_id = var_to_bytes([id, position, angle]).hex_encode().sha256_text()
 result.position = position
 if angle != null:
  result.rotation_degrees = angle
 return result

func make_fixture() -> Resource:
 var document := Document.new()
 document.title = "Exact gameplay object authoring"
 document.cell_size = 47.5
 document.entry_start_x = 7
 document.entry_width = 2
 document.exit_start_x = 1
 document.exit_width = 3
 document.placements = [{"shape_id": "slope_3x3", "base_size": Vector2i(3, 3),
  "anchor": Vector2i(4, 4), "quarter_turns": 3, "flip_h": true, "flip_v": false}]
 document.gameplay_objects = [
  object_at("round_bumper", Vector2(438.5, 271.25)),
  object_at("left_flipper", Vector2(320.0, 610.5)),
  object_at("triangle_bumper", Vector2(438.5, 271.25), 32),
  object_at("right_flipper", Vector2(320.125, 610.5), 161.12345678901235),
  object_at("triangle_bumper", Vector2(438.512345678901, -271.25123456789), 32.123456789012345),
  object_at("round_bumper", Vector2(-0.0000123456789, 10000.987654321), -725.1234567890123),
 ]
 # Nontrivial fractions exercise native ResourceSaver's Vector2 and double precision.
 var random := RandomNumberGenerator.new()
 random.seed = 377481
 var ids := ["round_bumper", "triangle_bumper", "left_flipper", "right_flipper"]
 for index in 64:
  var position := Vector2(random.randf_range(-1700, 2300) / 3.7, random.randf_range(-900, 4500) / 7.3)
  var angle := random.randf_range(-1500, 1500) / 2.9
  document.gameplay_objects.append(object_at(ids[index % ids.size()], position, angle))
 return document

func exact_transform(a: Dictionary, b: Dictionary) -> bool:
 return a.type == b.type and var_to_bytes(a.position) == var_to_bytes(b.position) and var_to_bytes(float(a.rotation_degrees)) == var_to_bytes(float(b.rotation_degrees))

func check_exact_layout(actual: Resource, expected: Resource, context: String) -> void:
 check(actual.gameplay_objects.size() == expected.gameplay_objects.size(), context + ": every object survives")
 if actual.gameplay_objects.size() != expected.gameplay_objects.size():
  return
 for index in expected.gameplay_objects.size():
  check(exact_transform(actual.gameplay_objects[index], expected.gameplay_objects[index]), context + ": byte-exact coordinates and angle for object " + str(index))
 check(actual.placements == expected.placements, context + ": terrain grid transforms remain unchanged")
 check(actual.get_connector("entry") == expected.get_connector("entry") and actual.get_connector("exit") == expected.get_connector("exit"), context + ": connector spans remain unchanged")
 check(actual.fingerprint() == expected.fingerprint(), context + ": complete authoring fingerprint matches")

func bounds_of(points: PackedVector2Array) -> Rect2:
 var minimum := points[0]
 var maximum := points[0]
 for point: Vector2 in points:
  minimum = minimum.min(point)
  maximum = maximum.max(point)
 return Rect2(minimum, maximum - minimum)

func check_definitions() -> void:
 var definitions: Array = Objects.definitions()
 check(definitions.size() == 10, "Gameplay palette contains the four original objects and six authored mechanics")
 var ids: Array = definitions.map(func(definition: Dictionary): return definition.id)
 for id: String in ["round_bumper", "triangle_bumper", "left_flipper", "right_flipper"]:
  check(ids.has(id), "Gameplay definition exists: " + id)
  var definition: Dictionary = Objects.get_definition(id)
  check(typeof(definition.label) == TYPE_STRING and typeof(definition.color) == TYPE_COLOR, "Gameplay definition has a readable label and preview color")
  var placement := Objects.make_placement(id)
  check(placement.type == id and placement.position == Vector2.ZERO and typeof(placement.rotation_degrees) == TYPE_FLOAT, "Factory defines an exact local anchor and float rest angle")
  var points := Objects.local_points(placement, 50.0)
  check(points.size() >= 3 and Geometry2D.triangulate_polygon(points).size() > 0, "Gameplay preview is a valid closed silhouette: " + id)
  placement.rotation_degrees += 17.25
  placement.position = Vector2(438.5, 271.25)
  check(Objects.local_points(placement, 50.0) == points, "Preview points stay local and unrotated: " + id)
 check(Objects.get_definition("ring").is_empty() and Objects.make_placement("ring").is_empty(), "Out-of-scope gameplay objects are not offered")
 check(Objects.local_points({"type": "unknown"}, 50.0).is_empty(), "Unknown preview types have no geometry")
 for cell_size: float in [25.0, 47.5, 50.0, 100.0]:
  var bumper := Objects.make_placement("round_bumper")
  bumper.position = Vector2(438.5, 271.25)
  var before := bumper.duplicate(true)
  var bounds := bounds_of(Objects.local_points(bumper, cell_size))
  check(bounds.size == Vector2.ONE * cell_size * 0.5 and bounds.get_center() == Vector2.ZERO, "Round bumper diameter is half a cell and remains centered: " + str(cell_size))
  check(bumper == before, "Sizing a bumper never changes its authored position or angle")
  var sling := Objects.make_placement("triangle_bumper")
  var sling_points := Objects.local_points(sling, cell_size)
  var sling_bounds := bounds_of(sling_points)
  check(is_equal_approx(sling_bounds.size.y / cell_size, 0.6) and sling_bounds.size.x < sling_bounds.size.y, "Sling dominant dimension is 0.6 cell")
  check(sling_points[0].is_equal_approx(Vector2(-40, 35) * cell_size / 150.0) and sling_points[1].is_equal_approx(Vector2(-15, -55) * cell_size / 150.0) and sling_points[2].is_equal_approx(Vector2(45, 35) * cell_size / 150.0), "Sling scales uniformly about its existing authored origin")
  for hand: String in ["left_flipper", "right_flipper"]:
   var flipper_bounds := bounds_of(Objects.local_points(Objects.make_placement(hand), cell_size))
   check(flipper_bounds.position.is_equal_approx(Vector2(-0.05, -0.05) * cell_size) and flipper_bounds.size.is_equal_approx(Vector2(0.75, 0.1) * cell_size), "Flipper is 0.75 cell long and 0.1 cell thick, with its rounded pivot centered at the saved origin: " + hand)
 var document := make_fixture()
 var fingerprint: String = document.fingerprint()
 for cell_size: float in [25.0, 100.0]:
  for placement: Dictionary in document.gameplay_objects:
   Objects.local_points(placement, cell_size)
 check(document.fingerprint() == fingerprint, "Resolving every object at different preview sizes never mutates stored transforms or terrain")
 var left := Objects.make_placement("left_flipper")
 var right := Objects.make_placement("right_flipper")
 check(absf(deg_to_rad(left.rotation_degrees) - 0.32) < 1e-12 and absf(deg_to_rad(right.rotation_degrees) - (PI - 0.32)) < 1e-12, "Left and right factories use actual resting orientations")
 check(absf(deg_to_rad(left.rotation_degrees - Objects.FLIPPER_SWING_DEGREES) + 0.48) < 1e-12 and absf(deg_to_rad(right.rotation_degrees + Objects.FLIPPER_SWING_DEGREES) - (PI + 0.48)) < 1e-12, "Handed swing direction reaches the current active angle")
 definitions[0].label = "Changed by caller"
 check(Objects.get_definition("round_bumper").label == "Round Bumper", "Palette callers cannot mutate shared definitions")
 print("PASS | Four pure-data object definitions and cell-relative preview dimensions")

func check_validation_and_copy() -> void:
 var document := make_fixture()
 check(document.validation_errors().is_empty(), "Exact gameplay coordinates, arbitrary angles and overlaps are valid")
 check(document.gameplay_objects[1].position.y > document.grid_size.y * document.cell_size, "Fixture includes a freely authored pivot outside the terrain grid")
 var copy: Resource = document.copy_document()
 check(copy.fingerprint() == document.fingerprint(), "History snapshot includes exact gameplay objects")
 copy.gameplay_objects[0].position += Vector2(0.03125, -0.0625)
 check(document.gameplay_objects[0].position == Vector2(438.5, 271.25), "Snapshot object dictionaries do not share mutations")
 check(copy.fingerprint() != document.fingerprint(), "Sub-grid movement marks the document changed")
 copy = document.copy_document()
 copy.gameplay_objects[4].rotation_degrees += 0.0000000000001
 check(copy.fingerprint() != document.fingerprint(), "Fine authored angle changes affect the fingerprint")
 copy = document.copy_document()
 copy.gameplay_objects[2].rotation_degrees = 32.0
 check(copy.fingerprint() == document.fingerprint(), "Equivalent integer and float angle input has the same fingerprint")
 var malformed_objects := [
  {"type": "ring"}, {"type": 1}, {"position": Vector2i(438, 271)},
  {"position": Vector2(INF, 1)}, {"position": Vector2(1, NAN)},
  {"rotation_degrees": true}, {"rotation_degrees": "32"},
  {"rotation_degrees": INF}, {"rotation_degrees": NAN}, {"anchor": Vector2i.ZERO},
 ]
 for change: Dictionary in malformed_objects:
  var invalid: Resource = document.copy_document()
  invalid.gameplay_objects[0].merge(change, true)
  check(not invalid.validation_errors().is_empty(), "Malformed gameplay data is rejected: " + str(change))
  check(ResourceSaver.save(invalid, INVALID_PATH) == OK, "Malformed object fixture is written without model validation")
  check(Document.load_document(INVALID_PATH).document == null, "Malformed object fields cannot be silently coerced during load")
 for field: String in ["type", "position", "rotation_degrees"]:
  var invalid: Resource = document.copy_document()
  invalid.gameplay_objects[0].erase(field)
  check(not invalid.validation_errors().is_empty(), "Required object field cannot be omitted: " + field)
 for value: Variant in ["not an array", [12]]:
  var invalid: Resource = document.copy_document()
  invalid.gameplay_objects = value
  check(not invalid.validation_errors().is_empty(), "Object collection has strict array/dictionary structure")
 for payload: PackedByteArray in [PackedByteArray(), PackedByteArray([2, 0, 0, 0]), var_to_bytes("32"), var_to_bytes({"angle": 32}), var_to_bytes(INF)]:
  var invalid: Resource = document.copy_document()
  invalid.gameplay_objects[0].rotation_degrees = payload
  check(ResourceSaver.save(invalid, INVALID_PATH) == OK, "Malformed stored-angle fixture is written")
  var rejected: Dictionary = Document.load_document(INVALID_PATH)
  check(rejected.document == null and not rejected.error.is_empty(), "Malformed/non-numeric/nonfinite angle payload is rejected cleanly")
 print("PASS | Exact local coordinates, overlap, independent snapshots and validation")

func check_previous_format() -> void:
 var source := FileAccess.get_file_as_string(V2_FIXTURE)
 var loaded: Dictionary = Document.load_document(V2_FIXTURE)
 check(loaded.document != null and loaded.error.is_empty(), "Previous terrain-and-connector Acts still load")
 if loaded.document != null:
  var document: Resource = loaded.document
  check(document.format_version == Document.FORMAT_VERSION and document.library_version == Shapes.VERSION, "Previous format becomes current in memory")
  check(document.gameplay_objects.is_empty(), "Previous Acts start with no gameplay objects")
  check(document.placements == [{"shape_id": "triangle_3x2", "base_size": Vector2i(3, 2), "anchor": Vector2i(4, 5), "quarter_turns": 3, "flip_h": true, "flip_v": false}], "Previous terrain identity and transforms are unchanged")
  check(document.entry_start_x == 7 and document.entry_width == 2 and document.exit_start_x == 1 and document.exit_width == 3 and document.cell_size == 47.5, "Previous connector spans and cell size are unchanged")
  document.gameplay_objects.append(object_at("round_bumper", Vector2(438.5, 271.25)))
  check(document.save_document(EDITED_PATH) == OK, "Loaded previous-format Act accepts an object and saves current format")
  var reopened: Dictionary = Document.load_document(EDITED_PATH)
  check(reopened.document != null and reopened.document.fingerprint() == document.fingerprint(), "Updated previous-format Act reopens with its exact new object")
 check(FileAccess.get_file_as_string(V2_FIXTURE) == source, "Loading and saving elsewhere do not modify the previous-format source")
 print("PASS | Existing terrain/connector format loads with an empty gameplay collection")

func apply_edits(document: Resource) -> void:
 document.gameplay_objects[0].position = Vector2(488.1234567890123, 321.9876543210987)
 document.gameplay_objects[1].rotation_degrees = -17.123456789012345
 document.gameplay_objects.append(object_at("right_flipper", Vector2(-125.375, 710.03125), 201.33333333333334))

func check_persistence() -> void:
 var document := make_fixture()
 check(document.save_document(SAVED_PATH) == OK, "Terrain, connectors and exact gameplay objects save together")
 var source := FileAccess.get_file_as_string(SAVED_PATH)
 check(source.contains("format_version = " + str(Document.FORMAT_VERSION)) and source.contains("gameplay_objects = ["), "Current native Resource explicitly stores its format and separate object array")
 check(source.contains("\"rotation_degrees\": PackedByteArray(") and not source.contains("rotation_bits"), "One lossless numeric payload stores each angle without a duplicate authority")
 check(typeof(document.gameplay_objects[0].rotation_degrees) == TYPE_FLOAT and typeof(document.gameplay_objects[2].rotation_degrees) == TYPE_INT, "Saving leaves the live authored angles numeric and unchanged")
 var loaded: Dictionary = Document.load_document(SAVED_PATH)
 check(loaded.document != null, "Current-format authoring file reopens")
 if loaded.document == null:
  return
 check_exact_layout(loaded.document, document, "First reload")
 # Several reopen/save cycles protect against cumulative text serialization drift.
 for cycle in 3:
  check(loaded.document.save_document(SAVED_PATH) == OK, "Repeated exact save " + str(cycle + 1))
  loaded = Document.load_document(SAVED_PATH)
  if loaded.document == null:
   check(false, "Repeated saved file reopens")
   return
  check_exact_layout(loaded.document, document, "Repeated reload " + str(cycle + 1))
 var invalid: Resource = document.copy_document()
 invalid.gameplay_objects[0].position = Vector2(INF, 0)
 var before_rejected_save := FileAccess.get_file_as_string(SAVED_PATH)
 check(invalid.save_document(SAVED_PATH) != OK and FileAccess.get_file_as_string(SAVED_PATH) == before_rejected_save, "Invalid object save retains the existing valid authored file")
 var output: Array = []
 var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
  "--headless", "--path", ProjectSettings.globalize_path("res://"),
  "--script", "res://tests/act_gameplay_regression.gd", "--", "--reload-gameplay"
 ]), output, true)
 for line: Variant in output:
  print(String(line).strip_edges())
 check(exit_code == 0, "Fresh Godot process reloads, edits and saves authored gameplay data")
 var edited: Dictionary = Document.load_document(EDITED_PATH)
 check(edited.document != null, "Parent reopens the child-edited file")
 if edited.document != null:
  apply_edits(document)
  check_exact_layout(edited.document, document, "Child-edited reload")

func reload_in_fresh_process() -> void:
 var loaded: Dictionary = Document.load_document(SAVED_PATH)
 check(loaded.document != null and loaded.error.is_empty(), "Fresh process loads complete authored Act")
 if loaded.document != null:
  check_exact_layout(loaded.document, make_fixture(), "Fresh-process reload")
  apply_edits(loaded.document)
  check(loaded.document.save_document(EDITED_PATH) == OK, "Fresh process edits exact positions/angles and saves again")
 print("RESULT | Fresh-process gameplay | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
 if OS.get_cmdline_user_args().has("--reload-gameplay"):
  reload_in_fresh_process()
  return
 check_definitions()
 check_validation_and_copy()
 check_previous_format()
 check_persistence()
 print("RESULT | Act gameplay | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
