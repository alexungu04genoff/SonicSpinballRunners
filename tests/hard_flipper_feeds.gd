extends "res://tests/zone_hard_rooms.gd"
## Gravity-fed approaches start in the upper room, never beside a paddle.
## Only a timed button press changes after the drop. Use --survey [--shaped]
## for the optional broader drop scan; the default is a small deterministic check.
const FEED_ROOMS: Array[String] = ["bank_vault", "offset_climb", "target_cove", "switchback"]

func run() -> void:
 if not OS.get_cmdline_user_args().has("--survey"):
  await regression()
  return
 var rows: Array[Dictionary] = []
 var layout := ZoneGenerator.generate(24, 0, TableGenerator.Difficulty.HARD)
 for name: String in FEED_ROOMS:
  var recipe: GridChunkRecipe = load("res://data/grid_chunks/zone_hard_" + name + ".tres")
  var compiled := GridChunkCompiler.compile(recipe)
  check(compiled.valid, name + " compiles with full clearance")
  if not compiled.valid:
   continue
  var data: ChunkData = compiled.chunk
  if OS.get_cmdline_user_args().has("--shaped") and layout.valid:
   for shaped: ChunkData in layout.chunks:
    if shaped.chunk_id == data.chunk_id:
     data = shaped.duplicate(true)
  data.grid_position = Vector2i.ZERO
  for paddle_index in data.flipper_placements.size():
   var hits := 0
   var target_hits := 0
   var best: Dictionary = {}
   for index in 50:
    var start := Vector2(100 + (index % 25) * 25, 100 + (index / 25) * 100)
    if not Geometry2D.is_point_in_polygon(start, data.world_polygon(data.playfield_outline)) or not TableGenerator.point_clear(start, data.gameplay_descriptors(), 20.0):
     continue
    var result := await feed(data, paddle_index, start, true)
    rows.append(result)
    if result.strikes > 0:
     hits += 1
     if best.is_empty() or result.rise > best.rise:
      best = result
    if result.target_scored:
     target_hits += 1
   print("NATURAL HARD FEED | ", name, " paddle=", paddle_index, " catches=", hits, " scoring=", target_hits, " best=", best)
 var output := FileAccess.open("res://test-results/hard-flipper-feeds-survey.json", FileAccess.WRITE)
 output.store_string(JSON.stringify(rows, " "))
 output.close()
 print("RESULT | Hard feed survey | %d compilation checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func feed(data: ChunkData, paddle_index: int, start: Vector2, press: bool, trigger_distance: float = 43.0, early: bool = false) -> Dictionary:
 var sample := fixture(data, start, Vector2.ZERO)
 var paddle: PlaygroundFlipper = sample.paddles[paddle_index]
 var target: Vector2 = data.world_flippers()[paddle_index].shot_target
 var result := {"room": data.chunk_id, "paddle": paddle_index, "start": start, "pressed": press, "early": early, "strikes": 0, "target_scored": false, "wall_contacts": 0, "bumper_contacts": 0, "feed_wall_contacts": 0, "feed_bumper_contacts": 0, "strike_position": Vector2.INF, "strike_velocity": Vector2.ZERO, "last": start, "rise": 0.0, "left_room": false, "upper_exit": false, "missed_downward": false, "press_tick": -1, "hit_tick": -1, "contact_fraction": -1.0, "impulse": Vector2.ZERO}
 paddle.shot_fired.connect(func(_position: Vector2, impulse: Vector2, fraction: float) -> void:
  result.contact_fraction = fraction
  result.impulse = impulse)
 sample.ball.body_entered.connect(func(body: Node) -> void:
  if body.name.begins_with("Rail"):
   result.wall_contacts += 1
  if body.has_meta("bumper"):
   result.bumper_contacts += 1)
 sample.ball.bumper_hit.connect(func(body: Node) -> void:
  if paddle.strikes > 0 and body.global_position.distance_to(target) < 1:
   result.target_scored = true)
 sample.rings.collected.connect(func(position: Vector2) -> void:
  if paddle.strikes > 0 and position.distance_to(target) < 1:
   result.target_scored = true)
 var pressed_tick := -1
 var lowest_after_strike := INF
 for tick in 960:
  var nearest := Geometry2D.get_closest_point_to_segment(sample.ball.position, paddle.position, paddle.tip())
  if press and pressed_tick < 0 and sample.ball.linear_velocity.y > 0 and sample.ball.position.y < paddle.position.y + 15 and nearest.distance_to(sample.ball.position) < trigger_distance:
   pressed_tick = tick
  var held := (tick >= 5 and tick < 20) if early else pressed_tick >= 0 and tick - pressed_tick < 15
  sample.controls.virtual_left = held and paddle.side > 0
  sample.controls.virtual_right = held and paddle.side < 0
  await frames(1)
  if paddle.strikes > 0 and result.strikes == 0:
   result.strike_position = sample.ball.position
   result.strike_velocity = sample.ball.linear_velocity
   result.feed_wall_contacts = result.wall_contacts
   result.feed_bumper_contacts = result.bumper_contacts
  result.strikes = paddle.strikes
  result.last = sample.ball.position
  if paddle.strikes > 0:
   lowest_after_strike = minf(lowest_after_strike, sample.ball.position.y)
   result.rise = result.strike_position.y - lowest_after_strike
  if result.target_scored:
   result.hit_tick = tick
   break
  if sample.ball.position.y > 730 or sample.ball.position.y < -30:
   result.left_room = true
   var opening := data.world_rect(data.top_connection)
   result.upper_exit = sample.ball.position.y < -30 and paddle.strikes > 0 and sample.ball.position.x > opening.position.x + PlaygroundBall.RADIUS and sample.ball.position.x < opening.end.x - PlaygroundBall.RADIUS
   result.missed_downward = sample.ball.position.y > 730
   break
 sample.world.free()
 await frames(2)
 result.press_tick = pressed_tick
 return result

func regression() -> void:
 var layout := ZoneGenerator.generate(24, 0, TableGenerator.Difficulty.HARD)
 check(layout.valid, "Hard24 final shaped layout remains valid")
 if not layout.valid:
  quit(1)
  return
 var witnesses: Array[Dictionary] = []
 var starts := {"zone_hard_bank_vault": Vector2(525, 100), "zone_hard_offset_climb": Vector2(600, 200), "zone_hard_target_cove": Vector2(100, 200)}
 for source: ChunkData in layout.chunks:
  if not starts.has(source.chunk_id):
   continue
  for mirrored: bool in [false, true]:
   var data: ChunkData = source.duplicate(true)
   data.grid_position = Vector2i.ZERO
   data.mirrored = mirrored
   var start := data.world_point(starts[source.chunk_id])
   check(Geometry2D.is_point_in_polygon(start, data.world_polygon(data.playfield_outline)) and TableGenerator.point_clear(start, data.gameplay_descriptors(), 20.0), "%s mirrored=%s upstream start has full clearance" % [data.chunk_id, mirrored])
   var caught := await feed(data, 0, start, true)
   var missed := await feed(data, 0, start, false)
   var early := await feed(data, 0, start, false, 43.0, true)
   caught.mirrored = mirrored
   missed.mirrored = mirrored
   witnesses.append(caught)
   witnesses.append(missed)
   witnesses.append(early)
   print("HARD TIMED FEED | ", caught)
   print("HARD MISSED FEED | ", missed)
   var follows_feed: bool = caught.feed_bumper_contacts >= 3 if data.chunk_id == "zone_hard_target_cove" else caught.feed_wall_contacts > 0
   check(caught.strikes == 1 and follows_feed and (caught.target_scored or caught.upper_exit), "%s mirrored=%s follows its bank or bumper feed to a scored target or upper exit" % [data.chunk_id, mirrored])
   check(missed.strikes == 0 and missed.missed_downward, "%s mirrored=%s missed catch falls back to lower recovery" % [data.chunk_id, mirrored])
   check(early.strikes == 0 and early.missed_downward, "%s mirrored=%s premature button press misses the later feed" % [data.chunk_id, mirrored])
 var output := FileAccess.open("res://test-results/hard-flipper-feeds.json", FileAccess.WRITE)
 output.store_string(JSON.stringify(witnesses, " "))
 output.close()
 print("RESULT | Hard natural feeds | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
