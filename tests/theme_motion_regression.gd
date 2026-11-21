extends SceneTree
## Contract checks, not artistic amplitude snapshots. No GPU or authored-data writes.
const Motion = preload("res://scripts/theme_motion/controller.gd")
const Registry = preload("res://scripts/theme_motion/registry.gd")
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const Batches = preload("res://scripts/endless/static_batches.gd")
const Bounds = preload("res://scripts/endless/foreground_contribution.gd")
var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)

func run() -> void:
 check(Registry.IDS == ["green_hill", "casino_night", "ice_cap", "rooftop_run", "aquarium_park"], "Motion supports the five base-game themes in roster order")
 for theme: String in Registry.IDS:
  var owner := Motion.new()
  owner.configure(theme)
  var expected := "B" if theme == "casino_night" else "C"
  check(Registry.PRODUCTION[theme] == expected and owner.candidate == expected and owner.tier == "NATIVE", theme + " uses the reviewed production selection")
 check(not Registry.binding_error({"kind":"arbitrary_script"}).is_empty(), "Unknown binding rejected")
 check(not Registry.binding_error({"kind":"drift","candidate":"A","axis":Vector3.UP,"period":0.0,"amplitude":1.0}).is_empty(), "Invalid period rejected")
 var source := Node3D.new()
 root.add_child(source)
 var moving := Node3D.new()
 moving.position = Vector3(2, 1, -3)
 moving.set_meta("theme_motion", {"kind":"drift","candidate":"A","axis":Vector3.RIGHT,"period":8.0,"amplitude":0.3,"phase":0.0})
 source.add_child(moving)
 var material := ShaderMaterial.new()
 material.shader = load("res://scripts/themes/green_hill_ocean.gdshader")
 for i in 4:
  var mesh := MeshInstance3D.new()
  mesh.mesh = BoxMesh.new()
  mesh.material_override = material
  moving.add_child(mesh)
 var original := moving.transform
 var motion := Motion.new()
 motion.configure("green_hill")
 motion.attach(source)
 check(moving.transform == original and material.get_shader_parameter("time_override") == -1.0, "Ordinary C is neutral")
 check(not motion.select("Q") and not motion.seek(INF) and not motion.seek(-2.0), "Invalid diagnostics rejected")
 check(motion.select("A", "FULL") and motion.seek(2.0), "Candidate selection and explicit seek")
 var pose := moving.transform
 check(pose != original and material.get_shader_parameter("time_override") == 2.0, "Node and shader share deterministic time")
 motion.seek(8002.0)
 check(moving.transform.is_equal_approx(pose), "Bounded loop has no accumulated drift")
 motion.seek(2.0)
 motion.update(3.0)
 check(moving.transform == pose, "Explicit time remains paused across updates")
 var second := Motion.new()
 var second_root := Node3D.new()
 root.add_child(second_root)
 var second_mesh := MeshInstance3D.new()
 second_mesh.mesh = BoxMesh.new()
 var private_material: ShaderMaterial = material.duplicate()
 second_mesh.material_override = private_material
 second_root.add_child(second_mesh)
 second.configure("green_hill", 1)
 second.attach(second_root)
 second.seek(7.25)
 check(material.get_shader_parameter("time_override") == 2.0 and private_material.get_shader_parameter("time_override") == 7.25, "Resident Zones retain independent material times")
 var multi := MultiMeshInstance3D.new()
 multi.multimesh = MultiMesh.new()
 multi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
 var unused: ShaderMaterial = material.duplicate()
 unused.set_shader_parameter("time_override", 123.0)
 var multi_mesh := BoxMesh.new()
 multi_mesh.material = unused
 multi.multimesh.mesh = multi_mesh
 multi.material_override = private_material
 second_root.add_child(multi)
 second.attach(second_root)
 second.seek(6.0)
 check(unused.get_shader_parameter("time_override") == 123.0, "Unused MultiMesh source material remains untouched")
 var bird_root := Node3D.new()
 bird_root.process_mode = Node.PROCESS_MODE_ALWAYS
 root.add_child(bird_root)
 var bird := preload("res://scripts/decor/island_flicky.gd").new()
 bird.pose = Node3D.new()
 bird.head = Node3D.new()
 bird.add_child(bird.pose)
 bird.pose.add_child(bird.head)
 bird.process_mode = Node.PROCESS_MODE_PAUSABLE
 bird_root.add_child(bird)
 var birds := Motion.new()
 birds.configure("green_hill")
 birds.attach(bird_root, true)
 birds.update(0.0, true)
 check(bird.is_processing(), "Visible background retains native Flicky callback")
 birds.update(0.1, false)
 check(not bird.is_processing() and birds.stats().cpu_callbacks == 0, "Zero-weight background disables explicit PAUSABLE Flicky callback")
 birds.update(0.1, true)
 check(bird.is_processing(), "Revealing background restores native callback")
 birds.seek(0.24)
 var bird_pose := bird.pose.transform
 birds.update(4.0, true)
 check(not bird.is_processing() and bird.pose.transform == bird_pose, "Deterministic Flicky time ignores native callbacks")
 birds.seek(-1.0)
 paused = true
 var bird_time: float = bird.animation_time
 await process_frame
 await process_frame
 check(bird.animation_time == bird_time, "Native Flicky respects scene pause despite always-processing ancestor")
 paused = false
 bird_root.free()
 birds.release()
 motion.select("A", "STATIC")
 var static_pose := moving.transform
 motion.seek(9.0)
 check(moving.transform == static_pose and material.get_shader_parameter("time_override") == 0.0, "STATIC suppresses all environmental time")
 motion.select("C", "NATIVE")
 motion.seek(-1.0)
 check(moving.transform == original and material.get_shader_parameter("time_override") == -1.0, "Return to native C restores exact base")
 motion.select("A", "FULL")
 var foreground_pose := moving.transform
 motion.update(0.75, false)
 check(moving.transform != foreground_pose, "Foreground motion remains live while background weight is zero")
 moving.hide()
 var retired_pose := moving.transform
 motion.update(0.75, true)
 check(moving.transform == retired_pose, "Hidden retiring subtree receives no live transform updates")
 moving.show()
 motion.select("C", "NATIVE")
 var recipe := Recipe.new()
 recipe.capture(source)
 recipe.finish()
 Batches.new().optimize(recipe)
 check(recipe.error.is_empty(), "Explicit metadata captures without arbitrary scripts")
 var path := "res://test-results/theme-motion-contract.res"
 DirAccess.make_dir_recursive_absolute("res://test-results")
 check(ResourceSaver.save(recipe, path) == OK, "Recipe serializes to disk")
 var disk: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
 var restored := Node3D.new()
 root.add_child(restored)
 var nodes: Array[Node] = []
 for i in disk.records.size(): disk.instantiate_one(i, nodes, restored)
 disk.bind_animations(nodes, null)
 var tagged: Array[Node] = nodes.filter(func(n: Node): return n.has_meta("theme_motion"))
 check(tagged.size() == 1 and tagged[0].get_child_count() == 4, "Metadata and moving subtree survive disk and static batching")
 var bounds := Bounds.new()
 bounds._collect(restored)
 check(bounds.valid and bounds.supported and bounds.bounds.size.is_finite(), "Motion receives finite contribution bounds")
 var malformed := Node3D.new()
 malformed.set_meta("theme_motion", "invalid")
 bounds._collect(malformed)
 check(not bounds.supported, "Invalid runtime metadata fails open without a type error")
 malformed.free()
 var bounded_root := Node3D.new()
 root.add_child(bounded_root)
 var bounded_mesh := MeshInstance3D.new()
 bounded_mesh.mesh = BoxMesh.new()
 bounded_mesh.position.x = 2.0
 bounded_mesh.set_meta("theme_motion", {"kind":"drift", "candidate":"B", "axis":Vector3.RIGHT, "amplitude":2.0, "period":8.0, "phase":PI * 0.5})
 bounded_root.add_child(bounded_mesh)
 var rest_bounds := Bounds.new()
 rest_bounds._collect(bounded_root)
 var bounded_motion := Motion.new()
 bounded_motion.configure("aquarium_park")
 bounded_motion.select("B", "FULL")
 bounded_motion.attach(bounded_root)
 var extremes_inside := true
 for seconds: float in [0.0, 4.0]:
  bounded_motion.seek(seconds)
  var box: AABB = bounded_mesh.global_transform * bounded_mesh.mesh.get_aabb()
  for corner in 8: extremes_inside = extremes_inside and rest_bounds.bounds.has_point(box.get_endpoint(corner))
 check(extremes_inside, "Rest-pose contribution bounds enclose both extrema after nonzero candidate phase attachment")
 bounded_root.free()
 bounded_motion.release()
 var reference: WeakRef = weakref(moving)
 source.free()
 motion.update(0.1, false)
 check(reference.get_ref() == null and motion.cpu_motion_usec == 0, "Zone controller does not retain nodes or update hidden scenery")
 second_root.free()
 restored.free()
 motion.release()
 second.release()
 check(motion.stats().bindings == 0, "Explicit release clears registrations")
 print("RESULT | Theme Motion | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
