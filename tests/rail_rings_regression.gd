extends SceneTree
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const RailRings = preload("res://scripts/authored_act/rail_rings.gd")
const RailPath = preload("res://scripts/authored_act/rail_path.gd")
const RingField = preload("res://scripts/ring_field.gd")
const ActData = preload("res://scripts/act_editor/act_geometry.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func _initialize() -> void:
 if "--stream" in OS.get_cmdline_user_args():
  call_deferred("stream_checks")
  return
 var rail := Objects.make_placement("elevated_rail")
 rail.object_id = "curved_rail"
 rail.position = Vector2(150, 250)
 rail.rotation_degrees = 37.0
 rail.properties.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -100), Vector2(120, -120), Vector2(180, 0)])
 var samples := RailRings.samples(rail, Objects.properties(rail))
 var control: PackedVector2Array = rail.properties.points.duplicate()
 for i in control.size(): control[i] = rail.position + control[i].rotated(deg_to_rad(37.0))
 var path := RailPath.build(control)
 check(samples.size() == floori(path.length / 35.0), "Ring count follows curved arc length")
 check(samples.all(func(ring): return ring.position.is_equal_approx(RailPath.sample(path, ring.distance)) and is_equal_approx(ring.height, RailPath.height(path, ring.distance, rail.properties.height))), "Rotated rail rings follow the exact physics centerline and height")
 var evenly_spaced := true
 for i in range(1, samples.size()): evenly_spaced = evenly_spaced and is_equal_approx(samples[i].distance - samples[i - 1].distance, 35.0)
 check(evenly_spaced and is_equal_approx(samples[0].distance, path.length - samples[-1].distance), "Rings have equal spacing and symmetric mouth clearance")
 var document := ActData.new()
 document.gameplay_objects = [rail]
 var offset := Vector2(0, -1600)
 var records := RingField.document_records(document, "act:2", offset)
 check(records.size() == samples.size() and records[0].position == samples[0].position + offset and records[0].rack.owner_id == "act:2", "Streaming offsets ring positions and owns the pattern per Act")
 var neighbor := RingField.document_records(document, "act:3", offset * 2)
 check(records[0].source_id != neighbor[0].source_id, "Repeated authored rails have distinct scoring identities in neighboring Acts")
 var field := RingField.new()
 var ball := preload("res://scripts/ball.gd").new()
 ball.serve_pending = false
 ball._teleport_pending = false
 field.ball = ball
 field.rings = records + neighbor
 field.active_owner_id = "act:2"
 field.collect_rail_progress("curved_rail", path.length, 0.0, "act:3")
 check(neighbor.all(func(ring): return ring.active), "Inactive neighboring Act cannot award its rail rings")
 field.collect_rail_progress("curved_rail", path.length, 0.0, "act:2")
 check(records.all(func(ring): return not ring.active) and neighbor.all(func(ring): return ring.active), "Reverse travel sweeps all crossed rings only in the active Act")
 check(records[0].rack.remaining == 0 and records[0].rack.respawn_remaining > 0 and not records[0].rack.settings.bonus_rack, "Rail chain uses ordinary ring respawn without an implicit rack bonus")
 field.collect_rail_progress("curved_rail", 0.0, path.length, "act:2")
 check(records[0].rack.remaining == 0, "Crossing collected rings cannot award them twice")
 field.free()
 ball.free()
 rail.properties.rings_enabled = false
 check(RingField.document_records(document, "off").is_empty(), "Disabled rail produces no ring data")
 rail.properties.rings_enabled = true
 rail.properties.ring_spacing = 50.0
 check(RailRings.samples(rail, Objects.properties(rail)).size() < samples.size(), "Larger spacing produces fewer rings")
 rail.properties.ring_spacing = 0.0
 check(not Objects.property_errors(rail).is_empty(), "Zero ring spacing is rejected by authored validation")
 rail.properties.erase("ring_spacing")
 rail.properties.erase("rings_enabled")
 check(RailRings.samples(rail, Objects.properties(rail)).size() == samples.size(), "Existing rails inherit enabled rings and default spacing")
 print("RESULT | Rail rings | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func stream_checks() -> void:
 var game := preload("res://scripts/prototype/zone_run.gd").new()
 var path := "res://data/acts/Authored/RampMania.tres"
 game.source_paths = [path, path, path]
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 180000
 while not game.started and game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
 check(game.started and game.resident.size() >= 2, "Baked rail Acts start in the real prototype")
 if game.started:
  while not game.resident[1].ready and Time.get_ticks_msec() < deadline: await process_frame
  check(game.resident[1].ready, "Baked neighboring rail Act attaches completely")
  game.set_physics_process(false)
  game.ring_field.set_physics_process(false)
  game.specials.set_physics_process(false)
  game.ball.freeze = true
  game.ball.serve_pending = false
  game.ball._teleport_pending = false
  check(game.presentation.ring_visuals.size() == game.ring_field.rings.size(), "Streamed visuals and collectible records share the same ordering and count")
  var positions_match := true
  for i in game.ring_field.rings.size():
   var ring: Dictionary = game.ring_field.rings[i]
   var expected: Vector3 = game.presentation.map_point(ring.position, game.presentation.ring_height() + float(ring.get("height", 0.0)) * game.presentation.SCALE)
   positions_match = positions_match and game.presentation.ring_visuals[i].global_position.is_equal_approx(expected)
  check(positions_match, "Baked ring nodes match runtime centers and elevation in both streamed Acts")
  var count_before: int = game.rings_collected
  for item: Dictionary in game.resident[1].runtime.mechanics.items:
   if item.type == "elevated_rail": game.resident[1].runtime.mechanics.rail_traveled.emit(item.object_id, 0.0, item.path.length)
  check(game.rings_collected == count_before, "Real neighbor signal wiring cannot award rings")
  var active_count := 0
  for ring: Dictionary in game.active.ring_data:
   if ring.has("rail_id"): active_count += 1
  for item: Dictionary in game.active.runtime.mechanics.items:
   if item.type == "elevated_rail": game.active.runtime.mechanics.rail_traveled.emit(item.object_id, 0.0, item.path.length)
  check(active_count > 0 and game.rings_collected - count_before == active_count, "Real active-Act signal wiring awards every rail ring")
  check(game.active.ring_data.filter(func(ring): return not ring.has("rail_id")).all(func(ring): return ring.active), "Streamed rail travel leaves floor rings untouched")
 await game.prepare_to_close()
 game.free()
 await process_frame
 print("RESULT | Rail rings streaming | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
