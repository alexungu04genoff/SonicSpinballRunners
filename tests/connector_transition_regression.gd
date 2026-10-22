extends "res://tests/vertical_shot_survey.gd"
## Focused passive-bank geometry and real 2D collision checks. Reuses the traversal
## diagnostic's frame stepping and uninterrupted shared-input play sample.
const TRANSITIONS = preload("res://scripts/connector_transitions.gd")
const V5_STATIC_GEOMETRY := {
 "0/1": "5a71f6e49e4264b4bb5108e771e0d8cee97a2f66fd2c6d8945db40b02e6953dd",
 "0/2": "0fac537fdde3e4ee5dbadeabc23c3c7f50316380e1ac5d997ae1a0d40046b242",
 "0/18": "5a71f6e49e4264b4bb5108e771e0d8cee97a2f66fd2c6d8945db40b02e6953dd",
 "0/23": "0fac537fdde3e4ee5dbadeabc23c3c7f50316380e1ac5d997ae1a0d40046b242",
 "2/1": "89d4235fa8981f936b44592e57e3096dd18db3fbeae8b1987b826f0f5887267f",
 "2/2": "eb76494c81902364bedd80bbd5be7cac2d024f4a133bca9ed4cefefdfcee74fe",
 "2/18": "f87f57ee02a32343f70eae870fc89bce4f63a83f5417ae9a7517d8c5104acd26",
 "2/23": "c0c6140f85a56c02594cb762b9e5387759d56dc249a0b26d2aae092af38f2104",
}
var fixture: Node2D
var passive_tuning: PhysicsTuning
var passive_controls: PlaygroundInput
var passive_ball: PlaygroundBall

func geometry_hash(layout: Dictionary, include_flippers: bool = true) -> String:
 var geometry: Array = []
 for chunk: ChunkData in layout.chunks:
  geometry.append(chunk.gameplay_descriptors())
  if include_flippers:
   geometry.append(chunk.world_flippers())
 for junction: Dictionary in layout.junctions:
  geometry.append(junction.passage)
  geometry.append(junction.junction_rails)
 return var_to_str(geometry).sha256_text()

func build_passive_fixture(chunks: Array[ChunkData], junctions: Array) -> void:
 fixture = Node2D.new()
 root.add_child(fixture)
 passive_tuning = PhysicsTuning.new()
 fixture.add_child(passive_tuning)
 passive_tuning.effective.gravity_scale = 0.0
 passive_tuning.effective.rolling_acceleration = 0.0
 passive_tuning.effective.rolling_drag = 0.0
 passive_controls = PlaygroundInput.new()
 passive_controls.virtual_enabled = true
 fixture.add_child(passive_controls)
 for i in chunks.size():
  var chunk := TableChunk.new()
  chunk.data = chunks[i]
  for junction: Dictionary in junctions:
   if junction.upper_index == i:
    chunk.junction_rails.append_array(junction.junction_rails)
  fixture.add_child(chunk)
  chunk.build()

func passive_shot(start: Vector2, velocity: Vector2, ticks: int = 36) -> Dictionary:
 if is_instance_valid(passive_ball):
  passive_ball.free()
 passive_ball = PlaygroundBall.new()
 passive_ball.position = start
 passive_ball.tuning = passive_tuning
 passive_ball.controls = passive_controls
 fixture.add_child(passive_ball)
 passive_ball.teleport_to(start, velocity)
 var result := {"start": start, "initial_velocity": velocity, "peak_speed": velocity.length(), "minimum_y": start.y, "escaped": false}
 for tick in ticks:
  await frames(1)
  result.peak_speed = maxf(result.peak_speed, passive_ball.linear_velocity.length())
  result.minimum_y = minf(result.minimum_y, passive_ball.position.y)
  result.escaped = result.escaped or passive_ball.position.x < 0 or passive_ball.position.x > 800 or passive_ball.position.y < 0
 result["position"] = passive_ball.position
 result["velocity"] = passive_ball.linear_velocity
 result["bumper_hits"] = passive_ball.bumper_hit_count
 result["rebounds"] = passive_ball.sweep_rebounds
 return result

