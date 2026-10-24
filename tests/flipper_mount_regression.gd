extends "res://tests/zone_hard_rooms.gd"
## Authoritative housing checks and short real-physics pinch probes at 120 Hz.
## Each shot has one initial state; afterward only ordinary paddle input changes.
const MOUNT_CASES := [
 {"id": "zone_normal_target_garden", "seed": 28, "difficulty": TableGenerator.Difficulty.NORMAL, "count": 2},
]

func run() -> void:
 verify_invalid_mounts()
 for spec: Dictionary in MOUNT_CASES:
  var recipe: GridChunkRecipe = load("res://data/grid_chunks/%s.tres" % spec.id)
  var compiled := GridChunkCompiler.compile(recipe)
  check(compiled.valid, "%s mounted source compiles: %s" % [spec.id, compiled.errors])
  if not compiled.valid:
   continue
  var generated := ZoneGenerator.generate(spec.seed, 0, spec.difficulty)
  check(generated.valid, "%s final Zone generates: %s / %s" % [spec.id, generated.get("errors", []), generated.get("rejected", [])])
  if not generated.valid:
   continue
  var shaped: ChunkData
  for candidate: ChunkData in generated.chunks:
   if candidate.chunk_id == spec.id:
    shaped = candidate
    break
  check(shaped != null, "%s remains in its review seed" % spec.id)
  if shaped == null:
   continue
  for source: ChunkData in [compiled.chunk, shaped]:
   var is_shaped := source == shaped
   for mirrored: bool in [false, true]:
    var data: ChunkData = source.duplicate(true)
    data.grid_position = Vector2i.ZERO if is_shaped else Vector2i(2, 9)
    data.horizontal_shift_cells = 0 if is_shaped else 1
    data.mirrored = mirrored
    var label := "%s shaped=%s mirrored=%s" % [data.chunk_id, is_shaped, mirrored]
    verify_geometry(data, spec.count, label)
    if not is_shaped:
     continue
    await verify_passage(data, label)
    for mount: Dictionary in data.local_flipper_mounts():
     for approach: String in ["upper", "lower", "hinge", "held_hinge"]:
      var witness := await housing_shot(data, mount.flipper_index, approach)
      report.append(witness)
      print("MOUNT SHOT | ", witness)
      check(witness.start_clear and witness.finite and witness.escaped and not witness.pinched, "%s paddle%d %s approach escapes without a pinch" % [label, mount.flipper_index, approach])
      check(witness.housing_contacts > 0 or (approach.ends_with("hinge") and witness.strikes > 0), "%s paddle%d %s probe physically touches its assembly" % [label, mount.flipper_index, approach])
 var output := FileAccess.open("res://test-results/flipper-mount-shots.json", FileAccess.WRITE)
 if output != null:
  output.store_string(JSON.stringify(report, " "))
  output.close()
 print("RESULT | Flipper mounts | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func verify_invalid_mounts() -> void:
 var recipe: GridChunkRecipe = load("res://data/grid_chunks/zone_normal_target_garden.tres")
 var compiled := GridChunkCompiler.compile(recipe)
 if not compiled.valid:
  check(false, "Negative mount fixtures require the valid Target Garden baseline")
  return
 var source: ChunkData = compiled.chunk
 var invalid_kind: GridChunkRecipe = recipe.duplicate(true)
 for placement: Dictionary in invalid_kind.placements:
  if placement.piece.begins_with("mounted_"):
   placement.shot_kind = "free_points"
   break
 var invalid_result := GridChunkCompiler.compile(invalid_kind)
 check(not invalid_result.valid and " ".join(invalid_result.errors).contains("shot kind"), "Compiler rejects unknown authored shot outcomes")
 verify_connector_root(source)
 var missing_wall: ChunkData = source.duplicate(true)
 missing_wall.flipper_placements[0].position.y = 10.0
 expect_clearance_error(missing_wall, "Mounted flipper requires a complete side-wall attachment", "Pivot near a seam rejects an incomplete housing attachment")
 var wall_collision: ChunkData = source.duplicate(true)
 wall_collision.flipper_placements[0].position.x = 124.0
 expect_clearance_error(wall_collision, "Mounted flipper physically intersects its attachment wall", "The sealed hinge cannot hide a paddle capsule overlapping its wall")
 var tiny_seal: ChunkData = source.duplicate(true)
 tiny_seal.flipper_placements[0].position.x = 129.5
 expect_clearance_error(tiny_seal, "Flipper housing must connect to a nearby wall behind its pivot", "A bearing with only 0.5px wall overlap is rejected")
 var overlong: ChunkData = source.duplicate(true)
 overlong.flipper_placements[0].position.x = 300.0
 expect_clearance_error(overlong, "Flipper housing must connect to a nearby wall behind its pivot", "A housing cannot bridge from a distant wall")
 var buried_ring: ChunkData = source.duplicate(true)
 buried_ring.rings.append(buried_ring.flipper_placements[0].position)
 expect_clearance_error(buried_ring, "Route marker or ring lacks ball clearance", "A ring inside the filled housing is rejected")
 var buried_bumper: ChunkData = source.duplicate(true)
 buried_bumper.bumpers.append({"kind": "circle", "position": Vector2(125, 500), "radius": 24.0})
 expect_clearance_error(buried_bumper, "Flipper housing leaves insufficient ball passage beside a bumper", "Housing overlap with an unrelated bumper is rejected")
 var blade_bumper: ChunkData = source.duplicate(true)
 blade_bumper.bumpers.append({"kind": "circle", "position": Vector2(220, 500), "radius": 24.0})
 expect_clearance_error(blade_bumper, "Flipper swing leaves insufficient ball passage beside a bumper", "Mounted paddle keeps its full clearance from an unrelated bumper")
 var remote_ledge: ChunkData = source.duplicate(true)
 var rail := PackedVector2Array()
 for point: Vector2 in source.rails[0]:
  rail.append(point)
  if point.is_equal_approx(Vector2(100, 400)):
   rail.append_array(PackedVector2Array([Vector2(100, 430), Vector2(185, 440), Vector2(100, 450)]))
 remote_ledge.rails[0] = rail
 expect_clearance_error(remote_ledge, "Flipper swing leaves insufficient ball passage beside a rail", "A remote same-side ledge cannot use the sealed-root exception")

func verify_connector_root(source: ChunkData) -> void:
 for mirrored: bool in [false, true]:
  var data: ChunkData = source.duplicate(true)
  data.grid_position = Vector2i.ZERO
  data.mirrored = mirrored
  var legal_wall: Array = [data.world_polygon(PackedVector2Array([Vector2(100, 470), Vector2(100, 530)]))]
  var clipping_wall: Array = [data.world_polygon(PackedVector2Array([Vector2(101, 470), Vector2(101, 530)]))]
  check(ConnectorTransitions._flippers_clear(legal_wall, [data]), "Connector validation permits the sealed 25px root mirrored=%s" % mirrored)
  check(not ConnectorTransitions._flippers_clear(clipping_wall, [data]), "Connector validation rejects a 1px wall/capsule overlap mirrored=%s" % mirrored)

func expect_clearance_error(data: ChunkData, expected: String, label: String) -> void:
 var errors := PackedStringArray()
 GridChunkCompiler._check_clearance(data, errors)
 var rejected := false
 for error: String in errors:
  rejected = rejected or error.begins_with(expected)
 check(rejected, label + ": " + expected)

func verify_geometry(data: ChunkData, expected: int, label: String) -> void:
 var mounts := data.local_flipper_mounts()
 check(mounts.size() == expected, label + " has one solid housing per selected pivot")
 var world_descriptors := data.gameplay_descriptors()
 var world := TableChunk.new()
 world.data = data
 root.add_child(world)
 world.build()
 for mount: Dictionary in mounts:
  var paddle: Dictionary = data.flipper_placements[mount.flipper_index]
  var rail: PackedVector2Array = data.rails[0 if mount.wall_attachment == "left" else 1]
  var polygon := absolute_polygon(mount)
  var footprint := Rect2(polygon[0], Vector2.ZERO)
  for point: Vector2 in polygon:
   footprint = footprint.expand(point)
  check(footprint.size.x <= 50.0 and footprint.size.y <= 50.0, "%s paddle%d bearing stays within a compact 50px footprint" % [label, mount.flipper_index])
  var sealed := true
  for sample in 31:
   var y: float = mount.position.y - ChunkData.MOUNT_HALF_HEIGHT + sample * ChunkData.MOUNT_HALF_HEIGHT * 2.0 / 30.0
   var point := Vector2.INF
   for edge in range(rail.size() - 1):
    if rail[edge].y <= y and rail[edge + 1].y >= y and rail[edge + 1].y > rail[edge].y:
     point = rail[edge].lerp(rail[edge + 1], (y - rail[edge].y) / (rail[edge + 1].y - rail[edge].y))
     break
   sealed = sealed and point.is_finite() and polygon_distance(point, polygon) < 0.1
  check(sealed, "%s paddle%d seals the full named wall attachment" % [label, mount.flipper_index])
  var maximum_root := 0.0
  for step in 41:
   var angle := lerpf(0.32, -0.48, step / 40.0)
   var axis := Vector2(cos(angle) * paddle.side, sin(angle))
   for point: Vector2 in mount.points:
    maximum_root = maxf(maximum_root, point.dot(axis) + PlaygroundFlipper.RADIUS)
  check(maximum_root <= 34.0, "%s paddle%d compact bearing overlap remains within 34px root (%.2f)" % [label, mount.flipper_index, maximum_root])
  var transformed := false
  for item: Dictionary in world_descriptors:
   if item.kind != "flipper_mount" or item.flipper_index != mount.flipper_index:
    continue
   transformed = item.position.distance_to(data.world_flippers()[mount.flipper_index].position) < 0.01
   transformed = transformed and data.world_flippers()[mount.flipper_index].get("shot_kind", "score") == paddle.get("shot_kind", "score")
   var attachment: String = mount.wall_attachment
   if data.mirrored:
    attachment = "right" if attachment == "left" else "left"
   transformed = transformed and item.wall_attachment == attachment
   for index in mount.rear_anchors.size():
    transformed = transformed and data.world_point(mount.rear_anchors[index]).distance_to(item.rear_anchors[index]) < 0.01
   for index in polygon.size():
    transformed = transformed and data.world_point(polygon[index]).distance_to(item.position + item.points[index]) < 0.01
  check(transformed, "%s paddle%d physics hull and pivot transform together" % [label, mount.flipper_index])
  check(not TableGenerator.point_clear(data.world_point(mount.position), world_descriptors, 0.0), "%s paddle%d housing interior is solid to route validation" % [label, mount.flipper_index])
 var passive := true
 var runtime_count := 0
 for descriptor: Dictionary in world.descriptors:
  if descriptor.kind != "flipper_mount":
   continue
  runtime_count += 1
  var body: StaticBody2D = descriptor.body
  passive = passive and not body.has_meta("bumper") and body.physics_material_override == world.wall_material
  passive = passive and body.collision_layer == 1 and body.collision_mask == 2
  passive = passive and body.get_child_count() == 1 and body.get_child(0) is CollisionPolygon2D
  passive = passive and body.global_position.distance_to(descriptor.position) < 0.01
 check(passive and runtime_count == expected, label + " builds filled passive wall bodies without scoring or homing metadata")
 world.free()

func absolute_polygon(item: Dictionary) -> PackedVector2Array:
 var polygon := PackedVector2Array()
 for point: Vector2 in item.points:
  polygon.append(item.position + point)
 return polygon

func polygon_distance(point: Vector2, polygon: PackedVector2Array) -> float:
 if Geometry2D.is_point_in_polygon(point, polygon):
  return 0.0
 var result := INF
 for edge in polygon.size():
  result = minf(result, point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[edge], polygon[(edge + 1) % polygon.size()])))
 return result

