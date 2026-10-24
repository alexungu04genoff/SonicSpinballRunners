extends "res://tests/normal_flipper_feeds.gd"
## Real upstream returns: initialize once, then use one timed flipper press.
## Scoring is recorded independently from physically reaching the upper opening.

func run() -> void:
 if OS.get_cmdline_user_args().has("--survey"):
  await survey()
  return
 await regression()

func regression() -> void:
 var layout := ZoneGenerator.generate(28, 0, TableGenerator.Difficulty.NORMAL)
 check(layout.valid and layout.chunks[7].chunk_id == "zone_normal_target_garden", "Normal28 retains its final connector-shaped Garden")
 if not layout.valid:
  quit(1)
  return
 var rows: Array[Dictionary] = []
 for mirrored in [false, true]:
  var data: ChunkData = layout.chunks[7].duplicate(true)
  data.grid_position = Vector2i.ZERO
  data.mirrored = mirrored
  var start := data.world_point(Vector2(688, 200))
  check(inside_clear(data, start) and data.world_flippers()[1].position.y - start.y >= 300, "Progression return starts clear and 300px upstream")
  var placement: Dictionary = data.world_flippers()[1]
  check(placement.get("shot_kind", "score") == "upper_passage" and placement.shot_target == data.world_point(Vector2(400, 100)), "Progression metadata requires the upper passage rather than a bumper reward")
  # Five neighboring input timings cover five consecutive 120Hz press ticks.
  # Every witness must climb, not merely award a ring below the opening.
  for trigger: float in [36.0, 40.0, 43.0, 46.0, 50.0]:
   var climb := await route_shot(data, 1, start, trigger)
   climb["mirrored"] = mirrored
   rows.append(climb)
   check(climb.strikes == 1 and climb.wall_feed > 0 and climb.finite and climb.upper_exit and climb.bumpers_after_strike.is_empty() and climb.rings_after_strike.size() >= 2, "Garden mirrored=%s trigger%.0f follows its ring trail through the upper opening" % [mirrored, trigger], str(climb))
  var bonus := await route_shot(data, 1, start, 55.0)
  bonus["mirrored"] = mirrored
  rows.append(bonus)
  check(bonus.strikes == 1 and bonus.finite and bonus.bumpers_after_strike.has(data.world_point(Vector2(600, 200))) and bonus.fell_below and not bonus.upper_exit and not bonus.resting, "Garden mirrored=%s deliberate earlier scoring shot hits the offset bonus bumper then falls to lower recovery" % mirrored, str(bonus))
  for mode: String in ["none", "early"]:
   var missed := await route_shot(data, 1, start, 43.0, mode)
   missed["mirrored"] = mirrored
   rows.append(missed)
   check(missed.strikes == 0 and missed.finite and missed.fell_below and not missed.resting, "Garden mirrored=%s %s input misses the catch without a resting trap" % [mirrored, mode], str(missed))
  var side_score := await route_shot(data, 0, data.world_point(Vector2(112, 200)), 43.0)
  side_score["mirrored"] = mirrored
  rows.append(side_score)
  check(side_score.strikes == 1 and side_score.finite and side_score.bumpers_after_strike.has(data.world_point(Vector2(250, 350))), "Garden mirrored=%s left scoring branch remains intentional and reachable" % mirrored, str(side_score))
  var passage := await upward_shot(data, 0.0)
  check(passage.crossed and passage.finite, "Garden mirrored=%s resting paddles preserve the central upward shot" % mirrored, str(passage))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var output := FileAccess.open("res://test-results/target-garden-routes.json", FileAccess.WRITE)
 if output == null:
  push_error("Cannot write Target Garden route report: " + error_string(FileAccess.get_open_error()))
  quit(1)
  return
 output.store_string(JSON.stringify(rows, " "))
 output.close()
 print("RESULT | Target Garden routes | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func route_shot(data: ChunkData, paddle_index: int, start: Vector2, trigger: float, mode: String = "timed") -> Dictionary:
 var sample := fixture(data, start, Vector2.ZERO)
 var paddle: PlaygroundFlipper = sample.paddles[paddle_index]
 var result := {"paddle": paddle_index, "start": start, "trigger": trigger, "mode": mode, "pressed_tick": -1, "strikes": 0, "strike_position": Vector2.INF, "wall_feed": 0, "rings_after_strike": [], "bumpers_after_strike": [], "upper_exit": false, "exit_position": Vector2.INF, "fell_below": false, "finite": true, "resting": false, "minimum_y_after_strike": INF, "last": start}
 sample.ball.body_entered.connect(func(body: Node) -> void:
  if paddle.strikes == 0 and body is StaticBody2D and not body is PlaygroundFlipper and not body.has_meta("bumper"):
   result.wall_feed += 1)
 sample.ball.bumper_hit.connect(func(body: Node) -> void:
  if paddle.strikes > 0:
   result.bumpers_after_strike.append(body.global_position))
 sample.rings.collected.connect(func(position: Vector2) -> void:
  if paddle.strikes > 0:
   result.rings_after_strike.append(position))
 var still_frames := 0
 for tick in 960:
  var nearest := Geometry2D.get_closest_point_to_segment(sample.ball.position, paddle.position, paddle.tip())
  var threshold := 130.0 if mode == "early" else trigger
  if mode != "none" and result.pressed_tick < 0 and sample.ball.linear_velocity.y > 0 and sample.ball.position.y < paddle.position.y + 15 and nearest.distance_to(sample.ball.position) < threshold:
   result.pressed_tick = tick
  var held: bool = result.pressed_tick >= 0 and tick - result.pressed_tick < (4 if mode == "early" else 15)
  sample.controls.virtual_left = held and paddle.side > 0
  sample.controls.virtual_right = held and paddle.side < 0
  await frames(1)
  if paddle.strikes > 0 and result.strikes == 0:
   result.strike_position = sample.ball.position
  result.strikes = paddle.strikes
  result.last = sample.ball.position
  result.finite = result.finite and sample.ball.position.is_finite() and sample.ball.linear_velocity.is_finite()
  if paddle.strikes > 0:
   result.minimum_y_after_strike = minf(result.minimum_y_after_strike, sample.ball.position.y)
  if sample.ball.position.y > 730:
   result.fell_below = true
   break
  if sample.ball.position.y < -30:
   var opening := data.world_rect(data.top_connection)
   var margin := PlaygroundBall.RADIUS + ChunkData.RAIL_RADIUS
   result.upper_exit = paddle.strikes == 1 and sample.ball.linear_velocity.y < 0 and sample.ball.position.x > opening.position.x + margin and sample.ball.position.x < opening.end.x - margin
   result.exit_position = sample.ball.position
   break
  still_frames = still_frames + 1 if sample.ball.linear_velocity.length() < 3 else 0
  if still_frames > 120:
   result.resting = true
   break
 sample.world.free()
 await frames(2)
 return result

func survey() -> void:
 var layout := ZoneGenerator.generate(28, 0, TableGenerator.Difficulty.NORMAL)
 check(layout.valid, "Normal28 provides final connector-shaped Garden")
 if not layout.valid:
  quit(1)
  return
 for bumper_x: float in [550.0, 600.0, 650.0]:
  var data: ChunkData = layout.chunks[7].duplicate(true)
  data.grid_position = Vector2i.ZERO
  data.mirrored = false
  data.bumpers[3].position = Vector2(bumper_x, 200)
  data.rings = PackedVector2Array([Vector2(400, 50), Vector2(400, 100), Vector2(400, 150), Vector2(200, 450), Vector2(200, 400), Vector2(200, 350), Vector2(600, 450), Vector2(550, 400), Vector2(500, 300), Vector2(450, 200)])
  var errors := PackedStringArray()
  GridChunkCompiler._check_clearance(data, errors)
  print("GARDEN CANDIDATE | bumper_x=", bumper_x, " clearance=", errors)
  if not errors.is_empty():
   continue
  for trigger: float in [36.0, 40.0, 43.0, 46.0, 50.0, 55.0, 60.0]:
   var result := await route_shot(data, 1, Vector2(688, 200), trigger)
   print("GARDEN SURVEY | bumper_x=", bumper_x, " result=", result)
 quit(0)
