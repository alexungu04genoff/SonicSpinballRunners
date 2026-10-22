class_name TableGenerator
extends RefCounted
## Ordered top / relay / launch sections. Transform resources are local to each layout.
const VERSION := 8
const PAIR_VERSION := 3
enum Difficulty { EASY, NORMAL, HARD }
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]
const DIFFICULTY_TARGETS := [25.0, 50.0, 75.0]
const LOWER: ChunkData = preload("res://data/lower_chunk.tres")
const FALLBACK: ChunkData = preload("res://data/upper_chunk.tres")
const CATALOGUE: Array[ChunkData] = [
 preload("res://data/chunks/bumper_garden.tres"),
 preload("res://data/chunks/outer_return.tres"),
 preload("res://data/chunks/central_targets.tres"),
 preload("res://data/chunks/risk_route.tres"),
 preload("res://data/chunks/open_meadow.tres"),
 preload("res://data/chunks/gentle_banks.tres"),
 preload("res://data/chunks/tapered_throat.tres"),
 preload("res://data/chunks/offset_neck.tres"),
]
const MIDDLE_CATALOGUE: Array[ChunkData] = [
 preload("res://data/middle_chunks/open_relay.tres"),
 preload("res://data/middle_chunks/bank_relay.tres"),
 preload("res://data/middle_chunks/rebound_relay.tres"),
]
const TABLE_BOUNDS := Rect2(0, 0, 800, 1400)
const MIN_OVERLAP := 300.0
const CLEARANCE := 20.0 # Radius 14 plus 6 pixels of static clearance.
const SAMPLE_STEP := 25.0
const PASSAGE_INSET := 36.0
const LEDGE_PIXELS_PER_POINT := 2.5
const FULL_NARROWING_PIXELS := 390.0
const APPROACH_REFERENCE_WIDTH := 300.0

static func allowed_shifts(source: ChunkData) -> Array[int]:
 var shifts: Array[int] = []
 # Full-width sections stay aligned; narrower sections retain grid shifts.
 for shift in range(maxi(1, LOWER.grid_dimensions.x - source.grid_dimensions.x + 1)):
  shifts.append(shift)
 return shifts

static func generate(seed_value: int, preference: int = Difficulty.NORMAL, catalogue: Array[ChunkData] = CATALOGUE, middle_catalogue: Array[ChunkData] = MIDDLE_CATALOGUE) -> Dictionary:
 preference = clampi(preference, Difficulty.EASY, Difficulty.HARD)
 var transition_requested := transition_preference(seed_value, preference)
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value
 var candidates: Array[Dictionary] = []
 var tops := _transforms(catalogue, 0)
 var middles := _transforms(middle_catalogue, 7)
 var bottom: ChunkData = LOWER.duplicate(true)
 bottom.grid_position = Vector2i(0, 14)
 for top: ChunkData in tops:
  for middle: ChunkData in middles:
   var chunks: Array[ChunkData] = [top, middle, bottom]
   candidates.append({"chunks": chunks})
 for i in range(candidates.size() - 1, 0, -1):
  var j := rng.randi_range(0, i)
  var temporary := candidates[i]
  candidates[i] = candidates[j]
  candidates[j] = temporary
 var rejected := PackedStringArray()
 if preference == Difficulty.NORMAL:
  return _generate_normal(seed_value, candidates, bottom, rejected, transition_requested)
 var junction_cache: Dictionary = {}
 var estimate_cache: Dictionary = {}
 # Lazy estimates avoid evaluating the entire Cartesian library for ordinary builds.
 # Exhausting the requested tier still evaluates every candidate before a fallback.
 for i in candidates.size():
  var candidate: Dictionary = candidates[i]
  candidate.order = i
  candidate.estimate = _course_estimate(candidate.chunks, estimate_cache)
  candidate.distance = absf(float(candidate.estimate.score) - DIFFICULTY_TARGETS[preference])
  if candidate.estimate.band == preference and _validate_course_candidate(candidate, junction_cache, rejected):
   return _course_layout(seed_value, preference, candidate, false, rejected, transition_requested)
 candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
  return a.order < b.order if is_equal_approx(a.distance, b.distance) else a.distance < b.distance
 )
 for candidate: Dictionary in candidates:
  if _validate_course_candidate(candidate, junction_cache, rejected):
   return _course_layout(seed_value, preference, candidate, false, rejected, transition_requested)
 # A catalogue failure never silently shrinks the course back to two sections.
 var top: ChunkData = FALLBACK.duplicate(true)
 top.grid_position = Vector2i.ZERO
 var middle: ChunkData = MIDDLE_CATALOGUE[0].duplicate(true)
 middle.grid_position = Vector2i(0, 7)
 var fallback_chunks: Array[ChunkData] = [top, middle, bottom]
 var fallback := {"chunks": fallback_chunks, "estimate": _course_estimate(fallback_chunks, {})}
 if not _validate_course_candidate(fallback, junction_cache, rejected):
  return {"valid": false, "errors": fallback.validation.errors, "rejected": rejected}
 return _course_layout(seed_value, preference, fallback, true, rejected, transition_requested)

