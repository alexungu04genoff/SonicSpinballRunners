extends RefCounted
## Original procedural low-poly hardware. This file creates no physics objects.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const STYLES := {
 "green_hill": ["705339", "f5c65c", "69e4a3", "flap"],
 "chemical_plant": ["253549", "e7b54c", "43eeeb", "valve"],
 "rooftop_run": ["384b55", "e0ba77", "fff0be", "ironwork"],
 "casino_night": ["302667", "ffd052", "ff55c8", "neon"],
 "aquarium_park": ["263f5b", "eacb96", "62e9fa", "lantern"],
 "sky_sanctuary": ["d9d3b3", "d1af65", "72eff4", "relic"],
 "ice_cap": ["658ec1", "c8eeff", "87f5ff", "crystal"],
 "lava_reef": ["4b4148", "bd9466", "ff8e42", "forge"],
}

static func build(p, parent: Node3D, item: Dictionary) -> Dictionary:
 var root := Node3D.new()
 root.name = item.type.to_pascal_case() + "_" + str(item.object_id)
 root.position = p.map_point(item.position)
 root.rotation.y = -deg_to_rad(float(item.rotation_degrees))
 root.set_meta("object_id", item.object_id)
 parent.add_child(root)
 var palette: Array = STYLES.get(p._pinball_theme_id(), STYLES.green_hill)
 var style := {"body": p.material(Color(palette[0])), "trim": p.material(Color(palette[1])), "light": p.material(Color(palette[2]), 1.8), "kind": palette[3]}
 match item.type:
  "one_way_gate": return _gate(p, root, item, style)
  "switch_target": return _switch(p, root, item, style)
  "wall_switch":
   var mount := Node3D.new()
   mount.position.y = Objects.switch_radius(item) * p.SCALE
   mount.rotation.x = -PI / 2.0
   root.add_child(mount)
   var entry := _switch(p, mount, item, style)
   mount.scale.y *= 0.4
   entry["root"] = root
   return entry
  "spring": return _spring(p, root, item)
  "lane_barrier": return _lanes(p, root, item, style)
  "diverter": return _diverter(p, root, item, style)
  "dash_panel": return _dash_panel(p, root, item, style)
 return {}

static func _box(p, parent: Node3D, size: Vector3, at: Vector3, mat: Material, label: String) -> MeshInstance3D:
 var mesh := BoxMesh.new()
 mesh.size = size
 var node: MeshInstance3D = p.mesh_node(mesh, mat, at, parent)
 node.name = label
 return node

static func _disc(p, parent: Node3D, radius: float, height: float, at: Vector3, mat: Material, label: String, segments := 16) -> MeshInstance3D:
 var mesh: CylinderMesh = p.cylinder(radius, height)
 mesh.radial_segments = segments
 var node: MeshInstance3D = p.mesh_node(mesh, mat, at, parent)
 node.name = label
 return node

static func _star(p, parent: Node3D, radius: float, height: float, mat: Material) -> void:
 var points := PackedVector2Array()
 for i in 10:
  points.append(Vector2.from_angle(-PI / 2.0 + i * TAU / 10.0) * radius / p.SCALE * (1.0 if i % 2 == 0 else 0.45))
 p.mesh_node(p._prism(points, 0.008, mat, mat), null, Vector3(0, height, 0), parent).name = "StarEmblem"

