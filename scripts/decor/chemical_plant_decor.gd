extends "res://scripts/decor/decor_skin.gd"
## Original, collisionless factory props in cell units. All primitives and
## materials are shared within this library; fluid is a static emissive insert.
var _meshes: Dictionary = {}
var _materials: Dictionary = {}

func _init(_owner_presentation: Node3D) -> void:
 skin_id = "chemical_plant"
 pools = {
  "small": {"surface": ["beacon", "valve", "vent"], "edge": ["beacon", "valve", "vent"], "either": ["beacon", "valve", "vent"]},
  "medium": {"surface": ["pump_elbow", "control_cabinet", "fluid_canister"], "edge": ["pump_elbow", "control_cabinet", "fluid_canister"], "either": ["pump_elbow", "control_cabinet", "fluid_canister"]},
  "large": {"surface": ["pipe_cluster", "tank_tower", "girder_machinery"], "edge": ["pipe_cluster", "tank_tower", "girder_machinery"], "either": ["pipe_cluster", "tank_tower", "girder_machinery"]},
  "landmark": {"surface": ["fluid_reactor", "pipe_arch"], "edge": ["fluid_reactor", "pipe_arch"], "either": ["fluid_reactor", "pipe_arch"]},
 }
 factory = build_variant
 _prepare_materials()

func build_variant(variant: String) -> Node3D:
 var root := Node3D.new()
 root.name = variant.to_pascal_case()
 match variant:
  "beacon": _beacon(root)
  "valve": _valve(root)
  "vent": _vent(root)
  "pump_elbow": _pump_elbow(root)
  "control_cabinet": _control_cabinet(root)
  "fluid_canister": _fluid_canister(root)
  "pipe_cluster": _pipe_cluster(root)
  "tank_tower": _tank_tower(root)
  "girder_machinery": _girder_machinery(root)
  "fluid_reactor": _fluid_reactor(root)
  "pipe_arch": _pipe_arch(root)
 return root

func _prepare_materials() -> void:
 var colors := {
  "steel": Color("a7b6cd"), "dark": Color("26334c"),
  "blue": Color("245aca"), "yellow": Color("e9b83f"),
  "black": Color("101a2b"), "cyan": Color("50e4f3"),
  "pink": Color("e964dc"), "green": Color("9deb63"),
  "red": Color("ff637a"), "glass": Color(0.40, 0.82, 0.96, 0.17),
 }
 for key: String in colors:
  var material := StandardMaterial3D.new()
  material.albedo_color = colors[key]
  material.roughness = 0.64
  if key in ["steel", "dark", "blue"]:
   material.metallic = 0.32
  if key in ["cyan", "pink", "green", "red"]:
   material.emission_enabled = true
   material.emission = colors[key]
   material.emission_energy_multiplier = 0.8
  if key == "glass":
   material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
   material.roughness = 0.2
  _materials[key] = material

func _primitive(kind: String) -> Mesh:
 if _meshes.has(kind): return _meshes[kind]
 var result: Mesh
 match kind:
  "box": result = BoxMesh.new()
  "ring":
   var ring := TorusMesh.new()
   ring.inner_radius = 0.72
   ring.outer_radius = 1.0
   ring.rings = 12
   ring.ring_segments = 5
   result = ring
  _:
   var cylinder := CylinderMesh.new()
   cylinder.top_radius = 1.0
   cylinder.bottom_radius = 1.0
   cylinder.height = 1.0
   cylinder.radial_segments = 10
   cylinder.rings = 1
   result = cylinder
 _meshes[kind] = result
 return result

func _piece(root: Node3D, kind: String, color: String, at: Vector3, size: Vector3) -> MeshInstance3D:
 var piece := MeshInstance3D.new()
 piece.mesh = _primitive(kind)
 piece.material_override = _materials[color]
 piece.position = at
 piece.scale = size
 piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(piece)
 return piece

func _box(root: Node3D, color: String, at: Vector3, size: Vector3) -> MeshInstance3D:
 return _piece(root, "box", color, at, size)

func _cylinder(root: Node3D, color: String, at: Vector3, radius: float, height: float) -> MeshInstance3D:
 return _piece(root, "cylinder", color, at, Vector3(radius, height, radius))

func _pipe(root: Node3D, color: String, a: Vector3, b: Vector3, radius: float) -> MeshInstance3D:
 var piece := _cylinder(root, color, (a + b) * 0.5, radius, a.distance_to(b))
 piece.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
 return piece