static func _generate_normal(seed_value: int, candidates: Array[Dictionary], bottom: ChunkData, rejected: PackedStringArray, preferred_style: String) -> Dictionary:
 var alternatives: Array[Dictionary] = []
 var styles: Array[String] = [preferred_style, ConnectorTransitions.CURVE if preferred_style == ConnectorTransitions.BANK else ConnectorTransitions.BANK]
 for source: Dictionary in candidates:
  for style: String in styles:
   var shaped := ConnectorTransitions.reshape(source.chunks, style)
   var flow_issues := ConnectorTransitions.normal_flow_issues(shaped)
   if not flow_issues.is_empty():
    rejected.append("Flow %s / %s: %s" % [_transform_key(source.chunks[0]), _transform_key(source.chunks[1]), "; ".join(flow_issues)])
    continue
   # Rate the final banked/curved geometry, never the raw closure shoulders.
   var candidate := {"chunks": shaped.chunks, "transition": shaped, "estimate": _course_estimate(shaped.chunks, {}, shaped)}
   candidate.order = alternatives.size()
   candidate.distance = absf(float(candidate.estimate.score) - DIFFICULTY_TARGETS[Difficulty.NORMAL])
   if candidate.estimate.band == Difficulty.NORMAL:
    if _validate_course_candidate(candidate, {}, rejected):
     return _course_layout(seed_value, Difficulty.NORMAL, candidate, false, rejected, preferred_style)
   else:
    alternatives.append(candidate)
   if not shaped.changed:
    break # Fully aligned geometry is identical for either style.
 # A missing tier may use a clearly reported easier/harder flowing course,
 # but never reintroduce a raw ceiling to satisfy a numeric difficulty band.
 alternatives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
  return a.order < b.order if is_equal_approx(a.distance, b.distance) else a.distance < b.distance
 )
 for candidate: Dictionary in alternatives:
  if _validate_course_candidate(candidate, {}, rejected):
   return _course_layout(seed_value, Difficulty.NORMAL, candidate, false, rejected, preferred_style)
 var top: ChunkData = CATALOGUE[4].duplicate(true) # Broad, aligned Open Meadow.
 top.grid_position = Vector2i.ZERO
 var middle: ChunkData = MIDDLE_CATALOGUE[0].duplicate(true)
 middle.grid_position = Vector2i(0, 7)
 var fallback_chunks: Array[ChunkData] = [top, middle, bottom]
 var shaped_fallback := ConnectorTransitions.reshape(fallback_chunks, preferred_style)
 var fallback := {"chunks": shaped_fallback.chunks, "transition": shaped_fallback, "estimate": _course_estimate(shaped_fallback.chunks, {}, shaped_fallback)}
 if not ConnectorTransitions.normal_flow_issues(shaped_fallback).is_empty() or not _validate_course_candidate(fallback, {}, rejected):
  return {"valid": false, "errors": PackedStringArray(["No technically valid flowing course"]), "rejected": rejected}
 return _course_layout(seed_value, Difficulty.NORMAL, fallback, true, rejected, preferred_style)

static func transition_preference(seed_value: int, preference: int) -> String:
 if preference != Difficulty.NORMAL:
  return ConnectorTransitions.STEP
 # Eight-seed comparison cycle: half straight banks, half faceted curves.
 # Separate from the catalogue RNG; Easy/Hard retain their original selection.
 var bucket := posmod(seed_value, 8)
 return ConnectorTransitions.BANK if bucket < 4 else ConnectorTransitions.CURVE

static func _transforms(catalogue: Array[ChunkData], row: int) -> Array[ChunkData]:
 var result: Array[ChunkData] = []
 for source: ChunkData in catalogue:
  for mirror: bool in [false, true]:
   for shift: int in allowed_shifts(source):
    var chunk: ChunkData = source.duplicate(true)
    chunk.grid_position = Vector2i(0, row)
    chunk.mirrored = mirror
    chunk.horizontal_shift_cells = shift
    result.append(chunk)
 return result

