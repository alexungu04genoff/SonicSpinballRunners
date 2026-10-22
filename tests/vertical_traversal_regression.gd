extends SceneTree
## Focused three-section generation, real collision, controls and lifecycle checks.
var checks := 0
var failures := 0
var game: Node

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

func geometry_signature(layout: Dictionary) -> Array:
 var result: Array = []
 for chunk: ChunkData in layout.chunks:
  result.append(chunk.gameplay_descriptors())
  result.append(chunk.world_flippers())
 for junction: Dictionary in layout.junctions:
  result.append(junction.passage)
  result.append(junction.junction_rails)
 return result

func rebuild(seed_value: int, preference: int) -> void:
 paused = true
 game.request_generation(seed_value, preference)
 for i in 3:
  await process_frame
 paused = false
 await frames(4)

func geometry_aligned() -> bool:
 for chunk: TableChunk in game.chunks:
  for descriptor: Dictionary in chunk.descriptors:
   if descriptor.kind in ["circle", "triangle"] and descriptor.position.distance_to(descriptor.body.global_position) > 0.001:
    return false
 for i in game.flippers.size():
  var visual: Node3D = game.presentation.flipper_visuals[i]
  var tip := visual.to_global(Vector3(PlaygroundFlipper.LENGTH * TablePresentation.SCALE, 0, 0))
  if TablePresentation.unmap_point(tip).distance_to(game.flippers[i].tip()) > 0.01:
   return false
 return game.presentation.find_children("*", "CollisionObject3D", true, false).is_empty()

