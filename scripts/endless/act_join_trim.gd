extends RefCounted
## Each Act keeps its own exterior trim. Only a flat end touching a matching
## surface in a neighboring Act can disappear. All spans are Act-local 3D X.
const SCALE := TablePresentation.SCALE
const EPS := 0.00003
const Clearance = preload("res://scripts/authored_act/terrain_clearance.gd")

static func _spans(outline: PackedVector2Array, y: float) -> Array[Vector2]:
 var result: Array[Vector2] = []
 for i in outline.size():
  var a := outline[i]
  var b := outline[(i + 1) % outline.size()]
  if absf(a.y - y) > EPS / SCALE or absf(b.y - y) > EPS / SCALE: continue
  if absf(a.x - b.x) * SCALE > EPS:
   result.append(Vector2(minf(a.x, b.x), maxf(a.x, b.x)) * SCALE)
 return result

static func _merged(spans: Array[Vector2]) -> PackedVector2Array:
 spans.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
 var merged := PackedVector2Array()
 for span in spans:
  if merged.is_empty() or span.x > merged[-1].y + EPS: merged.append(span)
  else: merged[-1] = Vector2(merged[-1].x, maxf(merged[-1].y, span.y))
 return merged

static func remaining(span: Vector2, covered: PackedVector2Array, offset := 0.0) -> PackedVector2Array:
 var result := PackedVector2Array()
 var start := span.x
 for cut in covered:
  cut += Vector2.ONE * offset
  if cut.y <= start + EPS: continue
  if cut.x >= span.y - EPS: break
  if cut.x > start + EPS: result.append(Vector2(start, cut.x))
  start = maxf(start, cut.y)
  if start >= span.y - EPS: break
 if start < span.y - EPS: result.append(Vector2(start, span.y))
 return result

## The floor/raised pairs describe the exit (top) followed by the entry (bottom).
static func profiles(floor_outline: PackedVector2Array, obstacles: Array[PackedVector2Array], height: float, clearance: Array[Dictionary]) -> Array:
 var result := []
 for y: float in [0.0, height]:
  var walls: Array[Vector2] = []
  for obstacle in obstacles: walls.append_array(_spans(obstacle, y))
  var raised := _merged(walls)
  var ground := PackedVector2Array()
  for span in _merged(_spans(floor_outline, y)): ground.append_array(remaining(span, raised))
  # A rail can lower a bank at the join. Keep its lip where the top height is uncertain.
  var lowered: Array[Vector2] = []
  for cut: Dictionary in clearance:
   var bounds: Rect2 = cut.bounds
   if y >= bounds.position.y and y <= bounds.end.y: lowered.append(Vector2(bounds.position.x, bounds.end.x) * SCALE)
  var safe_raised := PackedVector2Array()
  var exclusions := _merged(lowered)
  for span in raised: safe_raised.append_array(remaining(span, exclusions))
  result.append(ground)
  result.append(safe_raised)
 return result

static func _surface(material: Material) -> SurfaceTool:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(material)
 return surface

static func _vertex(surface: SurfaceTool, pos: Vector3, uv: Vector2, uv2: Vector2, normal: Vector3) -> void:
 surface.set_normal(normal)
 surface.set_uv(uv)
 surface.set_uv2(uv2)
 surface.add_vertex(pos)

## Bake a separate mesh only for triangles whose nearest outline edge actually
## runs along an Act end. Side trim and obstacle-foot trim remain on the main mesh.
static func partition(mesh: ArrayMesh, outline: PackedVector2Array, height: float, width: float) -> Dictionary:
 var ends := [_spans(outline, 0.0), _spans(outline, height)]
 if ends[0].is_empty() and ends[1].is_empty(): return {-1: mesh}
 var arrays := mesh.surface_get_arrays(0)
 var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
 var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
 var surfaces := {}
 var edge_height := height * SCALE
 for i in range(0, verts.size(), 3):
  var center := (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
  var edge := 0 if center.z < edge_height * 0.5 else 1
  var y := 0.0 if edge == 0 else edge_height
  var distance := absf(center.z - y)
  var group := -1
  if uv2[i].x > 0.5 and distance <= width * SCALE + EPS:
   for span: Vector2 in ends[edge]:
    if center.x < span.x or center.x > span.y: continue
    group = edge
    # At a corner, preserve the return along the side of the Act.
    var point := Vector2(center.x, center.z) / SCALE
    for j in outline.size():
     var a := outline[j]
     var b := outline[(j + 1) % outline.size()]
     if absf(a.y * SCALE - y) <= EPS and absf(b.y * SCALE - y) <= EPS: continue
     if point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) * SCALE < distance - EPS:
      group = -1
      break
    break
  if not surfaces.has(group): surfaces[group] = _surface(mesh.surface_get_material(0))
  for j in range(i, i + 3): _vertex(surfaces[group], verts[j], uv[j], uv2[j], Vector3.UP)
 if surfaces.size() == 1: return {surfaces.keys()[0]: mesh}
 for group: int in surfaces: surfaces[group] = surfaces[group].commit()
 return surfaces

## Most end caps are simply hidden. Only a partially exposed cap needs clipping,
## once when its neighbor arrives. The baked mesh and its UVs stay available for reuse.
static func clip(mesh: Mesh, spans: PackedVector2Array) -> ArrayMesh:
 var arrays := mesh.surface_get_arrays(0)
 var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
 var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
 var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
 var count := verts.size() if indices.is_empty() else indices.size()
 var surface := _surface(mesh.surface_get_material(0))
 var emitted := false
 for i in range(0, count, 3):
  var triangle := []
  for j in range(i, i + 3):
   var k := j if indices.is_empty() else indices[j]
   triangle.append([verts[k], uv[k], uv2[k], normals[k]])
  for span in spans:
   var polygon := Clearance._clip(triangle, 0, span.x, true)
   polygon = Clearance._clip(polygon, 0, span.y, false)
   for k in range(1, polygon.size() - 1):
    var a: Vector3 = polygon[0][0]
    if (polygon[k][0] - a).cross(polygon[k + 1][0] - a).length_squared() < 1e-16: continue
    for v: Array in [polygon[0], polygon[k], polygon[k + 1]]:
     _vertex(surface, v[0], v[1], v[2], v[3].normalized())
    emitted = true
 return surface.commit() if emitted else null
