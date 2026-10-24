extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("_run")

func expect(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error(message)

func _run() -> void:
 var directory := DirAccess.open("res://data/grid_chunks")
 for filename: String in directory.get_files():
  if not filename.begins_with("zone_") or not filename.ends_with(".tres"):
   continue
  var recipe: GridChunkRecipe = load("res://data/grid_chunks/" + filename)
  var compiled := GridChunkCompiler.compile(recipe)
  expect(compiled.valid, "%s: %s" % [recipe.recipe_id, "; ".join(compiled.errors)])
 var mounted: GridChunkRecipe = load("res://data/grid_chunks/zone_wall_garden.tres")
 var misplaced: GridChunkRecipe = mounted.duplicate(true)
 misplaced.placements[2].cell = Vector2i(2, 4)
 expect(not GridChunkCompiler.compile(misplaced).valid, "A mounted bumper offset from its named wall is rejected")
 var free_standing: GridChunkRecipe = mounted.duplicate(true)
 free_standing.placements[2].piece = "bumper"
 expect(not GridChunkCompiler.compile(free_standing).valid, "Ordinary free-standing bumpers still require passage behind them")
 var sling: GridChunkRecipe = load("res://data/grid_chunks/zone_sling_alley.tres")
 var bad_sling: GridChunkRecipe = sling.duplicate(true)
 bad_sling.placements[2].cell = Vector2i(2, 6)
 expect(not GridChunkCompiler.compile(bad_sling).valid, "Sling rear edge must be flush with its named boundary")
 var compiled_sling := GridChunkCompiler.compile(sling)
 var transformed: ChunkData = compiled_sling.chunk.duplicate(true)
 transformed.mirrored = true
 transformed.grid_position = Vector2i(0, 21)
 var triangle: Dictionary = transformed.gameplay_descriptors().filter(func(item: Dictionary) -> bool: return item.kind == "triangle")[0]
 expect(triangle.position == Vector2(750, 2400) and triangle.points[1] == Vector2(-70, 0), "Mounted triangle descriptor mirrors and translates with its authoritative collider")
 expect(not ZoneGenerator.generate(18, 0, 3).valid, "Unknown development difficulty fails explicitly")
 var signatures: Dictionary = {}
 for tier in 3:
  var layout := ZoneGenerator.generate(19 if tier == 2 else 18, 0, tier)
  expect(layout.valid, "Tier %d: %s / %s" % [tier, layout.get("errors", []), layout.get("rejected", [])])
  if layout.valid:
   expect(layout.difficulty_estimate.band == tier and layout.preference_available and not layout.used_fallback, "Development layout genuinely matches tier %d" % tier)
   signatures[layout.signature] = true
   print("LAYOUT | ", layout.signature)
 expect(signatures.size() == 3, "Difficulty override selects different physical geometry in every tier")
 await contact_fixture(mounted, Vector2(200, 200), Vector2(-700, 0), "Wall-mounted circular bumper produces a real hit and rebound")
 await contact_fixture(load("res://data/grid_chunks/zone_bank_return.tres"), Vector2(180, 250), Vector2(-700, 0), "Rounded-bank apex bumper produces a real hit and rebound")
 await contact_fixture(sling, Vector2(250, 300), Vector2(-700, 0), "Wall-mounted triangular sling produces a real hit and rebound")
 print("RESULT | Playfield catalogue | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func contact_fixture(recipe: GridChunkRecipe, start: Vector2, velocity: Vector2, message: String) -> void:
 var fixture := Node2D.new()
 root.add_child(fixture)
 var tuning := PhysicsTuning.new()
 fixture.add_child(tuning)
 tuning.effective.gravity_scale = 0.0
 tuning.effective.rolling_acceleration = 0.0
 tuning.effective.rolling_drag = 0.0
 var controls := PlaygroundInput.new()
 controls.virtual_enabled = true
 fixture.add_child(controls)
 var chunk := TableChunk.new()
 chunk.data = GridChunkCompiler.compile(recipe).chunk
 chunk.data.grid_position = Vector2i.ZERO
 fixture.add_child(chunk)
 chunk.build()
 var ball := PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 ball.position = start
 fixture.add_child(ball)
 ball.teleport_to(start, velocity)
 var rebounded := false
 for tick in 45:
  await physics_frame
  rebounded = rebounded or ball.linear_velocity.x > 100.0
 expect(ball.bumper_hit_count > 0 and rebounded, message)
 fixture.free()
 await physics_frame
