extends SceneTree
## Optional reference comparison and sequential CPU benchmark; no rendering/FPS claim.
const Current = preload("res://scripts/ring_field.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const SOURCES := ["res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/Secret Entry.tres", "res://data/acts/Authored/SpringUp.tres"]
const STEP := 1.0 / 120.0
var events: Array = [[], []]
var documents: Array = []
var report := {}
var baseline_path := ""
var output_path := "res://test-results/ring-rack-profile.json"

func _initialize() -> void: run.call_deferred()

func records(generation := 0) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for i in documents.size(): result.append_array(Current.document_records(documents[i], "owner:%d:%d" % [generation, i], Vector2(i * 3000, -i * 5000)))
 return result

func field(script: Script) -> Node:
 var result: Node = script.new()
 result.ball = PlaygroundBall.new()
 result.tuning = PhysicsTuning.new()
 result.ball.tuning = result.tuning
 result.ball.position = Vector2(100000, -100000)
 result.ball.serve_pending = false
 result.ball._teleport_pending = false
 result.rings = records()
 result.active_owner_id = "owner:0:0"
 result.previous_ball_position = result.ball.position
 return result

func dispose(item: Node) -> void:
 item.ball.free()
 item.tuning.free()
 item.free()

func listen(item: Node, which: int) -> void:
 item.pickup_claimed.connect(func(index: int): events[which].append(["pickup", index]))
 item.scoring_pickup.connect(func(at: Vector2, source: String, multiplier: int): events[which].append(["score", at, source, multiplier]))
 item.collected.connect(func(at: Vector2): events[which].append(["collected", at]))
 item.feature_completed.connect(func(kind: StringName, id: String, bonus: int): events[which].append(["feature", kind, id, bonus]))
 item.rack_completed.connect(func(at: Vector2, id: String): events[which].append(["complete", at, id]))
 item.rack_reset.connect(func(): events[which].append(["reset"]))

func equivalence(baseline: Script) -> bool:
 var fields := [field(baseline), field(Current)]
 for i in 2: listen(fields[i], i)
 var random := RandomNumberGenerator.new()
 random.seed = 8112026
 var generation := 0
 for tick in 4000:
  var action := random.randi_range(0, 11)
  var index := random.randi_range(0, fields[0].rings.size() - 1)
  var owner := random.randi_range(-1, 3)
  var delta := random.randf_range(0.01, 0.8)
  var offset := Vector2(random.randf_range(-3, 3), random.randf_range(-3, 3))
  if action == 7: generation += 1
  for item: Node in fields:
   match action:
    0: item.advance_racks(delta)
    1: item.claim_ring(index, "fixture", 2)
    2: item.active_owner_id = "" if owner < 0 else "owner:%d:%d" % [generation, owner]
    3: item.scoring_enabled = not item.scoring_enabled
    4: item.reset_rings()
    5: item.collection_bounds = Rect2(item.rings[index].home - Vector2(15, 15), Vector2(30, 30)) if owner >= 0 else Rect2()
    6:
     item.rings[index].home += offset
     item.rings[index].position += offset
    7: item.rings = records(generation)
    8:
     var first: Dictionary = item.rings.pop_front()
     item.rings.append(first)
     if item.has_method("invalidate_rack_cache"): item.invalidate_rack_cache()
    9: item.add_pattern({"start": Vector2(7000, 70), "end": Vector2(7020, 70), "spacing": 10.0}, "added_%d" % tick, item.active_owner_id)
    10:
     var ring: Dictionary = item.rings[index]
     if ring.has("rail_id"): item.collect_rail_progress(ring.rail_id, 0, ring.rail_distance + 100, ring.rack.owner_id)
    11:
     item.ball.position = item.rings[index].position
     item._physics_process(delta)
  if fields[0].rings != fields[1].rings or events[0] != events[1] or fields[0].previous_ball_position != fields[1].previous_ball_position:
   push_error("Equivalence mismatch at tick %d action %d" % [tick, action])
   for item: Node in fields: dispose(item)
   return false
  events[0].clear()
  events[1].clear()
 for item: Node in fields: dispose(item)
 report.equivalence = {"steps": 4000, "seed": 8112026, "states_and_signal_order_equal": true}
 print("RACK_EQUIVALENCE | 4000 steps | states and signal order identical")
 return true

func median(values: Array[float]) -> float:
 var sorted := values.duplicate()
 sorted.sort()
 return (sorted[sorted.size() / 2 - 1] + sorted[sorted.size() / 2]) * 0.5

func profile(baseline: Script) -> void:
 var inventory := records()
 var seen := {}
 var active := {}
 for ring: Dictionary in inventory:
  seen[ring.rack.id] = true
  if ring.rack.owner_id == "owner:0:0": active[ring.rack.id] = true
 report.inventory = {"sources": SOURCES, "resident_rings": inventory.size(), "resident_racks": seen.size(), "active_racks": active.size()}
 report.samples = []
 for armed: bool in [false, true]:
  for method: String in ["advance_racks", "_physics_process"]:
   var fields := [field(baseline), field(Current)]
   for item: Node in fields:
    if armed:
     for ring: Dictionary in item.rings: ring.rack.timeout_remaining = 1000000.0
    item.advance_racks(STEP)
   var values: Array = [[], []]
   for sample in 12:
    var order := [0, 1] if sample % 2 == 0 else [1, 0]
    for i: int in order:
     var callback := Callable(fields[i], method)
     var started := Time.get_ticks_usec()
     for tick in 3000: callback.call(STEP)
     values[i].append(float(Time.get_ticks_usec() - started) / 3000.0)
   var before: Array[float] = []
   var after: Array[float] = []
   before.assign(values[0])
   after.assign(values[1])
   var row := {"method": method, "armed": armed, "blocks_per_version": 12, "calls_per_block": 3000,
    "baseline_us_per_call": values[0], "cached_us_per_call": values[1], "baseline_median_us": median(before), "cached_median_us": median(after)}
   report.samples.append(row)
   print("RACK_PROFILE | ",JSON.stringify(row))
   for item: Node in fields: dispose(item)

func run() -> void:
 for path: String in SOURCES: documents.append(Document.load_document(path).document)
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--baseline="): baseline_path = argument.trim_prefix("--baseline=")
  if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
 if DisplayServer.get_name() != "headless" or not FileAccess.file_exists(baseline_path):
  push_error("Run headlessly with -- --baseline=<previous ring_field.gd> [--profile].")
  quit(1)
  return
 var baseline := GDScript.new()
 baseline.source_code = FileAccess.get_file_as_string(baseline_path).trim_prefix("\uFEFF").replace("\r", "").trim_prefix("class_name RingField\n")
 if baseline.reload() != OK:
  push_error("Could not compile the supplied RingField baseline.")
  quit(1)
  return
 report = {"baseline_script": baseline_path, "baseline_source_sha256": FileAccess.get_sha256(baseline_path), "engine": Engine.get_version_info().string, "headless": DisplayServer.get_name() == "headless", "processor": OS.get_processor_name(), "scope": "Sequential headless CPU method calls; no rendering or Windows FPS measurement."}
 if not equivalence(baseline): quit(1); return
 if "--profile" in OS.get_cmdline_user_args(): profile(baseline)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
 var output := FileAccess.open(output_path, FileAccess.WRITE)
 if output == null:
  push_error("Cannot save the CPU profile: " + error_string(FileAccess.get_open_error()))
  quit(1)
  return
 output.store_string(JSON.stringify(report, "  "))
 quit()
