extends RefCounted
## Collisionless inset bands. Scanline slabs triangulate concave rings and holes
## without filling the center, crossing a notch, or requiring matching vertex counts.
const SCALE := 0.01
const EPSILON := 0.0001

static func _height(edge: PackedVector2Array, x: float) -> float:
 return lerpf(edge[0].y, edge[1].y, (x - edge[0].x) / (edge[1].x - edge[0].x))

static func build(outline: PackedVector2Array, holes: Array[PackedVector2Array], width: float, height: float, material: Material) -> ArrayMesh:
 if outline.size() < 3 or width <= 0.0 or material == null: return null
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
 for i in edges.size():
  for j in range(i + 1, edges.size()):
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
 for contour: PackedVector2Array in boundaries:
  var distance := 0.0
  for j in contour.size():
   var a := contour[j]
   var b := contour[(j + 1) % contour.size()]
   var id := uv_segments.size()
   uv_segments.append({"a": a, "b": b, "distance": distance})
   var low := Vector2i(((a.min(b) - Vector2.ONE * width * 3.0) / grid_size).floor())
   var high := Vector2i(((a.max(b) + Vector2.ONE * width * 3.0) / grid_size).floor())
   for x in range(low.x, high.x + 1):
    for y in range(low.y, high.y + 1):
     var key := Vector2i(x, y)
     if not uv_grid.has(key): uv_grid[key] = []
     uv_grid[key].append(id)
   distance += a.distance_to(b)
 for i in range(unique.size() - 1):
  var left := unique[i]
  var right := unique[i + 1]
  var mid := (left + right) * 0.5
  var active: Array[Vector2] = []
  for edge_index in edges.size():
   var edge := edges[edge_index]
   if mid > minf(edge[0].x, edge[1].x) and mid < maxf(edge[0].x, edge[1].x): active.append(Vector2(_height(edge, mid), edge_index))
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
   for index: int in [0, 1, 2, 0, 2, 3]:
    var p := quad[index]
    surface.set_normal(Vector3.UP)
    if not uv_cache.has(p):
     var candidates: Array = uv_grid.get(Vector2i((p / grid_size).floor()), [])
     uv_cache[p] = _uv(p, uv_segments, candidates, width)
    surface.set_uv(uv_cache[p])
    surface.add_vertex(Vector3(p.x * SCALE, height, p.y * SCALE))
    vertices += 1
 return surface.commit() if vertices > 0 else null

static func _uv(point: Vector2, segments: Array[Dictionary], candidates: Array, width: float) -> Vector2:
 var best := INF
 var result := Vector2.ZERO
 if candidates.is_empty(): candidates = range(segments.size())
 for i: int in candidates:
  var segment := segments[i]
  var a: Vector2 = segment.a
  var closest := Geometry2D.get_closest_point_to_segment(point, a, segment.b)
  var separation := point.distance_to(closest)
  if separation < best:
   best = separation
   result = Vector2((segment.distance + a.distance_to(closest)) * SCALE / 0.48, clampf(separation / width, 0.0, 1.0))
 return result
