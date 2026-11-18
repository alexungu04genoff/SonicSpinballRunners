extends SceneTree
## Persistence and geometric oracles for the November editor qualification.
const Fixture = preload("res://tests/editor_qualification_fixture.gd")
const Act = Fixture.Act
const Selection = Fixture.Selection
const Objects = Fixture.Objects
const Shapes = Fixture.Shapes
const History = Fixture.History
const Transform = Fixture.Transform
const Composite = Fixture.Composite
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const Clipboard = preload("res://scripts/act_editor/selection_clipboard.gd")
const Assemblies = preload("res://scripts/act_editor/assembly_library.gd")
const Recovery = preload("res://scripts/act_editor/editor_recovery.gd")
var checks := 0
var failures := 0
var failed: Array[String] = []

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  failed.append(message)
  push_error(message)

func close_points(actual: PackedVector2Array, expected: PackedVector2Array, tolerance := 0.03) -> bool:
 if actual.size() != expected.size(): return false
 var remaining := Array(expected)
 for point: Vector2 in actual:
  var nearest := -1
  var distance := tolerance
  for index in remaining.size():
   var candidate := point.distance_to(remaining[index])
   if candidate <= distance:
    nearest = index
    distance = candidate
  if nearest < 0: return false
  remaining.remove_at(nearest)
 return true

func reflected(points: PackedVector2Array, pivot: Vector2, horizontal: bool) -> PackedVector2Array:
 var result := PackedVector2Array()
 var signs := Vector2(-1, 1) if horizontal else Vector2(1, -1)
 for point: Vector2 in points: result.append(pivot + (point - pivot) * signs)
 return result

func persistence(document: Resource) -> void:
 var original: String = document.editing_fingerprint()
 var duplicate: Resource = document.copy_document()
 check(duplicate.editing_fingerprint() == original, "copy_document preserves the complete editing state")
 duplicate.editor_groups[0].name = "Independent copy"
 duplicate.placements[-1].editor_sources.sources[0].anchor += Vector2i.ONE
 check(document.editing_fingerprint() == original, "Nested groups and source histories are deeply copied")
 for name in ["roundtrip", "save-as"]:
  var path: String = "user://qualification-" + name + ".tres"
  check(document.save_document(path) == OK, name + " saves format 19")
  var loaded := Act.load_document(path)
  check(loaded.document != null and loaded.document.editing_fingerprint() == original, name + " reloads all metadata, transforms, IDs and lifecycle exactly")
 var receipt := ConfigFile.new()
 receipt.set_value("restart", "fingerprint", original)
 receipt.save("user://qualification-restart.cfg")
 var old_count := 0
 for folder: String in ["res://data/acts", "res://data/acts/Authored", "res://tests/fixtures"]:
  var directory := DirAccess.open(folder)
  if directory == null: continue
  for filename: String in directory.get_files():
   if filename.get_extension() != "tres": continue
   var path := folder.path_join(filename)
   var raw := FileAccess.get_file_as_string(path)
   if not "act_geometry.gd" in raw: continue
   var before := FileAccess.get_sha256(path)
   var loaded := Act.load_document(path)
   check(FileAccess.get_sha256(path) == before, "Opening never rewrites " + filename)
   # Malformed fixtures have their own rejection tests; production Acts must load.
   if folder != "res://tests/fixtures":
    check(loaded.document != null, "Existing Act remains loadable: " + filename)
    old_count += 1
 check(old_count >= 14, "Compatibility exercised both production Act pools")
 var game_fingerprint: String = document.fingerprint()
 for metadata in ["editor_groups", "editor_locks", "editor_hidden"]:
  duplicate = document.copy_document()
  duplicate.set(metadata, [] if metadata == "editor_groups" else {})
  check(duplicate.fingerprint() == game_fingerprint and duplicate.editing_fingerprint() != original, metadata + " affects editing state only")
 duplicate = document.copy_document()
 duplicate.placements[-1].erase("editor_sources")
 check(duplicate.fingerprint() == game_fingerprint and duplicate.editing_fingerprint() != original, "Source history is excluded from gameplay freshness")
 var mutations: Array[Callable] = [
  func(d): d.gameplay_objects[0].position += Vector2(0.125, -0.25),
  func(d): d.gameplay_objects[1].rotation_degrees += 7.0,
  func(d): d.placements[0].terrain_scale *= 1.1,
  func(d): Transform.mirror(d, Selection.single("terrain", 0), Vector2(800, 1000), true),
  func(d): d.grid_size += Vector2i.ONE,
  func(d): d.gameplay_objects[9].properties.width += 1.0,
  func(d): d.gameplay_objects[17].properties.patrol_left -= 1.0]
 for index in mutations.size():
  duplicate = document.copy_document()
  mutations[index].call(duplicate)
  check(duplicate.fingerprint() != game_fingerprint, "Geometric freshness mutation %d is detected" % index)
 var invalid: Array[Callable] = [
  func(d): d.editor_groups[0].members.terrain = [99999],
  func(d): d.editor_locks = {"terrain": ["invalid"]},
  func(d): d.editor_hidden = {"gameplay": [-1]},
  func(d): d.placements[-1].editor_sources.reference = Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO),
  func(d): d.placements[-1].editor_sources.sources[0].base_size = Vector2i(99, 99),
  func(d): d.placements[-1].editor_sources.sources[0]["terrain_scale"] = 9.0,
  func(d): d.placements[-1].editor_sources.sources[0]["offset"] = Vector2(1.5, 0),
  func(d): malformed_composite_source(d, "composite_version", 999),
  func(d): malformed_composite_source(d, "base_size", Vector2i.ZERO),
  func(d): malformed_composite_source(d, "outline", PackedVector2Array([Vector2.ZERO, Vector2(2, 2), Vector2(0, 2), Vector2(2, 0)])),
  func(d): malformed_composite_source(d, "unexpected_payload", "invalid"),
  func(d): d.placements[0].offset = Vector2(NAN, 0),
  func(d): d.gameplay_objects[0].object_id = d.gameplay_objects[1].object_id]
 var good_path := "user://qualification-roundtrip.tres"
 var good_hash := FileAccess.get_sha256(good_path)
 for index in invalid.size():
  document.save_document(good_path)
  good_hash = FileAccess.get_sha256(good_path)
  duplicate = document.copy_document()
  invalid[index].call(duplicate)
  check(not duplicate.validation_errors().is_empty(), "Malformed metadata/transform/identity %d rejected" % index)
  check(duplicate.save_document(good_path) != OK and FileAccess.get_sha256(good_path) == good_hash, "Invalid save %d leaves the authored file intact" % index)
  var bad_path := "user://qualification-invalid-%d.tres" % index
  ResourceSaver.save(duplicate, bad_path)
  check(Act.load_document(bad_path).document == null, "Malformed disk resource %d cannot open" % index)

