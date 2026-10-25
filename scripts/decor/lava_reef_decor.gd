extends "res://scripts/decor/decor_skin.gd"
## Original volcanic/mining silhouettes in authored cells. No gameplay nodes.
var meshes: Dictionary = {}
var materials: Dictionary = {}

func _init(_presentation: Node3D) -> void:
 skin_id = "lava_reef"
 var sizes := {
  "small": ["mineral_sprout", "basalt_vent", "survey_stake"],
  "medium": ["crystal_fan", "pressure_elbow", "keep_out_barrier", "buried_drill"],
  "large": ["column_cluster", "mine_hoist", "shrine_fragment"],
  "landmark": ["rift_crown", "mine_viaduct", "caldera_seal"],
 }
 for size: String in sizes:
  pools[size] = {}
  for hint: String in ["surface", "edge", "either"]: pools[size][hint] = sizes[size].duplicate()
 factory = build_variant
 var colors := {"basalt": "b77b40", "facet": "f3cf78", "deep": "45235f", "mineral": "438d78", "iron": "8277bb", "rust": "514173", "brass": "dfad43", "warning": "e6bc59", "ancient": "65a18b", "inset": "315565", "heat": "ea5424"}
 for key: String in colors:
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(colors[key])
  mat.roughness = 0.92
  if key in ["iron", "brass", "rust"]:
   mat.metallic = 0.45
   mat.roughness = 0.38
  if key == "heat":
   mat.emission_enabled = true
   mat.emission = Color(colors[key])
   mat.emission_energy_multiplier = 0.65
  materials[key] = mat
 var crystal := ShaderMaterial.new()
 crystal.shader = preload("res://scripts/themes/lava_crystal.gdshader")
 materials.crystal = crystal
 var molten := ShaderMaterial.new()
 molten.shader = preload("res://scripts/themes/lava_molten.gdshader")
 molten.set_shader_parameter("pattern_scale", Vector2(3, 3))
 molten.set_shader_parameter("radiance", 0.7)
 materials.molten = molten

func primitive(kind: String) -> Mesh:
 if meshes.has(kind): return meshes[kind]
 var result: Mesh
 if kind == "box": result = BoxMesh.new()
 elif kind == "gem": result = _gem_mesh()
 elif kind == "boulder": result = _boulder_mesh()
 else:
  var cylinder := CylinderMesh.new()
  cylinder.top_radius = 0.0 if kind == "cone" else (0.72 if kind == "rock" else 1.0)
  cylinder.bottom_radius = 1.0
  cylinder.height = 1.0
  cylinder.radial_segments = 8 if kind == "pipe" else 6
  cylinder.rings = 1
  result = cylinder
 meshes[kind] = result
 return result

func _boulder_mesh() -> ArrayMesh:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Beveled, irregular octagonal rock: broad facets, no smooth sphere normals.
 var levels := [-0.5,-0.28,0.22,0.5]
 var radii := [0.48,1.0,0.92,0.40]
 for ring in 3:
  for i in 8:
   var points: Array[Vector3] = []
   for corner: Vector2i in [Vector2i(i,ring),Vector2i(i,ring+1),Vector2i(i+1,ring+1),Vector2i(i+1,ring)]:
    var angle := TAU*corner.x/8.0
    var radius: float = radii[corner.y]*(0.92+0.08*sin(corner.x*2.7))
    points.append(Vector3(cos(angle)*radius,levels[corner.y],sin(angle)*radius))
   for indices: Array in [[0,2,1],[0,3,2]]:
    var normal := (points[indices[2]]-points[indices[0]]).cross(points[indices[1]]-points[indices[0]]).normalized()
    for index: int in indices:
     surface.set_normal(normal)
     surface.add_vertex(points[index])
 for sign_y: float in [-1.0,1.0]:
  for i in 8:
   var a := TAU*i/8.0
   var b := TAU*(i+1)/8.0
   var radius := 0.40 if sign_y > 0.0 else 0.48
   var triangle := [Vector3(0,sign_y*0.5,0),Vector3(cos(a)*radius,sign_y*0.5,sin(a)*radius),Vector3(cos(b)*radius,sign_y*0.5,sin(b)*radius)]
   if sign_y < 0.0: triangle.reverse()
   for vertex: Vector3 in triangle:
    surface.set_normal(Vector3.UP*sign_y)
    surface.add_vertex(vertex)
 return surface.commit()

