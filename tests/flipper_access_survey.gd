extends SceneTree
## Diagnostic, not a difficulty gate or a player success-rate estimate.
## Run with --headless --fixed-fps 120 --script res://tests/flipper_access_survey.gd.
## Append -- --all-hard to survey every Hard catalogue transform instead of sample seeds.
## Uses real paddles and Balanced physics, with no steering, modifiers, or auto-serve.
const CONTACT_DISTANCES: Array[float] = [55.0, 95.0, 135.0]
const INCOMING_SPEEDS: Array[float] = [-200.0, 0.0, 200.0]
const SHOT_FRAMES := 480
const TARGET_RADIUS := 70.0
var fixture: Node2D
var tuning: PhysicsTuning
var controls: PlaygroundInput
var ball: PlaygroundBall
var flippers: Array[PlaygroundFlipper] = []
var checks := 0
var failures := 0
var all_hard := false

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

func build_fixture(layout: Dictionary) -> void:
 fixture = Node2D.new()
 root.add_child(fixture)
 tuning = PhysicsTuning.new()
 fixture.add_child(tuning)
 controls = PlaygroundInput.new()
 controls.virtual_enabled = true
 fixture.add_child(controls)
 for resource: ChunkData in [layout.upper, layout.lower]:
  var chunk := TableChunk.new()
  chunk.data = resource
  if resource == layout.upper:
   chunk.junction_rails.assign(layout.junction_rails)
  fixture.add_child(chunk)
  chunk.build()
  chunk.wall_material.bounce = tuning.effective.wall_restitution
 ball = PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 ball.serve_position = layout.lower.world_point(layout.lower.markers.serve)
 ball.position = ball.serve_position
 fixture.add_child(ball)
 ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
 flippers.clear()
 for side: int in [1, -1]:
  var flipper := PlaygroundFlipper.new()
  flipper.side = float(side)
  flipper.position = layout.lower.world_point(layout.lower.markers["left_flipper" if side > 0 else "right_flipper"])
  flipper.ball = ball
  flipper.controls = controls
  flipper.tuning = tuning
  fixture.add_child(flipper)
  flippers.append(flipper)

func sample_shot(paddle: int, distance: float, incoming_x: float, target: Variant) -> Dictionary:
 controls.virtual_left = false
 controls.virtual_right = false
 ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
 await frames(20) # Return both paddles fully before positioning the next ball.
 var flipper := flippers[paddle]
 var start := flipper.global_position + Vector2.RIGHT.rotated(flipper.rest_angle()) * distance + Vector2(0, -42)
 ball.teleport_to(start, Vector2(incoming_x, 100.0))
 await frames(3) # Apply the teleport through the physics integrator before the press.
 var strikes_before := flipper.strikes
 controls.virtual_left = paddle == 0
 controls.virtual_right = paddle == 1
 var result := {"paddle": "left" if paddle == 0 else "right", "contact_distance": distance, "incoming_vx": incoming_x, "strikes": 0, "upper_entry": false, "reach_y450": false, "target_hit": false, "minimum_y": ball.position.y, "frames": 0}
 var previous := ball.position
 for tick in SHOT_FRAMES:
  await frames(1)
  # Only the opening press is used; no rescue flip or timed second strike.
  if tick == 15:
   controls.virtual_left = false
   controls.virtual_right = false
  result.minimum_y = minf(float(result.minimum_y), ball.position.y)
  result.upper_entry = result.upper_entry or ball.position.y < 650.0
  result.reach_y450 = result.reach_y450 or ball.position.y <= 450.0
  if target is Vector2:
   var nearest := Geometry2D.get_closest_point_to_segment(target, previous, ball.position)
   result.target_hit = result.target_hit or nearest.distance_to(target) <= TARGET_RADIUS
  previous = ball.position
  result.frames = tick + 1
  if ball.position.y > 1450.0 or (tick > 36 and ball.position.y > 1120.0 and ball.linear_velocity.y > 0.0):
   break
 result.strikes = flipper.strikes - strikes_before
 return result

