extends "res://scripts/decor/decor_skin.gd"
## Original Spagonia-inspired primitives in cell units; no gameplay nodes.
## Pool order is stable: authored fixed variants address these exact indices.
var meshes: Dictionary = {}
var materials: Dictionary = {}

func _init(_presentation: Node3D) -> void:
 skin_id = "rooftop_run"
 var sizes := {
  "small": ["flower_urn", "chimney_pots", "festival_pennant"],
  "medium": ["garden_bench", "hedge_planter", "cafe_awning"],
  "large": ["roof_pavilion", "garden_arch", "cypress_terrace"],
  "landmark": ["clock_tower", "aqueduct", "festival_balloons"],
 }
 for size: String in sizes:
  pools[size] = {}
  for hint: String in ["surface", "edge", "either"]:
   pools[size][hint] = sizes[size].duplicate()
 factory = build_variant
 var colors := {"stone": "c3b191", "cream": "d8c4a1", "ochre": "c39b65", "roof": "cc5027", "roof_light": "e87935", "dark": "364b4b", "shutter": "326b60", "wood": "794637", "leaf": "458537", "leaf_light": "78a93c", "red": "e95158", "blue": "368fbd", "yellow": "e9bb4d", "flower": "e94d80"}
 for key: String in colors:
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(colors[key])
  mat.roughness = 0.88
  mat.metallic_specular = 0.15
  materials[key] = mat

func primitive(kind: String) -> Mesh:
 if meshes.has(kind): return meshes[kind]
 var result: Mesh
 match kind:
  "box": result = BoxMesh.new()
  "sphere":
   var sphere := SphereMesh.new()
   sphere.radius = 1.0
   sphere.height = 2.0
   sphere.radial_segments = 8
   sphere.rings = 4
   result = sphere
  "roof":
   var surface := SurfaceTool.new()
   surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   var a := Vector3(-0.5, 0, -0.5)
   var b := Vector3(0.5, 0, -0.5)
   var c := Vector3(-0.5, 0, 0.5)
   var d := Vector3(0.5, 0, 0.5)
   var e := Vector3(0, 1, -0.5)
   var f := Vector3(0, 1, 0.5)
   for vertex: Vector3 in [a, b, e, c, f, d, a, e, c, c, e, f, b, d, e, e, d, f, a, c, b, b, c, d]:
    surface.add_vertex(vertex)
   surface.generate_normals()
   result = surface.commit()
  _:
   var cylinder := CylinderMesh.new()
   cylinder.top_radius = 0.0 if kind == "cone" else (0.74 if kind == "pot" else 1.0)
   cylinder.bottom_radius = 1.0 if kind != "pot" else 0.54
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

func roof(root: Node3D, at: Vector3, size: Vector3) -> void:
 piece(root, "roof", "roof", at, size)
 box(root, "roof_light", at + Vector3.UP * size.y, Vector3(0.045, 0.04, size.z * 1.02))
 # Broad eaves remain readable; individual tiles would shimmer in the retro view.
 for side: int in [-1, 1]:
  box(root, "cream", at + Vector3(side * size.x * 0.49, -0.025, 0), Vector3(0.045, 0.055, size.z))

func build_variant(variant: String, landmark_layout := true) -> Node3D:
 var root := Node3D.new()
 root.name = variant.to_pascal_case()
 match variant:
  "flower_urn": flower_urn(root)
  "chimney_pots": chimney(root)
  "festival_pennant": pennant(root)
  "garden_bench": bench(root)
  "hedge_planter": planter(root)
  "cafe_awning": awning(root)
  "roof_pavilion": pavilion(root)
  "garden_arch":
   arch(root)
   for side: int in [-1, 1]:
    piece(root, "sphere", "leaf", Vector3(side * 0.51, 0.83, 0), Vector3(0.18, 0.22, 0.20))
  "cypress_terrace": cypress(root)
  "clock_tower":
   clock_tower(root)
   if landmark_layout:
    box(root, "stone", Vector3(0, 0.06, 0), Vector3(3.0, 0.12, 0.98))
    for side: int in [-1, 1]:
     box(root, "stone", Vector3(side * 0.95, 0.34, -0.12), Vector3(1.0, 0.44, 0.60))
     box(root, "cream", Vector3(side * 0.95, 0.59, -0.12), Vector3(1.04, 0.08, 0.64))
     railing(root, 0.94, Vector3(side * 0.95, 0.63, 0.12))
     var urn := Node3D.new()
     root.add_child(urn)
     urn.position = Vector3(side * 1.17, 0.12, 0.30)
     flower_urn(urn)
  "aqueduct": aqueduct(root, 3.0 if landmark_layout else 1.8)
  "festival_balloons":
   box(root, "cream", Vector3(0, 0.08, 0), Vector3(3.0, 0.16, 0.90))
   for i in 3:
    var at := Vector3((i - 1) * 0.95, 1.0 + (0.3 if i == 1 else 0.0), (i % 2) * -0.2)
    balloon(root, at, 0.31, i)
    bar(root, "dark", Vector3((i - 1) * 0.95, 0.16, 0), at + Vector3(0, -0.4, 0), 0.009)
 return root

