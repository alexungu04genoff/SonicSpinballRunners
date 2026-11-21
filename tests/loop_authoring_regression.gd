extends SceneTree
## Exercise the actual editor's history, exact serialization and shared mouth geometry.
const Act = preload("res://scripts/act_editor/act_geometry.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Path = Objects.LoopPath
const Clearance = preload("res://scripts/authored_act/loop_clearance.gd")
const WORKSHOP := "res://data/acts/Experiments/Loop Workshop.tres"
const OUTPUT := "res://test-results/loop-dev"
var checks := 0
var failures := 0

func _initialize() -> void:
 run.call_deferred()

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func geometry(document: Resource) -> void:
 var item: Dictionary = document.gameplay_objects[1].duplicate(true)
 item.properties = Objects.properties(item)
 var origin: Vector2 = item.position
 var forward := Objects.forward(item)
 var right := forward.orthogonal()
 for scale_value: float in [0.5, 1.0, 2.5]:
  item.properties.scale = scale_value
  var width := Path.HALF_WIDTH * scale_value - 7.0
  for side: float in [-1.0, 1.0]:
   var center := origin + right * (width - 0.05) * side
   check(Path.entry_fraction(center - forward, center + forward, forward * 241.0, item, 7) >= 0.0, "Inside mouth accepts either edge")
   center += right * 0.1 * side
   check(Path.entry_fraction(center - forward, center + forward, forward * 500.0, item, 7) < 0.0, "Outside ball clearance misses")
   for angle: float in [29.9, 30.1]:
    var velocity := forward.rotated(deg_to_rad(angle * side)) * 500.0
    check((Path.entry_fraction(origin - velocity * 0.01, origin + velocity * 0.01, velocity, item, 7) >= 0.0) == (angle < 30), "Both sides of approach cone")
  var end := Path.sample(item, Path.LENGTH * scale_value)
  var exit_offset := Vector2(end.x, end.z) - origin
  check(is_equal_approx(absf(exit_offset.dot(right)), Path.LANE_SHIFT * cos(Path.PITCH_ANGLE) * scale_value) and is_zero_approx(end.y), "Adjacent ground-level entrance and exit lanes scale with the structure")
  item.properties.direction = "clockwise"
  var crest := Path.sample(item, Path.LENGTH * scale_value / 2.0)
  item.properties.direction = "counter-clockwise"
  var mirror := Path.sample(item, Path.LENGTH * scale_value / 2.0)
  check(is_equal_approx(crest.y, mirror.y) and is_equal_approx(crest.y, 2.0 * Path.RADIUS * scale_value) and Vector2(crest.x - mirror.x, crest.z - mirror.z).length() > 65.0 * scale_value, "Both directions reach the full vertical diameter")
 item.rotation_degrees = 0.0
 item.properties.direction = "clockwise"
 for speed: float in [239.99, 240.0, 241.0]:
  check((Path.entry_fraction(origin + Vector2.DOWN, origin + Vector2.UP, Vector2.UP * speed, item, 7) >= 0) == (speed >= 240), "Minimum forward speed is inclusive")
 check(Path.entry_fraction(origin + Vector2.UP, origin + Vector2.DOWN, Vector2.DOWN * 700, item, 7) < 0, "Reverse shot passes")
 check(Path.entry_fraction(origin + Vector2.DOWN * 8, origin + Vector2.DOWN, Vector2.UP * 700, item, 7) < 0, "Proximity alone cannot capture")
 for bad: float in [0.49, 2.51, NAN, INF]:
  item.properties.scale = bad
  check(not Objects.property_errors(item).is_empty(), "Unsafe scale rejected")
 item.properties.scale = 1.0
 for invalid_score: Variant in [-1, 0.5, NAN, INF, 1000001]:
  item.properties.completion_score = invalid_score
  check(not Objects.property_errors(item).is_empty(), "Invalid completion score rejected")
 for field: String in ["position", "rotation_degrees"]:
  var invalid: Resource = document.copy_document()
  invalid.gameplay_objects[0][field] = Vector2.INF if field == "position" else NAN
  check(not invalid.validation_errors().is_empty(), "Non-finite transform rejected")
 var probe: Dictionary = document.gameplay_objects[0].duplicate(true)
 probe.properties = Objects.properties(probe)
 check(Clearance.editor_warning(document, probe).is_empty(), "Workshop room is clear")
 probe.position.x = 10
 check(not Clearance.editor_warning(document, probe).is_empty(), "Out-of-bounds footprint reported")
 probe.position = Vector2(400, 400)
 probe.rotation_degrees = 0.0
 var bounds := Rect2(0, 0, 800, 800)
 for distance: float in [0.0, Path.LENGTH, Path.LEAD + Path.RADIUS * 0.65]:
  var point := Path.sample(probe, distance)
  var wall := {"points": PackedVector2Array([Vector2(point.x - 5, point.z), Vector2(point.x + 5, point.z)]), "closed": false}
  check(not Clearance.check(probe, bounds, [wall], [], 50, 7).is_empty(), "Obstructed mouth, exit or low track reported")
 var apex := Path.sample(probe, Path.LENGTH / 2.0)
 var under := {"points": PackedVector2Array([Vector2(apex.x - 2, apex.z), Vector2(apex.x + 2, apex.z)]), "closed": false}
 check(Clearance.check(probe, bounds, [under], [], 50, 7).is_empty(), "High crossing above a wall is legal")
 probe.properties.scale = 2.5
 check(Clearance.check(probe, bounds, [], [], 50, 7).is_empty(), "Full 2.5x assembly and both mouths fit a clear authored room")
 var original: Dictionary = document.gameplay_objects[1].duplicate(true)
 original.properties = Objects.properties(original)
 var pivot := Vector2(400, 400)
 for horizontal: bool in [true, false]:
  var copy: Resource = document.copy_document()
  preload("res://scripts/act_editor/selection_transform.gd").mirror(copy, {"gameplay": [1]}, pivot, horizontal)
  var mirrored: Dictionary = copy.gameplay_objects[1]
  var matches := true
  for distance: float in Path.distances():
   var a := Path.sample(original, distance)
   var b := Path.sample(mirrored, distance)
   var expected := Vector3(2.0 * pivot.x - a.x, a.y, a.z) if horizontal else Vector3(a.x, a.y, 2.0 * pivot.y - a.z)
   matches = matches and b.is_equal_approx(expected)
  check(matches and mirrored.properties.direction != original.properties.direction, "Mirror reflects the reachable path, height and lane handedness")

func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 var loaded := Act.load_document(WORKSHOP)
 var document: Resource = loaded.document
 check(document != null and document.validation_errors().is_empty(), "Isolated Workshop loads: " + str(loaded.get("error", "")))
 if document == null:
  quit(1)
  return
 geometry(document)
 if "--measure" in OS.get_cmdline_user_args():
  var item: Dictionary = document.gameplay_objects[1].duplicate(true)
  item.properties = Objects.properties(item)
  var forward := Objects.forward(item)
  var start: Vector2 = item.position - forward * 25
  var steps := 100000
  var checksum := 0.0
  var begin := Time.get_ticks_usec()
  for i in steps:
   checksum += Path.entry_fraction(start, start + forward * 2.5, forward * 300.0, item, 7.0)
  var elapsed := Time.get_ticks_usec() - begin
  begin = Time.get_ticks_usec()
  for i in steps: checksum += Path.sample(item, Path.LENGTH * (i % 1000) / 1000.0).y
  print("LOOP_KERNEL_US | idle_mouth=%.3f | active_sample=%.3f | iterations=%d | checksum=%f" % [float(elapsed) / steps, float(Time.get_ticks_usec() - begin) / steps, steps, checksum])
 var ordinary: Resource = document.copy_document()
 ordinary.title = "Loop comparison"
 ordinary.decor_seed = document.decor_identity()
 for i in range(ordinary.gameplay_objects.size() - 1, -1, -1):
  if ordinary.gameplay_objects[i].type == "sonic_loop": ordinary.gameplay_objects.remove_at(i)
 check(ordinary.save_document(OUTPUT.path_join("comparison.tres")) == OK, "Matched render comparison saves")
 var editor := preload("res://scenes/act_geometry_editor.tscn").instantiate()
 root.add_child(editor)
 await process_frame
 editor.new_document()
 editor.document = document.copy_document()
 editor.canvas.set_document(editor.document)
 editor.canvas.snap_mode = 0
 editor.canvas.fit_view()
 editor._refresh()
 editor.workspace_tools.autosave_enabled.button_pressed = false
 editor.canvas.select_gameplay(1)
 var xy := Vector2(386.8125, 557.46875)
 var angle := -27.123456789
 var scale_value := 1.0323456789
 editor.move_gameplay_placement(1, xy)
 editor.set_gameplay_angle(angle)
 editor.set_gameplay_property("scale", scale_value)
 editor.undo()
 check(editor.document.gameplay_objects[1].properties.scale == 1.0, "Undo restores original scale")
 editor.redo()
 var labels: Array[Node] = editor.mechanics_properties.find_children("*", "Label", true, false)
 check(labels.any(func(label): return label.text == "Scale") and labels.any(func(label): return label.text == "Completion Score"), "Inspector exposes size and payout")
 editor.set_gameplay_property("completion_score", 1375)
 check(editor.document.gameplay_objects[1].properties.completion_score == 1375, "Editor sets an independent Loop reward")
 var item: Dictionary = editor.document.gameplay_objects[1]
 check(item.position == xy and item.rotation_degrees == angle and item.properties.scale == scale_value, "Exact free transforms survive redo")
 editor.canvas.select_gameplay(1)
 editor.duplicate_selected()
 var clone: Dictionary = editor.document.gameplay_objects.back()
 check(clone.object_id != item.object_id and clone.properties == item.properties and clone.rotation_degrees == angle, "Duplicate retains exact orientation, scale and direction with a new ID")
 editor.delete_selected()
 check(editor.document.gameplay_objects.size() == document.gameplay_objects.size(), "Selected duplicate deleted")
 editor.undo()
 check(editor.document.gameplay_objects.back().object_id == clone.object_id, "Undo deletion restores identity")
 editor.canvas.select_gameplay(1)
 editor.copy_selected()
 editor.paste_selected(false, true)
 var pasted: Dictionary = editor.document.gameplay_objects.back()
 check(pasted.position == xy and pasted.object_id != item.object_id and pasted.properties == item.properties, "Clipboard preserves the free transform in place")
 var path := OUTPUT.path_join("roundtrip.tres")
 check(editor.document.save_document(path) == OK, "Draft saves through standard format")
 var saved: Resource = Act.load_document(path).document
 check(saved.fingerprint() == editor.document.fingerprint() and saved.gameplay_objects[1].rotation_degrees == angle and saved.gameplay_objects[1].properties.scale == scale_value and saved.gameplay_objects[1].properties.completion_score == 1375, "Disk reload retains exact values")
 editor.free()
 print("RESULT | Loop authoring | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