func representative_layouts(preference: int) -> Array[Dictionary]:
 # Keep the common seeds for comparison, then include a different authored shape.
 # A mirror-only difference does not substitute for testing another chunk design.
 var layouts: Array[Dictionary] = []
 if all_hard:
  if preference != TableGenerator.Difficulty.HARD:
   return layouts
  for source: ChunkData in TableGenerator.CATALOGUE:
   for mirrored: bool in [false, true]:
    for shift: int in TableGenerator.allowed_shifts(source):
     var candidate: ChunkData = source.duplicate(true)
     candidate.mirrored = mirrored
     candidate.horizontal_shift_cells = shift
     var estimate := TableGenerator.estimate_difficulty(candidate, TableGenerator.LOWER)
     if estimate.band != TableGenerator.Difficulty.HARD:
      continue
     var validation := TableGenerator.validate(candidate, TableGenerator.LOWER)
     if validation.valid:
      layouts.append(TableGenerator._layout(0, preference, candidate, validation, estimate, false, PackedStringArray()))
  return layouts
 var sampled_chunks := PackedStringArray()
 for seed_value: int in [1, 2]:
  var layout := TableGenerator.generate_pair(seed_value, preference)
  layouts.append(layout)
  sampled_chunks.append(layout.upper.chunk_id)
 for seed_value in range(3, 25):
  var layout := TableGenerator.generate_pair(seed_value, preference)
  if not sampled_chunks.has(layout.upper.chunk_id):
   layouts.append(layout)
   break
 return layouts

func run() -> void:
 all_hard = OS.get_cmdline_user_args().has("--all-hard")
 check(Engine.physics_ticks_per_second == 120, "Survey uses the game's 120 Hz physics rate")
 var report := {"description": "Controlled real-flipper diagnostic; not player win rates, reachability proof, or a generation validity gate.", "profile": "Balanced", "steering": 0.0, "modifier_enabled": false, "duration_seconds": 4.0, "incoming_vy": 100.0, "target_radius": TARGET_RADIUS, "layouts": []}
 report["selection"] = "all Hard catalogue transforms (seed field unused)" if all_hard else "representative seeded layouts"
 var total_strikes := 0
 var total_shots := 0
 var finite_shots := true
 for preference in 3:
  for layout: Dictionary in representative_layouts(preference):
   build_fixture(layout)
   await frames(5)
   var target: Variant = layout.upper.world_point(layout.upper.markers.test_target) if layout.upper.markers.has("test_target") else null
   var summary := {"seed": layout.seed, "preference": preference, "signature": layout.signature, "valid_strikes": 0, "upper_entries": 0, "reach_y450": 0, "target_hits": 0, "test_target": [target.x, target.y] if target is Vector2 else null, "shots": []}
   for paddle in 2:
    for distance: float in CONTACT_DISTANCES:
     for incoming_x: float in INCOMING_SPEEDS:
      var shot := await sample_shot(paddle, distance, incoming_x, target)
      total_shots += 1
      summary.shots.append(shot)
      finite_shots = finite_shots and is_finite(float(shot.minimum_y)) and ball.position.is_finite() and ball.linear_velocity.is_finite()
      if int(shot.strikes) == 1:
       summary.valid_strikes += 1
       summary.upper_entries += int(shot.upper_entry)
       summary.reach_y450 += int(shot.reach_y450)
       summary.target_hits += int(shot.target_hit)
   total_strikes += int(summary.valid_strikes)
   if all_hard:
    check(summary.reach_y450 > 0 and (not target is Vector2 or summary.target_hits > 0), "At least one opening shot reaches the upper route and authored target: " + layout.signature)
   report.layouts.append(summary)
   print("ACCESS | ", summary.signature, " | strikes=", summary.valid_strikes, "/18 | y<650=", summary.upper_entries, " | y<=450=", summary.reach_y450, " | target=", str(summary.target_hits) if target is Vector2 else "n/a")
   fixture.queue_free()
   await frames(3)
 check(total_strikes == total_shots and total_shots >= 108, "All %d samples receive exactly one real flipper strike" % total_shots)
 check(finite_shots, "All sampled physics trajectories remain finite")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var report_path := "res://test-results/flipper-access-all-hard.json" if all_hard else "res://test-results/flipper-access-survey.json"
 var output := FileAccess.open(report_path, FileAccess.WRITE)
 check(output != null, "Machine-readable diagnostic report opens for writing")
 if output != null:
  output.store_string(JSON.stringify(report, " "))
  output.close()
 print("RESULT | ", checks, " checks | ", failures, " failures | ", report_path)
 quit(0 if failures == 0 else 1)
