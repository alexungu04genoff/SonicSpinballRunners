extends RefCounted
## Stage-specific shells surround a shared running surface. All meshes are static and collisionless.
const Path = preload("res://scripts/authored_act/loop_path.gd")
const Dimensions = preload("res://scripts/act_dimensions.gd")

# Side elevation of the cut glacier, in units of the opening radius.
const ICE_EDGE := [Vector2(-1.18, -1.1), Vector2(-1.26, -0.51), Vector2(-1.10, 0.43),
 Vector2(-0.80, 1.00), Vector2(-0.31, 1.22), Vector2(0.38, 1.14), Vector2(0.77, 1.09),
 Vector2(1.17, 0.56), Vector2(1.22, -0.42), Vector2(1.32, -1.10)]
const TIES := [PI * 0.375, PI, TAU - PI * 0.375]

static func thickness_ratio(profile: StringName, angle: float) -> float:
 match profile:
  &"cabinet": return 0.12
  &"bridge": return 0.10
  &"masonry": return 0.22
  &"glacier":
   var direction := Vector2(sin(angle), -cos(angle))
   for edge in ICE_EDGE.size():
    var intersection: Variant = Geometry2D.segment_intersects_segment(Vector2.ZERO, direction * 2.0, ICE_EDGE[edge], ICE_EDGE[(edge + 1) % ICE_EDGE.size()])
    if intersection != null: return Vector2(intersection).length() - 1.0
 # The turf landmark has a nearly square outside and a circular bore.
 var outer_radius := pow((absf(sin(angle)) / 1.07) ** 6 + absf(cos(angle)) ** 6, -1.0 / 6.0)
 return outer_radius / 0.84 - 1.0

static func section(distance: float, clockwise: bool, size: float, ball_radius: float, profile := &"cliff") -> Dictionary:
 var angle := Path.angle_at(distance)
 var hand := 1.0 if clockwise else -1.0
 var frame := Path.local_frame(distance, clockwise)
 var inward := frame.y
 var across := frame.x * hand
 var center := Path.local_sample(distance, clockwise) * size + (Vector3.UP - inward) * ball_radius
 var thickness := thickness_ratio(profile, angle) * (Path.RADIUS * size + ball_radius)
 if profile == &"masonry" and absf(angle - PI) <= deg_to_rad(6.01): thickness += 4.0 * size
 var inner_left := center - across * Path.HALF_WIDTH * size
 var inner_right := center + across * Path.HALF_WIDTH * size
 var outer_left := inner_left - inward * thickness
 var outer_right := inner_right - inward * thickness
 outer_left.y = maxf(-0.45, outer_left.y)
 outer_right.y = maxf(-0.45, outer_right.y)
 var points := PackedVector3Array([inner_left, inner_right, outer_right, outer_left])
 var depths := PackedFloat32Array([0, 0, 1, 1])
 if profile != &"cliff":
  # The slim lip sits alongside the tread; its width does not grow with the cliff.
  var lip := minf(0.42, (2.4 if profile == &"glacier" else 1.7) * size / thickness)
  points = PackedVector3Array([inner_left, inner_right, inner_right.lerp(outer_right, lip), outer_right, outer_left, inner_left.lerp(outer_left, lip)])
  depths = PackedFloat32Array([0, 0, lip, 1, 1, lip])
 return {"points": points, "depths": depths, "inward": inward, "across": across, "base": (outer_left + outer_right) * 0.5}

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
 var profile: StringName = skin.get("profile", &"cliff")
 var distances := Path.distances()
 var accents: Array = TIES if profile == &"bridge" else ([PI] if profile == &"masonry" else [])
 var half_angle := deg_to_rad(6.0 if profile == &"masonry" else 1.5)
 for a: float in accents:
  for edge: float in [-half_angle, half_angle]:
   distances.append(Path.LEAD + (a + edge) / TAU * Path.ARC)
 distances.sort()
 var sections: Array[Dictionary] = []
 var tread_lengths := PackedFloat32Array()
 var last_center := Vector3.ZERO
 var length := 0.0
 for distance: float in distances:
  var ring := section(distance, clockwise, size, radius, profile)
  var center: Vector3 = (ring.points[0] + ring.points[1]) * 0.5 * table.SCALE
  if not sections.is_empty(): length += last_center.distance_to(center)
  tread_lengths.append(length)
  last_center = center
  sections.append(ring)
 var width := 2.0 * Path.HALF_WIDTH * size * table.SCALE
 for i in range(1, distances.size()):
  var previous := sections[i - 1]
  var current := sections[i]
  var inward: Vector3 = (previous.inward + current.inward).normalized()
  var across: Vector3 = (previous.across + current.across).normalized()
  var mid_angle := Path.angle_at((distances[i - 1] + distances[i]) * 0.5)
  var wall: Material = skin.wall
  var crown: Material = skin.crown
  for a: float in accents:
   if absf(a - mid_angle) < half_angle:
    wall = skin.get("accent", skin.trim) if profile == &"bridge" else skin.trim
    crown = wall
  var materials := [skin.track, wall, crown if -inward.y > 0.7 else wall, wall]
  var normals := [inward, across, -inward, -across]
  if profile != &"cliff":
   materials = [skin.track, skin.trim, wall, crown, wall, skin.trim]
   normals = [inward, across, across, -inward, -across, -across]
  for side in materials.size():
   var material: Material = materials[side]
   if not surfaces.has(material):
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_material(material)
    surfaces[material] = surface
   var next := (side + 1) % materials.size()
   var points := PackedVector3Array([previous.points[side], previous.points[next], current.points[next], current.points[side]])
   var uv := PackedVector2Array()
   var route_uv := PackedVector2Array()
   for j in 4:
    points[j] *= table.SCALE
    var station := distances[i - 1 if j < 2 else i] * size * table.SCALE
    var width_fraction := 1.0 if j in [1, 2] else 0.0
    if side == 0 or side == (materials.size() >> 1):
     if side == 0 and material.has_meta("playing_card_lane"):
      var tread_station := tread_lengths[i - 1 if j < 2 else i]
      uv.append(Vector2(length / width, tread_station))
      route_uv.append(Vector2(width_fraction, tread_station / width))
     else:
      uv.append(Vector2(width_fraction * width, station))
      route_uv.append(Vector2(width_fraction, station))
    else:
     var elevation := Vector2(-points[j].z, points[j].y)
     var depths: PackedFloat32Array = previous.depths if j < 2 else current.depths
     var depth := depths[next if j in [1, 2] else side]
     uv.append(elevation if profile == &"cliff" else Vector2(station, depth))
     route_uv.append(elevation)
   quad(surfaces[material], points, normals[side], uv, route_uv)
 var mesh := ArrayMesh.new()
 for surface: SurfaceTool in surfaces.values(): surface.commit(mesh)
 var track := MeshInstance3D.new()
 track.name = "LoopShell"
 track.mesh = mesh
 root.add_child(track)
 if profile in [&"masonry", &"bridge", &"cabinet"]:
  _build_feet(table, root, skin, size, clockwise, radius)
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

