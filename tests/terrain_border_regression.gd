extends SceneTree
const Border = preload("res://scripts/themes/terrain_border.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func area(mesh: ArrayMesh) -> float:
 if mesh == null: return 0.0
 var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var total := 0.0
 for i in range(0, vertices.size(), 3): total += (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).length() * 0.5
 return total / (Border.SCALE * Border.SCALE)

func _initialize() -> void:
 var mat := StandardMaterial3D.new()
 var square := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
 var hole := PackedVector2Array([Vector2(40, 40), Vector2(60, 40), Vector2(60, 60), Vector2(40, 60)])
 var before := square.duplicate()
 check(is_equal_approx(area(Border.build(square, [], 5, 0, mat)), 1900), "Square keeps an empty 90x90 center")
 check(is_equal_approx(area(Border.build(square, [hole], 5, 0, mat)), 2400), "Floor includes perimeter and outward obstacle border")
 var notch := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 30), Vector2(30, 30), Vector2(30, 100), Vector2(0, 100)])
 var mesh := Border.build(notch, [], 5, 0.326, mat)
 check(mesh != null, "Concave contour creates a border")
 var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 for i in range(0, vertices.size(), 3):
  var center := (vertices[i] + vertices[i + 1] + vertices[i + 2]) / 3.0
  check(Geometry2D.is_point_in_polygon(Vector2(center.x, center.z) / Border.SCALE, notch), "Triangle remains inside concave path")
  check(is_equal_approx(center.y, 0.326), "Border height remains cosmetic")
 var thin := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 20), Vector2(0, 20)])
 check(is_equal_approx(area(Border.build(thin, [], 0.25, 0, mat)), 10.25), "Narrow rail retains its center")
 check(is_equal_approx(area(Border.build(square, [hole, hole], 5, 0, mat)), 2400), "Overlapping obstacles do not double-fill")
 var edge_hole := PackedVector2Array([Vector2(90, 40), Vector2(110, 40), Vector2(110, 60), Vector2(90, 60)])
 check(is_equal_approx(area(Border.build(square, [edge_hole], 5, 0, mat)), 2000), "Floor clips obstacle borders at the deck edge without overlap")
 check(square == before, "Source contour stays unchanged")
 check(Border.build(square, [], 0, 0, mat) == null, "Zero width disables border")
 check(Border.build(square, [], 5, 0, null) == null, "Other themes remain opt-in")
 print("RESULT | Terrain borders | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
