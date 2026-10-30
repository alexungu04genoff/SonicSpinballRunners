extends RefCounted
## Original primitive-mesh interpretation of the classic Buzz Bomber silhouette.
## The portrait plane faces the camera; collision remains entirely in 2D.
const VISUAL_SCALE := 0.39
const HOVER_HEIGHT := 10.5

static func build(table: TablePresentation, parent: Node3D, item: Dictionary) -> Dictionary:
 var root := Node3D.new()
 root.name = "BuzzBomber_" + str(item.object_id)
 root.position = table.map_point(item.position, HOVER_HEIGHT * table.SCALE)
 root.scale = Vector3.ONE * float(item.properties.scale) * VISUAL_SCALE
 parent.add_child(root)
 var pose := Node3D.new()
 root.add_child(pose)
 var body := Node3D.new()
 pose.add_child(body)
 var blue := table.material(Color("178ed2"), 0.25)
 var cyan := table.material(Color("36b9e8"), 0.2)
 var dark := table.material(Color("142330"), 0.25)
 var stripe := table.material(Color("153f99"), 0.25)
 var gold := table.material(Color("ffc536"), 0.3)
 var silver := table.material(Color("b9cedb"), 0.4)
 var wing_material := table.material(Color("d7edf1"), 0.1)
 var white := table.material(Color("f6f5e8"), 0.05)
 var pupil := table.material(Color("062237"), 0.05)
 _sphere(table, body, Vector3(-3, 3, 0), Vector3(30, 28, 25), dark)
 _abdomen(table, body, blue, stripe)
 _cone(table, body, Vector3(12, -34, 0), Vector3(17, -45, 0), 4.5, 0, silver)
 _sphere(table, body, Vector3(15, 7, 0), Vector3(25, 25, 23), cyan)
 # Paired eyes, jaws and antennae remain visible when the enemy turns around.
 for side in [-1.0, 1.0]:
  _sphere(table, body, Vector3(24, 10, side * 7), Vector3(10, 14, 10), white)
  _sphere(table, body, Vector3(28, 10, side * 8.5), Vector3(3, 6, 4), pupil)
  _cone(table, body, Vector3(24, -1, side * 7), Vector3(21, -10, side * 4.5), 4, 0, silver)
  _cone(table, body, Vector3(13, 17, side * 7), Vector3(16, 27, side * 8), 1.3, 1.0, gold)
  _sphere(table, body, Vector3(20, 27, side * 8), Vector3(15, 4, 6), gold)
  # Stubby cylindrical silver arms, not the previous long rectangular legs.
  _sphere(table, body, Vector3(1, -3, side * 15), Vector3(9, 9, 9), silver)
  _cone(table, body, Vector3(1, -3, side * 16), Vector3(-16, -3, side * 16), 5, 5, silver)
  _cone(table, body, Vector3(-16, -3, side * 16), Vector3(-18, -3, side * 16), 5.5, 5.5, dark)
 var wings: Array[Node3D] = []
 for side in [-1.0, 1.0]:
  var hinge := Node3D.new()
  hinge.position = Vector3(-9, 13, side * 6) * table.SCALE
  body.add_child(hinge)
  _wing(table, hinge, Vector3.ZERO, Vector3(-25, 27, side * 5), 4.5, wing_material)
  _wing(table, hinge, Vector3.ZERO, Vector3(-32, 14, side * 6), 4.0, wing_material)
  wings.append(hinge)
 var flash := _sphere(table, pose, Vector3.ZERO, Vector3(38, 38, 30), table.material(Color("fff1a0"), 0.0))
 flash.visible = false
 var entry := {"item": item, "root": root, "pose": pose, "body": body, "wings": wings, "flash": flash, "base": root.position}
 update(entry, 0.0, table)
 return entry

