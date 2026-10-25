extends "res://scripts/decor/decor_skin.gd"
## Original casino ornaments, in construction-cell units. No gameplay nodes.
## Published pool order is shared by all hints and must remain stable.
var meshes: Dictionary = {}
var materials: Dictionary = {}

func _init(_presentation: Node3D) -> void:
 skin_id = "casino_night"
 var sizes := {
  "small": ["neon_star", "chip_stack", "diamond_ornament"],
  "medium": ["reel_cabinet", "neon_palm", "crown_lamp", "card_fan"],
  "large": ["star_lantern", "reel_tower", "casino_pylon"],
  "landmark": ["jackpot_palace", "star_gateway", "roulette_pavilion"],
 }
 for size: String in sizes:
  pools[size] = {}
  for hint: String in ["surface", "edge", "either"]: pools[size][hint] = sizes[size].duplicate()
 factory = build_variant
 var colors := {"gold": "b8812d", "gold_light": "d3a451", "navy": "10162f", "blue": "163da4", "red": "a51c3d", "purple": "44276e", "ivory": "8194b2", "dark": "080d20", "pink": "e31b59", "aqua": "127edb", "mint": "21b85d", "amber": "ff9e24"}
 for key: String in colors:
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(colors[key])
  mat.roughness = 0.62
  mat.metallic_specular = 0.3
  if key in ["pink", "aqua", "mint", "amber"]:
   mat.emission_enabled = true
   mat.emission = mat.albedo_color
   mat.emission_energy_multiplier = 2.8
  materials[key] = mat

func primitive(kind: String) -> Mesh:
 if meshes.has(kind): return meshes[kind]
 var result: Mesh
 if kind == "box": result = BoxMesh.new()
 elif kind == "star":
  var surface := SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  var outline := PackedVector2Array()
  for i in 10:
   var angle := -PI * 0.5 + i * TAU / 10.0
   outline.append(Vector2(cos(angle), -sin(angle)) * (0.5 if i % 2 == 0 else 0.23))
  var indices := Geometry2D.triangulate_polygon(outline)
  for side: float in [-1.0, 1.0]:
   for i in range(0, indices.size(), 3):
    for j in ([0, 1, 2] if side < 0 else [2, 1, 0]):
     var point := outline[indices[i + j]]
     surface.add_vertex(Vector3(point.x, point.y, side * 0.06))
  for i in 10:
   var a := Vector3(outline[i].x, outline[i].y, -0.06)
   var b := Vector3(outline[(i + 1) % 10].x, outline[(i + 1) % 10].y, -0.06)
   for v: Vector3 in [a, b, a + Vector3(0, 0, 0.12), b, b + Vector3(0, 0, 0.12), a + Vector3(0, 0, 0.12)]: surface.add_vertex(v)
  surface.generate_normals()
  result = surface.commit()
 else:
  var cylinder := CylinderMesh.new()
  cylinder.top_radius = 0.0 if kind == "cone" else 1.0
  cylinder.bottom_radius = 1.0
  if kind == "lantern_lower": cylinder.bottom_radius = 0.55
  if kind == "lantern_upper": cylinder.top_radius = 0.18
  cylinder.height = 1.0
  cylinder.radial_segments = 12
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

func star(root: Node3D, at: Vector3, size: float, color := "amber") -> void:
 piece(root, "star", "gold", at, Vector3(size, size, size))
 piece(root, "star", color, at + Vector3(0, 0, size * 0.065), Vector3(size * 0.75, size * 0.75, size * 0.3))

func frame(root: Node3D, at: Vector3, size: Vector2, color := "amber", width := 0.035) -> void:
 for side: int in [-1, 1]:
  box(root, color, at + Vector3(side * size.x * 0.5, 0, 0), Vector3(width, size.y, width))
  box(root, color, at + Vector3(0, side * size.y * 0.5, 0), Vector3(size.x, width, width))

func build_variant(variant: String, landmark_layout := true) -> Node3D:
 var root := Node3D.new()
 root.name = variant.to_pascal_case()
 match variant:
  "neon_star":
   box(root, "navy", Vector3(0, 0.035, 0), Vector3(0.30, 0.07, 0.22))
   star(root, Vector3(0, 0.23, 0), 0.42, "pink")
  "chip_stack": chips(root)
  "diamond_ornament":
   piece(root, "cylinder", "gold", Vector3(0, 0.045, 0), Vector3(0.17, 0.09, 0.17))
   var diamond := box(root, "blue", Vector3(0, 0.25, 0), Vector3(0.24, 0.24, 0.10))
   diamond.rotation.z = PI * 0.25
   var inset := box(root, "aqua", Vector3(0, 0.25, 0.06), Vector3(0.14, 0.14, 0.02))
   inset.rotation.z = PI * 0.25
  "reel_cabinet": reels(root)
  "neon_palm": palm(root)
  "crown_lamp": crown(root)
  "card_fan": cards(root)
  "star_lantern": lantern(root)
  "reel_tower":
   box(root, "navy", Vector3(0, 0.11, 0), Vector3(0.84, 0.22, 0.70))
   for i in 2:
    var machine := Node3D.new()
    root.add_child(machine)
    machine.position.y = 0.22 + i * 0.68
    reels(machine)
   star(root, Vector3(0, 1.80, 0), 0.44, "pink")
  "casino_pylon": pylon(root)
  "jackpot_palace": palace(root, landmark_layout)
  "star_gateway": gateway(root)
  "roulette_pavilion": roulette(root)
 return root