func _gem_mesh() -> ArrayMesh:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 6:
  var a := TAU * i / 6.0
  var b := TAU * (i + 1) / 6.0
  var low_a := Vector3(cos(a), 0, sin(a))
  var low_b := Vector3(cos(b), 0, sin(b))
  var high_a := Vector3(cos(a) * 0.78, 0.69, sin(a) * 0.78)
  var high_b := Vector3(cos(b) * 0.78, 0.69, sin(b) * 0.78)
  for triangle: Array in [[low_a, high_a, low_b], [low_b, high_a, high_b], [high_a, Vector3(0.12,1.0,0.04), high_b]]:
   var normal: Vector3 = (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
   for vertex: Vector3 in triangle:
    surface.set_normal(normal)
    surface.add_vertex(vertex)
 return surface.commit()

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

func bar(root: Node3D, color: String, a: Vector3, b: Vector3, width: float, round_bar := false) -> void:
 var part := piece(root, "pipe" if round_bar else "box", color, (a + b) * 0.5, Vector3(width, a.distance_to(b), width))
 part.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func crystal(root: Node3D, at: Vector3, height: float, radius: float, lean := 0.0) -> void:
 var gem := piece(root, "gem", "crystal", at, Vector3(radius, height, radius * 0.8))
 gem.rotation.z = lean

func column(root: Node3D, at: Vector3, height: float, radius: float) -> void:
 for i in 4:
  var taper := 1.0-float(i)*0.16
  var stone := piece(root,"boulder","facet" if i%2 == 0 else "basalt",at+Vector3.UP*height*(0.125+i*0.24),Vector3(radius*taper,height*0.30,radius*taper))
  stone.rotation.y = i*0.85

func pipe(root: Node3D, a: Vector3, b: Vector3, radius: float) -> void:
 bar(root, "iron", a, b, radius, true)
 var direction := (b - a).normalized()
 for t: float in [0.12, 0.88]:
  var at := a.lerp(b, t)
  bar(root, "rust", at - direction * radius * 0.45, at + direction * radius * 0.45, radius * 1.38, true)
  bar(root, "brass", at - direction * radius * 0.23, at + direction * radius * 0.23, radius * 1.42, true)

func warning_panel(root: Node3D, at: Vector3, width: float, height: float) -> void:
 box(root, "warning", at, Vector3(width, height, 0.035))
 for i in 5:
  var stripe := box(root, "deep", at + Vector3((i - 2) * width * 0.18, 0, 0.021), Vector3(width * 0.07, height * 0.82, 0.008))
  stripe.rotation.z = -0.3

func hoist(root: Node3D, at: Vector3, width: float, height: float) -> void:
 for side: int in [-1, 1]:
  var foot := at + Vector3(side * width * 0.40, 0, 0)
  box(root, "basalt", foot + Vector3(0, 0.06, 0), Vector3(width * 0.28, 0.12, width * 0.45))
  bar(root, "rust", foot, at + Vector3(side * width * 0.29, height, 0), width * 0.065)
 box(root, "iron", at + Vector3.UP * height, Vector3(width, height * 0.09, width * 0.24))
 bar(root, "iron", at + Vector3(-width * 0.32, height * 0.5, 0), at + Vector3(width * 0.32, height * 0.88, 0), width * 0.04)
 var winch := piece(root, "pipe", "brass", at + Vector3(0, height * 0.90, 0.06), Vector3(width * 0.10, width * 0.22, width * 0.10))
 winch.rotation.x = PI * 0.5
 bar(root, "deep", at + Vector3(0, height * 0.87, 0.14), at + Vector3(0, height * 0.35, 0.14), width * 0.018)
 box(root, "iron", at + Vector3(0, height * 0.3, 0.14), Vector3(width * 0.24, height * 0.12, width * 0.20))

func build_variant(variant: String) -> Node3D:
 var root := Node3D.new()
 root.name = variant.to_pascal_case()
 match variant:
  "mineral_sprout":
   piece(root, "rock", "basalt", Vector3(0, 0.035, 0), Vector3(0.19, 0.07, 0.15))
   for i in 3: crystal(root, Vector3((i - 1) * 0.09, 0.06, 0), 0.24 + (i % 2) * 0.14, 0.055, (1 - i) * 0.22)
  "basalt_vent":
   for i in 5:
    var angle := TAU * i / 5.0
    column(root, Vector3(cos(angle) * 0.10, 0, sin(angle) * 0.1), 0.12 + (i % 2) * 0.07, 0.075)
   piece(root, "pipe", "heat", Vector3(0, 0.05, 0), Vector3(0.07, 0.03, 0.07))
  "survey_stake":
   box(root, "rust", Vector3(0, 0.20, 0), Vector3(0.04, 0.40, 0.04))
   warning_panel(root, Vector3(0, 0.31, 0.025), 0.24, 0.12)
   piece(root, "rock", "basalt", Vector3(0.02, 0.035, 0), Vector3(0.12,0.07,0.10))
  "crystal_fan":
   piece(root, "rock", "mineral", Vector3(0,0.05,0), Vector3(0.31,0.1,0.22))
   for i in 5: crystal(root, Vector3((i-2)*0.09, 0.08, abs(i-2)*0.015), 0.63-abs(i-2)*0.12, 0.07, (2-i)*0.21)
  "pressure_elbow":
   pipe(root, Vector3(-0.27,0.10,0), Vector3(0.10,0.10,0), 0.09)
   pipe(root, Vector3(0.10,0.10,0), Vector3(0.10,0.49,0), 0.09)
   piece(root,"pipe","brass",Vector3(0.10,0.51,0),Vector3(0.13,0.04,0.13))
   box(root,"deep",Vector3(0.1,0.54,0),Vector3(0.12,0.01,0.12))
   column(root,Vector3(-0.23,0,-0.10),0.19,0.15)
  "keep_out_barrier":
   for side: int in [-1,1]:
    box(root,"rust",Vector3(side*0.29,0.22,0),Vector3(0.06,0.44,0.09))
    box(root,"iron",Vector3(side*0.29,0.03,0),Vector3(0.15,0.06,0.23))
   warning_panel(root,Vector3(0,0.33,0),0.66,0.17)
   bar(root,"iron",Vector3(-0.29,0.12,0),Vector3(0.29,0.12,0),0.025)
   # Original stencil, deliberately secondary to the readable striped silhouette.
   var sign := Label3D.new()
   sign.text = "KEEP OUT"
   sign.font_size = 32
   sign.pixel_size = 0.0018
   sign.position = Vector3(0,0.33,0.03)
   sign.modulate = Color("f8e8bb")
   sign.outline_size = 6
   sign.no_depth_test = false
   root.add_child(sign)
  "buried_drill":
   var machine := Node3D.new()
   root.add_child(machine)
   machine.position = Vector3(0.07,0.19,0)
   machine.rotation.z = -0.68
   piece(machine,"pipe","iron",Vector3(0,0.12,0),Vector3(0.13,0.25,0.13))
   piece(machine,"cone","brass",Vector3(0,-0.09,0),Vector3(0.16,0.22,0.16)).rotation.z = PI
   for i in 3: piece(machine,"pipe","rust",Vector3(0,0.03+i*0.07,0),Vector3(0.145,0.025,0.145))
   for i in 3: column(root,Vector3((i-1)*0.18,0,0.02),0.13+(i%2)*0.05,0.11)
  "column_cluster":
   for i in 5:
    column(root,Vector3((i-2)*0.17,0,sin(i*2.5)*0.13),1.15-abs(i-2)*0.21,0.15)
   crystal(root,Vector3(0.32,0.05,0.22),0.52,0.10,-0.27)
  "mine_hoist": hoist(root,Vector3.ZERO,0.90,1.18)
  "shrine_fragment":
   box(root,"basalt",Vector3(0,0.06,0),Vector3(0.94,0.12,0.60))
   for side: int in [-1,1]:
    piece(root,"rock","ancient",Vector3(side*0.31,0.43,0),Vector3(0.13,0.68,0.14))
    box(root,"inset",Vector3(side*0.31,0.75,0),Vector3(0.29,0.08,0.29))
   var lintel := box(root,"ancient",Vector3(-0.08,0.84,0),Vector3(0.75,0.13,0.32))
   lintel.rotation.z = 0.09
   crystal(root,Vector3(0.14,0.12,0.12),0.67,0.14,-0.18)
  "rift_crown":
   box(root,"basalt",Vector3(0,0.09,0),Vector3(3.0,0.18,1.0))
   for i in 9:
    column(root,Vector3((i-4)*0.31,0.18,0),1.75-abs(i-4)*0.30,0.17)
   for i in 5: crystal(root,Vector3((i-2)*0.27,0.21,0.28),1.62-abs(i-2)*0.45,0.11,(2-i)*0.12)
   pipe(root,Vector3(-1.35,0.31,-0.28),Vector3(1.35,0.31,-0.28),0.07)
  "mine_viaduct":
   box(root,"basalt",Vector3(0,0.07,0),Vector3(3.0,0.14,1.0))
   for side: int in [-1,1]:
    column(root,Vector3(side*1.12,0.14,0),0.71,0.31)
    box(root,"rust",Vector3(side*1.12,0.95,0),Vector3(0.16,0.45,0.50))
   box(root,"iron",Vector3(0,0.86,0),Vector3(2.8,0.16,0.55))
   for z: float in [-0.28,0.28]:
    pipe(root,Vector3(-1.28,1.22,z),Vector3(1.28,1.22,z),0.035)
    for i in 7:
     bar(root,"rust",Vector3((i-3)*0.4,0.95,z),Vector3((i-3)*0.4,1.22,z),0.025)
   crystal(root,Vector3(-0.7,0.15,0.25),0.40,0.09)
  "caldera_seal":
   piece(root,"pipe","basalt",Vector3(0,0.08,0),Vector3(0.80,0.16,0.80))
   piece(root,"pipe","molten",Vector3(0,0.17,0),Vector3(0.63,0.015,0.63))
   piece(root,"rock","ancient",Vector3(0,0.25,0),Vector3(0.28,0.18,0.28))
   crystal(root,Vector3(0,0.34,0),0.65,0.18)
   for i in 6:
    var angle := TAU * i / 6.0
    var marker := box(root,"ancient",Vector3(cos(angle)*0.66,0.27,sin(angle)*0.66),Vector3(0.17,0.22,0.17))
    marker.rotation.y = -angle
 return root
