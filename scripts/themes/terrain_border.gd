extends RefCounted
## Collisionless inset bands. Scanline slabs triangulate concave rings and holes
## without filling the center, crossing a notch, or requiring matching vertex counts.
const SCALE := 0.01
const EPSILON := 0.0001

static func _height(edge: PackedVector2Array, x: float) -> float:
 return lerpf(edge[0].y, edge[1].y, (x - edge[0].x) / (edge[1].x - edge[0].x))

static func _redundant(a: Vector2, b: Vector2, c: Vector2) -> bool:
 return b.distance_to(Geometry2D.get_closest_point_to_segment(b, a, c)) <= EPSILON

static func _clean_contour(source: PackedVector2Array) -> PackedVector2Array:
 # Floor inference samples either side of each wall vertex. Remove only redundant
 # collinear samples in this private border copy, within the existing tolerance.
 # Stored presentation outlines and collision polygons retain every original point.
 var result := PackedVector2Array()
 for point: Vector2 in source:
  if not result.is_empty() and point.distance_to(result[-1]) <= EPSILON: continue
  while result.size() >= 2 and _redundant(result[-2], result[-1], point): result.remove_at(result.size() - 1)
  result.append(point)
 while result.size() > 3:
  if _redundant(result[-1], result[0], result[1]): result.remove_at(0)
  elif _redundant(result[-2], result[-1], result[0]): result.remove_at(result.size() - 1)
  else: break
 return result

