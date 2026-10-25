extends "res://scripts/decor/decor_skin.gd"
## Lightweight, collisionless props in cell units. Reuses the presentation's
## existing palm and sunflower silhouettes; all assets are constructed locally.
var presentation: Node3D

func _init(owner_presentation: Node3D) -> void:
 presentation = owner_presentation
 skin_id = "green_hill"
 pools = {
  "small": {"surface": ["flower", "small_rock", "grass_tuft"], "edge": ["flower", "small_rock", "grass_tuft"], "either": ["flower", "small_rock", "grass_tuft"]},
  "medium": {"surface": ["shrub", "medium_rock", "flower_patch"], "edge": ["medium_rock", "shrub"], "either": ["medium_rock", "shrub", "flower_patch"]},
  "large": {"surface": ["tall_rock", "checker_pedestal"], "edge": ["palm", "palm_left"], "either": ["palm", "tall_rock", "checker_pedestal"]},
  "landmark": {"surface": ["turf_loop", "rope_bridge", "palm_island"], "edge": ["turf_loop", "rope_bridge", "palm_island"], "either": ["turf_loop", "rope_bridge", "palm_island"]},
 }
 factory = _build_prop

func _build_prop(variant: String) -> Node3D:
 var root := Node3D.new()
 root.name = variant.to_pascal_case()
 match variant:
  "flower": presentation._flower(Vector3.ZERO, 0.72, root)
  "small_rock": _rock(root, Vector3.ZERO, Vector3(0.23, 0.18, 0.20))
  "grass_tuft": _grass_tuft(root)
  "medium_rock":
   _rock(root, Vector3.ZERO, Vector3(0.48, 0.46, 0.38))
   _rock(root, Vector3(0.20, 0, 0.12), Vector3(0.22, 0.23, 0.20))
  "tall_rock":
   _rock(root, Vector3(-0.12, 0, 0.04), Vector3(0.48, 1.12, 0.45))
   _rock(root, Vector3(0.23, 0, 0.10), Vector3(0.36, 0.68, 0.40))
  "shrub":
   for i in 3:
    var mesh := SphereMesh.new()
    mesh.radius = 0.22
    mesh.height = 0.36
    mesh.radial_segments = 7
    mesh.rings = 3
    var offset := Vector3((i - 1) * 0.18, 0.15 + (0.07 if i == 1 else 0.0), 0.08 if i == 1 else 0.0)
    presentation.mesh_node(mesh, presentation.material(Color("52ae36") if i == 1 else Color("287e38")), offset, root)
  "flower_patch":
   presentation._flower(Vector3(-0.16, 0, 0.04), 0.72, root)
   presentation._flower(Vector3(0.17, 0, -0.04), 0.54, root)
   presentation._flower(Vector3(0.02, 0, 0.15), 0.45, root)
  "palm", "palm_left": presentation._palm(Vector3.ZERO, -1 if variant == "palm_left" else 1, 0.82, root)
  "checker_pedestal":
   _checker_box(root, Vector3(0, 0.25, 0), Vector3(0.68, 0.5, 0.68))
   _grass_box(root, Vector3(0, 0.53, 0), Vector3(0.73, 0.08, 0.73))
   presentation._flower(Vector3(0, 0.57, 0), 0.63, root)
  "turf_loop": _turf_loop(root)
  "rope_bridge": _rope_bridge(root)
  "palm_island":
   # Explicit side UVs keep checker squares readable around the shallow island.
   var soil := SurfaceTool.new()
   soil.begin(Mesh.PRIMITIVE_TRIANGLES)
   for i in 16:
    var a := Vector3(cos(TAU * i / 16.0), 0, sin(TAU * i / 16.0)) * 0.80
    var b := Vector3(cos(TAU * (i + 1) / 16.0), 0, sin(TAU * (i + 1) / 16.0)) * 0.80
    var up := Vector3.UP * 0.28
    var vertices := [a, b, b + up, a, b + up, a + up]
    var uvs := [Vector2(i * 0.32, 0), Vector2((i + 1) * 0.32, 0), Vector2((i + 1) * 0.32, 0.32), Vector2(i * 0.32, 0), Vector2((i + 1) * 0.32, 0.32), Vector2(i * 0.32, 0.32)]
    for vertex in 6:
     soil.set_uv(uvs[vertex])
     soil.add_vertex(vertices[vertex])
   soil.generate_normals()
   presentation.mesh_node(soil.commit(), presentation._cliff, Vector3.ZERO, root)
   var turf: CylinderMesh = presentation.cylinder(0.82, 0.06)
   turf.radial_segments = 16
   presentation.mesh_node(turf, presentation.terrain_top_material(), Vector3(0, 0.31, 0), root)
   presentation._palm(Vector3(-0.16, 0.34, 0.05), 1, 0.50, root)
   presentation._flower(Vector3(0.42, 0.34, 0.30), 0.48, root)
 return root

