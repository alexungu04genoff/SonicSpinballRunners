extends SceneTree
## Real 120 Hz collision checks. Each sample creates one fresh ball, then uses only input.
## Run with --headless --fixed-fps 120 --script res://tests/flipper_recovery_regression.gd.
var checks := 0
var failures := 0
var game: Node
var report: Dictionary = {"drops": [], "cradles": [], "passages": [], "recoveries": []}

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func check(condition: bool, label: String, detail: String = "") -> void:
 checks += 1
 if condition:
  print("PASS | ", label, " | ", detail)
 else:
  failures += 1
  push_error("FAIL | " + label + " | " + detail)

func create_game(seed_value: int, preference: int) -> void:
 game = load("res://scenes/playground.tscn").instantiate()
 game.generation_seed = seed_value
 game.generation_difficulty = preference
 root.add_child(game)
 await frames(4)
 game.controls.virtual_enabled = true
 game.presentation.set_process(false)
 game.ring_field.set_physics_process(false)

func remove_game() -> void:
 game.queue_free()
 await frames(3)

func fresh_ball(where: Vector2, velocity: Vector2) -> void:
 # Replacing the body avoids stale native CCD contact recovery between independent
 # initial conditions. No transform or velocity edits occur during a sample.
 var serve: Vector2 = game.ball.serve_position
 game.ball.free()
 var fresh := PlaygroundBall.new()
 fresh.position = where
 fresh.serve_position = serve
 fresh.tuning = game.tuning
 fresh.controls = game.controls
 game.world.add_child(fresh)
 game.ball = fresh
 for flipper: PlaygroundFlipper in game.flippers:
  flipper.ball = fresh
 game.presentation.ball = fresh
 game.ring_field.ball = fresh
 game.ring_field.previous_ball_position = where
 fresh.bumper_hit.connect(game._on_bumper_hit)
 fresh.teleport_to(where, velocity)
 game.respawn_time = -1.0
 game.auto_launch_time = -1.0

func rest_flippers() -> void:
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 game.ball.serve_pending = true
 await frames(22)

func drop_sample(x: float, profile: int, early_press: bool = false) -> Dictionary:
 game.set_physics_process(true)
 game.tuning.select_profile(profile)
 await rest_flippers()
 var start := Vector2(x, game.flippers[0].position.y - 95.0)
 fresh_ball(start, Vector2.ZERO)
 var initial_number: int = game.ball_number
 var strikes_before: int = game.flippers[0].strikes + game.flippers[1].strikes
 var result := {"x": x, "profile": profile, "early_press": early_press, "drained": false, "respawned": false, "relaunched": false, "drain_frame": -1, "drain_position": Vector2.ZERO, "last_position": start, "last_velocity": Vector2.ZERO, "strikes": 0}
 for tick in 1800:
  game.controls.virtual_left = early_press and tick < 10
  game.controls.virtual_right = early_press and tick < 10
  await frames(1)
  result.last_position = game.ball.position
  result.last_velocity = game.ball.linear_velocity
  if not result.drained and game.ball_number > initial_number:
   result.drained = true
   result.drain_frame = tick
   result.drain_position = game.ball.position
  if result.drained and game.ball.serve_pending and game.ball.position.distance_to(game.ball.serve_position) < 1.0:
   result.respawned = true
  if result.respawned and not game.ball.serve_pending and game.ball.linear_velocity.y < -500.0:
   result.relaunched = true
   break
 result.strikes = game.flippers[0].strikes + game.flippers[1].strikes - strikes_before
 report.drops.append(result)
 return result

