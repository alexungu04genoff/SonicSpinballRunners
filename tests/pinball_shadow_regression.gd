extends SceneTree
const Batch = preload("res://scripts/pinball_mesh_batch.gd")
const Models = preload("res://scripts/pinball_models.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func triangles(actor: Node3D, shadow: bool) -> Array:
 var result: Array = []
 for node: Node in actor.get_children():
  if not node is MeshInstance3D: continue
  if shadow and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: continue
  if not shadow and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
  for surface in node.mesh.get_surface_count():
   var arrays: Array = node.mesh.surface_get_arrays(surface)
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
   if indices.is_empty():
    for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(i)
   for offset in range(0, indices.size(), 3):
    var face: Array = []
    for i in 3:
     var vertex: Vector3 = node.transform * arrays[Mesh.ARRAY_VERTEX][indices[offset + i]]
     var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][indices[offset + i]]
     face.append([vertex.snapped(Vector3.ONE * 0.001), normal.snapped(Vector3.ONE * 0.001)])
    result.append(str(face))
 result.sort()
 return result

func _initialize() -> void:
 var presenter := TablePresentation.new()
 var materials := Models.materials("green_hill")
 Batch.shadow_batch_enabled = false
 for kind: String in ["round", "triangle", "flipper"]:
  var actor := Node3D.new()
  match kind:
   "round": Models.round_bumper(presenter, actor, 0.38, 1.0, materials)
   "triangle": Models.triangle_bumper(presenter, actor, PackedVector2Array([Vector2(-30, 20), Vector2(30, 20), Vector2(0, -20)]), 0.2, materials)
   "flipper": Models.flipper(presenter, actor, 0.6, 0.12, 1.0, materials)
  var before := triangles(actor, false)
  var shadow_before := triangles(actor, true)
  Batch.shadow_batch_enabled = true
  check(Batch.combine_shadows(actor) > 0, kind + " reduces caster submissions")
  check(triangles(actor, false) == before, kind + " retains all visible triangles and normals")
  check(triangles(actor, true) == shadow_before, kind + " retains exact caster triangles, winding and normals")
  check(Batch.combine_shadows(actor) == 0, kind + " shadow combining is idempotent")
  var recipe := preload("res://scripts/endless/visual_recipe.gd").new()
  recipe.capture(actor)
  preload("res://scripts/endless/warm_manifest.gd").new().prepare(recipe)
  var restored := Node3D.new()
  var nodes: Array[Node] = []
  for index in recipe.records.size(): recipe.instantiate_one(index, nodes, restored)
  check(triangles(nodes[0], false) == before and triangles(nodes[0], true) == shadow_before, kind + " bake retains separate visible and shadow geometry")
  restored.free()
  actor.free()
  Batch.shadow_batch_enabled = false
 Batch.shadow_batch_enabled = true
 var empty_actor := Node3D.new()
 for i in 2:
  var node := MeshInstance3D.new()
  node.mesh = ArrayMesh.new()
  empty_actor.add_child(node)
 check(Batch.combine_shadows(empty_actor) == 0 and empty_actor.get_child_count() == 2, "Empty meshes remain untouched without creating an invalid shadow surface")
 empty_actor.free()
 presenter.free()
 print("PINBALL_SHADOW_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