static func _gate(p, root: Node3D, item: Dictionary, style: Dictionary) -> Dictionary:
 var width: float = float(item.properties.width) * p.SCALE
 root.set_meta("gate_style", style.kind)
 var panel := Node3D.new()
 panel.name = "RetractingFlap"
 root.add_child(panel)
 _box(p, panel, Vector3(width, 0.14, 8.0 * p.SCALE), Vector3(0, 0.1, 0), style.body, "Barrier")
 _box(p, panel, Vector3(width * 0.9, 0.025, 0.085), Vector3(0, 0.175, 0), style.trim, "Cap")
 for side: float in [-1.0, 1.0]:
  _disc(p, root, 0.032, 0.19, Vector3(side * (width * 0.5 - 0.025), 0.095, 0), style.trim, "Hinge", 8)
 var light := _box(p, panel, Vector3(width * 0.78, 0.025, 0.012), Vector3(0, 0.14, -0.045), style.light, "StateLight")
 match style.kind:
  "flap":
   for side: float in [-1.0, 1.0]:
    var brace := _box(p, panel, Vector3(width * 0.36, 0.022, 0.013), Vector3(side * width * 0.2, 0.10, -0.047), style.trim, "TimberBrace")
    brace.rotation.z = side * 0.18
  "valve":
   var valve := _disc(p, panel, 0.07, 0.015, Vector3(0, 0.10, -0.05), style.trim, "ValveHub", 8)
   valve.rotation.x = PI / 2
   for side: float in [-1.0, 1.0]:
    _box(p, panel, Vector3(0.025, 0.10, 0.012), Vector3(side * width * 0.3, 0.10, -0.05), style.light, "EnergyVent")
  "ironwork", "lantern":
   for i in 7:
    _box(p, panel, Vector3(0.012, 0.13 + (0.03 if i % 2 == 0 else 0.0), 0.012), Vector3((i - 3) * width / 8.0, 0.12, -0.05), style.trim, "MetalSpindle")
   if style.kind == "lantern":
    for side: float in [-1.0, 1.0]:
     _box(p, panel, Vector3(0.055, 0.06, 0.04), Vector3(side * width * 0.35, 0.22, 0), style.light, "Lantern")
  "neon":
   for i in 5:
    var bulb := _disc(p, panel, 0.018, 0.012, Vector3((i - 2) * width / 6.0, 0.2, 0), style.light, "MarqueeBulb", 8)
    bulb.rotation.x = PI / 2
  "relic", "crystal":
   for i in 5:
    var crystal := PrismMesh.new()
    crystal.size = Vector3(width / 8, 0.10 + (0.05 if i == 2 else 0.0), 0.05)
    p.mesh_node(crystal, style.light if style.kind == "crystal" else style.trim, Vector3((i - 2) * width / 6, 0.22, 0), panel).name = "Crystal" if style.kind == "crystal" else "SacredCrest"
  "forge":
   for i in 6:
    var rivet := _disc(p, panel, 0.012, 0.015, Vector3((i - 2.5) * width / 7, 0.085, -0.05), style.trim, "Rivet", 6)
    rivet.rotation.x = PI / 2
 # A floor arrow always points along the allowed direction, including when open.
 # Repeat face hardware on the reverse side so the normal table camera and
 # rotated placements both show the valve, braces, lights and rivets.
 for child: Node3D in panel.get_children():
  if child.position.z < -0.04:
   var reverse: Node3D = child.duplicate()
   reverse.position.z = -child.position.z
   panel.add_child(reverse)
 var arrow := PackedVector2Array([Vector2(-7, 15), Vector2(7, 15), Vector2(0, 1)])
 p.mesh_node(p._prism(arrow, 0.004, style.light, style.light), null, Vector3(0, 0.005, 0), root).name = "AllowedDirection"
 return {"item": item, "root": root, "panel": panel, "light": light, "kind": "gate"}