func malformed_composite_source(document: Resource, field: String, value: Variant) -> void:
 var source: Dictionary = document.placements[-1].duplicate(true)
 source[field] = value
 document.placements[-1].editor_sources.sources[0] = source

func mirrors(document: Resource) -> void:
 var pivot := Vector2(800, 1000)
 var selection := Fixture.all(document, true)
 for horizontal in [true, false]:
  var mirrored: Resource = document.copy_document()
  Transform.mirror(mirrored, selection, pivot, horizontal)
  var axis := "H" if horizontal else "V"
  check(mirrored.validation_errors().is_empty(), axis + " mirror remains a valid document")
  for index in document.placements.size():
   check(close_points(Fixture.terrain_points(mirrored.placements[index]), reflected(Fixture.terrain_points(document.placements[index]), pivot, horizontal)), axis + " reflects terrain silhouette %d" % index)
  for index in document.gameplay_objects.size():
   var before: Dictionary = document.gameplay_objects[index]
   var after: Dictionary = mirrored.gameplay_objects[index]
   check(close_points(Fixture.object_points(after), reflected(Fixture.object_points(before), pivot, horizontal)), axis + " reflects hardware silhouette " + before.type)
   if before.type in ["spring", "slingshot", "magnetic_field", "dash_panel", "one_way_gate"]:
    var signs := Vector2(-1, 1) if horizontal else Vector2(1, -1)
    check(Objects.forward(after).is_equal_approx(Objects.forward(before) * signs), axis + " reflects directional force " + before.type)
   if before.type == "teleporter":
    check(Objects.teleporter_exit(after).distance_to(reflected(PackedVector2Array([Objects.teleporter_exit(before)]), pivot, horizontal)[0]) < 0.001, axis + " reflects teleporter destination")
    check(Objects.teleporter_direction(after).distance_to(Objects.teleporter_direction(before) * (Vector2(-1, 1) if horizontal else Vector2(1, -1))) < 0.00001, axis + " reflects teleporter exit direction")
   if before.type == "diverter":
    for state in ["a", "b"]:
     check(Objects.diverter_forward(after, state).distance_to(Objects.diverter_forward(before, state) * (Vector2(-1, 1) if horizontal else Vector2(1, -1))) < 0.00001, axis + " reflects diverter state " + state)
   if before.type == "buzz_bomber":
    var patrol := PackedVector2Array()
    var moved := PackedVector2Array()
    for key in ["patrol_left", "patrol_right"]:
     patrol.append(before.position + Vector2(Objects.properties(before)[key], 0).rotated(deg_to_rad(float(before.rotation_degrees))))
     moved.append(after.position + Vector2(Objects.properties(after)[key], 0).rotated(deg_to_rad(float(after.rotation_degrees))))
    check(close_points(moved, reflected(patrol, pivot, horizontal)), axis + " reflects asymmetric Buzz patrol endpoints")
  for index in document.ring_trails.size():
   check(close_points(Rings.positions(mirrored.ring_trails[index]), reflected(Rings.positions(document.ring_trails[index]), pivot, horizontal)), axis + " reflects sampled ring pattern %d" % index)
  check(mirrored.switch_banks == document.switch_banks, axis + " retains internal bank membership and actions")
  check(mirrored.entry_start_x == document.entry_start_x and mirrored.exit_start_x == document.exit_start_x, axis + " leaves structural connectors unchanged")
  check(mirrored.spawn_position == reflected(PackedVector2Array([document.spawn_position]), pivot, horizontal)[0] and mirrored.goal_position == reflected(PackedVector2Array([document.goal_position]), pivot, horizontal)[0], axis + " reflects Spawn and Goal")
  check(mirrored.activation_y == (document.activation_y if horizontal else 2000.0 - document.activation_y), axis + " keeps Activation horizontal")
  Transform.mirror(mirrored, selection, pivot, horizontal)
  for index in document.placements.size():
   check(close_points(Fixture.terrain_points(mirrored.placements[index]), Fixture.terrain_points(document.placements[index])), axis + " double mirror restores terrain %d" % index)
  for index in document.gameplay_objects.size():
   check(mirrored.gameplay_objects[index].type == document.gameplay_objects[index].type and close_points(Fixture.object_points(mirrored.gameplay_objects[index]), Fixture.object_points(document.gameplay_objects[index])), axis + " double mirror restores handedness and hardware %d" % index)
  for index in document.decor_slots.size():
   check(mirrored.decor_slots[index].position.distance_to(document.decor_slots[index].position) < 0.001 and not mirrored.decor_slots[index].get("mirror_x", false), axis + " double mirror restores Decor %d" % index)

