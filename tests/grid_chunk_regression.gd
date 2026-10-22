extends "res://tests/flipper_recovery_regression.gd"
## Resource compilation and real 120 Hz traversal probes for the optional grid kit.
## Each physics sample starts a fresh ball and then uses only ordinary input.
const COMPILER = preload("res://scripts/grid_chunk_compiler.gd")
const RECIPES := [preload("res://data/grid_chunks/flow_relay.tres"), preload("res://data/grid_chunks/flow_relay_variant.tres")]
const V6_GEOMETRY := {
 "0/1": "1f090310adc1e99bb277b22818db584755eafd221798fc175da037c9b7dea344",
 "0/8": "1f090310adc1e99bb277b22818db584755eafd221798fc175da037c9b7dea344",
 "0/18": "1f090310adc1e99bb277b22818db584755eafd221798fc175da037c9b7dea344",
 "0/23": "08c2ae9fcaa370b0498c7b4fbeed021cddbcfc59e0addec24b84a96729010580",
 "1/1": "cbdeb0b3342ad32035e0fd7bf28a329726eecc4ae158e7301e1c3c511c484492",
 "1/8": "e15a4f493441f11df4d2fed3bf106023d5608d84a9b7fb14f14828e7f6d512ba",
 "1/18": "faf0d9a5eb2bbdf12be43861af47652728d28f99c18d068d1309337d7a1de8f2",
 "1/23": "057e838cd778ed62601dc82ef767dfb9f65befeeb62133fdc503586c2250c7a4",
 "2/1": "cda3263b40932d8067cb0b48e95fdebee2cec052bcf8142341d5a6aedfd3c56c",
 "2/8": "c46af4ab67bce252107fc01aa394a3e98d30fd0f56de421613ddb8d712c05816",
 "2/18": "3a2aeb4d1187d6d4d6185c1593ac8c495c5271dc76541291c5caf08ddfc04800",
 "2/23": "8a4f3db26a072828ef661e0cf8f125ce678cb081c113afe0f1e63d3178aeaa17",
}
var grid_report: Dictionary = {"layouts": [], "passive_shots": [], "recoveries": []}
var passive_root: Node2D
var passive_tuning: PhysicsTuning
var passive_controls: PlaygroundInput
var passive_ball: PlaygroundBall

func geometry_hash(layout: Dictionary) -> String:
 var geometry: Array = []
 for chunk: ChunkData in layout.chunks:
  geometry.append(chunk.gameplay_descriptors())
  geometry.append(chunk.world_flippers())
 for junction: Dictionary in layout.junctions:
  geometry.append(junction.passage)
  geometry.append(junction.junction_rails)
 return var_to_str(geometry).sha256_text()

func compact_geometry(chunk: ChunkData) -> String:
 return var_to_str([chunk.gameplay_descriptors(), chunk.world_flippers(), chunk.playfield_outline, chunk.top_connection, chunk.bottom_connection])

func passive_fixture(chunks: Array[ChunkData], junctions: Array) -> void:
 passive_root = Node2D.new()
 root.add_child(passive_root)
 passive_tuning = PhysicsTuning.new()
 passive_root.add_child(passive_tuning)
 passive_tuning.effective.gravity_scale = 0.0
 passive_tuning.effective.rolling_acceleration = 0.0
 passive_tuning.effective.rolling_drag = 0.0
 passive_controls = PlaygroundInput.new()
 passive_controls.virtual_enabled = true
 passive_root.add_child(passive_controls)
 for i in chunks.size():
  var chunk := TableChunk.new()
  chunk.data = chunks[i]
  for junction: Dictionary in junctions:
   if junction.upper_index == i:
    chunk.junction_rails.append_array(junction.junction_rails)
  passive_root.add_child(chunk)
  chunk.build()

func passive_shot(where: Vector2, velocity: Vector2, count: int) -> Dictionary:
 if is_instance_valid(passive_ball):
  passive_ball.free()
 passive_ball = PlaygroundBall.new()
 passive_ball.tuning = passive_tuning
 passive_ball.controls = passive_controls
 passive_ball.position = where
 passive_root.add_child(passive_ball)
 passive_ball.teleport_to(where, velocity)
 var result := {"start": where, "initial_velocity": velocity, "peak_speed": velocity.length(), "finite": true, "off_grid": false}
 for tick in count:
  await frames(1)
  result.finite = result.finite and passive_ball.position.is_finite() and passive_ball.linear_velocity.is_finite()
  result.peak_speed = maxf(result.peak_speed, passive_ball.linear_velocity.length())
  result.off_grid = result.off_grid or absf(passive_ball.position.x / 50.0 - roundf(passive_ball.position.x / 50.0)) > 0.001
 result.position = passive_ball.position
 result.velocity = passive_ball.linear_velocity
 result.rebounds = passive_ball.sweep_rebounds
 result.bumper_hits = passive_ball.bumper_hit_count
 grid_report.passive_shots.append(result)
 return result

