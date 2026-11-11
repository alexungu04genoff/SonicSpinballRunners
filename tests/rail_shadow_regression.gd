extends "res://tests/gimmick_shadow_regression.gd"
const Fixture = preload("res://tests/rail_shadow_fixture.gd")

func run() -> void:
 var controls := [
  PackedVector2Array([Vector2(0,400),Vector2(0,0)]),
  PackedVector2Array([Vector2(0,500),Vector2(0,200),Vector2(220,50),Vector2(450,200),Vector2(450,500)]),
  PackedVector2Array([Vector2(-200,300),Vector2(-230,80),Vector2(0,-120),Vector2(250,20)])]
 var report: Array = []
 for theme: String in Fixture.Registry.IDS:
  for path_index in controls.size():
   var fixture := await Fixture.build(root,theme,controls[path_index])
   var original_path: Dictionary = fixture.item.path.duplicate(true)
   var rail: Node3D = fixture.rail
   # Exercise translated, rotated and mirrored owners; local cell membership
   # never depends on where a streamed Act is placed in the larger run.
   fixture.presenter.position = Vector3(1,0,-8)
   fixture.presenter.rotation.y = 0.31
   if path_index == 2: fixture.presenter.scale.x = -1.0
   detail(rail)
   var visible_before := triangles(rail,false)
   var shadow_before := shadow_faces(rail)
   var resources := visible_resources(rail)
   var inventory_before := Fixture.inventory(rail)
   var saved := Fixture.combine(rail)
   var label := theme + "/" + str(path_index)
   check(saved > 0,label + " reduces eligible support casters")
   check(visible_resources(rail) == resources and triangles(rail,false) == visible_before,label + " keeps visible meshes/materials and transformed geometry")
   check(same_faces(shadow_faces(rail),shadow_before),label + " preserves shadow triangles/winding/normals")
   check(fixture.item.path == original_path,label + " leaves authoritative path samples untouched")
   var bounded := true
   for node: Node in rail.find_children("*","MeshInstance3D",true,false):
    if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
    var box: AABB = node.get_aabb()
    bounded = bounded and maxf(box.size.x,box.size.z) <= 4.001
   check(bounded,label + " bounds each combined footprint to twice the cell width")
   check(Fixture.combine(rail) == 0,label + " combining twice is inert")
   var recipe := Recipe.new()
   recipe.capture(rail)
   var restored := Node3D.new()
   root.add_child(restored)
   restored.transform = fixture.presenter.transform
   var nodes: Array[Node] = []
   for i in recipe.records.size(): recipe.instantiate_one(i,nodes,restored)
   check(same_faces(shadow_faces(nodes[0]),shadow_before),label + " preserves caster geometry through recipe reconstruction")
   report.append({"theme":theme,"path":path_index,"original":inventory_before,"combined":Fixture.inventory(rail),"saved_nodes":saved})
   restored.free()
   fixture.presenter.free()
   await process_frame
 spatial_checks()
 print("RAIL_SHADOW_INVENTORY | " + JSON.stringify(report))
 print("RAIL_SHADOW_REGRESSION | checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)

func shadow_faces(node: Node3D, result: Dictionary = {}) -> Dictionary:
 if not node.visible: return result
 if node is MeshInstance3D and node.mesh != null and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
  for surface in node.mesh.get_surface_count():
   var arrays: Array = node.mesh.surface_get_arrays(surface)
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
   if indices.is_empty():
    for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(i)
   var normal_basis := node.global_basis.inverse().transposed()
   for offset in range(0,indices.size(),3):
    var face := PackedVector3Array()
    for i in 3:
     face.append(node.global_transform * arrays[Mesh.ARRAY_VERTEX][indices[offset+i]])
     face.append((normal_basis * arrays[Mesh.ARRAY_NORMAL][indices[offset+i]]).normalized())
    result[face] = result.get(face,0) + 1
 for child: Node in node.get_children():
  if child is Node3D: shadow_faces(child,result)
 return result

func same_faces(a: Dictionary, b: Dictionary) -> bool:
 var remaining := b.duplicate()
 var unmatched: Array = []
 for face: PackedVector3Array in a:
  var common := mini(a[face],remaining.get(face,0))
  if remaining.has(face): remaining[face] -= common
  for i in a[face] - common: unmatched.append(face)
 for face: PackedVector3Array in unmatched:
  var found := false
  for other: PackedVector3Array in remaining:
   if remaining[other] == 0: continue
   var matches := true
   # Baking translation into float vertices changes operation order under a
   # rotated parent. Compare actual distance, not rounding across a grid edge.
   for i in face.size(): matches = matches and face[i].distance_to(other[i]) < 0.00001
   if matches:
    remaining[other] -= 1
    found = true
    break
  if not found: return false
 for count: int in remaining.values():
  if count != 0: return false
 return true

func spatial_checks() -> void:
 var holder := Node3D.new()
 root.add_child(holder)
 var sources: Array[MeshInstance3D] = []
 for x: float in [-3.8,-3.5,0.2,0.5,6.0]:
  var node := MeshInstance3D.new()
  node.mesh = BoxMesh.new()
  node.mesh.size = Vector3(0.1,0.5,0.1)
  node.material_override = StandardMaterial3D.new()
  node.position.x = x
  holder.add_child(node)
  sources.append(node)
 var long_deck := MeshInstance3D.new()
 long_deck.mesh = BoxMesh.new()
 long_deck.mesh.size = Vector3(10,0.1,0.4)
 long_deck.material_override = StandardMaterial3D.new()
 holder.add_child(long_deck)
 check(Shadows.combine(holder,false,[],2.0) == 2,"Separate positive/negative cells combine their own pairs")
 check(sources[-1].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"An isolated post keeps its individual caster")
 check(long_deck.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"Long standard-material decks cannot widen a post batch")
 holder.free()
