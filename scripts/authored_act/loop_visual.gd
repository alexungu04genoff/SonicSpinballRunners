extends RefCounted
## The inner track, checker cliff and industrial shell wrap the same upright
## helix that carries the real Ball. All geometry is static and collisionless.
const Path = preload("res://scripts/authored_act/loop_path.gd")
const Dimensions = preload("res://scripts/act_dimensions.gd")

static func section(distance: float, clockwise: bool, size: float, ball_radius: float) -> Dictionary:
 var angle := Path.angle_at(distance)
 var hand := 1.0 if clockwise else -1.0
 var frame := Path.local_frame(distance, clockwise)
 var inward := frame.y
 var across := frame.x * hand
 var center := Path.local_sample(distance, clockwise) * size + (Vector3.UP - inward) * ball_radius
 # Rounded-square cliff around a circular opening, as on the coastal turf landmark.
 var outer_radius := pow((absf(sin(angle)) / 1.07) ** 6 + absf(cos(angle)) ** 6, -1.0 / 6.0)
 var thickness := (outer_radius / 0.84 - 1.0) * (Path.RADIUS * size + ball_radius)
 var inner_left := center - across * Path.HALF_WIDTH * size
 var inner_right := center + across * Path.HALF_WIDTH * size
 var outer_left := inner_left - inward * thickness
 var outer_right := inner_right - inward * thickness
 outer_left.y = maxf(-0.45, outer_left.y)
 outer_right.y = maxf(-0.45, outer_right.y)
 return {"points": PackedVector3Array([inner_left, inner_right, outer_right, outer_left]), "inward": inward, "across": across}

static func quad(surface: SurfaceTool, points: PackedVector3Array, outward: Vector3, uv: PackedVector2Array, route_uv: PackedVector2Array) -> void:
 for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
  var normal := (points[triangle[2]] - points[triangle[0]]).cross(points[triangle[1]] - points[triangle[0]])
  if normal.length_squared() < 0.00000000001: continue
  if normal.dot(outward) < 0.0:
   triangle.reverse()
   normal = -normal
  normal = normal.normalized()
  for index: int in triangle:
   surface.set_normal(normal)
   surface.set_uv(uv[index])
   surface.set_uv2(route_uv[index])
   surface.add_vertex(points[index])

static func build(table: TablePresentation, parent: Node3D, item: Dictionary) -> void:
 var root := Node3D.new()
 root.name = "Loop_" + str(item.object_id)
 root.position = table.map_point(item.position, 0.012)
 root.rotation.y = -deg_to_rad(float(item.rotation_degrees))
 parent.add_child(root)
 var size := float(item.properties.scale)
 var clockwise: bool = item.properties.direction == "clockwise"
 var radius := table.authored_cell_size * Dimensions.BALL_RADIUS_CELLS
 var skin := table.loop_materials()
 var surfaces := {}
 var distances := Path.distances()
 var previous := section(0, clockwise, size, radius)
 for i in range(1, distances.size()):
  var current := section(distances[i], clockwise, size, radius)
  var inward: Vector3 = (previous.inward + current.inward).normalized()
  var across: Vector3 = (previous.across + current.across).normalized()
  var face_material: Material = skin.wall
  var materials := [skin.track, face_material, skin.crown if -inward.y > 0.7 else face_material, face_material]
  var normals := [inward, across, -inward, -across]
  for side in 4:
   var material: Material = materials[side]
   if not surfaces.has(material):
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_material(material)
    surfaces[material] = surface
   var next := (side + 1) % 4
   var points := PackedVector3Array([previous.points[side], previous.points[next], current.points[next], current.points[side]])
   var uv := PackedVector2Array()
   var route_uv := PackedVector2Array()
   for j in 4:
    points[j] *= table.SCALE
    var station := distances[i - 1 if j < 2 else i] * size * table.SCALE
    var width_fraction := 1.0 if j in [1, 2] else 0.0
    route_uv.append(Vector2(width_fraction, station))
    if side in [1, 3]:
     # The landmark checker stays square in the face plane. Masonry and panels
     # wrap along the arc, with a full course between the tread and outer edge.
     var depth := width_fraction if side == 1 else 1.0 - width_fraction
     uv.append(Vector2(station, depth) if skin.get("wrap_face", false) else Vector2(-points[j].z, points[j].y))
    else:
     uv.append(Vector2(width_fraction * 2.0 * Path.HALF_WIDTH * size * table.SCALE, station))
   quad(surfaces[material], points, normals[side], uv, route_uv)
  previous = current
 var mesh := ArrayMesh.new()
 for surface: SurfaceTool in surfaces.values(): surface.commit(mesh)
 var track := MeshInstance3D.new()
 track.name = "LoopShell"
 track.mesh = mesh
 root.add_child(track)
 if item.properties.ring_markers and int(item.properties.ring_reward) > 0:
  var torus := TorusMesh.new()
  torus.outer_radius = table.authored_cell_size * Dimensions.RING_RADIUS_CELLS * table.SCALE
  torus.inner_radius = torus.outer_radius * 0.55
  torus.rings = table.Density.RING_SIDES
  torus.ring_segments = table.Density.RING_TUBE_SIDES
  var gold := table.material(Color("ffd568"), 0.08)
  for i in 3:
   var d := Path.LEAD + Path.ARC * (i + 1) * 0.25
   var point := Path.local_sample(d, clockwise) * size + Vector3.UP * radius
   var marker := table.mesh_node(torus, gold, point * table.SCALE, root)
   marker.name = "RingInlay%d" % i
   marker.rotation.z = PI * 0.5
