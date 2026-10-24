extends SceneTree
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const Dimensions = preload("res://scripts/act_editor/preview_dimensions.gd")
const PATH := "res://test-results/act-rings.tres"
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func fixture() -> Resource:
 var doc := Document.new()
 doc.ring_trails = [
  {"start": Vector2(50, 50), "end": Vector2(50, 50), "spacing": 20.0},
  {"start": Vector2(100, 100), "end": Vector2(300, 100), "spacing": 20.0},
  {"start": Vector2(100, 100), "end": Vector2(100, 350), "spacing": 20.0},
  {"start": Vector2(71.125, 83.375), "end": Vector2(317.25, 294.5), "spacing": 20.0 / 1.7},
 ]
 return doc

func compare(actual: Resource, expected: Resource) -> void:
 check(actual.fingerprint() == expected.fingerprint(), "Exact document fingerprint survives persistence")
 for index in expected.ring_trails.size():
  for field: String in ["start", "end", "spacing"]:
   check(var_to_bytes(actual.ring_trails[index][field]) == var_to_bytes(expected.ring_trails[index][field]), "Exact endpoint/scalar bits survive persistence: " + field)
  check(var_to_bytes(Rings.positions(actual.ring_trails[index])) == var_to_bytes(Rings.positions(expected.ring_trails[index])), "Generated positions are byte-identical after loading")

func finish() -> void:
 print("RESULT | Ring model | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var doc := fixture()
 if OS.get_cmdline_user_args().has("--reload-rings"):
  var loaded := Document.load_document(PATH)
  check(loaded.document != null, "Fresh process loads ring document")
  if loaded.document != null: compare(loaded.document, doc)
  finish()
  return
 check(doc.validation_errors().is_empty(), "Single/horizontal/vertical/free diagonal trails are valid")
 check(Dimensions.RING_RADIUS_CELLS * 2 == 0.18, "Centralized ring diameter is 0.18 cell")
 check(Rings.positions(doc.ring_trails[0]).size() == 1, "Click creates exactly one ring")
 check(Rings.positions(doc.ring_trails[1]).size() == 11, "Horizontal trail fits eleven rings at twenty-pixel spacing")
 for trail: Dictionary in doc.ring_trails:
  var points := Rings.positions(trail)
  check(points[0] == trail.start and points[-1] == trail.end, "Both exact authored endpoints are included")
  if points.size() < 2: continue
  var step := points[0].distance_to(points[1])
  var even := true
  var collinear := true
  for index in range(1, points.size()):
   even = even and absf(points[index].distance_to(points[index - 1]) - step) < 0.0001
   collinear = collinear and absf((points[index] - points[0]).cross(trail.end - trail.start)) < 0.02
  check(even and step <= float(trail.spacing) + 0.0001 and collinear, "All generated centers lie evenly on the unconstrained line")
 var diagonal := Rings.positions(doc.ring_trails[3])
 check(diagonal[1] != (diagonal[1] / doc.cell_size).round() * doc.cell_size, "Interior diagonal centers remain fractional rather than grid-snapped")
 var before := var_to_bytes(diagonal)
 doc.cell_size = 47.5
 check(var_to_bytes(Rings.positions(doc.ring_trails[3])) == before, "Cell-size/preview changes do not reposition authored rings")
 doc.cell_size = 50.0
 var snapshot: Resource = doc.copy_document()
 snapshot.ring_trails[0].start += Vector2.ONE
 check(doc.ring_trails[0].start == Vector2(50, 50) and snapshot.fingerprint() != doc.fingerprint(), "Snapshots are independent and ring edits mark the document dirty")
 for bad: Variant in [null, {}, {"start": Vector2.ZERO, "end": Vector2.ONE, "spacing": 0}, {"start": Vector2(NAN, 0), "end": Vector2.ONE, "spacing": 20}, {"start": Vector2.ZERO, "end": Vector2.ONE, "spacing": INF}, {"start": Vector2.ZERO, "end": Vector2.ONE, "spacing": 0.00000001}]:
  var invalid := fixture()
  invalid.ring_trails = [bad]
  check(not invalid.validation_errors().is_empty(), "Malformed or unbounded trails are rejected without repair")
 for path: String in ["res://tests/fixtures/act_format_2.tres", "res://tests/fixtures/act_format_3.tres", "res://data/acts/playtest_showcase.tres"]:
  var bytes := FileAccess.get_file_as_bytes(path)
  var loaded := Document.load_document(path)
  check(loaded.document != null and loaded.document.format_version == Document.FORMAT_VERSION and loaded.document.ring_trails.is_empty(), "Previous format loads with empty trails: " + path)
  check(FileAccess.get_file_as_bytes(path) == bytes, "Loading previous Acts never rewrites their source")
 check(doc.save_document(PATH) == OK, "Ring Resource saves through the normal exact persistence path")
 var loaded := Document.load_document(PATH)
 check(loaded.document != null, "Saved ring Resource loads")
 if loaded.document != null: compare(loaded.document, doc)
 var output := []
 var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/act_ring_regression.gd", "--", "--reload-rings"]), output, true)
 check(code == 0, "Fresh process reopens the exact rings and spacing")
 for line: String in output: print(line.strip_edges())
 finish()
