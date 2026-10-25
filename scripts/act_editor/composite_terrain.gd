class_name CompositeTerrain
extends RefCounted
## Explicit editor-time sculpting. Runtime consumes only the saved final outline.
const SHAPES = preload("res://scripts/act_editor/terrain_shapes.gd")
const VERSION := 1
const MAX_VERTICES := 2048
const MAX_SELECTION := 128
const MAX_INPUT_VERTICES := 8192
const MAX_COORDINATE := 4096.0
const MAX_STRENGTH := 5.0
const ANGLE_TOLERANCE_DEGREES := 1.0
const EDGE_EPSILON := 0.00001
const AREA_EPSILON := 0.00000001

static func merge(placements: Array) -> Dictionary:
 if placements.size() < 2:
  return _failure("Select at least two filled terrain pieces to merge.")
 if placements.size() > MAX_SELECTION:
  return _failure("Merge supports up to %d selected terrain pieces at once." % MAX_SELECTION)
 var polygons: Array[PackedVector2Array] = []
 var input_vertices := 0
 for index in placements.size():
  if not placements[index] is Dictionary:
   return _failure("Merge accepts terrain placements only.")
  var placement: Dictionary = placements[index]
  var definition := SHAPES.definition_for_placement(placement)
  if definition.is_empty():
   return _failure("Selected terrain %d has no usable silhouette." % (index + 1))
  if not definition.closed:
   return _failure("Merge supports filled terrain only. Remove open walls and curves from the selection.")
  if typeof(placement.get("anchor")) != TYPE_VECTOR2I:
   return _failure("Selected terrain must have an integer grid anchor.")
  var polygon := SHAPES.transformed_points(placement)
  for point_index in polygon.size():
   polygon[point_index] += Vector2(placement.anchor)
  var pieces: Array[PackedVector2Array] = [polygon]
  # The filled U's two lobes meet at one bottom point. Keep their exact geometry;
  # another selected piece can bridge them into a valid, solid composite.
  if placement.shape_id.begins_with("u_band_"):
   var middle := SHAPES.CURVE_STEPS
   pieces = [polygon.slice(0, middle + 1), polygon.slice(middle, middle * 2 + 1)]
   pieces[0].append(polygon[polygon.size() - 1])
   pieces[1].append(polygon[polygon.size() - 2])
  for piece: PackedVector2Array in pieces:
   var error := validation_error(piece)
   if not error.is_empty():
    return _failure("Selected terrain %d: %s" % [index + 1, error])
   input_vertices += piece.size()
   polygons.append(_canonical_polygon(piece))
 if input_vertices > MAX_INPUT_VERTICES:
  return _failure("Selection is too detailed. Merge fewer pieces at once.")
 var source_polygons := polygons.duplicate(true)
 # Canonical order makes the result independent of click order. Retry every pair
 # after a successful union so a later bridging piece can connect earlier islands.
 polygons.sort_custom(_polygon_less)
 var saw_hole := false
 while polygons.size() > 1:
  var joined := false
  for left in polygons.size():
   if joined: break
   for right in range(left + 1, polygons.size()):
    var union: Array[PackedVector2Array] = Geometry2D.merge_polygons(polygons[left], polygons[right])
    if union.size() != 1:
     for contour: PackedVector2Array in union:
      if Geometry2D.is_polygon_clockwise(contour): saw_hole = true
     continue
    var candidate := _canonical_polygon(union[0])
    # Point-only contacts can be returned as a self-touching contour. They do not
    # form a valid solid and must not be accepted as a collision polygon.
    if not validation_error(candidate).is_empty(): continue
    polygons[left] = candidate
    polygons.remove_at(right)
    polygons.sort_custom(_polygon_less)
    joined = true
    break
  if not joined:
   if saw_hole:
    return _failure("This union contains a hole. Fill the hole with terrain or change the selection; holes are not supported yet.")
   return _failure("Selection must form one connected solid. Separate islands and point-only joins are not supported; overlap or share an edge.")
 var result := _placement_from_global(polygons[0])
 result["join_indices"] = _join_indices(polygons[0], source_polygons)
 return result

static func _join_indices(outline: PackedVector2Array, sources: Array) -> PackedInt32Array:
 var joins := PackedInt32Array()
 for index in outline.size():
  var original_corner := false
  var point := outline[index]
  for source: PackedVector2Array in sources:
   if _boundary_follows(source, point, outline[posmod(index - 1, outline.size())]) and _boundary_follows(source, point, outline[(index + 1) % outline.size()]):
    original_corner = true
    break
  if not original_corner: joins.append(index)
 return joins

