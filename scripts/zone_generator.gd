class_name ZoneGenerator
extends RefCounted
## One connected course. Chunk indices run from the final cap to the launch deck;
## acts run in the opposite direction, in the order the player completes them.
const VERSION := 2
const CHUNK_COUNT := 9
const CHUNKS_PER_ACT := 3
const EASY_TOPS: Array[ChunkData] = [TableGenerator.CATALOGUE[4], TableGenerator.CATALOGUE[5]]
const EASY_GRID: Array[GridChunkRecipe] = [
 preload("res://data/grid_chunks/zone_wall_garden.tres"),
 preload("res://data/grid_chunks/zone_sling_alley.tres"),
 preload("res://data/grid_chunks/zone_orbit_cluster.tres"),
 preload("res://data/grid_chunks/zone_bank_return.tres"),
 preload("res://data/grid_chunks/zone_staggered_steps.tres"),
 preload("res://data/grid_chunks/zone_winding_lane.tres"),
 preload("res://data/grid_chunks/zone_twin_banks.tres"),
 preload("res://data/grid_chunks/zone_crosscourt.tres"),
]
const NORMAL_GRID: Array[GridChunkRecipe] = [
 preload("res://data/grid_chunks/flow_relay.tres"),
 preload("res://data/grid_chunks/flow_relay_variant.tres"),
]
const HARD_GRID: Array[GridChunkRecipe] = [
 preload("res://data/grid_chunks/zone_target_gauntlet.tres"),
 preload("res://data/grid_chunks/zone_crossfire.tres"),
]
const MAX_ATTEMPTS := 48

static func generate(seed_value: int, grid_mode: int = 0, preference: int = TableGenerator.Difficulty.EASY) -> Dictionary:
 if preference < TableGenerator.Difficulty.EASY or preference > TableGenerator.Difficulty.HARD:
  return {"valid": false, "errors": PackedStringArray(["Unknown Zone difficulty; choose Easy, Normal or Hard"])}
 grid_mode = clampi(grid_mode, 0, 2)
 var sources: Array[ChunkData] = []
 var recipes: Array[GridChunkRecipe] = EASY_GRID if preference == TableGenerator.Difficulty.EASY else NORMAL_GRID
 if preference == TableGenerator.Difficulty.HARD:
  recipes = HARD_GRID
 for recipe: GridChunkRecipe in recipes:
  var compiled := GridChunkCompiler.compile(recipe)
  if not compiled.valid:
   return {"valid": false, "errors": compiled.errors}
  sources.append(compiled.chunk)
 if preference == TableGenerator.Difficulty.NORMAL:
  sources.append(TableGenerator.MIDDLE_CATALOGUE[2])
 var tops: Array[ChunkData] = EASY_TOPS
 if preference == TableGenerator.Difficulty.NORMAL:
  tops = [TableGenerator.CATALOGUE[1], TableGenerator.CATALOGUE[2], TableGenerator.CATALOGUE[3]]
 elif preference == TableGenerator.Difficulty.HARD:
  tops = [TableGenerator.CATALOGUE[6], TableGenerator.CATALOGUE[7]]
 var act_bottom: ChunkData = load("res://data/act_bottom.tres")
 if act_bottom == null:
  return {"valid": false, "errors": PackedStringArray(["Missing reusable Act launch deck"])}
 var rng := RandomNumberGenerator.new()
 # Both grid choices retain the complete authored library. Their stable shuffle
 # changes arrangement and transforms rather than repeating one recipe seven times.
 rng.seed = seed_value + grid_mode * 104729
 var rejected := PackedStringArray()
 for attempt in MAX_ATTEMPTS:
  var chunks: Array[ChunkData] = []
  var remaining: Array[ChunkData] = []
  var previous_id := ""
  var shift_side := rng.randi_range(0, 1)
  for index in CHUNK_COUNT:
   var source: ChunkData
   if index == 0:
    source = tops[rng.randi_range(0, tops.size() - 1)]
   elif index == CHUNK_COUNT - 1:
    source = TableGenerator.LOWER
   elif index in [2, 5]:
    source = act_bottom
   else:
    if remaining.is_empty():
     remaining = sources.duplicate()
    var choices: Array[int] = []
    for item in remaining.size():
     if remaining[item].chunk_id != previous_id:
      choices.append(item)
    var selected: int = choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else 0
    source = remaining[selected]
    remaining.remove_at(selected)
   previous_id = source.chunk_id
   var chunk: ChunkData = source.duplicate(true)
   chunk.grid_position = Vector2i(0, index * 7)
   chunk.mirrored = rng.randi_range(0, 1) == 1 if index < CHUNK_COUNT - 1 else false
   var shifts := TableGenerator.allowed_shifts(source)
   # Narrow sections share an alignment within this course, avoiding opposing
   # shifts that would squeeze a recovery paddle at their shared seam.
   chunk.horizontal_shift_cells = shifts[shift_side % shifts.size()]
   chunks.append(chunk)
  var style := ConnectorTransitions.CURVE if preference != TableGenerator.Difficulty.HARD else ConnectorTransitions.STEP
  var transition := ConnectorTransitions.reshape(chunks, style, 180.0 if preference == TableGenerator.Difficulty.EASY else ConnectorTransitions.COLLAR)
  if preference != TableGenerator.Difficulty.HARD:
   var issues := ConnectorTransitions.normal_flow_issues(transition)
   if not issues.is_empty():
    rejected.append(issues[0])
    continue
  var estimate := TableGenerator._course_estimate(transition.chunks, {}, transition)
  if estimate.band != preference:
   rejected.append("Candidate geometry is %s, requested %s" % [TableGenerator.DIFFICULTY_NAMES[estimate.band], TableGenerator.DIFFICULTY_NAMES[preference]])
   continue
  var validation := TableGenerator.validate_course(transition.chunks)
  if not validation.valid:
   rejected.append(validation.errors[0])
   continue
  var candidate := {"chunks": transition.chunks, "transition": transition, "validation": validation, "estimate": estimate}
  var layout := TableGenerator._course_layout(seed_value, preference, candidate, false, rejected, style)
  return _with_acts(layout, grid_mode, preference)
 return {"valid": false, "errors": PackedStringArray(["No valid nine-chunk %s Zone found after %d authored combinations; no difficulty fallback was used" % [TableGenerator.DIFFICULTY_NAMES[preference], MAX_ATTEMPTS]]), "rejected": rejected}