func collider_rails_match(chunk: TableChunk, expected: Array) -> bool:
 var matched := 0
 for body: Node in chunk.get_children():
  if not body is StaticBody2D or body.has_meta("bumper"):
   continue
  var collision: CollisionShape2D = body.get_child(0)
  var shape: CapsuleShape2D = collision.shape
  var half: Vector2 = Vector2.DOWN.rotated(collision.global_rotation) * (shape.height * 0.5 - shape.radius)
  var a: Vector2 = collision.global_position - half
  var b: Vector2 = collision.global_position + half
  var found := false
  for rail: Array in expected:
   found = found or (a.distance_to(rail[0]) < 0.01 and b.distance_to(rail[1]) < 0.01) or (b.distance_to(rail[0]) < 0.01 and a.distance_to(rail[1]) < 0.01)
  if not found:
   return false
  matched += 1
 return matched == expected.size()

func run() -> void:
 # Static fingerprints were captured before the drain/recovery flipper changes.
 # Flipper placements intentionally change; their actual collision checks live
 # in flipper_recovery_regression.gd. Keep all other geometry protected here.
 var unaffected := true
 for key: String in V5_STATIC_GEOMETRY:
  var parts := key.split("/")
  unaffected = unaffected and geometry_hash(TableGenerator.generate(int(parts[1]), int(parts[0])), false) == V5_STATIC_GEOMETRY[key]
 check(unaffected, "Easy and Hard retain v5 static rails, bumpers, rings and junctions for eight sampled layouts")
 var reproducible := true
 var valid := true
 var styles: Dictionary = {}
 for seed_value in range(1, 9):
  var a := TableGenerator.generate(seed_value, TableGenerator.Difficulty.NORMAL)
  var b := TableGenerator.generate(seed_value, TableGenerator.Difficulty.NORMAL)
  reproducible = reproducible and a.signature == b.signature and geometry_hash(a) == geometry_hash(b)
  valid = valid and a.valid and a.preference_available and TableGenerator.validate_course(a.chunks).valid
  for junction: Dictionary in a.junctions:
   styles[junction.get("transition_style", "Step")] = true
 check(reproducible and valid, "Normal seeds 1–8 reproduce technically valid in-tier courses")
 check(styles.has("Step") and (styles.has("Bank") or styles.has("Curve")), "Normal seed variation retains steps alongside passive banks")

 for seed_value: int in [18, 23]:
  var source := TableGenerator.generate_pair(seed_value, TableGenerator.Difficulty.NORMAL)
  var original := geometry_hash(source)
  var correct_ceiling := false
  for rail: Dictionary in source.junction_rails:
   correct_ceiling = correct_ceiling or (rail.a == Vector2(595, 700) and rail.b == Vector2(745, 700))
  check(correct_ceiling, "Legacy Normal %d reproduces the reported 150 px right ceiling" % seed_value)
  build_passive_fixture(source.chunks, source.junctions)
  var step_shot := await passive_shot(Vector2(670, 820), Vector2(0, -800))
  check(step_shot.velocity.y > 0 and absf(step_shot.velocity.x) < 5, "Legacy ceiling reflects a vertical shot downward")
  fixture.free()
  for style: String in ["Bank", "Curve"]:
   var reshaped := TRANSITIONS.reshape(source.chunks, style)
   var validation := TableGenerator.validate_course(reshaped.chunks)
   var stable := geometry_hash(source) == original
   for i in source.chunks.size():
    stable = stable and source.chunks[i].markers == reshaped.chunks[i].markers and source.chunks[i].world_flippers() == reshaped.chunks[i].world_flippers() and source.chunks[i].grid_position == reshaped.chunks[i].grid_position
    stable = stable and source.chunks[i].mirrored == reshaped.chunks[i].mirrored and source.chunks[i].horizontal_shift_cells == reshaped.chunks[i].horizontal_shift_cells
   check(validation.valid and reshaped.changed and stable, "%s %d is valid and preserves source resources, markers, transforms and paddle placements" % [style, seed_value])
   build_passive_fixture(reshaped.chunks, validation.junctions)
   var bank_shot := await passive_shot(Vector2(670, 820), Vector2(0, -800))
   print("PASSIVE BANK | ", seed_value, " | ", style, " | step=", step_shot, " | bank=", bank_shot)
   check(bank_shot.velocity.x < -100 and bank_shot.velocity.y < 0 and bank_shot.position.y < 700, "Passive %s redirects the former ceiling shot inward while retaining upward travel" % style)
   check(bank_shot.peak_speed <= 800.1 and bank_shot.bumper_hits == 0, "Passive contact adds no speed, steering or bumper impulse")
   var both_directions := true
   for direction: float in [-1, 1]:
    # Restrict this probe to the seam. The unchanged launch-deck bumper at y820
    # intentionally blocks a longer centerline descent after a successful crossing.
    var crossing := await passive_shot(Vector2(400, 700 - direction * 40), Vector2(0, direction * 1200), 9)
    both_directions = both_directions and (crossing.position.y - 700) * direction > 25 and absf(crossing.velocity.y - direction * 1200) < 3
   check(both_directions, "Banked junction keeps the central route open in both directions")
   var contained := true
   for probe: Vector2 in [Vector2(620, 820), Vector2(650, 760), Vector2(570, 610)]:
    var fast := await passive_shot(probe, Vector2(4200, -6800), 8)
    contained = contained and not fast.escaped and fast.rebounds > 0 and fast.position.is_finite() and fast.velocity.is_finite()
   check(contained, "Fast oblique probes near bank facets and endpoints remain contained")
   fixture.free()

 for seed_value: int in [18, 23]:
  await create_game(seed_value, TableGenerator.Difficulty.NORMAL)
  var trials := await continuous_trials()
  var traversal: Dictionary = trials.back()
  print("BANK PLAY | ", game.layout.signature, " | ", trials)
  check(traversal.top and traversal.fell_from_top and traversal.strikes[0] + traversal.strikes[1] > 0 and traversal.strikes[2] + traversal.strikes[3] > 0, "Normal %d supports an uninterrupted serve-to-top-to-bottom run using both paddle pairs" % seed_value)
  var lower: TableChunk = game.chunks.back()
  var old_lower_geometry := lower.data.gameplay_descriptors()
  var old_lower_id := lower.get_instance_id()
  var bottom_paddles: Array = [game.flippers[0], game.flippers[1]]
  paused = true
  game.request_generation(1, TableGenerator.Difficulty.HARD)
  for i in 3:
   await process_frame
  var expected: ChunkData = game.layout.chunks.back()
  var replacement_needed: bool = old_lower_geometry != expected.gameplay_descriptors()
  var current_lower: TableChunk = game.chunks.back()
  var actual_rails: Array = []
  var expected_rails: Array = []
  for item: Dictionary in current_lower.descriptors:
   if item.kind == "rail":
    actual_rails.append([item.a, item.b])
  for item: Dictionary in expected.gameplay_descriptors():
   if item.kind == "rail":
    expected_rails.append([item.a, item.b])
  check(actual_rails == expected_rails and collider_rails_match(current_lower, expected_rails) and (not replacement_needed or current_lower.get_instance_id() != old_lower_id) and game.flippers[0] == bottom_paddles[0] and game.flippers[1] == bottom_paddles[1], "Bank-to-step regeneration rebuilds changed lower collision rails while preserving paddle placements")
  paused = false
  game.queue_free()
  await frames(3)
 print("RESULT | Connector transitions | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
