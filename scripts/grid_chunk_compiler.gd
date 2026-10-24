class_name GridChunkCompiler
extends RefCounted
## Converts one authoritative recipe to existing runtime descriptors. It does not
## instantiate a TileMapLayer, add collisions, or modify shared legacy resources.
const EPSILON := 0.01
const BALL_CLEARANCE := 20.0 # 14-pixel ball radius plus the existing 6-pixel margin.
const SWING_STEPS := 20
const SWING_MARGIN := 3.0 # Covers the arc between samples for the kit's <=125px paddles.

static func compile(recipe: GridChunkRecipe) -> Dictionary:
 var errors := PackedStringArray()
 var chunk := ChunkData.new()
 if recipe == null:
  return {"valid": false, "errors": PackedStringArray(["Missing grid recipe"]), "chunk": chunk}
 if recipe.dimensions.x <= 0 or recipe.dimensions.y != 14 or recipe.dimensions.x % 2 != 0:
  errors.append("Grid footprint must use an even positive width and 14 rows")
 for span: Vector2i in [recipe.top_span, recipe.bottom_span]:
  if span.x < 0 or span.y > recipe.dimensions.x or span.y <= span.x:
   errors.append("Invalid grid connector span")
 chunk.chunk_id = recipe.recipe_id
 chunk.title = recipe.title
 chunk.estimated_difficulty = recipe.estimated_difficulty
 chunk.grid_dimensions = Vector2i(Vector2(recipe.dimensions) * GridPieceKit.CELL_SIZE / ChunkData.GRID_SIZE)
 chunk.grid_position = Vector2i(0, 7)
 chunk.top_connection = Rect2(recipe.top_span.x * GridPieceKit.CELL_SIZE, 0, (recipe.top_span.y - recipe.top_span.x) * GridPieceKit.CELL_SIZE, 20)
 chunk.bottom_connection = Rect2(recipe.bottom_span.x * GridPieceKit.CELL_SIZE, recipe.dimensions.y * GridPieceKit.CELL_SIZE - 20, (recipe.bottom_span.y - recipe.bottom_span.x) * GridPieceKit.CELL_SIZE, 20)
 var chains := {"left": [], "right": []}
 var metadata: Array[Dictionary] = []
 for index in recipe.placements.size():
  var placement: Dictionary = recipe.placements[index]
  if not placement.get("cell") is Vector2i or not placement.get("piece") is String:
   errors.append("Placement %d requires a piece name and integer cell anchor" % index)
   continue
  if placement.has("rotation") or placement.has("rotated") or placement.has("mirror"):
   errors.append("Placement %d: use oriented kit pieces; rotations and per-piece transforms are unsupported" % index)
   continue
  if placement.has("span"):
   if not placement.span is int or placement.span <= 0:
    errors.append("Placement %d: span must be a positive integer" % index)
    continue
   if placement.piece not in ["rail_v", "rail_h", "slope_left", "slope_right", "corner_left", "corner_right"]:
    errors.append("Placement %d: this piece has a fixed footprint and does not accept span" % index)
    continue
  var piece := GridPieceKit.definition(placement.piece, placement.get("span", 1))
  if piece.is_empty():
   errors.append("Placement %d: unknown piece or invalid span" % index)
   continue
  var anchor := Vector2(placement.cell)
  var footprint: Rect2 = piece.footprint
  footprint.position += anchor
  if footprint.position.x < 0 or footprint.position.y < 0 or footprint.end.x > recipe.dimensions.x or footprint.end.y > recipe.dimensions.y:
   errors.append("Placement %d extends beyond the construction footprint" % index)
  metadata.append({"piece": placement.piece, "cell": placement.cell, "footprint": footprint, "chain": placement.get("chain", "")})
  var position := anchor * GridPieceKit.CELL_SIZE
  match piece.kind:
   "rail":
    var chain: String = placement.get("chain", "")
    if not chains.has(chain):
     errors.append("Rail placement %d requires a left or right boundary chain" % index)
     continue
    var points: PackedVector2Array = piece.points
    for i in range(points.size() - 1):
     chains[chain].append([position + points[i] * GridPieceKit.CELL_SIZE, position + points[i + 1] * GridPieceKit.CELL_SIZE])
   "circle":
    var bumper := {"kind": "circle", "position": position, "radius": piece.radius * GridPieceKit.CELL_SIZE}
    if not piece.attachment.is_empty():
     bumper.wall_attachment = piece.attachment
    chunk.bumpers.append(bumper)
   "triangle":
    var vertices := PackedVector2Array()
    for point: Vector2 in piece.points:
     vertices.append(point * GridPieceKit.CELL_SIZE)
    chunk.bumpers.append({"kind": "triangle", "position": position, "points": vertices, "wall_attachment": piece.attachment})
   "ring":
    if chunk.rings.has(position):
     errors.append("Duplicate ring anchor at %s" % placement.cell)
    chunk.rings.append(position)
   "flipper": chunk.flipper_placements.append({"position": position + piece.offset * GridPieceKit.CELL_SIZE, "side": piece.side, "length": piece.length * GridPieceKit.CELL_SIZE})
 for key: String in recipe.markers:
  if not recipe.markers[key] is Vector2i:
   errors.append("Marker %s must use integer grid coordinates" % key)
  else:
   chunk.markers[key] = Vector2(recipe.markers[key]) * GridPieceKit.CELL_SIZE
 for cell: Vector2i in recipe.navigation_cells:
  chunk.navigation_probes.append(Vector2(cell) * GridPieceKit.CELL_SIZE)
 for side in 2:
  var chain: String = "left" if side == 0 else "right"
  var start := Vector2(recipe.top_span[side], 0) * GridPieceKit.CELL_SIZE
  var finish := Vector2(recipe.bottom_span[side], recipe.dimensions.y) * GridPieceKit.CELL_SIZE
  var rail := _join_chain(chains[chain], start, finish, chain, errors)
  if not rail.is_empty():
   chunk.rails.append(rail)
 if errors.is_empty():
  _check_wall_intersections(chunk.rails, errors)
 if errors.is_empty():
  # The two joined boundaries are the sole source for the navigable polygon.
  chunk.playfield_outline = chunk.rails[0].duplicate()
  var reverse := chunk.rails[1].duplicate()
  reverse.reverse()
  chunk.playfield_outline.append_array(reverse)
  _check_clearance(chunk, errors)
 chunk.construction_grid = {"cell_size": GridPieceKit.CELL_SIZE, "dimensions": recipe.dimensions, "version": GridPieceKit.VERSION, "recipe_id": recipe.recipe_id, "placements": metadata}
 return {"valid": errors.is_empty(), "errors": errors, "chunk": chunk}

