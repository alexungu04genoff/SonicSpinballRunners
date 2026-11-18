extends RefCounted
## Faceted, collisionless hardware. Fixed mesh feedback; no lights or particles.
const Path = preload("res://scripts/authored_act/rail_path.gd")

static func build(p, root: Node3D, item: Dictionary, style: Dictionary) -> Dictionary:
 var path: Dictionary = Path.build(item.properties.points)
 var width: float = float(item.properties.width) * p.SCALE
 var height: float = float(item.properties.height) if item.properties.presentation == "exposed" else 0.0
 var radius: float = width * 0.5
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for index in path.points.size() - 1:
  for facet in 8:
   # Exposed is an open cradle. Tunnel keeps its complete opaque shell.
   if item.properties.presentation == "exposed" and facet in [0, 1, 2, 3]: continue
   var corners: Array[Vector3] = []
   for sample_index: int in [index, index + 1]:
    var tangent := Path.tangent(path, path.lengths[sample_index])
    var across := Vector3(-tangent.y, 0, tangent.x)
    var center: Vector3 = p.map_point(path.points[sample_index], Path.height(path, path.lengths[sample_index], height) * p.SCALE + radius)
    for side in 2:
     var angle: float = (facet + side) * TAU / 8.0
     corners.append(center + (across * cos(angle) + Vector3.UP * sin(angle)) * radius)
   for vertex: int in [0, 1, 2, 1, 3, 2]: surface.add_vertex(corners[vertex])
 surface.generate_normals()
 var shell_material: Material = style.body.duplicate()
 if shell_material is BaseMaterial3D: shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
 p.mesh_node(surface.commit(), shell_material, Vector3.ZERO, root).name = "TubeShell"
 var grip := _collar(p, root, path, 0.0, height, radius * 1.15, style.trim, "DockCompression", radius)
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
 _collar(p, root, path, path.length, height, radius * 1.13, style.trim, "ExitCollar", radius)
 var distance := 65.0
 while distance < float(path.length) - 40.0:
  _collar(p, root, path, distance, height, radius * 1.05, style.trim, "TubeRib", radius)
  distance += 85.0
 var pulse := _collar(p, root, path, 0.0, height, radius * 1.08, style.light, "TraversalPulse", radius)
 var burst := _collar(p, root, path, path.length, height, radius * 1.12, style.light, "ExitBurst", radius)
 pulse.visible = false
 burst.visible = false
 return {"kind": "launch_tube", "item": item, "root": root, "grip": grip,
  "lights": lights, "pulse": pulse, "burst": burst, "path": path, "height": height, "radius": radius}

static func _collar(p, parent: Node3D, path: Dictionary, distance: float, height: float, radius: float, material: Material, label: String, center_radius: float) -> Node3D:
 var root := Node3D.new()
 root.name = label
 parent.add_child(root)
 _place(root, path, distance, height, center_radius)
 var ring := TorusMesh.new()
 ring.inner_radius = radius * 0.86
 ring.outer_radius = radius
 ring.rings = 12
 ring.ring_segments = 4
 var mesh: MeshInstance3D = p.mesh_node(ring, material, Vector3.ZERO, root)
 mesh.rotation.x = PI * 0.5
 return root

static func _place(node: Node3D, path: Dictionary, distance: float, height: float, radius: float) -> void:
 var tangent := Path.tangent(path, distance)
 node.position = TablePresentation.map_point(Path.sample(path, distance), Path.height(path, distance, height) * TablePresentation.SCALE + radius)
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
 if entry.pulse.visible: _place(entry.pulse, entry.path, tube.distance, entry.height, entry.radius)
 entry.burst.visible = feedback > 0.0 and tube.exit_flash > 0.0
 entry.burst.scale = Vector3.ONE * (1.0 + (1.0 - float(tube.exit_flash) / 0.28) * 1.5 * feedback)
