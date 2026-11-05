extends RefCounted
## Explicit rail-owned overpasses. Base 2D terrain remains solid; the constrained
## rail ball already bypasses ground collision. Only terrain presentation lowers.
const Dimensions = preload("res://scripts/act_dimensions.gd")
const RailPath = preload("res://scripts/authored_act/rail_path.gd")
const MIN_TERRAIN_HEIGHT := 8.0
const GRID := 8.0
const SHOULDER := 16.0
const MESH_GUARD := 12.0 # Greater than the diagonal of one tessellation cell.

static func required_height(item: Dictionary) -> float:
 return (MIN_TERRAIN_HEIGHT if item.properties.get("terrain_clearance", false) else Dimensions.TERRAIN_HEIGHT_PIXELS) + Dimensions.RAMP_DECK_THICKNESS_PIXELS + Dimensions.RAMP_CLEARANCE_GAP_PIXELS

static func crossings(items: Array, ball_radius: float) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for item: Dictionary in items:
  if item.type != "elevated_rail" or not item.properties.get("terrain_clearance", false): continue
  var path: Dictionary = item.path
  var width := maxf(ball_radius, float(item.properties.width) * 0.54) + MESH_GUARD
  for i in path.points.size() - 1:
   var cap := minf(RailPath.height(path, path.lengths[i], item.properties.height), RailPath.height(path, path.lengths[i + 1], item.properties.height)) - Dimensions.RAMP_DECK_THICKNESS_PIXELS - Dimensions.RAMP_CLEARANCE_GAP_PIXELS
   if cap >= Dimensions.TERRAIN_HEIGHT_PIXELS: continue
   var a: Vector2 = path.points[i]
   var b: Vector2 = path.points[i + 1]
   result.append({"a": a, "b": b, "width": width, "height": maxf(MIN_TERRAIN_HEIGHT, cap), "bounds": Rect2(a, Vector2.ZERO).expand(b).grow(width + SHOULDER)})
 return result

static func top_at(point: Vector2, cuts: Array[Dictionary]) -> float:
 var height := Dimensions.TERRAIN_HEIGHT_PIXELS
 for cut: Dictionary in cuts:
  if not cut.bounds.has_point(point): continue
  var distance := point.distance_to(Geometry2D.get_closest_point_to_segment(point, cut.a, cut.b))
  var shoulder := clampf((distance - float(cut.width)) / SHOULDER, 0.0, 1.0)
  height = minf(height, lerpf(float(cut.height), Dimensions.TERRAIN_HEIGHT_PIXELS, shoulder))
 return height

static func apply(root: Node3D, items: Array, ball_radius: float, scale_factor: float) -> void:
 var cuts := crossings(items, ball_radius)
 if cuts.is_empty(): return
 # Floor/facade and decor retain their original height and collision meaning.
 for child: Node in root.get_children():
  if child.name != "SolidTerrainObstacle" and not str(child.name).begins_with("SolidTerrainObstacle") and child.name != "OpenTerrainRail" and not str(child.name).begins_with("OpenTerrainRail"): continue
  var meshes: Array[Node] = child.find_children("*", "MeshInstance3D", true, false)
  if child is MeshInstance3D: meshes.append(child)
  for visual: MeshInstance3D in meshes:
   if visual.mesh == null: continue
   visual.mesh = lower_mesh(visual.mesh, cuts, scale_factor)

static func _affected(bounds: Rect2, cuts: Array[Dictionary]) -> bool:
 for cut: Dictionary in cuts:
  if bounds.intersects(cut.bounds, true): return true
 return false

static func _clip(poly: Array, axis: int, plane: float, positive: bool) -> Array:
 var result: Array = []
 if poly.is_empty(): return result
 var previous: Array = poly[-1]
 var before := float(previous[0][axis]) - plane
 for current: Array in poly:
  var after := float(current[0][axis]) - plane
  if (before >= 0.0 if positive else before <= 0.0) != (after >= 0.0 if positive else after <= 0.0):
   var t := before / (before - after)
   result.append([previous[0].lerp(current[0], t), previous[1].lerp(current[1], t), previous[2].lerp(current[2], t), previous[3].lerp(current[3], t)])
  if after >= 0.0 if positive else after <= 0.0: result.append(current)
  previous = current
  before = after
 return result

static func _split(poly: Array, axis: int, step: float) -> Array:
 var low := INF
 var high := -INF
 for vertex: Array in poly:
  low = minf(low, vertex[0][axis])
  high = maxf(high, vertex[0][axis])
 var pieces: Array = []
 var rest := poly
 for index in range(floori(low / step) + 1, ceili(high / step)):
  var plane := index * step
  var piece := _clip(rest, axis, plane, false)
  if piece.size() >= 3: pieces.append(piece)
  rest = _clip(rest, axis, plane, true)
 if rest.size() >= 3: pieces.append(rest)
 return pieces

static func lower_mesh(source: Mesh, cuts: Array[Dictionary], scale_factor: float) -> ArrayMesh:
 var output := ArrayMesh.new()
 for surface_index in source.get_surface_count():
  var arrays := source.surface_get_arrays(surface_index)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
  if indices.is_empty():
   for i in vertices.size(): indices.append(i)
  var surface := SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  surface.set_material(source.surface_get_material(surface_index))
  for triangle in range(0, indices.size(), 3):
   var poly: Array = []
   var bounds := Rect2(Vector2(vertices[indices[triangle]].x, vertices[indices[triangle]].z) / scale_factor, Vector2.ZERO)
   for offset in 3:
    var i := indices[triangle + offset]
    var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][i] if arrays[Mesh.ARRAY_TEX_UV] != null and not arrays[Mesh.ARRAY_TEX_UV].is_empty() else Vector2.ZERO
    var uv2: Vector2 = arrays[Mesh.ARRAY_TEX_UV2][i] if arrays[Mesh.ARRAY_TEX_UV2] != null and not arrays[Mesh.ARRAY_TEX_UV2].is_empty() else Vector2.ZERO
    var color: Color = arrays[Mesh.ARRAY_COLOR][i] if arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty() else Color.WHITE
    poly.append([vertices[i], uv, uv2, color])
    bounds = bounds.expand(Vector2(vertices[i].x, vertices[i].z) / scale_factor)
   var pieces: Array = [poly]
   if _affected(bounds, cuts):
    pieces = []
    for strip: Array in _split(poly, 0, GRID * scale_factor):
     pieces.append_array(_split(strip, 2, GRID * scale_factor))
   for piece: Array in pieces:
    piece = piece.duplicate(true)
    for vertex: Array in piece:
     var point: Vector3 = vertex[0]
     var height := top_at(Vector2(point.x, point.z) / scale_factor, cuts) * scale_factor
     var full_height := Dimensions.TERRAIN_HEIGHT_PIXELS * scale_factor
     # Preserve trim thickness above the cap; shorten the side extrusion below it.
     point.y = height + point.y - full_height if point.y >= full_height else point.y * height / full_height
     vertex[0] = point
    for i in range(1, piece.size() - 1):
     var a: Vector3 = piece[0][0]
     var b: Vector3 = piece[i][0]
     var c: Vector3 = piece[i + 1][0]
     var normal := (c - a).cross(b - a).normalized()
     if normal.is_zero_approx(): continue
     for vertex: Array in [piece[0], piece[i], piece[i + 1]]:
      surface.set_normal(normal)
      surface.set_uv(vertex[1])
      surface.set_uv2(vertex[2])
      surface.set_color(vertex[3])
      surface.add_vertex(vertex[0])
  surface.commit(output)
 return output
