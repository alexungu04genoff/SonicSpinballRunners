extends SceneTree
## Warmed visual nodes must survive transfer into the live world unchanged.
const Library = preload("res://scripts/endless/template_library.gd")
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const Manifest = preload("res://scripts/endless/warm_manifest.gd")
const Act = preload("res://scripts/endless/streamed_act.gd")
const Flicky = preload("res://scripts/decor/island_flicky.gd")
var checks := 0
var failures := 0

class StreamingHost extends Node:
 var started := true
 var presentation: TablePresentation

class ObservedRecipe extends Recipe:
 var created_ids: Array[int] = []
 func instantiate_one(index: int, nodes: Array[Node], target: Node) -> void:
  super.instantiate_one(index, nodes, target)
  created_ids.append(nodes[-1].get_instance_id())

class ObservedLibrary extends Library:
 var observed_recipe: ObservedRecipe
 var parent_index := -1
 var child_index := -1
 var nested_parent_draws := 0
 var nested_child_draws := 0
 var separate_child_draws := 0
 func _draw_frames(count := 2) -> void:
  var parent: GeometryInstance3D = instance_from_id(observed_recipe.created_ids[parent_index])
  var child: GeometryInstance3D = instance_from_id(observed_recipe.created_ids[child_index])
  if parent != null and parent.is_visible_in_tree() and parent.layers == 4:
   nested_parent_draws += 1
  if child != null and child.is_visible_in_tree() and child.layers == 8:
   nested_child_draws += 1
   if parent.layers == 0: separate_child_draws += 1
  await super._draw_frames(count)

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func run() -> void:
 var host := StreamingHost.new()
 host.presentation = TablePresentation.new()
 host.presentation._key_light = DirectionalLight3D.new()
 host.presentation.add_child(host.presentation._key_light)
 var library := ObservedLibrary.new()
 root.add_child(library)
 library._game = host
 library._view = SubViewport.new()
 library._view.size = Vector2i(64, 64)
 library._view.own_world_3d = true
 library._view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 library.add_child(library._view)
 library.backgrounds.fixture = Recipe.new()
 library.environments.fixture = Environment.new()
 library.lights.fixture = {"rotation": Vector3(-0.6, 0.3, 0), "color": Color.WHITE, "energy": 1.0, "bias": 1.0}

 var authoring := Node3D.new()
 authoring.position = Vector3(2, 0.5, -3)
 authoring.rotation = Vector3(0.1, 0.4, -0.2)
 authoring.scale = Vector3(1.2, 0.8, 1.5)
 var material := StandardMaterial3D.new()
 material.albedo_color = Color.CORNFLOWER_BLUE
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().get_mesh_arrays())
 var hidden := MeshInstance3D.new()
 hidden.mesh = mesh
 hidden.material_override = material
 hidden.position = Vector3(-1, 0.3, 2)
 hidden.rotation = Vector3(0, -0.3, 0.2)
 hidden.extra_cull_margin = 0.75
 hidden.visible = false
 authoring.add_child(hidden)
 var concealed := Node3D.new()
 concealed.name = "ConcealedGroup"
 concealed.visible = false
 authoring.add_child(concealed)
 var nested_parent := MeshInstance3D.new()
 nested_parent.name = "WarmParent"
 nested_parent.mesh = mesh
 nested_parent.layers = 4
 nested_parent.extra_cull_margin = 0.25
 nested_parent.material_override = StandardMaterial3D.new()
 nested_parent.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 concealed.add_child(nested_parent)
 var nested_child := MeshInstance3D.new()
 nested_child.name = "WarmChild"
 nested_child.mesh = mesh
 nested_child.layers = 8
 nested_child.visible = false
 nested_child.extra_cull_margin = 0.5
 nested_child.material_override = StandardMaterial3D.new()
 nested_child.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 nested_parent.add_child(nested_child)
 var bird := Flicky.new()
 bird.position = Vector3(1.5, 0.2, -0.4)
 bird.phase = 0.2
 bird.pose = Node3D.new()
 bird.head = Node3D.new()
 bird.add_child(bird.pose)
 bird.pose.add_child(bird.head)
 for side in [-1, 1]:
  var wing := MeshInstance3D.new()
  wing.mesh = mesh
  wing.material_override = material
  wing.position = Vector3(side * 0.2, 0.1, 0)
  wing.extra_cull_margin = 0.125
  bird.pose.add_child(wing)
  bird.wings.append(wing)
 authoring.add_child(bird)
 var recipe := ObservedRecipe.new()
 recipe.capture(authoring)
 recipe.finish()
 Manifest.new().prepare(recipe)
 library.observed_recipe = recipe
 library.parent_index = recipe.indices[nested_parent.get_instance_id()]
 library.child_index = recipe.indices[nested_child.get_instance_id()]
 check(recipe.error.is_empty() and recipe.has_warm_manifest(), "Fixture has offline warm-up metadata")

 var placement := Transform3D(Basis.from_euler(Vector3(0, 0.7, 0)), Vector3(18, 0, -42))
 var expected_root := Node3D.new()
 expected_root.transform = placement
 root.add_child(expected_root)
 var expected: Array[Node] = []
 for index in recipe.records.size(): recipe.instantiate_one(index, expected, expected_root)
 recipe.created_ids.clear()
 await library._warm_recipe(recipe, "fixture", "act", "fixture:0")
 check(library.nested_parent_draws > 0, "A mesh beneath an authored hidden Node3D is visible during warm-up")
 check(library.nested_child_draws > 0, "An authored hidden child mesh is visible in the warm-up tree")
 check(library.separate_child_draws > 0, "Child draws in a separate batch while its parent mesh is suppressed without hiding descendants")
 check(library._view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Private viewport stops before authored render state is restored")
 var prepared := library.take_prepared_visuals("fixture:0")
 check(prepared.size() == recipe.records.size(), "Warm-up retains every visual node")
 check(library.take_prepared_visuals("fixture:0").is_empty(), "Prepared nodes transfer ownership only once")
 check(library.reused_visual_nodes == prepared.size(), "Reuse diagnostics count transferred nodes")
 for index in prepared.size():
  var node: Node3D = prepared[index]
  check(node.get_instance_id() == recipe.created_ids[index], "Live handoff preserves warmed node identity %d" % index)
  check(node.get_parent() == null, "Prepared node is individually detached %d" % index)
  check(node.transform.is_equal_approx(expected[index].transform), "Warm-up preserves local transform %d" % index)
  check(node.visible == expected[index].visible, "Warm-up restores authored visibility %d" % index)
  check(node.process_mode == Node.PROCESS_MODE_INHERIT, "Prepared nodes inherit staged activation %d" % index)
  if node is GeometryInstance3D:
   check(is_equal_approx(node.extra_cull_margin, expected[index].extra_cull_margin), "Warm-up restores culling bounds %d" % index)
   check(node.layers == expected[index].layers, "Warm-up restores authored render layers %d" % index)

 var live = Act.new()
 live.game = host
 live.recipe = recipe
 live.phase = 2
 live.prepared_nodes = prepared
 live.visual.transform = placement
 live.visual.visible = false
 live.visual.process_mode = Node.PROCESS_MODE_DISABLED
 root.add_child(live.root)
 root.add_child(live.visual)
 var mechanics := Node.new()
 live.root.add_child(mechanics)
 live.runtime = {"mechanics": mechanics}
 for index in recipe.records.size():
  live.step()
  check(live.nodes[index] == prepared[index], "Incremental attachment uses retained node %d" % index)
  check(live.nodes[index].global_transform.is_equal_approx(expected[index].global_transform), "Nested world placement survives transfer %d" % index)
  check(not live.nodes[index].can_process(), "Staged visual remains inactive %d" % index)
 var live_hidden: MeshInstance3D = live.nodes[1]
 check(live_hidden.mesh == mesh and live_hidden.material_override == material, "Meshes and materials retain shared resource identity")
 check(not live_hidden.visible, "Authored hidden geometry stays hidden after attachment")
 live.step()
 check(live.prepared_nodes.is_empty() and live.phase == 3, "Completed attachment releases the staging node list")
 var bird_index: int = recipe.animations[0].index
 var restored: Node = live.nodes[bird_index]
 var values: Dictionary = recipe.animations[0].values
 check(restored.pose == live.nodes[values.pose["$node"]] and restored.head == live.nodes[values.head["$node"]], "Animation indices resolve to retained live nodes")
 check(restored.wings[0] == live.nodes[values.wings[0]["$node"]] and restored.wings[1] == live.nodes[values.wings[1]["$node"]], "Animation arrays preserve both retained wing bindings")
 restored.set_animation_time(0.1)
 check(restored.pose.position.y > 0 and is_zero_approx(bird.pose.position.y), "Transferred animation changes only the live visual")
 live.step()
 check(live.ready and live.visual.visible and live.visual.process_mode == Node.PROCESS_MODE_PAUSABLE, "Activation exposes the completed visual")
 var live_root: Node = live.root
 var live_visual: Node = live.visual
 live = null
 check(is_instance_valid(live_visual) and is_instance_valid(live_hidden), "Releasing a complete Act does not free tree-owned visuals")
 live_root.free()
 live_visual.free()
 expected_root.free()

 recipe.created_ids.clear()
 await library._warm_recipe(recipe, "fixture", "act", "fixture:1")
 var interrupted = Act.new()
 interrupted.recipe = recipe
 interrupted.phase = 2
 interrupted.prepared_nodes = library.take_prepared_visuals("fixture:1")
 var interrupted_ids := recipe.created_ids.duplicate()
 var interrupted_root: Node = interrupted.root
 var interrupted_visual: Node = interrupted.visual
 root.add_child(interrupted_root)
 root.add_child(interrupted_visual)
 interrupted.step()
 interrupted.step()
 interrupted = null
 for index in interrupted_ids.size():
  check(is_instance_id_valid(interrupted_ids[index]) == (index < 2), "Interrupted Act frees only unattached node %d" % index)
 interrupted_root.free()
 interrupted_visual.free()
 check(not is_instance_id_valid(interrupted_ids[0]) and not is_instance_id_valid(interrupted_ids[1]), "Attached nodes remain safely owned until their tree is freed")

 recipe.created_ids.clear()
 await library._warm_recipe(recipe, "fixture", "act", "fixture:2")
 var unclaimed_ids := recipe.created_ids.duplicate()
 library.free()
 for id: int in unclaimed_ids:
  check(not is_instance_id_valid(id), "Library shutdown frees unclaimed prepared node")
 authoring.free()
 host.presentation.free()
 host.free()
 print("ENDLESS_REUSE_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
