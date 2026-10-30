extends SceneTree
## Optional Act lifecycle metadata, system gutter bounds and exact persistence.
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const ROOT := "res://test-results/act-lifecycle"
const SAVED_PATH := ROOT + "/authored.tres"
const EDITED_PATH := ROOT + "/edited.tres"
const INVALID_PATH := ROOT + "/invalid.tres"
const PREVIOUS_FILES := ["res://tests/fixtures/act_format_2.tres", "res://tests/fixtures/act_format_3.tres"]
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL | " + label)

func make_fixture() -> Resource:
 var document := Document.new()
 document.title = "Authored Act lifecycle"
 document.entry_start_x = 7
 document.entry_width = 2
 document.exit_start_x = 1
 document.exit_width = 3
 document.activation_y = 1234.56789 / 3.7
 document.spawn_position = Vector2(320.123456789, 525.03125)
 document.placements = [{"shape_id": "rectangle_3x3", "base_size": Vector2i(3, 3),
  "anchor": Vector2i(2, 4), "quarter_turns": 3, "flip_h": true, "flip_v": false}]
 var bumper: Dictionary = Objects.make_placement("round_bumper")
 bumper.object_id = "lifecycle_bumper"
 bumper.position = Vector2(438.5, 271.25)
 var flipper: Dictionary = Objects.make_placement("left_flipper")
 flipper.object_id = "lifecycle_flipper"
 flipper.position = Vector2(320, 610.5)
 flipper.rotation_degrees += 1.0 / 7.0
 document.gameplay_objects = [bumper, flipper]
 return document

func exact_number(value: Variant) -> PackedByteArray:
 return var_to_bytes(float(value)) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else var_to_bytes(value)

func check_exact_layout(actual: Resource, expected: Resource, context: String) -> void:
 check(exact_number(actual.activation_y) == exact_number(expected.activation_y), context + ": activation retains exact scalar bits")
 check(var_to_bytes(actual.spawn_position) == var_to_bytes(expected.spawn_position), context + ": spawn retains exact Vector2 bits")
 check(actual.placements == expected.placements and actual.gameplay_objects == expected.gameplay_objects, context + ": terrain and gameplay transforms remain unchanged")
 check(actual.get_connector("entry") == expected.get_connector("entry") and actual.get_connector("exit") == expected.get_connector("exit"), context + ": connector spans remain unchanged")
 check(actual.grid_size == Vector2i(12, 12), context + ": terrain remains exactly 12 by 12")
 check(actual.fingerprint() == expected.fingerprint(), context + ": entire document fingerprint matches")

func check_bounds_and_drafts() -> void:
 var document := Document.new()
 check(document.activation_y == null and document.spawn_position == null, "Lifecycle markers start unset")
 check(document.validation_errors().is_empty(), "Incomplete draft is valid without any markers")
 check(Document.RED_GUTTER_CELLS == 1, "System gutter height comes from one shared cell constant")
 check(document.terrain_bounds() == Rect2(0, 0, 600, 600), "Terrain bounds remain the original 12 by 12 cells")
 check(document.red_gutter_bounds() == Rect2(0, 600, 600, 50), "Gutter is one cell tall and begins outside terrain")
 check(not document.terrain_bounds().intersects(document.red_gutter_bounds()), "Gutter and terrain interiors do not overlap")
 check(not document.terrain_bounds().has_point(Vector2(300, 625)), "Gutter cannot become an authored terrain row")
 document.placements = [{"shape_id": "rectangle_1x1", "base_size": Vector2i.ONE, "anchor": Vector2i(0, 11), "quarter_turns": 0, "flip_h": false, "flip_v": false}]
 check(document.validation_errors().is_empty(), "Terrain still fits in its twelfth row")
 document.placements[0].anchor.y = 12
 check(not document.validation_errors().is_empty(), "Terrain placement in the red gutter is rejected")
 document.placements.clear()
 for activation: Variant in [0, 500, 599.999, null]:
  document.activation_y = activation
  check(document.validation_errors().is_empty(), "Activation accepts top/inside/unset: " + str(activation))
 document.activation_y = null
 for spawn: Variant in [Vector2.ZERO, Vector2(438.5, 271.25), Vector2(599.999, 599.999), null]:
  document.spawn_position = spawn
  check(document.validation_errors().is_empty(), "Spawn accepts top-left/inside/unset: " + str(spawn))
 document.cell_size = 47.5
 check(document.terrain_bounds() == Rect2(0, 0, 570, 570) and document.red_gutter_bounds() == Rect2(0, 570, 570, 47.5), "Bounds follow configured cell size without changing grid dimensions")
 check(document.grid_size == Vector2i(12, 12), "Bounds helpers never mutate the grid")
 print("PASS | Optional markers and a separate one-cell system gutter")

