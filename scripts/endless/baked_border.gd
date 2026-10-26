extends RefCounted
## Bake-only strip triangulation for simple inset rings. Complex topology keeps
## the established scanline builder; authored outlines and colliders are untouched.
const Fallback = preload("res://scripts/themes/terrain_border.gd")
const EPSILON := 0.0001

static func build(outline: PackedVector2Array, holes: Array[PackedVector2Array], width: float, height: float, material: Material) -> ArrayMesh:
 if outline.size() < 3 or width <= 0.0 or material == null: return null
 if not holes.is_empty(): return Fallback.build(outline, holes, width, height, material)
 var outer := Fallback._clean_contour(outline)
 # Reversing a mirrored contour would also reverse its texture travel. Preserve
 # that established mapping with the existing builder until separately audited.
 if _area(outer) < 0.0: return Fallback.build(outline, holes, width, height, material)
 var insets := Geometry2D.offset_polygon(outer, -width, Geometry2D.JOIN_MITER)
 if insets.size() != 1: return Fallback.build(outline, holes, width, height, material)
 var inner := Fallback._clean_contour(insets[0])
 if _area(inner) < 0.0: inner.reverse()
 if inner.size() != outer.size(): return Fallback.build(outline, holes, width, height, material)
 # Clipper may rotate the first vertex. Match complete cycles, never individual
 # nearest points that could jump across the arms of a narrow U/J contour.
 var best_shift := 0
 var best_cost := INF
 for shift in inner.size():
  var cost := 0.0
  for i in outer.size(): cost += outer[i].distance_squared_to(inner[(i + shift) % inner.size()])
  if cost < best_cost:
   best_cost = cost
   best_shift = shift
 var paired := PackedVector2Array()
 for i in inner.size(): paired.append(inner[(i + best_shift) % inner.size()])
 if not _valid_strip(outer, paired): return Fallback.build(outline, holes, width, height, material)
 var perimeter := 0.0
 for i in outer.size(): perimeter += outer[i].distance_to(outer[(i + 1) % outer.size()])
 var repeats := maxf(1.0, roundf(perimeter * Fallback.SCALE / 0.48))
 var factor := repeats / perimeter
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(material)
 var distance := 0.0
 for i in outer.size():
  var next := (i + 1) % outer.size()
  var end := distance + outer[i].distance_to(outer[next])
  var points := [outer[i], outer[next], paired[next], paired[i]]
  var uvs := [Vector2(distance * factor, 0), Vector2(end * factor, 0), Vector2(end * factor, 1), Vector2(distance * factor, 1)]
  for index: int in [0, 1, 2, 0, 2, 3]:
   surface.set_normal(Vector3.UP)
   surface.set_uv(uvs[index])
   surface.add_vertex(Vector3(points[index].x * Fallback.SCALE, height, points[index].y * Fallback.SCALE))
  distance = end
 return surface.commit()

static func _valid_strip(outer: PackedVector2Array, inner: PackedVector2Array) -> bool:
 if outer.size() < 3 or _area(inner) <= EPSILON: return false
 if preload("res://scripts/endless/visual_detail.gd")._crosses(outer) or preload("res://scripts/endless/visual_detail.gd")._crosses(inner): return false
 for i in outer.size():
  var next := (i + 1) % outer.size()
  if not Geometry2D.is_point_in_polygon(inner[i], outer): return false
  var quad := [outer[i], outer[next], inner[next], inner[i]]
  # Strictly convex quads give two nondegenerate triangles with no flipped face.
  for k in 4:
   if (quad[(k + 1) % 4] - quad[k]).cross(quad[(k + 2) % 4] - quad[(k + 1) % 4]) <= EPSILON: return false
  for j in outer.size():
   var after := (j + 1) % outer.size()
   if Geometry2D.segment_intersects_segment(outer[i], outer[next], inner[j], inner[after]) != null: return false
   if i != j and Geometry2D.segment_intersects_segment(outer[i], inner[i], outer[j], inner[j]) != null: return false
   if j != i and after != i:
    if Geometry2D.segment_intersects_segment(outer[i], inner[i], outer[j], outer[after]) != null: return false
    if Geometry2D.segment_intersects_segment(outer[i], inner[i], inner[j], inner[after]) != null: return false
 return true

static func _area(points: PackedVector2Array) -> float:
 var result := 0.0
 for i in points.size(): result += points[i].cross(points[(i + 1) % points.size()])
 return result * 0.5
