extends "res://scripts/decor/decor_skin.gd"
## Original winter props, measured in authored cells. Visual nodes only.
var meshes: Dictionary = {}
var materials: Dictionary = {}

func _init(_presentation: Node3D) -> void:
 skin_id = "ice_cap"
 var sizes := {
  "small": ["crystal_shards", "snow_cairn", "frost_grass"],
  "medium": ["snow_pine", "ice_fan", "trail_fence", "frozen_spring"],
  "large": ["alpine_fir", "icicle_grotto", "glacier_sail"],
  "landmark": ["glacier_crown", "frozen_bridge", "aurora_basin"],
 }
 for size: String in sizes:
  pools[size] = {}
  for hint: String in ["surface", "edge", "either"]: pools[size][hint] = sizes[size].duplicate()
 factory = build_variant
 var colors := {"snow": "cfdfeb", "ice": "488caa", "deep": "234560", "rock": "34465c", "pine": "254f57", "trunk": "5e5969", "inset": "167b91", "glow": "68d9ce"}
 for key: String in colors:
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(colors[key])
  mat.roughness = 0.93 if key in ["snow", "rock", "pine", "trunk"] else 0.19
  mat.metallic_specular = 0.18 if key == "snow" else 0.7
  if key == "glow":
   mat.emission_enabled = true
   mat.emission = Color(colors[key])
   mat.emission_energy_multiplier = 0.35
  materials[key] = mat
 var crystal := ShaderMaterial.new()
 crystal.shader = preload("res://scripts/themes/ice_crystal.gdshader")
 materials.crystal = crystal

func primitive(kind: String) -> Mesh:
 if meshes.has(kind): return meshes[kind]
 var result: Mesh
 if kind == "box": result = BoxMesh.new()
 elif kind == "sphere":
  var sphere := SphereMesh.new()
  sphere.radius = 1.0
  sphere.height = 2.0
  sphere.radial_segments = 8
  sphere.rings = 4
  result = sphere
 else:
  var cylinder := CylinderMesh.new()
  cylinder.top_radius = 0.0 if kind == "cone" else (0.65 if kind == "facet" else 1.0)
  cylinder.bottom_radius = 1.0
  cylinder.height = 1.0
  cylinder.radial_segments = 8 if kind == "cylinder" else 6
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

func crystal(root: Node3D, at: Vector3, height: float, radius: float, lean := 0.0, transparent := true) -> void:
 var group := Node3D.new()
 root.add_child(group)
 group.position = at
 group.rotation.z = lean
 var color := "crystal" if transparent else "ice"
 piece(group, "facet", color, Vector3(0, height * 0.35, 0), Vector3(radius, height * 0.7, radius * 0.75))
 piece(group, "cone", color, Vector3(0, height * 0.85, 0), Vector3(radius * 0.65, height * 0.3, radius * 0.49))

func pine(root: Node3D, at: Vector3, height: float, radius: float) -> void:
 piece(root, "cylinder", "trunk", at + Vector3.UP * height * 0.23, Vector3(radius * 0.13, height * 0.46, radius * 0.13))
 for i in 3:
  var tier := 1.0 - i * 0.25
  var y := height * (0.40 + i * 0.22)
  piece(root, "cone", "pine", at + Vector3.UP * y, Vector3(radius * tier, height * 0.46, radius * tier))
  piece(root, "cone", "snow", at + Vector3.UP * (y + height * 0.055), Vector3(radius * tier * 0.85, height * 0.38, radius * tier * 0.85))

func arch(root: Node3D, at: Vector3, width: float, height: float, depth: float) -> void:
 for side: int in [-1, 1]:
  var pillar := box(root, "ice", at + Vector3(side * width * 0.40, height * 0.34, 0), Vector3(width * 0.19, height * 0.68, depth))
  pillar.rotation.z = side * -0.13
 for i in 7:
  var angle := PI * (i + 0.5) / 7.0
  var pos := at + Vector3(cos(angle) * width * 0.36, height * 0.57 + sin(angle) * height * 0.32, 0)
  var block := box(root, "ice", pos, Vector3(width * 0.20, height * 0.20, depth))
  block.rotation.z = angle - PI * 0.5
  piece(root, "sphere", "snow", pos + Vector3(0, height * 0.10, 0), Vector3(width * 0.12, 0.055, depth * 0.52))
 for i in 5:
  var tip := piece(root, "cone", "crystal", at + Vector3((i - 2) * width * 0.11, height * 0.57 + (0.14 if i % 2 else 0.0), 0), Vector3(width * 0.025, height * (0.18 + (i % 2) * 0.10), depth * 0.12))
  tip.rotation.z = PI

