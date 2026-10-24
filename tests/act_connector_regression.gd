extends SceneTree
## Deterministic connector validation, width compatibility and restart persistence.
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const ROOT := "res://test-results/act-connectors"
const SAVED_PATH := ROOT + "/authored.tres"
const EDITED_PATH := ROOT + "/edited.tres"
const INVALID_PATH := ROOT + "/invalid.tres"
const CONNECTOR_FIELDS := ["entry_start_x", "entry_width", "exit_start_x", "exit_width"]
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL | " + label)

func placement(id: String, anchor: Vector2i, turns: int, horizontal: bool, vertical: bool) -> Dictionary:
 return {"shape_id": id, "base_size": Shapes.get_definition(id).size, "anchor": anchor,
  "quarter_turns": turns, "flip_h": horizontal, "flip_v": vertical}

func make_fixture() -> Resource:
 var document := Document.new()
 document.title = "Authored boundary connectors"
 document.cell_size = 47.5
 document.entry_start_x = 7
 document.entry_width = 2
 document.exit_start_x = 1
 document.exit_width = 3
 document.placements = [
  placement("triangle_1x3", Vector2i(1, 1), 1, true, false),
  placement("j_curve_2x3", Vector2i(4, 2), 2, false, true),
  placement("circle_1x1", Vector2i(4, 2), 3, true, true),
 ]
 return document

func rejected_load(path: String, label: String) -> void:
 var result: Dictionary = Document.load_document(path)
 check(result.document == null and not result.error.is_empty(), label)

func check_compatibility() -> void:
 check(Document.compatible({"start_x": 1, "width": 3}, {"start_x": 8, "width": 3}), "Equal widths are compatible at different local X coordinates")
 check(Document.compatible({"width": 3}, {"start_x": -200, "width": 3}), "Compatibility reads width only; span validity belongs to the document")
 check(not Document.compatible({"start_x": 1, "width": 2}, {"start_x": 1, "width": 3}), "Equal positions do not make unequal widths compatible")
 for width: Variant in [0, -1, true, 3.0, "3", null]:
  check(not Document.compatible({"width": width}, {"width": width}), "Unset or nonpositive/noninteger widths cannot connect: " + str(width))
  check(not Document.compatible({"width": 3}, {"width": width}), "Next entry must have a positive integer width: " + str(width))
 check(not Document.compatible({}, {}), "Missing widths are not compatible")
 print("PASS | Connector compatibility compares positive integer widths only")

func check_validation_and_copy() -> void:
 var draft := Document.new()
 check(draft.validation_errors().is_empty(), "Drafts may leave both connectors unset")
 check(draft.get_connector("entry") == {"start_x": 0, "width": 0} and draft.get_connector("exit") == {"start_x": 0, "width": 0}, "New Acts have optional unset connectors")
 check(draft.get_connector("side").is_empty(), "Unknown connector kind does not alias a valid boundary")
 var document := make_fixture()
 check(document.validation_errors().is_empty(), "Entry and exit spans coexist with overlapping terrain")
 check(document.get_connector("entry") == {"start_x": 7, "width": 2} and document.get_connector("exit") == {"start_x": 1, "width": 3}, "Connector accessors expose exact local spans")
 var independent: Resource = document.copy_document()
 check(independent.fingerprint() == document.fingerprint(), "Document snapshots retain both connector spans")
 independent.entry_start_x = 8
 independent.placements[0].anchor = Vector2i(5, 5)
 check(document.entry_start_x == 7 and document.placements[0].anchor == Vector2i(1, 1), "Connector and terrain snapshot edits do not modify the original")
 for field: String in CONNECTOR_FIELDS:
  var changed: Resource = document.copy_document()
  changed.set(field, changed.get(field) + 1)
  check(changed.fingerprint() != document.fingerprint(), "Dirty fingerprint covers " + field)
  for invalid_value: Variant in [true, 1.5, "1", null]:
   var invalid: Resource = document.copy_document()
   invalid.set(field, invalid_value)
   check(not invalid.validation_errors().is_empty(), "Strict connector type: " + field + "=" + str(invalid_value))
   check(ResourceSaver.save(invalid, INVALID_PATH) == OK, "Malformed connector fixture is written without validation")
   rejected_load(INVALID_PATH, "Resource loading does not coerce malformed " + field)
 for kind: String in ["entry", "exit"]:
  for span: Vector2i in [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(12, 1), Vector2i(10, 3), Vector2i(0, 13)]:
   var invalid: Resource = document.copy_document()
   invalid.set(kind + "_start_x", span.x)
   invalid.set(kind + "_width", span.y)
   check(not invalid.validation_errors().is_empty(), "%s span rejects invalid start/width %s" % [kind, span])
  for span: Vector2i in [Vector2i.ZERO, Vector2i(0, 12), Vector2i(11, 1), Vector2i(9, 3)]:
   var valid: Resource = document.copy_document()
   valid.set(kind + "_start_x", span.x)
   valid.set(kind + "_width", span.y)
   check(valid.validation_errors().is_empty(), "%s span accepts exact grid boundaries %s" % [kind, span])
 var narrow := Document.new()
 narrow.grid_size = Vector2i(3, 8)
 narrow.entry_start_x = 1
 narrow.entry_width = 2
 check(narrow.validation_errors().is_empty(), "Connector bounds use the document's grid width")
 narrow.entry_width = 3
 check(not narrow.validation_errors().is_empty(), "Connector bounds do not assume a fixed 12-column Act")
 check(draft.save_document(EDITED_PATH) == OK, "Unset connector drafts save")
 var loaded: Dictionary = Document.load_document(EDITED_PATH)
 check(loaded.document != null and loaded.document.fingerprint() == draft.fingerprint(), "Unset drafts reload as current documents")
 print("PASS | Optional spans, strict types, bounds, snapshots and fingerprints")