static func course_bounds(chunks: Array[ChunkData]) -> Rect2:
 var bounds := Rect2()
 for i in chunks.size():
  var chunk := chunks[i]
  var footprint := chunk.world_rect(Rect2(Vector2.ZERO, Vector2(chunk.grid_dimensions) * ChunkData.GRID_SIZE))
  bounds = footprint if i == 0 else bounds.merge(footprint)
 return bounds

static func _transform_key(chunk: ChunkData) -> String:
 return "%s@%d,%d:%s:%d" % [chunk.chunk_id, chunk.grid_position.x, chunk.grid_position.y, chunk.mirrored, chunk.horizontal_shift_cells]

static func _junction_key(upper: ChunkData, lower: ChunkData) -> String:
 # Instance IDs avoid aliasing two caller-supplied resources with the same authored ID.
 return "%d/%d" % [upper.get_instance_id(), lower.get_instance_id()]

static func _course_estimate(chunks: Array[ChunkData], cache: Dictionary, transition: Dictionary = {}) -> Dictionary:
 var estimates: Array[Dictionary] = []
 var worst: Dictionary = {}
 var worst_index := 0
 for i in range(chunks.size() - 1):
  var key := _junction_key(chunks[i], chunks[i + 1])
  if not cache.has(key):
   cache[key] = estimate_difficulty(chunks[i], chunks[i + 1])
  var estimate: Dictionary = cache[key].duplicate(true)
  if not transition.is_empty():
   # A shallow bank demands a more precise approach even with no residual ledge.
   estimate.flow_grade = ConnectorTransitions.maximum_grade(transition.junction_paths[i])
   estimate.flow_score = minf(100.0, estimate.flow_grade * 80.0)
   estimate.score = maxf(estimate.score, estimate.flow_score)
   estimate.band = difficulty_band(estimate.score)
  estimates.append(estimate)
  if worst.is_empty() or float(estimate.score) > float(worst.score):
   worst = estimate
   worst_index = i
 var result := worst.duplicate(true)
 result.junction_estimates = estimates
 result.worst_junction = worst_index
 var reasons := PackedStringArray(["Whole course: hardest component wins"])
 for i in estimates.size():
  reasons.append("Join %d: %.0f (%s)" % [i + 1, estimates[i].score, DIFFICULTY_NAMES[estimates[i].band]])
 reasons.append_array(PackedStringArray([
  "Hardest join checked width: %.0f px" % result.clear_width,
  "Hardest approach lane: %.0f px" % result.approach_clear_width,
  "Largest ledge at hardest join: %.0f px" % result.largest_ledge,
 ]))
 result.reasons = reasons
 return result

static func _validate_course_candidate(candidate: Dictionary, cache: Dictionary, rejected: PackedStringArray) -> bool:
 if candidate.has("validation"):
  return candidate.validation.valid
 candidate.validation = validate_course(candidate.chunks, cache)
 if not candidate.validation.valid:
  rejected.append("%s: %s" % [_transform_key(candidate.chunks[0]) + " / " + _transform_key(candidate.chunks[1]), "; ".join(candidate.validation.errors)])
 return candidate.validation.valid

static func _course_layout(seed_value: int, preference: int, candidate: Dictionary, fallback: bool, rejected: PackedStringArray, transition_requested: String = ConnectorTransitions.STEP) -> Dictionary:
 var estimate: Dictionary = candidate.estimate
 var matched: bool = not fallback and estimate.band == preference
 var note := "Requested tier matched." if matched else "No valid %s course; using %s." % [DIFFICULTY_NAMES[preference], DIFFICULTY_NAMES[estimate.band]]
 if fallback:
  note = "Catalogue exhausted; validated three-section %s fallback." % DIFFICULTY_NAMES[estimate.band]
 if preference == Difficulty.NORMAL:
  note += " Both joins preserve upward flow; authored interior corners remain."
 var transforms := PackedStringArray()
 for chunk: ChunkData in candidate.chunks:
  transforms.append(_transform_key(chunk))
 var junctions: Array[Dictionary] = candidate.validation.junctions
 var styles := PackedStringArray()
 for i in junctions.size():
  junctions[i].difficulty_estimate = estimate.junction_estimates[i]
  junctions[i].transition_style = ConnectorTransitions.ALIGNED if junctions[i].junction_rails.is_empty() else ConnectorTransitions.STEP
  junctions[i].transition_paths = []
  if candidate.has("transition"):
   junctions[i].transition_style = candidate.transition.junction_styles[i]
   junctions[i].transition_paths = candidate.transition.junction_paths[i]
  styles.append("J%d %s" % [i + 1, junctions[i].transition_style])
 var transition_summary := "Requested %s; %s" % [transition_requested, " / ".join(styles)]
 var notes: PackedStringArray = candidate.transition.notes.duplicate() if candidate.has("transition") else PackedStringArray()
 if preference == Difficulty.NORMAL:
  for i in estimate.junction_estimates.size():
   var component: Dictionary = estimate.junction_estimates[i]
   notes.append("Join %d flow grade %.2f; bank-shape contribution %.1f / 100" % [i + 1, component.get("flow_grade", 0.0), component.get("flow_score", 0.0)])
 if transition_requested != ConnectorTransitions.STEP and not candidate.has("transition"):
  transition_summary += "; no compatible bank in this tier"
 return {"valid": true, "seed": seed_value, "version": VERSION, "chunks": candidate.chunks,
  "junctions": junctions, "bounds": course_bounds(candidate.chunks),
  "used_fallback": fallback, "rejected": rejected, "difficulty_preference": preference,
  "difficulty_estimate": estimate, "preference_available": matched, "selection_note": note,
  "transition_requested": transition_requested, "transition_summary": transition_summary,
  "transition_notes": notes,
  "signature": "v%d seed=%d preference=%s chunks=%s estimate=%.1f transition=%s actual=%s" % [VERSION, seed_value, DIFFICULTY_NAMES[preference], " > ".join(transforms), estimate.score, transition_requested, "/".join(styles)]}