func check_validation_and_snapshots() -> void:
 var document := make_fixture()
 check(document.validation_errors().is_empty(), "Lifecycle markers coexist with terrain, connectors and freely authored objects")
 var snapshot: Resource = document.copy_document()
 check(snapshot.fingerprint() == document.fingerprint(), "Snapshot retains both lifecycle markers")
 document.activation_y += 0.03125
 document.spawn_position += Vector2(0.125, -0.25)
 check(snapshot.activation_y != document.activation_y and snapshot.spawn_position != document.spawn_position, "Lifecycle snapshot data is independent")
 check(snapshot.fingerprint() != document.fingerprint(), "Marker edits change the dirty fingerprint")
 document.activation_y = null
 document.spawn_position = null
 check(document.validation_errors().is_empty() and snapshot.activation_y != null and snapshot.spawn_position != null, "Deleting both markers leaves a valid draft and preserves the previous snapshot")
 check(document.fingerprint() != snapshot.fingerprint(), "Deletion changes the authoring fingerprint")
 var integer_y := Document.new()
 integer_y.activation_y = 500
 var float_y: Resource = integer_y.copy_document()
 float_y.activation_y = 500.0
 check(integer_y.fingerprint() == float_y.fingerprint(), "Equivalent integer/float activation coordinates have equal fingerprints")
 for activation: Variant in [true, "500", Vector2(1, 2), NAN, INF, -0.01, 600, 625]:
  var invalid: Resource = snapshot.copy_document()
  invalid.activation_y = activation
  var before := var_to_bytes(invalid.activation_y)
  check(not invalid.validation_errors().is_empty(), "Invalid activation is reported: " + str(activation))
  check(var_to_bytes(invalid.activation_y) == before, "Activation validation never repairs or clamps input")
  check(ResourceSaver.save(invalid, INVALID_PATH) == OK, "Malformed activation fixture is written")
  check(Document.load_document(INVALID_PATH).document == null, "Loading malformed activation fails explicitly")
 for spawn: Variant in [Vector2i(1, 2), 42, true, "spawn", Vector2(NAN, 1), Vector2(1, INF), Vector2(-0.01, 200), Vector2(600, 300), Vector2(300, 600), Vector2(300, 625)]:
  var invalid: Resource = snapshot.copy_document()
  invalid.spawn_position = spawn
  var before := var_to_bytes(invalid.spawn_position)
  check(not invalid.validation_errors().is_empty(), "Invalid spawn is reported: " + str(spawn))
  check(var_to_bytes(invalid.spawn_position) == before, "Spawn validation never repairs or clamps input")
  check(ResourceSaver.save(invalid, INVALID_PATH) == OK, "Malformed spawn fixture is written")
  check(Document.load_document(INVALID_PATH).document == null, "Loading malformed spawn fails explicitly")
 for payload: PackedByteArray in [PackedByteArray(), PackedByteArray([2, 0, 0, 0]), var_to_bytes("500"), var_to_bytes(null), var_to_bytes(INF)]:
  var invalid: Resource = snapshot.copy_document()
  invalid.activation_y = payload
  check(ResourceSaver.save(invalid, INVALID_PATH) == OK, "Malformed stored activation fixture is written")
  var rejected: Dictionary = Document.load_document(INVALID_PATH)
  check(rejected.document == null and not rejected.error.is_empty(), "Malformed activation bytes cannot silently become an unset marker")
 print("PASS | Half-open marker bounds, exact snapshots and authoring validation")

func check_previous_formats() -> void:
 for path: String in PREVIOUS_FILES:
  var source := FileAccess.get_file_as_string(path)
  var raw: Resource = ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
  var result: Dictionary = Document.load_document(path)
  check(result.document != null and result.error.is_empty(), "Previous Act format loads: " + path)
  if result.document == null:
   continue
  var document: Resource = result.document
  check(document.format_version == Document.FORMAT_VERSION and document.activation_y == null and document.spawn_position == null, "Previous Acts gain unset lifecycle markers in memory")
  check(document.placements == raw.placements and document.get_connector("entry") == raw.get_connector("entry") and document.get_connector("exit") == raw.get_connector("exit"), "Previous terrain and connectors remain exact")
  check(document.gameplay_objects.size() == raw.gameplay_objects.size(), "Previous gameplay object count remains exact")
  for index in raw.gameplay_objects.size():
   var original: Dictionary = raw.gameplay_objects[index]
   var restored: Dictionary = document.gameplay_objects[index]
   check(restored.type == original.type and var_to_bytes(restored.position) == var_to_bytes(original.position) and var_to_bytes(restored.rotation_degrees) == original.rotation_degrees, "Previous gameplay position and encoded angle bits remain exact")
  document.activation_y = 400.125
  document.spawn_position = Vector2(438.5, 271.25)
  check(document.save_document(EDITED_PATH) == OK, "Previous Act accepts lifecycle markers and saves current format")
  var reopened: Dictionary = Document.load_document(EDITED_PATH)
  check(reopened.document != null and reopened.document.fingerprint() == document.fingerprint(), "Updated previous Act reloads its full authoring data")
  check(FileAccess.get_file_as_string(path) == source, "Loading and saving elsewhere leaves previous source untouched")
 print("PASS | Formats 2 and 3 gain optional unset markers without altering existing data")

