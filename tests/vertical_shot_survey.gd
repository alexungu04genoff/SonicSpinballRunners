extends SceneTree
## Real Balanced flipper shots; diagnostic coverage, not difficulty calibration.
## Run with --headless --fixed-fps 120 --script res://tests/vertical_shot_survey.gd.
## No teleport or velocity edits occur between the opening press and shot completion.
const CONTACT_DISTANCES: Array[float] = [55.0, 75.0, 95.0, 135.0]
const INCOMING_SPEEDS: Array[float] = [-200.0, 0.0, 200.0]
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func create_game(seed_value: int, preference: int) -> void:
 game = load("res://scenes/playground.tscn").instantiate()
 game.generation_seed = seed_value
 game.generation_difficulty = preference
 root.add_child(game)
 await frames(4)
 game.set_physics_process(false) # Disable automatic drain/serve; observe one real shot.
 game.controls.virtual_enabled = true
 game.ring_field.set_physics_process(false)
 game.presentation.set_process(false)

func prepare_ball(where: Vector2, velocity: Vector2, waiting: bool = false) -> void:
 # Each controlled shot starts with a fresh body. Reusing a CCD body after a long
 # teleport can retain native contact recovery from the previous sample.
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
 game.ring_field.ball = fresh
 game.presentation.ball = fresh
 fresh.teleport_to(where, velocity, waiting)

func sample_shot(paddle: int, distance: float, incoming_x: float) -> Dictionary:
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 game.ball.teleport_to(game.ball.serve_position, Vector2.ZERO, true)
 await frames(20)
 var flipper: PlaygroundFlipper = game.flippers[paddle]
 var start := flipper.global_position + Vector2.RIGHT.rotated(flipper.rest_angle()) * distance + Vector2(0, -42)
 prepare_ball(start, Vector2(incoming_x, 100.0))
 await frames(3)
 var strikes_before := flipper.strikes
 game.controls.virtual_left = flipper.side > 0
 game.controls.virtual_right = flipper.side < 0
 var receiver: ChunkData = game.layout.chunks[1 if paddle < 2 else 0]
 var seam := float(receiver.grid_position.y + receiver.grid_dimensions.y) * ChunkData.GRID_SIZE
 var target_y := seam - 250.0
 var result := {"paddle": paddle, "contact_distance": distance, "incoming_vx": incoming_x, "strikes": 0, "entry": false, "chamber": false, "minimum_y": game.ball.position.y, "frames": 0}
 for tick in 600:
  await frames(1)
  if tick == 15:
   game.controls.virtual_left = false
   game.controls.virtual_right = false
  result.minimum_y = minf(result.minimum_y, game.ball.position.y)
  result.entry = result.entry or game.ball.position.y < seam - 50.0
  result.chamber = result.chamber or game.ball.position.y < target_y
  result.frames = tick + 1
  if game.ball.position.y > flipper.position.y + 150.0 or (tick > 36 and game.ball.position.y > flipper.position.y - 140.0 and game.ball.linear_velocity.y > 0.0):
   break
 result.strikes = flipper.strikes - strikes_before
 return result

func continuous_run(seconds: int = 40) -> Dictionary:
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 prepare_ball(game.ball.serve_position, Vector2.ZERO, true)
 await frames(20)
 game.ball.launch()
 var result := {"minimum_y": game.ball.serve_position.y, "middle": false, "top": false, "fell_from_top": false, "drained": false, "frames": 0, "strikes": []}
 var initial: Array[int] = []
 for flipper: PlaygroundFlipper in game.flippers:
  initial.append(flipper.strikes)
 var cooldown := 0
 for tick in seconds * 120:
  if cooldown > 0:
   cooldown -= 1
  game.controls.virtual_left = cooldown > 15
  game.controls.virtual_right = cooldown > 15
  if cooldown == 0 and game.ball.linear_velocity.y > 0:
   for flipper: PlaygroundFlipper in game.flippers:
    var nearest := Geometry2D.get_closest_point_to_segment(game.ball.position, flipper.global_position, flipper.global_position + Vector2.RIGHT.rotated(flipper.rest_angle()) * PlaygroundFlipper.LENGTH)
    if game.ball.position.y < flipper.position.y + 15 and nearest.distance_to(game.ball.position) < 58:
     cooldown = 30
     game.controls.virtual_left = true
     game.controls.virtual_right = true
     break
  await frames(1)
  result.minimum_y = minf(result.minimum_y, game.ball.position.y)
  result.middle = result.middle or game.ball.position.y < 1150.0
  result.top = result.top or game.ball.position.y < 450.0
  result.fell_from_top = result.fell_from_top or (result.top and game.ball.position.y > 1450.0)
  result.frames = tick + 1
  if game.ball.position.y > game.layout.bounds.end.y + 50.0:
   result.drained = true
   break
 for i in game.flippers.size():
  result.strikes.append(game.flippers[i].strikes - initial[i])
 return result

