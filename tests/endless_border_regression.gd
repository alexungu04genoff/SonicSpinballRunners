extends SceneTree
const Border = preload("res://scripts/endless/baked_border.gd")
const Legacy = preload("res://scripts/themes/terrain_border.gd")
const Detail = preload("res://scripts/endless/visual_detail.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
var checks := 0
var failures := 0
var reduced := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func area(mesh: Mesh) -> float:
 if mesh == null: return 0.0
 var vertices := mesh.get_faces()
 var result := 0.0
 for i in range(0, vertices.size(), 3): result += (vertices[i+1] - vertices[i]).cross(vertices[i+2] - vertices[i]).length() * 0.5
 return result

func inspect(outline: PackedVector2Array, holes: Array[PackedVector2Array], width: float, label: String) -> void:
 var original := outline.duplicate()
 var material := StandardMaterial3D.new()
 var old := Legacy.build(outline, holes, width, 0.401, material)
 var baked := Border.build(outline, holes, width, 0.401, material)
 check(outline == original, label + ": authoritative outline stays unchanged")
 if baked != null and old.get_faces() != baked.get_faces():
  var cleaned := Legacy._clean_contour(outline)
  var inset := Geometry2D.offset_polygon(cleaned, -width, Geometry2D.JOIN_MITER)
  check(inset.size() == 1 and holes.is_empty(), label + ": fast strip has simple inset topology")
  var expected := (absf(Border._area(cleaned)) - absf(Border._area(inset[0]))) * Legacy.SCALE * Legacy.SCALE
  var perimeter := 0.0
  for contour: PackedVector2Array in [cleaned, inset[0]]:
   for i in contour.size(): perimeter += contour[i].distance_to(contour[(i + 1) % contour.size()]) * Legacy.SCALE
  # Mesh packing quantizes positions; bound area error by the boundary length
  # times a full position-quantization step, independently of the old tessellation.
  var quantization := baked.get_aabb().size.length() / 65535.0 + 0.000001
  check(absf(area(baked) - expected) <= perimeter * quantization * 2.0, label + ": packed strip covers the exact inset ring within position precision")
 else:
  check(area(old) == area(baked), label + ": fallback retains existing coverage exactly")
 if baked == null:
  check(old == null, label + ": empty offsets agree")
  return
 check(baked.get_faces().size() <= old.get_faces().size(), label + ": border never adds triangles")
 if baked.get_faces().size() < old.get_faces().size(): reduced += 1
 var arrays := baked.surface_get_arrays(0)
 var valid := true
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
  var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][i]
  valid = valid and vertex.is_finite() and is_equal_approx(vertex.y, 0.401) and uv.is_finite() and uv.y >= -0.001 and uv.y <= 1.001 and arrays[Mesh.ARRAY_NORMAL][i].distance_to(Vector3.UP) < 0.00004
 check(valid, label + ": finite UVs, correct height and upward normals")
 if label == "J/50":
  var presentation := TablePresentation.new()
  var walls := presentation._prism(outline, 0.4, material, material).get_faces().size() / 3
  print("BAKED_J_TRIANGLES | previous=", walls + old.get_faces().size() / 3, " | batched trim=", walls + baked.get_faces().size() / 3)
  presentation.free()

func _initialize() -> void:
 for shape: Dictionary in Shapes.definitions():
  for scale_value: float in [25.0, 50.0, 100.0]:
   var points: PackedVector2Array = shape.points.duplicate()
   for i in points.size(): points[i] *= scale_value
   if shape.closed:
    if Detail._crosses(points): continue
    inspect(Detail.contour(points), [], 0.5, shape.id + "/" + str(scale_value))
   else:
    for ribbon: PackedVector2Array in Geometry2D.offset_polyline(points, 1.0, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
     inspect(Detail.contour(ribbon), [], 0.5, "J/50" if shape.id == "j_curve_1x1" and scale_value == 50.0 else shape.id)
 var outer := PackedVector2Array([Vector2.ZERO, Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
 var hole := PackedVector2Array([Vector2(40, 40), Vector2(60, 40), Vector2(60, 60), Vector2(40, 60)])
 inspect(outer, [hole], 3.0, "Hole fallback")
 inspect(outer, [], 60.0, "Collapsed inset fallback")
 outer.reverse()
 inspect(outer, [], 3.0, "Mirrored UV direction fallback")
 check(reduced > 20, "Strip optimization applies beyond one demonstration curve")
 print("ENDLESS_BORDER_REGRESSION | checks=%d failures=%d reduced=%d" % [checks, failures, reduced])
 quit(1 if failures else 0)