static func generate_pair(seed_value: int, preference: int = Difficulty.NORMAL, catalogue: Array[ChunkData] = CATALOGUE) -> Dictionary:
 preference = clampi(preference, Difficulty.EASY, Difficulty.HARD)
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value
 var candidates: Array[ChunkData] = []
 for source: ChunkData in catalogue:
  for mirror: bool in [false, true]:
   for shift: int in allowed_shifts(source):
    var candidate: ChunkData = source.duplicate(true)
    candidate.mirrored = mirror
    candidate.horizontal_shift_cells = shift
    candidates.append(candidate)
 # Local RNG only: gameplay randomness cannot change seed reproduction.
 for i in range(candidates.size() - 1, 0, -1):
  var j := rng.randi_range(0, i)
  var temporary := candidates[i]
  candidates[i] = candidates[j]
  candidates[j] = temporary
 var rejected := PackedStringArray()
 var rated_candidates: Array[Dictionary] = []
 for candidate: ChunkData in candidates:
  var estimate := estimate_difficulty(candidate, LOWER)
  var distance := absf(float(estimate.score) - DIFFICULTY_TARGETS[preference])
  var rated := {"chunk": candidate, "estimate": estimate, "distance": distance, "order": rated_candidates.size()}
  rated_candidates.append(rated)
 # Prefer the requested tier, preserving the shuffled variety within it.
 # A near-target candidate in another tier cannot displace a matching valid one.
 for rated: Dictionary in rated_candidates:
  if rated.estimate.band != preference:
   continue
  if _validate_rated(rated, rejected):
   return _layout(seed_value, preference, rated.chunk, rated.validation, rated.estimate, false, rejected)
 # No valid matching tier: report the shortage and use the closest valid result.
 rated_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
  return a.order < b.order if is_equal_approx(a.distance, b.distance) else a.distance < b.distance
 )
 for rated: Dictionary in rated_candidates:
  if _validate_rated(rated, rejected):
   return _layout(seed_value, preference, rated.chunk, rated.validation, rated.estimate, false, rejected)
 var fallback: ChunkData = FALLBACK.duplicate(true)
 var fallback_validation := validate(fallback, LOWER)
 if not fallback_validation.valid:
  return {"valid": false, "errors": fallback_validation.errors, "rejected": rejected}
 return _layout(seed_value, preference, fallback, fallback_validation, estimate_difficulty(fallback, LOWER), true, rejected)

static func _validate_rated(rated: Dictionary, rejected: PackedStringArray) -> bool:
 if not rated.has("validation"):
  rated.validation = validate(rated.chunk, LOWER)
  if not rated.validation.valid:
   rejected.append("%s mirror=%s shift=%d: %s" % [rated.chunk.chunk_id, rated.chunk.mirrored, rated.chunk.horizontal_shift_cells, "; ".join(rated.validation.errors)])
 return rated.validation.valid