static func _boundary_follows(polygon: PackedVector2Array, point: Vector2, neighbor: Vector2) -> bool:
 var direction := (neighbor - point).normalized()
 for index in polygon.size():
  var a := polygon[index]
  var b := polygon[(index + 1) % polygon.size()]
  if Geometry2D.get_closest_point_to_segment(point, a, b).distance_squared_to(point) > EDGE_EPSILON * EDGE_EPSILON:
   continue
  if absf((b - a).normalized().cross(direction)) <= 0.0001 and maxf((a - point).dot(direction), (b - point).dot(direction)) > EDGE_EPSILON:
   return true
 return false

static func smooth(placement: Dictionary, strength: float, preserve_corners: bool = false, preserve_angle_degrees: float = 90.0, join_indices: Variant = null) -> Dictionary:
 if not is_finite(strength) or strength < 0.0 or strength > MAX_STRENGTH:
  return _failure("Smoothing strength must be between 0% and 500%.")
 if not is_finite(preserve_angle_degrees) or preserve_angle_degrees < 1.0 or preserve_angle_degrees > 179.0:
  return _failure("Preserved corner angle must be between 1 and 179 degrees.")
 var definition := SHAPES.definition_for_placement(placement)
 if definition.is_empty() or not definition.closed:
  return _failure("Smooth supports filled terrain only.")
 var outline: PackedVector2Array = definition.points
 var error := validation_error(outline)
 if not error.is_empty(): return _failure("Cannot smooth this outline: " + error)
 if join_indices != null:
  if typeof(join_indices) != TYPE_PACKED_INT32_ARRAY:
   return _failure("Join-only smoothing requires the current merge's corner indices.")
  for index: int in join_indices:
   if index < 0 or index >= outline.size(): return _failure("Join corner index is outside the merged outline.")
 var result := placement.duplicate(true)
 # Explicit String keys also satisfy the authoring schema when the input is a
 # primitive without these fields (dot insertion can create StringName keys).
 result["shape_id"] = "composite"
 result["composite_version"] = VERSION
 result["smoothing_strength"] = strength
 if strength == 0.0:
  result["outline"] = outline.duplicate()
  return {"placement": result, "error": ""}
 var rounded := PackedVector2Array()
 for index in outline.size():
  var point := outline[index]
  if join_indices != null and not join_indices.has(index):
   rounded.append(point)
   continue
  var previous := outline[posmod(index - 1, outline.size())]
  var next := outline[(index + 1) % outline.size()]
  var incoming := point - previous
  var outgoing := next - point
  # Preserve both convex 90-degree corners and concave right-angle notches by
  # default, or the chosen smaller angle between edges for other corner shapes.
  # The edge dot product is invariant under rotation, mirroring and polygon winding.
  var direction_dot := incoming.normalized().dot(outgoing.normalized())
  var corner_angle := rad_to_deg(acos(clampf(-direction_dot, -1.0, 1.0)))
  if preserve_corners and absf(corner_angle - preserve_angle_degrees) <= ANGLE_TOLERANCE_DEGREES:
   rounded.append(point)
   continue
  # Leave existing gentle curve samples alone. Only meaningful corners round.
  if direction_dot > 0.99875:
   rounded.append(point)
   continue
  # Local quadratic rounding stays in the adjacent corner triangle. Its maximum
  # setback was 0.15 cells and 18.75% of either edge at the original 75% maximum.
  # At 200%, allow 0.4 cells; at 500%, allow 1 cell. Keep cuts below half an edge so adjacent
  # rounded corners never meet in a duplicate vertex or consume a narrow edge.
  var setback := minf(strength * 0.2, minf(incoming.length(), outgoing.length()) * minf(strength * 0.25, 0.45))
  var start := point - incoming.normalized() * setback
  var end := point + outgoing.normalized() * setback
  var steps := maxi(4, ceili(strength * 2.0))
  for sample in range(steps + 1):
   var t := float(sample) / float(steps)
   rounded.append(start.lerp(point, t).lerp(point.lerp(end, t), t))
 error = validation_error(rounded)
 if not error.is_empty():
  return _failure("Smoothing would produce invalid terrain. Reduce strength. " + error)
 var original_area := absf(_signed_area(outline))
 var rounded_area := absf(_signed_area(rounded))
 if absf(rounded_area - original_area) > original_area * 0.05:
  return _failure("Smoothing would change this small shape too much. Reduce strength.")
 result["outline"] = rounded
 return {"placement": result, "error": ""}

