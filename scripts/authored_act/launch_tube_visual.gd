extends RefCounted
## Faceted, collisionless hardware. Fixed mesh feedback; no lights or particles.
const Path = preload("res://scripts/authored_act/rail_path.gd")

static func build(p, root: Node3D, item: Dictionary, style: Dictionary) -> Dictionary:
 var path: Dictionary = Path.build(item.properties.points)
 var width: float = float(item.properties.width) * p.SCALE
 var radius := width * 0.5
 var hub_height := width * 0.12
 var grip := _collar(p, root, path, 0.0, radius * 1.15, style.trim, "DockCompression", hub_height)
 var lights: Array[Node3D] = []
 for index in 8:
  var light := Node3D.new()
  grip.add_child(light)
  var angle: float = index * TAU / 8.0
  light.position = Vector3(cos(angle), sin(angle), 0) * radius * 1.12
  var mesh := BoxMesh.new()
  mesh.size = Vector3(width * 0.12, width * 0.12, width * 0.1)
  p.mesh_node(mesh, style.light, Vector3.ZERO, light).name = "ChargeIndicator"
  lights.append(light)
 _collar(p, root, path, path.length, radius * 1.13, style.trim, "ExitCollar", hub_height)
 var distance := 65.0
 while item.properties.presentation == "tunnel" and distance < float(path.length) - 40.0:
  _collar(p, root, path, distance, radius * 1.05, style.trim, "TubeRib", hub_height)
  distance += 85.0
 var pulse := _collar(p, root, path, 0.0, radius * 1.08, style.light, "TraversalPulse", hub_height)
 var burst := _collar(p, root, path, path.length, radius * 1.12, style.light, "ExitBurst", hub_height)
 pulse.visible = false
 burst.visible = false
 return {"kind": "launch_tube", "item": item, "root": root, "grip": grip,
  "lights": lights, "pulse": pulse, "burst": burst, "path": path, "hub_height": hub_height}

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
 entry.grip.scale.z = 1.0 - charge * 0.3 * feedback
 entry.grip.rotation.z = float(tube.visual_time) * charge * TAU * feedback
 for index in entry.lights.size():
  entry.lights[index].visible = feedback > 0.0 and tube.contained and index < ceili(charge * 8.0)
  entry.lights[index].scale = Vector3.ONE * lerpf(0.3, 1.0, feedback)
 entry.pulse.visible = feedback > 0.0 and tube.contained and tube.phase in [tube.Phase.OUTBOUND, tube.Phase.RETURNING]
 entry.pulse.scale = Vector3.ONE * lerpf(0.95, 1.0, feedback)
 if entry.pulse.visible: _place(entry.pulse, entry.path, tube.distance, entry.hub_height)
 entry.burst.visible = feedback > 0.0 and tube.exit_flash > 0.0
 entry.burst.scale = Vector3.ONE * (1.0 + (1.0 - float(tube.exit_flash) / 0.28) * 1.5 * feedback)