static func build(outline: PackedVector2Array, holes: Array[PackedVector2Array], width: float, height: float, material: Material) -> ArrayMesh:
 if outline.size() < 3 or width <= 0.0 or material == null: return null
 outline = _clean_contour(outline)
 var clean_holes: Array[PackedVector2Array] = []
 for hole: PackedVector2Array in holes: clean_holes.append(_clean_contour(hole))
 holes = clean_holes
 var outer: Array[PackedVector2Array] = [outline]
 var inset := Geometry2D.offset_polygon(outline, -width, Geometry2D.JOIN_MITER)
 var expanded: Array[PackedVector2Array] = []
 for hole: PackedVector2Array in holes:
  expanded.append_array(Geometry2D.offset_polygon(hole, width, Geometry2D.JOIN_MITER))
 var contours: Array[PackedVector2Array] = outer.duplicate()
 contours.append_array(inset)
 contours.append_array(holes)
 contours.append_array(expanded)
 var edges: Array[PackedVector2Array] = []
 var edge_groups: Array[int] = []
 var xs: Array[float] = []
 for contour_index in contours.size():
  var contour := contours[contour_index]
  var group := 0 if contour_index == 0 else (1 if contour_index <= inset.size() else contour_index - inset.size() + 1)
  for i in contour.size():
   var a := contour[i]
   var b := contour[(i + 1) % contour.size()]
   xs.append(a.x)
   if absf(a.x - b.x) > EPSILON:
    edges.append(PackedVector2Array([a, b]))
    edge_groups.append(group)
 # Offset contours can cross near narrow passages. Split at intersections too,
 # so the sorted boundary order cannot change inside any emitted trapezoid.
 var edge_bounds: Array[Rect2] = []
 var edge_order: Array[int] = []
 for i in edges.size():
  edge_bounds.append(Rect2(edges[i][0].min(edges[i][1]), (edges[i][1] - edges[i][0]).abs()))
  edge_order.append(i)
 edge_order.sort_custom(func(a: int, b: int) -> bool: return edge_bounds[a].position.x < edge_bounds[b].position.x)
 for ordered_i in edge_order.size():
  var i := edge_order[ordered_i]
  for ordered_j in range(ordered_i + 1, edge_order.size()):
   var j := edge_order[ordered_j]
   if edge_bounds[j].position.x > edge_bounds[i].end.x: break
   if edge_bounds[i].position.y > edge_bounds[j].end.y or edge_bounds[j].position.y > edge_bounds[i].end.y: continue
   var crossing: Variant = Geometry2D.segment_intersects_segment(edges[i][0], edges[i][1], edges[j][0], edges[j][1])
   if crossing != null: xs.append(crossing.x)
 xs.sort()
 var unique: Array[float] = []
 for x: float in xs:
  if unique.is_empty() or x - unique[-1] > EPSILON: unique.append(x)
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(material)
 var vertices := 0
 var boundaries: Array[PackedVector2Array] = outer.duplicate()
 boundaries.append_array(holes)
 var uv_cache: Dictionary = {}
 var uv_segments: Array[Dictionary] = []
 var uv_grid: Dictionary = {}
 var grid_size := maxf(width * 4.0, 8.0)
 for contour_index in boundaries.size():
  var contour := boundaries[contour_index]
  var perimeter := 0.0
  for j in contour.size(): perimeter += contour[j].distance_to(contour[(j + 1) % contour.size()])
  var repeats := maxf(1.0, roundf(perimeter * SCALE / 0.48))
  var distance := 0.0
  for j in contour.size():
   var a := contour[j]
   var b := contour[(j + 1) % contour.size()]
   var id := uv_segments.size()
   uv_segments.append({"a": a, "b": b, "distance": distance, "contour": contour_index, "repeats": repeats, "factor": repeats / maxf(perimeter, EPSILON)})
   var low := Vector2i(((a.min(b) - Vector2.ONE * width * 3.0) / grid_size).floor())
   var high := Vector2i(((a.max(b) + Vector2.ONE * width * 3.0) / grid_size).floor())
   for x in range(low.x, high.x + 1):
    for y in range(low.y, high.y + 1):
     var key := Vector2i(x, y)
     if not uv_grid.has(key): uv_grid[key] = []
     uv_grid[key].append(id)
   distance += a.distance_to(b)
 var next_edge := 0
 var crossing_edges: Array[int] = []
 for i in range(unique.size() - 1):
  var left := unique[i]
  var right := unique[i + 1]
  var mid := (left + right) * 0.5
  var active: Array[Vector2] = []
  while next_edge < edge_order.size() and edge_bounds[edge_order[next_edge]].position.x < mid:
   crossing_edges.append(edge_order[next_edge])
   next_edge += 1
  var retained: Array[int] = []
  for edge_index: int in crossing_edges:
   if edge_bounds[edge_index].end.x <= mid: continue
   retained.append(edge_index)
   var edge := edges[edge_index]
   active.append(Vector2(_height(edge, mid), edge_index))
  crossing_edges = retained
  active.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
  var inside: Dictionary = {}
  var hole_count := 0
  var expanded_count := 0
  for j in range(active.size() - 1):
   var edge_index := int(active[j].y)
   var group := edge_groups[edge_index]
   var entering: bool = not inside.get(group, false)
   inside[group] = entering
   if group >= 2 and group < 2 + holes.size(): hole_count += 1 if entering else -1
   elif group >= 2 + holes.size(): expanded_count += 1 if entering else -1
   var low := active[j].x
   var high := active[j + 1].x
   if high - low <= EPSILON: continue
   # Toggle contour membership as the scanline crosses each edge. Counts union
   # overlapping obstacles instead of cancelling them as a global parity would.
   if not inside.get(0, false) or hole_count > 0 or (inside.get(1, false) and expanded_count == 0): continue
   var bottom := edges[edge_index]
   var top := edges[int(active[j + 1].y)]
   var quad := PackedVector2Array([
    Vector2(left, _height(bottom, left)), Vector2(right, _height(bottom, right)),
    Vector2(right, _height(top, right)), Vector2(left, _height(top, left))])
   # A scanline strip can span several bends. Subdivide before assigning path
   # coordinates so a long triangle cannot smear the nearest-edge mapping.
   var step_size := maxf(2.0, width * 1.5)
   var columns := maxi(1, ceili((right - left) / step_size))
   var rows := maxi(1, ceili(maxf(quad[0].distance_to(quad[3]), quad[1].distance_to(quad[2])) / step_size))
   for column in columns:
    var start := float(column) / columns
    var end := float(column + 1) / columns
    var lower_a := quad[0].lerp(quad[1], start)
    var lower_b := quad[0].lerp(quad[1], end)
    var upper_a := quad[3].lerp(quad[2], start)
    var upper_b := quad[3].lerp(quad[2], end)
    for row in rows:
     var a := float(row) / rows
     var b := float(row + 1) / rows
     var cell := PackedVector2Array([lower_a.lerp(upper_a, a), lower_b.lerp(upper_b, a), lower_b.lerp(upper_b, b), lower_a.lerp(upper_a, b)])
     for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
      var coordinates: Array[Vector4] = []
      for index: int in triangle:
       var p := cell[index]
       if not uv_cache.has(p):
        var candidates: Array = uv_grid.get(Vector2i((p / grid_size).floor()), [])
        uv_cache[p] = _uv(p, uv_segments, candidates, width)
       coordinates.append(uv_cache[p])
      for k in 3:
       var uv := coordinates[k]
       # Each closed contour fits whole repeats. Unwrap locally across its
       # start/end seam instead of interpolating through the entire perimeter.
       if uv.z == coordinates[0].z: uv.x += roundf((coordinates[0].x - uv.x) / uv.w) * uv.w
       coordinates[k] = uv
      var span := maxf(coordinates[0].x, maxf(coordinates[1].x, coordinates[2].x)) - minf(coordinates[0].x, minf(coordinates[1].x, coordinates[2].x))
      if span > 0.75 or coordinates[0].z != coordinates[1].z or coordinates[0].z != coordinates[2].z:
       # At a narrow junction, two unrelated perimeter branches can be equally
       # close. Use one local tangent instead of smearing many repeats between them.
       var center := (cell[triangle[0]] + cell[triangle[1]] + cell[triangle[2]]) / 3.0
       var candidates: Array = uv_grid.get(Vector2i((center / grid_size).floor()), [])
       var segment := _nearest_segment(center, uv_segments, candidates)
       var tangent: Vector2 = (segment.b - segment.a).normalized()
       for k in 3:
        var delta: Vector2 = cell[triangle[k]] - segment.a
        coordinates[k] = Vector4((segment.distance + delta.dot(tangent)) * segment.factor, clampf(absf(delta.cross(tangent)) / width, 0, 1), segment.contour, segment.repeats)
      for k in 3:
       var uv := coordinates[k]
       var p := cell[triangle[k]]
       surface.set_normal(Vector3.UP)
       surface.set_uv(Vector2(uv.x, uv.y))
       surface.add_vertex(Vector3(p.x * SCALE, height, p.y * SCALE))
       vertices += 1
 return surface.commit() if vertices > 0 else null

static func _nearest_segment(point: Vector2, segments: Array[Dictionary], candidates: Array) -> Dictionary:
 var best := INF
 var result: Dictionary = segments[0]
 if candidates.is_empty(): candidates = range(segments.size())
 for i: int in candidates:
  var segment := segments[i]
  var distance := point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point, segment.a, segment.b))
  if distance < best:
   best = distance
   result = segment
 return result

static func _uv(point: Vector2, segments: Array[Dictionary], candidates: Array, width: float) -> Vector4:
 var best := INF
 var result := Vector4(0, 0, 0, 1)
 if candidates.is_empty(): candidates = range(segments.size())
 for i: int in candidates:
  var segment := segments[i]
  var a: Vector2 = segment.a
  var closest := Geometry2D.get_closest_point_to_segment(point, a, segment.b)
  var separation := point.distance_to(closest)
  if separation < best:
   best = separation
   result = Vector4((segment.distance + a.distance_to(closest)) * segment.factor, clampf(separation / width, 0.0, 1.0), segment.contour, segment.repeats)
 return result