static func _layout(seed_value: int, preference: int, upper: ChunkData, validation: Dictionary, estimate: Dictionary, fallback: bool, rejected: PackedStringArray) -> Dictionary:
 var matched: bool = not fallback and estimate.band == preference
 var selection_note := "Requested tier matched." if matched else "No valid %s candidate; using %s." % [DIFFICULTY_NAMES[preference], DIFFICULTY_NAMES[estimate.band]]
 if fallback:
  selection_note = "Catalogue exhausted; validated %s fallback." % DIFFICULTY_NAMES[estimate.band]
 var chunks: Array[ChunkData] = [upper, LOWER]
 var junctions: Array[Dictionary] = [{"upper_index": 0, "lower_index": 1, "junction_rails": validation.junction_rails, "passage": validation.passage, "difficulty_estimate": estimate}]
 return {"valid": true, "seed": seed_value, "version": PAIR_VERSION, "upper": upper,
  "lower": LOWER, "junction_rails": validation.junction_rails, "passage": validation.passage,
  "chunks": chunks, "junctions": junctions, "bounds": course_bounds(chunks),
  "used_fallback": fallback, "rejected": rejected, "difficulty_preference": preference, "difficulty_estimate": estimate,
  "preference_available": matched, "selection_note": selection_note,
  "signature": "v%d seed=%d preference=%s upper=%s mirror=%s shift=%d lower=%s estimate=%.1f" % [PAIR_VERSION, seed_value, DIFFICULTY_NAMES[preference], upper.chunk_id, upper.mirrored, upper.horizontal_shift_cells, LOWER.chunk_id, estimate.score]}

static func difficulty_band(score: float) -> int:
 return Difficulty.EASY if score < 37.5 else (Difficulty.NORMAL if score < 62.5 else Difficulty.HARD)

static func estimate_difficulty(upper: ChunkData, lower: ChunkData) -> Dictionary:
 # A static selection heuristic, not a trajectory simulation or a validity test.
 # Measure actual shoulders and the authored approach; preserve their geometry.
 var up := upper.world_rect(upper.bottom_connection)
 var down := lower.world_rect(lower.top_connection)
 var left := maxf(up.position.x, down.position.x)
 var right := minf(up.end.x, down.end.x)
 var corridor := _passage_interval(upper, lower, left, right)
 var clear_width := maxf(0.0, corridor.y - corridor.x - PASSAGE_INSET * 2.0)
 var reference_width := maxf(1.0, down.size.x - PASSAGE_INSET * 2.0)
 var offset := absf(up.get_center().x - down.get_center().x)
 var largest_ledge := maxf(absf(up.position.x - down.position.x), absf(up.end.x - down.end.x))
 var geometry := upper.gameplay_descriptors()
 geometry.append_array(lower.gameplay_descriptors())
 var blocked := 0
 const APPROACH_SAMPLES := 42
 for dy: float in [-150.0, -100.0, -50.0, 50.0, 100.0, 150.0]:
  for column in 7:
   var point := Vector2(corridor.x + PASSAGE_INSET + clear_width * (column + 0.5) / 7.0, down.position.y + dy)
   if not point_clear(point, geometry):
    blocked += 1
 var crowding := float(blocked) / APPROACH_SAMPLES
 var approach := _measure_approach(upper, geometry)
 var ledge_score := clampf(largest_ledge / LEDGE_PIXELS_PER_POINT, 0.0, 100.0)
 # A protrusion over two ball diameters is never classified as Easy.
 if largest_ledge > 4.0 * PlaygroundBall.RADIUS:
  ledge_score = maxf(40.0, ledge_score)
 var narrowing_score := 80.0 * clampf((reference_width - clear_width) / FULL_NARROWING_PIXELS, 0.0, 1.0)
 var offset_score := 45.0 * clampf(offset / 200.0, 0.0, 1.0)
 var connector_score := maxf(ledge_score, maxf(narrowing_score, offset_score))
 var pinch_score := 100.0 * clampf(1.0 - float(approach.width) / APPROACH_REFERENCE_WIDTH, 0.0, 1.0)
 var turn_score := 60.0 * clampf(float(approach.turn) / 90.0, 0.0, 1.0)
 var approach_score := maxf(pinch_score, maxf(turn_score, crowding * 60.0))
 var chunk_score := maxf(clampf(upper.estimated_difficulty, 0.0, 100.0), clampf(lower.estimated_difficulty, 0.0, 100.0))
 # The hardest component sets the estimate. Easy content cannot dilute a hard join.
 var score := maxf(chunk_score, maxf(connector_score, approach_score))
 return {"score": score, "band": difficulty_band(score), "chunk_score": chunk_score,
  "connector_score": connector_score, "clear_width": clear_width, "offset": offset,
  "largest_ledge": largest_ledge, "approach_blocked": crowding, "approach_score": approach_score,
  "approach_clear_width": approach.width, "turn_degrees": approach.turn,
  "reasons": PackedStringArray([
   "Chunk %.0f / Join %.0f" % [chunk_score, connector_score],
   "Approach %.0f; peak wins" % approach_score,
   "Checked join: %.0f px" % clear_width,
   "Largest ledge: %.0f px" % largest_ledge,
   "Approach lane: %.0f px" % approach.width,
   "Sharpest turn: %.0f°" % approach.turn,
  ])}

