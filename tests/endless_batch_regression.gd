extends SceneTree
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const Batcher = preload("res://scripts/endless/static_batches.gd")
const Assets = preload("res://scripts/endless/bake_assets.gd")
const Flicky = preload("res://scripts/decor/island_flicky.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func box(parent: Node3D, at: Vector3, color: Color = Color.RED) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 var mesh := BoxMesh.new()
 mesh.size = Vector3.ONE * 0.1
 node.mesh = mesh
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 node.material_override = material
 node.position = at
 parent.add_child(node)
 return node

func flatten(recipe: Resource) -> Array:
 var result: Array = []
 var nodes: Array[Node] = []
 var root_node := Node3D.new()
 root.add_child(root_node)
 for i in recipe.records.size(): recipe.instantiate_one(i, nodes, root_node)
 for index in nodes.size():
  var node := nodes[index]
  if node is MeshInstance3D and node.is_visible_in_tree():
   result.append([node.global_transform, node.mesh, node.get_active_material(0)])
  elif node is MultiMeshInstance3D:
   check(node.multimesh.instance_count <= Batcher.MAX_INSTANCES, "Each spatial batch respects its instance bound")
   for i in node.multimesh.instance_count:
    var transform: Transform3D = node.multimesh.get_instance_transform(i)
    if DisplayServer.get_name() == "headless":
     # Dummy rendering has no instance readback. Verify the persisted CPU rows;
     # the same test graphically verifies real RenderingServer readback instead.
     var b: PackedFloat32Array = recipe.records[index].instance_buffer
     var at: int = i * 12
     transform = Transform3D(Basis(Vector3(b[at], b[at+4], b[at+8]), Vector3(b[at+1], b[at+5], b[at+9]), Vector3(b[at+2], b[at+6], b[at+10])), Vector3(b[at+3], b[at+7], b[at+11]))
    result.append([node.global_transform * transform, node.multimesh.mesh, node.material_override])
 root_node.free()
 return result

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var source := Node3D.new()
 source.transform = Transform3D(Basis(Vector3.UP, 0.17), Vector3(0.35, 0.1, 0.2))
 for i in 70:
  var node := box(source, Vector3(0.1 + (i % 7) * 0.04, 0.2, 0.1 + (i / 7) * 0.03))
  node.rotation.y = i * 0.03
  node.scale = Vector3(1.2, 0.9, 1.1)
 for i in 3: box(source, Vector3(0.1 + i * 0.04, 0.3, 0.1), Color.BLUE)
 for i in 3: box(source, Vector3(8.1 + i * 0.04, 0.3, 0.1))
 var moving := Node3D.new()
 source.add_child(moving)
 for i in 3: box(moving, Vector3(0.3 + i * 0.04, 0.5, 0.3))
 var ring := box(source, Vector3(0.6, 0.6, 0.6))
 var hidden := Node3D.new()
 hidden.visible = false
 source.add_child(hidden)
 for i in 3: box(hidden, Vector3(0.2, 0.2, 0.2))
 var native := MultiMeshInstance3D.new()
 native.multimesh = MultiMesh.new()
 native.multimesh.transform_format = MultiMesh.TRANSFORM_3D
 native.multimesh.mesh = BoxMesh.new()
 native.multimesh.instance_count = 3
 native.material_override = StandardMaterial3D.new()
 native.material_override.albedo_color = Color.GREEN
 var theme = preload("res://scripts/themes/theme_definition.gd").new()
 for i in 3: theme._set_instance_transform(native.multimesh, i, Transform3D(Basis.IDENTITY, Vector3(15 + i, 0, 0)))
 source.add_child(native)
 var bird := Flicky.new()
 source.add_child(bird)
 bird.pose = Node3D.new()
 bird.add_child(bird.pose)
 bird.head = box(bird.pose, Vector3(0.5, 0.2, 0.5))
 for i in 2: bird.wings.append(box(bird.pose, Vector3(0.5 + i * 0.1, 0.3, 0.5)))
 var recipe := Recipe.new()
 recipe.capture(source)
 recipe.finish()
 check(recipe.error.is_empty(), "Native theme instances retain CPU transforms in headless capture")
 recipe.flippers.append(recipe.indices[moving.get_instance_id()])
 recipe.retracted.append(recipe.indices[ring.get_instance_id()])
 recipe.rings.append(recipe.indices[ring.get_instance_id()])
 recipe.bumpers[7] = recipe.indices[moving.get_instance_id()]
 var assets := Assets.new()
 assets.share(recipe)
 check(assets.error.is_empty(), "Fixture resources canonicalize before batching")
 var before := flatten(recipe)
 var stats := Batcher.new().optimize(recipe)
 check(stats.instances == 76 and stats.batches == 4, "Repeated meshes batch by full material, spatial cell and size limit")
 check(stats.records_after < stats.records_before - 60, "Static instancing removes substantial scene-node work")
 var after := flatten(recipe)
 check(before.size() == after.size(), "Every visible mesh instance survives")
 for original: Array in before:
  var matched := -1
  for i in after.size():
   if original[0].is_equal_approx(after[i][0]) and original[1] == after[i][1] and original[2].albedo_color == after[i][2].albedo_color:
    matched = i
    break
  check(matched >= 0, "World transform, geometry, normals/UV source and exact material color survive")
  if matched >= 0: after.remove_at(matched)
 var path := "res://test-results/spatial-recipe.res"
 check(ResourceSaver.save(recipe, path, ResourceSaver.FLAG_COMPRESS) == OK, "Batched recipe saves to disk")
 var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
 check(restored.batch_stats == stats and Batcher.new().optimize(restored) == stats, "Batch metadata survives and repeated optimization is a no-op")
 for index in recipe.records.size():
  if recipe.records[index].has("instance_buffer"):
   check(restored.records[index].instance_buffer == recipe.records[index].instance_buffer and restored.records[index].instance_bounds == recipe.records[index].instance_bounds, "Disk reload retains every instance row and culling bounds exactly")
 var parent := Node3D.new()
 root.add_child(parent)
 var nodes: Array[Node] = []
 for i in restored.records.size(): restored.instantiate_one(i, nodes, parent)
 restored.bind_animations(nodes, null)
 var restored_bird: Node = nodes[restored.animations[0].index]
 check(restored_bird.head is MeshInstance3D and restored_bird.wings.size() == 2, "Animation node references remap after static record removal")
 restored_bird.set_animation_time(0.1)
 check(restored_bird.pose.position.y > 0.0, "Rebound animation still updates its own nodes")
 check(nodes[restored.flippers[0]].get_child_count() == 3 and restored.bumpers[7] == restored.flippers[0], "Flipper descendants and bumper bindings remain individual nodes")
 check(nodes[restored.rings[0]] is MeshInstance3D and restored.rings == restored.retracted, "Ring and retracted-flipper indices remain valid")
 var batcher := Batcher.new()
 var red := StandardMaterial3D.new()
 red.albedo_color = Color.RED
 var blue: StandardMaterial3D = red.duplicate()
 blue.albedo_color = Color.BLUE
 check(batcher._digest(batcher._value_key(red)) != batcher._digest(batcher._value_key(blue)), "Batching does not reuse the color-insensitive shader warm-up key")
 red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 check(not batcher._material_safe(red), "Transparent meshes retain individual sorting")
 var shader := Shader.new()
 shader.code = "shader_type spatial; void vertex() { VERTEX.x += float(INSTANCE_ID); }"
 var material := ShaderMaterial.new()
 material.shader = shader
 check(not batcher._material_safe(material), "Shaders with per-instance identity remain separate")
 parent.free()
 source.free()
 print("ENDLESS_BATCH_REGRESSION | checks=%d failures=%d | %s" % [checks, failures, stats])
 quit(1 if failures else 0)