static func _join_chain(edges: Array, start: Vector2, finish: Vector2, label: String, errors: PackedStringArray) -> PackedVector2Array:
 var pending := edges.duplicate(true)
 var points := PackedVector2Array([start])
 while not pending.is_empty():
  var matches: Array[int] = []
  var current := points[points.size() - 1]
  for i in pending.size():
   if current.distance_to(pending[i][0]) < EPSILON or current.distance_to(pending[i][1]) < EPSILON:
    matches.append(i)
  if matches.size() != 1:
   errors.append("%s boundary has a gap, branch or duplicate at %s" % [label, current])
   return PackedVector2Array()
  var edge: Array = pending[matches[0]]
  var next: Vector2 = edge[1] if current.distance_to(edge[0]) < EPSILON else edge[0]
  if next.y < current.y - EPSILON or next.distance_to(current) < EPSILON:
   errors.append("%s boundary backtracks vertically or has a zero-length edge" % label)
   return PackedVector2Array()
  points.append(next)
  pending.remove_at(matches[0])
 if points.size() < 2 or points[points.size() - 1].distance_to(finish) >= EPSILON:
  errors.append("%s boundary does not reach its connector port" % label)
  return PackedVector2Array()
 # Continuous collinear pieces become one capsule; no internal tile edges remain.
 var joined := PackedVector2Array()
 for point: Vector2 in points:
  while joined.size() > 1:
   var before := joined[joined.size() - 1] - joined[joined.size() - 2]
   var after := point - joined[joined.size() - 1]
   if absf(before.normalized().cross(after.normalized())) > 0.00001 or before.dot(after) <= 0:
    break
   joined.remove_at(joined.size() - 1)
  joined.append(point)
 return joined

