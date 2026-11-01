extends SceneTree
## Shared facade ownership, exact triangle preservation, and recipe transforms.
const Facade := preload("res://scripts/themes/terrain_facade.gd")
const Presenter := preload("res://scripts/themes/themed_presentation.gd")
const Registry := preload("res://scripts/themes/theme_registry.gd")
const Recipe := preload("res://scripts/endless/visual_recipe.gd")
const Batches := preload("res://scripts/endless/static_batches.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func run() -> void:
 for theme: String in Registry.IDS:
  for curved: bool in [false, true]:
   var p := Presenter.new()
   p.authored_mode = true
   p.theme_definition = Registry.create(theme)
   p._grass = p.theme_definition.floor_material
   p._cliff = Facade.material(p.theme_definition.cliff_material, 0.325, p.theme_definition.side_material)
   var terrain := Node3D.new()
   p.add_child(terrain)
   var floor_root := Node3D.new()
   terrain.add_child(floor_root)
   var outline := PackedVector2Array([Vector2(0, 0), Vector2(400, 0), Vector2(400, 300), Vector2(0, 300)])
   if curved:
    outline = PackedVector2Array([Vector2(0, 0), Vector2(400, 0), Vector2(400, 300), Vector2(300, 350), Vector2(100, 350), Vector2(0, 300)])
   p._make_land(outline, 1.45, floor_root, 0.0, 0.0)
   # Separate wall ownership above a straight front, or the same bent contour.
   var wall_outline := outline if curved else PackedVector2Array([Vector2(0, 280), Vector2(200, 280), Vector2(200, 300), Vector2(0, 300)])
   var side: Material = p.theme_definition.side_material
   p.mesh_node(p._prism(wall_outline, 0.325, side, p.theme_definition.top_material), null, Vector3.ZERO, terrain)
   if not curved:
    var other := PackedVector2Array([Vector2(200, 280), Vector2(400, 280), Vector2(400, 300), Vector2(200, 300)])
    p.mesh_node(p._prism(other, 0.325, side, p.theme_definition.top_material), null, Vector3.ZERO, terrain)
   var original := triangles(terrain)
   var stats := Facade.consolidate(floor_root, terrain, outline, side)
   check(stats.triangles > 0, theme + " transfers exterior triangles")
   check(stats.surfaces_after <= stats.surfaces_before, theme + " adds no material surface/pass")
   check(triangles(terrain) == original, theme + " preserves every vertex, triangle and normal")
   var cliff: MeshInstance3D = floor_root.get_node("CheckerCliff")
   check(cliff.mesh.surface_get_material(0) == p._cliff, theme + " one existing facade material spans the join")
   var vertices: PackedVector3Array = cliff.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   check(Array(vertices).any(func(v: Vector3): return v.y > 0.3), theme + " upper wall is part of facade")
   if p._cliff.shader.code.contains("uniform int mapping"):
    check(p._cliff.get_shader_parameter("mapping") == 1, theme + " exterior never uses private contour UV")
    check(is_equal_approx(p._cliff.get_shader_parameter("top_height"), 0.325), theme + " shared height datum")
   var recipe := Recipe.new()
   recipe.capture(terrain)
   recipe.finish()
   for stage: int in 2:
    if stage == 1: Batches.new().optimize(recipe)
    var restored := Node3D.new()
    var nodes: Array[Node] = []
    for i in recipe.records.size(): recipe.instantiate_one(i, nodes, restored)
    check(triangles(restored) == original, theme + " capture/batching preserves geometry")
    # Act placement is a translation. World projection sees final positions;
    # neither recipe nor batch supplies an Act-specific texture origin.
    restored.position = Vector3(2.5, 0, -17.25)
    check(triangles(restored, -restored.position) == original, theme + " neighboring Act placement preserves mapping inputs")
    restored.free()
   p.free()
 print("TERRAIN_FACADE_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func triangles(parent: Node3D, offset := Vector3.ZERO) -> Array:
 var result: Array = []
 _triangles(parent, Transform3D(Basis.IDENTITY, offset), result)
 result.sort()
 return result

func _triangles(node: Node, parent_transform: Transform3D, result: Array) -> void:
 var transform: Transform3D = parent_transform * node.transform if node is Node3D else parent_transform
 if node is MeshInstance3D:
  _mesh_triangles(node.mesh, transform, result)
 elif node is MultiMeshInstance3D:
  for i in node.multimesh.instance_count:
   var transforms: Array = node.multimesh.get_meta("offline_transforms", [])
   var local: Transform3D = transforms[i] if not transforms.is_empty() else node.multimesh.get_instance_transform(i)
   _mesh_triangles(node.multimesh.mesh, transform * local, result)
 for child in node.get_children(): _triangles(child, transform, result)

func _mesh_triangles(mesh: Mesh, transform: Transform3D, result: Array) -> void:
 for s in mesh.get_surface_count():
  var arrays := mesh.surface_get_arrays(s)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
  var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
  var count := vertices.size() if indices.is_empty() else indices.size()
  for i in range(0, count, 3):
   var triangle := []
   for j in 3:
    var index: int = i + j if indices.is_empty() else indices[i + j]
    var v := transform * vertices[index]
    var n := transform.basis * normals[index]
    triangle.append("%.5f,%.5f,%.5f/%.4f,%.4f,%.4f" % [v.x, v.y, v.z, n.x, n.y, n.z])
   result.append(";".join(triangle))