func _grass_tuft(root: Node3D) -> void:
 for i in 7:
  var angle := TAU * float(i) / 7.0
  var direction := Vector3(cos(angle), 0, sin(angle))
  var across := Vector3(-sin(angle), 0, cos(angle)) * 0.045
  var base := direction * 0.035
  var middle := direction * 0.10 + Vector3.UP * 0.19
  var tip := direction * 0.23 + Vector3.UP * (0.31 + (i % 3) * 0.045)
  var surface := SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for vertex: Vector3 in [base, middle + across, middle + Vector3.UP * 0.035, base, middle + Vector3.UP * 0.035, middle - across, middle - across, middle + Vector3.UP * 0.035, tip, middle + Vector3.UP * 0.035, middle + across, tip]:
   surface.add_vertex(vertex)
  surface.generate_normals()
  var leaf: Material = presentation.material(Color("286c39") if i % 2 == 0 else Color("69ae35"))
  leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
  presentation.mesh_node(surface.commit(), leaf, Vector3.ZERO, root)

func _turf_loop(root: Node3D) -> void:
 # A continuous inner running surface through a broad checker cliff, with
 # separate approach/exit lanes in depth. The landmark remains collisionless.
 var soil := SurfaceTool.new()
 var turf := SurfaceTool.new()
 soil.begin(Mesh.PRIMITIVE_TRIANGLES)
 turf.begin(Mesh.PRIMITIVE_TRIANGLES)
 var inner := PackedVector3Array()
 var outer := PackedVector3Array()
 var normals := PackedVector3Array()
 var steps := 64
 for i in steps + 1:
  var t := float(i) / steps
  var angle := -PI * 0.5 + TAU * t
  var radial := Vector3(cos(angle), sin(angle), 0)
  var center := Vector3(0, 1.0, lerpf(0.29, -0.29, smoothstep(0, 1, t)))
  # A rounded rectangular exterior, not a circular torus silhouette.
  var radius := pow(pow(absf(radial.x) / 1.07, 6) + pow(absf(radial.y), 6), -1.0 / 6.0)
  inner.append(center + radial * 0.84)
  outer.append(center + radial * radius)
  normals.append(radial)
 var across := Vector3(0, 0, 0.23)
 for i in steps:
  var a := inner[i]
  var b := inner[i + 1]
  var c := outer[i + 1]
  var d := outer[i]
  # Grass is on the inside of the loop, with a small visible lip on each face.
  _quad(turf, a - across, b - across, b + across, a + across)
  for side: int in [-1, 1]:
   var offset := across * side
   var lip_a := a + normals[i] * 0.035
   var lip_b := b + normals[i + 1] * 0.035
   if side > 0:
    _quad(soil, lip_a + offset, lip_b + offset, c + offset, d + offset)
    _quad(turf, a + offset, b + offset, lip_b + offset, lip_a + offset)
   else:
    _quad(soil, d + offset, c + offset, lip_b + offset, lip_a + offset)
    _quad(turf, lip_a + offset, lip_b + offset, b + offset, a + offset)
  var top: SurfaceTool = turf if normals[i].y > 0.72 and normals[i + 1].y > 0.72 else soil
  _quad(top, d + across, c + across, c - across, d - across)
 # Tangent entry and exit aprons are attached to the two ends of the spiral.
 for end: int in [0, steps]:
  var at := inner[end]
  var tip := at + Vector3(-1.52 if end == 0 else 1.52, 0, 0)
  var down := Vector3(0, -0.16, 0)
  _quad(turf, at + across, tip + across, tip - across, at - across, end > 0)
  _quad(soil, at + across + down, tip + across + down, tip + across, at + across, end > 0)
  _quad(soil, at - across, tip - across, tip - across + down, at - across + down, end > 0)
  _quad(soil, tip + across, tip + across + down, tip - across + down, tip - across, end > 0)
  _quad(soil, at - across + down, tip - across + down, tip + across + down, at + across + down, end > 0)
 presentation.mesh_node(soil.commit(), presentation._cliff, Vector3.ZERO, root).name = "CheckerCliff"
 presentation.mesh_node(turf.commit(), presentation.terrain_top_material(), Vector3.ZERO, root).name = "ContinuousTurfTrack"

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, reverse := false) -> void:
 var normal := (d - a).cross(b - a).normalized() * (-1.0 if reverse else 1.0)
 # Clockwise front faces; UVs keep checker squares consistent across the cliff.
 for point: Vector3 in ([a, c, b, a, d, c] if reverse else [a, b, c, a, c, d]):
  surface.set_normal(normal)
  var uv := Vector2(point.x, point.y)
  if absf(normal.x) > absf(normal.z) and absf(normal.x) > absf(normal.y):
   uv = Vector2(point.z, point.y)
  elif absf(normal.y) > absf(normal.z):
   uv = Vector2(point.x, point.z)
  surface.set_uv(uv * 0.60)
  surface.add_vertex(point)