func held_cradle_sample(paddle: int) -> Dictionary:
 game.set_physics_process(true)
 game.tuning.select_profile(0)
 await rest_flippers()
 game.controls.virtual_left = true
 game.controls.virtual_right = true
 await frames(20)
 var flipper: PlaygroundFlipper = game.flippers[paddle]
 fresh_ball(flipper.position + Vector2(flipper.side * 20.0, -80.0), Vector2.ZERO)
 var initial_number: int = game.ball_number
 await frames(960)
 var result := {"paddle": paddle, "held_position": game.ball.position, "held_velocity": game.ball.linear_velocity, "held_without_drain": game.ball_number == initial_number, "released_drain": false}
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 for tick in 1200:
  await frames(1)
  if game.ball_number > initial_number:
   result.released_drain = game.ball.position.y > game.layout.bounds.end.y + 50.0
   break
 report.cradles.append(result)
 return result

func upward_sample(mode: String, offset: float) -> Dictionary:
 game.set_physics_process(false)
 await rest_flippers()
 var middle: ChunkData = game.layout.chunks[1]
 var x: float = middle.world_point(middle.markers.entry).x + offset
 var bottom_y := float(middle.grid_position.y + middle.grid_dimensions.y) * ChunkData.GRID_SIZE
 var top_pivot := minf(game.flippers[2].position.y, game.flippers[3].position.y)
 var lower_pivot := maxf(game.flippers[2].position.y, game.flippers[3].position.y)
 if mode == "held":
  game.controls.virtual_left = true
  game.controls.virtual_right = true
  await frames(15)
 fresh_ball(Vector2(x, bottom_y - 20.0), Vector2(0, -1200))
 var initial_strikes: int = game.flippers[2].strikes + game.flippers[3].strikes
 var result := {"layout": game.layout.signature, "mode": mode, "offset": offset, "crossed": false, "minimum_y": bottom_y, "finite": true, "strikes": 0}
 for tick in 90:
  if mode == "moving":
   var near_paddles: bool = game.ball.position.y < lower_pivot + 90.0
   game.controls.virtual_left = near_paddles and tick % 24 < 12
   game.controls.virtual_right = near_paddles and tick % 24 < 12
  await frames(1)
  result.minimum_y = minf(result.minimum_y, game.ball.position.y)
  result.finite = result.finite and game.ball.position.is_finite() and game.ball.linear_velocity.is_finite()
  if game.ball.position.y < top_pivot - 90.0:
   result.crossed = true
   break
 result.strikes = game.flippers[2].strikes + game.flippers[3].strikes - initial_strikes
 report.passages.append(result)
 return result

func recovery_sample(paddle: int, fraction: float, incoming_x: float) -> Dictionary:
 game.set_physics_process(false)
 await rest_flippers()
 var flipper: PlaygroundFlipper = game.flippers[paddle]
 var distance: float = flipper.length * fraction
 var where := flipper.position + Vector2.RIGHT.rotated(flipper.rest_angle()) * distance + Vector2(0, -65)
 fresh_ball(where, Vector2(incoming_x, 180))
 var strikes_before: int = flipper.strikes
 var pressed_tick := -1
 var result := {"layout": game.layout.signature, "paddle": paddle, "fraction": fraction, "incoming_x": incoming_x, "strikes": 0, "chamber": false, "entry": false, "minimum_y": where.y, "finite": true}
 for tick in 660:
  var nearest := Geometry2D.get_closest_point_to_segment(game.ball.position, flipper.global_position, flipper.tip())
  if pressed_tick < 0 and game.ball.linear_velocity.y > 0.0 and game.ball.position.y < flipper.position.y + 15.0 and nearest.distance_to(game.ball.position) < 43.0:
   pressed_tick = tick
  var pressed: bool = pressed_tick >= 0 and tick - pressed_tick < 15
  game.controls.virtual_left = pressed and flipper.side > 0.0
  game.controls.virtual_right = pressed and flipper.side < 0.0
  await frames(1)
  result.strikes = flipper.strikes - strikes_before
  result.minimum_y = minf(result.minimum_y, game.ball.position.y)
  result.entry = result.entry or game.ball.position.y < 650.0
  result.chamber = result.chamber or game.ball.position.y < 450.0
  result.finite = result.finite and game.ball.position.is_finite() and game.ball.linear_velocity.is_finite()
  if result.chamber or game.ball.position.y > flipper.position.y + 180.0:
   break
 report.recoveries.append(result)
 return result