static func _measure_approach(upper: ChunkData, geometry: Array[Dictionary]) -> Dictionary:
 # Largest contiguous ball-center lane in each row, then the tightest of those rows.
 # Multiple parallel routes are alternatives, not one combined fictitious opening.
 var outline := upper.world_polygon(upper.playfield_outline)
 var seam := upper.world_rect(upper.bottom_connection).end.y
 var course_width := float(LOWER.grid_dimensions.x) * ChunkData.GRID_SIZE
 var tightest := course_width
 for y in range(int(seam - 250.0), int(seam - 49.0), 25):
  var best := 0.0
  var run := 0.0
  for x in range(0, int(course_width) + 1, 10):
   var point := Vector2(x, y)
   if Geometry2D.is_point_in_polygon(point, outline) and point_clear(point, geometry, PlaygroundBall.RADIUS):
    run += 10.0
    best = maxf(best, run)
   else:
    run = 0.0
  tightest = minf(tightest, maxf(0.0, best - 10.0))
 var sharpest := 0.0
 for rail: PackedVector2Array in upper.rails:
  for i in range(1, rail.size() - 1):
   var point := upper.world_point(rail[i])
   if point.y < seam - 250.0:
    continue
   var incoming := (rail[i] - rail[i - 1]).normalized()
   var outgoing := (rail[i + 1] - rail[i]).normalized()
   sharpest = maxf(sharpest, rad_to_deg(acos(clampf(incoming.dot(outgoing), -1.0, 1.0))))
 return {"width": tightest, "turn": sharpest}

static func validate(upper: ChunkData, lower: ChunkData) -> Dictionary:
 var result := validate_junction(upper, lower)
 if lower.grid_position != Vector2i(0, 7) or lower.mirrored or lower.horizontal_shift_cells != 0 or upper.grid_position.y != 0:
  result.errors.append("Legacy pair requires the fixed lower deck and an upper section at row zero")
  result.valid = false
 return result

static func validate_course(chunks: Array[ChunkData], junction_cache: Dictionary = {}) -> Dictionary:
 var errors := PackedStringArray()
 var junctions: Array[Dictionary] = []
 if chunks.size() < 2:
  return {"valid": false, "errors": PackedStringArray(["A course needs at least two ordered sections"]), "junctions": junctions}
 var geometry: Array[Dictionary] = []
 for chunk: ChunkData in chunks:
  geometry.append_array(chunk.gameplay_descriptors())
 for i in range(chunks.size() - 1):
  var key := _junction_key(chunks[i], chunks[i + 1])
  if not junction_cache.has(key):
   junction_cache[key] = validate_junction(chunks[i], chunks[i + 1])
  var validation: Dictionary = junction_cache[key]
  if not validation.valid:
   for error: String in validation.errors:
    errors.append("Join %d: %s" % [i + 1, error])
  var junction := {"upper_index": i, "lower_index": i + 1, "passage": validation.passage, "junction_rails": validation.junction_rails}
  junctions.append(junction)
  geometry.append_array(validation.junction_rails)
 if errors.is_empty():
  _check_routes(chunks, geometry, errors)
 return {"valid": errors.is_empty(), "errors": errors, "junctions": junctions}