func clipboard_and_assemblies(document: Resource) -> void:
 var selection := Fixture.all(document)
 var copied := Clipboard.capture(document, selection)
 var source_fingerprint: String = document.editing_fingerprint()
 var destination := Fixture.base("Clipboard destination")
 var added := Clipboard.append_to(destination, copied, Vector2.ZERO)
 check(added.error.is_empty() and destination.validation_errors().is_empty(), "Mixed paste-in-place is valid")
 for kind: String in Selection.COLLECTIONS:
  var source: Array = document.get(Selection.COLLECTIONS[kind])
  var pasted: Array = destination.get(Selection.COLLECTIONS[kind])
  var id_key: String = {"terrain": "", "gameplay": "object_id", "decor": "slot_id", "ring": "pattern_id"}[kind]
  for index in source.size():
   if not id_key.is_empty(): check(pasted[index][id_key] != source[index][id_key], "Fresh %s identity %d" % [kind, index])
 check(destination.editor_locks.is_empty() and destination.editor_hidden.is_empty(), "Copies start unlocked and visible")
 check(destination.editor_groups == document.editor_groups, "Complete group metadata survives paste")
 check(destination.placements[-1].editor_sources == document.placements[-1].editor_sources, "Source history survives clipboard")
 for index in document.switch_banks.size():
  var bank: Dictionary = destination.switch_banks[index]
  check(bank.bank_id != document.switch_banks[index].bank_id, "Copied bank gets a fresh identity")
  var pasted_ids: Array = destination.gameplay_objects.map(func(item): return item.object_id)
  check(bank.members.all(func(id): return id in pasted_ids) and bank.gates.all(func(id): return id in pasted_ids) and bank.actions.all(func(action): return action.object_id in pasted_ids), "All copied bank targets belong to the destination")
 var first_ids: Array = destination.gameplay_objects.map(func(item): return item.object_id)
 added = Clipboard.append_to(destination, copied, Vector2(20, 20))
 check(added.error.is_empty() and destination.validation_errors().is_empty(), "Repeated mixed paste remains valid")
 check(destination.gameplay_objects.slice(first_ids.size()).all(func(item): return item.object_id not in first_ids), "Repeated placement never reuses an earlier identity")
 var partial := Selection.single("gameplay", 5)
 check(Clipboard.capture(document, partial).banks.is_empty(), "Partial objective drops bank membership")
 partial.gameplay = [5, 6]
 var targets_only := Clipboard.capture(document, partial)
 check(targets_only.banks.size() == 1 and targets_only.banks[0].gates.is_empty() and targets_only.banks[0].actions.is_empty(), "Complete objective omits all outside routing links")
 destination = Fixture.base("Larger cell destination")
 destination.cell_size = 75.0
 added = Clipboard.append_to(destination, copied, Vector2.ZERO)
 check(added.error.is_empty(), "Cross-cell-size paste validates")
 for index in document.gameplay_objects.size():
  var original: Dictionary = document.gameplay_objects[index]
  var pasted: Dictionary = destination.gameplay_objects[index]
  var expected := Fixture.object_points(document.gameplay_objects[index])
  for point in expected.size(): expected[point] *= 1.5
  # These mechanisms have fixed pixel caps/thickness as well as scalable authoring
  # dimensions. A uniform point-cloud assertion would incorrectly scale the caps.
  var fixed_section := {"one_way_gate": "width", "wall_switch": "scale", "drop_target_bank": "target_size", "slingshot": "width", "spinner": "width", "diverter": "length", "dash_panel": "width"}
  if fixed_section.has(original.type):
   var dimension: String = fixed_section[original.type]
   check(pasted.position.distance_to(original.position * 1.5) < 0.001 and is_equal_approx(float(Objects.properties(pasted)[dimension]), float(Objects.properties(original)[dimension]) * 1.5), "Cross-cell authorable dimension and anchor scale: " + original.type)
  else:
   check(close_points(Fixture.object_points(pasted, 75.0), expected), "Cross-cell physical silhouette scales in cells: " + original.type)
 var clamped := Clipboard.append_to(Fixture.base("Boundary adjustment"), copied, Vector2(-10000, -10000))
 check(clamped.error.is_empty() and clamped.offset != Vector2(-10000, -10000), "Normal paste adjusts the whole selection to terrain bounds")
 var saved := Assemblies.save_selection(document, selection, "Qualification assembly")
 check(saved.error.is_empty(), "Mixed linked assembly persists")
 if saved.error.is_empty():
  var loaded := Assemblies.load_copy(saved.path, 75.0)
  check(loaded.error.is_empty() and loaded.copied.cell_size == 75.0, "Assembly reload adapts cell size")
  var state := ConfigFile.new()
  state.load("user://qualification-restart.cfg")
  state.set_value("restart", "assembly", saved.path)
  state.save("user://qualification-restart.cfg")
  check(Assemblies.entries().any(func(entry): return entry.path == saved.path), "Assembly appears in the library")
  var delete_copy: String = saved.path.get_basename() + "-delete.tres"
  DirAccess.copy_absolute(ProjectSettings.globalize_path(saved.path), ProjectSettings.globalize_path(delete_copy))
  check(DirAccess.remove_absolute(ProjectSettings.globalize_path(delete_copy)) == OK and not Assemblies.entries().any(func(entry): return entry.path == delete_copy), "Deleted assembly disappears from the library")
 var corrupt := Assemblies.DIRECTORY.path_join("invalid.tres")
 var bad := Act.new()
 bad.editor_locks = {"terrain": [99999]}
 ResourceSaver.save(bad, corrupt)
 check(not Assemblies.entries().any(func(entry): return entry.path == corrupt), "Corrupt assembly is excluded from library entries")
 check(document.editing_fingerprint() == source_fingerprint, "Clipboard and assembly operations never mutate the source Act")

