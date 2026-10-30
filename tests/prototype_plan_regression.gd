extends SceneTree
const RunPlan = preload("res://scripts/prototype/run_plan.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Buddies = preload("res://scripts/prototype/buddies.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func _initialize() -> void:
 var paths := RunPlan.source_paths()
 var documents: Array = []
 var fingerprints: Array = []
 check(paths.size() >= 6, "The prototype discovers the requested authored folder")
 for path: String in paths:
  var loaded := Document.load_document(path)
  check(loaded.document != null, "Authored source loads: " + path)
  if loaded.document == null: continue
  documents.append(loaded.document)
  fingerprints.append(loaded.document.fingerprint())
 check(RunPlan.pool_error(documents).is_empty(), "Every authored connector can join every other Act")
 check(not RunPlan.pool_error(documents.slice(0, 5)).is_empty() and RunPlan.build([], 18).is_empty(), "An incomplete pool is rejected without indexing an absent Act")
 var first := RunPlan.build(documents, 18)
 check(first.size() == 6 and first == RunPlan.build(documents, 18), "An explicit seed reproduces exactly six Acts")
 var orders := {}
 for seed_value in 20:
  var entries := RunPlan.build(documents, seed_value)
  var seen := {}
  var valid := entries.size() == 6
  for i in entries.size():
   var entry: Dictionary = entries[i]
   valid = valid and not seen.has(entry.id) and entry.sequence == i and entry.zone == i / 3 and entry.act == i % 3 and entry.theme == RunPlan.THEMES[i / 3]
   seen[entry.id] = true
   if i > 0:
    valid = valid and entry.offset == RunPlan.StreamPlan.aligned_offset(documents[entries[i - 1].id], entries[i - 1].offset, documents[entry.id])
  check(valid, "Seed %d uses six distinct sources and aligned connectors across both Zones" % seed_value)
  orders[str(entries)] = true
 check(orders.size() > 1, "Different seeds produce different run orders")
 var unchanged := true
 for i in documents.size(): unchanged = unchanged and documents[i].fingerprint() == fingerprints[i]
 check(unchanged, "Planning preserves source geometry, score settings and bake fingerprints")
 var buddies := Buddies.new()
 for draft in 5:
  var offers := buddies.offers()
  check(not offers.is_empty() and buddies.choose(offers[0].id), "Draft %d has a valid upgrade without exceeding the level cap" % (draft + 1))
 print("RESULT | Prototype plan | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
