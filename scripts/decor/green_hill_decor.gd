extends "res://scripts/decor/decor_skin.gd"
## Lightweight, collisionless props in cell units. Reuses the presentation's
## existing palm and sunflower silhouettes; all assets are constructed locally.
var presentation: Node3D
static var _rock_geometry: ArrayMesh
var _loop_soil: ShaderMaterial
var _loop_turf: ShaderMaterial
const IslandFlicky = preload("res://scripts/decor/island_flicky.gd")

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
    var shrub: Material = presentation.material(Color("52ae36") if i == 1 else Color("287e38"))
    preload("res://scripts/themes/theme_atmosphere.gd").foliage(shrub)
    presentation.mesh_node(mesh, shrub, offset, root)
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
   var perches := [Vector3(-.42, .34, .31), Vector3(.02, .34, .48), Vector3(.35, .34, -.23)]
   for i in perches.size():
    var flicky := IslandFlicky.new(presentation, i)
    flicky.position = perches[i]
    flicky.rotation.y = [-.35, .3, .55][i]
    root.add_child(flicky)
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
  preload("res://scripts/themes/theme_atmosphere.gd").foliage(leaf)
  leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
  presentation.mesh_node(surface.commit(), leaf, Vector3.ZERO, root)

func build_coastal_loop() -> Node3D:
 var root := Node3D.new()
 root.name = "CoastalTurfLoop"
 _turf_loop(root, 1.12)
 return root

func _turf_loop(root: Node3D, apron_reach := 1.52) -> void:
 # A continuous inner running surface through a broad checker cliff, with
 # separate approach/exit lanes in depth. The landmark remains collisionless.
 var soil := SurfaceTool.new()
 var turf := SurfaceTool.new()
 soil.begin(Mesh.PRIMITIVE_TRIANGLES)
 turf.begin(Mesh.PRIMITIVE_TRIANGLES)
 var inner := PackedVector3Array()
 var outer := PackedVector3Array()
 var distances := PackedFloat32Array([0.0])
 var steps := 16
 for i in steps + 1:
  var t := float(i) / steps
  var angle := -PI * 0.5 + TAU * t
  var radial := Vector3(cos(angle), sin(angle), 0)
  var center := Vector3(0, 1.0, lerpf(0.29, -0.29, smoothstep(0, 1, t)))
  # A rounded rectangular exterior, not a circular torus silhouette.
  var radius := pow(pow(absf(radial.x) / 1.07, 6) + pow(absf(radial.y), 6), -1.0 / 6.0)
  inner.append(center + radial * 0.84)
  outer.append(center + radial * radius)
  if i > 0: distances.append(distances[-1] + inner[i - 1].distance_to(inner[i]))
 var across := Vector3(0, 0, 0.23)
 for i in steps:
  var a := inner[i]
  var b := inner[i + 1]
  var c := outer[i + 1]
  var d := outer[i]
  # Unwrap along the running surface, including its upright sections. Keep the
  # checker face flush to the inside edge instead of adding a bright green rim.
  _quad(turf, a - across, b - across, b + across, a + across, false,
   PackedVector2Array([Vector2(distances[i], 0), Vector2(distances[i + 1], 0), Vector2(distances[i + 1], across.z * 2), Vector2(distances[i], across.z * 2)]))
  for side: int in [-1, 1]:
   var offset := across * side
   if side > 0:
    _quad(soil, a + offset, b + offset, c + offset, d + offset)
   else:
    _quad(soil, d + offset, c + offset, b + offset, a + offset)
  # Classify the actual superellipse face, not its circular sample direction.
  # Coarse upper chords can be almost horizontal even at a 45-degree radial
  # sample; the vertical cliff projection is undefined on those faces.
  var exterior_normal := Vector3(0, 0, -1).cross(c - d).normalized()
  var top: SurfaceTool = turf if exterior_normal.y > 0.72 else soil
  _quad(top, d + across, c + across, c - across, d - across)
 # Tangent entry and exit aprons are attached to the two ends of the spiral.
 for end: int in [0, steps]:
  var at := inner[end]
  var reach: float = -apron_reach if end == 0 else apron_reach
  var tip := at + Vector3(reach, 0, 0)
  var down := Vector3(0, -0.16, 0)
  _quad(turf, at + across, tip + across, tip - across, at - across, end > 0,
   PackedVector2Array([Vector2(distances[end], across.z * 2), Vector2(distances[end] + reach, across.z * 2), Vector2(distances[end] + reach, 0), Vector2(distances[end], 0)]))
  _quad(soil, at + across + down, tip + across + down, tip + across, at + across, end > 0)
  _quad(soil, at - across, tip - across, tip - across + down, at - across + down, end > 0)
  _quad(soil, tip + across, tip + across + down, tip - across + down, tip - across, end > 0)
  _quad(soil, at - across + down, tip - across + down, tip + across + down, at + across + down, end > 0)
 if _loop_soil == null:
  _loop_soil = presentation.theme_definition._texture_material("3A", Vector2(0.64, 0.64), false)
  # Production bakes use flat turf. The existing UV surface shader preserves
  # that material policy while unwrapping the curved prop in source and bakes.
  _loop_turf = _loop_soil.duplicate()
  _loop_turf.set_shader_parameter("surface_texture", presentation.theme_definition._selected_texture("5B"))
  _loop_turf.set_shader_parameter("repeat_size", Vector2(2, 2))
 presentation.mesh_node(soil.commit(), _loop_soil, Vector3.ZERO, root).name = "CheckerCliff"
 presentation.mesh_node(turf.commit(), _loop_turf, Vector3.ZERO, root).name = "ContinuousTurfTrack"

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, reverse := false, coordinates := PackedVector2Array()) -> void:
 var normal := (d - a).cross(b - a).normalized() * (-1.0 if reverse else 1.0)
 # Clockwise front faces; UVs keep checker squares consistent across the cliff.
 var points := [a, b, c, d]
 var indices := [0, 2, 1, 0, 3, 2] if reverse else [0, 1, 2, 0, 2, 3]
 var vertices: Array[Vector3] = []
 for index: int in indices: vertices.append(points[index])
 for triangle in [0, 3]:
  # The loop twists in depth. A coarse quad is not planar: each triangle needs
  # its own geometric normal for lighting and the existing shadow normal bias.
  var face_normal: Vector3 = (vertices[triangle + 2] - vertices[triangle]).cross(vertices[triangle + 1] - vertices[triangle]).normalized()
  for corner in 3:
   var point: Vector3 = vertices[triangle + corner]
   surface.set_normal(face_normal)
   var uv := Vector2(point.x, point.y)
   if absf(normal.x) > absf(normal.z) and absf(normal.x) > absf(normal.y):
    uv = Vector2(point.z, point.y)
   elif absf(normal.y) > absf(normal.z):
    uv = Vector2(point.x, point.z)
   surface.set_uv(coordinates[indices[triangle + corner]] if coordinates.size() == 4 else uv)
   surface.add_vertex(point)