static func _check_wall_intersections(rails: Array[PackedVector2Array], errors: PackedStringArray) -> void:
 var edges: Array = []
 for chain_index in rails.size():
  var rail := rails[chain_index]
  for i in range(rail.size() - 1):
   edges.append({"a": rail[i], "b": rail[i + 1], "chain": chain_index, "index": i})
 for i in edges.size():
  var a: Dictionary = edges[i]
  for j in range(i + 1, edges.size()):
   var b: Dictionary = edges[j]
   var adjacent: bool = a.chain == b.chain and absi(a.index - b.index) == 1
   if adjacent:
    var incoming: Vector2 = a.a - a.b
    var outgoing: Vector2 = b.b - b.a
    if absf(incoming.normalized().cross(outgoing.normalized())) < 0.00001 and incoming.dot(outgoing) > 0:
     errors.append("Boundary pieces overlap or double back")
   elif _segment_distance(a.a, a.b, b.a, b.b) < EPSILON:
    errors.append("Boundary pieces intersect or duplicate collision geometry")
   if a.chain != b.chain and _segment_distance(a.a, a.b, b.a, b.b) < 2.0 * (ChunkData.RAIL_RADIUS + BALL_CLEARANCE):
    errors.append("Opposing rails leave insufficient clearance for the ball")

static func _point_clear(point: Vector2, chunk: ChunkData, clearance: float) -> bool:
 if not Geometry2D.is_point_in_polygon(point, chunk.playfield_outline):
  return false
 for rail: PackedVector2Array in chunk.rails:
  for i in range(rail.size() - 1):
   if point.distance_to(Geometry2D.get_closest_point_to_segment(point, rail[i], rail[i + 1])) < ChunkData.RAIL_RADIUS + clearance:
    return false
 if not TableGenerator.point_clear(point, chunk.bumpers, clearance):
  return false
 return true

