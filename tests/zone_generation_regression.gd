extends "res://tests/grid_chunk_regression.gd"
## The Zone uses the existing static validation and real 2D collision fixtures.
const ZONE = preload("res://scripts/zone_generator.gd")

func catalogue_geometry() -> String:
 var snapshots := PackedStringArray()
 for chunk: ChunkData in [TableGenerator.LOWER] + TableGenerator.CATALOGUE + TableGenerator.MIDDLE_CATALOGUE:
  snapshots.append(compact_geometry(chunk))
 return "\n".join(snapshots)

func run() -> void:
 var source_hash := catalogue_geometry()
 var deterministic := true
 var connected := true
 var easy := true
 var act_bounds := true
 var checkpoints := true
 var topology := true
 var swings := true
 var mirrored := false
 var mixed_grid := false
 var signatures: Dictionary = {}
 var sample: Dictionary = {}
 for mode in [0, 1, 2]:
  for seed_value in [1, 8, 18, 23]:
   var layout := ZONE.generate(seed_value, mode)
   check(layout.valid, "Nine-section Zone builds: seed %d, grid %d" % [seed_value, mode], str(layout.get("errors", [])))
   if not layout.valid:
    continue
   var repeat := ZONE.generate(seed_value, mode)
   deterministic = deterministic and repeat.valid and geometry_hash(layout) == geometry_hash(repeat) and layout.acts == repeat.acts
   connected = connected and layout.chunks.size() == 9 and layout.junctions.size() == 8 and TableGenerator.validate_course(layout.chunks).valid
   easy = easy and layout.difficulty_estimate.band == TableGenerator.Difficulty.EASY and layout.preference_available
   topology = topology and layout.chunks[0].top_connection.size == Vector2.ZERO and layout.chunks[8].chunk_id == "launch_deck"
   for i in range(1, 8):
    var relay: ChunkData = layout.chunks[i]
    topology = topology and relay.top_connection.size.x >= 690.0 and relay.bottom_connection.size.x >= 690.0 and not relay.markers.has("serve")
    swings = swings and flippers_clear(relay)
    mirrored = mirrored or relay.mirrored
    mixed_grid = mixed_grid or (mode == 0 and not relay.construction_grid.is_empty())
    if mode > 0:
     topology = topology and relay.construction_grid.recipe_id == ZONE.EASY_GRID[mode - 1].recipe_id
   for junction: Dictionary in layout.junctions:
    easy = easy and junction.junction_rails.is_empty() and junction.passage.size.x >= 618.0 and ConnectorTransitions.maximum_grade(junction.transition_paths) < 0.5
   for act_index in 3:
    var act: Dictionary = layout.acts[act_index]
    var expected := Rect2(0, (2 - act_index) * 2100, 800, 2100)
    act_bounds = act_bounds and act.bounds == expected and act.chunk_indices == [6 - act_index * 3, 7 - act_index * 3, 8 - act_index * 3]
    checkpoints = checkpoints and act.bounds.has_point(act.entry)
    var geometry: Array[Dictionary] = []
    for index: int in act.chunk_indices:
     geometry.append_array(layout.chunks[index].gameplay_descriptors())
    checkpoints = checkpoints and TableGenerator.point_clear(act.entry, geometry, PlaygroundBall.RADIUS + 6.0)
    if act_index > 0:
     checkpoints = checkpoints and act.entry.y < act.bounds.end.y - 70.0
    if act_index < 2:
     var top: ChunkData = layout.chunks[act.chunk_indices[0]]
     var exit := top.world_rect(top.top_connection)
     act_bounds = act_bounds and is_equal_approx(act.exit_y, act.bounds.position.y) and is_equal_approx(act.exit_left, exit.position.x) and is_equal_approx(act.exit_right, exit.end.x)
    else:
     checkpoints = checkpoints and act.bounds.has_point(act.goal_position) and TableGenerator.point_clear(act.goal_position, geometry, ScoreAttack.GOAL_RADIUS)
   signatures[geometry_hash(layout)] = true
   if mode == 0 and seed_value == 18:
    sample = layout
 check(deterministic and signatures.size() >= 8, "Same seed repeats geometry and checkpoints; different seeds retain variety")
 check(connected, "All eight seams and every route validate as one connected course")
 check(easy, "All three Acts retain broad Easy geometry with no closure shoulders")
 check(topology, "Exactly one launch deck, one capped top and seven open relays; grid modes stay explicit")
 check(act_bounds, "Three exact nonoverlapping Act bounds and exits derive from the joined geometry")
 check(checkpoints, "Checkpoint serves and final portal stay inside clear geometry across mirrored recipes")
 check(swings and mirrored and mixed_grid, "Mirrored legacy and grid relays retain complete flipper swing clearance")
 check(source_hash == catalogue_geometry(), "Generation does not modify shared catalogue resources")
 if not sample.is_empty():
  passive_fixture(sample.chunks, sample.junctions)
  var crossed := true
  for junction: Dictionary in sample.junctions:
   var seam: float = junction.passage.get_center().y
   var x: float = junction.passage.get_center().x
   var shot := await passive_shot(Vector2(x, seam + 70), Vector2(0, -1200), 18)
   crossed = crossed and shot.finite and shot.position.y < seam - 70.0 and shot.velocity.y < 0.0
  check(crossed, "Real 2D ball passes upward through all eight open seams without a cap or duplicate deck")
  passive_root.free()
  await frames(2)
 print("RESULT | Zone generation | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