static func validate_junction(upper: ChunkData, lower: ChunkData) -> Dictionary:
 var errors := PackedStringArray()
 var closures: Array[Dictionary] = []
 var result := {"valid": false, "errors": errors, "junction_rails": closures, "passage": Rect2()}
 var chunks: Array[ChunkData] = [upper, lower]
 var pair_bounds := course_bounds(chunks)
 var permitted_bounds := Rect2(0.0, pair_bounds.position.y, LOWER.grid_dimensions.x * ChunkData.GRID_SIZE, pair_bounds.size.y)
 for chunk: ChunkData in chunks:
  var bounds := chunk.world_rect(Rect2(Vector2.ZERO, Vector2(chunk.grid_dimensions) * ChunkData.GRID_SIZE))
  if chunk.grid_dimensions.x <= 0 or chunk.grid_dimensions.y != 7 or not permitted_bounds.encloses(bounds):
   errors.append("Invalid footprint or horizontal offset: " + chunk.chunk_id)
  if chunk.playfield_outline.size() < 3:
   errors.append("Missing navigable footprint: " + chunk.chunk_id)
 _check_connection(upper, upper.bottom_connection, false, errors)
 _check_connection(lower, lower.top_connection, true, errors)
 var up := upper.world_rect(upper.bottom_connection)
 var down := lower.world_rect(lower.top_connection)
 var left := maxf(up.position.x, down.position.x)
 var right := minf(up.end.x, down.end.x)
 var seam := down.position.y
 if not is_equal_approx(up.end.y, seam):
  errors.append("Connector boundaries do not meet vertically")
 if right - left < MIN_OVERLAP:
  errors.append("Insufficient connector overlap (minimum 300 pixels)")
 if not errors.is_empty():
  result.errors = errors
  return result
 # Close the symmetric difference of the openings, never the shared passage.
 for pair: Vector2 in [Vector2(up.position.x, down.position.x), Vector2(up.end.x, down.end.x)]:
  if not is_equal_approx(pair.x, pair.y):
   closures.append({"kind": "rail", "a": Vector2(minf(pair.x, pair.y), seam), "b": Vector2(maxf(pair.x, pair.y), seam), "radius": ChunkData.RAIL_RADIUS})
 var geometry := upper.gameplay_descriptors()
 geometry.append_array(lower.gameplay_descriptors())
 geometry.append_array(closures)
 # Clear central band includes ball radius, rail cap radius and a safety margin.
 var corridor := _passage_interval(upper, lower, left, right)
 var passage := Rect2(corridor.x + PASSAGE_INSET, seam - 45.0, corridor.y - corridor.x - PASSAGE_INSET * 2.0, 90.0)
 if corridor.y - corridor.x < MIN_OVERLAP:
  errors.append("Insufficient clearance across the full connector band")
 for x in range(ceili(passage.position.x), floori(passage.end.x) + 1, 10):
  for y in range(ceili(passage.position.y), floori(passage.end.y) + 1, 10):
   if not point_clear(Vector2(x, y), geometry):
    errors.append("Object obstructs the critical connector passage")
    break
  if not errors.is_empty():
   break
 if errors.is_empty():
  _check_routes(chunks, geometry, errors)
 result.valid = errors.is_empty()
 result.errors = errors
 result.junction_rails = closures
 result.passage = passage
 return result

static func _passage_interval(upper: ChunkData, lower: ChunkData, left: float, right: float) -> Vector2:
 # A sloped boundary changes x within the band. Claim only a rectangle that lies
 # inside both outlines throughout its height, then retain all physical checks.
 var seam := lower.world_rect(lower.top_connection).position.y
 for chunk: ChunkData in [upper, lower]:
  var outline := chunk.world_polygon(chunk.playfield_outline)
  var start := seam - 45.0 if chunk == upper else seam
  var end := seam if chunk == upper else seam + 45.0
  var heights: Array[float] = [start, end]
  for point: Vector2 in outline:
   if point.y > start and point.y < end:
    heights.append(point.y)
  # Polygon edges are linear; extrema occur at band edges or polygon vertices.
  for y: float in heights:
   var row_left := INF
   var row_right := -INF
   for i in outline.size():
    var a := outline[i]
    var b := outline[(i + 1) % outline.size()]
    if y < minf(a.y, b.y) or y > maxf(a.y, b.y):
     continue
    if is_equal_approx(a.y, b.y):
     row_left = minf(row_left, minf(a.x, b.x))
     row_right = maxf(row_right, maxf(a.x, b.x))
    else:
     var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
     row_left = minf(row_left, x)
     row_right = maxf(row_right, x)
   if not is_finite(row_left) or not is_finite(row_right):
    return Vector2(left, left)
   left = maxf(left, row_left)
   right = minf(right, row_right)
 return Vector2(left, right)

static func _check_connection(chunk: ChunkData, connection: Rect2, top: bool, errors: PackedStringArray) -> void:
 var size := Vector2(chunk.grid_dimensions) * ChunkData.GRID_SIZE
 if connection.size.x <= 0 or connection.size.y <= 0 or connection.position.x < 0 or connection.end.x > size.x or connection.position.y < 0 or connection.end.y > size.y:
  errors.append("Invalid connector rectangle: " + chunk.chunk_id)
  return
 var edge := connection.position.y if top else connection.end.y
 if not is_equal_approx(edge, 0.0 if top else size.y):
  errors.append("Connector does not touch its chunk boundary: " + chunk.chunk_id)
 for value: float in [connection.position.x, connection.position.y, connection.size.x, connection.size.y]:
  if not is_equal_approx(value, snappedf(value, 5.0)):
   errors.append("Connector must use the 5-pixel authoring grid: " + chunk.chunk_id)
   break
 for x: float in [connection.position.x, connection.end.x]:
  var target := chunk.world_point(Vector2(x, edge))
  var matches := 0
  for rail: PackedVector2Array in chunk.rails:
   if rail.size() >= 2:
    for point: Vector2 in [rail[0], rail[rail.size() - 1]]:
     if chunk.world_point(point).distance_to(target) < 0.1:
      matches += 1
  if matches != 1:
   errors.append("Opening edge must meet exactly one rail endpoint: " + chunk.chunk_id)

