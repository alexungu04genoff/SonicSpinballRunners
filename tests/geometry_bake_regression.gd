extends SceneTree
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const Plan = preload("res://scripts/endless/endless_plan.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func run() -> void:
 var tuning := PhysicsTuning.new()
 var controls := PlaygroundInput.new()
 var ball := PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 for path: String in Plan.PATHS:
  var document: Resource = Document.load_document(path).document
  var original: Dictionary = Compiler.compile(document, tuning, controls, ball)
  var saved := Bake.new()
  saved.source_fingerprint = document.fingerprint()
  saved.theme_id = "green_hill"
  saved.pipeline_fingerprint = Bake.pipeline_hash(saved.theme_id)
  for item: Dictionary in original.terrain:
   var records: Array = []
   for owner: int in item.body.get_shape_owners():
    for i in item.body.shape_owner_get_shape_count(owner):
     records.append({"shape": item.body.shape_owner_get_shape(owner, i), "transform": item.body.shape_owner_get_transform(owner)})
   saved.collisions.append(records)
  var file := "res://test-results/geometry-bake-test.res"
  check(ResourceSaver.save(saved, file, ResourceSaver.FLAG_COMPRESS) == OK, "Geometry sidecar saves")
  var loaded: Resource = ResourceLoader.load(file, "", ResourceLoader.CACHE_MODE_IGNORE)
  check(loaded.matches(document, "green_hill"), "Freshly loaded sidecar matches the exact source and pipeline")
  var baked: Dictionary = Compiler.compile(document, tuning, controls, ball, loaded.collisions)
  check(baked.error.is_empty(), "Baked collisions compile with the existing gameplay compiler")
  for i in original.terrain.size():
   var body: StaticBody2D = baked.terrain[i].body
   var shapes: Array[Shape2D] = []
   for owner: int in body.get_shape_owners():
    for index in body.shape_owner_get_shape_count(owner): shapes.append(body.shape_owner_get_shape(owner, index))
   check(shapes.size() == saved.collisions[i].size() and not shapes.is_empty(), "Every baked terrain piece keeps its collision shapes")
   for j in shapes.size():
    if shapes[j] is ConvexPolygonShape2D:
     check(shapes[j].points == saved.collisions[i][j].shape.points, "Convex decomposition survives saving exactly")
    elif shapes[j] is ConcavePolygonShape2D:
     check(shapes[j].segments == saved.collisions[i][j].shape.segments, "Open walls keep their exact segment pairs")
  document.spawn_position += Vector2(1, 0)
  check(not loaded.matches(document, "green_hill"), "Editing an Act invalidates its old bake")
  document.spawn_position -= Vector2(1, 0)
  loaded.pipeline_fingerprint = "outdated"
  check(not loaded.matches(document, "green_hill"), "Changing the geometry pipeline invalidates its old bake")
  original.root.free()
  baked.root.free()
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var material := StandardMaterial3D.new()
 surface.set_material(material)
 for vertex: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD]: surface.add_vertex(vertex)
 var source := surface.commit()
 var stripped: ArrayMesh = Bake.without_materials(source)
 check(stripped.surface_get_material(0) == null and source.surface_get_material(0) == material, "Baked meshes exclude theme materials without mutating live resources")
 check(stripped.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == source.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Stripping materials preserves every visual vertex")
 ball.free()
 controls.free()
 tuning.free()
 print("GEOMETRY_BAKE_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