func rails_match_colliders(chunk: TableChunk) -> bool:
 var rails: Array[Dictionary] = []
 for item: Dictionary in chunk.descriptors:
  if item.kind == "rail":
   rails.append(item)
 var actual := 0
 for body: Node in chunk.get_children():
  if not body is StaticBody2D or body.has_meta("bumper"):
   continue
  actual += 1
  var shape_node: CollisionShape2D = body.get_child(0)
  var capsule: CapsuleShape2D = shape_node.shape
  var half: Vector2 = Vector2.DOWN.rotated(shape_node.global_rotation) * (capsule.height * 0.5 - capsule.radius)
  var a := shape_node.global_position - half
  var b := shape_node.global_position + half
  var matches := 0
  for rail: Dictionary in rails:
   if ((a.distance_to(rail.a) < 0.01 and b.distance_to(rail.b) < 0.01) or (a.distance_to(rail.b) < 0.01 and b.distance_to(rail.a) < 0.01)) and is_equal_approx(capsule.radius, rail.radius):
    matches += 1
  if matches != 1:
   return false
 return actual == rails.size()

func flippers_clear(chunk: ChunkData) -> bool:
 var static_geometry := chunk.gameplay_descriptors()
 # Match the compiler: a complete ball passage, both 6 px margins and the
 # 3 px arc-sampling margin must remain outside the paddle capsule.
 var reserve := PlaygroundFlipper.RADIUS + 2.0 * (PlaygroundBall.RADIUS + 6.0) + 3.0
 for placement: Dictionary in chunk.world_flippers():
  for angle_step in 21:
   var angle := lerpf(0.32, -0.48, angle_step / 20.0)
   if placement.side < 0:
    angle = PI - angle
   var steps := ceili(float(placement.length) / 5.0)
   for distance_step in range(steps + 1):
    var point: Vector2 = placement.position + Vector2.RIGHT.rotated(angle) * float(placement.length) * distance_step / steps
    if not TableGenerator.point_clear(point, static_geometry, reserve):
     return false
 return true