static func point_clear(point: Vector2, geometry: Array[Dictionary], clearance: float = CLEARANCE) -> bool:
 for item: Dictionary in geometry:
  match item.kind:
   "rail":
    if point.distance_to(Geometry2D.get_closest_point_to_segment(point, item.a, item.b)) < clearance + float(item.radius):
     return false
   "circle":
    if point.distance_to(item.position) < clearance + float(item.radius):
     return false
   "triangle":
    var local: Vector2 = point - item.position
    if Geometry2D.is_point_in_polygon(local, item.points):
     return false
    for i in item.points.size():
     if local.distance_to(Geometry2D.get_closest_point_to_segment(local, item.points[i], item.points[(i + 1) % item.points.size()])) < clearance:
      return false
 return true

static func _check_routes(chunks: Array[ChunkData], geometry: Array[Dictionary], errors: PackedStringArray) -> void:
 # Coarse static connectivity, not a promise about dynamic trajectories or gravity.
 var outlines: Array[PackedVector2Array] = []
 for chunk: ChunkData in chunks:
  outlines.append(chunk.world_polygon(chunk.playfield_outline))
 var bounds := course_bounds(chunks)
 var free_cells: Dictionary = {}
 for y in range(ceili(bounds.position.y / SAMPLE_STEP), ceili(bounds.end.y / SAMPLE_STEP)):
  for x in range(floori(bounds.position.x / SAMPLE_STEP) + 1, ceili(bounds.end.x / SAMPLE_STEP)):
   var cell := Vector2i(x, y)
   var point := Vector2(cell) * SAMPLE_STEP
   var inside := false
   for outline: PackedVector2Array in outlines:
    if Geometry2D.is_point_in_polygon(point, outline):
     inside = true
     break
   if inside and point_clear(point, geometry):
    free_cells[cell] = true
 var lower: ChunkData = chunks[chunks.size() - 1]
 var start := _nearest_cell(lower.world_point(lower.markers.get("serve", lower.markers.get("entry", Vector2(lower.grid_dimensions) * ChunkData.GRID_SIZE * 0.5))), free_cells)
 if start == Vector2i(-1, -1):
  errors.append("Lower-section entry has no clear navigable cell")
  return
 var queue: Array[Vector2i] = [start]
 var reached: Dictionary = {start: true}
 var cursor := 0
 while cursor < queue.size():
  var cell := queue[cursor]
  cursor += 1
  for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
   var adjacent := cell + offset
   if free_cells.has(adjacent) and not reached.has(adjacent) and point_clear((Vector2(cell) + Vector2(adjacent)) * SAMPLE_STEP * 0.5, geometry):
    reached[adjacent] = true
    queue.append(adjacent)
 for chunk: ChunkData in chunks:
  var targets := chunk.navigation_probes.duplicate()
  targets.append_array(chunk.rings)
  for marker_name: String in ["entry", "exit", "test_target"]:
   if chunk.markers.has(marker_name):
    targets.append(chunk.markers[marker_name])
  for target: Vector2 in targets:
   var cell := _nearest_cell(chunk.world_point(target), free_cells)
   if not reached.has(cell):
    errors.append("Unreachable route or collectible in %s near %s" % [chunk.chunk_id, target])
    return
 # A disconnected open patch larger than a few coarse cells is an obvious pocket.
 var disconnected := free_cells.size() - reached.size()
 if disconnected > 4:
  errors.append("Disconnected navigable pocket (%d cells)" % disconnected)

static func _nearest_cell(point: Vector2, cells: Dictionary) -> Vector2i:
 var center := Vector2i((point / SAMPLE_STEP).round())
 var best := Vector2i(-1, -1)
 var distance := 36.0
 for y in range(-1, 2):
  for x in range(-1, 2):
   var cell := center + Vector2i(x, y)
   var candidate_distance := point.distance_to(Vector2(cell) * SAMPLE_STEP)
   if cells.has(cell) and candidate_distance < distance:
    best = cell
    distance = candidate_distance
 return best
