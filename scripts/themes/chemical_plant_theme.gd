extends "res://scripts/themes/theme_definition.gd"
## Original low-poly industrial art. Only presentation nodes and materials live here.
const ChemicalDecor = preload("res://scripts/decor/chemical_plant_decor.gd")
const FLOOR = preload("res://scripts/themes/chemical_floor.gdshader")
const WALL = preload("res://scripts/themes/chemical_wall.gdshader")
const LIQUID = preload("res://scripts/themes/chemical_reservoir.gdshader")
var _steel: StandardMaterial3D
var _dark: StandardMaterial3D
var _blue: StandardMaterial3D
var _cyan: StandardMaterial3D
var _signal: StandardMaterial3D
var _yellow: StandardMaterial3D

func _init() -> void:
 theme_id = "chemical_plant"
 display_name = "Chemical Plant"
 floor_material = _shader(FLOOR)
 top_material = _shader(FLOOR)
 top_material.set_shader_parameter("raised_surface", true)
 side_material = _shader(WALL)
 cliff_material = _shader(WALL)
 cliff_material.set_shader_parameter("top_height", 0.0)
 _steel = _surface(Color("647487"))
 _dark = _surface(Color("1c233b"))
 _blue = _surface(Color("224f9c"))
 _cyan = _surface(Color("4de4dc"), 0.5)
 _signal = _surface(Color("f64e91"), 0.6)
 _yellow = _surface(Color("e5b243"))

func _shader(source: Shader) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = source
 return result

func _surface(color: Color, glow := 0.0) -> StandardMaterial3D:
 var result := StandardMaterial3D.new()
 result.albedo_color = color
 result.roughness = 0.78
 if glow > 0.0:
  result.emission_enabled = true
  result.emission = color
  result.emission_energy_multiplier = glow
 return result

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
 # Preserve familiar gameplay colors under cool illumination. Terrain and props
 # own their own materials; this palette only styles the shared object meshes.
 var palette := {"b34039": Color("d44e70"), "ff8962": Color("ffe4ac"),
  "307ac3": Color("efb438"), "b0e6ff": Color("fff5cc"),
  "ffd568": Color("ffe15c"), "4f97ff": Color("418fff"),
  "549c24": Color("598394")}
 return _surface(palette.get(color.to_html(false), color), glow)

func configure_environment(p: Node3D) -> void:
 var world: Environment = p._world_environment.environment
 var sky_material := ProceduralSkyMaterial.new()
 sky_material.sky_top_color = Color("090d27")
 sky_material.sky_horizon_color = Color("692841")
 sky_material.ground_bottom_color = Color("080e25")
 sky_material.ground_horizon_color = Color("52223f")
 sky_material.sky_curve = 0.28
 sky_material.sun_angle_max = 0.1
 var sky := Sky.new()
 sky.sky_material = sky_material
 world.background_mode = Environment.BG_SKY
 world.sky = sky
 world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.ambient_light_color = Color("b4c5ee")
 world.ambient_light_energy = 0.52
 world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 # Emissive shapes remain visible in Compatibility, without requiring bloom.
 world.glow_enabled = false
 var light: DirectionalLight3D = p._key_light
 light.rotation_degrees = Vector3(-58, -32, 0)
 light.light_color = Color("d9e9ff")
 light.light_energy = 0.90
 light.shadow_normal_bias = 2.0

func create_decor(p: Node3D) -> RefCounted:
 return ChemicalDecor.new(p)

func build_background(p: Node3D) -> void:
 var root: Node3D = p.scenery_root
 var center: Vector3 = p.map_point(p.table_bounds.get_center())
 var water := PlaneMesh.new()
 water.size = Vector2(180, 180)
 p.mesh_node(water, _shader(LIQUID), center + Vector3(0, -2.45, 0), root)
 var width: float = p.table_bounds.size.x * p.SCALE
 var length: float = p.table_bounds.size.y * p.SCALE
 # Towers sit beyond the table's lateral silhouette, with a lower reservoir gap.
 # Layers use deterministic dimensions and never consume the gameplay RNG.
 for side: int in [-1, 1]:
  for i in 5:
   var base := center + Vector3(side * (width * 0.5 + 4.7 + float(i % 2) * 1.6), -2.0, -length * 0.55 + i * maxf(2.6, length * 0.27))
   _silo(p, root, base, 1.1 + float(i % 2) * 0.2, 3.4 + float(i % 3) * 0.65, i)
   if i < 4:
    var finish := base + Vector3(0, 0, maxf(2.6, length * 0.27))
    _pipe(p, root, base + Vector3(0, 0.8, 0), finish + Vector3(0, 0.8, 0), 0.19, _blue)
 # Far processing district: broad silhouettes, sparse strips, no noisy windows.
 for i in 9:
  var height := 3.5 + float((i * 7) % 5) * 0.65
  var at := Vector3(center.x + (i - 4) * 3.0, -2.0, p.table_bounds.position.y * p.SCALE - 10.0 - (i % 2) * 3.0)
  _box(p, root, at + Vector3(0, height * 0.5, 0), Vector3(1.6, height, 1.7), _dark)
  for row in 3:
   _box(p, root, at + Vector3(0, 0.7 + row * 0.8, 0.865), Vector3(1.35, 0.04, 0.025), _signal if i % 3 == 0 else _cyan)
  var stack := at + Vector3(0.3, height, 0)
  _pipe(p, root, stack, stack + Vector3(0, 1.3, 0), 0.20, _steel)
  _box(p, root, stack + Vector3(0, 1.35, 0), Vector3(0.17, 0.10, 0.17), _signal)