func run() -> void:
 var legacy_preserved := true
 for key: String in V6_GEOMETRY:
  var parts := key.split("/")
  legacy_preserved = legacy_preserved and geometry_hash(TableGenerator.generate(int(parts[1]), int(parts[0]))) == V6_GEOMETRY[key]
 check(legacy_preserved, "Default generation preserves v6 complete geometry and paddle placement for 12 sampled layouts")
 var compiled: Array[ChunkData] = []
 var source_snapshots: Array[String] = []
 var reproducible := true
 for recipe: Resource in RECIPES:
  source_snapshots.append(var_to_str(recipe.placements))
  var a: Dictionary = COMPILER.compile(recipe)
  var b: Dictionary = COMPILER.compile(recipe)
  check(a.valid and b.valid, "Grid recipe compiles: " + recipe.resource_path, str(a.errors))
  if not a.valid or not b.valid:
   print("RESULT | Grid construction | %d checks | %d failures" % [checks, failures])
   quit(1)
   return
  compiled.append(a.chunk)
  reproducible = reproducible and compact_geometry(a.chunk) == compact_geometry(b.chunk)
 check(reproducible and compact_geometry(compiled[0]) != compact_geometry(compiled[1]), "Compilation is deterministic and the edited recipe produces different physical geometry")
 await grid_static_checks(compiled, source_snapshots)
 await grid_runtime_checks(compiled)
 var output := FileAccess.open("res://test-results/grid-construction-report.json", FileAccess.WRITE)
 if output != null:
  output.store_string(JSON.stringify(grid_report, " "))
  output.close()
 print("RESULT | Grid construction | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func grid_static_checks(compiled: Array[ChunkData], source_snapshots: Array[String]) -> void:
 var anchors_match := true
 var transforms_match := true
 var seams_clean := true
 var swing_clear := true
 for index in compiled.size():
  var chunk := compiled[index]
  var recipe: Resource = RECIPES[index]
  for placement: Dictionary in recipe.placements:
   var definition := GridPieceKit.definition(placement.piece, placement.get("span", 1))
   var point := Vector2(placement.cell) * 50.0
   match definition.kind:
    "circle":
     anchors_match = anchors_match and chunk.bumpers.any(func(item: Dictionary) -> bool: return item.position == point and is_equal_approx(item.radius, definition.radius * 50.0))
    "ring":
     anchors_match = anchors_match and chunk.rings.has(point)
    "flipper":
     anchors_match = anchors_match and chunk.flipper_placements.any(func(item: Dictionary) -> bool: return item.position == point and is_equal_approx(item.length, definition.length * 50.0))
  var mirrored: ChunkData = chunk.duplicate(true)
  mirrored.mirrored = true
  mirrored.horizontal_shift_cells = 1
  mirrored.grid_position = Vector2i(0, 7)
  for point: Vector2 in [Vector2.ZERO, Vector2(123.25, 321.75), Vector2(650, 700)]:
   transforms_match = transforms_match and mirrored.world_point(point).is_equal_approx(Vector2(800 - point.x, 700 + point.y))
  for i in chunk.flipper_placements.size():
   transforms_match = transforms_match and mirrored.world_flippers()[i].side == -chunk.flipper_placements[i].side
  var edges: Dictionary = {}
  for rail: PackedVector2Array in chunk.rails:
   for i in range(rail.size() - 1):
    var a := rail[i]
    var b := rail[i + 1]
    var key := str(a) + "/" + str(b) if a < b else str(b) + "/" + str(a)
    seams_clean = seams_clean and not edges.has(key) and a.distance_to(b) > 0.01
    edges[key] = true
    if i + 2 < rail.size():
     var next := rail[i + 2] - b
     seams_clean = seams_clean and not (absf((b - a).cross(next)) < 0.001 and (b - a).dot(next) > 0.0)
  swing_clear = swing_clear and flippers_clear(chunk)
 var split_recipe: Resource = RECIPES[0].duplicate(true)
 split_recipe.placements.remove_at(0)
 for row: int in [2, 0, 1]:
  split_recipe.placements.append({"piece": "rail_v", "cell": Vector2i(1, row), "span": 1, "chain": "left"})
 var split: Dictionary = COMPILER.compile(split_recipe)
 seams_clean = seams_clean and split.valid and compact_geometry(split.chunk) == compact_geometry(compiled[0])
 var corner_recipe: Resource = RECIPES[0].duplicate(true)
 corner_recipe.placements.remove_at(0)
 corner_recipe.placements.append_array([
  {"piece": "rail_v", "cell": Vector2i(1, 0), "span": 1, "chain": "left"},
  {"piece": "corner_right", "cell": Vector2i(1, 1), "span": 1, "chain": "left"},
  {"piece": "slope_left", "cell": Vector2i(2, 2), "span": 1, "chain": "left"},
 ])
 var corner: Dictionary = COMPILER.compile(corner_recipe)
 seams_clean = seams_clean and corner.valid
 check(anchors_match and transforms_match, "50 px anchors convert centrally; fractional coordinates, horizontal mirror and 100 px shifts remain exact")
 check(seams_clean, "Split/reordered collinear pieces compile identically without duplicate seams, while intentional corners remain valid")
 check(swing_clear, "Both recipes reserve ball-radius clearance around the complete sampled paddle swing")
 var malformed_rejected := true
 var malformed_details: Array = []
 for change in ["duplicate", "gap", "rotation", "unknown", "blocked_bumper", "blocked_flipper", "fractional_span", "zero_span", "negative_span", "fixed_piece_span"]:
  var bad: Resource = RECIPES[0].duplicate(true)
  match change:
   "duplicate": bad.placements.append(bad.placements[0].duplicate(true))
   "gap": bad.placements[0].cell += Vector2i(1, 0)
   "rotation": bad.placements[0]["rotation"] = 90
   "unknown":
    bad.placements[0].piece = "unsupported_piece"
    bad.placements[0].erase("span")
   "blocked_bumper": bad.placements.append({"piece": "bumper", "cell": Vector2i(1, 1)})
   "blocked_flipper": bad.placements.append({"piece": "flipper_left", "cell": Vector2i(2, 9)})
   "fractional_span": bad.placements[0].span = 2.5
   "zero_span": bad.placements[0].span = 0
   "negative_span": bad.placements[0].span = -2
   "fixed_piece_span": bad.placements[1]["span"] = 2
  var result: Dictionary = COMPILER.compile(bad)
  malformed_rejected = malformed_rejected and not result.valid and not result.errors.is_empty()
  malformed_details.append({"case": change, "valid": result.valid, "first_error": "" if result.errors.is_empty() else result.errors[0]})
 check(malformed_rejected, "Malformed rails, rotations, unsupported pieces and blocked dynamic envelopes fail authoring validation", str(malformed_details))
 var generation_valid := true
 var sources_unchanged := true
 for index in compiled.size():
  var middle_library: Array[ChunkData] = [compiled[index]]
  for preference in 3:
   for seed_value: int in [1, 8, 18, 23]:
    var first := TableGenerator.generate(seed_value, preference, TableGenerator.CATALOGUE, middle_library)
    var repeated := TableGenerator.generate(seed_value, preference, TableGenerator.CATALOGUE, middle_library)
    generation_valid = generation_valid and first.valid and repeated.valid and first.signature == repeated.signature and geometry_hash(first) == geometry_hash(repeated) and first.chunks[1].chunk_id == compiled[index].chunk_id and TableGenerator.validate_course(first.chunks).valid and flippers_clear(first.chunks[1])
    if not first.preference_available:
     generation_valid = generation_valid and first.selection_note.begins_with("No valid ")
    grid_report.layouts.append({"signature": first.signature, "tier_available": first.preference_available, "selection_note": first.selection_note})
  sources_unchanged = sources_unchanged and var_to_str(RECIPES[index].placements) == source_snapshots[index]
 check(generation_valid and sources_unchanged, "Both recipes reproduce seeds 1/8/18/23 in every preference with valid routes and paddle sweeps, preserving source placements")

func create_grid_game(mode: int) -> void:
 game = load("res://scenes/playground.tscn").instantiate()
 game.generation_seed = 8
 game.generation_difficulty = TableGenerator.Difficulty.NORMAL
 game.generation_grid_mode = mode
 root.add_child(game)
 await frames(4)
 game.controls.virtual_enabled = true
 game.presentation.set_process(false)
 game.ring_field.set_physics_process(false)

func grid_runtime_checks(compiled: Array[ChunkData]) -> void:
 for index in compiled.size():
  await create_grid_game(index + 1)
  var middle: ChunkData = game.layout.chunks[1]
  game.presentation._process(0.0)
  var aligned: bool = game.presentation.find_children("*", "CollisionObject3D", true, false).is_empty() and game.find_children("*", "TileMapLayer", true, false).is_empty()
  for chunk: TableChunk in game.chunks:
   aligned = aligned and rails_match_colliders(chunk)
  for i in game.flippers.size():
   var visual_tip: Vector3 = game.presentation.flipper_visuals[i].to_global(Vector3(game.flippers[i].length * TablePresentation.SCALE, 0, 0))
   aligned = aligned and TablePresentation.unmap_point(visual_tip).distance_to(game.flippers[i].tip()) < 0.01
  aligned = aligned and game.presentation.ball_visual.position.distance_to(TablePresentation.map_point(game.ball.position, TablePresentation.BALL_HEIGHT)) < 0.001
  check(aligned and middle.chunk_id == compiled[index].chunk_id, "Grid runtime uses one collider per descriptor, aligned collisionless visuals and no duplicate TileMap collision: " + middle.chunk_id)
  var passages_work := true
  for mode: String in ["rest", "held", "moving"]:
   var sample := await upward_sample(mode, 0.0)
   passages_work = passages_work and sample.crossed and sample.finite
  check(passages_work, "Real upward shots pass resting, raised and moving grid recovery paddles: " + middle.chunk_id)
  var recovered := false
  var witness: Dictionary = {}
  for paddle in [2, 3]:
   for fraction: float in [0.5, 0.7, 0.9]:
    for incoming_x: float in [-150.0, 0.0, 150.0]:
     var recovery := await recovery_sample(paddle, fraction, incoming_x)
     if recovery.strikes == 1 and recovery.chamber and recovery.finite:
      recovered = true
      witness = recovery
      break
    if recovered:
     break
   if recovered:
    break
  grid_report.recoveries.append(witness)
  check(recovered, "A genuine timed descending grid-flipper recovery reaches the upper chamber: " + middle.chunk_id, str(witness))
  var drop := await drop_sample(400.0, 0, true)
  check(drop.drained and drop.respawned and drop.relaunched and drop.strikes == 0, "A missed bottom shot still drains and automatically relaunches with the grid middle: " + middle.chunk_id)
  var layout: Dictionary = game.layout
  await remove_game()
  passive_fixture(layout.chunks, layout.junctions)
  var crossed := true
  for junction: Dictionary in layout.junctions:
   var center: Vector2 = junction.passage.get_center()
   for direction: float in [-1, 1]:
    var sample := await passive_shot(center - Vector2(0, direction * 40), Vector2(0, direction * 1200), 10)
    crossed = crossed and sample.finite and (sample.position.y - center.y) * direction > 25 and absf(sample.velocity.y - direction * 1200) < 3.0
  check(crossed, "Actual 28 px ball crosses both grid junctions upward and downward without a seam collision")
  var bank_clear := true
  var probes := 0
  for rail: PackedVector2Array in middle.rails:
   for i in range(1, rail.size() - 1):
    var joint: Vector2 = middle.world_point(rail[i])
    if joint.y < 920 or joint.y > 1200:
     continue
    var side: float = 1 if joint.x < middle.world_point(Vector2(350, 350)).x else -1
    var where := joint + Vector2(side * 75, 0)
    if not TableGenerator.point_clear(where, middle.gameplay_descriptors(), PlaygroundBall.RADIUS):
     continue
    var shot := await passive_shot(where, Vector2(-side * 8000, -1000), 7)
    bank_clear = bank_clear and shot.finite and shot.rebounds > 0 and Geometry2D.is_point_in_polygon(shot.position, middle.world_polygon(middle.playfield_outline)) and shot.peak_speed <= Vector2(8000, 1000).length() + 0.1
    probes += 1
  var free_start := middle.world_point(Vector2(350.25, 450.75))
  var free_shot := await passive_shot(free_start, Vector2(123.4, -55.5), 5)
  check(probes > 0 and bank_clear and free_shot.off_grid and free_shot.velocity.distance_to(Vector2(123.4, -55.5)) < 0.1, "Fast bank-joint contacts remain contained and passive; free movement remains continuous off the construction grid", "probes=%d" % probes)
  passive_root.free()
 await grid_regeneration_check()

func grid_regeneration_check() -> void:
 await create_grid_game(1)
 paused = true
 game.tuning.select_profile(1)
 game.tuning.modifier_enabled = true
 game.tuning.set_value("steering_acceleration", 2400.0)
 game.presentation.set_camera_preset(TablePresentation.CameraPreset.DRAMATIC_PINBALL)
 game.presentation.set_camera_value("look_ahead", 135.0)
 game.presentation.physics_overlay.visible = true
 game.presentation.construction_grid_overlay.visible = true
 var values: Dictionary = game.tuning.effective.duplicate()
 var camera_settings: Dictionary = game.presentation.camera_settings.duplicate()
 var bottom_ids: Array = [game.flippers[0].get_instance_id(), game.flippers[1].get_instance_id()]
 var intact := true
 for mode: int in [2, 0, 1]:
  var old_middle: TableChunk = game.chunks[1]
  var old_ring: MeshInstance3D = game.presentation.ring_visuals[0]
  intact = game.request_generation(8, TableGenerator.Difficulty.NORMAL, mode) and intact
  for tick in 3:
   await process_frame
  intact = intact and paused and game.generation_grid_mode == mode and game.tuning.effective == values and game.presentation.camera_preset == TablePresentation.CameraPreset.DRAMATIC_PINBALL and game.presentation.camera_settings == camera_settings and game.presentation.camera_follow_enabled and game.presentation.physics_overlay.visible and game.presentation.construction_grid_overlay.visible and not is_instance_valid(old_middle) and not is_instance_valid(old_ring) and game.ring_field.pickup_claimed.get_connections().size() == 1 and game.flippers.size() == 4 and game.ball.serve_pending and game.flippers[0].get_instance_id() == bottom_ids[0] and game.flippers[1].get_instance_id() == bottom_ids[1]
  if mode == 0:
   intact = intact and geometry_hash(game.layout) == V6_GEOMETRY["1/8"]
  else:
   intact = intact and game.chunks[1].data.chunk_id == RECIPES[mode - 1].recipe_id
 check(intact, "Grid base, variant and legacy regeneration preserve tuning, camera, overlays, pause and bottom paddles without stale visuals/listeners")
 var prior_signature: String = game.layout.signature
 var prior_middle_id: int = game.chunks[1].get_instance_id()
 var prior_presentation_id: int = game.presentation.get_instance_id()
 # Exercise the transactional failure path without changing any resource on disk.
 # This deliberate invalid request emits the expected Godot error below.
 var shared_recipe: Resource = game.GRID_RECIPES[0]
 shared_recipe.placements.append({"piece": "unsupported_piece", "cell": Vector2i(7, 7)})
 print("EXPECTED INVALID RECIPE | Next diagnostic verifies active-table preservation")
 game._regenerate(8, TableGenerator.Difficulty.NORMAL, 1)
 shared_recipe.placements.pop_back()
 check(game.layout.signature == prior_signature and game.chunks[1].get_instance_id() == prior_middle_id and game.presentation.get_instance_id() == prior_presentation_id and game.generation_grid_mode == 1 and not game.generation_pending and game.status_message == "Generation failed; current table preserved.", "Invalid grid recipe leaves the complete active table intact")
 paused = false
 await remove_game()