func _bar(root: Node3D, color: String, a: Vector3, b: Vector3, width: float) -> MeshInstance3D:
 var piece := _box(root, color, (a + b) * 0.5, Vector3(width, a.distance_to(b), width))
 piece.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
 return piece

func _arc(root: Node3D, color: String, center: Vector3, bend_radius: float, pipe_radius: float, start: float, sweep: float, steps: int = 6) -> void:
 # Segmented elbows preserve a deliberately faceted low-poly silhouette.
 for i in steps:
  var angle_a := start + sweep * float(i) / steps
  var angle_b := start + sweep * float(i + 1) / steps
  var a := center + Vector3(cos(angle_a), sin(angle_a), 0) * bend_radius
  var b := center + Vector3(cos(angle_b), sin(angle_b), 0) * bend_radius
  _pipe(root, color, a, b, pipe_radius)

func _hazard_plate(root: Node3D, center: Vector3, width: float) -> void:
 _box(root, "yellow", center, Vector3(width, 0.10, 0.025))
 for i in 4:
  var stripe := _box(root, "black", center + Vector3((float(i) - 1.5) * width * 0.22, 0, 0.015), Vector3(width * 0.09, 0.095, 0.012))
  stripe.rotation.z = -0.4

func _beacon(root: Node3D) -> void:
 _box(root, "dark", Vector3(0, 0.04, 0), Vector3(0.26, 0.08, 0.24))
 _cylinder(root, "steel", Vector3(0, 0.14, 0), 0.075, 0.12)
 _cylinder(root, "red", Vector3(0, 0.255, 0), 0.085, 0.13)
 _cylinder(root, "dark", Vector3(0, 0.33, 0), 0.105, 0.035)
 _hazard_plate(root, Vector3(0, 0.075, 0.13), 0.20)

func _valve_wheel(root: Node3D, center: Vector3, radius: float) -> void:
 var wheel := _piece(root, "ring", "red", center, Vector3.ONE * radius)
 wheel.rotation.x = PI * 0.5
 for i in 3:
  var angle := TAU * float(i) / 3.0
  _bar(root, "steel", center, center + Vector3(cos(angle), sin(angle), 0) * radius * 0.8, radius * 0.14)
 _pipe(root, "steel", center - Vector3(0, 0, 0.06), center + Vector3(0, 0, 0.03), radius * 0.24)

func _valve(root: Node3D) -> void:
 _box(root, "dark", Vector3(0, 0.04, 0), Vector3(0.32, 0.08, 0.28))
 _pipe(root, "blue", Vector3(-0.17, 0.15, 0), Vector3(0.17, 0.15, 0), 0.075)
 _pipe(root, "steel", Vector3(-0.18, 0.15, 0), Vector3(-0.13, 0.15, 0), 0.10)
 _pipe(root, "steel", Vector3(0.13, 0.15, 0), Vector3(0.18, 0.15, 0), 0.10)
 _valve_wheel(root, Vector3(0, 0.24, 0.13), 0.13)

func _vent(root: Node3D) -> void:
 _box(root, "steel", Vector3(0, 0.085, 0), Vector3(0.40, 0.17, 0.32))
 _box(root, "black", Vector3(0, 0.175, 0), Vector3(0.32, 0.015, 0.25))
 for i in 5:
  _box(root, "dark", Vector3(0, 0.19, (i - 2) * 0.048), Vector3(0.30, 0.025, 0.018))
 _box(root, "blue", Vector3(0, 0.09, 0.168), Vector3(0.33, 0.07, 0.02))
 _box(root, "cyan", Vector3(0.12, 0.09, 0.182), Vector3(0.055, 0.035, 0.01))

func _pump_elbow(root: Node3D) -> void:
 _box(root, "dark", Vector3(0, 0.055, 0), Vector3(0.72, 0.11, 0.48))
 _pipe(root, "steel", Vector3(-0.26, 0.23, 0), Vector3(0.04, 0.23, 0), 0.14)
 for i in 4:
  _pipe(root, "dark", Vector3(-0.24 + i * 0.07, 0.23, 0), Vector3(-0.21 + i * 0.07, 0.23, 0), 0.15)
 _cylinder(root, "blue", Vector3(0.15, 0.28, 0), 0.135, 0.34)
 _arc(root, "blue", Vector3(0.02, 0.45, 0), 0.13, 0.095, 0, PI * 0.5, 4)
 _pipe(root, "blue", Vector3(0.02, 0.58, 0), Vector3(-0.19, 0.58, 0), 0.095)
 _pipe(root, "steel", Vector3(-0.20, 0.58, 0), Vector3(-0.15, 0.58, 0), 0.12)
 _hazard_plate(root, Vector3(0.14, 0.15, 0.25), 0.29)

