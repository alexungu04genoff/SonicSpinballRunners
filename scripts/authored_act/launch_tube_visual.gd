extends RefCounted
## Faceted, collisionless hardware. Fixed mesh feedback; no lights or particles.
const Path = preload("res://scripts/authored_act/rail_path.gd")
const Hardware = preload("res://scripts/atmosphere/hardware_palette.gd")
## Visible timber or paving at the back of the dock, inside the physical pocket.
const DECK_REAR_WIDTHS := 0.85

static func build(p, root: Node3D, item: Dictionary, style: Dictionary) -> Dictionary:
 var path: Dictionary = Path.build(item.properties.points)
 var width: float = float(item.properties.width) * p.SCALE
 var radius := width * 0.5
 var hub_height := width * 0.12
 var mount := Node3D.new()
 mount.name = "Plunger"
 root.add_child(mount)
 _place(mount, path, 0.0, TablePresentation.ROUTE_DECK_HEIGHT)
 var steel := Hardware.fixed(p, "spinner_crossbar")
 var frame := Hardware.fixed(p, "spinner_frame")
 var gunmetal := Hardware.fixed(p, "lane_chassis")
 var rear := width * (DECK_REAR_WIDTHS - 0.065)
 var length := rear - width * 0.16
 var seat := Node3D.new()
 seat.name = "SpringSeat"
 mount.add_child(seat)
 seat.position = Vector3(0, width * 0.125, -rear)
 var foot: MeshInstance3D = p.mesh_node(p.cylinder(width * 0.16, width * 0.066), gunmetal, Vector3.DOWN * width * 0.093, seat)
 foot.scale.z = 0.38
 _axial_part(p, seat, width * 0.114, width * 0.078, 0.0, frame)
 _axial_part(p, seat, width * 0.080, width * 0.032, -width * 0.039, gunmetal)
 var coil := Node3D.new()
 coil.name = "CompressionSpring"
 seat.add_child(coil)
 _axial_part(p, coil, width * 0.032, length, length * 0.5, gunmetal)
 p.mesh_node(_coil_mesh(width, length), steel, Vector3.ZERO, coil)
 var head := Node3D.new()
 head.name = "PlungerHead"
 seat.add_child(head)
 head.position.z = length
 _axial_part(p, head, width * 0.137, width * 0.045, -width * 0.023, frame)
 _axial_part(p, head, width * 0.145, width * 0.075, width * 0.031, gunmetal)
 var lights: Array[Node3D] = []
 var strip := BoxMesh.new()
 strip.size = Vector3(width * 0.061, width * 0.025, width * 0.61)
 var lens := BoxMesh.new()
 lens.size = Vector3(width * 0.044, width * 0.014, width * 0.093)
 for side: float in [-1.0, 1.0]:
  p.mesh_node(strip, gunmetal, Vector3(side * width * 0.34, strip.size.y * 0.5, -width * 0.38), mount)
 for row in 4:
  for side: float in [-1.0, 1.0]:
   var light := Node3D.new()
   mount.add_child(light)
   light.position = Vector3(side * width * 0.34, strip.size.y + lens.size.y * 0.5, -width * (0.16 + row * 0.145))
   p.mesh_node(lens, style.light, Vector3.ZERO, light).name = "ChargeIndicator"
   lights.append(light)
 if item.properties.presentation == "tunnel":
  _collar(p, root, path, 0.0, radius * 1.13, style.trim, "TunnelMouth", hub_height)
  _collar(p, root, path, path.length, radius * 1.13, style.trim, "ExitCollar", hub_height)
 var distance := 65.0
 while item.properties.presentation == "tunnel" and distance < float(path.length) - 40.0:
  _collar(p, root, path, distance, radius * 1.05, style.trim, "TubeRib", hub_height)
  distance += 85.0
 var pulse := _collar(p, root, path, 0.0, radius * 1.08, style.light, "TraversalPulse", hub_height)
 var burst := _collar(p, root, path, path.length, radius * 1.12, style.light, "ExitBurst", hub_height)
 pulse.visible = false
 burst.visible = false
 return {"kind": "launch_tube", "item": item, "root": root,
  "coil": coil, "head": head, "spring_length": length,
  "lights": lights, "pulse": pulse, "burst": burst, "path": path, "hub_height": hub_height}

