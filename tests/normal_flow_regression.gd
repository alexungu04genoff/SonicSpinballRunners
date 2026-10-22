extends "res://tests/connector_transition_regression.gd"
## Normal's geometry policy is separate from collision validity. Real collision
## samples observe momentum; no transform/velocity edits occur after launch.
var flow_report: Dictionary = {"layouts": [], "shots": [], "recovery": []}

func flow_transition(layout: Dictionary) -> Dictionary:
 var transition := {"junction_styles": [], "junction_paths": []}
 for junction: Dictionary in layout.junctions:
  transition.junction_styles.append(junction.transition_style)
  transition.junction_paths.append(junction.transition_paths)
 return transition

func narrowing_bank(layout: Dictionary) -> Dictionary:
 for junction: Dictionary in layout.junctions:
  for path: PackedVector2Array in junction.transition_paths:
   var side := 1.0 if path[path.size() - 1].x > junction.passage.get_center().x else -1.0
   for i in range(path.size() - 2, -1, -1):
    var delta := path[i + 1] - path[i]
    if delta.x * side < 8.0:
     continue
    var normal := Vector2(-delta.y, delta.x).normalized() * side
    var point := (path[i] + path[i + 1]) * 0.5
    var center := point + normal * (ChunkData.RAIL_RADIUS + PlaygroundBall.RADIUS + 0.5)
    return {"center": center, "normal": normal, "side": side, "seam": junction.passage.get_center().y}
 return {}

func observe_contact(center: Vector2, velocity: Vector2) -> Dictionary:
 if is_instance_valid(passive_ball):
  passive_ball.free()
 var start := center - velocity.normalized() * 60.0
 passive_ball = PlaygroundBall.new()
 passive_ball.position = start
 passive_ball.tuning = passive_tuning
 passive_ball.controls = passive_controls
 fixture.add_child(passive_ball)
 passive_ball.teleport_to(start, velocity)
 var result := {"incoming": velocity, "outgoing": Vector2.ZERO, "contact": false, "peak_speed": velocity.length(), "start": start}
 var after_contact := 0
 for tick in 90:
  await frames(1)
  var current := passive_ball.linear_velocity
  result.peak_speed = maxf(result.peak_speed, current.length())
  if tick > 1 and not result.contact and current.length() > 1.0 and current.distance_to(velocity) > 1.0:
   result.contact = true
   result.outgoing = current
  if result.contact:
   after_contact += 1
   if after_contact >= 12:
    break
 result.position = passive_ball.position
 result.bumper_hits = passive_ball.bumper_hit_count
 flow_report.shots.append(result)
 return result

func missed_bank_recovery(seed_value: int) -> Dictionary:
 await create_game(seed_value, TableGenerator.Difficulty.NORMAL)
 var bank := narrowing_bank(game.layout)
 var pair_start := 0 if bank.seam > 1000.0 else 2
 var result := {"seed": seed_value, "recovered": false, "attempts": []}
 for speed: float in [400.0, 600.0, 800.0]:
  for trigger: float in [42.0, 58.0]:
   game.controls.virtual_left = false
   game.controls.virtual_right = false
   prepare_ball(game.ball.serve_position, Vector2.ZERO, true)
   await frames(20)
   var incoming := Vector2(bank.side * speed, -180.0)
   prepare_ball(bank.center - incoming.normalized() * 60.0, incoming)
   var strikes_before: int = game.flippers[pair_start].strikes + game.flippers[pair_start + 1].strikes
   var attempt := {"speed": speed, "trigger": trigger, "downward_rebound": false, "recovery_strikes": 0, "returned_above_join": false, "finite": true}
   var cooldown := 0
   for tick in 1200:
    if cooldown > 0:
     cooldown -= 1
    game.controls.virtual_left = cooldown > 15
    game.controls.virtual_right = cooldown > 15
    if cooldown == 0 and game.ball.linear_velocity.y > 0.0:
     for paddle: PlaygroundFlipper in game.flippers:
      var nearest := Geometry2D.get_closest_point_to_segment(game.ball.position, paddle.position, paddle.tip())
      if game.ball.position.y < paddle.position.y + 15 and nearest.distance_to(game.ball.position) < trigger:
       game.controls.virtual_left = true
       game.controls.virtual_right = true
       cooldown = 30
       break
    await frames(1)
    if tick < 30 and game.ball.linear_velocity.x * bank.side < -20 and game.ball.linear_velocity.y > 20:
     attempt.downward_rebound = true
    attempt.recovery_strikes = game.flippers[pair_start].strikes + game.flippers[pair_start + 1].strikes - strikes_before
    attempt.returned_above_join = attempt.recovery_strikes > 0 and game.ball.position.y < bank.seam - 30
    attempt.finite = attempt.finite and game.ball.position.is_finite() and game.ball.linear_velocity.is_finite()
    if attempt.returned_above_join or game.ball.position.y > game.layout.bounds.end.y + 50:
     break
   result.attempts.append(attempt)
   if attempt.downward_rebound and attempt.returned_above_join and attempt.finite:
    result.recovered = true
    break
  if result.recovered:
   break
 game.free()
 await frames(3)
 flow_report.recovery.append(result)
 return result

