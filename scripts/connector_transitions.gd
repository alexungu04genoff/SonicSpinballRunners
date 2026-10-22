class_name ConnectorTransitions
extends RefCounted
## Passive outer-wall shaping. Both sides of a seam are edited on private resources.
const STEP := "Step"
const BANK := "Bank"
const CURVE := "Curve"
const ALIGNED := "Aligned"
const COLLAR := 160.0

static func reshape(sources: Array[ChunkData], style: String) -> Dictionary:
 var chunks: Array[ChunkData] = []
 for source: ChunkData in sources:
  chunks.append(source.duplicate(true))
 var styles := PackedStringArray()
 var paths: Array = []
 var notes := PackedStringArray()
 var changed := false
 for i in range(chunks.size() - 1):
  var upper: ChunkData = chunks[i].duplicate(true)
  var lower: ChunkData = chunks[i + 1].duplicate(true)
  var shaped := _reshape_junction(upper, lower, style)
  if shaped.changed and not _flippers_clear(shaped.paths, chunks):
   shaped = {"changed": false, "style": STEP, "paths": [], "note": "Bank would reduce flipper swing clearance"}
  if shaped.changed:
   chunks[i] = upper
   chunks[i + 1] = lower
   changed = true
  styles.append(shaped.style)
  paths.append(shaped.paths)
  if not shaped.note.is_empty():
   notes.append("Join %d: %s" % [i + 1, shaped.note])
 return {"chunks": chunks, "junction_styles": styles, "junction_paths": paths, "notes": notes, "changed": changed}

static func _reshape_junction(upper: ChunkData, lower: ChunkData, style: String) -> Dictionary:
 var up := upper.world_rect(upper.bottom_connection)
 var down := lower.world_rect(lower.top_connection)
 var result := {"changed": false, "style": STEP, "paths": [], "note": ""}
 if is_equal_approx(up.position.x, down.position.x) and is_equal_approx(up.end.x, down.end.x):
  result.style = ALIGNED
  return result
 if style == STEP:
  return result
 if style not in [BANK, CURVE] or not is_equal_approx(up.end.y, down.position.y):
  result.note = "Unsupported transition or nonadjacent sections"
  return result
 var seam := down.position.y
 var edges := [Vector2(up.position.x, up.end.x), Vector2(down.position.x, down.end.x)]
 var paths: Array[PackedVector2Array] = []
 for side in 2:
  var up_x: float = edges[0][side]
  var down_x: float = edges[1][side]
  if is_equal_approx(up_x, down_x):
   continue
  var upper_edge := Vector2(up_x, seam)
  var lower_edge := Vector2(down_x, seam)
  var upper_boundary := _boundary(upper, upper_edge, seam - COLLAR)
  var lower_boundary := _boundary(lower, lower_edge, seam + COLLAR)
  if upper_boundary.is_empty() or lower_boundary.is_empty():
   result.note = "Boundary has no unambiguous monotonic collar"
   return result
  var a: Vector2 = upper_boundary.tail[0]
  var b: Vector2 = lower_boundary.tail[0]
  var middle := (a + b) * 0.5
  if not is_equal_approx(middle.x, snappedf(middle.x, 5.0)) or not _inside_width(upper, middle) or not _inside_width(lower, middle):
   result.note = "Collar midpoint falls outside a footprint or connector authoring grid"
   return result
  var path := PackedVector2Array([a])
  if style == CURVE:
   path.append(Vector2(lerpf(a.x, b.x, 0.15625), lerpf(a.y, b.y, 0.25)))
  path.append(middle)
  if style == CURVE:
   path.append(Vector2(lerpf(a.x, b.x, 0.84375), lerpf(a.y, b.y, 0.75)))
  path.append(b)
  var half := floori(path.size() / 2.0)
  var upper_path := PackedVector2Array()
  var lower_path := PackedVector2Array()
  for p in range(half, -1, -1):
   upper_path.append(path[p])
  for p in range(half, path.size()):
   lower_path.append(path[p])
  if not _replace_boundary(upper, upper_boundary, upper_edge, upper_path) or not _replace_boundary(lower, lower_boundary, lower_edge, lower_path):
   result.note = "Boundary rail and navigable outline do not describe the same collar"
   return result
  edges[0][side] = middle.x
  edges[1][side] = middle.x
  paths.append(path)
 _set_connection(upper, false, edges[0], seam)
 _set_connection(lower, true, edges[1], seam)
 result.changed = true
 result.style = style
 result.paths = paths
 return result

static func _inside_width(chunk: ChunkData, point: Vector2) -> bool:
 var local := _local(chunk, point)
 return local.x >= 0.0 and local.x <= chunk.grid_dimensions.x * ChunkData.GRID_SIZE