func run() -> void:
 await create_game(8, TableGenerator.Difficulty.NORMAL)
 var rest_gap: float = game.flippers[0].tip().distance_to(game.flippers[1].tip()) - PlaygroundFlipper.RADIUS * 2.0
 check(rest_gap > PlaygroundBall.RADIUS * 2.0 + 10.0, "Resting bottom tips leave ball diameter plus useful drain clearance", "gap=%.2f px" % rest_gap)
 var drops_work := true
 for profile in 2:
  for x: float in [365.0, 385.0, 400.0, 415.0, 435.0]:
   var result := await drop_sample(x, profile)
   drops_work = drops_work and result.drained and result.drain_position.y > game.layout.bounds.end.y + 50.0 and result.respawned and result.relaunched
   print("LOW SPEED DROP | ", result)
 check(drops_work, "Balanced and Floaty center/tip-near zero-speed drops physically drain and automatically relaunch")
 var miss := await drop_sample(400.0, 0, true)
 check(miss.drained and miss.respawned and miss.relaunched and miss.strikes == 0, "An early missed flip drains, respawns and relaunches without a forced ball correction", str(miss))
 var cradles_release := true
 for paddle in [0, 1]:
  var cradle := await held_cradle_sample(paddle)
  cradles_release = cradles_release and cradle.released_drain
  print("HELD CRADLE | ", cradle)
 check(cradles_release, "Releasing either raised bottom flipper frees its hinge cradle and permits a physical drain")
 await remove_game()

 var arrangements: Dictionary = {}
 for specification: Array in [[1, TableGenerator.Difficulty.EASY], [2, TableGenerator.Difficulty.EASY], [8, TableGenerator.Difficulty.NORMAL]]:
  await create_game(specification[0], specification[1])
  var middle: ChunkData = game.layout.chunks[1]
  arrangements[middle.chunk_id] = true
  var passages_work := true
  for mode: String in ["rest", "held", "moving"]:
   for offset: float in [-8.0, 0.0, 8.0]:
    var passage := await upward_sample(mode, offset)
    passages_work = passages_work and passage.crossed and passage.finite
    print("MIDDLE PASSAGE | ", passage)
  check(passages_work, "Three upward lanes pass resting, raised and moving middle flippers: " + middle.chunk_id)
  if specification[0] == 8:
   var deck_route := true
   var offset: float = game.layout.bounds.get_center().x - middle.world_point(middle.markers.entry).x
   for mode: String in ["rest", "held", "moving"]:
    var passage := await upward_sample(mode, offset)
    deck_route = deck_route and passage.crossed and passage.finite
    print("NORMAL 8 DECK CENTER | ", passage)
   check(deck_route, "Normal 8's lower-deck center shot at x=400 passes the offset middle pair in every tested paddle state")
  var recovered := false
  var all_finite := true
  var witness: Dictionary = {}
  for paddle in [2, 3]:
   for fraction: float in [0.5, 0.7, 0.9]:
    for incoming_x: float in [-150.0, 0.0, 150.0]:
     var recovery := await recovery_sample(paddle, fraction, incoming_x)
     all_finite = all_finite and recovery.finite
     if recovery.strikes == 1 and recovery.chamber:
      recovered = true
      witness = recovery
      break
    if recovered:
     break
   if recovered:
    break
  check(recovered and all_finite, "A timed descending middle recovery reaches the upper chamber: " + middle.chunk_id, str(witness))
  await remove_game()
 check(arrangements.size() == 3, "Physical traversal samples cover all three distinct recovery arrangements", str(arrangements.keys()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var output := FileAccess.open("res://test-results/flipper-recovery-report.json", FileAccess.WRITE)
 if output != null:
  output.store_string(JSON.stringify(report, " "))
  output.close()
 print("RESULT | Flipper recovery | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