func run() -> void:
 var valid := true
 var deterministic := true
 var final_rating := true
 var tops: Dictionary = {}
 var middles: Dictionary = {}
 var combinations: Dictionary = {}
 var styles: Dictionary = {}
 var source_snapshot := var_to_str([TableGenerator.CATALOGUE[3].rails, TableGenerator.MIDDLE_CATALOGUE[2].rails])
 for mode in 3:
  var library: Array[ChunkData] = TableGenerator.MIDDLE_CATALOGUE
  if mode > 0:
   library = [GridChunkCompiler.compile(load("res://data/grid_chunks/flow_relay%s.tres" % ("_variant" if mode == 2 else ""))).chunk]
  var seeds: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 18, 23] if mode == 0 else [1, 8, 18, 23]
  for seed_value: int in seeds:
   var a := TableGenerator.generate(seed_value, TableGenerator.Difficulty.NORMAL, TableGenerator.CATALOGUE, library)
   var b := TableGenerator.generate(seed_value, TableGenerator.Difficulty.NORMAL, TableGenerator.CATALOGUE, library)
   valid = valid and a.valid and a.preference_available and TableGenerator.validate_course(a.chunks).valid and ConnectorTransitions.normal_flow_issues(flow_transition(a)).is_empty()
   deterministic = deterministic and a.signature == b.signature and geometry_hash(a) == geometry_hash(b)
   var worst := 0.0
   for i in a.junctions.size():
    var junction: Dictionary = a.junctions[i]
    var measured := TableGenerator.estimate_difficulty(a.chunks[i], a.chunks[i + 1])
    var grade := ConnectorTransitions.maximum_grade(junction.transition_paths)
    worst = maxf(worst, maxf(measured.score, grade * 80.0))
    valid = valid and junction.junction_rails.is_empty()
    styles[junction.transition_style] = true
   final_rating = final_rating and is_equal_approx(worst, a.difficulty_estimate.score)
   if mode == 0:
    tops[a.chunks[0].chunk_id] = true
    middles[a.chunks[1].chunk_id] = true
    combinations[a.chunks[0].chunk_id + "/" + a.chunks[1].chunk_id] = true
   flow_report.layouts.append({"mode": mode, "seed": seed_value, "signature": a.signature})
 check(valid and deterministic, "22 Normal configurations reproduce valid in-tier geometry with no generated closure shoulders, including both grid recipes")
 check(final_rating, "Difficulty uses resulting collider geometry and the actual bank facets")
 check(tops.size() >= 4 and middles.size() == 3 and combinations.size() >= 6 and styles.has("Bank") and styles.has("Curve"), "Normal retains varied top/middle arrangements and both bank styles")
 check(source_snapshot == var_to_str([TableGenerator.CATALOGUE[3].rails, TableGenerator.MIDDLE_CATALOGUE[2].rails]), "Shaping preserves authored resources and their intentional interior geometry")
 var fallback := TableGenerator.generate(1, TableGenerator.Difficulty.NORMAL, [], [])
 check(fallback.valid and fallback.used_fallback and not fallback.preference_available and ConnectorTransitions.normal_flow_issues(flow_transition(fallback)).is_empty(), "Exhausted Normal catalogue reports an aligned easier fallback without a hidden ceiling")
 var partial := {"junction_styles": ["Bank", "Step"], "junction_paths": [[], []]}
 var shallow := {"junction_styles": ["Bank"], "junction_paths": [[PackedVector2Array([Vector2.ZERO, Vector2(300, 320)])]]}
 check(not ConnectorTransitions.normal_flow_issues(partial).is_empty() and not ConnectorTransitions.normal_flow_issues(shallow).is_empty(), "A partially reshaped course or overly shallow bank is excluded by flow policy, separately from validity")
 for seed_value: int in [18, 23]:
  var layout := TableGenerator.generate(seed_value, TableGenerator.Difficulty.NORMAL)
  var bank := narrowing_bank(layout)
  check(not bank.is_empty(), "Representative layout has a narrowing bank for a real upward shot: %d" % seed_value)
  build_passive_fixture(layout.chunks, layout.junctions)
  var upward := await observe_contact(bank.center, Vector2(0, -800))
  print("UPWARD FLOW | ", seed_value, " | ", upward)
  check(upward.contact and upward.outgoing.y < -100 and upward.outgoing.x * bank.side < -100 and upward.position.y < upward.start.y - 60 and upward.peak_speed <= 800.1 and upward.bumper_hits == 0, "Generated bank redirects a vertical shot inward/upward without adding speed: %d" % seed_value)
  var miss := await observe_contact(bank.center, Vector2(bank.side * 700.0, -180.0))
  print("MISSED APPROACH | ", seed_value, " | ", miss)
  check(miss.contact and miss.outgoing.y > 0 and miss.outgoing.x * bank.side < 0 and miss.peak_speed <= miss.incoming.length() + 0.1 and miss.bumper_hits == 0, "An oblique missed approach still rebounds downward through passive physics: %d" % seed_value)
  passive_tuning.effective.gravity_scale = 1.0
  var slow := await passive_shot(bank.center + bank.normal * 4.0, Vector2.ZERO, 240)
  check(slow.position.y > slow.start.y + 60 and slow.position.is_finite(), "A low-speed bank contact falls free instead of settling into a seam pocket: %d" % seed_value)
  fixture.free()
  var recovery := await missed_bank_recovery(seed_value)
  print("MISSED BANK RECOVERY | ", recovery)
  check(recovery.recovered, "A missed bank approach can recover above the join using ordinary timed flippers: %d" % seed_value)
 var output := FileAccess.open("res://test-results/normal-flow-report.json", FileAccess.WRITE)
 output.store_string(JSON.stringify(flow_report, " "))
 print("RESULT | Normal flow | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