static func _build_feet(table: TablePresentation, root: Node3D, skin: Dictionary, size: float, clockwise: bool, radius: float) -> void:
 var profile: StringName = skin.profile
 var shoulder := deg_to_rad(87.0 if profile == &"masonry" else 53.0)
 for angle: float in [shoulder, TAU - shoulder]:
  var ring := section(Path.LEAD + angle / TAU * Path.ARC, clockwise, size, radius, profile)
  var at: Vector3 = ring.base * table.SCALE
  var across: Vector3 = ring.across
  var yaw := atan2(-across.z, across.x)
  var width := 2.0 * Path.HALF_WIDTH * size * table.SCALE
  var depth := width * (0.5 if profile == &"masonry" else 0.33)
  var material: Material = skin.get("support", skin.wall)
  if profile == &"bridge":
   var beam := maxf(width * 0.11, 0.022)
   for side: float in [-1.0, 1.0]:
    var offset := Vector3.RIGHT.rotated(Vector3.UP, yaw) * (side * width * 0.38)
    _block(table, root, at + offset, Vector3(beam, at.y, beam), yaw, material)
   _block(table, root, at, Vector3(width * 0.94, beam, depth * 0.65), yaw, material)
  else:
   _block(table, root, at, Vector3(width * 0.82, at.y, depth), yaw, material)
   var cap := width * 0.11
   var foot := Vector3(at.x, cap, at.z)
   _block(table, root, foot, Vector3(width * 0.97, cap, depth + cap), yaw, material)
   if profile == &"masonry":
    _block(table, root, at, Vector3(width, cap, depth + cap), yaw, skin.trim)

static func _block(table: TablePresentation, root: Node3D, top: Vector3, dimensions: Vector3, yaw: float, material: Material) -> void:
 var mesh := BoxMesh.new()
 mesh.size = dimensions
 var block := table.mesh_node(mesh, material, top - Vector3.UP * dimensions.y * 0.5, root)
 block.rotation.y = yaw
