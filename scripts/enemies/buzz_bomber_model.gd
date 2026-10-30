extends RefCounted
## Original low-poly mechanical wasp, built from primitives. No collision nodes.

static func build(table: TablePresentation, parent: Node3D, item: Dictionary) -> Dictionary:
 var root := Node3D.new()
 root.name = "BuzzBomber_" + str(item.object_id)
 root.position = table.map_point(item.position, 28.0 * table.SCALE)
 root.scale = Vector3.ONE * float(item.properties.scale)
 parent.add_child(root)
 var body := Node3D.new()
 root.add_child(body)
 var blue := table.material(Color("166db8"), 0.45)
 var dark := table.material(Color("102237"), 0.25)
 var yellow := table.material(Color("ffcc32"), 0.35)
 var silver := table.material(Color("b6e3f0"), 0.65)
 var red := table.material(Color("ff4d54"), 0.2)
 _sphere(table, body, Vector3(-11, 0, 0), Vector3(30, 22, 25), yellow)
 for x in [-20, -10, 0]:
  var band := table.cylinder(11.5 * table.SCALE, 4.0 * table.SCALE)
  band.radial_segments = 12
  var stripe := table.mesh_node(band, dark, Vector3(x, 0, 0) * table.SCALE, body)
  stripe.rotation.z = PI * 0.5
 _sphere(table, body, Vector3(11, 2, 0), Vector3(27, 25, 25), blue)
 _box(table, body, Vector3(23, 1, 0), Vector3(9, 13, 18), dark)
 for side in [-1.0, 1.0]:
  _box(table, body, Vector3(24, 5, side * 7), Vector3(8, 5, 4), red)
  _box(table, body, Vector3(8, -11, side * 12), Vector3(5, 14, 5), silver).rotation.x = side * 0.45
  _box(table, body, Vector3(14, -17, side * 15), Vector3(15, 5, 7), blue)
 # A small tail spike, not a projectile or a damaging collision shape.
 var spike := CylinderMesh.new()
 spike.top_radius = 0
 spike.bottom_radius = 5 * table.SCALE
 spike.height = 14 * table.SCALE
 spike.radial_segments = 6
 var stinger := table.mesh_node(spike, silver, Vector3(-31, 0, 0) * table.SCALE, body)
 stinger.rotation.z = PI * 0.5
 var wings: Array[Node3D] = []
 for side in [-1.0, 1.0]:
  var hinge := Node3D.new()
  hinge.position = Vector3(1, 10, side * 7) * table.SCALE
  body.add_child(hinge)
  for x in [-7.0, 7.0]:
   var wing := _box(table, hinge, Vector3(x, 3, side * 17), Vector3(9, 2.5, 32), silver)
   wing.rotation.y = side * (0.18 if x > 0 else -0.25)
   _box(table, hinge, Vector3(x, 4.5, side * 19), Vector3(3, 1, 21), blue).rotation.y = wing.rotation.y
  wings.append(hinge)
 var flash := _sphere(table, root, Vector3.ZERO, Vector3(45, 32, 45), table.material(Color("fff1a0"), 0.0))
 flash.visible = false
 return {"item": item, "root": root, "body": body, "wings": wings, "flash": flash, "base": root.position}

static func _box(table: TablePresentation, parent: Node3D, at: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
 var mesh := BoxMesh.new()
 mesh.size = size_value * table.SCALE
 return table.mesh_node(mesh, material, at * table.SCALE, parent)

static func _sphere(table: TablePresentation, parent: Node3D, at: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
 var mesh := SphereMesh.new()
 mesh.radius = 0.5
 mesh.height = 1.0
 mesh.radial_segments = 12
 mesh.rings = 6
 var node := table.mesh_node(mesh, material, at * table.SCALE, parent)
 node.scale = size_value * table.SCALE
 return node

static func update(entry: Dictionary, elapsed: float) -> void:
 var item: Dictionary = entry.item
 var root: Node3D = entry.root
 root.visible = item.alive or item.death_remaining > 0.0
 var displacement: Vector2 = item.position - item.anchor
 root.position = entry.base + Vector3(displacement.x, sin(elapsed * 3.8) * 2.5, displacement.y) * TablePresentation.SCALE
 root.rotation.y = PI if item.direction < 0.0 else 0.0
 entry.body.visible = item.alive
 entry.flash.visible = not item.alive and item.death_remaining > 0.0
 if item.alive:
  for i in entry.wings.size():
   entry.wings[i].rotation.x = sin(elapsed * 45) * 0.38 * (-1 if i == 0 else 1)
 else:
  var progress := 1.0 - float(item.death_remaining) / 0.28
  entry.flash.scale = Vector3(45, 32, 45) * TablePresentation.SCALE * (1.0 + progress * 1.5)
  entry.flash.transparency = clampf(progress, 0, 1)
