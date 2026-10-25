extends "res://scripts/decor/decor_skin.gd"
## Original procedural sanctuary masonry. Units are authored cells; no physics nodes.
var meshes: Dictionary = {}
var materials: Dictionary = {}

func _init(_presentation: Node3D) -> void:
 skin_id = "sky_sanctuary"
 var sizes := {
  "small": ["fallen_capital", "vine_tablet", "sky_blossoms"],
  "medium": ["broken_column", "orb_reliquary", "stepped_fountain", "azure_tablet"],
  "large": ["vine_obelisk", "broken_colonnade", "sanctuary_palm"],
  "landmark": ["sanctuary_belfry", "sky_aqueduct", "astral_dais"],
 }
 for size: String in sizes:
  pools[size] = {}
  for hint: String in ["surface", "edge", "either"]: pools[size][hint] = sizes[size].duplicate()
 factory = build_variant
 var colors := {"stone": "bdc4ac", "warm": "d5c99f", "pale": "e2dfc4", "shadow": "617f7c", "gold": "a38c49", "moss": "4c743b", "leaf": "6c9b49", "blue": "15435d", "cyan": "64b8c7", "flower": "cf90bb", "trunk": "80765a"}
 for key: String in colors:
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(colors[key])
  mat.roughness = 0.92
  mat.metallic_specular = 0.18
  if key == "blue": mat.roughness = 0.24
  if key == "cyan":
   mat.emission_enabled = true
   mat.emission = Color(colors[key])
   mat.emission_energy_multiplier = 0.12
  materials[key] = mat

func primitive(kind: String) -> Mesh:
 if meshes.has(kind): return meshes[kind]
 var result: Mesh
 if kind == "box": result = BoxMesh.new()
 elif kind == "sphere":
  var sphere := SphereMesh.new()
  sphere.radius = 1.0
  sphere.height = 2.0
  sphere.radial_segments = 12
  sphere.rings = 6
  result = sphere
 else:
  var cylinder := CylinderMesh.new()
  cylinder.top_radius = 0.0 if kind == "cone" else 1.0
  cylinder.bottom_radius = 1.0
  cylinder.height = 1.0
  cylinder.radial_segments = 8
  cylinder.rings = 1
  result = cylinder
 meshes[kind] = result
 return result

func piece(root: Node3D, kind: String, color: String, at: Vector3, size: Vector3) -> MeshInstance3D:
 var mesh := MeshInstance3D.new()
 mesh.mesh = primitive(kind)
 mesh.material_override = materials[color]
 mesh.position = at
 mesh.scale = size
 root.add_child(mesh)
 return mesh

func box(root: Node3D, color: String, at: Vector3, size: Vector3) -> MeshInstance3D:
 return piece(root, "box", color, at, size)

func bar(root: Node3D, color: String, a: Vector3, b: Vector3, width: float) -> void:
 var mesh := box(root, color, (a + b) * 0.5, Vector3(width, a.distance_to(b), width))
 mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func vine(root: Node3D, at: Vector3, length: float) -> void:
 for i in 5:
  var point := at + Vector3(sin(i * 1.7) * 0.035, -length * i / 5.0, 0.01)
  piece(root, "sphere", "moss" if i % 2 == 0 else "leaf", point, Vector3(0.065, length * 0.15, 0.035))

func column(root: Node3D, at: Vector3, height: float, radius: float, broken := false) -> void:
 box(root, "warm", at + Vector3.UP * 0.06, Vector3(radius * 2.7, 0.12, radius * 2.7))
 piece(root, "cylinder", "stone", at + Vector3.UP * height * 0.5, Vector3(radius, height - 0.1, radius))
 for i in 8:
  var angle := TAU * i / 8.0
  piece(root, "cylinder", "pale" if i % 3 else "warm", at + Vector3(cos(angle) * radius * 0.89, height * 0.5, sin(angle) * radius * 0.89), Vector3(radius * 0.13, height * 0.79, radius * 0.13))
 if broken:
  var chip := box(root, "pale", at + Vector3(0.02, height, 0), Vector3(radius * 1.5, 0.12, radius * 1.5))
  chip.rotation.z = 0.22
 else:
  box(root, "pale", at + Vector3.UP * height, Vector3(radius * 2.8, 0.11, radius * 2.8))
  box(root, "gold", at + Vector3.UP * (height - 0.10), Vector3(radius * 2.2, 0.035, radius * 2.2))

func arch(root: Node3D, at: Vector3, width: float, height: float, depth: float, broken := false) -> void:
 var radius := width * 0.39
 var spring_height := height - radius - 0.08
 for side: int in [-1, 1]:
  column(root, at + Vector3(side * radius, 0, 0), spring_height, width * 0.075)
 for i in (6 if broken else 9):
  var angle := PI * (i + 0.5) / 9.0
  var block := box(root, "warm" if i % 3 == 0 else "pale", at + Vector3(cos(angle) * radius, spring_height + sin(angle) * radius, 0), Vector3(width * 0.155, width * 0.14, depth))
  block.rotation.z = angle - PI * 0.5

