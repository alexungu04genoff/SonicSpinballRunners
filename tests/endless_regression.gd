extends SceneTree
const Plan = preload("res://scripts/endless/endless_plan.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func run() -> void:
 var documents: Array = []
 var fingerprints: Array[String] = []
 for path: String in Plan.PATHS:
  var loaded := Document.load_document(path)
  check(loaded.error.is_empty(), "Saved Act loads: " + path)
  if loaded.document == null:
   quit(1)
   return
  documents.append(loaded.document)
  fingerprints.append(loaded.document.fingerprint())
 check(Plan.pool_error(documents).is_empty(), "The whole pool has compatible connectors and checkpoints")
 var a := Plan.new(79)
 var b := Plan.new(79)
 var themes: Array[String] = []
 var last: Dictionary = {}
 for zone_index in 64:
  var zone_a := a.next_zone(documents)
  var zone_b := b.next_zone(documents)
  check(zone_a == zone_b, "Seed reproduces Zone %d" % zone_index)
  var ids: Array[int] = []
  for entry: Dictionary in zone_a:
   ids.append(entry.id)
   check(entry.zone == zone_index, "Zone numbering")
   if not last.is_empty():
    var previous: Resource = documents[last.id]
    var next: Resource = documents[entry.id]
    var exit := Vector2(last.offset) + Vector2(previous.exit_start_x * previous.cell_size, 0)
    var entrance := Vector2(entry.offset) + Vector2(next.entry_start_x * next.cell_size, next.terrain_bounds().size.y)
    check(exit.is_equal_approx(entrance), "Whole-Act connector alignment")
    check(last.id != entry.id, "No immediate Act repeat")
   last = entry
  ids.sort()
  check(ids == [0, 1, 2], "Every Zone uses all three Acts once")
  if not themes.is_empty(): check(themes.back() != zone_a[0].theme, "No adjacent theme repeat")
  themes.append(zone_a[0].theme)
  if themes.size() == 8:
   var unique := {}
   for theme: String in themes: unique[theme] = true
   check(unique.size() == 8, "Theme bag visits all eight themes")
   themes.clear()
 var tuning := PhysicsTuning.new()
 root.add_child(tuning)
 var controls := PlaygroundInput.new()
 root.add_child(controls)
 var ball := PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 ball.freeze = true
 root.add_child(ball)
 var runtimes: Array[Dictionary] = []
 for document: Resource in documents:
  var runtime := Compiler.compile(document, tuning, controls, ball)
  check(runtime.error.is_empty(), "Act passes shared runtime validation")
  if not runtime.error.is_empty():
   quit(1)
   return
  runtime.mechanics.bind_ball_on_ready = false
  root.add_child(runtime.root)
  runtime.root.process_mode = Node.PROCESS_MODE_DISABLED
  runtimes.append(runtime)
  var shape_count := 0
  for item: Dictionary in runtime.terrain:
   for owner: int in item.body.get_shape_owners(): shape_count += item.body.shape_owner_get_shape_count(owner)
  check(shape_count > 0, "Compiled convex shapes are available for streaming")
  print("ENDLESS_TEMPLATE | terrain=%d shapes=%d objects=%d" % [runtime.terrain.size(), shape_count, runtime.objects.size()])
 # Test every ordered connector pair against actual collision shapes. The probe
 # moves through the seam; this checks validity, not difficulty or route reachability.
 for lower in 3:
  for upper in 3:
   var previous: Resource = documents[lower]
   var next: Resource = documents[upper]
   for i in 3: runtimes[i].root.position = Vector2(10000, 10000)
   runtimes[lower].root.position = Vector2.ZERO
   var second := Compiler.compile(next, tuning, controls, ball)
   second.mechanics.bind_ball_on_ready = false
   second.root.position = Plan.aligned_offset(previous, Vector2.ZERO, next)
   second.root.process_mode = Node.PROCESS_MODE_DISABLED
   root.add_child(second.root)
   await physics_frame
   await physics_frame
   var clear := 0
   var left: float = previous.exit_start_x * previous.cell_size
   var width: float = previous.exit_width * previous.cell_size
   for sample in 9:
    var query := PhysicsTestMotionParameters2D.new()
    query.from = Transform2D(0, Vector2(left + width * float(sample + 1) / 10.0, 14))
    query.motion = Vector2(0, -28)
    if not PhysicsServer2D.body_test_motion(ball.get_rid(), query): clear += 1
   check(clear > 0, "Connector %d to %d has ball-width clearance" % [lower, upper])
   print("ENDLESS_JOIN | %d to %d | clear probes=%d/9" % [lower, upper, clear])
   second.root.free()
 for i in 3:
  check(documents[i].fingerprint() == fingerprints[i], "Streaming plan and compilation preserve authored data")
  runtimes[i].root.free()
 ball.free()
 controls.free()
 tuning.free()
 print("ENDLESS_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
