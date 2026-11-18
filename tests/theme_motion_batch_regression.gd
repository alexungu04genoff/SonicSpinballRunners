extends SceneTree
## Custom background batching preserves motion in the original parent space.
const Preserve = preload("res://scripts/themes/motion_preserve.gd")
const Motion = preload("res://scripts/theme_motion/controller.gd")
var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)

func fixture() -> Node3D:
 var group := Node3D.new()
 var parent := Node3D.new()
 parent.position = Vector3(3, 1, -2)
 parent.basis = Basis(Vector3.UP, 0.7).scaled(Vector3(3.5, 1.8, 2.0))
 group.add_child(parent)
 var fish := MeshInstance3D.new()
 fish.mesh = BoxMesh.new()
 fish.position = Vector3(0.6, 0.4, 0.2)
 fish.rotation.y = 0.3
 fish.set_meta("theme_motion", {"kind":"drift","candidate":"B","axis":Vector3(1,0.18,0),"amplitude":0.2,"period":11.0,"phase":0.7})
 parent.add_child(fish)
 return group

func run() -> void:
 var source := fixture()
 var batch := fixture()
 root.add_child(source)
 root.add_child(batch)
 var original: Node3D = source.get_child(0).get_child(0)
 var moved: Node3D = batch.get_child(0).get_child(0)
 var before := moved.global_transform
 var extracted := Preserve.take(batch)
 Preserve.restore(batch, extracted)
 check(extracted.size() == 1 and moved.get_parent() == batch, "Only explicit moving subtree is retained")
 check(moved.global_transform.is_equal_approx(before), "Flattening preserves exact C geometry")
 var left := Motion.new()
 var right := Motion.new()
 left.configure("aquarium_park")
 right.configure("aquarium_park")
 left.attach(source, true)
 right.attach(batch, true)
 left.select("B", "FULL")
 right.select("B", "FULL")
 for seconds: float in [0.0, 2.75, 7.25, 11.0, 11007.25]:
  left.seek(seconds)
  right.seek(seconds)
  check(original.global_transform.is_equal_approx(moved.global_transform), "Scaled rotated parent motion survives batching at " + str(seconds))
 left.select("C")
 right.select("C")
 check(moved.global_transform.is_equal_approx(before), "Returning to C restores the flattened base")
 source.free()
 batch.free()
 print("RESULT | Theme Motion custom batching | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