static func _check_clearance(chunk: ChunkData, errors: PackedStringArray) -> void:
 for bumper: Dictionary in chunk.bumpers:
  var attachment: String = bumper.get("wall_attachment", "")
  var attached_side := 0 if attachment == "left" else (1 if attachment == "right" else -1)
  if attached_side < 0 and not Geometry2D.is_point_in_polygon(bumper.position, chunk.playfield_outline):
   errors.append("Bumper is outside the navigable outline")
  if attached_side >= 0 and not _valid_attachment(bumper, chunk.rails[attached_side]):
   errors.append("Wall bumper or sling must be anchored directly to its named boundary")
  for side in chunk.rails.size():
   if side == attached_side:
    continue # This authored edge is deliberately sealed; it is not a ball lane.
   var rail: PackedVector2Array = chunk.rails[side]
   for i in range(rail.size() - 1):
    if _bumper_segment_distance(bumper, rail[i], rail[i + 1]) < ChunkData.RAIL_RADIUS + BALL_CLEARANCE * 2.0:
     errors.append("Bumper leaves insufficient ball passage beside a rail")
 for i in chunk.bumpers.size():
  for j in range(i + 1, chunk.bumpers.size()):
   var a: Dictionary = chunk.bumpers[i]
   var b: Dictionary = chunk.bumpers[j]
   if _bumper_pair_distance(a, b) < BALL_CLEARANCE * 2.0:
    errors.append("Bumpers overlap or leave insufficient ball passage")
 var targets := chunk.navigation_probes.duplicate()
 targets.append_array(chunk.rings)
 for point: Vector2 in chunk.markers.values():
  targets.append(point)
 for point: Vector2 in targets:
  if not _point_clear(point, chunk, BALL_CLEARANCE):
   errors.append("Route marker or ring lacks ball clearance at %s" % point)
 # Capsule sweeps include the complete pivot-to-tip segment, not just an anchor cell.
 var sweeps: Array = []
 for flipper: Dictionary in chunk.flipper_placements:
  var samples: Array = []
  for step in SWING_STEPS + 1:
   var angle := lerpf(0.32, -0.48, float(step) / SWING_STEPS)
   if flipper.side < 0:
    angle = PI - angle
   var tip: Vector2 = flipper.position + Vector2.RIGHT.rotated(angle) * float(flipper.length)
   if not Geometry2D.is_point_in_polygon(flipper.position, chunk.playfield_outline) or not Geometry2D.is_point_in_polygon(tip, chunk.playfield_outline):
    errors.append("Flipper swing extends outside the navigable outline")
   for rail: PackedVector2Array in chunk.rails:
    for i in range(rail.size() - 1):
     if _segment_distance(flipper.position, tip, rail[i], rail[i + 1]) < PlaygroundFlipper.RADIUS + ChunkData.RAIL_RADIUS + BALL_CLEARANCE * 2.0 + SWING_MARGIN:
      errors.append("Flipper swing leaves insufficient ball passage beside a rail")
   for bumper: Dictionary in chunk.bumpers:
    if _bumper_segment_distance(bumper, flipper.position, tip) < PlaygroundFlipper.RADIUS + BALL_CLEARANCE * 2.0 + SWING_MARGIN:
     errors.append("Flipper swing leaves insufficient ball passage beside a bumper")
   samples.append([flipper.position, tip])
  sweeps.append(samples)
 for i in sweeps.size():
  for j in range(i + 1, sweeps.size()):
   for a: Array in sweeps[i]:
    for b: Array in sweeps[j]:
     if _segment_distance(a[0], a[1], b[0], b[1]) < PlaygroundFlipper.RADIUS * 2.0 + BALL_CLEARANCE * 2.0 + SWING_MARGIN * 2.0:
      errors.append("Flipper sweeps overlap or close the ball passage")
      return

static func _valid_attachment(bumper: Dictionary, rail: PackedVector2Array) -> bool:
 # The whole rear edge must touch one straight boundary segment. A misplaced
 # mounted piece cannot create an unvalidated narrow passage behind itself.
 var anchors := PackedVector2Array([bumper.position])
 if bumper.kind == "triangle":
  anchors = PackedVector2Array([bumper.position + bumper.points[0], bumper.position + bumper.points[2]])
 for i in range(rail.size() - 1):
  var aligned := true
  for point: Vector2 in anchors:
   aligned = aligned and point.distance_to(Geometry2D.get_closest_point_to_segment(point, rail[i], rail[i + 1])) < EPSILON
  if aligned:
   return true
 return false

static func _bumper_segment_distance(bumper: Dictionary, a: Vector2, b: Vector2) -> float:
 if bumper.kind == "circle":
  return bumper.position.distance_to(Geometry2D.get_closest_point_to_segment(bumper.position, a, b)) - float(bumper.radius)
 var points: PackedVector2Array = bumper.points
 if Geometry2D.is_point_in_polygon(a - bumper.position, points) or Geometry2D.is_point_in_polygon(b - bumper.position, points):
  return 0.0
 var distance := INF
 for i in points.size():
  distance = minf(distance, _segment_distance(a, b, bumper.position + points[i], bumper.position + points[(i + 1) % points.size()]))
 return distance

static func _bumper_pair_distance(a: Dictionary, b: Dictionary) -> float:
 if a.kind == "circle":
  return _bumper_segment_distance(b, a.position, a.position) - float(a.radius)
 var distance := INF
 for i in a.points.size():
  distance = minf(distance, _bumper_segment_distance(b, a.position + a.points[i], a.position + a.points[(i + 1) % a.points.size()]))
 return distance

static func _segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
 if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
  return 0.0
 return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a, c, d)), b.distance_to(Geometry2D.get_closest_point_to_segment(b, c, d))), minf(c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)), d.distance_to(Geometry2D.get_closest_point_to_segment(d, a, b))))
