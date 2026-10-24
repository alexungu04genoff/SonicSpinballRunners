extends SceneTree
## Authored Normal room checks and actual 120 Hz input-timed recovery shots.
const RECIPES: Array[String] = ["target_garden", "bank_return", "crosscourt", "offset_crown", "winding_lane", "balcony"]
var checks := 0
var failures := 0
var report: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String, detail: String = "") -> void:
 checks += 1
 if condition:
  print("PASS | ", label, " | ", detail)
 else:
  failures += 1
  push_error("FAIL | " + label + " | " + detail)

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func run() -> void:
 var paddle_counts: Dictionary = {}
 var shape_signatures: Dictionary = {}
 for id: String in RECIPES:
  var recipe: GridChunkRecipe = load("res://data/grid_chunks/zone_normal_" + id + ".tres")
  var compiled := GridChunkCompiler.compile(recipe)
  check(compiled.valid, recipe.title + " preserves collider clearance", "; ".join(compiled.errors))
  if not compiled.valid:
   continue
  var data: ChunkData = compiled.chunk
  data.grid_position = Vector2i.ZERO
  paddle_counts[data.flipper_placements.size()] = true
  shape_signatures[var_to_str(data.rails)] = true
  check(data.zone_role in ["interaction", "approach"] and not data.shot_description.is_empty(), recipe.title + " declares its composition and shot purpose")
  for mirrored in [false, true]:
   data.mirrored = mirrored
   var passed := false
   var passage: Dictionary = {}
   for offset: float in [0.0, -100.0, 100.0]:
    passage = await upward_shot(data, offset)
    if passage.crossed:
     passed = true
     break
   check(passed, "%s %s admits a real upward shot" % [recipe.title, "mirrored" if mirrored else "authored"], str(passage))
   for paddle in data.flipper_placements.size():
    var witness: Dictionary = {}
    var found := false
    for fraction: float in [0.55, 0.75, 0.9]:
     for incoming_x: float in [0.0, -80.0, 80.0]:
      witness = await recovery_shot(data, paddle, fraction, incoming_x)
      if witness.success:
       found = true
       break
     if found:
      break
    check(found, "%s paddle %d %s catches a descent and completes its declared shot" % [recipe.title, paddle, "mirrored" if mirrored else "authored"], str(witness))
    report.append(witness)
 check(paddle_counts.has(0) and paddle_counts.has(1) and paddle_counts.has(2), "Normal library has deliberate zero, one and two-paddle rooms")
 check(shape_signatures.size() == RECIPES.size(), "All six authored room outlines differ before mirroring")
 var layout := ZoneGenerator.generate(28, 0, TableGenerator.Difficulty.NORMAL)
 check(layout.valid, "Normal seed 28 builds with authored Act composition", str(layout.get("errors", [])) + " / " + str(layout.get("rejected", [])))
 if layout.valid:
  for chunk_index in [1, 3, 4, 6, 7]:
   var shaped: ChunkData = layout.chunks[chunk_index].duplicate(true)
   shaped.grid_position = Vector2i.ZERO
   for paddle in shaped.flipper_placements.size():
    var witness: Dictionary = {}
    var found := false
    for fraction: float in [0.55, 0.75, 0.9]:
     for incoming_x: float in [0.0, -80.0, 80.0]:
      witness = await recovery_shot(shaped, paddle, fraction, incoming_x)
      if witness.success:
       found = true
       break
     if found:
      break
    witness["generated_seed"] = 28
    witness["chunk_index"] = chunk_index
    check(found, "%s generated paddle %d still reaches its target after connector shaping" % [shaped.title, paddle], str(witness))
    report.append(witness)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var output := FileAccess.open("res://test-results/normal-room-shots.json", FileAccess.WRITE)
 output.store_string(JSON.stringify(report, " "))
 output.close()
 print("RESULT | Normal rooms | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func fixture(data: ChunkData, start: Vector2, velocity: Vector2) -> Dictionary:
 var world := Node2D.new()
 root.add_child(world)
 var tuning := PhysicsTuning.new()
 world.add_child(tuning)
 var controls := PlaygroundInput.new()
 controls.virtual_enabled = true
 world.add_child(controls)
 var chunk := TableChunk.new()
 chunk.data = data
 world.add_child(chunk)
 chunk.build()
 var ball := PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 ball.position = start
 world.add_child(ball)
 ball.teleport_to(start, velocity)
 var paddles: Array[PlaygroundFlipper] = []
 for placement: Dictionary in data.world_flippers():
  var paddle := PlaygroundFlipper.new()
  paddle.position = placement.position
  paddle.side = placement.side
  paddle.length = placement.length
  paddle.ball = ball
  paddle.controls = controls
  paddle.tuning = tuning
  world.add_child(paddle)
  paddles.append(paddle)
 var rings := RingField.new()
 rings.ball = ball
 rings.tuning = tuning
 rings.previous_ball_position = start
 for position: Vector2 in data.rings:
  rings.add_ring(data.world_point(position))
 world.add_child(rings)
 return {"world": world, "ball": ball, "controls": controls, "paddles": paddles, "rings": rings}

func upward_shot(data: ChunkData, offset: float) -> Dictionary:
 var start := data.world_point(data.markers.entry) + Vector2(offset, 0)
 var exit := data.world_rect(data.top_connection)
 var sample := fixture(data, start, Vector2(0, -1450))
 var result := {"room": data.chunk_id, "mirrored": data.mirrored, "offset": offset, "crossed": false, "finite": true, "position": start}
 for tick in 180:
  await frames(1)
  result.position = sample.ball.position
  result.finite = result.finite and sample.ball.position.is_finite() and sample.ball.linear_velocity.is_finite()
  if sample.ball.position.y < exit.position.y - PlaygroundBall.RADIUS:
   result.crossed = result.finite and sample.ball.linear_velocity.y < 0.0 and sample.ball.position.x > exit.position.x + PlaygroundBall.RADIUS + ChunkData.RAIL_RADIUS and sample.ball.position.x < exit.end.x - PlaygroundBall.RADIUS - ChunkData.RAIL_RADIUS
   break
  if sample.ball.position.y > 710.0:
   break
 sample.world.free()
 await frames(2)
 return result

func recovery_shot(data: ChunkData, paddle_index: int, fraction: float, incoming_x: float) -> Dictionary:
 var placement: Dictionary = data.world_flippers()[paddle_index]
 var angle := 0.32 if placement.side > 0.0 else PI - 0.32
 var start: Vector2 = placement.position + Vector2.RIGHT.rotated(angle) * placement.length * fraction + Vector2(0, -110)
 var sample := fixture(data, start, Vector2(incoming_x, 180))
 var paddle: PlaygroundFlipper = sample.paddles[paddle_index]
 var target: Vector2 = placement.get("shot_target", Vector2.INF)
 var passage: bool = placement.get("shot_kind", "score") == "upper_passage"
 var opening := data.world_rect(data.top_connection)
 var result := {"room": data.chunk_id, "mirrored": data.mirrored, "paddle": paddle_index, "role": placement.role, "shot_kind": placement.get("shot_kind", "score"), "fraction": fraction, "incoming_x": incoming_x, "target": target, "pressed_tick": -1, "strikes": 0, "target_hit": false, "target_ring": false, "upper_passage": false, "finite": true, "minimum_target_distance": INF, "success": false}
 sample.ball.bumper_hit.connect(func(body: Node) -> void:
  if paddle.strikes > 0 and body.global_position.distance_to(target) < 1.0:
   result.target_hit = true)
 sample.rings.collected.connect(func(position: Vector2) -> void:
  if paddle.strikes > 0 and position.distance_to(target) < 1.0:
   result.target_ring = true)
 for tick in 420:
  var nearest := Geometry2D.get_closest_point_to_segment(sample.ball.position, paddle.position, paddle.tip())
  if result.pressed_tick < 0 and sample.ball.linear_velocity.y > 0.0 and sample.ball.position.y < paddle.position.y + 15.0 and nearest.distance_to(sample.ball.position) < 43.0:
   result.pressed_tick = tick
  var held: bool = result.pressed_tick >= 0 and tick - result.pressed_tick < 15
  sample.controls.virtual_left = held and paddle.side > 0.0
  sample.controls.virtual_right = held and paddle.side < 0.0
  await frames(1)
  result.strikes = paddle.strikes
  result.finite = result.finite and sample.ball.position.is_finite() and sample.ball.linear_velocity.is_finite()
  if paddle.strikes > 0:
   result.minimum_target_distance = minf(result.minimum_target_distance, sample.ball.position.distance_to(target))
  if result.finite and paddle.strikes == 1:
   result.upper_passage = sample.ball.position.y < opening.position.y - PlaygroundBall.RADIUS and sample.ball.linear_velocity.y < 0.0 and sample.ball.position.x > opening.position.x + PlaygroundBall.RADIUS + ChunkData.RAIL_RADIUS and sample.ball.position.x < opening.end.x - PlaygroundBall.RADIUS - ChunkData.RAIL_RADIUS
   result.success = result.upper_passage if passage else (result.target_hit or result.target_ring)
   if result.success:
    break
  if sample.ball.position.y > 720.0 or sample.ball.position.y < -25.0:
   break
 sample.world.free()
 await frames(2)
 return result