func build_variant(variant: String) -> Node3D:
 var root := Node3D.new()
 root.name = variant.to_pascal_case()
 match variant:
  "crystal_shards":
   for i in 3: crystal(root, Vector3((i - 1) * 0.11, 0, (i % 2) * 0.05), 0.22 + (i % 2) * 0.18, 0.065, (1 - i) * 0.25)
  "snow_cairn":
   for i in 2:
    piece(root, "sphere", "rock", Vector3(i * 0.12 - 0.05, 0.10, 0), Vector3(0.14, 0.12 + i * 0.035, 0.14))
    piece(root, "sphere", "snow", Vector3(i * 0.12 - 0.05, 0.20 + i * 0.03, 0), Vector3(0.13, 0.035, 0.13))
  "frost_grass":
   for i in 5:
    var blade := piece(root, "cone", "snow", Vector3((i - 2) * 0.045, 0.11, sin(i * 2.1) * 0.05), Vector3(0.022, 0.22 + (i % 2) * 0.1, 0.02))
    blade.rotation.z = (i - 2) * -0.18
  "snow_pine": pine(root, Vector3.ZERO, 0.64, 0.24)
  "ice_fan":
   for i in 5: crystal(root, Vector3((i - 2) * 0.09, 0, abs(i - 2) * 0.015), 0.62 - abs(i - 2) * 0.12, 0.085, (2 - i) * 0.22)
  "trail_fence":
   for side: int in [-1, 1]:
    box(root, "trunk", Vector3(side * 0.28, 0.21, 0), Vector3(0.07, 0.42, 0.08))
    box(root, "snow", Vector3(side * 0.28, 0.43, 0), Vector3(0.11, 0.045, 0.12))
   for y: float in [0.17, 0.31]:
    box(root, "trunk", Vector3(0, y, 0), Vector3(0.65, 0.045, 0.045))
    box(root, "snow", Vector3(0, y + 0.025, 0), Vector3(0.65, 0.025, 0.06))
  "frozen_spring":
   piece(root, "cylinder", "rock", Vector3(0, 0.065, 0), Vector3(0.31, 0.13, 0.27))
   piece(root, "cylinder", "inset", Vector3(0, 0.135, 0), Vector3(0.25, 0.025, 0.21))
   for i in 3: crystal(root, Vector3((i - 1) * 0.14, 0.14, -0.10), 0.22 + (i % 2) * 0.15, 0.04)
  "alpine_fir":
   pine(root, Vector3.ZERO, 1.22, 0.43)
   pine(root, Vector3(0.33, 0, 0.17), 0.42, 0.16)
   piece(root, "sphere", "snow", Vector3(-0.12, 0.04, 0), Vector3(0.34, 0.06, 0.28))
  "icicle_grotto": arch(root, Vector3.ZERO, 1.10, 0.92, 0.42)
  "glacier_sail":
   for i in 3: crystal(root, Vector3((i - 1) * 0.25, 0, 0), 1.30 - i * 0.27, 0.22, -0.13, false)
   piece(root, "sphere", "snow", Vector3(0, 0.08, 0), Vector3(0.55, 0.10, 0.29))
  "glacier_crown":
   box(root, "deep", Vector3(0, 0.09, 0), Vector3(3.0, 0.18, 1.0))
   piece(root, "sphere", "snow", Vector3(0, 0.19, 0), Vector3(1.48, 0.12, 0.48))
   for i in 7:
    crystal(root, Vector3((i - 3) * 0.36, 0.20, sin(i * 2.0) * 0.08), 2.15 - abs(i - 3) * 0.45, 0.19, (3 - i) * 0.09, i % 2 == 0)
  "frozen_bridge":
   box(root, "deep", Vector3(0, 0.07, 0), Vector3(3.0, 0.14, 1.0))
   arch(root, Vector3(0, 0.14, 0), 2.7, 1.22, 0.65)
  "aurora_basin":
   piece(root, "cylinder", "deep", Vector3(0, 0.09, 0), Vector3(0.80, 0.18, 0.80))
   piece(root, "cylinder", "inset", Vector3(0, 0.19, 0), Vector3(0.66, 0.04, 0.66))
   for i in 8:
    var angle := TAU * i / 8.0
    var at := Vector3(cos(angle) * 0.62, 0.20, sin(angle) * 0.62)
    piece(root, "sphere", "snow", at, Vector3(0.15, 0.07, 0.15))
   crystal(root, Vector3(0, 0.21, 0), 0.72, 0.13)
 return root
