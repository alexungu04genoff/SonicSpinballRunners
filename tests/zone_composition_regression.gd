extends "res://tests/act_pinball_regression.gd"
## Composition is additional selection policy, never a replacement for clearance.
## Shot fixtures prescribe initial trajectories/scores; input surveys are separate.

func run() -> void:
 var samples: Dictionary = {}
 var signatures: Dictionary = {}
 for tier in [TableGenerator.Difficulty.NORMAL, TableGenerator.Difficulty.HARD]:
  for seed_value in ([18, 28, 41] if tier == TableGenerator.Difficulty.NORMAL else [18, 24, 41]):
   var layout := ZoneGenerator.generate(seed_value, 0, tier)
   check(layout.valid, "Tier %d seed %d builds a complete authored Zone: %s" % [tier, seed_value, layout.get("errors", [])])
   if not layout.valid:
    print("REJECTIONS | ", layout.get("rejected", []))
    continue
   check(layout.composition.valid and layout.composition.distinct_rooms == 5 and layout.composition.distinct_silhouettes >= 3, "Five distinct relay identities form varied room silhouettes")
   var proper_acts := true
   for act: Dictionary in layout.composition.acts:
    proper_acts = proper_acts and act.room_band == tier
    if tier == TableGenerator.Difficulty.HARD:
     proper_acts = proper_acts and maxi(act.interaction_metrics.narrow_rows, act.approach_metrics.narrow_rows) >= 2
   check(proper_acts, "Every Act has intended room difficulty; Hard also has measured interior precision lanes")
   var flowing := true
   for junction: Dictionary in layout.junctions:
    flowing = flowing and junction.junction_rails.is_empty() and ConnectorTransitions.maximum_grade(junction.transition_paths) <= ConnectorTransitions.NORMAL_MAX_GRADE + 0.0001
   check(flowing, "All eight joins flow without Step ceilings or weakened bank grades")
   print("COMPOSITION | ", layout.signature, " | ", layout.composition)
   signatures[layout.signature] = true
   if seed_value == (28 if tier == TableGenerator.Difficulty.NORMAL else 24):
    samples[tier] = layout
    var repeated := ZoneGenerator.generate(seed_value, 0, tier)
    check(repeated.valid and repeated.signature == layout.signature and repeated.acts == layout.acts and repeated.composition == layout.composition, "Same seed reproduces roles, transforms, geometry summary and checkpoints")
  for shuffle in [1, 2]:
   var alternative := ZoneGenerator.generate(28 if tier == TableGenerator.Difficulty.NORMAL else 24, shuffle, tier)
   check(alternative.valid and alternative.composition.valid and alternative.construction_mode == shuffle, "Layout shuffle %d retains full tier %d composition" % [shuffle, tier])
 check(signatures.size() == 6, "All six requested Zone examples have distinct assembled layouts")
 if samples.size() != 2:
  print("RESULT | Zone composition | %d checks | %d failures" % [checks, failures])
  quit(1)
  return
 var counterfeit: Array[ChunkData] = []
 for source: ChunkData in samples[TableGenerator.Difficulty.NORMAL].chunks:
  counterfeit.append(source.duplicate(true))
 counterfeit[0].estimated_difficulty = 90.0
 check(not ZoneGenerator.inspect_composition(counterfeit, TableGenerator.Difficulty.HARD).valid, "One severe cap/junction cannot promote otherwise Normal Acts to Hard")
 for index in [0, 1, 3, 4, 6, 7]:
  var room := counterfeit[index]
  room.estimated_difficulty = 70.0
  room.bumpers.clear()
  room.rails = [PackedVector2Array([Vector2(50, 0), Vector2(50, 700)]), PackedVector2Array([Vector2(750, 0), Vector2(750, 700)])]
  room.playfield_outline = PackedVector2Array([Vector2(50, 0), Vector2(50, 700), Vector2(750, 700), Vector2(750, 0)])
 var rejected := ZoneGenerator.inspect_composition(counterfeit, TableGenerator.Difficulty.HARD)
 check(not rejected.valid and " ".join(rejected.errors).contains("precision lane"), "High authored ratings alone cannot make broad empty rooms count as Hard")
 for tier in [TableGenerator.Difficulty.NORMAL, TableGenerator.Difficulty.HARD]:
  game = load("res://scenes/playground.tscn").instantiate()
  game.generation_seed = 28 if tier == TableGenerator.Difficulty.NORMAL else 24
  game.zone_enabled = true
  game.zone_difficulty_override = tier
  root.add_child(game)
  await frames(5)
  game.controls.virtual_enabled = true
  game.ring_field.set_physics_process(false)
  for act_index in 3:
   var first: int = game.zone.acts[act_index].chunk_indices[0]
   for seam_index in [first, first + 1]:
    game.reset_ball(false)
    await frames(4)
    var passage: Rect2 = game.layout.junctions[seam_index].passage
    var center := passage.get_center()
    await place_ball(center + Vector2(0, 75), Vector2(0, -1200))
    await frames(20)
    check(game.ball.position.y < center.y - 50 and game.ball.linear_velocity.y < 0.0, "Tier %d Act %d real upward shot passes internal join %d" % [tier, act_index + 1, seam_index + 1])
   await test_recovery(act_index, bottom_paddles(act_index)[act_index % 2])
   await test_drain(act_index)
   if act_index < 2:
    await enter_next_act(act_index)
  game.free()
  await frames(4)
 print("RESULT | Zone composition | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