func chips(root: Node3D) -> void:
 for i in 4:
  piece(root, "cylinder", "red" if i % 2 == 0 else "blue", Vector3(0, 0.035 + i * 0.065, 0), Vector3(0.18, 0.06, 0.18))
  for j in 6:
   var angle := TAU * j / 6.0
   var mark := box(root, "ivory", Vector3(cos(angle) * 0.17, 0.035 + i * 0.065, sin(angle) * 0.17), Vector3(0.045, 0.045, 0.028))
   mark.rotation.y = PI * 0.5 - angle
 # Solid embossed cap avoids resembling a collectible ring.
 piece(root, "cylinder", "gold", Vector3(0, 0.265, 0), Vector3(0.10, 0.012, 0.10))

func reels(root: Node3D) -> void:
 box(root, "red", Vector3(0, 0.34, 0), Vector3(0.72, 0.68, 0.48))
 box(root, "gold", Vector3(0, 0.08, 0), Vector3(0.78, 0.16, 0.53))
 box(root, "navy", Vector3(0, 0.40, 0.252), Vector3(0.62, 0.38, 0.035))
 frame(root, Vector3(0, 0.40, 0.28), Vector2(0.64, 0.40), "amber", 0.025)
 for i in 3:
  var x := (i - 1) * 0.195
  var reel := piece(root, "cylinder", "ivory", Vector3(x, 0.40, 0.27), Vector3(0.15, 0.17, 0.15))
  reel.rotation.z = PI * 0.5
  star(root, Vector3(x, 0.40, 0.423), 0.13, "pink" if i == 1 else "aqua")
 box(root, "blue", Vector3(0, 0.64, 0.015), Vector3(0.78, 0.09, 0.52))

func palm(root: Node3D) -> void:
 piece(root, "cylinder", "gold", Vector3(0, 0.04, 0), Vector3(0.23, 0.08, 0.23))
 bar(root, "gold", Vector3.ZERO, Vector3(0.06, 0.72, 0), 0.06)
 for i in 6:
  var angle := TAU * i / 6.0
  var start := Vector3(0.06, 0.72, 0)
  var elbow := start + Vector3(cos(angle) * 0.20, 0.12, sin(angle) * 0.20)
  bar(root, "mint", start, elbow, 0.045)
  bar(root, "mint", elbow, start + Vector3(cos(angle) * 0.39, -0.12, sin(angle) * 0.39), 0.045)

func crown(root: Node3D) -> void:
 piece(root, "cylinder", "gold", Vector3(0, 0.04, 0), Vector3(0.21, 0.08, 0.21))
 piece(root, "cylinder", "blue", Vector3(0, 0.32, 0), Vector3(0.07, 0.56, 0.07))
 piece(root, "cylinder", "purple", Vector3(0, 0.64, 0), Vector3(0.23, 0.24, 0.23))
 for i in 5:
  var angle := TAU * i / 5.0
  piece(root, "cone", "gold_light", Vector3(cos(angle) * 0.18, 0.82, sin(angle) * 0.18), Vector3(0.06, 0.20, 0.06))
  box(root, "amber", Vector3(cos(angle) * 0.21, 0.64, sin(angle) * 0.21), Vector3.ONE * 0.07)

func cards(root: Node3D) -> void:
 box(root, "gold", Vector3(0, 0.04, 0), Vector3(0.66, 0.08, 0.30))
 for i in 3:
  var card := Node3D.new()
  root.add_child(card)
  card.position = Vector3((i - 1) * 0.18, 0.33, i * 0.035)
  card.rotation.z = (1 - i) * 0.25
  box(card, "ivory", Vector3.ZERO, Vector3(0.28, 0.43, 0.025))
  var diamond := box(card, "red" if i % 2 == 0 else "blue", Vector3(0, 0, 0.02), Vector3(0.10, 0.13, 0.018))
  diamond.rotation.z = PI * 0.25