static func _switch(p, root: Node3D, item: Dictionary, style: Dictionary) -> Dictionary:
 root.scale = Vector3.ONE * float(Objects.properties(item).scale)
 var radius: float = Objects.SWITCH_RADIUS * p.SCALE
 var color: Color = Objects.COLORS[item.properties.color]
 _disc(p, root, radius, 0.045, Vector3(0, 0.0225, 0), style.body, "OctagonalHousing", 8)
 _disc(p, root, radius * 0.9, 0.018, Vector3(0, 0.055, 0), style.trim, "Bezel", 12)
 var pad := Node3D.new()
 pad.name = "PressPad"
 root.add_child(pad)
 var material: StandardMaterial3D = p.material(color.darkened(0.3))
 material.emission_enabled = true
 material.emission = color
 material.emission_energy_multiplier = 0.0
 _disc(p, pad, radius * 0.73, 0.055, Vector3(0, 0, 0), material, "ColoredButton", 24)
 var ring := TorusMesh.new()
 ring.inner_radius = radius * 0.33
 ring.outer_radius = radius * 0.43
 ring.rings = 24
 ring.ring_segments = 6
 p.mesh_node(ring, style.trim, Vector3(0, 0.03, 0), pad).name = "PowerSymbol"
 _box(p, pad, Vector3(0.018, 0.008, radius * 0.44), Vector3(0, 0.04, -radius * 0.35), style.trim, "PowerStroke")
 for i in 4:
  var angle := PI * 0.25 + i * PI * 0.5
  _disc(p, root, 0.01, 0.012, Vector3(cos(angle) * radius * 0.82, 0.07, sin(angle) * radius * 0.82), style.light, "Indicator", 8)
 return {"item": item, "root": root, "pad": pad, "material": material, "color": color, "kind": "switch", "emitters": [pad.get_node("ColoredButton")]}

static func _spring(p, root: Node3D, item: Dictionary) -> Dictionary:
 # Deliberately bypass theme palettes: these three colors are the visual identity.
 var red: StandardMaterial3D = p.material(Objects.COLORS[item.properties.color])
 var blue: StandardMaterial3D = p.material(Color("175bd2"))
 var yellow: StandardMaterial3D = p.material(Color("ffdb40"), 0.25)
 var steel: StandardMaterial3D = p.material(Color("b7c5d3"))
 steel.metallic = 0.7
 var width: float = float(item.properties.width) * p.SCALE
 var radius := width * 0.5
 _box(p, root, Vector3(width * 0.68, 0.04, 0.10), Vector3(0, 0.02, 0.025), blue, "SpringFoot")
 var pad := Node3D.new()
 pad.name = "SpringPad"
 pad.position = Vector3(0, radius * 0.85, 0)
 # Face points toward the launch direction, tipped upward for table readability.
 pad.rotation.x = deg_to_rad(-20.0)
 root.add_child(pad)
 for i in 3:
  var coil := TorusMesh.new()
  coil.inner_radius = radius * 0.38
  coil.outer_radius = radius * 0.47
  coil.rings = 20
  coil.ring_segments = 6
  p.mesh_node(coil, steel, Vector3(0, -0.02 - i * 0.018, 0), pad).name = "MetalCoil"
 _disc(p, pad, radius, 0.055, Vector3(0, 0.018, 0), red, "RoundedPad", 24)
 _disc(p, pad, radius * 0.88, 0.012, Vector3(0, 0.05, 0), yellow, "YellowRim", 24)
 _disc(p, pad, radius * 0.75, 0.014, Vector3(0, 0.061, 0), blue, "BlueInset", 24)
 _star(p, pad, radius * 0.55, 0.07, yellow)
 var arrow := PackedVector2Array([Vector2(-4, -float(item.properties.width) * 0.5 - 5), Vector2(4, -float(item.properties.width) * 0.5 - 5), Vector2(0, -float(item.properties.width) * 0.5 - 14)])
 p.mesh_node(p._prism(arrow, 0.003, yellow, yellow), null, Vector3(0, 0.005, 0), root).name = "LaunchDirection"
 return {"item": item, "root": root, "pad": pad, "rest": pad.position, "kind": "spring"}