func build_variant(variant: String) -> Node3D:
 var root := Node3D.new()
 root.name = variant.to_pascal_case()
 match variant:
  "fallen_capital":
   var slab := box(root, "warm", Vector3(0, 0.10, 0), Vector3(0.40, 0.19, 0.30))
   slab.rotation.z = 0.16
   box(root, "pale", Vector3(0.04, 0.22, 0), Vector3(0.32, 0.07, 0.26))
   vine(root, Vector3(-0.13, 0.25, 0.14), 0.20)
  "vine_tablet":
   box(root, "stone", Vector3(0, 0.055, 0), Vector3(0.38, 0.11, 0.32))
   for i in 3: vine(root, Vector3((i - 1) * 0.10, 0.18, i * 0.04), 0.16)
  "sky_blossoms":
   piece(root, "cylinder", "warm", Vector3(0, 0.06, 0), Vector3(0.17, 0.12, 0.17))
   for i in 3:
    var at := Vector3((i - 1) * 0.10, 0.21 + (i % 2) * 0.07, 0)
    bar(root, "moss", at * Vector3(1, 0, 1), at, 0.02)
    piece(root, "sphere", "flower", at, Vector3(0.075, 0.035, 0.065))
  "broken_column":
   column(root, Vector3.ZERO, 0.58, 0.18, true)
   vine(root, Vector3(0.1, 0.52, 0.16), 0.45)
  "orb_reliquary":
   column(root, Vector3.ZERO, 0.35, 0.14)
   piece(root, "sphere", "blue", Vector3(0, 0.54, 0), Vector3.ONE * 0.16)
   for side: int in [-1, 1]: bar(root, "gold", Vector3(side * 0.20, 0.32, 0), Vector3(side * 0.12, 0.65, 0), 0.035)
   piece(root, "sphere", "cyan", Vector3(0, 0.57, 0.145), Vector3.ONE * 0.035)
  "stepped_fountain":
   for i in 3: piece(root, "cylinder", "pale", Vector3(0, 0.07 + i * 0.14, 0), Vector3(0.36 - i * 0.09, 0.10, 0.36 - i * 0.09))
   piece(root, "cylinder", "blue", Vector3(0, 0.13, 0), Vector3(0.28, 0.016, 0.28))
   piece(root, "cone", "cyan", Vector3(0, 0.51, 0), Vector3(0.05, 0.26, 0.05))
  "azure_tablet":
   box(root, "warm", Vector3(0, 0.11, 0), Vector3(0.60, 0.22, 0.40))
   box(root, "blue", Vector3(0, 0.23, 0), Vector3(0.48, 0.025, 0.29))
   for i in 3: box(root, "cyan", Vector3((i - 1) * 0.12, 0.25, 0), Vector3(0.025, 0.008, 0.16 - abs(i - 1) * 0.06))
  "vine_obelisk":
   column(root, Vector3.ZERO, 1.55, 0.23, true)
   vine(root, Vector3(0.14, 1.50, 0.22), 1.26)
   box(root, "moss", Vector3(0, 0.13, 0), Vector3(0.55, 0.05, 0.49))
  "broken_colonnade":
   arch(root, Vector3.ZERO, 1.25, 1.32, 0.30, true)
   vine(root, Vector3(-0.43, 1.17, 0.19), 0.75)
  "sanctuary_palm":
   box(root, "stone", Vector3(0, 0.08, 0), Vector3(0.67, 0.16, 0.62))
   for i in 5: piece(root, "cylinder", "trunk", Vector3(i * 0.018, 0.17 + i * 0.17, 0), Vector3(0.075, 0.19, 0.075))
   for i in 7:
    var angle := TAU * i / 7.0
    var leaf := piece(root, "sphere", "moss" if i % 2 else "leaf", Vector3(cos(angle) * 0.23, 1.02, sin(angle) * 0.23), Vector3(0.40, 0.055, 0.10))
    leaf.rotation.y = -angle
    leaf.rotation.z = -0.20
  "sanctuary_belfry":
   box(root, "stone", Vector3(0, 0.07, 0), Vector3(3.0, 0.14, 0.98))
   for side: int in [-1, 1]:
    column(root, Vector3(side * 0.35, 0.14, 0), 1.40, 0.16)
    column(root, Vector3(side * 1.12, 0.14, 0), 0.48, 0.20, true)
   box(root, "warm", Vector3(0, 1.65, 0), Vector3(1.22, 0.22, 0.83))
   arch(root, Vector3(0, 1.77, 0), 0.78, 0.75, 0.34, true)
   piece(root, "sphere", "blue", Vector3(0, 1.02, 0), Vector3(0.20, 0.27, 0.20))
   vine(root, Vector3(0.46, 1.74, 0.39), 1.3)
  "sky_aqueduct":
   box(root, "stone", Vector3(0, 0.055, 0), Vector3(3.0, 0.11, 0.92))
   for side: int in [-1, 1]: arch(root, Vector3(side * 0.72, 0.11, 0), 1.40, 1.1, 0.50)
   box(root, "warm", Vector3(0, 1.23, 0), Vector3(3.0, 0.12, 0.84))
   box(root, "blue", Vector3(0, 1.30, 0), Vector3(2.8, 0.025, 0.44))
   for side: int in [-1, 1]: vine(root, Vector3(side * 1.10, 1.30, 0.43), 0.76)
  "astral_dais":
   piece(root, "cylinder", "stone", Vector3(0, 0.09, 0), Vector3(0.81, 0.18, 0.81))
   piece(root, "cylinder", "blue", Vector3(0, 0.19, 0), Vector3(0.67, 0.035, 0.67))
   for i in 11:
    var angle := TAU * i / 14.0 - PI * 0.5
    var block := box(root, "pale" if i % 2 else "warm", Vector3(cos(angle) * 0.62, 0.91 + sin(angle) * 0.62, 0), Vector3(0.25, 0.15, 0.24))
    block.rotation.z = angle + PI * 0.5
   vine(root, Vector3(-0.5, 1.24, 0.14), 0.55)
 return root