func _control_cabinet(root: Node3D) -> void:
 _box(root, "dark", Vector3(0, 0.04, 0), Vector3(0.53, 0.08, 0.39))
 _box(root, "blue", Vector3(0, 0.31, 0), Vector3(0.45, 0.48, 0.32))
 _box(root, "steel", Vector3(0, 0.32, 0.17), Vector3(0.39, 0.39, 0.035))
 _box(root, "black", Vector3(0, 0.415, 0.192), Vector3(0.29, 0.14, 0.018))
 _box(root, "green", Vector3(-0.035, 0.415, 0.205), Vector3(0.18, 0.085, 0.01))
 for i in 3:
  _pipe(root, ["red", "cyan", "yellow"][i], Vector3(-0.11 + i * 0.11, 0.28, 0.19), Vector3(-0.11 + i * 0.11, 0.28, 0.215), 0.023)
 _hazard_plate(root, Vector3(0, 0.15, 0.20), 0.33)
 _cylinder(root, "red", Vector3(0.13, 0.59, 0), 0.035, 0.08)

func _fluid_canister(root: Node3D) -> void:
 _cylinder(root, "dark", Vector3(0, 0.07, 0), 0.25, 0.14)
 _cylinder(root, "green", Vector3(0, 0.29, 0), 0.17, 0.32)
 _cylinder(root, "glass", Vector3(0, 0.34, 0), 0.215, 0.46)
 _cylinder(root, "steel", Vector3(0, 0.57, 0), 0.24, 0.08)
 for x in [-0.20, 0.20]:
  _bar(root, "dark", Vector3(x, 0.12, 0.08), Vector3(x, 0.56, 0.08), 0.035)
  _bar(root, "yellow", Vector3(x, 0.60, 0), Vector3(x, 0.71, 0), 0.035)
 _bar(root, "yellow", Vector3(-0.20, 0.71, 0), Vector3(0.20, 0.71, 0), 0.035)

func _pipe_cluster(root: Node3D) -> void:
 _box(root, "dark", Vector3(0, 0.06, 0), Vector3(0.94, 0.12, 0.53))
 for i in 3:
  var x := (float(i) - 1.0) * 0.28
  var height: float = [1.04, 1.36, 0.88][i]
  var color: String = ["blue", "yellow", "steel"][i]
  _pipe(root, color, Vector3(x, 0.12, 0), Vector3(x, height - 0.14, 0), 0.09)
  _arc(root, color, Vector3(x - 0.12, height - 0.14, 0), 0.12, 0.09, 0, PI * 0.5, 4)
  _pipe(root, "dark", Vector3(x - 0.18, height - 0.02, 0), Vector3(x - 0.12, height - 0.02, 0), 0.11)
  for y in [0.25, 0.66]:
   _cylinder(root, "steel", Vector3(x, y, 0), 0.115, 0.065)
 _bar(root, "dark", Vector3(-0.38, 0.48, 0.12), Vector3(0.38, 0.48, 0.12), 0.075)
 _hazard_plate(root, Vector3(0, 0.18, 0.27), 0.65)

func _tank_tower(root: Node3D) -> void:
 _box(root, "dark", Vector3(0, 0.06, 0), Vector3(0.78, 0.12, 0.70))
 for x in [-0.27, 0.27]:
  _bar(root, "steel", Vector3(x, 0.12, 0), Vector3(x, 0.45, 0), 0.10)
 _cylinder(root, "blue", Vector3(0, 0.85, 0), 0.32, 0.89)
 for y in [0.42, 0.64, 1.10, 1.30]:
  _cylinder(root, "steel", Vector3(0, y, 0), 0.35, 0.055)
 _cylinder(root, "dark", Vector3(0, 1.36, 0), 0.24, 0.11)
 _cylinder(root, "red", Vector3(0, 1.47, 0), 0.045, 0.11)
 _box(root, "black", Vector3(0, 0.88, 0.316), Vector3(0.16, 0.37, 0.035))
 _box(root, "cyan", Vector3(0, 0.86, 0.34), Vector3(0.08, 0.29, 0.016))
 _pipe(root, "yellow", Vector3(0.32, 0.25, 0), Vector3(0.32, 0.70, 0), 0.055)
 _hazard_plate(root, Vector3(0, 0.26, 0.29), 0.38)