static func update(entry: Dictionary) -> void:
 var item: Dictionary = entry.item
 match entry.kind:
  "gate": entry.panel.visible = not item.open
  "switch":
   entry.pad.position.y = 0.052 if item.active else 0.105
   entry.material.albedo_color = entry.color if item.active else Color(entry.color).darkened(0.3)
   entry.material.emission_energy_multiplier = 1.0 if item.active else 0.0
  "spring":
   var compression := sin(clampf(float(item.pulse) / 0.2, 0.0, 1.0) * PI) * 0.035
   entry.pad.position = Vector3(entry.rest) + Vector3(0, -compression * 0.3, compression)
  "lanes":
   for i in entry.lights.size():
    var light: StandardMaterial3D = entry.lights[i]
    var lit: bool = item.lanes[i].lit and item.properties.completion_mode == "light_all"
    light.albedo_color = Color("b6fff1") if item.complete else (Color("4affaa") if lit else Color("286876"))
    light.emission = light.albedo_color
    light.emission_energy_multiplier = 2.8 if item.complete else (1.6 if lit else 0.25)
   entry.label.visible = item.complete
  "diverter":
   entry.arm.rotation.y = -deg_to_rad(float(item.properties.state_a_angle if item.state == "a" else item.properties.state_b_angle))
   entry.indicator.albedo_color = Color("ffc84c") if item.pending_state != "" else Color("5af1cb")
  "dash_panel":
   entry.material.emission_energy_multiplier = 3.5 if item.pulse > 0.0 else 1.5

static func _lanes(p, root: Node3D, item: Dictionary, style: Dictionary) -> Dictionary:
 var dark: StandardMaterial3D = p.material(Color("172435"))
 var radius: float = float(item.properties.post_radius) * p.SCALE
 var crown: StandardMaterial3D = p.material(Color("77f9e5"), 1.5)
 var lights: Array[StandardMaterial3D] = []
 var emitters: Array[MeshInstance3D] = []
 for point: Vector2 in item.properties.points:
  var at := Vector3(point.x * p.SCALE, 0, point.y * p.SCALE)
  _disc(p, root, radius, 0.065, at + Vector3(0, 0.0325, 0), dark, "OctagonalPostFoot", 8)
  _disc(p, root, radius * 0.82, 0.28, at + Vector3(0, 0.19, 0), dark, "BarrierPost", 8)
  _disc(p, root, radius * 0.9, 0.045, at + Vector3(0, 0.35, 0), style.trim, "CrownRim", 8)
  _disc(p, root, radius * 0.76, 0.03, at + Vector3(0, 0.385, 0), crown, "IlluminatedCrown", 8)
  for side: float in [-1.0, 1.0]:
   _box(p, root, Vector3(radius * 0.25, 0.18, 0.012), at + Vector3(side * radius * 0.45, 0.20, -radius * 0.76), style.light, "PostStatusStrip")
 for i in item.properties.points.size() - 1:
  var a: Vector2 = item.properties.points[i]
  var b: Vector2 = item.properties.points[i + 1]
  var center := (a + b) * 0.5
  var material: StandardMaterial3D = p.material(Color("286876"), 0.25)
  lights.append(material)
  var strip := _box(p, root, Vector3((a.distance_to(b) - 2.0 * item.properties.post_radius) * p.SCALE, 0.007, 0.12), Vector3(center.x * p.SCALE, 0.008, center.y * p.SCALE), material, "PassingLane_%d" % (i + 1))
  strip.rotation.y = -(b - a).angle()
  emitters.append(strip)
 var label := Label3D.new()
 label.text = "LANE SET COMPLETE"
 label.font_size = 36
 label.pixel_size = 0.002
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.modulate = Color("a3ffe0")
 var midpoint: Vector2 = (item.properties.points[0] + item.properties.points[-1]) * 0.5
 label.position = Vector3(midpoint.x * p.SCALE, 0.66, midpoint.y * p.SCALE)
 root.add_child(label)
 return {"item": item, "root": root, "lights": lights, "label": label, "kind": "lanes", "emitters": emitters}