func apply_loaded_edits(document: Resource) -> void:
 document.activation_y += 1.0 / 7.0
 document.spawn_position = Vector2(438.512345678901, 271.25123456789)

func check_persistence() -> void:
 var document := make_fixture()
 check(document.save_document(SAVED_PATH) == OK, "Complete Act saves with lifecycle markers")
 var source := FileAccess.get_file_as_string(SAVED_PATH)
 check(source.contains("format_version = " + str(Document.FORMAT_VERSION)), "Current lifecycle format is stored explicitly")
 check(source.contains("activation_y = PackedByteArray(") and source.contains("spawn_position = Vector2("), "Activation uses the exact scalar codec; spawn uses native Vector2 storage")
 check(not source.to_lower().contains("gutter"), "System gutter height is not duplicated in authored files")
 check(typeof(document.activation_y) == TYPE_FLOAT and typeof(document.spawn_position) == TYPE_VECTOR2, "Saving leaves live lifecycle values numeric")
 var loaded: Dictionary = Document.load_document(SAVED_PATH)
 check(loaded.document != null, "Current lifecycle file reloads")
 if loaded.document == null:
  return
 check_exact_layout(loaded.document, document, "First reload")
 for cycle in 3:
  check(loaded.document.save_document(SAVED_PATH) == OK, "Repeated lifecycle save " + str(cycle + 1))
  loaded = Document.load_document(SAVED_PATH)
  check(loaded.document != null, "Repeated lifecycle file reloads")
  if loaded.document == null:
   return
  check_exact_layout(loaded.document, document, "Repeated reload " + str(cycle + 1))
 var invalid: Resource = document.copy_document()
 invalid.spawn_position = Vector2(300, 625)
 var before_invalid_save := FileAccess.get_file_as_string(SAVED_PATH)
 check(invalid.save_document(SAVED_PATH) != OK and FileAccess.get_file_as_string(SAVED_PATH) == before_invalid_save, "Rejected gutter spawn keeps the existing saved file unchanged")
 var output: Array = []
 var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
  "--headless", "--path", ProjectSettings.globalize_path("res://"),
  "--script", "res://tests/act_lifecycle_regression.gd", "--", "--reload-lifecycle"
 ]), output, true)
 for line: Variant in output:
  print(String(line).strip_edges())
 check(exit_code == 0, "Fresh Godot process reloads, edits and saves all lifecycle state")
 var edited: Dictionary = Document.load_document(EDITED_PATH)
 apply_loaded_edits(document)
 check(edited.document != null, "Parent opens the exact child-edited lifecycle state")
 if edited.document != null:
  check_exact_layout(edited.document, document, "Child-edited reload")
 document.activation_y = null
 document.spawn_position = null
 check(document.save_document(EDITED_PATH) == OK, "Deleted markers save as an incomplete draft")
 var empty: Dictionary = Document.load_document(EDITED_PATH)
 check(empty.document != null and empty.document.activation_y == null and empty.document.spawn_position == null and empty.document.grid_size == Vector2i(12, 12), "Deleted markers remain unset after reload without adding a terrain row")

func reload_in_fresh_process() -> void:
 var loaded: Dictionary = Document.load_document(SAVED_PATH)
 check(loaded.document != null and loaded.error.is_empty(), "Fresh process loads all authored Act state")
 if loaded.document != null:
  check_exact_layout(loaded.document, make_fixture(), "Fresh-process reload")
  apply_loaded_edits(loaded.document)
  check(loaded.document.save_document(EDITED_PATH) == OK, "Fresh process edits exact lifecycle markers and saves again")
 print("RESULT | Fresh-process lifecycle | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
 if OS.get_cmdline_user_args().has("--reload-lifecycle"):
  reload_in_fresh_process()
  return
 check_bounds_and_drafts()
 check_validation_and_snapshots()
 check_previous_formats()
 check_persistence()
 print("RESULT | Act lifecycle | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