func histories(document: Resource) -> void:
 var piece: Dictionary = document.placements[-1].duplicate(true)
 var original_sources: Array = piece.editor_sources.sources.duplicate(true)
 var sources := History.restore(piece)
 check(sources.error.is_empty() and sources.sources == original_sources, "Unchanged composite restores exact source records")
 var source_transform: Transform2D = History.placement_transform(piece)
 var mapping := Transform2D(deg_to_rad(37.0), Vector2(2.5, -1.75)).scaled_local(Vector2(-1.2, 1.2))
 History.set_transform(piece, mapping * source_transform)
 var restored := History.restore(piece)
 check(restored.error.is_empty(), "Moved, rotated, scaled and mirrored composite can recover sources")
 if restored.error.is_empty():
  for index in original_sources.size():
   var expected := Fixture.terrain_points(original_sources[index], 1.0)
   for point in expected.size(): expected[point] = mapping * expected[point]
   check(close_points(Fixture.terrain_points(restored.sources[index], 1.0), expected, 0.0001), "Recovery follows the final composite transform for source %d" % index)
 var no_history: Dictionary = piece.duplicate(true)
 no_history.erase("editor_sources")
 check(not History.restore(no_history).error.is_empty(), "Legacy composite refuses to invent missing sources")
 var nested := Fixture.piece(Vector2i(4, 4))
 for level in 20:
  var next := Fixture.piece(Vector2i(4, 4))
  History.remember(next, [nested])
  nested = next
 check(History.validation_error(nested.editor_sources).is_empty(), "Remember caps nested source histories at the documented depth")
 var depth := 0
 var cursor: Dictionary = nested
 while cursor.has("editor_sources"):
  depth += 1
  cursor = cursor.editor_sources.sources[0]
 check(depth == 16, "Source history retains exactly sixteen levels")
 var oversized := {"reference": Transform2D.IDENTITY, "sources": []}
 oversized.sources.resize(History.MAX_SOURCES + 1)
 check(not History.validation_error(oversized).is_empty(), "Oversized source history rejects before traversal")
 var deep: Dictionary = nested.duplicate(true)
 deep.editor_sources.sources[0] = nested
 check(not History.validation_error(deep.editor_sources).is_empty(), "Externally supplied over-depth history is rejected")
 var open_piece: Dictionary = document.placements[3]
 check(not Composite.merge([open_piece, original_sources[0]]).error.is_empty(), "Open walls cannot enter a filled merge")
 check(not Composite.merge([Fixture.piece(Vector2i(1, 1)), Fixture.piece(Vector2i(20, 20))]).error.is_empty(), "Disconnected islands reject atomically")

