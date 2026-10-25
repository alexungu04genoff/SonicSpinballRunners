extends SceneTree
const Act = preload("res://scripts/act_editor/act_geometry.gd")
const Slots = preload("res://scripts/act_editor/decor_slots.gd")
const DecorSkin = preload("res://scripts/decor/decor_skin.gd")
const GreenHill = preload("res://scripts/decor/green_hill_decor.gd")
const SAVE := "res://test-results/decor-roundtrip.tres"
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 checks += 1
 if ok: print("PASS | ", message)
 else:
  failures += 1
  push_error("FAIL | " + message)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var skin := GreenHill.new(null)
 if OS.get_cmdline_user_args().has("--reload-decor"):
  var loaded := Act.load_document(SAVE)
  check(loaded.document != null, "Fresh process loads decor")
  if loaded.document != null:
   check(loaded.document.fingerprint() == OS.get_cmdline_user_args()[-2], "Fresh process retains exact data")
   check(skin.resolve(loaded.document.decor_identity(), loaded.document.decor_slots[0]) == OS.get_cmdline_user_args()[-1], "Fresh process chooses the same variant")
   var fixed_loaded := Act.load_document("res://test-results/decor-fixed.tres")
   check(fixed_loaded.document != null and fixed_loaded.document.decor_slots[0].variant_mode == "fixed" and fixed_loaded.document.decor_slots[0].variant_index == 9, "Fresh process preserves the fixed generic index")
  finish()
  return
 var act := Act.new()
 act.decor_seed = "stable-act"
 var slot := Slots.make_slot("large")
 slot.slot_id = "stable-slot"
 slot.position = Vector2(38.125, 44.625)
 slot.rotation_degrees = PI * 17.0
 slot.scale = 1.0 + 0.1234567890123
 slot.placement_hint = "edge"
 act.decor_slots.append(slot)
 check(act.validation_errors().is_empty(), "Generic slot schema accepts exact transforms")
 var before := act.fingerprint()
 var manual := Slots.make_slot("small")
 manual.placement_hint = "surface"
 manual.variant_mode = "fixed"
 manual["variant_index"] = 0
 var generic := DecorSkin.new("other", {"small": {"surface": ["beacon", "valve"]}})
 var sequence := PackedStringArray()
 for index in [0, 1, 0]:
  manual.variant_index = index
  sequence.append(skin.resolve("any seed", manual))
  check(generic.resolve("any seed", manual) == ["beacon", "valve"][index], "Fixed index maps through the active skin's own pool")
 check(sequence == PackedStringArray(["flower", "small_rock", "flower"]), "Fixed variants author flower-rock-flower independently of slot IDs")
 manual.variant_index = 9
 var unchanged := var_to_bytes(manual)
 var fallback := manual.duplicate(true)
 fallback.variant_mode = "auto"
 check(skin.resolve("seed", manual) == skin.resolve("seed", fallback) and not skin.variant_warning(manual).is_empty() and var_to_bytes(manual) == unchanged, "Unavailable fixed index warns and falls back to deterministic Auto without changing the Act")
 var fixed_act := Act.new()
 fixed_act.decor_slots = [manual]
 var fixed_path := "res://test-results/decor-fixed.tres"
 check(fixed_act.save_document(fixed_path) == OK and Act.load_document(fixed_path).document.fingerprint() == fixed_act.fingerprint(), "Generic fixed index persists even when outside the current theme's pool")
 var fixed_text := FileAccess.get_file_as_string(fixed_path)
 check(not fixed_text.contains("flower") and not fixed_text.contains("small_rock") and fixed_text.contains("variant_index"), "Saved Act contains generic indices and no prop names")
 for mutation: Dictionary in [{"variant_index": -1}, {"variant_index": 1.5}, {"variant_index": true}, {"variant_index": "flower"}]:
  var malformed := manual.duplicate(true)
  malformed.merge(mutation, true)
  check(not Slots.validation_error(malformed).is_empty(), "Malformed fixed index rejects")
 var missing := manual.duplicate(true)
 missing.erase("variant_index")
 check(not Slots.validation_error(missing).is_empty(), "Fixed mode requires an index")
 var legacy_auto := act._storage_document()
 legacy_auto.format_version = 9
 ResourceSaver.save(legacy_auto, fixed_path)
 check(Act.load_document(fixed_path).document.fingerprint() == before, "Format 9 Auto decor migrates unchanged")
 legacy_auto.decor_slots = [manual]
 ResourceSaver.save(legacy_auto, fixed_path)
 check(Act.load_document(fixed_path).document == null, "Old schema cannot carry fixed-variant fields")
 check(fixed_act.save_document(fixed_path) == OK, "Restore fixed fixture for fresh-process verification")
 check(act.save_document(SAVE) == OK, "Atomic decor save succeeds")
 var loaded := Act.load_document(SAVE)
 check(loaded.document != null and loaded.document.fingerprint() == before, "Save/load preserves numeric bits, stable seed and slot ID")
 var choice := skin.resolve(act.decor_identity(), slot)
 check(choice in ["palm", "palm_left"], "Green Hill large edge resolves to the palm family")
 var other := DecorSkin.new("industrial_test", {"large": {"edge": ["pipe_tower", "tank"]}})
 check(other.resolve(act.decor_identity(), slot) in ["pipe_tower", "tank"] and act.fingerprint() == before, "The same unchanged Act resolves through another skin")
 var choices: Dictionary = {}
 for i in 64:
  var sample := slot.duplicate(true)
  sample.slot_id = "sample-%d" % i
  choices[skin.resolve(act.decor_identity(), sample)] = true
 check(choices.size() == 2, "Stable slot IDs exercise both auto variants")
 var copied: Resource = act.copy_document()
 copied.decor_slots.push_front(Slots.make_slot("small"))
 copied.decor_slots.reverse()
 check(skin.resolve(copied.decor_identity(), copied.decor_slots[0]) == choice, "Insertion and reordering do not reshuffle an existing slot")
 copied.decor_slots.pop_back()
 check(skin.resolve(copied.decor_identity(), copied.decor_slots[0]) == choice, "Deleting another slot preserves the chosen variant")
 copied.decor_slots[0].rotation_degrees += 0.125
 check(copied.fingerprint() != before and act.fingerprint() == before, "Deep copies and fingerprints track decor changes independently")
 var invalid := slot.duplicate(true)
 for mutation: Dictionary in [{"slot_type": "palm_tree_01"}, {"placement_hint": "ceiling"}, {"variant_mode": "palm"}, {"position": Vector2(INF, 0)}, {"rotation_degrees": NAN}, {"scale": 1.16}, {"scale": true}, {"mesh": "palm"}, {"slot_id": ""}]:
  invalid = slot.duplicate(true)
  invalid.merge(mutation, true)
  check(not Slots.validation_error(invalid).is_empty(), "Malformed decor rejected: " + str(mutation.keys()))
 copied = act.copy_document()
 copied.decor_slots.append(slot.duplicate(true))
 check(not copied.validation_errors().is_empty(), "Duplicate slot identities rejected")
 for version in [2, 3, 4, 5, 6]:
  var old := Act.new()
  old.format_version = version
  var path := "res://test-results/decor-legacy-%d.tres" % version
  ResourceSaver.save(old, path)
  var bytes := FileAccess.get_file_as_bytes(path)
  var migrated := Act.load_document(path)
  check(migrated.document != null and migrated.document.decor_slots.is_empty() and migrated.document.format_version == Act.FORMAT_VERSION and bytes == FileAccess.get_file_as_bytes(path), "Format %d loads empty decor without rewriting source" % version)
 for file: String in ["decor_terraces", "decor_garden_steps", "decor_loop_court"]:
  var example := Act.load_document("res://data/acts/%s.tres" % file)
  check(example.document != null, "Example validates: " + file)
  if example.document == null: continue
  var types: Dictionary = {}
  var supported := true
  for item: Dictionary in example.document.decor_slots:
   types[item.slot_type] = true
   supported = supported and Slots.supported_in_document(item.position, example.document)
  check(types.size() == 4 and supported, "Example includes all four sizes on raised terrain: " + file)
 var output: Array = []
 var result := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/decor_regression.gd", "--", "--reload-decor", before, choice], output, true)
 check(result == 0 and str(output).contains("4 checks | 0 failures"), "Fresh-process serialization and variation verified")
 finish()

func finish() -> void:
 print("RESULT | Decor data | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