func run() -> void:
 var reproducible := true
 var valid_courses := true
 var tier_matches := true
 var middle_ids: Dictionary = {}
 var tier_scores: Array[float] = [0.0, 0.0, 0.0]
 for preference in 3:
  for seed_value: int in [1, 2, 7, 19]:
   var a := TableGenerator.generate(seed_value, preference)
   var b := TableGenerator.generate(seed_value, preference)
   reproducible = reproducible and a.signature == b.signature and a.difficulty_estimate == b.difficulty_estimate and geometry_signature(a) == geometry_signature(b)
   valid_courses = valid_courses and a.valid and not a.used_fallback and a.chunks.size() == 3 and a.junctions.size() == 2 and a.bounds == Rect2(0, 0, 800, 2100)
   for i in 3:
    valid_courses = valid_courses and a.chunks[i].grid_position.y == i * 7
   tier_matches = tier_matches and a.preference_available and a.difficulty_estimate.band == preference
   tier_scores[preference] += a.difficulty_estimate.score
   middle_ids[a.chunks[1].chunk_id] = true
   print("VERTICAL SAMPLE | ", a.signature)
 check(reproducible, "Four seeds in each tier reproduce all three chunks, flippers and both junctions")
 check(valid_courses, "Sampled courses contain three valid ordered sections and two connections within 800 × 2100 bounds")
 check(tier_matches and tier_scores[0] < tier_scores[1] and tier_scores[1] < tier_scores[2], "Difficulty selection remains meaningful for the whole course")
 check(middle_ids.size() == TableGenerator.MIDDLE_CATALOGUE.size(), "Samples include every reusable middle-section design", str(middle_ids.keys()))
 var missing: Array[ChunkData] = []
 var fallback := TableGenerator.generate(1, TableGenerator.Difficulty.HARD, missing, missing)
 check(fallback.valid and fallback.used_fallback and fallback.chunks.size() == 3 and not fallback.preference_available, "An exhausted catalogue produces an explicit valid three-section fallback")

 game = load("res://scenes/playground.tscn").instantiate()
 root.add_child(game)
 await frames(6)
 game.controls.virtual_enabled = true
 check(game.chunks.size() == 3 and game.flippers.size() == 4 and game.ball.serve_position.y > 1400, "Runtime creates a bottom serve and two pairs of flippers")
 var middle_positions := PackedVector2Array()
 for i in [2, 3]:
  middle_positions.append(game.flippers[i].position)
 check(middle_positions[0].y > 700 and middle_positions[0].y < 1400 and middle_positions[1].y > 700 and middle_positions[1].y < 1400, "Experimental recovery paddles lie inside the middle section")
 game.controls.virtual_left = true
 game.controls.virtual_right = true
 await frames(15)
 var all_held := true
 for flipper: PlaygroundFlipper in game.flippers:
  all_held = all_held and flipper.held and is_equal_approx(flipper.rotation, flipper.active_angle())
 check(all_held, "Both input actions operate all four flippers simultaneously")
 check(geometry_aligned(), "All translated bumper and moving paddle visuals match collision geometry, with no 3D collisions")
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 await frames(20)

 game.set_physics_process(false)
 game.tuning.effective.gravity_scale = 0.0
 game.tuning.effective.rolling_acceleration = 0.0
 game.tuning.effective.rolling_drag = 0.0
 for preference in 3:
  await rebuild(1, preference)
  var seamless := true
  var closures_solid := true
  for junction: Dictionary in game.layout.junctions:
   var passage: Rect2 = junction.passage
   var seam_y := passage.get_center().y
   for x: float in [passage.position.x + 5, passage.get_center().x, passage.end.x - 5]:
    for direction: float in [-1.0, 1.0]:
     game.ball.teleport_to(Vector2(x, seam_y - direction * 40), Vector2(0, direction * 1200))
     await frames(9)
     seamless = seamless and (game.ball.position.y - seam_y) * direction > 25 and absf(game.ball.linear_velocity.y - direction * 1200) < 3
   for rail: Dictionary in junction.junction_rails:
    game.ball.teleport_to(Vector2((rail.a.x + rail.b.x) * 0.5, seam_y + 80), Vector2(0, -8000))
    await frames(3)
    closures_solid = closures_solid and game.ball.position.y > seam_y + 15 and game.ball.linear_velocity.y > 0
  check(seamless, "Both joins pass upward/downward 1200 px/s shots across three lanes", game.layout.signature)
  check(closures_solid, "Both joins retain solid closure rails at 8000 px/s", game.layout.signature)

 game.tuning.select_profile(0)
 game.set_physics_process(true)
 game.reset_ball(false)
 await frames(3)
 game.launch_ball()
 await frames(8)
 var frozen_position: Vector2 = game.ball.position
 var frozen_velocity: Vector2 = game.ball.linear_velocity
 paused = true
 for i in 5:
  await process_frame
 check(game.ball.position == frozen_position and game.ball.linear_velocity == frozen_velocity, "Pause freezes a launched ball on the tall table")
 paused = false
 game.reset_ball(false)
 await frames(3)
 check(game.ball.serve_pending and game.ball.position.is_equal_approx(game.ball.serve_position) and game.ball.linear_velocity.is_zero_approx(), "Reset returns to the bottom serve, with no middle checkpoint")

 game.ball.teleport_to(Vector2(game.layout.bounds.get_center().x, game.layout.bounds.end.y + 60), Vector2(0, 300))
 await frames(4)
 check(game.respawn_time > 0, "Leaving the bottom course boundary triggers the drain")
 await frames(81)
 check(game.ball.serve_pending and game.ball.position.distance_to(game.ball.serve_position) < 1, "Automatic respawn returns to the bottom deck", "position=%s serve=%s waiting=%s drain=%.3f launch=%.3f" % [game.ball.position, game.ball.serve_position, game.ball.serve_pending, game.respawn_time, game.auto_launch_time])
 game.reset_ball(false)
 await frames(3)
 game.ring_field.reset_rings()
 game.ball.serve_pending = false
 game.ball.position = game.ring_field.rings[0].position
 game.ring_field.previous_ball_position = game.ball.position
 game.ring_field._physics_process(1.0 / 120.0)
 game.ball.serve_pending = true
 var old_presentation: Node = game.presentation
 var old_chunks: Array = game.chunks.duplicate()
 var old_flippers: Array = game.flippers.duplicate()
 var old_visual: Node = game.presentation.ring_visuals[0]
 game.tuning.select_profile(1)
 game.tuning.set_value("steering_strength", 0.14)
 game.tuning.modifier_enabled = true
 game.tuning.rebuild()
 game.presentation.set_camera_value("look_ahead", 165.0)
 game.presentation.set_camera_follow(false)
 game.presentation.physics_overlay.visible = true
 game.presentation.chunk_overlay.visible = true
 game.presentation.connector_overlay.visible = true
 paused = true
 check(game.request_generation(7, TableGenerator.Difficulty.HARD), "Paused regeneration accepts the new course")
 for i in 3:
  await process_frame
 var stale_freed := not is_instance_valid(old_presentation) and not is_instance_valid(old_visual)
 for old in [old_chunks[0], old_chunks[1], old_flippers[2], old_flippers[3]]:
  stale_freed = stale_freed and not is_instance_valid(old)
 check(stale_freed and game.flippers.size() == 4 and game.chunks.size() == 3 and game.chunks[2] == old_chunks[2] and game.flippers[0] == old_flippers[0] and game.flippers[1] == old_flippers[1], "Regeneration frees generated chunks, middle paddles and pickup visuals while preserving the launch deck")
 check(paused and game.ball.serve_pending and game.presentation.ring_pickups.is_empty() and game.ring_field.pickup_claimed.get_connections().size() == 1, "Regeneration preserves pause and leaves no stale pickup flight or duplicate listener")
 check(game.tuning.modifier_enabled and is_equal_approx(game.tuning.effective.steering_strength, 0.14) and is_equal_approx(game.tuning.effective.gravity_scale, 0.58), "Regeneration preserves Floaty, modifier and live steering override")
 check(not game.presentation.camera_follow_enabled and is_equal_approx(game.presentation.camera_settings.look_ahead, 165.0) and game.presentation.physics_overlay.visible and game.presentation.chunk_overlay.visible and game.presentation.connector_overlay.visible, "Regeneration preserves camera tuning, follow preference and overlays")
 check(game.score == 0 and game.rings_collected == 0 and game.special_meter == 0 and game.respawn_time < 0 and game.auto_launch_time < 0 and game.ring_reset_time < 0, "Regeneration clears run counters and delayed events")
 paused = false
 game.queue_free()
 await frames(3)
 print("RESULT | Vertical traversal | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