static func _sphere(table: TablePresentation, parent: Node3D, at: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
 var mesh := SphereMesh.new()
 mesh.radius = 0.5
 mesh.height = 1.0
 mesh.radial_segments = 10
 mesh.rings = 4
 var node := table.mesh_node(mesh, material, at * table.SCALE, parent)
 node.scale = size_value * table.SCALE
 return node

static func _cone(table: TablePresentation, parent: Node3D, start: Vector3, end: Vector3, start_radius: float, end_radius: float, material: Material) -> MeshInstance3D:
 var mesh := CylinderMesh.new()
 mesh.bottom_radius = start_radius * table.SCALE
 mesh.top_radius = end_radius * table.SCALE
 mesh.height = start.distance_to(end) * table.SCALE
 mesh.radial_segments = 10
 var node := table.mesh_node(mesh, material, (start + end) * 0.5 * table.SCALE, parent)
 node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
 return node

static func _abdomen(table: TablePresentation, parent: Node3D, blue: Material, stripe: Material) -> void:
 # Tapered blue shell with narrow cobalt bands, swept forward below the thorax.
 var sections := [Vector3(0, -7, 7), Vector3(2, -12, 12), Vector3(3, -14, 12.8), Vector3(5, -20, 13.5), Vector3(6, -22, 12.6), Vector3(9, -28, 9), Vector3(10, -30, 7), Vector3(12, -34, 3.5)]
 for i in sections.size() - 1:
  var a: Vector3 = sections[i]
  var b: Vector3 = sections[i + 1]
  _cone(table, parent, Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), a.z, b.z, stripe if i in [1, 3, 5] else blue)

static func _wing(table: TablePresentation, parent: Node3D, start: Vector3, end: Vector3, width: float, material: Material) -> void:
 # A tapered, six-sided blade has a clear sprite-like silhouette at table scale.
 var direction := (end - start).normalized()
 var across := Vector3(-direction.y, direction.x, 0).normalized() * width
 var points := [start, start.lerp(end, 0.25) + across, start.lerp(end, 0.85) + across * 0.65, end, start.lerp(end, 0.85) - across * 0.65, start.lerp(end, 0.25) - across]
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for side in [-1.0, 1.0]:
  for i in range(1, points.size() - 1):
   var triangle := [points[0], points[i], points[i + 1]] if side > 0 else [points[0], points[i + 1], points[i]]
   for point: Vector3 in triangle: surface.add_vertex((point + Vector3(0, 0, side * 0.6)) * table.SCALE)
 for i in points.size():
  var a: Vector3 = points[i]
  var b: Vector3 = points[(i + 1) % points.size()]
  for point: Vector3 in [a + Vector3(0, 0, 0.6), b + Vector3(0, 0, 0.6), a - Vector3(0, 0, 0.6), a - Vector3(0, 0, 0.6), b + Vector3(0, 0, 0.6), b - Vector3(0, 0, 0.6)]: surface.add_vertex(point * table.SCALE)
 surface.generate_normals()
 table.mesh_node(surface.commit(), material, Vector3.ZERO, parent)

static func update(entry: Dictionary, elapsed: float, table: TablePresentation) -> void:
 var item: Dictionary = entry.item
 var root: Node3D = entry.root
 root.visible = item.alive or item.death_remaining > 0.0
 var displacement: Vector2 = item.position - item.anchor
 root.position = entry.base + Vector3(displacement.x, sin(elapsed * 3.8) * 0.9, displacement.y) * TablePresentation.SCALE
 # Rotate only the collisionless portrait plane. Its local up projects upward
 # in top-down, normal and dramatic cameras instead of showing a wasp's back.
 var normal := Vector3(0, sin(PI / 3), cos(PI / 3))
 if is_instance_valid(table.camera): normal = table.camera.global_basis.z
 entry.pose.rotation.x = -atan2(normal.y, normal.z)
 entry.body.rotation.y = PI + deg_to_rad(15) if item.direction < 0.0 else deg_to_rad(-15)
 entry.body.visible = item.alive
 entry.flash.visible = not item.alive and item.death_remaining > 0.0
 if item.alive:
  for i in entry.wings.size():
   entry.wings[i].rotation.y = sin(elapsed * 45) * 0.16 * (-1 if i == 0 else 1)
   entry.wings[i].rotation.z = sin(elapsed * 45) * 0.06
 else:
  var progress := 1.0 - float(item.death_remaining) / 0.28
  entry.flash.scale = Vector3(38, 38, 30) * TablePresentation.SCALE * (1.0 + progress * 1.5)
  entry.flash.transparency = clampf(progress, 0, 1)