func selection_guards(document: Resource) -> void:
 var selected := Selection.single("gameplay", 5)
 var group: Dictionary = document.editor_groups[0].members
 check(Selection.expanded(document, selected) == group, "Selecting one member expands the complete mixed group")
 for protection in ["editor_locks", "editor_hidden"]:
  var protected: Resource = document.copy_document()
  protected.set(protection, Selection.single("decor", 0))
  check(Selection.count(Selection.expanded(protected, selected)) == 0, "Partial %s protects the entire group" % protection)
 var unlocked: Resource = document.copy_document()
 unlocked.editor_locks = {}
 unlocked.editor_hidden = {}
 Selection.ungroup(unlocked, selected)
 check(unlocked.editor_groups.is_empty(), "Ungroup removes the intersected group only")

func border_mirrors() -> void:
 var document := Fixture.base("Border mirror precision")
 var piece := Fixture.piece(Vector2i(5, 1), "triangle_1x3")
 piece.quarter_turns = 1
 piece.flip_h = true
 piece.flip_v = true
 document.placements = [piece]
 var selection := Selection.single("terrain", 0)
 var pivot := Vector2(325, 75)
 Transform.apply(document, selection, pivot, 1.0, 90.0)
 var before := Fixture.terrain_points(document.placements[0])
 for horizontal: bool in [true, false, true, false]:
  pivot = Transform.bounds(document, selection).get_center()
  var expected := before.duplicate()
  for index in expected.size():
   if horizontal: expected[index].x = 2.0 * pivot.x - expected[index].x
   else: expected[index].y = 2.0 * pivot.y - expected[index].y
  Transform.mirror(document, selection, pivot, horizontal)
  check(document.validation_errors().is_empty(), "Border-touching terrain mirror remains valid without boundary adjustment")
  var actual := Fixture.terrain_points(document.placements[0])
  var matches := actual.size() == expected.size()
  for index in actual.size(): matches = matches and actual[index].distance_to(expected[index]) < 0.001
  check(matches, "Border mirror agrees with independently reflected vertices")
  before = actual