func lantern(root: Node3D) -> void:
 piece(root, "cylinder", "gold", Vector3(0, 0.08, 0), Vector3(0.39, 0.16, 0.39))
 piece(root, "cylinder", "blue", Vector3(0, 0.62, 0), Vector3(0.19, 1.10, 0.19))
 for i in 6:
  var angle := TAU * i / 6.0
  box(root, "pink", Vector3(cos(angle) * 0.19, 0.65, sin(angle) * 0.19), Vector3(0.035, 0.87, 0.035))
 # Faceted tulip lantern: a swollen lower bowl and tapered crown, not a cone.
 piece(root, "lantern_lower", "purple", Vector3(0, 1.10, 0), Vector3(0.43, 0.24, 0.43))
 piece(root, "lantern_upper", "purple", Vector3(0, 1.47, 0), Vector3(0.43, 0.50, 0.43))
 for i in 4:
  var y := 1.22 + i * 0.12
  var radius := lerpf(0.43, 0.077, (y - 1.22) / 0.50)
  piece(root, "cylinder", "aqua", Vector3(0, y, 0), Vector3(radius + 0.008, 0.035, radius + 0.008))
 star(root, Vector3(0, 1.27, 0.40), 0.45)
 star(root, Vector3(0, 1.82, 0), 0.30, "pink")

func pylon(root: Node3D) -> void:
 box(root, "gold", Vector3(0, 0.10, 0), Vector3(0.70, 0.20, 0.60))
 box(root, "navy", Vector3(0, 0.78, 0), Vector3(0.47, 1.30, 0.42))
 for side: int in [-1, 1]:
  box(root, "gold", Vector3(side * 0.28, 0.76, 0), Vector3(0.10, 1.18, 0.50))
  box(root, "aqua", Vector3(side * 0.28, 0.76, 0.26), Vector3(0.035, 1.0, 0.025))
 for i in 3: star(root, Vector3(0, 0.38 + i * 0.32, 0.24), 0.25, "pink" if i == 1 else "amber")
 box(root, "gold_light", Vector3(0, 1.42, 0), Vector3(0.73, 0.12, 0.62))
 piece(root, "cone", "red", Vector3(0, 1.60, 0), Vector3(0.31, 0.30, 0.27))

func palace(root: Node3D, wide: bool) -> void:
 box(root, "gold", Vector3(0, 0.08, 0), Vector3(3.0 if wide else 1.4, 0.16, 0.98))
 box(root, "navy", Vector3(0, 0.73, 0), Vector3(1.16, 1.30, 0.78))
 var cabinet := Node3D.new()
 root.add_child(cabinet)
 cabinet.position = Vector3(0, 0.62, 0.10)
 cabinet.scale = Vector3(1.35, 1.35, 1.1)
 reels(cabinet)
 box(root, "blue", Vector3(0, 1.68, 0), Vector3(1.32, 0.28, 0.85))
 frame(root, Vector3(0, 1.68, 0.44), Vector2(1.28, 0.25), "pink")
 star(root, Vector3(0, 2.00, 0), 0.52)
 for side: int in [-1, 1]:
  box(root, "red", Vector3(side * (1.02 if wide else 0.55), 0.45, 0), Vector3(0.72 if wide else 0.25, 0.70, 0.70))
  box(root, "gold_light", Vector3(side * (1.02 if wide else 0.55), 0.84, 0), Vector3(0.77 if wide else 0.30, 0.08, 0.77))
  star(root, Vector3(side * (1.02 if wide else 0.55), 1.08, 0), 0.44, "aqua")

func gateway(root: Node3D) -> void:
 for side: int in [-1, 1]:
  box(root, "gold", Vector3(side * 1.28, 0.06, 0), Vector3(0.44, 0.12, 0.98))
  box(root, "blue", Vector3(side * 1.28, 0.60, 0), Vector3(0.29, 1.08, 0.38))
  box(root, "pink", Vector3(side * 1.28, 0.61, 0.21), Vector3(0.06, 0.87, 0.035))
 box(root, "gold", Vector3(0, 1.16, 0), Vector3(2.85, 0.24, 0.48))
 box(root, "navy", Vector3(0, 1.16, 0.25), Vector3(2.55, 0.18, 0.03))
 for i in 7: star(root, Vector3((i - 3) * 0.35, 1.16, 0.285), 0.20, "aqua" if i % 2 == 0 else "amber")
 box(root, "pink", Vector3(0, 1.32, 0), Vector3(2.85, 0.04, 0.48))

func roulette(root: Node3D) -> void:
 piece(root, "cylinder", "gold", Vector3(0, 0.08, 0), Vector3(0.82, 0.16, 0.82))
 piece(root, "cylinder", "navy", Vector3(0, 0.18, 0), Vector3(0.75, 0.08, 0.75))
 for i in 12:
  var angle := TAU * i / 12.0
  var wedge := box(root, "red" if i % 2 == 0 else "blue", Vector3(cos(angle) * 0.55, 0.25, sin(angle) * 0.55), Vector3(0.19, 0.09, 0.21))
  wedge.rotation.y = -angle
  box(root, "amber", Vector3(cos(angle) * 0.72, 0.23, sin(angle) * 0.72), Vector3.ONE * 0.055)
 piece(root, "cone", "gold_light", Vector3(0, 0.42, 0), Vector3(0.30, 0.50, 0.30))
 star(root, Vector3(0, 0.85, 0), 0.40, "pink")