func flower_urn(root: Node3D) -> void:
 piece(root, "pot", "roof", Vector3(0, 0.11, 0), Vector3(0.17, 0.22, 0.17))
 piece(root, "cylinder", "cream", Vector3(0, 0.21, 0), Vector3(0.14, 0.04, 0.14))
 piece(root, "sphere", "leaf", Vector3(0, 0.29, 0), Vector3(0.18, 0.10, 0.15))
 for i in 3:
  var angle := TAU * i / 3.0
  piece(root, "sphere", "flower", Vector3(cos(angle) * 0.10, 0.36, sin(angle) * 0.10), Vector3.ONE * 0.055)

func chimney(root: Node3D) -> void:
 box(root, "stone", Vector3(0, 0.13, 0), Vector3(0.34, 0.26, 0.23))
 box(root, "cream", Vector3(0, 0.27, 0), Vector3(0.39, 0.06, 0.28))
 for x: float in [-0.10, 0.10]:
  piece(root, "cylinder", "roof", Vector3(x, 0.36, 0), Vector3(0.055, 0.15, 0.055))
  piece(root, "cylinder", "dark", Vector3(x, 0.44, 0), Vector3(0.037, 0.012, 0.037))

func pennant(root: Node3D) -> void:
 box(root, "stone", Vector3(0, 0.04, 0), Vector3(0.2, 0.08, 0.2))
 bar(root, "dark", Vector3.ZERO, Vector3(0, 0.68, 0), 0.025)
 box(root, "red", Vector3(0.12, 0.51, 0), Vector3(0.23, 0.24, 0.018))
 box(root, "cream", Vector3(0.12, 0.41, 0), Vector3(0.23, 0.025, 0.021))

func bench(root: Node3D) -> void:
 for x: float in [-0.26, 0.26]:
  box(root, "dark", Vector3(x, 0.13, 0), Vector3(0.055, 0.26, 0.28))
  box(root, "dark", Vector3(x, 0.32, -0.13), Vector3(0.035, 0.38, 0.035))
 for z: float in [-0.09, 0, 0.09]:
  box(root, "wood", Vector3(0, 0.26, z), Vector3(0.70, 0.05, 0.07))
 for y: float in [0.39, 0.48]:
  box(root, "wood", Vector3(0, y, -0.14), Vector3(0.70, 0.065, 0.045))

func planter(root: Node3D) -> void:
 box(root, "stone", Vector3(0, 0.11, 0), Vector3(0.72, 0.22, 0.34))
 box(root, "cream", Vector3(0, 0.22, 0), Vector3(0.78, 0.055, 0.40))
 for i in 3:
  piece(root, "sphere", "leaf" if i % 2 == 0 else "leaf_light", Vector3((i - 1) * 0.22, 0.34, 0), Vector3(0.20, 0.18, 0.20))

func awning(root: Node3D) -> void:
 for x: float in [-0.34, 0.34]:
  bar(root, "dark", Vector3(x, 0, -0.15), Vector3(x, 0.67, -0.15), 0.03)
 for i in 6:
  var canopy := box(root, "red" if i % 2 == 0 else "cream", Vector3((i - 2.5) * 0.13, 0.62, 0), Vector3(0.13, 0.035, 0.51))
  canopy.rotation.x = 0.20
  box(root, "red" if i % 2 == 0 else "cream", Vector3((i - 2.5) * 0.13, 0.53, 0.25), Vector3(0.13, 0.12, 0.025))
 box(root, "wood", Vector3(0, 0.22, 0), Vector3(0.66, 0.055, 0.30))

func arch(root: Node3D, width := 1.12, height := 0.85, depth := 0.28) -> void:
 var radius := width * 0.5 - 0.12
 var spring := height - radius - 0.08
 for side: int in [-1, 1]:
  box(root, "stone", Vector3(side * (radius + 0.065), spring * 0.5, 0), Vector3(0.16, spring, depth))
  box(root, "cream", Vector3(side * (radius + 0.065), 0.05, 0), Vector3(0.23, 0.10, depth * 1.2))
 for i in 9:
  var angle := PI * (i + 0.5) / 9.0
  var block_length := maxf(0.18, 2.0 * (radius + 0.15) * tan(PI / 18.0))
  var block := box(root, "cream" if i == 4 else "stone", Vector3(cos(angle) * (radius + 0.06), spring + sin(angle) * (radius + 0.06), 0), Vector3(block_length, 0.18, depth))
  block.rotation.z = angle - PI * 0.5

func railing(root: Node3D, width: float, at: Vector3) -> void:
 box(root, "dark", at + Vector3.UP * 0.24, Vector3(width, 0.028, 0.025))
 for i in 7:
  box(root, "dark", at + Vector3((i / 6.0 - 0.5) * width, 0.12, 0), Vector3(0.025, 0.24, 0.025))