func recovery(document: Resource) -> void:
 var source := "user://qualification-roundtrip.tres"
 var before := FileAccess.get_sha256(source)
 var first := Recovery.save_copy(document, source, "session-a", "", true)
 var again := Recovery.save_copy(document, source, "session-b", "", true)
 check(first.error.is_empty() and again.path == first.path, "A saved source has one automatic recovery copy across sessions")
 var unsaved := Recovery.save_copy(document, "", "session-a", "", true)
 var unsaved_again := Recovery.save_copy(document, "", "session-a", "", true)
 var different := Recovery.save_copy(document, "", "session-b", "", true)
 check(unsaved.path == unsaved_again.path and unsaved.path != different.path and unsaved.path != first.path, "Unsaved automatic recovery is keyed by editing session")
 var named := Recovery.save_copy(document, source, "session-a", "Qualification checkpoint", false)
 var named_again := Recovery.save_copy(document, source, "session-a", "Qualification checkpoint", false)
 check(named.error.is_empty() and named.path != named_again.path, "Named checkpoints are retained separately")
 var backup: String = first.path.get_basename() + ".backup-interrupted.tres"
 DirAccess.copy_absolute(ProjectSettings.globalize_path(first.path), ProjectSettings.globalize_path(backup))
 check(Recovery.entries().any(func(entry): return entry.path == backup and entry.label == "Interrupted save backup"), "Interrupted atomic-save backup is discoverable")
 check(FileAccess.get_sha256(source) == before, "Recovery writes never modify the authored source")

func run() -> void:
 if "--restart" in OS.get_cmdline_user_args():
  var receipt := ConfigFile.new()
  check(receipt.load("user://qualification-restart.cfg") == OK, "Restart finds persisted qualification receipt")
  var loaded := Act.load_document("user://qualification-save-as.tres")
  check(loaded.document != null and loaded.document.editing_fingerprint() == receipt.get_value("restart", "fingerprint"), "Fresh process reloads exact format-19 state")
  var assembly := Assemblies.load_copy(receipt.get_value("restart", "assembly", ""), 50.0)
  check(assembly.error.is_empty() and assembly.copied.banks.size() == 2, "Fresh process reloads assembly with both isolated objectives")
 else:
  var document := Fixture.dense()
  check(document.validation_errors().is_empty(), "Dense fixture validates: " + str(document.validation_errors()))
  for slot: Dictionary in document.decor_slots:
   check(Fixture.Decor.supported_in_document(slot.position, document), "Dense fixture mounts Decor on real terrain: " + slot.slot_id)
  if document.validation_errors().is_empty():
   persistence(document)
   selection_guards(document)
   border_mirrors()
   mirrors(document)
   clipboard_and_assemblies(document)
   histories(document)
   recovery(document)
   DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Fixture.DIRECTORY))
   var state := ConfigFile.new()
   state.load("user://qualification-restart.cfg")
   var recipe := Assemblies.load_copy(state.get_value("restart", "assembly", ""), 50.0)
   var linked_fixture := Fixture.base("Qualification B - mirrored persisted assembly")
   var linked_vertical := Fixture.base("Qualification B - vertically mirrored persisted assembly")
   if recipe.error.is_empty():
    var placed := Clipboard.append_to(linked_fixture, recipe.copied, Vector2.ZERO)
    check(placed.error.is_empty(), "Fixture B places the persisted assembly")
    Selection.group(linked_fixture, placed.selection)
    linked_fixture.editor_groups[0].name = "Mirrored linked assembly"
    linked_vertical = linked_fixture.copy_document()
    linked_vertical.title = "Qualification B - vertically mirrored persisted assembly"
    Transform.mirror(linked_vertical, Fixture.all(linked_vertical), Vector2(800, 1000), false)
    Transform.mirror(linked_fixture, Fixture.all(linked_fixture), Vector2(800, 1000), true)
   var smooth_fixture := Fixture.smoothed()
   Transform.mirror(smooth_fixture, Selection.single("terrain", 0), Vector2(800, 1000), false)
   for entry: Dictionary in [{"name": "dense", "document": document}, {"name": "linked", "document": linked_fixture}, {"name": "linked_vertical", "document": linked_vertical}, {"name": "smoothed", "document": smooth_fixture}]:
    var path := Fixture.DIRECTORY.path_join(entry.name + ".tres")
    check(entry.document.save_document(path) == OK, "Qualification fixture saves: " + entry.name)
    var loaded := Act.load_document(path)
    check(loaded.document != null and loaded.document.editing_fingerprint() == entry.document.editing_fingerprint(), "Qualification fixture reopens: " + entry.name)
 var output := FileAccess.open("user://qualification-core-result.json", FileAccess.WRITE)
 output.store_string(JSON.stringify({"checks": checks, "failures": failures, "failed": failed}, "  "))
 output.close()
 print("EDITOR QUALIFICATION CORE | %d checks | %d failures" % [checks, failures])
 quit(failures)