static func _with_acts(layout: Dictionary, grid_mode: int, preference: int) -> Dictionary:
 layout.zone_version = VERSION
 layout.grid_mode = grid_mode
 layout.construction_mode = grid_mode
 layout.construction_version = GridPieceKit.VERSION
 layout.selection_note = "Green Hill Zone: three %s Acts, nine connected sections." % TableGenerator.DIFFICULTY_NAMES[preference]
 layout.signature = "zone-v%d grid=%d %s" % [VERSION, grid_mode, layout.signature]
 var acts: Array[Dictionary] = []
 for act_index in 3:
  var first := CHUNK_COUNT - (act_index + 1) * CHUNKS_PER_ACT
  var indices: Array[int] = [first, first + 1, first + 2]
  var act_chunks: Array[ChunkData] = []
  for index: int in indices:
   act_chunks.append(layout.chunks[index])
  var bottom: ChunkData = act_chunks.back()
  var entry := bottom.world_point(bottom.markers.serve)
  if not entry.is_finite():
   return {"valid": false, "errors": PackedStringArray(["No clear checkpoint for Act %d" % (act_index + 1)])}
  var top: ChunkData = act_chunks.front()
  var exit := top.world_rect(top.top_connection)
  acts.append({
   "bounds": TableGenerator.course_bounds(act_chunks), "chunk_indices": indices, "entry": entry,
   "entry_clear": bottom.world_point(bottom.markers.get("entry_clear", bottom.markers.serve)),
   "drain": bottom.world_point(bottom.markers.drain),
   "exit_y": exit.position.y if act_index < 2 else INF,
   "exit_left": exit.position.x if act_index < 2 else INF,
   "exit_right": exit.end.x if act_index < 2 else INF,
   "goal_position": ScoreAttack.find_goal(layout) if act_index == 2 else Vector2.INF,
  })
 if not acts[2].goal_position.is_finite():
  return {"valid": false, "errors": PackedStringArray(["No clear Zone portal anchor"])}
 for act_index in 2:
  acts[act_index].clear_y = acts[act_index + 1].entry_clear.y
 layout.acts = acts
 return layout
