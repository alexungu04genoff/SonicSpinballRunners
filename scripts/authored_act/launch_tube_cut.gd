extends RefCounted
## Derive playable openings from the same sampled path as the tube controller.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")

static func footprints(objects: Array) -> Array[Dictionary]:
 var cuts: Array[Dictionary] = []
 for item: Dictionary in objects:
  if item.type != "launch_tube": continue
  var props := Objects.properties(item)
  var path: PackedVector2Array = Objects.RailPath.build(props.points).points
  if path.size() < 2: continue
  var direction := (path[1] - path[0]).normalized()
  path.insert(0, path[0] - direction * float(props.width) * preload("res://scripts/authored_act/launch_tube.gd").PLUNGER_BAY_WIDTHS)
  var transform := Transform2D(deg_to_rad(float(item.rotation_degrees)), item.position)
  _add_footprint(cuts, transform * path, float(props.width) * 0.54)
 return cuts

static func _bounds(points: PackedVector2Array) -> Rect2:
 var bounds := Rect2(points[0], Vector2.ZERO)
 for point: Vector2 in points: bounds = bounds.expand(point)
 return bounds

static func _add_footprint(cuts: Array[Dictionary], path: PackedVector2Array, radius: float) -> void:
 var outlines := Geometry2D.offset_polyline(path, radius, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
 if outlines.size() > 1 and path.size() > 2:
  # A route that curls back onto itself can enclose an untouched island.
  var middle := path.size() / 2
  _add_footprint(cuts, path.slice(0, middle + 1), radius)
  _add_footprint(cuts, path.slice(middle), radius)
 else:
  for outline in outlines: cuts.append({"points": outline, "bounds": _bounds(outline)})

static func carve(points: PackedVector2Array, closed: bool, cuts: Array[Dictionary]) -> Array[PackedVector2Array]:
 var pieces: Array[PackedVector2Array] = [points]
 for cut: Dictionary in cuts:
  var remaining: Array[PackedVector2Array] = []
  for piece in pieces:
   if not _bounds(piece).intersects(cut.bounds, true):
    remaining.append(piece)
   elif closed:
    if Geometry2D.intersect_polygons(piece, cut.points).is_empty(): remaining.append(piece)
    else: remaining.append_array(_cut_solid(piece, cut.points))
   else:
    remaining.append_array(Geometry2D.clip_polyline_with_polygon(piece, cut.points))
  pieces = remaining
 return pieces

static func _cut_solid(piece: PackedVector2Array, cut: PackedVector2Array) -> Array[PackedVector2Array]:
 var result := Geometry2D.clip_polygons(piece, cut)
 for contour in result:
  if not Geometry2D.is_polygon_clockwise(contour): continue
  # CollisionPolygon2D and the wall renderer both require simple solids.
  # Open an enclosed cut by partitioning its containing wall across the hole.
  var bounds := _bounds(piece).grow(1.0)
  var x := _bounds(contour).get_center().x
  var left := PackedVector2Array([bounds.position, Vector2(x, bounds.position.y),
   Vector2(x, bounds.end.y), Vector2(bounds.position.x, bounds.end.y)])
  var halves := Geometry2D.intersect_polygons(piece, left)
  halves.append_array(Geometry2D.clip_polygons(piece, left))
  var solids: Array[PackedVector2Array] = []
  for half in halves: solids.append_array(_cut_solid(half, cut))
  return solids
 return result
