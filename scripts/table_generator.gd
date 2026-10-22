class_name TableGenerator
extends RefCounted
## Phase 2A: one fixed lower deck and one validated, hand-authored upper section.
const VERSION := 3
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
 for shift in range(maxi(1, floori(TABLE_BOUNDS.size.x / ChunkData.GRID_SIZE) - source.grid_dimensions.x + 1)):
  shifts.append(shift)
 return shifts

static func generate(seed_value: int, preference: int = Difficulty.NORMAL, catalogue: Array[ChunkData] = CATALOGUE) -> Dictionary:
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
 return {"valid": true, "seed": seed_value, "version": VERSION, "upper": upper,
  "lower": LOWER, "junction_rails": validation.junction_rails, "passage": validation.passage,
  "used_fallback": fallback, "rejected": rejected, "difficulty_preference": preference, "difficulty_estimate": estimate,
  "preference_available": matched, "selection_note": selection_note,
  "signature": "v%d seed=%d preference=%s upper=%s mirror=%s shift=%d lower=%s estimate=%.1f" % [VERSION, seed_value, DIFFICULTY_NAMES[preference], upper.chunk_id, upper.mirrored, upper.horizontal_shift_cells, LOWER.chunk_id, estimate.score]}

static func difficulty_band(score: float) -> int:
 return Difficulty.EASY if score < 37.5 else (Difficulty.NORMAL if score < 62.5 else Difficulty.HARD)

static func estimate_difficulty(upper: ChunkData, lower: ChunkData) -> Dictionary:
 # A static selection heuristic, not a trajectory simulation or a validity test.
 # Measure actual shoulders and the authored approach; preserve their geometry.
 var up := upper.world_rect(upper.bottom_connection)
 var down := lower.world_rect(lower.top_connection)
 var left := maxf(up.position.x, down.position.x)
 var right := minf(up.end.x, down.end.x)
 var clear_width := maxf(0.0, right - left - PASSAGE_INSET * 2.0)
 var reference_width := maxf(1.0, down.size.x - PASSAGE_INSET * 2.0)
 var offset := absf(up.get_center().x - down.get_center().x)
 var largest_ledge := maxf(absf(up.position.x - down.position.x), absf(up.end.x - down.end.x))
 var geometry := upper.gameplay_descriptors()
 geometry.append_array(lower.gameplay_descriptors())
 var blocked := 0
 const APPROACH_SAMPLES := 42
 for dy: float in [-150.0, -100.0, -50.0, 50.0, 100.0, 150.0]:
  for column in 7:
   var point := Vector2(left + PASSAGE_INSET + clear_width * (column + 0.5) / 7.0, down.position.y + dy)
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
 var tightest := TABLE_BOUNDS.size.x
 for y in range(int(seam - 250.0), int(seam - 49.0), 25):
  var best := 0.0
  var run := 0.0
  for x in range(0, int(TABLE_BOUNDS.end.x) + 1, 10):
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
 var errors := PackedStringArray()
 var closures: Array[Dictionary] = []
 var result := {"valid": false, "errors": errors, "junction_rails": closures, "passage": Rect2()}
 for chunk: ChunkData in [upper, lower]:
  var bounds := chunk.world_rect(Rect2(Vector2.ZERO, Vector2(chunk.grid_dimensions) * ChunkData.GRID_SIZE))
  if chunk.grid_dimensions.x <= 0 or chunk.grid_dimensions.y != 7 or not TABLE_BOUNDS.encloses(bounds):
   errors.append("Invalid footprint or horizontal offset: " + chunk.chunk_id)
  if chunk.playfield_outline.size() < 3:
   errors.append("Missing navigable footprint: " + chunk.chunk_id)
 if lower.grid_position != Vector2i(0, 7) or lower.mirrored or lower.horizontal_shift_cells != 0 or upper.grid_position.y != 0:
  errors.append("Phase 2A requires the fixed lower deck and an upper section at row zero")
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
 var passage := Rect2(left + PASSAGE_INSET, seam - 45.0, right - left - PASSAGE_INSET * 2.0, 90.0)
 for x in range(ceili(passage.position.x), floori(passage.end.x) + 1, 10):
  for y in range(ceili(passage.position.y), floori(passage.end.y) + 1, 10):
   if not point_clear(Vector2(x, y), geometry):
    errors.append("Object obstructs the critical connector passage")
    break
  if not errors.is_empty():
   break
 if errors.is_empty():
  _check_routes(upper, lower, geometry, errors)
 result.valid = errors.is_empty()
 result.errors = errors
 result.junction_rails = closures
 result.passage = passage
 return result

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

static func _check_routes(upper: ChunkData, lower: ChunkData, geometry: Array[Dictionary], errors: PackedStringArray) -> void:
 # Coarse static connectivity, not a promise about dynamic trajectories or gravity.
 var outlines: Array[PackedVector2Array] = [upper.world_polygon(upper.playfield_outline), lower.world_polygon(lower.playfield_outline)]
 var free_cells: Dictionary = {}
 for y in range(2, 56):
  for x in range(1, 32):
   var cell := Vector2i(x, y)
   var point := Vector2(cell) * SAMPLE_STEP
   if (Geometry2D.is_point_in_polygon(point, outlines[0]) or Geometry2D.is_point_in_polygon(point, outlines[1])) and point_clear(point, geometry):
    free_cells[cell] = true
 var start := _nearest_cell(lower.world_point(lower.markers.get("serve", Vector2(665, 420))), free_cells)
 if start == Vector2i(-1, -1):
  errors.append("Serve has no clear navigable cell")
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
 for chunk: ChunkData in [upper, lower]:
  var targets := chunk.navigation_probes.duplicate()
  targets.append_array(chunk.rings)
  for marker_name: String in ["entry", "test_target"]:
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
