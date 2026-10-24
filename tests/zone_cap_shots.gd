extends "res://tests/zone_hard_rooms.gd"
## Controlled final-cap approach, separate from ordinary-input completion surveys.
## One initial entry velocity is prescribed below the cap. Thereafter only timed
## flipper input changes; real collision geometry and ZoneRun detect the portal.

func run() -> void:
 var layout := ZoneGenerator.generate(24, 0, TableGenerator.Difficulty.HARD)
 check(layout.valid, "Hard seed 24 generates for a controlled final-cap entry shot")
 if not layout.valid:
  quit(1)
  return
 var found := false
 var witness: Dictionary = {}
 var attempts := 0
 for speed: float in [900.0, 1100.0, 1300.0]:
  for offset: float in [0.0, -25.0, 25.0, -50.0, 50.0, -75.0, 75.0]:
   for sideways: float in [0.0, -120.0, 120.0]:
    witness = await cap_entry(layout, offset, Vector2(sideways, -speed))
    attempts += 1
    if witness.reached:
     found = true
     break
   if found:
    break
  if found:
   break
 witness.attempts = attempts
 print("HARD CAP ENTRY | ", witness)
 check(found, "A real shot from below the shaped final cap reaches the unlocked Zone portal")
 var recovered := false
 var recovery_witness: Dictionary = {}
 var recovery_attempts := 0
 for speed: float in [700.0, 800.0, 1000.0]:
  for offset: float in [0.0, 25.0, 50.0, -25.0, -50.0]:
   for sideways: float in [0.0, -80.0, 80.0, -160.0, 160.0]:
    recovery_witness = await cap_entry(layout, offset, Vector2(sideways, -speed), true)
    recovery_attempts += 1
    if recovery_witness.reached:
     recovered = true
     break
   if recovered:
    break
  if recovered:
   break
 recovery_witness.attempts = recovery_attempts
 print("HARD CAP RECOVERY | ", recovery_witness)
 check(recovered, "The final cap paddle catches an entry shot's descent and redirects it to the unlocked portal")
 var output := FileAccess.open("res://test-results/hard-cap-shot.json", FileAccess.WRITE)
 if output != null:
  output.store_string(JSON.stringify({"entry": witness, "recovery": recovery_witness}, " "))
  output.close()
 print("RESULT | Hard cap shots | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func cap_entry(layout: Dictionary, offset: float, velocity: Vector2, require_recovery: bool = false) -> Dictionary:
 var cap: ChunkData = layout.chunks[0]
 var opening := cap.world_rect(cap.bottom_connection)
 var start := Vector2(cap.world_point(cap.markers.entry).x + offset, opening.end.y + 30.0)
 var sample := fixture(cap, start, velocity)
 # Include the real room immediately below the cap, so entry cannot exploit an
 # absent neighboring boundary. It remains at its generated world transform.
 var below := TableChunk.new()
 below.data = layout.chunks[1]
 sample.world.add_child(below)
 below.build()
 for placement: Dictionary in below.data.world_flippers():
  var paddle := PlaygroundFlipper.new()
  paddle.position = placement.position
  paddle.side = placement.side
  paddle.length = placement.length
  paddle.ball = sample.ball
  paddle.controls = sample.controls
  paddle.tuning = sample.ball.tuning
  sample.world.add_child(paddle)
  sample.paddles.append(paddle)
 var zone := ZoneRun.new()
 zone.reset(true, load("res://data/green_hill_zone.tres"), layout)
 zone.active_act = 2
 zone.completed_acts = 2
 zone.observe_score(zone.targets[2])
 var result := {"seed": 24, "room": cap.chunk_id, "start": start, "entry_velocity": velocity, "goal": zone.acts[2].goal_position, "reached": false, "crossed_entrance": false, "minimum_y": start.y, "minimum_goal_distance": INF, "strikes": 0, "bumper_hits": 0, "ticks": 0, "escaped": false}
 var previous := start
 var cooldown := 0
 for tick in 960:
  cooldown = maxi(0, cooldown - 1)
  sample.controls.virtual_left = cooldown > 15
  sample.controls.virtual_right = cooldown > 15
  if cooldown == 0 and sample.ball.linear_velocity.y > 0:
   for paddle: PlaygroundFlipper in sample.paddles:
    var near := Geometry2D.get_closest_point_to_segment(sample.ball.position, paddle.position, paddle.tip())
    if sample.ball.position.y < paddle.position.y + 15 and near.distance_to(sample.ball.position) < 43:
     cooldown = 30
     sample.controls.virtual_left = paddle.side > 0
     sample.controls.virtual_right = paddle.side < 0
     break
  await frames(1)
  var current: Vector2 = sample.ball.position
  result.crossed_entrance = result.crossed_entrance or (previous.y >= opening.end.y and current.y < opening.end.y)
  result.minimum_y = minf(result.minimum_y, current.y)
  result.minimum_goal_distance = minf(result.minimum_goal_distance, Geometry2D.get_closest_point_to_segment(zone.acts[2].goal_position, previous, current).distance_to(zone.acts[2].goal_position))
  result.bumper_hits = sample.ball.bumper_hit_count
  result.ticks = tick + 1
  result.escaped = not current.is_finite() or current.x < -20 or current.x > 820 or current.y < -20
  result.strikes = 0
  for paddle: PlaygroundFlipper in sample.paddles:
   result.strikes += paddle.strikes
  if zone.observe_motion(previous, current):
   result.reached = result.crossed_entrance and zone.completed_acts == 3 and zone.state == ZoneRun.State.DRAFT and not result.escaped and (not require_recovery or result.strikes > 0)
   break
  previous = current
  if result.escaped or current.y > 1450:
   break
 sample.world.free()
 await frames(2)
 return result