static func _local(chunk: ChunkData, point: Vector2) -> Vector2:
 var local := point - Vector2(chunk.grid_position) * ChunkData.GRID_SIZE - Vector2(chunk.horizontal_shift_cells * ChunkData.GRID_SIZE, 0.0)
 if chunk.mirrored:
  local.x = chunk.grid_dimensions.x * ChunkData.GRID_SIZE - local.x
 return local

static func _tail_at_height(points: PackedVector2Array, height: float) -> PackedVector2Array:
 var direction := signf(height - points[0].y)
 for i in range(1, points.size()):
  var before := points[i - 1]
  var after := points[i]
  if (after.y - before.y) * direction <= 0.0:
   return PackedVector2Array()
  if (after.y - height) * direction >= 0.0:
   var anchor := before.lerp(after, (height - before.y) / (after.y - before.y))
   var tail := PackedVector2Array([anchor])
   for j in range(i, points.size()):
    if tail[tail.size() - 1].distance_to(points[j]) > 0.01:
     tail.append(points[j])
   return tail
 return PackedVector2Array()

static func _boundary(chunk: ChunkData, endpoint: Vector2, height: float) -> Dictionary:
 var found: Dictionary = {}
 for i in chunk.rails.size():
  var points := chunk.world_polygon(chunk.rails[i])
  if points.size() < 2:
   continue
  var reverse := points[points.size() - 1].distance_to(endpoint) < 0.01
  if reverse:
   points.reverse()
  if points[0].distance_to(endpoint) > 0.01:
   continue
  if not found.is_empty():
   return {}
  var tail := _tail_at_height(points, height)
  if tail.is_empty():
   return {}
  found = {"index": i, "reverse": reverse, "tail": tail}
 return found

static func _replace_boundary(chunk: ChunkData, boundary: Dictionary, endpoint: Vector2, path: PackedVector2Array) -> bool:
 var outline := chunk.world_polygon(chunk.playfield_outline)
 var endpoint_index := -1
 for i in outline.size():
  if outline[i].distance_to(endpoint) < 0.01:
   if endpoint_index >= 0:
    return false
   endpoint_index = i
 if endpoint_index < 0:
  return false
 var polygon := PackedVector2Array()
 for direction: int in [1, -1]:
  var ordered := PackedVector2Array()
  for i in outline.size():
   ordered.append(outline[posmod(endpoint_index + i * direction, outline.size())])
  var tail := _tail_at_height(ordered, path[path.size() - 1].y)
  if tail.is_empty() or tail[0].distance_to(path[path.size() - 1]) > 0.01:
   continue
  if not polygon.is_empty():
   return false
  polygon = path.duplicate()
  polygon.append_array(tail.slice(1))
  if direction < 0:
   polygon.reverse()
 if polygon.is_empty():
  return false
 var rail := path.duplicate()
 rail.append_array(boundary.tail.slice(1))
 if boundary.reverse:
  rail.reverse()
 for i in rail.size():
  rail[i] = _local(chunk, rail[i])
 for i in polygon.size():
  polygon[i] = _local(chunk, polygon[i])
 chunk.rails[boundary.index] = rail
 chunk.playfield_outline = polygon
 return true

static func _set_connection(chunk: ChunkData, top: bool, edges: Vector2, seam: float) -> void:
 var a := _local(chunk, Vector2(edges.x, seam))
 var b := _local(chunk, Vector2(edges.y, seam))
 var connection := chunk.top_connection if top else chunk.bottom_connection
 connection.position.x = minf(a.x, b.x)
 connection.size.x = absf(a.x - b.x)
 if top:
  chunk.top_connection = connection
 else:
  chunk.bottom_connection = connection

static func _segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
 if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
  return 0.0
 return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a, c, d)), b.distance_to(Geometry2D.get_closest_point_to_segment(b, c, d))), minf(c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)), d.distance_to(Geometry2D.get_closest_point_to_segment(d, a, b))))

static func _flippers_clear(paths: Array, chunks: Array[ChunkData]) -> bool:
 # At most 6px between sampled tips; an extra 4px covers the unsampled arc.
 # Keep room for the ball plus the existing 6px static margin beside each paddle.
 var required := PlaygroundFlipper.RADIUS + ChunkData.RAIL_RADIUS + PlaygroundBall.RADIUS + 10.0
 for chunk: ChunkData in chunks:
  for flipper: Dictionary in chunk.world_flippers():
   for step in 21:
    var angle := lerpf(0.32, -0.48, step / 20.0)
    if flipper.side < 0.0:
     angle = PI - angle
    var tip: Vector2 = flipper.position + Vector2.RIGHT.rotated(angle) * PlaygroundFlipper.LENGTH
    for path: PackedVector2Array in paths:
     for i in range(path.size() - 1):
      if _segment_distance(flipper.position, tip, path[i], path[i + 1]) < required:
       return false
 return true
