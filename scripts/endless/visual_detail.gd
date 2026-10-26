extends RefCounted
## Bake-only visual detail. Never modify the authoritative collision contours.
const MAX_ERROR := 0.35 # Local physics pixels, well below the 7 px trial ball radius.
const CORNER_ANGLE := PI / 7.2 # Preserve authored turns of 25 degrees or more.

static func contour(source: PackedVector2Array, closed := true) -> PackedVector2Array:
 if source.size() < 4: return source.duplicate()
 var points := source.duplicate()
 if closed: points.append(source[0])
 var anchors: Array[int] = [0]
 for i in range(1, points.size() - 1):
  var incoming := points[i] - points[i - 1]
  var outgoing := points[i + 1] - points[i]
  if absf(incoming.angle_to(outgoing)) >= CORNER_ANGLE: anchors.append(i)
 anchors.append(points.size() - 1)
 var kept := {}
 for i in anchors.size() - 1: _reduce(points, anchors[i], anchors[i + 1], kept)
 var indices := kept.keys()
 indices.sort()
 var result := PackedVector2Array()
 for index: int in indices:
  if not closed or index < points.size() - 1: result.append(points[index])
 if closed:
  if result.size() < 3 or Geometry2D.is_polygon_clockwise(result) != Geometry2D.is_polygon_clockwise(source): return source.duplicate()
  if Geometry2D.triangulate_polygon(result).is_empty() or _crosses(result): return source.duplicate()
 elif _crosses(result, false):
  return source.duplicate()
 return result

static func _reduce(points: PackedVector2Array, first: int, last: int, kept: Dictionary) -> void:
 kept[first] = true
 kept[last] = true
 var farthest := -1
 var distance := MAX_ERROR
 for i in range(first + 1, last):
  var error := points[i].distance_to(Geometry2D.get_closest_point_to_segment(points[i], points[first], points[last]))
  if error > distance:
   distance = error
   farthest = i
 if farthest >= 0:
  _reduce(points, first, farthest, kept)
  _reduce(points, farthest, last, kept)

static func _crosses(points: PackedVector2Array, closed := true) -> bool:
 var edges := points.size() if closed else points.size() - 1
 for i in edges:
  for j in range(i + 2, edges):
   if closed and i == 0 and j == edges - 1: continue
   if Geometry2D.segment_intersects_segment(points[i], points[(i + 1) % points.size()], points[j], points[(j + 1) % points.size()]) != null: return true
 return false

static func primitive(source: PrimitiveMesh) -> PrimitiveMesh:
 var mesh: PrimitiveMesh = source.duplicate()
 if mesh is SphereMesh:
  mesh.radial_segments = mini(mesh.radial_segments, 16)
  mesh.rings = mini(mesh.rings, 7)
 elif mesh is CylinderMesh:
  mesh.radial_segments = mini(mesh.radial_segments, 16)
  mesh.rings = mini(mesh.rings, 1)
 elif mesh is CapsuleMesh:
  mesh.radial_segments = mini(mesh.radial_segments, 16)
  mesh.rings = mini(mesh.rings, 4)
 elif mesh is TorusMesh:
  mesh.rings = mini(mesh.rings, 20)
  mesh.ring_segments = mini(mesh.ring_segments, 8)
 return mesh
