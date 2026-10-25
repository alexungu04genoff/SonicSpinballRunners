extends Node3D
## Generic collisionless pinball visuals, shared by every theme.
const RailPath = preload("res://scripts/authored_act/rail_path.gd")
var table: TablePresentation
var spinners: Array[Dictionary] = []
var fields: Array[Dictionary] = []
var elapsed := 0.0

func build(presenter: TablePresentation, runtime: Dictionary) -> void:
 table = presenter
 name = "AuthoredPinballVisuals"
 process_mode = Node.PROCESS_MODE_PAUSABLE
 for descriptor: Dictionary in runtime.objects:
  if not descriptor.has("mechanic"): continue
  var item: Dictionary = descriptor.mechanic
  match item.type:
   "spinner": _spinner(item)
   "magnetic_field": _field(item)
   "elevated_rail": _rail(item)

func _box(size: Vector3, color: Color, at: Vector3, parent: Node3D) -> MeshInstance3D:
 var mesh := BoxMesh.new()
 mesh.size = size
 return table.mesh_node(mesh, table.material(color), at, parent)

func _spinner(item: Dictionary) -> void:
 var frame := Node3D.new()
 frame.position = table.map_point(item.position, 0.20)
 frame.rotation.y = -deg_to_rad(float(item.rotation_degrees))
 add_child(frame)
 var width := float(item.properties.width) * table.SCALE
 for side: float in [-1.0, 1.0]:
  _box(Vector3(0.035, 0.23, 0.045), Color("b8cbd9"), Vector3(side * width / 2, -0.10, 0), frame)
 _box(Vector3(width + 0.08, 0.025, 0.025), Color("dbe7ef"), Vector3.ZERO, frame)
 var paddle := Node3D.new()
 frame.add_child(paddle)
 _box(Vector3(width * 0.8, 0.16, 0.035), Color("ffbf48"), Vector3.ZERO, paddle)
 _box(Vector3(width * 0.5, 0.055, 0.038), Color("244362"), Vector3.ZERO, paddle)
 spinners.append({"item": item, "paddle": paddle})

func _field(item: Dictionary) -> void:
 var center := Node3D.new()
 center.position = table.map_point(item.position, 0.018)
 add_child(center)
 var repel: bool = item.properties.mode == "repel"
 var color := Color("f68b6f") if repel else Color("a68ef5")
 var material := table.material(color, 0.1)
 var radius := float(item.properties.radius) * table.SCALE
 var ring := TorusMesh.new()
 ring.inner_radius = maxf(0.01, radius - 0.012)
 ring.outer_radius = radius
 ring.rings = 48
 ring.ring_segments = 6
 table.mesh_node(ring, material, Vector3.ZERO, center)
 table.mesh_node(table.cylinder(0.035, 0.025), material, Vector3.ZERO, center)
 var arcs := Node3D.new()
 center.add_child(arcs)
 for i in 6:
  var marker := _box(Vector3(0.07, 0.012, 0.018), color, Vector3.ZERO, arcs)
  marker.rotation.y = -i * TAU / 6.0
 fields.append({"arcs": arcs, "radius": radius, "repel": repel})

func _rail(item: Dictionary) -> void:
 var path: Dictionary = item.path
 var width := float(item.properties.width) * table.SCALE
 var peak := float(item.properties.height)
 var deck := SurfaceTool.new()
 deck.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Deck and two narrow raised edge strips follow exactly the runtime height profile.
 for band: Vector3 in [Vector3(-0.5, 0.5, 0.0), Vector3(-0.54, -0.44, 0.055), Vector3(0.44, 0.54, 0.055)]:
  for i in path.points.size() - 1:
   var corners: Array[Vector3] = []
   for index: int in [i, i + 1]:
    var distance: float = path.lengths[index]
    var tangent := RailPath.tangent(path, distance)
    var side := Vector3(-tangent.y, 0, tangent.x)
    var center := table.map_point(path.points[index], RailPath.height(path, distance, peak) * table.SCALE + 0.012 + band.z)
    corners.append(center + side * width * band.x)
    corners.append(center + side * width * band.y)
   for vertex: int in [0, 2, 1, 1, 2, 3]: deck.add_vertex(corners[vertex])
 deck.generate_normals()
 var material := table.material(Color("9bb9c8"))
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 var mesh := table.mesh_node(deck.commit(), material, Vector3.ZERO, self)
 mesh.name = "ElevatedRail_" + str(item.get("object_id", "route"))
 for i in range(10, path.points.size() - 10, 20):
  var height := RailPath.height(path, path.lengths[i], peak) * table.SCALE
  _box(Vector3(0.055, height, 0.055), Color("4c647b"), table.map_point(path.points[i], height / 2.0), self)
 # A bright mouth marks forward entry without adding hidden collision geometry.
 var mouth := table.mesh_node(table.cylinder(width * 0.45, 0.012), table.material(Color("62ddbd")), table.map_point(path.points[0], 0.012), self)
 mouth.name = "RailEntry"

func _process(delta: float) -> void:
 elapsed += delta
 for entry: Dictionary in spinners: entry.paddle.rotation.x = float(entry.item.angle)
 for field: Dictionary in fields:
  for i in field.arcs.get_child_count():
   var phase := fposmod(elapsed * 0.4 + float(i) / 6, 1.0)
   if not field.repel: phase = 1.0 - phase
   var angle: float = i * TAU / 6.0
   field.arcs.get_child(i).position = Vector3(cos(angle), 0.012, sin(angle)) * float(field.radius) * lerpf(0.2, 0.88, phase)
