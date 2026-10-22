extends SceneTree
## Deterministic contract checks plus real 2D seam shots. No external test framework.
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String, detail: String = "") -> void:
 checks += 1
 if condition:
  print("PASS | ", label, " | ", detail)
 else:
  failures += 1
  push_error("FAIL | " + label + " | " + detail)

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func run() -> void:
 var variants_valid := true
 var variant_scores: Array[float] = []
 var variant_count := 0
 for source: ChunkData in TableGenerator.CATALOGUE:
  for mirrored: bool in [false, true]:
   for shift: int in TableGenerator.allowed_shifts(source):
    var chunk: ChunkData = source.duplicate(true)
    chunk.mirrored = mirrored
    chunk.horizontal_shift_cells = shift
    variant_count += 1
    var validation := TableGenerator.validate(chunk, TableGenerator.LOWER)
    variant_scores.append(TableGenerator.estimate_difficulty(chunk, TableGenerator.LOWER).score)
    if not validation.valid:
     variants_valid = false
     print("INVALID VARIANT | ", chunk.chunk_id, " | ", mirrored, " | ", shift, " | ", validation.errors)
 check(variants_valid, "Every permitted catalogue / mirror / shift combination passes clearance validation", "%d variants" % variant_count)
 check(TableGenerator.allowed_shifts(TableGenerator.FALLBACK) == [0] and TableGenerator.allowed_shifts(TableGenerator.CATALOGUE[0]) == [0, 1], "Eight-cell chunks remain aligned while seven-cell chunks retain both legal shifts")
 var representatives: Dictionary = {}
 var deterministic := true
 var no_fallback := true
 var preference_respected := true
 var variety_preserved := true
 var easy_ledges_small := true
 var score_totals: Array[float] = [0.0, 0.0, 0.0]
 var clearance_totals: Array[float] = [0.0, 0.0, 0.0]
 var ledge_totals: Array[float] = [0.0, 0.0, 0.0]
 for preference in 3:
  var tier_ids: Dictionary = {}
  for seed_value in range(1, 25):
   var a := TableGenerator.generate_pair(seed_value, preference)
   var b := TableGenerator.generate_pair(seed_value, preference)
   deterministic = deterministic and a.signature == b.signature and a.difficulty_preference == preference and a.difficulty_estimate == b.difficulty_estimate and a.junction_rails == b.junction_rails and a.upper.gameplay_descriptors() == b.upper.gameplay_descriptors()
   no_fallback = no_fallback and not a.used_fallback
   tier_ids[a.upper.chunk_id] = true
   score_totals[preference] += float(a.difficulty_estimate.score)
   clearance_totals[preference] += float(a.difficulty_estimate.clear_width)
   ledge_totals[preference] += float(a.difficulty_estimate.largest_ledge)
   preference_respected = preference_respected and a.preference_available and a.difficulty_estimate.band == preference
   if preference == TableGenerator.Difficulty.EASY:
    easy_ledges_small = easy_ledges_small and float(a.difficulty_estimate.largest_ledge) <= 56.0
   if not representatives.has(a.upper.chunk_id):
    representatives[a.upper.chunk_id] = {"seed": seed_value, "preference": preference}
    print("SAMPLE | ", a.signature, " | clear join=", a.passage.size.x)
   if seed_value == 1:
    print("COMPARISON | ", a.signature)
  variety_preserved = variety_preserved and tier_ids.size() >= 2
  print("TIER VARIETY | ", TableGenerator.DIFFICULTY_NAMES[preference], " | ", tier_ids.keys())
 check(deterministic and no_fallback, "Seeds 1–24 at all three preferences reproduce geometry and estimates without fallback")
 check(preference_respected, "Every selected candidate belongs to the requested difficulty band")
 check(variety_preserved and representatives.size() == TableGenerator.CATALOGUE.size(), "Each tier samples at least two authored layouts and all catalogue entries appear")
 check(easy_ledges_small, "Easy layouts never contain a closure ledge larger than two ball diameters")
 check(score_totals[0] < score_totals[1] and score_totals[1] < score_totals[2], "Preference increases estimated difficulty across the same 24 seeds", "Means: %.1f / %.1f / %.1f" % [score_totals[0] / 24.0, score_totals[1] / 24.0, score_totals[2] / 24.0])
 check(clearance_totals[2] < clearance_totals[0] and ledge_totals[2] > ledge_totals[0], "Hard layouts have narrower joins and larger ledges than Easy layouts", "Mean clear widths %.0f / %.0f / %.0f px; ledges %.0f / %.0f / %.0f px" % [clearance_totals[0] / 24.0, clearance_totals[1] / 24.0, clearance_totals[2] / 24.0, ledge_totals[0] / 24.0, ledge_totals[1] / 24.0, ledge_totals[2] / 24.0])
 print("LIBRARY | score range %.1f–%.1f" % [variant_scores.min(), variant_scores.max()])
 var transformed: ChunkData = TableGenerator.CATALOGUE[1].duplicate(true)
 transformed.mirrored = true
 transformed.horizontal_shift_cells = 1
 check(transformed.world_rect(transformed.bottom_connection) == Rect2(155, 680, 540, 20), "Asymmetric connector mirrors and shifts in world coordinates")
 check(transformed.world_point(Vector2(105, 700)) == Vector2(695, 700), "Point transform matches reversed connector endpoint")
 var validation := TableGenerator.validate(transformed, TableGenerator.LOWER)
 check(validation.valid and validation.junction_rails.size() == 2 and validation.passage == Rect2(191, 655, 468, 90), "Partial openings generate two closures outside the safe passage")
 var estimate := TableGenerator.estimate_difficulty(transformed, TableGenerator.LOWER)
 check(is_equal_approx(estimate.score, TableGenerator.estimate_difficulty(TableGenerator.CATALOGUE[1], TableGenerator.LOWER).score), "Full-table reflection preserves the difficulty estimate")
 var more_offset: ChunkData = transformed.duplicate(true)
 more_offset.horizontal_shift_cells = 0
 var harder := TableGenerator.estimate_difficulty(more_offset, TableGenerator.LOWER)
 check(harder.connector_score > estimate.connector_score and harder.score >= estimate.score and harder.largest_ledge > estimate.largest_ledge and TableGenerator.validate(more_offset, TableGenerator.LOWER).valid, "Larger ledge and offset increase connector challenge without invalidating sharp geometry")
 var rated: ChunkData = TableGenerator.CATALOGUE[0].duplicate(true)
 var initial_geometry := rated.gameplay_descriptors()
 var base_estimate := TableGenerator.estimate_difficulty(rated, TableGenerator.LOWER)
 rated.estimated_difficulty = 95
 check(TableGenerator.estimate_difficulty(rated, TableGenerator.LOWER).score > base_estimate.score and rated.gameplay_descriptors() == initial_geometry and TableGenerator.validate(rated, TableGenerator.LOWER).valid, "Authored chunk rating changes selection score without changing colliders or validity")
 rated.estimated_difficulty = 0
 var severe_connector := TableGenerator.estimate_difficulty(rated, TableGenerator.LOWER)
 check(is_equal_approx(severe_connector.score, maxf(severe_connector.chunk_score, maxf(severe_connector.connector_score, severe_connector.approach_score))) and severe_connector.score >= severe_connector.connector_score, "Easy intrinsic rating cannot average away a more demanding connector or approach")
 rated = TableGenerator.CATALOGUE[0].duplicate(true)
 rated.bumpers.append({"kind": "circle", "position": Vector2(400, 600), "radius": 25.0})
 check(TableGenerator.estimate_difficulty(rated, TableGenerator.LOWER).approach_blocked > base_estimate.approach_blocked and TableGenerator.validate(rated, TableGenerator.LOWER).valid, "Nearby obstacle affects approach estimate while the critical passage remains valid")
 var hard_request := TableGenerator.generate_pair(1, TableGenerator.Difficulty.HARD)
 check(hard_request.preference_available and hard_request.difficulty_preference == TableGenerator.Difficulty.HARD and hard_request.difficulty_estimate.band == TableGenerator.Difficulty.HARD, "Default catalogue supplies actual Hard geometry")
 var missing_tier := TableGenerator.generate_pair(1, TableGenerator.Difficulty.HARD, [TableGenerator.CATALOGUE[0]])
 check(missing_tier.valid and not missing_tier.used_fallback and not missing_tier.preference_available and missing_tier.difficulty_estimate.band != TableGenerator.Difficulty.HARD and missing_tier.selection_note.contains("No valid Hard candidate; using"), "Missing requested tier explicitly reports the closest valid available band")
 var bad: ChunkData = transformed.duplicate(true)
 bad.horizontal_shift_cells = 2
 check(not TableGenerator.validate(bad, TableGenerator.LOWER).valid, "Out-of-bounds horizontal shift rejected")
 bad = transformed.duplicate(true)
 bad.grid_position.y = 1
 check(not TableGenerator.validate(bad, TableGenerator.LOWER).valid, "Vertically misaligned section rejected")
 bad = transformed.duplicate(true)
 bad.bottom_connection.size.x = 100
 check(not TableGenerator.validate(bad, TableGenerator.LOWER).valid, "Insufficient overlap rejected")
 bad = transformed.duplicate(true)
 var rail: PackedVector2Array = bad.rails[0].duplicate()
 rail[0] += Vector2(30, 0)
 bad.rails[0] = rail
 check(not TableGenerator.validate(bad, TableGenerator.LOWER).valid, "Gap between connector edge and rail endpoint rejected")
 bad = transformed.duplicate(true)
 bad.bumpers.append({"kind": "circle", "position": Vector2(350, 695), "radius": 35.0})
 check(not TableGenerator.validate(bad, TableGenerator.LOWER).valid, "Bumper blocking join rejected")
 bad = TableGenerator.CATALOGUE[0].duplicate(true)
 bad.rails.append(PackedVector2Array([Vector2(100, 220), Vector2(100, 480), Vector2(200, 480), Vector2(200, 220), Vector2(100, 220)]))
 check(not TableGenerator.validate(bad, TableGenerator.LOWER).valid, "Closed pocket containing a route probe rejected")
 var fallback := TableGenerator.generate_pair(9, TableGenerator.Difficulty.HARD, [bad])
 check(fallback.valid and fallback.used_fallback and fallback.upper.chunk_id == "classic_garden" and fallback.rejected.size() == 4, "Rejected candidates fall back to validated original layout")
 var valid_alternative := TableGenerator.generate_pair(9, TableGenerator.Difficulty.EASY, [bad, TableGenerator.CATALOGUE[0]])
 check(valid_alternative.upper.chunk_id == "bumper_garden" and TableGenerator.validate(valid_alternative.upper, TableGenerator.LOWER).valid and not valid_alternative.used_fallback, "Difficulty preference cannot select a trapped candidate over a valid alternative")
 check(not TableGenerator.CATALOGUE[1].mirrored and TableGenerator.CATALOGUE[1].horizontal_shift_cells == 0 and TableGenerator.CATALOGUE[0].rails.size() == 1, "Generation never mutates catalogue resources")
 for profile: PhysicsProfile in [PhysicsTuning.BALANCED, PhysicsTuning.FLOATY]:
  var matches := true
  for key: String in PhysicsTuning.STEERING_PRESETS[1].values:
   matches = matches and is_equal_approx(profile.as_values()[key], PhysicsTuning.STEERING_PRESETS[1].values[key])
  check(matches, profile.display_name + " starts with Quick / Tight")

 game = load("res://scenes/playground.tscn").instantiate()
 game.legacy_pair_fixture = true # Preserve v3 two-section geometry and shot fixtures.
 root.add_child(game)
 await frames(5)
 var lower_id: int = game.chunks[1].get_instance_id()
 var flipper_positions: Array[Vector2] = [game.flippers[0].position, game.flippers[1].position]
 game.controls.virtual_enabled = true
 game.tuning.effective.gravity_scale = 0.0
 game.launch_ball()
 await frames(5)
 var prior_signature: String = game.layout.signature
 check(not game.request_generation(2) and game.layout.signature == prior_signature, "Generation refused during live flight")
 paused = true
 game.request_generation(2)
 paused = false
 for i in 3:
  await process_frame
 check(not game.generation_pending and game.layout.signature == prior_signature, "Deferred generation cancels if live play resumes before the swap")
 paused = true
 game.score = 5000
 game.rings_collected = 12
 game.special_meter = 75
 game.ball_number = 8
 game.respawn_time = 0.3
 game.auto_launch_time = 0.5
 game.ring_reset_time = 0.5
 game.tuning.modifier_enabled = true
 game.tuning.set_value("wall_restitution", 0.63)
 game.presentation.physics_overlay.visible = true
 game.presentation.chunk_overlay.visible = true
 game.presentation.connector_overlay.visible = true
 check(game.request_generation(3), "Paused regeneration accepted")
 for i in 3:
  await process_frame
 check(paused and game.ball.serve_pending and game.ball.position == game.ball.serve_position and game.ball.linear_velocity.is_zero_approx(), "Paused rebuild keeps pause and resets ball immediately")
 check(game.score == 0 and game.rings_collected == 0 and game.special_meter == 0 and game.ball_number == 1 and game.respawn_time < 0 and game.auto_launch_time < 0 and game.ring_reset_time < 0, "Generation clears run counters and pending timers")
 check(game.chunks[1].get_instance_id() == lower_id and game.flippers[0].position == flipper_positions[0] and game.flippers[1].position == flipper_positions[1], "Fixed lower deck and flippers survive regeneration")
 check(game.tuning.modifier_enabled and is_equal_approx(game.chunks[0].wall_material.bounce, 0.63) and game.presentation.physics_overlay.visible and game.presentation.chunk_overlay.visible and game.presentation.connector_overlay.visible, "Regeneration preserves tuning, modifier and overlays")
 prior_signature = game.layout.signature
 game.request_generation(game.generation_seed)
 for i in 3:
  await process_frame
 check(game.layout.signature == prior_signature and game.presentation.ring_visuals.size() == game.ring_field.rings.size(), "Repeating seed rebuilds same layout with matching ring visuals")
 paused = false
 game.set_physics_process(false)
 game.tuning.modifier_enabled = false
 game.tuning.select_profile(0)
 game.tuning.effective.gravity_scale = 0.0
 game.tuning.effective.rolling_acceleration = 0.0
 game.tuning.effective.rolling_drag = 0.0
 var simulated_tiers: Dictionary = {}
 for settings: Dictionary in representatives.values():
  paused = true
  game.request_generation(settings.seed, settings.preference)
  for i in 3:
   await process_frame
  paused = false
  await frames(4)
  var passage: Rect2 = game.layout.passage
  var seam_clear := true
  for x: float in [passage.position.x + 5, passage.get_center().x, passage.end.x - 5]:
   for direction: float in [-1.0, 1.0]:
    # Stay below the existing 1500 px/s downward limiter when checking no seam impulse.
    game.ball.teleport_to(Vector2(x, 700 - direction * 40), Vector2(0, direction * 1200))
    await frames(9)
    var crossed: bool = (game.ball.position.y - 700) * direction > 25 and absf(game.ball.linear_velocity.y - direction * 1200) < 3
    if not crossed:
     print("SEAM SHOT | x=", x, " direction=", direction, " position=", game.ball.position, " velocity=", game.ball.linear_velocity)
    seam_clear = seam_clear and crossed
  check(seam_clear, "Bidirectional seam shots across three lanes", game.layout.signature)
  var closures_solid := true
  for closure: Dictionary in game.layout.junction_rails:
   var x: float = (closure.a.x + closure.b.x) * 0.5
   game.ball.teleport_to(Vector2(x, 780), Vector2(0, -8000))
   await frames(3)
   closures_solid = closures_solid and game.ball.position.y > 715 and game.ball.linear_velocity.y > 0
  check(closures_solid, "Unused opening closures block 8000 px/s shots", game.layout.upper.chunk_id)
  var geometry_matches := true
  for descriptor: Dictionary in game.chunks[0].descriptors:
   if descriptor.kind in ["circle", "triangle"]:
    geometry_matches = geometry_matches and descriptor.position.distance_to(descriptor.body.global_position) < 0.001
   if descriptor.kind == "triangle":
    geometry_matches = geometry_matches and descriptor.points == descriptor.body.get_child(0).polygon
  check(geometry_matches, "Transformed bumper descriptors match actual 2D bodies", game.layout.upper.chunk_id)
  if simulated_tiers.has(settings.preference):
   continue
  simulated_tiers[settings.preference] = true
  # Brief deterministic play probes catch escapes and persistent stationary stalls.
  game.tuning.select_profile(0)
  game.set_physics_process(true)
  game.reset_ball(true)
  var escaped := false
  var stalled := 0
  var worst_stall := 0
  for tick in 960:
   game.controls.virtual_left = game.ball.position.y > 1130 and tick % 36 < 18
   game.controls.virtual_right = game.controls.virtual_left
   game.controls.virtual_steering = sin(float(tick) / 110.0) * 0.7
   await frames(1)
   escaped = escaped or game.ball.position.x < 20 or game.ball.position.x > 780 or game.ball.position.y < 10
   stalled = stalled + 1 if game.ball.linear_velocity.length() < 5 and not game.ball.serve_pending else 0
   worst_stall = maxi(worst_stall, stalled)
  check(not escaped and worst_stall < 240, "Eight-second simulated play has no side/top escape or two-second stationary stall", game.layout.upper.chunk_id)
  game.controls.virtual_left = false
  game.controls.virtual_right = false
  game.controls.virtual_steering = 0
  game.set_physics_process(false)
  game.tuning.effective.gravity_scale = 0.0
  game.tuning.effective.rolling_acceleration = 0.0
  game.tuning.effective.rolling_drag = 0.0
 game.queue_free()
 await frames(3)
 print("RESULT | Generation | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
