extends "res://tests/zone_normal_rooms.gd"
## Natural upstream gravity feeds. Each sample starts at rest at least 300px above
## its paddle, then uses only flipper input; no steering or body corrections.

func run() -> void:
 if OS.get_cmdline_user_args().has("--audit"):
  await audit()
  return
 var layout := ZoneGenerator.generate(28, 0, TableGenerator.Difficulty.NORMAL)
 check(layout.valid, "Normal 28 provides the actual shaped feed geometry")
 if not layout.valid:
  quit(1)
  return
 # Source-local upstream positions chosen from the gravity-feed investigation.
 # Each remains at least 300px above its paddle, outside every collider.
 var starts := {
  "zone_normal_bank_return": [Vector2(222, 300)],
  "zone_normal_balcony": [Vector2(538, 200)],
  "zone_normal_crosscourt": [Vector2(112, 200), Vector2(688, 300)],
  "zone_normal_offset_crown": [Vector2(222, 200)],
  "zone_normal_target_garden": [Vector2(112, 200), Vector2(688, 200)],
 }
 var feeds: Array[Dictionary] = []
 for chunk_index in [1, 3, 4, 6, 7]:
  var data: ChunkData = layout.chunks[chunk_index].duplicate(true)
  data.grid_position = Vector2i.ZERO
  for mirrored in [false, true]:
   data.mirrored = mirrored
   var passage: Dictionary = {}
   for offset: float in [0.0, -100.0, 100.0]:
    passage = await upward_shot(data, offset)
    if passage.crossed:
     break
   check(passage.crossed, "%s mirrored=%s retains an upward passage past resting paddles" % [data.chunk_id, mirrored], str(passage))
   for paddle_index in data.world_flippers().size():
    var start := data.world_point(starts[data.chunk_id][paddle_index])
    var placement: Dictionary = data.world_flippers()[paddle_index]
    check(inside_clear(data, start) and placement.position.y - start.y >= 300.0, "%s paddle%d starts clear and well upstream" % [data.chunk_id, paddle_index])
    var timed := await feed_shot(data, paddle_index, start, 43.0)
    # Balcony's precision return deliberately aims through the upper opening;
    # the other fixtures require their authored bumper/ring scoring target.
    var reached: bool = timed.exit if data.chunk_id == "zone_normal_balcony" else timed.useful
    var destination := "upper opening" if data.chunk_id == "zone_normal_balcony" else "declared scoring target"
    check(timed.strikes == 1 and reached and timed.finite, "%s paddle%d mirrored=%s turns a natural descent into its %s" % [data.chunk_id, paddle_index, mirrored, destination], str(timed))
    var missed := await feed_shot(data, paddle_index, start, 43.0, false)
    check(missed.strikes == 0 and missed.missed and not missed.resting and missed.finite, "%s paddle%d mirrored=%s lets a missed shot fall to the recovery section below" % [data.chunk_id, paddle_index, mirrored], str(missed))
    if data.chunk_id == "zone_normal_target_garden":
     check(absf(timed.incoming_velocity.x) > 250.0 and timed.wall_contacts > 0, "Garden shoulder physically feeds the catch before its powered strike", str(timed))
     var early := await feed_shot(data, paddle_index, start, 130.0, true, 4)
     check(early.strikes == 0 and early.missed and not early.resting, "An early tap expires before the Garden return arrives and the ball falls below", str(early))
     timed["early_tap"] = early
    feeds.append({"room": data.chunk_id, "paddle": paddle_index, "mirrored": mirrored, "timed": timed, "missed": missed})
 var output := FileAccess.open("res://test-results/normal-flipper-feeds.json", FileAccess.WRITE)
 output.store_string(JSON.stringify(feeds, " "))
 output.close()
 print("RESULT | Normal natural flipper feeds | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func audit() -> void:
 var layout := ZoneGenerator.generate(28, 0, TableGenerator.Difficulty.NORMAL)
 check(layout.valid, "Normal 28 provides the actual shaped feed geometry")
 if not layout.valid:
  quit(1)
  return
 var feeds: Array[Dictionary] = []
 for chunk_index in [1, 3, 4, 6, 7]:
  var data: ChunkData = layout.chunks[chunk_index].duplicate(true)
  data.grid_position = Vector2i.ZERO
  for paddle_index in data.world_flippers().size():
   var placement: Dictionary = data.world_flippers()[paddle_index]
   var start_y: float = placement.position.y - 300.0
   var wall := boundary_x(data, start_y, placement.side > 0.0)
   var samples: Array[Dictionary] = []
   for inset: float in [32.0, 62.0, 92.0, 122.0, 152.0, 182.0]:
    var start := Vector2(wall + placement.side * inset, start_y)
    if not inside_clear(data, start):
     continue
    var sample := await feed_shot(data, paddle_index, start, 43.0)
    sample["inset"] = inset
    samples.append(sample)
   print("FEED AUDIT | ", data.chunk_id, " paddle=", paddle_index, " | ", JSON.stringify(samples))
   feeds.append({"room": data.chunk_id, "paddle": paddle_index, "samples": samples})
 var suffix := "current"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--tag="):
   suffix = argument.trim_prefix("--tag=")
 var output := FileAccess.open("res://test-results/normal-flipper-feeds-" + suffix + ".json", FileAccess.WRITE)
 output.store_string(JSON.stringify(feeds, " "))
 output.close()
 quit(0)

func boundary_x(data: ChunkData, y: float, left: bool) -> float:
 var intersections: Array[float] = []
 for rail: PackedVector2Array in data.rails:
  var points := data.world_polygon(rail)
  for i in range(points.size() - 1):
   var a := points[i]
   var b := points[i + 1]
   if y >= minf(a.y, b.y) and y <= maxf(a.y, b.y) and not is_equal_approx(a.y, b.y):
    intersections.append(lerpf(a.x, b.x, (y - a.y) / (b.y - a.y)))
 return intersections.min() if left else intersections.max()

func inside_clear(data: ChunkData, at: Vector2) -> bool:
 return Geometry2D.is_point_in_polygon(at, data.world_polygon(data.playfield_outline)) and TableGenerator.point_clear(at, data.gameplay_descriptors(), PlaygroundBall.RADIUS + 6.0)

func feed_shot(data: ChunkData, paddle_index: int, start: Vector2, trigger: float, press: bool = true, hold_ticks: int = 15) -> Dictionary:
 var placement: Dictionary = data.world_flippers()[paddle_index]
 var sample := fixture(data, start, Vector2.ZERO)
 var paddle: PlaygroundFlipper = sample.paddles[paddle_index]
 var target: Vector2 = placement.shot_target
 var result := {"start": start, "trigger": trigger, "pressed_tick": -1, "strikes": 0, "target_hit": false, "target_ring": false, "useful": false, "useful_tick": -1, "exit": false, "exit_position": Vector2.INF, "missed": false, "resting": false, "finite": true, "wall_contacts": 0, "minimum_y_after_strike": INF, "closest_paddle": INF, "strike_position": Vector2.INF, "incoming_velocity": Vector2.ZERO}
 sample.ball.body_entered.connect(func(body: Node) -> void:
  if paddle.strikes == 0 and body is StaticBody2D and not body is PlaygroundFlipper and not body.has_meta("bumper"):
   result.wall_contacts += 1)
 sample.ball.bumper_hit.connect(func(body: Node) -> void:
  if paddle.strikes > 0 and body.global_position.distance_to(target) < 1.0:
   result.target_hit = true)
 sample.rings.collected.connect(func(position: Vector2) -> void:
  if paddle.strikes > 0 and position.distance_to(target) < 1.0:
   result.target_ring = true)
 var strike_seen := false
 var still_frames := 0
 for tick in 720:
  var nearest := Geometry2D.get_closest_point_to_segment(sample.ball.position, paddle.position, paddle.tip())
  result.closest_paddle = minf(result.closest_paddle, nearest.distance_to(sample.ball.position))
  if press and result.pressed_tick < 0 and sample.ball.linear_velocity.y > 0.0 and sample.ball.position.y < paddle.position.y + 15.0 and nearest.distance_to(sample.ball.position) < trigger:
   result.pressed_tick = tick
   result.incoming_velocity = sample.ball.linear_velocity
  var held: bool = result.pressed_tick >= 0 and tick - result.pressed_tick < hold_ticks
  sample.controls.virtual_left = held and paddle.side > 0.0
  sample.controls.virtual_right = held and paddle.side < 0.0
  await frames(1)
  result.strikes = paddle.strikes
  result.finite = result.finite and sample.ball.position.is_finite() and sample.ball.linear_velocity.is_finite()
  if paddle.strikes > 0:
   if not strike_seen:
    result.strike_position = sample.ball.position
    strike_seen = true
   result.minimum_y_after_strike = minf(result.minimum_y_after_strike, sample.ball.position.y)
  result.useful = result.target_hit or result.target_ring
  if result.useful:
   result.useful_tick = tick
   break
  if sample.ball.position.y > 720.0:
   result.missed = true
   break
  if sample.ball.position.y < -25.0:
   var opening := data.world_rect(data.top_connection)
   result.exit = sample.ball.position.x > opening.position.x + PlaygroundBall.RADIUS + ChunkData.RAIL_RADIUS and sample.ball.position.x < opening.end.x - PlaygroundBall.RADIUS - ChunkData.RAIL_RADIUS
   result.exit_position = sample.ball.position
   break
  still_frames = still_frames + 1 if sample.ball.linear_velocity.length() < 3.0 else 0
  if still_frames > 120:
   result.resting = true
   break
 sample.world.free()
 await frames(2)
 return result