func _rope_bridge(root: Node3D) -> void:
 var wood: Material = presentation.material(Color("9d542b"))
 var light_wood: Material = presentation.material(Color("bd7839"))
 var rope: Material = presentation.material(Color("dec078"))
 var post_material: Material = presentation.material(Color("68422a"))
 for side: int in [-1, 1]:
  _checker_box(root, Vector3(side * 1.12, 0.31, 0), Vector3(0.65, 0.62, 0.84))
  _grass_box(root, Vector3(side * 1.12, 0.65, 0), Vector3(0.71, 0.08, 0.90))
  for z: float in [-0.34, 0.34]:
   _beam(root, Vector3(side * 0.91, 0.59, z), Vector3(side * 0.91, 1.15, z), 0.048, post_material)
   _beam(root, Vector3(side * 0.91, 1.03, z), Vector3(side * 0.91, 1.085, z), 0.058, rope)
 # Individual crosswise planks follow a shallow sag. Short ropes join each post
 # to the deck; all details use the same two curves so attachments stay aligned.
 for i in 13:
  var x := lerpf(-0.87, 0.87, float(i) / 12.0)
  var plank := BoxMesh.new()
  plank.size = Vector3(0.137, 0.065, 0.64)
  var board: MeshInstance3D = presentation.mesh_node(plank, light_wood if i % 3 == 0 else wood, Vector3(x, _bridge_height(x), 0), root)
  board.rotation.z = atan(0.38 * x / (0.91 * 0.91))
 for side: int in [-1, 1]:
  var z := side * 0.34
  for i in 12:
   var x0 := lerpf(-0.91, 0.91, float(i) / 12.0)
   var x1 := lerpf(-0.91, 0.91, float(i + 1) / 12.0)
   for lift: float in [-0.045, 0.39]:
    _beam(root, Vector3(x0, _bridge_height(x0) + lift, z), Vector3(x1, _bridge_height(x1) + lift, z), 0.016, rope)
   if i % 3 == 0 and i > 0:
    _beam(root, Vector3(x0, _bridge_height(x0), z), Vector3(x0, _bridge_height(x0) + 0.39, z), 0.012, rope)

func _bridge_height(x: float) -> float:
 return 0.49 + 0.19 * pow(x / 0.91, 2)

func _beam(root: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
 var mesh := CylinderMesh.new()
 mesh.top_radius = radius
 mesh.bottom_radius = radius
 mesh.height = a.distance_to(b)
 mesh.radial_segments = 6
 mesh.rings = 1
 var beam: MeshInstance3D = presentation.mesh_node(mesh, material, (a + b) * 0.5, root)
 beam.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _rock(root: Node3D, base: Vector3, size: Vector3) -> void:
 var mesh := CylinderMesh.new()
 mesh.bottom_radius = 0.5
 mesh.top_radius = 0.29
 mesh.height = 1.0
 mesh.radial_segments = 5
 mesh.rings = 1
 var rock: MeshInstance3D = presentation.mesh_node(mesh, presentation.material(Color("b9b497")), base + Vector3.UP * size.y * 0.5, root)
 rock.scale = size
 rock.rotation.y = 0.35

func _checker_box(root: Node3D, at: Vector3, size: Vector3) -> MeshInstance3D:
 var box := BoxMesh.new()
 box.size = size
 return presentation.mesh_node(box, presentation._cliff, at, root)

func _grass_box(root: Node3D, at: Vector3, size: Vector3) -> MeshInstance3D:
 var box := BoxMesh.new()
 box.size = size
 return presentation.mesh_node(box, presentation.terrain_top_material(), at, root)
