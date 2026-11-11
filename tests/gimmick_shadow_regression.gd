extends SceneTree
const Models = preload("res://scripts/authored_act/gimmick_models.gd")
const Shadows = preload("res://scripts/authored_act/gimmick_shadows.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Detail = preload("res://scripts/endless/visual_detail.gd")
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const KINDS := ["one_way_gate", "switch_target", "wall_switch", "drop_target_bank", "slingshot", "spring", "lane_barrier", "diverter", "dash_panel"]
var checks := 0
var failures := 0

class Presenter extends TablePresentation:
 var theme := "green_hill"
 func _pinball_theme_id() -> String: return theme

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func item_for(kind: String) -> Dictionary:
 var item: Dictionary = Objects.make_placement(kind)
 item.object_id = kind
 item.position = Vector2(40, 60)
 item.rotation_degrees = 27.0
 item.properties = Objects.properties(item)
 item.merge({"active": false, "open": false, "pulse": 0.0, "complete": false, "state": "a", "pending_state": ""})
 item.targets = []
 if kind == "drop_target_bank":
  for point: Vector2 in Objects.drop_positions(item): item.targets.append({"retraction": 0.0})
 item.lanes = []
 if kind == "lane_barrier":
  for i in item.properties.points.size() - 1: item.lanes.append({"lit": false})
 return item

func state(entry: Dictionary, index: int) -> void:
 entry.item.active = index > 0
 entry.item.open = index == 1
 entry.item.pulse = 0.1 if index == 1 else 0.0
 entry.item.complete = index == 2
 entry.item.state = "b" if index == 1 else "a"
 entry.item.pending_state = "a" if index == 1 else ""
 for target: Dictionary in entry.item.targets: target.retraction = 1.0 if index == 1 else 0.0
 for lane: Dictionary in entry.item.lanes: lane.lit = index > 0
 Models.update(entry)

func triangles(node: Node3D, shadow: bool, result: Array = []) -> Array:
 if not node.visible: return result
 if node is MeshInstance3D and node.mesh != null:
  var draw: bool = node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if shadow else node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
  if draw:
   for surface in node.mesh.get_surface_count():
    var arrays: Array = node.mesh.surface_get_arrays(surface)
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
    if indices.is_empty():
     for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(i)
    var normal_basis := node.global_basis.inverse().transposed()
    for offset in range(0, indices.size(), 3):
     var face: Array = []
     for i in 3:
      var vertex: Vector3 = node.global_transform * arrays[Mesh.ARRAY_VERTEX][indices[offset + i]]
      var normal: Vector3 = normal_basis * arrays[Mesh.ARRAY_NORMAL][indices[offset + i]]
      face.append([vertex.snapped(Vector3.ONE * 0.001), normal.normalized().snapped(Vector3.ONE * 0.001)])
     result.append(str(face))
 for child: Node in node.get_children():
  if child is Node3D: triangles(child, shadow, result)
 result.sort()
 return result

func detail(node: Node) -> void:
 if node is MeshInstance3D and node.mesh is PrimitiveMesh: node.mesh = Detail.primitive(node.mesh)
 for child: Node in node.get_children(): detail(child)

func visible_resources(node: Node, result: Dictionary = {}) -> Dictionary:
 if node is MeshInstance3D and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
  result[node.get_instance_id()] = [node.mesh, node.material_override, node.material_overlay]
 for child: Node in node.get_children(): visible_resources(child, result)
 return result

func run() -> void:
 var presenter := Presenter.new()
 root.add_child(presenter)
 presenter.set_process(false)
 var report := {}
 for baked: bool in [false, true]:
  for theme: String in Models.STYLES:
   presenter.theme = theme
   for kind: String in KINDS:
    Shadows.enabled = false
    var entry := Models.build(presenter, presenter, item_for(kind))
    if baked: detail(entry.root)
    var reference: Array = []
    for i in 3:
     state(entry, i)
     reference.append([triangles(entry.root, false), triangles(entry.root, true)])
    state(entry, 0)
    var original := visible_resources(entry.root)
    Shadows.enabled = true
    var saved := Shadows.combine(entry.root, baked, [entry.rubber] if kind == "slingshot" else [])
    var label := "%s/%s/%s" % [theme, kind, "baked" if baked else "source"]
    report[label] = saved
    check(saved == 0 if kind == "slingshot" else saved > 0, label + " combines only eligible rigid siblings")
    check(visible_resources(entry.root) == original, label + " keeps source meshes, materials and emitter identities")
    for i in 3:
     state(entry, i)
     check(triangles(entry.root, false) == reference[i][0], label + " visible triangles/normals state " + str(i))
     check(triangles(entry.root, true) == reference[i][1], label + " shadow triangles/winding/normals state " + str(i))
    check(Shadows.combine(entry.root, baked, [entry.rubber] if kind == "slingshot" else []) == 0, label + " repeated combining is inert")
    var recipe := Recipe.new()
    recipe.capture(entry.root)
    var restored := Node3D.new()
    root.add_child(restored)
    var nodes: Array[Node] = []
    for i in recipe.records.size(): recipe.instantiate_one(i, nodes, restored)
    check(triangles(nodes[0], true) == reference[2][1], label + " recipe retains shadow geometry and parent state")
    restored.free()
    entry.root.free()
 print("GIMMICK_SHADOW_SAVINGS | " + JSON.stringify(report))
 exclusions(presenter)
 presenter.free()
 print("GIMMICK_SHADOW_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func exclusions(presenter: Node3D) -> void:
 for mode: String in ["alpha", "cull", "grow", "billboard", "height", "pass", "shader", "rotation", "hidden", "excluded"]:
  var holder := Node3D.new()
  presenter.add_child(holder)
  var excluded: Array = []
  for i in 2:
   var node := MeshInstance3D.new()
   node.mesh = BoxMesh.new()
   var material := StandardMaterial3D.new()
   node.material_override = material
   match mode:
    "alpha": material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    "cull": material.cull_mode = BaseMaterial3D.CULL_DISABLED
    "grow": material.grow = true
    "billboard": material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    "height": material.heightmap_enabled = true
    "pass": material.next_pass = StandardMaterial3D.new()
    "shader": node.material_override = ShaderMaterial.new()
    "rotation": node.rotation.x = 0.5
    "hidden": node.visible = false
    "excluded": excluded.append(node)
   holder.add_child(node)
  check(Shadows.combine(holder, false, excluded) == 0 and holder.get_child_count() == 2, "Unsupported " + mode + " retains its original caster")
  holder.free()