func apply_loaded_edits(document: Resource) -> void:
 document.entry_start_x = 9
 document.entry_width = 3
 document.exit_start_x = 0
 document.exit_width = 5
 document.placements[0].anchor = Vector2i(7, 8)
 document.placements[0].flip_v = true

func check_persistence() -> void:
 var document := make_fixture()
 check(document.save_document(SAVED_PATH) == OK, "Authored terrain and both connectors save together")
 var source := FileAccess.get_file_as_string(SAVED_PATH)
 check(source.contains("format_version = 2") and source.contains("library_version = 2"), "Both current versions are serialized explicitly")
 for field: String in CONNECTOR_FIELDS:
  check(source.contains(field + " = " + str(document.get(field))), "Saved resource retains " + field)
 var invalid: Resource = document.copy_document()
 invalid.entry_width = 99
 check(invalid.save_document(SAVED_PATH) != OK and FileAccess.get_file_as_string(SAVED_PATH) == source, "Invalid connector save preserves the previous authored file")
 var output: Array = []
 var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
  "--headless", "--path", ProjectSettings.globalize_path("res://"),
  "--script", "res://tests/act_connector_regression.gd", "--", "--reload-connectors"
 ]), output, true)
 for line: Variant in output:
  print(String(line).strip_edges())
 check(exit_code == 0, "Fresh Godot process reloads, edits and re-saves both connectors")
 var loaded: Dictionary = Document.load_document(EDITED_PATH)
 apply_loaded_edits(document)
 check(loaded.document != null and loaded.document.fingerprint() == document.fingerprint(), "Parent sees exact child-edited connectors and terrain without stale cached data")

func reload_in_fresh_process() -> void:
 var loaded: Dictionary = Document.load_document(SAVED_PATH)
 check(loaded.document != null and loaded.error.is_empty(), "Fresh process loads the current Act format")
 if loaded.document != null:
  var expected := make_fixture()
  var actual: Resource = loaded.document
  check(actual.fingerprint() == expected.fingerprint(), "Fresh process reproduces the entire authored document exactly")
  check(actual.get_connector("entry") == expected.get_connector("entry") and actual.get_connector("exit") == expected.get_connector("exit"), "Fresh process restores both connector local positions and widths")
  check(actual.placements == expected.placements, "Connector persistence preserves independent overlapping terrain")
  apply_loaded_edits(actual)
  check(actual.save_document(EDITED_PATH) == OK, "Loaded connector spans remain editable and save again")
 print("RESULT | Fresh-process connectors | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
 if OS.get_cmdline_user_args().has("--reload-connectors"):
  reload_in_fresh_process()
  return
 check_compatibility()
 check_validation_and_copy()
 check_persistence()
 print("RESULT | Act connectors | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
