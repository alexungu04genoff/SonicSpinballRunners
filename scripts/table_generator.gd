class_name TableGenerator
extends RefCounted
## Phase 2A: one fixed lower deck and one validated, hand-authored upper section.
const VERSION := 1
const LOWER: ChunkData = preload("res://data/lower_chunk.tres")
const FALLBACK: ChunkData = preload("res://data/upper_chunk.tres")
const CATALOGUE: Array[ChunkData] = [
 preload("res://data/chunks/bumper_garden.tres"),
 preload("res://data/chunks/outer_return.tres"),
 preload("res://data/chunks/central_targets.tres"),
 preload("res://data/chunks/risk_route.tres"),
]
const TABLE_BOUNDS := Rect2(0, 0, 800, 1400)
const MIN_OVERLAP := 300.0
const CLEARANCE := 20.0 # Radius 14 plus 6 pixels of static clearance.
const SAMPLE_STEP := 25.0

static func generate(seed_value: int, catalogue: Array[ChunkData] = CATALOGUE) -> Dictionary:
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value
 var candidates: Array[ChunkData] = []
 for source: ChunkData in catalogue:
  for mirror: bool in [false, true]:
   for shift: int in [0, 1]:
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
 for candidate: ChunkData in candidates:
  var validation := validate(candidate, LOWER)
  if validation.valid:
   return _layout(seed_value, candidate, validation, false, rejected)
  rejected.append("%s mirror=%s shift=%d: %s" % [candidate.chunk_id, candidate.mirrored, candidate.horizontal_shift_cells, "; ".join(validation.errors)])
 var fallback: ChunkData = FALLBACK.duplicate(true)
 var fallback_validation := validate(fallback, LOWER)
 if not fallback_validation.valid:
  return {"valid": false, "errors": fallback_validation.errors, "rejected": rejected}
 return _layout(seed_value, fallback, fallback_validation, true, rejected)

static func _layout(seed_value: int, upper: ChunkData, validation: Dictionary, fallback: bool, rejected: PackedStringArray) -> Dictionary:
 return {"valid": true, "seed": seed_value, "version": VERSION, "upper": upper,
  "lower": LOWER, "junction_rails": validation.junction_rails, "passage": validation.passage,
  "used_fallback": fallback, "rejected": rejected,
  "signature": "v%d seed=%d upper=%s mirror=%s shift=%d lower=%s" % [VERSION, seed_value, upper.chunk_id, upper.mirrored, upper.horizontal_shift_cells, LOWER.chunk_id]}

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
 var passage := Rect2(left + 36.0, seam - 45.0, right - left - 72.0, 90.0)
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
  if chunk.markers.has("entry"):
   targets.append(chunk.markers.entry)
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
