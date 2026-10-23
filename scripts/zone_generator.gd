class_name ZoneGenerator
extends RefCounted
## One connected Easy course. Chunk indices run from the final cap to the launch deck;
## acts run in the opposite direction, in the order the player completes them.
const VERSION := 1
const CHUNK_COUNT := 9
const CHUNKS_PER_ACT := 3
const EASY_TOPS: Array[ChunkData] = [TableGenerator.CATALOGUE[4], TableGenerator.CATALOGUE[5]]
const EASY_RELAYS: Array[ChunkData] = [TableGenerator.MIDDLE_CATALOGUE[0], TableGenerator.MIDDLE_CATALOGUE[1]]
const EASY_GRID: Array[GridChunkRecipe] = [
 preload("res://data/grid_chunks/flow_relay_easy.tres"),
 preload("res://data/grid_chunks/flow_relay_easy_variant.tres"),
]

static func generate(seed_value: int, grid_mode: int = 0) -> Dictionary:
 grid_mode = clampi(grid_mode, 0, EASY_GRID.size())
 var sources: Array[ChunkData] = EASY_RELAYS.duplicate()
 for recipe: GridChunkRecipe in EASY_GRID:
  var compiled := GridChunkCompiler.compile(recipe)
  if not compiled.valid:
   return {"valid": false, "errors": compiled.errors}
  sources.append(compiled.chunk)
 if grid_mode in [1, 2]:
  sources = [sources[grid_mode + 1]]
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value
 var chunks: Array[ChunkData] = []
 for index in CHUNK_COUNT:
  var source: ChunkData
  if index == 0:
   source = EASY_TOPS[rng.randi_range(0, EASY_TOPS.size() - 1)]
  elif index == CHUNK_COUNT - 1:
   source = TableGenerator.LOWER
  else:
   source = sources[rng.randi_range(0, sources.size() - 1)]
  var chunk: ChunkData = source.duplicate(true)
  chunk.grid_position = Vector2i(0, index * 7)
  chunk.mirrored = rng.randi_range(0, 1) == 1 if index < CHUNK_COUNT - 1 else false
  chunk.horizontal_shift_cells = 0
  chunks.append(chunk)
 # The 50px kit and legacy 55px wall insets meet through the same short,
 # shallow Easy collars. No intermediate chunk has a roof or a launch funnel.
 var transition := ConnectorTransitions.reshape(chunks, ConnectorTransitions.CURVE, 100.0)
 var issues := ConnectorTransitions.normal_flow_issues(transition)
 if not issues.is_empty():
  return {"valid": false, "errors": issues}
 var validation := TableGenerator.validate_course(transition.chunks)
 if not validation.valid:
  return {"valid": false, "errors": validation.errors}
 var candidate := {
  "chunks": transition.chunks, "transition": transition, "validation": validation,
  "estimate": TableGenerator._course_estimate(transition.chunks, {}, transition),
 }
 if candidate.estimate.band != TableGenerator.Difficulty.EASY:
  return {"valid": false, "errors": PackedStringArray(["Zone layout exceeded Easy geometry limits"])}
 var layout := TableGenerator._course_layout(seed_value, TableGenerator.Difficulty.EASY, candidate, false, PackedStringArray(), ConnectorTransitions.CURVE)
 layout.zone_version = VERSION
 layout.grid_mode = grid_mode
 layout.construction_mode = grid_mode
 layout.construction_version = GridPieceKit.VERSION
 layout.selection_note = "Green Hill Zone: three Easy Acts, nine connected sections."
 layout.signature = "zone-v%d grid=%d %s" % [VERSION, grid_mode, layout.signature]
 var acts: Array[Dictionary] = []
 for act_index in 3:
  var first := CHUNK_COUNT - (act_index + 1) * CHUNKS_PER_ACT
  var indices: Array[int] = [first, first + 1, first + 2]
  var act_chunks: Array[ChunkData] = []
  for index: int in indices:
   act_chunks.append(layout.chunks[index])
  var bottom: ChunkData = act_chunks.back()
  var entry := bottom.world_point(bottom.markers.serve) if act_index == 0 else _checkpoint(bottom)
  if not entry.is_finite():
   return {"valid": false, "errors": PackedStringArray(["No clear checkpoint for Act %d" % (act_index + 1)])}
  var top: ChunkData = act_chunks.front()
  var exit := top.world_rect(top.top_connection)
  acts.append({
   "bounds": TableGenerator.course_bounds(act_chunks), "chunk_indices": indices, "entry": entry,
   "exit_y": exit.position.y if act_index < 2 else INF,
   "exit_left": exit.position.x if act_index < 2 else INF,
   "exit_right": exit.end.x if act_index < 2 else INF,
   "goal_position": ScoreAttack.find_goal(layout) if act_index == 2 else Vector2.INF,
  })
 if not acts[2].goal_position.is_finite():
  return {"valid": false, "errors": PackedStringArray(["No clear Zone portal anchor"])}
 layout.acts = acts
 return layout

static func _checkpoint(chunk: ChunkData) -> Vector2:
 # Use the transformed entry route, inset from the previous Act boundary so a
 # returning ball has room above its one-way floor and every flipper sweep.
 var authored: Vector2 = chunk.markers.get("entry", Vector2.INF)
 var geometry := chunk.gameplay_descriptors()
 for inset: float in [70.0, 100.0, 140.0]:
  var local := authored - Vector2(0, inset)
  var point := chunk.world_point(local)
  if Geometry2D.is_point_in_polygon(local, chunk.playfield_outline) and TableGenerator.point_clear(point, geometry, 50.0):
   var safe := true
   for paddle: Dictionary in chunk.world_flippers():
    if point.distance_to(paddle.position) < float(paddle.length) + PlaygroundFlipper.RADIUS + PlaygroundBall.RADIUS + 20.0:
     safe = false
     break
   if safe:
    return point
 return Vector2.INF