static func validation_error(polygon: PackedVector2Array) -> String:
 if polygon.size() < 3: return "A solid outline needs at least three vertices."
 if polygon.size() > MAX_VERTICES: return "A composite may contain at most %d vertices." % MAX_VERTICES
 for index in polygon.size():
  var point := polygon[index]
  if not point.is_finite(): return "Outline coordinates must be finite."
  if absf(point.x) > MAX_COORDINATE or absf(point.y) > MAX_COORDINATE:
   return "Outline coordinates exceed the supported terrain extent."
  if point.distance_squared_to(polygon[(index + 1) % polygon.size()]) <= EDGE_EPSILON * EDGE_EPSILON:
   return "Outline contains a zero-length or microscopic edge."
  var incoming := point - polygon[posmod(index - 1, polygon.size())]
  var outgoing := polygon[(index + 1) % polygon.size()] - point
  if absf(incoming.cross(outgoing)) <= AREA_EPSILON and incoming.dot(outgoing) < 0.0:
   return "Outline contains a backtracking edge or zero-width spike."
 for first in polygon.size():
  var first_end := (first + 1) % polygon.size()
  for second in range(first + 1, polygon.size()):
   var second_end := (second + 1) % polygon.size()
   if first_end == second or second_end == first: continue
   if _segments_touch(polygon[first], polygon[first_end], polygon[second], polygon[second_end]):
    return "Outline intersects or touches itself; point-only joins and micro-loops are not valid solids."
 var area := absf(_signed_area(polygon))
 if area <= AREA_EPSILON: return "Outline must enclose a nonzero solid area."
 var triangles := Geometry2D.triangulate_polygon(polygon)
 if triangles.is_empty(): return "Outline could not be triangulated for solid collision."
 var triangle_area := 0.0
 for index in range(0, triangles.size(), 3):
  triangle_area += absf((polygon[triangles[index + 1]] - polygon[triangles[index]]).cross(polygon[triangles[index + 2]] - polygon[triangles[index]])) * 0.5
 if absf(triangle_area - area) > maxf(0.00001, area * 0.0001):
  return "Solid triangulation does not match the authored outline."
 if Geometry2D.decompose_polygon_in_convex(polygon).is_empty():
  return "Outline could not be decomposed for solid physics collision."
 return ""

static func _segments_touch(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
 var ab_c := (b - a).cross(c - a)
 var ab_d := (b - a).cross(d - a)
 var cd_a := (d - c).cross(a - c)
 var cd_b := (d - c).cross(b - c)
 if ((ab_c > 0.0 and ab_d < 0.0) or (ab_c < 0.0 and ab_d > 0.0)) and ((cd_a > 0.0 and cd_b < 0.0) or (cd_a < 0.0 and cd_b > 0.0)):
  return true
 return (absf(ab_c) <= AREA_EPSILON and _on_segment(c, a, b)) or (absf(ab_d) <= AREA_EPSILON and _on_segment(d, a, b)) or (absf(cd_a) <= AREA_EPSILON and _on_segment(a, c, d)) or (absf(cd_b) <= AREA_EPSILON and _on_segment(b, c, d))

static func _on_segment(point: Vector2, start: Vector2, end: Vector2) -> bool:
 return point.x >= minf(start.x, end.x) - EDGE_EPSILON and point.x <= maxf(start.x, end.x) + EDGE_EPSILON and point.y >= minf(start.y, end.y) - EDGE_EPSILON and point.y <= maxf(start.y, end.y) + EDGE_EPSILON

static func _signed_area(polygon: PackedVector2Array) -> float:
 var area := 0.0
 var origin := polygon[0]
 for index in polygon.size():
  # A local origin avoids cancellation when a small stamp sits far from (0, 0).
  area += (polygon[index] - origin).cross(polygon[(index + 1) % polygon.size()] - origin)
 return area * 0.5

static func _canonical_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
 var result := polygon.duplicate()
 if Geometry2D.is_polygon_clockwise(result): result.reverse()
 var first := 0
 for index in range(1, result.size()):
  if result[index].x < result[first].x or (result[index].x == result[first].x and result[index].y < result[first].y): first = index
 return result.slice(first) + result.slice(0, first)

static func _polygon_less(left: PackedVector2Array, right: PackedVector2Array) -> bool:
 return var_to_bytes(left).hex_encode() < var_to_bytes(right).hex_encode()

static func _placement_from_global(polygon: PackedVector2Array) -> Dictionary:
 var minimum := polygon[0]
 var maximum := polygon[0]
 for point: Vector2 in polygon:
  minimum = minimum.min(point)
  maximum = maximum.max(point)
 var anchor := Vector2i(floori(minimum.x), floori(minimum.y))
 var size := Vector2i(ceili(maximum.x), ceili(maximum.y)) - anchor
 var local := PackedVector2Array()
 for point: Vector2 in polygon: local.append(point - Vector2(anchor))
 return {"placement": {"shape_id": "composite", "base_size": size, "anchor": anchor,
  "quarter_turns": 0, "flip_h": false, "flip_v": false, "composite_version": VERSION,
  "outline": local, "smoothing_strength": 0.0}, "error": ""}

static func _failure(message: String) -> Dictionary:
 return {"placement": {}, "error": message}