func verify_passage(data: ChunkData, label: String) -> void:
 var passed := false
 var position := Vector2.ZERO
 var opening := data.world_rect(data.top_connection)
 for offset: float in [0.0, -100.0, 100.0, -75.0, 75.0]:
  var start := data.world_point(data.markers.entry) + Vector2(offset, 0)
  if not TableGenerator.point_clear(start, data.gameplay_descriptors(), 20.0):
   continue
  var sample := fixture(data, start, Vector2(0, -1450))
  for tick in 240:
   await frames(1)
   position = sample.ball.position
   if position.y < -25.0:
    passed = position.x > opening.position.x + PlaygroundBall.RADIUS and position.x < opening.end.x - PlaygroundBall.RADIUS
    break
   if position.y > 730.0 or not position.is_finite():
    break
  sample.world.free()
  await frames(2)
  if passed:
   break
 check(passed, "%s preserves a real full upward passage: %s" % [label, position])

func housing_shot(data: ChunkData, paddle_index: int, approach: String) -> Dictionary:
 var placement: Dictionary = data.world_flippers()[paddle_index]
 var start: Vector2 = placement.position + Vector2(10.0 * placement.side, -110.0)
 var velocity := Vector2.ZERO
 if approach == "lower":
  start = placement.position + Vector2(8.0 * placement.side, 105.0)
  velocity = Vector2(0.0, -700.0)
 elif approach.ends_with("hinge"):
  start = placement.position + Vector2(35.0 * placement.side, -85.0)
 var clear := Geometry2D.is_point_in_polygon(start, data.world_polygon(data.playfield_outline)) and TableGenerator.point_clear(start, data.gameplay_descriptors(), 20.0)
 var result := {"room": data.chunk_id, "mirrored": data.mirrored, "paddle": paddle_index, "approach": approach, "start": start, "velocity": velocity, "start_clear": clear, "finite": true, "escaped": false, "pinched": false, "housing_contacts": 0, "strikes": 0, "last": start, "ticks": 0}
 if not clear:
  return result
 var sample := fixture(data, start, velocity)
 var paddle: PlaygroundFlipper = sample.paddles[paddle_index]
 sample.ball.body_entered.connect(func(body: Node) -> void:
  if body.name.begins_with("FlipperHousing"):
   result.housing_contacts += 1)
 var pressed_tick := -1
 var stationary_ticks := 0
 for tick in 720:
  var nearest := Geometry2D.get_closest_point_to_segment(sample.ball.position, paddle.position, paddle.tip())
  if approach.ends_with("hinge") and pressed_tick < 0 and sample.ball.linear_velocity.y > 0.0 and sample.ball.position.y < paddle.position.y + 15.0 and nearest.distance_to(sample.ball.position) < 43.0:
   pressed_tick = tick
  var hold_ticks := 120 if approach == "held_hinge" else 15
  var held := pressed_tick >= 0 and tick - pressed_tick < hold_ticks
  sample.controls.virtual_left = held and paddle.side > 0
  sample.controls.virtual_right = held and paddle.side < 0
  await frames(1)
  result.ticks = tick + 1
  result.last = sample.ball.position
  result.strikes = paddle.strikes
  result.finite = result.finite and sample.ball.position.is_finite() and sample.ball.linear_velocity.is_finite()
  stationary_ticks = stationary_ticks + 1 if not held and sample.ball.linear_velocity.length() < 5.0 else 0
  if stationary_ticks >= 120:
   result.pinched = true
   break
  if sample.ball.position.y > 730.0 or sample.ball.position.y < -30.0:
   result.escaped = true
   break
  if not result.finite:
   break
 sample.world.free()
 await frames(2)
 return result