static func _diverter(p, root: Node3D, item: Dictionary, style: Dictionary) -> Dictionary:
 var length: float = float(item.properties.length) * p.SCALE
 _disc(p, root, 0.065, 0.06, Vector3(0, 0.03, 0), style.body, "RoutingHub", 12)
 var arm := Node3D.new()
 arm.name = "RoutingArm"
 root.add_child(arm)
 _box(p, arm, Vector3(length - 0.08, 0.20, 0.08), Vector3(0, 0.12, 0), style.body, "PhysicalBarrier")
 for side: float in [-1.0, 1.0]:
  _disc(p, arm, 0.04, 0.20, Vector3(side * (length * 0.5 - 0.04), 0.12, 0), style.body, "RoundedEnd", 12)
 _box(p, arm, Vector3(length * 0.85, 0.025, 0.07), Vector3(0, 0.2325, 0), style.trim, "ArmCap")
 for side: float in [-1.0, 1.0]:
  _box(p, arm, Vector3(length * 0.76, 0.025, 0.007), Vector3(0, 0.16, side * 0.044), style.light, "RouteLight")
 for i in 5:
  var brace := _box(p, arm, Vector3(0.018, 0.13, 0.092), Vector3((i - 2) * length / 6.0, 0.12, 0), style.trim, "Brace")
  if style.kind == "flap": brace.rotation.z = 0.45
 var indicator: StandardMaterial3D = p.material(Color("5af1cb"), 1.0)
 var indicator_mesh := _disc(p, root, 0.036, 0.02, Vector3(0, 0.255, 0), indicator, "PendingStateIndicator", 8)
 root.set_meta("diverter_style", style.kind)
 return {"item": item, "root": root, "arm": arm, "indicator": indicator, "kind": "diverter", "emitters": [indicator_mesh]}

static func _dash_panel(p, root: Node3D, item: Dictionary, style: Dictionary) -> Dictionary:
 # Original geometry: a dark inset belt, violet rails and three cyan chevrons.
 # No textures, models or other game assets are imported.
 var width: float = float(item.properties.width) * p.SCALE
 var dark: StandardMaterial3D = p.material(Color("182336"))
 var violet: StandardMaterial3D = p.material(Color("7456ad"), 0.15)
 var cyan: StandardMaterial3D = p.material(Color("58f2ff"), 1.5)
 var emitters: Array[MeshInstance3D] = []
 _box(p, root, Vector3(width, 0.035, 0.36), Vector3(0, 0.0175, 0), dark, "DashChassis")
 for side: float in [-1.0, 1.0]:
  _box(p, root, Vector3(0.035, 0.025, 0.36), Vector3(side * (width * 0.5 - 0.0175), 0.0425, 0), violet, "VioletFrame")
  for offset: float in [-0.12, 0.12]:
   _disc(p, root, 0.011, 0.006, Vector3(side * (width * 0.5 - 0.0175), 0.058, offset), style.trim, "FrameBolt", 6)
 for offset: float in [-0.09, 0.01, 0.11]:
  var half_arrow: float = minf(width * 0.30, 0.15) / p.SCALE
  var z: float = offset / p.SCALE
  var arrow := PackedVector2Array([Vector2(-half_arrow, z + 3), Vector2(0, z - 5), Vector2(half_arrow, z + 3), Vector2(half_arrow, z + 7), Vector2(0, z - 1), Vector2(-half_arrow, z + 7)])
  var mesh: MeshInstance3D = p.mesh_node(p._prism(arrow, 0.006, cyan, cyan), null, Vector3(0, 0.038, 0), root)
  mesh.name = "CyanChevron"
  emitters.append(mesh)
 return {"item": item, "root": root, "material": cyan, "kind": "dash_panel", "emitters": emitters}

static func bind_instance_materials(entry: Dictionary) -> void:
 # Baked meshes may share immutable materials, but state lights belong to one
 # resident Act. Animation must update the exact materials used by its meshes.
 if entry.kind == "lanes":
  entry.lights = entry.lights.duplicate()
  for i in entry.lights.size():
   entry.lights[i] = entry.lights[i].duplicate()
   entry.emitters[i].material_override = entry.lights[i]
 elif entry.kind in ["switch", "dash_panel", "diverter"]:
  var key := "indicator" if entry.kind == "diverter" else "material"
  entry[key] = entry[key].duplicate()
  for mesh: MeshInstance3D in entry.emitters: mesh.material_override = entry[key]
