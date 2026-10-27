extends SceneTree
const Retirement = preload("res://scripts/endless/resource_retirement.gd")
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const Library = preload("res://scripts/endless/template_library.gd")
var checks := 0
var failures := 0

class Link extends Resource:
 static var inspections := 0
 @export var children: Array[Resource] = []
 @export var retirement_dependencies: Array[Resource] = []
 func _get_property_list() -> Array[Dictionary]:
  inspections += 1
  return []

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func _initialize() -> void:
 call_deferred("run")

func mesh_reference(resources: Array) -> WeakRef:
 for resource: Resource in resources:
  if resource is ArrayMesh: return weakref(resource)
 return null

func drain(queue: RefCounted, limit := 100000) -> void:
 var iterations := 0
 while queue.pending_count() > 0 and iterations < limit:
  queue.step(1, 1000000)
  iterations += 1
  if queue.last_steps > 1 or queue.last_releases > 1:
   check(false, "A one-step slice never releases several dependency pins")
   return
 check(queue.pending_count() == 0, "Retirement finishes within its bounded test workload")

func run() -> void:
 var queue := Retirement.new()
 var shared := Link.new()
 var leaf := Link.new()
 shared.children.append(leaf)
 var first := Link.new()
 var second := Link.new()
 first.children.append(shared)
 second.children.append(shared)
 var owner := Link.new()
 owner.children.assign([first, second])
 var references: Array[WeakRef] = [weakref(owner), weakref(first), weakref(second), weakref(shared), weakref(leaf)]
 owner.retirement_dependencies = Retirement.dependencies(owner)
 check(not owner.retirement_dependencies.has(owner), "The offline manifest excludes its owner")
 check(owner.retirement_dependencies.find(shared) < owner.retirement_dependencies.find(leaf), "The manifest orders shared owners before their children")
 check(Retirement.dependencies(owner) == owner.retirement_dependencies, "A stored manifest is excluded from dependency discovery")
 Link.inspections = 0
 check(queue.enqueue(owner, owner.retirement_dependencies), "The cache can hand off a baked shared dependency graph")
 owner = null
 first = null
 second = null
 shared = null
 leaf = null
 check(references[0].get_ref() != null, "Enqueue holds the owner before the caller drops its reference")
 var previously_alive := references.size()
 var iterations := 0
 while queue.pending_count() > 0 and iterations < 10000:
  queue.step(1, 1000000)
  var alive := 0
  for reference: WeakRef in references:
   if reference.get_ref() != null: alive += 1
  check(previously_alive - alive <= 1, "A single release cannot cascade through the shared resource graph")
  previously_alive = alive
  iterations += 1
 check(previously_alive == 0 and queue.pending_count() == 0, "All unreferenced owners and dependencies are released")
 check(Link.inspections == 0, "Baked retirement performs no runtime property inspection")

 var material := StandardMaterial3D.new()
 material.albedo_color = Color.CORAL
 var node := MeshInstance3D.new()
 var mesh := ArrayMesh.new()
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 mesh.surface_set_material(0, material)
 node.mesh = mesh
 var recipe := Recipe.new()
 recipe.capture(node)
 var mesh_ref: WeakRef = weakref(mesh)
 var recipe_ref: WeakRef = weakref(recipe)
 node.free()
 mesh = null
 var manifest := Retirement.dependencies(recipe)
 check(manifest.has(mesh_ref.get_ref()) and manifest.has(material), "The offline manifest discovers SceneState and mesh surface dependencies")
 recipe.retirement_dependencies = manifest
 var path := "res://test-results/endless-retirement-recipe.res"
 check(ResourceSaver.save(recipe, path, ResourceSaver.FLAG_COMPRESS) == OK, "Dependency manifests save with the visual recipe")
 var restored: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
 check(restored != null and restored.retirement_dependencies.size() == manifest.size(), "Dependency manifests survive loading from disk")
 var restored_mesh: WeakRef = mesh_reference(restored.retirement_dependencies)
 check(restored_mesh != null, "The persisted manifest retains the mesh dependency")
 check(queue.enqueue(restored, restored.retirement_dependencies), "A loaded manifest works without rebuilding its dependency graph")
 restored = null
 check(queue.enqueue(recipe, manifest), "PackedScene recipe dependencies can be retired without instantiation")
 recipe = null
 manifest = []
 drain(queue)
 check(mesh_ref.get_ref() == null and recipe_ref.get_ref() == null, "SceneState and mesh pins are released after retirement")
 check(restored_mesh != null and restored_mesh.get_ref() == null, "Loaded dependency pins are released after retirement")
 check(material.albedo_color == Color.CORAL, "A shared external material remains alive and unchanged")

 var retained := Link.new()
 var retained_leaf := Link.new()
 retained.children.append(retained_leaf)
 check(queue.enqueue_unbaked(retained), "An externally retained owner may enter fallback retirement")
 drain(queue)
 check(retained.children.size() == 1 and retained.children[0] == retained_leaf, "Retirement does not mutate caller-owned dependencies")

 var cycle := Link.new()
 cycle.children.append(cycle)
 var cycle_ref: WeakRef = weakref(cycle)
 check(queue.enqueue_unbaked(cycle), "A cyclic resource graph is accepted")
 drain(queue)
 check(cycle.children[0] == cycle, "Retirement does not break shared resource cycles")
 cycle.children.clear()
 cycle = null
 check(cycle_ref.get_ref() == null, "The queue retains no cyclic graph after its pins drain")

 var array_cycle: Array = []
 array_cycle.append(array_cycle)
 check(queue.enqueue_unbaked(array_cycle), "A cyclic container is accepted")
 drain(queue)
 check(is_same(array_cycle[0], array_cycle), "Retirement leaves caller container identity intact")
 array_cycle.clear()

 for index in Retirement.MAX_PENDING:
  check(queue.enqueue(Link.new(), []), "Retirement accepts work up to its queue bound")
 var refused := Link.new()
 var refused_ref: WeakRef = weakref(refused)
 check(not queue.enqueue(refused, []), "A full queue applies backpressure before the cache erases an owner")
 refused = null
 check(refused_ref.get_ref() == null, "Rejected work is not silently retained")
 check(queue.step(0, 1000000) == 0 and queue.step(1, 0) == 0, "Zero budget does no work")
 drain(queue)
 check(queue.peak_pending == Retirement.MAX_PENDING, "The pending graph bound is enforced")
 var library := Library.new()
 root.add_child(library)
 library.set_process(false)
 var first_root: WeakRef
 for id in 10:
  var physics_root := Node2D.new()
  for child_index in 4:
   var child := Node2D.new()
   child.add_child(Node2D.new())
   physics_root.add_child(child)
  if id == 0: first_root = weakref(physics_root)
  library.runtimes[id] = {"root": physics_root}
  library.shapes[id] = []
 var pinned := [{"theme": "green_hill", "id": 9}]
 check(not library.trim(pinned), "A second physics eviction waits for the first retirement")
 check(library.runtimes.size() == 9 and library.runtimes.has(9), "Only one unpinned physics owner leaves the cache")
 check(first_root.get_ref() != null, "Cache eviction does not synchronously free a physics tree")
 check(library._step_physics_retirement(0) == 0 and library._step_physics_retirement(1, 0) == 0, "Physics retirement respects zero budgets")
 var steps := 0
 while not library._retiring_physics.is_empty() and steps < 100:
  check(library._step_physics_retirement(1, 1000000) == 1, "A physics slice performs at most one traversal or node free")
  steps += 1
 check(first_root.get_ref() == null and library._retiring_runtime.is_empty(), "Retired physics nodes and their owner are released")
 check(library.trim(pinned) and library.runtimes.size() == library.MAX_VARIANTS, "Draining allows the next eviction and restores the cache bound")
 library.free()
 print("ENDLESS_RETIREMENT_REGRESSION | checks=", checks, " | failures=", failures)
 quit(0 if failures == 0 else 1)