func build_edges(p: Node3D) -> void:
 # A few external utility platforms echo authored slots without scattering onto
 # gameplay surfaces. Their anchors remain entirely outside the terrain bounds.
 var count := clampi(int(p.table_bounds.size.y / 260.0), 2, 8)
 for i in count:
  var y: float = p.table_bounds.position.y + (i + 0.5) * p.table_bounds.size.y / count
  var edge: Vector2 = p._boundary_at_y(y)
  if not is_finite(edge.x): continue
  for side: int in [-1, 1]:
   var x: float = (edge.x if side < 0 else edge.y) + side * 165.0
   var base: Vector3 = p.map_point(Vector2(x, y), -1.5)
   _box(p, p.scenery_root, base, Vector3(1.1, 0.24, 1.05), _steel)
   _silo(p, p.scenery_root, base + Vector3(0, 0.12, 0), 0.35, 1.25 + (i % 2) * 0.3, i)

func build_study(p: Node3D, parent: Node3D, origin: Vector3) -> void:
 parent.position = origin
 _box(p, parent, Vector3(0, -0.15, 0), Vector3(2.8, 0.30, 2.8), side_material)
 _box(p, parent, Vector3(0, 0.01, 0), Vector3(2.8, 0.035, 2.8), top_material)
 _silo(p, parent, Vector3(-1.0, 0, -0.85), 0.25, 1.1, 0)
 _silo(p, parent, Vector3(1.0, 0, -0.85), 0.25, 0.85, 1)

func _silo(p: Node3D, parent: Node3D, base: Vector3, radius: float, height: float, variant: int) -> void:
 var cylinder := CylinderMesh.new()
 cylinder.top_radius = radius
 cylinder.bottom_radius = radius
 cylinder.height = height
 cylinder.radial_segments = 10
 cylinder.rings = 1
 p.mesh_node(cylinder, _blue if variant % 2 == 0 else _dark, base + Vector3.UP * height * 0.5, parent)
 for fraction: float in [0.08, 0.78, 0.96]:
  var collar := CylinderMesh.new()
  collar.top_radius = radius * 1.08
  collar.bottom_radius = radius * 1.08
  collar.height = height * 0.045
  collar.radial_segments = 10
  collar.rings = 1
  p.mesh_node(collar, _steel, base + Vector3.UP * height * fraction, parent)
 for i in 5:
  var angle := TAU * float(i) / 5.0
  var radial := Vector3(cos(angle), 0, sin(angle)) * radius * 1.015
  var panel := _box(p, parent, base + radial + Vector3.UP * height * 0.52, Vector3(radius * 0.24, height * 0.36, 0.035), _cyan if variant % 2 == 0 else _signal)
  panel.rotation.y = -angle + PI * 0.5
 var cap := CylinderMesh.new()
 cap.bottom_radius = radius
 cap.top_radius = radius * 0.6
 cap.height = height * 0.13
 cap.radial_segments = 10
 cap.rings = 1
 p.mesh_node(cap, _steel, base + Vector3.UP * height * 1.065, parent)
 _box(p, parent, base + Vector3.UP * height * 1.17, Vector3(radius * 0.19, 0.10, radius * 0.19), _signal)

func _box(p: Node3D, parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
 var box := BoxMesh.new()
 box.size = size
 return p.mesh_node(box, mat, at, parent)

func _pipe(p: Node3D, parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
 var cylinder := CylinderMesh.new()
 cylinder.top_radius = radius
 cylinder.bottom_radius = radius
 cylinder.height = a.distance_to(b)
 cylinder.radial_segments = 8
 cylinder.rings = 1
 var mesh: MeshInstance3D = p.mesh_node(cylinder, mat, (a + b) * 0.5, parent)
 mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func ramp_materials() -> Dictionary:
 var blue := material(Color("314acb"))
 blue.roughness = 0.32
 blue.metallic = 0.25
 var coupler := material(Color("6e7896"))
 coupler.roughness = 0.48
 coupler.metallic = 0.45
 return {"deck": _shader(preload("res://scripts/themes/chemical_ramp_panels.gdshader")),
  "edge": material(Color("e5b638")), "support": material(Color("26384b")), "accent": material(Color("68e1de"), 0.25),
  "pipe": blue, "pipe_clamp": coupler}
