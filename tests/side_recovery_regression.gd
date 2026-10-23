extends "res://tests/grid_chunk_regression.gd"
## Side clearance, rounded Easy routes and actual short-paddle upper recovery.

func upper_trial(source: ChunkData, mirrored: bool) -> Dictionary:
 var fixture := Node2D.new()
 root.add_child(fixture)
 var tuning := PhysicsTuning.new()
 fixture.add_child(tuning)
 var controls := PlaygroundInput.new()
 controls.virtual_enabled = true
 fixture.add_child(controls)
 var chunk := TableChunk.new()
 chunk.data = source.duplicate(true)
 chunk.data.mirrored = mirrored
 fixture.add_child(chunk)
 chunk.build()
 chunk.wall_material.bounce = tuning.effective.wall_restitution
 var placement: Dictionary = chunk.data.world_flippers()[0]
 var ball := PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 var paddle := PlaygroundFlipper.new()
 paddle.position = placement.position
 paddle.side = placement.side
 paddle.length = placement.length
 paddle.tuning = tuning
 paddle.controls = controls
 paddle.ball = ball
 fixture.add_child(paddle)
 var start: Vector2 = paddle.position + Vector2.RIGHT.rotated(paddle.rest_angle()) * paddle.length * 0.65 + Vector2(0, -65)
 ball.position = start
 fixture.add_child(ball)
 ball.teleport_to(start, Vector2(0, 180))
 var pressed := -1
 var minimum_y := start.y
 var finite := true
 for tick in 240:
  var near := Geometry2D.get_closest_point_to_segment(ball.position, paddle.position, paddle.tip())
  if pressed < 0 and ball.linear_velocity.y > 0 and near.distance_to(ball.position) < 43:
   pressed = tick
  controls.virtual_left = pressed >= 0 and tick - pressed < 15 and paddle.side > 0
  controls.virtual_right = pressed >= 0 and tick - pressed < 15 and paddle.side < 0
  await frames(1)
  minimum_y = minf(minimum_y, ball.position.y)
  finite = finite and ball.position.is_finite() and ball.linear_velocity.is_finite()
  if minimum_y < paddle.position.y - 150 or ball.position.y > paddle.position.y + 150:
   break
 var result := {"chunk": source.chunk_id, "mirror": mirrored, "strikes": paddle.strikes, "rise": paddle.position.y - minimum_y, "finite": finite}
 fixture.free()
 await frames(3)
 return result

func run() -> void:
 var source_clear := true
 var upper_clear := true
 for chunk: ChunkData in TableGenerator.MIDDLE_CATALOGUE:
  source_clear = source_clear and flippers_clear(chunk)
 for source: ChunkData in TableGenerator.CATALOGUE + [TableGenerator.FALLBACK]:
  upper_clear = upper_clear and source.world_flippers().size() == 1 and source.flipper_placements[0].length in [70.0, 85.0]
  for mirror: bool in [false, true]:
   var chunk: ChunkData = source.duplicate(true)
   chunk.mirrored = mirror
   upper_clear = upper_clear and flippers_clear(chunk)
 check(source_clear, "Every revised middle paddle retains full ball passage through its complete swing")
 check(upper_clear, "Every upper design and fallback has one 70–85 px paddle with clear mirrored swings")
 var host = load("res://scripts/game.gd").new()
 var easy_valid := true
 var smooth := true
 var deterministic := true
 var grid_clear := true
 for mode in [1, 2]:
  var compilation := GridChunkCompiler.compile(host.GRID_EASY_RECIPES[mode - 1])
  grid_clear = grid_clear and compilation.valid
  for seed_value in range(1, 13):
   var layout: Dictionary = host._generate_layout(seed_value, TableGenerator.Difficulty.EASY, mode)
   var repeated: Dictionary = host._generate_layout(seed_value, TableGenerator.Difficulty.EASY, mode)
   easy_valid = easy_valid and layout.valid and layout.preference_available and layout.difficulty_estimate.band == TableGenerator.Difficulty.EASY
   deterministic = deterministic and geometry_hash(layout) == geometry_hash(repeated)
   for junction: Dictionary in layout.junctions:
    smooth = smooth and junction.junction_rails.is_empty() and junction.transition_style in [ConnectorTransitions.ALIGNED, ConnectorTransitions.CURVE]
   var middle: ChunkData = layout.chunks[1]
   grid_clear = grid_clear and flippers_clear(middle)
   for rail: PackedVector2Array in middle.rails:
    for i in range(1, rail.size() - 1):
     var before := rail[i] - rail[i - 1]
     var after := rail[i + 1] - rail[i]
     smooth = smooth and absf(before.angle_to(after)) <= deg_to_rad(20.0)
   for placement: Dictionary in middle.flipper_placements:
    var wall_x := 50.0 if placement.side > 0 else 750.0
    grid_clear = grid_clear and is_equal_approx(absf(placement.position.x - wall_x), 75.0)
 check(easy_valid and deterministic, "24 seeded Easy grid builds remain deterministic and in tier")
 check(smooth, "Easy grid banks turn at most 20 degrees per facet and both junctions have no horizontal steps")
 check(grid_clear, "Grid side pivots sit 75 px from authored walls without reducing swing safety margins")
 host.free()
 var recovered := true
 for source: ChunkData in TableGenerator.CATALOGUE + [TableGenerator.FALLBACK]:
  for mirror: bool in [false, true]:
   var result := await upper_trial(source, mirror)
   print("UPPER RECOVERY | ", result)
   recovered = recovered and result.finite and result.strikes == 1 and result.rise >= 150.0
 check(recovered, "All nine upper designs recover at least 150 px through one actual short-flipper strike in both mirrors")
 # Real game rebuilds must create exactly one top paddle and remove its old body.
 await create_game(1, TableGenerator.Difficulty.NORMAL)
 var old_top: PlaygroundFlipper = game.flippers.back()
 check(game.flippers.size() == 5 and old_top.length <= 85 and old_top.position.y < 700, "Runtime adds the upper paddle with the existing input/physics path")
 game.request_generation(2, TableGenerator.Difficulty.EASY, 2)
 await frames(8)
 check(not is_instance_valid(old_top) and game.flippers.size() == 5 and game.presentation.flipper_visuals.size() == 5, "Regeneration replaces top and middle paddles and builds matching collisionless visuals")
 await remove_game()
 for mode in [1, 2]:
  game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
  game.generation_difficulty = TableGenerator.Difficulty.EASY
  game.generation_grid_mode = 0
  game.generation_seed = 8
  root.add_child(game)
  await frames(12)
  game.layout_buttons[mode + 1].pressed.emit()
  await frames(8)
  check(game.generation_seed == 8 and game.generation_difficulty == TableGenerator.Difficulty.EASY and game.generation_grid_mode == mode and game.status_label.text.contains("Easy"), "Green Hill grid shortcut preserves Easy and seed, and displays the active difficulty: %d" % mode)
  if DisplayServer.get_name() == "headless":
   game.free()
   await frames(3)
   continue
  game.presentation.set_camera_follow(false)
  await create_timer(0.3).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/side-recovery-green-hill-%d.png" % mode)
  game.presentation.physics_overlay.visible = true
  game.presentation.set_camera_follow(true)
  game.presentation.reset_camera(Vector2(400, 1050))
  game.presentation.set_process(false)
  await create_timer(0.2).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/side-recovery-grid-close-%d.png" % mode)
  game.free()
  await frames(3)
 print("RESULT | Side recovery | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
