extends SceneTree
## Small presentation-contract regression: all pools, fixed/Auto, transforms,
## collision isolation, and primitive resource sharing.
const LavaTheme = preload("res://scripts/themes/lava_reef_theme.gd")
const Presentation = preload("res://scripts/themes/themed_presentation.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func only_visual(node: Node) -> bool:
 if node is CollisionObject2D or node is CollisionObject3D or node is CollisionShape2D or node is CollisionShape3D: return false
 for child: Node in node.get_children():
  if not only_visual(child): return false
 return true

func _initialize() -> void:
 var theme := LavaTheme.new()
 var skin: RefCounted = theme.create_decor(null)
 var built: Dictionary = {}
 for size: String in ["small", "medium", "large", "landmark"]:
  for hint: String in ["surface", "edge", "either"]:
   var slot := {"slot_id": "exact-angle", "slot_type": size, "placement_hint": hint, "position": Vector2(25, 25), "rotation_degrees": 37.125, "scale": 1.07}
   var pool: Array = skin.variants_for(slot)
   check(pool.size() == (4 if size == "medium" else 3), size + "/" + hint + " has the published variants")
   var automatic: String = skin.resolve("act", slot)
   check(automatic == skin.resolve("act", slot), "Auto is deterministic")
   for i in pool.size():
    slot.variant_mode = "fixed"
    slot.variant_index = i
    check(skin.resolve("different_seed", slot) == pool[i], "Fixed index selects the exact pool entry")
    if not built.has(pool[i]):
     var prop: Node3D = skin.instantiate_slot("act", slot)
     check(only_visual(prop) and prop.get_child_count() > 0, "Original prop is populated and collisionless: " + pool[i])
     built[pool[i]] = true
     prop.free()
   slot.variant_index = 99
   check(not skin.variant_warning(slot).is_empty() and skin.resolve("act", slot) == automatic, "Missing fixed index warns and retains deterministic fallback")
 check(built.size() == 13, "Thirteen distinct original props")
 check(skin.primitive("gem") == skin.primitive("gem"), "Repeated crystals share one mesh")
 var rock: ArrayMesh = skin.primitive("boulder")
 var arrays := rock.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 var outward := true
 for i in range(0,vertices.size(),3):
  var center := (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
  var face := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
  outward = outward and center.dot(face) > 0.0 and face.dot(normals[i]) > 0.99
 check(outward, "Opaque boulder faces point outward without backface holes")
 for kind: String in ["rift_shell", "rift_channels"]:
  var mesh: ArrayMesh = skin.primitive(kind)
  check(mesh == skin.primitive(kind), "Caldera instances share " + kind)
  var data := mesh.surface_get_arrays(0)
  var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
  var directions: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
  var valid := points.size() == directions.size()
  for index in range(0, points.size(), 3):
   var face := (points[index+2]-points[index]).cross(points[index+1]-points[index])
   valid = valid and face.is_finite() and face.length_squared() > 0.00000001
   valid = valid and face.normalized().dot(directions[index]) > 0.99
  check(valid, "Caldera faces have finite clockwise geometry and matching normals: " + kind)
  check(points.size() / 3 <= (36 if kind == "rift_shell" else 24), "Caldera keeps its small static mesh budget: " + kind)
  if kind == "rift_shell":
   var facing := true
   for sector in 6:
    var first := sector * 18
    var radial := Vector3(points[first].x, 0, points[first].z)
    facing = facing and radial.dot(directions[first]) > 0.0
    facing = facing and directions[first + 6].y > 0.99
    facing = facing and radial.dot(directions[first + 12]) < 0.0
   check(facing, "Caldera outer walls, upper rim and inner cavity face their visible sides")
 # Exercise the actual placement path at a non-round authored angle.
 var p := Presentation.new()
 p.set_theme_definition(theme)
 p.terrain_root = Node3D.new()
 p.add_child(p.terrain_root)
 var runtime := {"decor_seed": "placement", "terrain": [{"closed": true, "points": PackedVector2Array([Vector2.ZERO, Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])}], "decor_slots": [{"slot_id": "bench", "slot_type": "medium", "placement_hint": "surface", "position": Vector2(25, 25), "rotation_degrees": 37.125, "scale": 1.07, "variant_mode": "fixed", "variant_index": 0}]}
 p._build_authored_decor(runtime, 50.0)
 check(p.decor_root.get_child_count() == 1, "Supported slot spawns once")
 if p.decor_root.get_child_count() == 1:
  var prop: Node3D = p.decor_root.get_child(0)
  check(is_equal_approx(prop.rotation.y, -deg_to_rad(37.125)), "Exact authored yaw survives")
  check(prop.scale.is_equal_approx(Vector3.ONE * 0.535), "Cell size and authored scale survive")
  check(prop.position.is_equal_approx(Vector3(0.25, 0.325, 0.25)), "Exact authored anchor survives")
  check(prop.get_meta("decor_variant") == "crystal_fan", "Manual variant is used by actual placement")
 p.free()
 print("RESULT | Lava Reef decor | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
