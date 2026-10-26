extends SceneTree
const Detail = preload("res://scripts/endless/visual_detail.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Border = preload("res://scripts/themes/terrain_border.gd")
const Presentation = preload("res://scripts/presentation.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func _initialize() -> void:
 for definition: Dictionary in Shapes.definitions():
  for scale_value: float in [25.0, 50.0, 100.0]:
   var original: PackedVector2Array = definition.points.duplicate()
   for i in original.size(): original[i] *= scale_value
   var snapshot := original.duplicate()
   var reduced := Detail.contour(original, definition.closed)
   check(original == snapshot, "Visual reduction never changes source points")
   check(reduced.size() <= original.size(), "Visual reduction cannot add samples")
   var worst := 0.0
   for point: Vector2 in original:
    var nearest := INF
    for i in (reduced.size() if definition.closed else reduced.size() - 1):
     nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, reduced[i], reduced[(i + 1) % reduced.size()])))
    worst = maxf(worst, nearest)
   check(worst <= Detail.MAX_ERROR + 0.001, "Reduced contour respects the visual error limit")
   if definition.closed:
    if Detail._crosses(original):
     check(reduced == original, "Existing self-touching filled U contours remain untouched")
    else:
     check(not Geometry2D.triangulate_polygon(reduced).is_empty() and not Detail._crosses(reduced), "Closed contours remain valid and do not cross")
   else:
    check(reduced[0] == original[0] and reduced[-1] == original[-1], "Open wall endpoints stay exact")
   if definition.id == "j_curve_1x1" and scale_value == 50.0: measure_j(original, reduced)
 var notch := PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 30), Vector2(10, 30), Vector2(10, 3), Vector2(9, 3), Vector2(9, 30), Vector2(0, 30)])
 check(Detail.contour(notch) == notch, "A narrow intentional notch keeps every corner")
 for source: PrimitiveMesh in [SphereMesh.new(), CylinderMesh.new(), CapsuleMesh.new(), TorusMesh.new()]:
  var before := source.get_mesh_arrays()
  var reduced := Detail.primitive(source)
  check(triangles(reduced) < triangles(source), "Round primitive detail is reduced")
  check(source.get_mesh_arrays() == before, "Shared source primitive stays unchanged")
  check(reduced.get_aabb().size.distance_to(source.get_aabb().size) < source.get_aabb().size.length() * 0.01, "Primitive extents stay within one percent of the original samples")
 var faceted := CylinderMesh.new()
 faceted.radial_segments = 6
 check(Detail.primitive(faceted).radial_segments == 6, "Existing faceted art keeps its chosen detail")
 print("ENDLESS_DETAIL_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func triangles(mesh: Mesh) -> int:
 var total := 0
 for surface in mesh.get_surface_count():
  var arrays := mesh.surface_get_arrays(surface)
  total += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
 return total

func measure_j(original: PackedVector2Array, reduced: PackedVector2Array) -> void:
 var presenter := Presentation.new()
 var material := StandardMaterial3D.new()
 var counts: Array[int] = []
 for simplify: bool in [false, true]:
  var count := 0
  for ribbon: PackedVector2Array in Geometry2D.offset_polyline(original, 1.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
   if simplify: ribbon = Detail.contour(ribbon)
   count += triangles(presenter._prism(ribbon, 0.4, material, material))
   var border := Border.build(ribbon, [], 0.5, 0.401, material)
   if border != null: count += triangles(border)
  counts.append(count)
 check(counts[1] < counts[0] * 0.65, "J rail and cap lose at least 35 percent of triangles")
 print("ENDLESS_J_DETAIL | points=", original.size(), " -> ", reduced.size(), " | rail + cap triangles=", counts[0], " -> ", counts[1])
 presenter.free()