func run() -> void:
 var report := {"description": "Controlled actual flipper launches and continuous serve-to-drain samples. Not player success rates or proof of every possible trajectory.", "profile": "Balanced", "steering": 0.0, "modifier_enabled": false, "incoming_vy": 100.0, "press_frames": 15, "layouts": []}
 var total_strikes := 0
 var total_shots := 0
 var all_finite := true
 var continuous_witnesses: Dictionary = {}
 var arguments := OS.get_cmdline_user_args()
 var seeds: Array[int] = [1, 2]
 if arguments.has("--quick"):
  seeds = [1]
 for preference in 3:
  for seed_value in seeds:
   await create_game(seed_value, preference)
   var summary := {"signature": game.layout.signature, "pairs": [], "continuous": {}}
   for pair in 2:
    var samples := {"pair": "bottom" if pair == 0 else "middle", "entries": 0, "chambers": 0, "shots": [], "witness": {}}
    for side in 2:
     for distance in CONTACT_DISTANCES:
      for speed in INCOMING_SPEEDS:
       var shot := await sample_shot(pair * 2 + side, distance, speed)
       total_shots += 1
       total_strikes += int(shot.strikes == 1)
       all_finite = all_finite and is_finite(shot.minimum_y) and game.ball.position.is_finite() and game.ball.linear_velocity.is_finite()
       samples.shots.append(shot)
       if shot.strikes == 1:
        samples.entries += int(shot.entry)
        samples.chambers += int(shot.chamber)
        if shot.chamber and samples.witness.is_empty():
         samples.witness = shot
    summary.pairs.append(samples)
    print("VERTICAL ACCESS | ", game.layout.signature, " | ", samples.pair, " | entries=", samples.entries, "/", samples.shots.size(), " | chambers=", samples.chambers, "/", samples.shots.size(), " | witness=", samples.witness)
    check(samples.chambers > 0, "Real " + samples.pair + " flipper shot reaches the next chamber: " + game.layout.signature)
   summary.continuous = await continuous_run()
   var middle_id: String = game.layout.chunks[1].chunk_id
   var traversal: Dictionary = summary.continuous
   var complete: bool = traversal.top and traversal.fell_from_top and traversal.strikes[0] + traversal.strikes[1] > 0 and traversal.strikes[2] + traversal.strikes[3] > 0
   continuous_witnesses[middle_id] = continuous_witnesses.get(middle_id, false) or complete
   print("CONTINUOUS | ", game.layout.signature, " | ", summary.continuous)
   report.layouts.append(summary)
   game.queue_free()
   await frames(3)
 check(total_strikes == total_shots, "All %d controlled samples receive exactly one real flipper strike" % total_shots)
 check(all_finite, "All sampled trajectories remain finite")
 for middle_id: String in continuous_witnesses:
  check(continuous_witnesses[middle_id], "Continuous serve, both paddle pairs, top chamber and return to the bottom: " + middle_id)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var output := FileAccess.open("res://test-results/vertical-shot-survey.json", FileAccess.WRITE)
 check(output != null, "Vertical shot diagnostic report opens")
 if output != null:
  output.store_string(JSON.stringify(report, " "))
  output.close()
 print("RESULT | Vertical shots | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