func pavilion(root: Node3D) -> void:
 box(root, "stone", Vector3(0, 0.07, 0), Vector3(1.05, 0.14, 0.8))
 for x: float in [-0.40, 0.40]:
  for z: float in [-0.27, 0.27]:
   box(root, "cream", Vector3(x, 0.48, z), Vector3(0.095, 0.70, 0.095))
 roof(root, Vector3(0, 0.84, 0), Vector3(1.10, 0.32, 0.88))
 railing(root, 0.8, Vector3(0, 0.14, 0.34))

func cypress(root: Node3D) -> void:
 planter(root)
 bar(root, "wood", Vector3(0, 0.2, 0), Vector3(0, 0.65, 0), 0.08)
 piece(root, "sphere", "leaf", Vector3(0, 0.83, 0), Vector3(0.23, 0.55, 0.23))
 piece(root, "cone", "leaf_light", Vector3(0, 1.20, 0), Vector3(0.18, 0.55, 0.18))

func clock_tower(root: Node3D) -> void:
 box(root, "stone", Vector3(0, 0.78, 0), Vector3(0.65, 1.56, 0.62))
 for y: float in [0.08, 0.87, 1.42, 1.77]:
  box(root, "cream", Vector3(0, y, 0), Vector3(0.76, 0.09, 0.72))
 box(root, "ochre", Vector3(0, 1.59, 0), Vector3(0.70, 0.32, 0.66))
 for side in 4:
  var face := Node3D.new()
  face.rotation.y = side * PI * 0.5
  root.add_child(face)
  var wall_depth := 0.31 if side % 2 == 0 else 0.325
  var clock_depth := 0.33 if side % 2 == 0 else 0.35
  box(face, "shutter", Vector3(0, 1.12, wall_depth + 0.018), Vector3(0.22, 0.33, 0.018))
  var clock := piece(face, "cylinder", "cream", Vector3(0, 1.60, clock_depth + 0.014), Vector3(0.135, 0.018, 0.135))
  clock.rotation.x = PI * 0.5
  bar(face, "dark", Vector3(0, 1.60, clock_depth + 0.035), Vector3(0, 1.70, clock_depth + 0.035), 0.017)
  bar(face, "dark", Vector3(0, 1.60, clock_depth + 0.036), Vector3(0.07, 1.64, clock_depth + 0.036), 0.017)
 roof(root, Vector3(0, 1.82, 0), Vector3(0.82, 0.32, 0.78))
 piece(root, "cone", "dark", Vector3(0, 2.24, 0), Vector3(0.10, 0.24, 0.10))

func aqueduct(root: Node3D, width := 1.8) -> void:
 for side: int in [-1, 1]:
  var span := Node3D.new()
  span.position.x = side * (width - 0.08) * 0.25
  root.add_child(span)
  arch(span, (width - 0.08) * 0.5, 0.92, 0.64 if width > 2.0 else 0.34)
 box(root, "cream", Vector3(0, 0.95, 0), Vector3(width, 0.12, 0.84 if width > 2.0 else 0.44))
 railing(root, width - 0.08, Vector3(0, 1.01, 0.36 if width > 2.0 else 0.17))

func balloon(root: Node3D, at: Vector3, radius: float, variant: int) -> void:
 # Eight colored gores form a faceted envelope; basket and ropes are visual only.
 for side in 8:
  var key := "balloon_%d_%d" % [variant % 3, side]
  if not meshes.has(key):
   var surface := SurfaceTool.new()
   surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   var profile := [Vector2(0.18, -1.0), Vector2(0.72, -0.45), Vector2(1.0, 0.25), Vector2(0.70, 0.88), Vector2(0.0, 1.14)]
   for row in 4:
    var vertices: Array[Vector3] = []
    for edge in 2:
     var angle := TAU * (side + edge) / 8.0
     for level in 2:
      var point: Vector2 = profile[row + level]
      vertices.append(Vector3(cos(angle) * point.x, point.y, sin(angle) * point.x))
    for index: int in [0, 1, 2, 2, 1, 3]: surface.add_vertex(vertices[index])
   surface.generate_normals()
   meshes[key] = surface.commit()
  var gore := MeshInstance3D.new()
  gore.mesh = meshes[key]
  gore.material_override = materials[["red", "blue", "shutter"][variant % 3] if side % 2 == 0 else "yellow"]
  gore.position = at
  gore.scale = Vector3.ONE * radius
  root.add_child(gore)
 box(root, "wood", at - Vector3.UP * radius * 1.6, Vector3(0.43, 0.30, 0.43) * radius)
 for x: float in [-0.15, 0.15]:
  bar(root, "dark", at + Vector3(x, -1.0, 0) * radius, at + Vector3(x, -1.5, 0) * radius, radius * 0.025)