static func _axial_part(p, parent: Node3D, radius: float, depth: float, z: float, material: Material) -> void:
 var part: MeshInstance3D = p.mesh_node(p.cylinder(radius, depth), material, Vector3.BACK * z, parent)
 part.rotation.x = PI * 0.5

static func _coil_mesh(width: float, length: float) -> ArrayMesh:
 var mesh := SurfaceTool.new()
 mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 const SIDES := 6
 const STEPS := 42
 for i in STEPS + 1:
  var fraction := float(i) / STEPS
  var angle := fraction * 3.5 * TAU
  var radial := Vector3(cos(angle), sin(angle), 0)
  var radius := width * 0.093
  var center := radial * radius + Vector3.BACK * length * fraction
  var tangent := Vector3(-radial.y, radial.x, length / (radius * 3.5 * TAU)).normalized()
  var across := radial.cross(tangent)
  for j in SIDES:
   var around := TAU * j / SIDES
   var normal := radial * cos(around) + across * sin(around)
   mesh.set_normal(normal)
   mesh.add_vertex(center + normal * width * 0.017)
   if i < STEPS:
    var a := i * SIDES + j
    var b := i * SIDES + (j + 1) % SIDES
    for index: int in [a, b, a + SIDES, b, b + SIDES, a + SIDES]: mesh.add_index(index)
 return mesh.commit()

static func _collar(p, parent: Node3D, path: Dictionary, distance: float, radius: float, material: Material, label: String, hub_height: float) -> Node3D:
 var root := Node3D.new()
 root.name = label
 parent.add_child(root)
 _place(root, path, distance, hub_height)
 var ring := TorusMesh.new()
 ring.inner_radius = radius * 0.86
 ring.outer_radius = radius
 ring.rings = 12
 ring.ring_segments = 4
 var mesh: MeshInstance3D = p.mesh_node(ring, material, Vector3.ZERO, root)
 mesh.rotation.x = PI * 0.5
 return root

static func _place(node: Node3D, path: Dictionary, distance: float, hub_height: float) -> void:
 var tangent := Path.tangent(path, distance)
 node.position = TablePresentation.map_point(Path.sample(path, distance), hub_height)
 node.rotation.y = atan2(tangent.x, tangent.y)

static func update(entry: Dictionary) -> void:
 var tube: Node = entry.item.get("tube")
 if not is_instance_valid(tube): return
 var charge: float = tube.charge
 var feedback: float = entry.item.properties.feedback_strength
 var spring_length: float = entry.spring_length
 entry.head.position.z = spring_length - tube.plunger_pullback() * TablePresentation.SCALE
 entry.coil.scale.z = entry.head.position.z / spring_length
 var lit_count := ceili(charge * 4.0) * 2
 for index in entry.lights.size():
  entry.lights[index].visible = feedback > 0.0 and tube.contained and index < lit_count
  entry.lights[index].scale = Vector3.ONE * lerpf(0.3, 1.0, feedback)
 entry.pulse.visible = feedback > 0.0 and tube.contained and tube.phase in [tube.Phase.OUTBOUND, tube.Phase.RETURNING]
 entry.pulse.scale = Vector3.ONE * lerpf(0.95, 1.0, feedback)
 if entry.pulse.visible: _place(entry.pulse, entry.path, tube.distance, entry.hub_height)
 entry.burst.visible = feedback > 0.0 and tube.exit_flash > 0.0
 entry.burst.scale = Vector3.ONE * (1.0 + (1.0 - float(tube.exit_flash) / 0.28) * 1.5 * feedback)
