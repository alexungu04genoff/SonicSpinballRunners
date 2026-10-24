extends SceneTree
## Real 120 Hz room fixtures: each descending ball is initialized once, then
## only flipper input changes. These are reproducible shot witnesses, not a bot run.
const RECIPES: Array[String] = ["target_cove", "bank_vault", "split_orbit", "offset_climb", "needle_gate", "switchback"]
var checks := 0
var failures := 0
var report: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error(message)
 else:
  print("PASS | ", message)

func frames(count: int) -> void:
 for tick in count:
  await physics_frame
  await process_frame

func run() -> void:
 var paddle_counts: Dictionary = {}
 var outlines: Dictionary = {}
 for name: String in RECIPES:
  var recipe: GridChunkRecipe = load("res://data/grid_chunks/zone_hard_" + name + ".tres")
  var compiled := GridChunkCompiler.compile(recipe)
  check(compiled.valid, "%s compile: %s" % [name, "; ".join(compiled.errors)])
  if not compiled.valid:
   continue
  var chunk: ChunkData = compiled.chunk
  chunk.grid_position = Vector2i.ZERO
  paddle_counts[chunk.flipper_placements.size()] = true
  outlines[var_to_str(chunk.rails)] = true
  for mirrored: bool in [false, true]:
   chunk.mirrored = mirrored
   var passage: Dictionary = {}
   for offset: float in [0.0, -100.0, 100.0, -75.0, 75.0]:
    passage = await upward_shot(chunk, offset)
    if passage.crossed:
     break
   print("HARD ROOM PASSAGE | ", name, " | ", passage)
   check(passage.crossed, "%s mirrored=%s admits a real upward shot" % [name, mirrored])
   for paddle_index in chunk.flipper_placements.size():
    var witness := await find_recovery(chunk, paddle_index)
    print("HARD ROOM RECOVERY | ", name, " | mirrored=", mirrored, " | ", witness)
    check(witness.success, "%s paddle %d mirrored=%s catches a descending ball and scores its authored target" % [name, paddle_index, mirrored])
    report.append(witness)
 check(paddle_counts.has(0) and paddle_counts.has(1), "Hard rooms use optional single catches or leave recovery to the neighboring Act deck")
 check(outlines.size() == RECIPES.size(), "All six Hard outlines differ before mirroring")
 var layout := ZoneGenerator.generate(24, 0, TableGenerator.Difficulty.HARD)
 check(layout.valid, "Hard seed 24 generates for final shaped-room recovery checks: %s / %s" % [layout.get("errors", []), layout.get("rejected", [])])
 if layout.valid:
  for chunk: ChunkData in layout.chunks:
   if not chunk.chunk_id.begins_with("zone_hard_"):
    continue
   for paddle_index in chunk.flipper_placements.size():
    var witness := await find_recovery(chunk, paddle_index)
    print("SHAPED HARD RECOVERY | ", chunk.chunk_id, " | ", witness)
    check(witness.success, "Final shaped seed24 %s paddle%d still reaches its authored scoring target" % [chunk.chunk_id, paddle_index])
    report.append(witness)
 var output := FileAccess.open("res://test-results/hard-room-shots.json", FileAccess.WRITE)
 if output != null:
  output.store_string(JSON.stringify(report, " "))
  output.close()
 print("RESULT | Hard rooms | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func find_recovery(chunk: ChunkData, paddle_index: int) -> Dictionary:
 var last: Dictionary = {}
 var attempts := 0
 for fraction: float in [0.7, 0.5, 0.9]:
  for incoming_x: float in [0.0, -100.0, 100.0]:
   last = await recovery(chunk, paddle_index, fraction, incoming_x)
   attempts += 1
   last.attempts = attempts
   if last.success:
    return last
 return last

func fixture(data: ChunkData, start: Vector2, velocity: Vector2) -> Dictionary:
 var fixture := Node2D.new()
 root.add_child(fixture)
 var tuning := PhysicsTuning.new()
 fixture.add_child(tuning)
 var controls := PlaygroundInput.new()
 controls.virtual_enabled = true
 fixture.add_child(controls)
 var chunk := TableChunk.new()
 chunk.data = data.duplicate(true)
 chunk.data.grid_position = Vector2i.ZERO
 fixture.add_child(chunk)
 chunk.build()
 var ball := PlaygroundBall.new()
 ball.position = start
 ball.tuning = tuning
 ball.controls = controls
 fixture.add_child(ball)
 ball.teleport_to(start, velocity)
 var paddles: Array[PlaygroundFlipper] = []
 for placement: Dictionary in chunk.data.world_flippers():
  var paddle := PlaygroundFlipper.new()
  paddle.position = placement.position
  paddle.side = placement.side
  paddle.length = placement.length
  paddle.ball = ball
  paddle.controls = controls
  paddle.tuning = tuning
  fixture.add_child(paddle)
  paddles.append(paddle)
 var rings := RingField.new()
 rings.ball = ball
 rings.tuning = tuning
 rings.previous_ball_position = start
 for position: Vector2 in chunk.data.rings:
  rings.add_ring(chunk.data.world_point(position))
 fixture.add_child(rings)
 return {"world": fixture, "ball": ball, "controls": controls, "paddles": paddles, "rings": rings}

func upward_shot(data: ChunkData, offset: float) -> Dictionary:
 var local: ChunkData = data.duplicate(true)
 local.grid_position = Vector2i.ZERO
 var start := local.world_point(local.markers.entry) + Vector2(offset, 0)
 var sample := fixture(local, start, Vector2(0, -1450))
 var result := {"mirrored": data.mirrored, "offset": offset, "crossed": false, "position": start}
 for tick in 180:
  await frames(1)
  result.position = sample.ball.position
  if sample.ball.position.y < 25.0:
   result.crossed = true
   break
  if sample.ball.position.y > 710.0:
   break
 sample.world.free()
 await frames(2)
 return result

func recovery(data: ChunkData, paddle_index: int, fraction: float, incoming_x: float) -> Dictionary:
 var local: ChunkData = data.duplicate(true)
 local.grid_position = Vector2i.ZERO
 var selected_placement: Dictionary = local.world_flippers()[paddle_index]
 var rest_angle := 0.32 if selected_placement.side > 0 else PI - 0.32
 var start: Vector2 = selected_placement.position + Vector2.RIGHT.rotated(rest_angle) * selected_placement.length * fraction + Vector2(0, -100)
 var sample := fixture(local, start, Vector2(incoming_x, 180))
 var paddles: Array[PlaygroundFlipper] = sample.paddles
 var ball: PlaygroundBall = sample.ball
 var controls: PlaygroundInput = sample.controls
 var selected: PlaygroundFlipper = paddles[paddle_index]
 var target: Vector2 = selected_placement.shot_target
 var pressed_tick := -1
 var result := {"room": data.chunk_id, "mirrored": data.mirrored, "paddle": paddle_index, "success": false, "fraction": fraction, "incoming_x": incoming_x, "strikes": 0, "target": target, "target_hit": false, "target_ring": false, "nearest_target": INF, "minimum_y": start.y, "finite": true}
 ball.bumper_hit.connect(func(body: Node) -> void:
  if selected.strikes > 0 and body.global_position.distance_to(target) < 1.0:
   result.target_hit = true)
 sample.rings.collected.connect(func(position: Vector2) -> void:
  if selected.strikes > 0 and position.distance_to(target) < 1.0:
   result.target_ring = true)
 for tick in 600:
  var nearest := Geometry2D.get_closest_point_to_segment(ball.position, selected.position, selected.tip())
  if pressed_tick < 0 and ball.linear_velocity.y > 0 and ball.position.y < selected.position.y + 15 and nearest.distance_to(ball.position) < 43:
   pressed_tick = tick
  var pressed := pressed_tick >= 0 and tick - pressed_tick < 15
  controls.virtual_left = pressed and selected.side > 0
  controls.virtual_right = pressed and selected.side < 0
  await frames(1)
  result.strikes = selected.strikes
  result.minimum_y = minf(result.minimum_y, ball.position.y)
  result.finite = result.finite and ball.position.is_finite() and ball.linear_velocity.is_finite()
  if selected.strikes > 0:
   result.nearest_target = minf(result.nearest_target, ball.position.distance_to(target))
   if result.target_hit or result.target_ring:
    result.success = result.finite
    break
  if ball.position.y > 750.0 or ball.position.y < -30.0 or not result.finite:
   break
 sample.world.free()
 await frames(2)
 return result