func _girder_machinery(root: Node3D) -> void:
 _box(root, "dark", Vector3(0, 0.065, 0), Vector3(0.78, 0.13, 0.58))
 _box(root, "blue", Vector3(0, 0.58, -0.04), Vector3(0.56, 0.92, 0.35))
 for x in [-0.33, 0.33]:
  _bar(root, "steel", Vector3(x, 0.12, 0.20), Vector3(x, 1.28, 0.20), 0.085)
 for y in [0.17, 0.67, 1.22]:
  _bar(root, "steel", Vector3(-0.33, y, 0.20), Vector3(0.33, y, 0.20), 0.075)
 for y in [0.20, 0.73]:
  _bar(root, "dark", Vector3(-0.29, y, 0.25), Vector3(0.29, y + 0.43, 0.25), 0.06)
  _bar(root, "dark", Vector3(0.29, y, 0.26), Vector3(-0.29, y + 0.43, 0.26), 0.06)
 _box(root, "green", Vector3(0, 0.93, 0.15), Vector3(0.39, 0.11, 0.028))
 _hazard_plate(root, Vector3(0, 1.28, 0.22), 0.73)
 _pipe(root, "yellow", Vector3(0.38, 0.18, -0.03), Vector3(0.38, 1.13, -0.03), 0.055)

func _fluid_reactor(root: Node3D) -> void:
 _cylinder(root, "dark", Vector3(0, 0.11, 0), 0.48, 0.22)
 _cylinder(root, "pink", Vector3(0, 0.62, 0), 0.29, 0.79)
 _cylinder(root, "glass", Vector3(0, 0.88, 0), 0.37, 1.30)
 for y in [0.25, 1.48]:
  _cylinder(root, "steel", Vector3(0, y, 0), 0.43, 0.12)
  _cylinder(root, "cyan", Vector3(0, y + 0.07, 0), 0.405, 0.025)
 for angle in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
  var offset := Vector3(cos(angle), 0, sin(angle)) * 0.37
  _bar(root, "dark", offset + Vector3.UP * 0.30, offset + Vector3.UP * 1.42, 0.048)
 _cylinder(root, "blue", Vector3(0, 1.61, 0), 0.28, 0.15)
 _cylinder(root, "red", Vector3(0, 1.74, 0), 0.055, 0.12)
 _pipe(root, "yellow", Vector3(-0.48, 0.20, -0.10), Vector3(-0.48, 1.34, -0.10), 0.065)
 _pipe(root, "yellow", Vector3(-0.48, 1.34, -0.10), Vector3(-0.24, 1.34, -0.10), 0.065)
 _hazard_plate(root, Vector3(0, 0.12, 0.48), 0.55)

func _pipe_arch(root: Node3D) -> void:
 # The open center keeps this landmark airy at the pinball camera angle.
 for x in [-0.72, 0.72]:
  _box(root, "dark", Vector3(x, 0.075, 0), Vector3(0.35, 0.15, 0.52))
  _pipe(root, "blue", Vector3(x, 0.15, 0), Vector3(x, 0.88, 0), 0.115)
  for y in [0.24, 0.67]:
   _cylinder(root, "steel", Vector3(x, y, 0), 0.145, 0.075)
  _hazard_plate(root, Vector3(x, 0.16, 0.27), 0.29)
 _arc(root, "blue", Vector3(0, 0.88, 0), 0.72, 0.115, 0, PI, 10)
 _arc(root, "yellow", Vector3(0, 0.88, -0.18), 0.56, 0.045, 0, PI, 9)
 _pipe(root, "yellow", Vector3(-0.56, 0.18, -0.18), Vector3(-0.56, 0.88, -0.18), 0.045)
 _pipe(root, "yellow", Vector3(0.56, 0.18, -0.18), Vector3(0.56, 0.88, -0.18), 0.045)
 _box(root, "steel", Vector3(0, 1.61, 0), Vector3(0.23, 0.16, 0.29))
 _box(root, "green", Vector3(0, 1.62, 0.155), Vector3(0.13, 0.075, 0.025))