func _rope_bridge(root: Node3D) -> void:
 var colors := preload("res://scripts/themes/green_hill_palette.gd").wood(presentation.theme_definition)
 var wood: Material = presentation.material(colors[0])
 var light_wood: Material = presentation.material(colors[1])
 var rope: Material = presentation.material(colors[1])
 var post_material: Material = presentation.material(colors[0])
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
 if _rock_geometry == null:
  # Three irregular rings give the existing rocks broad shoulders and chipped
  # crowns. Thirty-six triangles, flat normals, and the original unit envelope.
  var surface := SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  surface.set_smooth_group(-1)
  var rings: Array[PackedVector3Array] = []
  for row in 3:
   var ring := PackedVector3Array()
   for i in 6:
    var angle := TAU * i / 6.0
    var radius: float = [0.43, 0.50, 0.29][row] * (0.88 if i % 3 == 1 else 1.0)
    var height: float = [-0.5, 0.18, 0.46][row] + (0.04 * sin(i * 2.0) if row > 0 else 0.0)
    ring.append(Vector3(cos(angle) * radius + (0.06 if row == 2 else 0.0), height, sin(angle) * radius))
   rings.append(ring)
  for i in 6:
   var next := (i + 1) % 6
   for row in 2:
    for point: Vector3 in [rings[row][i], rings[row][next], rings[row + 1][i], rings[row][next], rings[row + 1][next], rings[row + 1][i]]:
     surface.add_vertex(point)
   for point: Vector3 in [rings[2][i], rings[2][next], Vector3(0.06, 0.5, 0), rings[0][next], rings[0][i], Vector3(0, -0.5, 0)]:
    surface.add_vertex(point)
  surface.generate_normals()
  _rock_geometry = surface.commit()
 var rock: MeshInstance3D = presentation.mesh_node(_rock_geometry, presentation.material(Color("b9b497")), base + Vector3.UP * size.y * 0.5, root)
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
