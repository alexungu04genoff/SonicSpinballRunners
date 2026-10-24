class_name ZoneGenerator
extends RefCounted
## One connected course. Chunk indices run from the final cap to the launch deck;
## acts run in the opposite direction, in the order the player completes them.
const VERSION := 3
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
 preload("res://data/grid_chunks/zone_normal_target_garden.tres"),
 preload("res://data/grid_chunks/zone_normal_bank_return.tres"),
 preload("res://data/grid_chunks/zone_normal_crosscourt.tres"),
 preload("res://data/grid_chunks/zone_normal_offset_crown.tres"),
 preload("res://data/grid_chunks/zone_normal_winding_lane.tres"),
 preload("res://data/grid_chunks/zone_normal_balcony.tres"),
]
const HARD_GRID: Array[GridChunkRecipe] = [
 preload("res://data/grid_chunks/zone_hard_target_cove.tres"),
 preload("res://data/grid_chunks/zone_hard_bank_vault.tres"),
 preload("res://data/grid_chunks/zone_hard_split_orbit.tres"),
 preload("res://data/grid_chunks/zone_hard_offset_climb.tres"),
 preload("res://data/grid_chunks/zone_hard_needle_gate.tres"),
 preload("res://data/grid_chunks/zone_hard_switchback.tres"),
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
  var act_mirrors := [rng.randi_range(0, 1) == 1, rng.randi_range(0, 1) == 1, rng.randi_range(0, 1) == 1] if preference != TableGenerator.Difficulty.EASY else []
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
     var role := "interaction" if index in [1, 4, 7] else "approach"
     if remaining[item].chunk_id != previous_id and (preference == TableGenerator.Difficulty.EASY or remaining[item].zone_role == role):
      choices.append(item)
    if choices.is_empty():
     return {"valid": false, "errors": PackedStringArray(["Zone library lacks distinct rooms for its Act roles"])}
    var selected: int = choices[rng.randi_range(0, choices.size() - 1)]
    source = remaining[selected]
    remaining.remove_at(selected)
   previous_id = source.chunk_id
   var chunk: ChunkData = source.duplicate(true)
   chunk.grid_position = Vector2i(0, index * 7)
   chunk.mirrored = rng.randi_range(0, 1) == 1 if index < CHUNK_COUNT - 1 else false
   if preference != TableGenerator.Difficulty.EASY and index < CHUNK_COUNT - 1:
    chunk.mirrored = act_mirrors[index / CHUNKS_PER_ACT]
   var shifts := TableGenerator.allowed_shifts(source)
   # Narrow sections share an alignment within this course, avoiding opposing
   # shifts that would squeeze a recovery paddle at their shared seam.
   chunk.horizontal_shift_cells = shifts[shift_side % shifts.size()]
   chunks.append(chunk)
  var style := ConnectorTransitions.BANK if preference == TableGenerator.Difficulty.HARD else ConnectorTransitions.CURVE
  var collar := 240.0 if preference == TableGenerator.Difficulty.HARD else (180.0 if preference == TableGenerator.Difficulty.EASY else ConnectorTransitions.COLLAR)
  var transition := ConnectorTransitions.reshape(chunks, style, collar)
  # Hard challenge belongs inside its authored rooms, not accidental seam ceilings.
  var issues := ConnectorTransitions.normal_flow_issues(transition)
  if not issues.is_empty():
   rejected.append(issues[0])
   continue
  # Recheck the complete authored object/paddle clearances after collars move.
  # The compiler's checks operate in chunk-local coordinates, including mirrors.
  for chunk: ChunkData in transition.chunks:
   if not chunk.construction_grid.is_empty():
    GridChunkCompiler._check_clearance(chunk, issues)
  if not issues.is_empty():
   rejected.append("Shaped room: " + issues[0])
   continue
  var estimate := TableGenerator._course_estimate(transition.chunks, {}, transition)
  if estimate.band != preference:
   rejected.append("Candidate geometry is %s, requested %s" % [TableGenerator.DIFFICULTY_NAMES[estimate.band], TableGenerator.DIFFICULTY_NAMES[preference]])
   continue
  var composition := inspect_composition(transition.chunks, preference)
  if not composition.valid:
   rejected.append(composition.errors[0])
   continue
  var validation := TableGenerator.validate_course(transition.chunks)
  if not validation.valid:
   rejected.append(validation.errors[0])
   continue
  var candidate := {"chunks": transition.chunks, "transition": transition, "validation": validation, "estimate": estimate}
  var layout := TableGenerator._course_layout(seed_value, preference, candidate, false, rejected, style)
  layout.composition = composition
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
   "layout_name": layout.chunks[first + 1].title.split(" / ")[0].capitalize(),
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
  var next: Dictionary = acts[act_index + 1]
  var incoming: ChunkData = layout.chunks[next.chunk_indices.back()]
  var clear_y: float = next.entry_clear.y
  var span := _clear_line_span(incoming, clear_y)
  if not span.is_finite() or span.y <= span.x:
   return {"valid": false, "errors": PackedStringArray(["No safe completion-line span in incoming Act"])}
  acts[act_index].clear_y = clear_y
  acts[act_index].clear_left = span.x
  acts[act_index].clear_right = span.y
 layout.acts = acts
 return layout

static func _clear_line_span(incoming: ChunkData, y: float) -> Vector2:
 # An entering shot may fan sideways after passing a narrower score gate.
 # Completion uses the incoming chamber at this line, not the old gate's width.
 var outline := incoming.world_polygon(incoming.playfield_outline)
 var left := INF
 var right := -INF
 for index in outline.size():
  var a := outline[index]
  var b := outline[(index + 1) % outline.size()]
  if y < minf(a.y, b.y) or y > maxf(a.y, b.y) or is_equal_approx(a.y, b.y):
   continue
  var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
  left = minf(left, x)
  right = maxf(right, x)
 var inset := PlaygroundBall.RADIUS + ChunkData.RAIL_RADIUS
 return Vector2(left + inset, right - inset)

static func room_metrics(chunk: ChunkData) -> Dictionary:
 # Read the actual interior, independently of the authored rating and seams.
 # The largest contiguous clear lane on a row represents the easiest bypass.
 var outline := chunk.world_polygon(chunk.playfield_outline)
 var geometry := chunk.gameplay_descriptors()
 var narrow_rows := 0
 var lane_width := INF
 var widths := PackedInt32Array()
 var centers := PackedInt32Array()
 for local_y in range(175, 526, 25):
  var y := chunk.world_point(Vector2(0, local_y)).y
  var first := -1
  var last := -1
  var longest := 0
  var run := 0
  for x in range(0, 801, 10):
   var point := Vector2(x, y)
   var inside := Geometry2D.is_point_in_polygon(point, outline)
   if inside:
    if first < 0:
     first = x
    last = x
   if inside and TableGenerator.point_clear(point, geometry, PlaygroundBall.RADIUS + 6.0):
    run += 10
    longest = maxi(longest, run)
   else:
    run = 0
  var clear := maxi(0, longest - 10)
  lane_width = minf(lane_width, clear)
  if clear <= 320:
   narrow_rows += 1
  widths.append(last - first)
  centers.append((first + last) / 2)
 return {"narrow_rows": narrow_rows, "clear_lane": lane_width, "min_width": Array(widths).min(), "max_width": Array(widths).max(), "widths": widths, "centers": centers, "paddles": chunk.world_flippers().size()}

static func inspect_composition(chunks: Array[ChunkData], preference: int) -> Dictionary:
 var errors := PackedStringArray()
 var acts: Array[Dictionary] = []
 var ids: Dictionary = {}
 var silhouettes: Dictionary = {}
 for index in [1, 3, 4, 6, 7]:
  ids[chunks[index].chunk_id] = true
  var metrics := room_metrics(chunks[index])
  silhouettes[str(metrics.widths) + str(metrics.centers)] = true
 for act_index in 3:
  var first := 6 - act_index * 3
  var interaction := chunks[first + 1]
  var approach := chunks[first]
  var metrics := room_metrics(interaction)
  var approach_metrics := room_metrics(approach)
  var band := TableGenerator.difficulty_band(interaction.estimated_difficulty)
  acts.append({"interaction": interaction.chunk_id, "approach": approach.chunk_id, "room_band": band,
   "interaction_metrics": metrics, "approach_metrics": approach_metrics})
  if preference == TableGenerator.Difficulty.EASY:
   continue # Preserve the existing broad Easy library and deterministic selection.
  if interaction.zone_role != "interaction" or (act_index < 2 and approach.zone_role != "approach"):
   errors.append("Act %d lacks an interaction chamber followed by an exit approach" % (act_index + 1))
  if band != preference or (act_index < 2 and TableGenerator.difficulty_band(approach.estimated_difficulty) != preference):
   errors.append("Act %d room content does not match its requested difficulty" % (act_index + 1))
  if preference == TableGenerator.Difficulty.HARD and maxi(metrics.narrow_rows, approach_metrics.narrow_rows) < 2:
   errors.append("Act %d lacks a sustained precision lane inside its rooms" % (act_index + 1))
 if ids.size() != 5:
  errors.append("A Zone must use five distinct relay rooms")
 if preference != TableGenerator.Difficulty.EASY and silhouettes.size() < 3:
  errors.append("Zone rooms lack distinct interior silhouettes")
 return {"valid": errors.is_empty(), "errors": errors, "acts": acts, "distinct_rooms": ids.size(), "distinct_silhouettes": silhouettes.size()}
