extends Node3D
## Collisionless pinball visuals; theme materials never alter the shared rail geometry.
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
 var path: Dictionary = item.path.duplicate()
 var width := float(item.properties.width) * table.SCALE
 var peak := float(item.properties.height)
 # Bound the inside offset by local bend radius so wide strips cannot fold
 # over themselves. This is visual edging only; the authoritative route is unchanged.
 var inside := PackedFloat32Array()
 for i in path.points.size():
  var factor := 0.0
  if i > 0 and i < path.points.size() - 1:
   var incoming: Vector2 = path.points[i] - path.points[i - 1]
   var outgoing: Vector2 = path.points[i + 1] - path.points[i]
   var turn := incoming.angle_to(outgoing)
   if absf(turn) > 0.0001:
    var radius := (incoming.length() + outgoing.length()) * 0.5 / absf(turn)
    factor = signf(turn) * minf(1.0, radius * 0.8 / (float(item.properties.width) * 0.54))
  inside.append(factor)
 path["inside_edge_scale"] = inside
 var style := table.ramp_materials()
 var thickness := preload("res://scripts/act_dimensions.gd").RAMP_DECK_THICKNESS_PIXELS * table.SCALE
 var root := Node3D.new()
 root.name = "ElevatedRail_" + str(item.get("object_id", "route"))
 add_child(root)
 # Three meshes keep a readable deck, edge trim and real fascia/underside.
 # All vertices follow the same elevation samples used by the physical ball.
 _rail_strip(root, path, width, peak, Vector2(-0.5, 0.5), Vector2.ZERO, style.deck, "Deck")
 for side: float in [-1.0, 1.0]:
  _rail_strip(root, path, width, peak, Vector2(side * 0.44, side * 0.54), Vector2(0.035, 0.035), style.edge, "EdgeCap")
  _rail_strip(root, path, width, peak, Vector2(side * 0.54, side * 0.54), Vector2(-thickness, 0.035), style.support, "Fascia")
  _rail_strip(root, path, width, peak, Vector2(side * 0.44, side * 0.44), Vector2(0.0, 0.035), style.edge, "InnerEdge")
 _rail_strip(root, path, width, peak, Vector2(0.54, -0.54), Vector2(-thickness, -thickness), style.support, "Underside")
 # Slim paired timber/metal/stone posts leave the lane center visually open.
 var distance := 50.0
 while distance < float(path.length) - 35.0:
  var height := maxf(0.0, RailPath.height(path, distance, peak) * table.SCALE + 0.012 - thickness)
  if height > 0.06:
   var tangent := RailPath.tangent(path, distance)
   var across := Vector2(-tangent.y, tangent.x)
   var edge_index := clampi(path.lengths.bsearch(distance), 0, path.points.size() - 1)
   var edge_scale: float = path.inside_edge_scale[edge_index]
   for side: float in [-1.0, 1.0]:
    var post_offset := side * float(item.properties.width) * 0.46
    if side * edge_scale > 0.0: post_offset *= absf(edge_scale)
    var post := BoxMesh.new()
    post.size = Vector3(0.045, height, 0.045)
    table.mesh_node(post, style.support, table.map_point(RailPath.sample(path, distance) + across * post_offset, height / 2.0), root)
  distance += 80.0
 # A small inlaid arrow replaces the oversized bright circular entry pad.
 var marker := SurfaceTool.new()
 marker.begin(Mesh.PRIMITIVE_TRIANGLES)
 for vertex: Vector2 in [Vector2(-0.18, 6.0), Vector2(0.18, 6.0), Vector2(0.0, 16.0)]:
  var d := minf(vertex.y, float(path.length) * 0.15)
  var tangent := RailPath.tangent(path, d)
  var point := RailPath.sample(path, d) + Vector2(-tangent.y, tangent.x) * vertex.x * float(item.properties.width)
  marker.add_vertex(table.map_point(point, RailPath.height(path, d, peak) * table.SCALE + 0.014))
 marker.generate_normals()
 table.mesh_node(marker.commit(), style.accent, Vector3.ZERO, root).name = "EntryArrow"

func _rail_strip(parent: Node3D, path: Dictionary, width: float, peak: float, edges: Vector2, offsets: Vector2, material: Material, label: String) -> void:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in path.points.size() - 1:
  var corners: Array[Vector3] = []
  var uvs: Array[Vector2] = []
  for index: int in [i, i + 1]:
   var distance: float = path.lengths[index]
   var tangent := RailPath.tangent(path, distance)
   var side := Vector3(-tangent.y, 0, tangent.x)
   var center := table.map_point(path.points[index], RailPath.height(path, distance, peak) * table.SCALE + 0.012)
   var edge_scale: float = path.inside_edge_scale[index]
   var left := edges.x * absf(edge_scale) if edges.x * edge_scale > 0.0 else edges.x
   var right := edges.y * absf(edge_scale) if edges.y * edge_scale > 0.0 else edges.y
   corners.append(center + side * width * left + Vector3.UP * offsets.x)
   corners.append(center + side * width * right + Vector3.UP * offsets.y)
   uvs.append(Vector2(width * edges.x, distance * table.SCALE))
   uvs.append(Vector2(width * edges.y, distance * table.SCALE))
  for vertex: int in [0, 2, 1, 1, 2, 3]:
   surface.set_uv(uvs[vertex])
   surface.add_vertex(corners[vertex])
 surface.generate_normals()
 # Edge winding reverses on the opposite side; both faces must remain visible.
 var double_sided: Material = material.duplicate()
 if double_sided is BaseMaterial3D: double_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
 table.mesh_node(surface.commit(), double_sided, Vector3.ZERO, parent).name = label

func _process(delta: float) -> void:
 elapsed += delta
 for entry: Dictionary in spinners: entry.paddle.rotation.x = float(entry.item.angle)
 for field: Dictionary in fields:
  for i in field.arcs.get_child_count():
   var phase := fposmod(elapsed * 0.4 + float(i) / 6, 1.0)
   if not field.repel: phase = 1.0 - phase
   var angle: float = i * TAU / 6.0
   field.arcs.get_child(i).position = Vector3(cos(angle), 0.012, sin(angle)) * float(field.radius) * lerpf(0.2, 0.88, phase)
