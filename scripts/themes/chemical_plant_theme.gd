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
var _vessel_meshes: Dictionary = {}

func _init() -> void:
 theme_id = "chemical_plant"
 display_name = "Chemical Plant"
 _apply_texture_set()
 _steel = _surface(Color("647487"))
 _dark = _surface(Color("1c233b"))
 _blue = _surface(Color("224f9c"))
 _cyan = _surface(Color("4de4dc"), 0.5)
 _signal = _surface(Color("f64e91"), 0.6)
 _yellow = _surface(Color("e5b243"))
 for body: Material in [_dark, _blue]: Atmosphere.color(body, "industrial_body", "tint")
 Atmosphere.color(_steel, "industrial_metal", "tint")
 Atmosphere.color(_yellow, "industrial_trim", "tint")
 Atmosphere.color(_cyan, "industrial_cyan")
 Atmosphere.color(_signal, "signal_pink")

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
 # The shared Zone backdrop starts 1200 pixels before its first Act. Keep this
 # low processing district near its downstream water, where upper gameplay
 # views can expose it. It is a simpler tier than the local hero vessels.
 for i in 5:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var height := 1.6 + float((i * 7) % 3) * 0.35
  var district := Node3D.new()
  root.add_child(district)
  district.position = Vector3(center.x + (i - 2) * 1.8, -1.3, center.z + 1.0 - (i % 2) * 0.3)
  district.scale = Vector3.ONE * 0.45
  var at := Vector3.ZERO
  # Two broad risers and one bridge leave an unmistakable open pipe profile.
  for side: int in [-1, 1]:
   _vessel_piece(p, district, "handle", at + Vector3(side * 0.62, height * 0.5, 0), Vector3(0.32, height, 0.32), _blue)
   _vessel_piece(p, district, "body", at + Vector3(side * 0.62, height * 0.72, 0), Vector3(0.40, 0.18, 0.40), _cyan)
   _vessel_piece(p, district, "stripe", at + Vector3(side * 0.62, 0.16, 0), Vector3(0.85, 0.32, 0.85), _yellow)
  var bridge := _vessel_piece(p, district, "handle", at + Vector3.UP * height, Vector3(0.32, 1.24, 0.32), _blue)
  bridge.rotation.z = PI * 0.5
  _vessel_piece(p, district, "body", at + Vector3(0, height * 0.43, -0.28), Vector3(0.46, height * 0.66, 0.46), _signal)
 for mesh: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
  mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_edges(p: Node3D) -> void:
 # One tank and a short pipe run on each side follow the local bend. Long
 # straight spines would recreate the invisible bounding-box gap on curved Acts.
 var root: Node3D = p.scenery_root
 var layout := scenery_layout(p)
 for plan: Dictionary in layout.plans([{"side": -1, "at": 0.80}, {"side": 1, "at": 0.24}]):
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var side: int = plan.side
  var radius := layout.varied("radius/" + str(plan.id), 0.85, 0.10)
  var span := maxf(radius * 1.08 / p.SCALE, 65.0 + 0.18 / p.SCALE)
  var y := layout.fit(p.table_bounds, side, lerpf(p.table_bounds.position.y, p.table_bounds.end.y, plan.at), span)
  if not is_finite(y): continue
  var edge := scenery_side_edge(p, side, y, span)
  var base: Vector3 = p.map_point(Vector2(edge + side * (radius * 1.08 / p.SCALE + 35.0), y), -2.2)
  _silo(p, root, base, radius, layout.varied("height/" + str(plan.id), 3.1, 0.35), layout.choice("tank/" + str(plan.id), plan.id % 2, 2))
  var pipe_x := edge + side * 38.0
  _pipe(p, root, p.map_point(Vector2(pipe_x, y - 65.0), -1.35), p.map_point(Vector2(pipe_x, y + 65.0), -1.35), 0.18, _blue)
  _pipe(p, root, base + Vector3.UP * 0.85, p.map_point(Vector2(pipe_x, y), -1.35), 0.16, _steel)
 p.scenery_group_count = layout.occupied.size()
 # These external silhouettes do not need to cast into the playable lanes.
 for mesh: GeometryInstance3D in p.scenery_root.find_children("*", "GeometryInstance3D", true, false):
  mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_study(p: Node3D, parent: Node3D, origin: Vector3) -> void:
 parent.position = origin
 _box(p, parent, Vector3(0, -0.15, 0), Vector3(2.8, 0.30, 2.8), side_material)
 _box(p, parent, Vector3(0, 0.01, 0), Vector3(2.8, 0.035, 2.8), top_material)
 _silo(p, parent, Vector3(-1.0, 0, -0.85), 0.25, 1.1, 0)
 _silo(p, parent, Vector3(1.0, 0, -0.85), 0.25, 0.85, 1)

func _silo(p: Node3D, parent: Node3D, base: Vector3, radius: float, height: float, variant: int) -> void:
 # A pinched chemical vessel replaces the generic straight silo. Broad shoulders,
 # an exposed fluid mass and two pipe handles read from either side of the Act.
 # Every piece stays inside the existing 1.08-radius scenery clearance envelope.
 for band: Vector3 in [Vector3(0.16, 0.32, 1.0), Vector3(0.54, 0.44, 0.60), Vector3(0.86, 0.20, 1.0)]:
  var mat: Material = _signal if band.z < 0.7 else (_blue if band.x < 0.5 else _yellow)
  _vessel_piece(p, parent, "body", base + Vector3.UP * height * band.x, Vector3(radius * band.z, height * band.y, radius * band.z), mat)
 for fraction: float in [0.08, 0.32, 0.76, 0.96]:
  _vessel_piece(p, parent, "body", base + Vector3.UP * height * fraction, Vector3(radius * 1.08, height * 0.045, radius * 1.08), _cyan if fraction in [0.32, 0.76] else _steel)
 for side: int in [-1, 1]:
  var a := base + Vector3(side * radius * 0.55, height * 0.35, 0)
  var b := base + Vector3(side * radius * 0.89, height * 0.42, 0)
  var c := base + Vector3(side * radius * 0.89, height * 0.66, 0)
  var d := base + Vector3(side * radius * 0.55, height * 0.73, 0)
  for segment: Array in [[a, b], [b, c], [c, d]]:
   var pipe: MeshInstance3D = _vessel_piece(p, parent, "handle", (segment[0] + segment[1]) * 0.5, Vector3(radius * 0.15, segment[0].distance_to(segment[1]), radius * 0.15), _blue if variant % 2 == 0 else _dark)
   pipe.quaternion = Quaternion(Vector3.UP, (segment[1] - segment[0]).normalized())
 # Four large hazard blocks wrap the shoulder; no little labels or valve swarm.
 for i in 4:
  var angle := TAU * (i + 0.5) / 4.0
  var radial := Vector3(cos(angle), 0, sin(angle)) * radius * 0.98
  var stripe := _vessel_piece(p, parent, "stripe", base + radial + Vector3.UP * height * 0.86, Vector3(radius * 0.35, height * 0.17, radius * 0.04), _dark)
  stripe.rotation.y = -angle + PI * 0.5
 _vessel_piece(p, parent, "cap", base + Vector3.UP * height * 1.065, Vector3(radius, height * 0.13, radius), _steel)
 _vessel_piece(p, parent, "stripe", base + Vector3.UP * height * 1.17, Vector3(radius * 0.19, 0.10, radius * 0.19), _signal)

func _vessel_piece(p: Node3D, parent: Node3D, kind: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
 # Unit meshes let the existing static batcher combine differently sized tanks.
 # Sizes live on transforms; there is no additional runtime batching system.
 if not _vessel_meshes.has(kind):
  if kind == "stripe":
   _vessel_meshes[kind] = BoxMesh.new()
  else:
   var cylinder := CylinderMesh.new()
   cylinder.top_radius = 0.6 if kind == "cap" else 1.0
   cylinder.bottom_radius = 1.0
   cylinder.height = 1.0
   cylinder.radial_segments = 8 if kind == "handle" else 10
   cylinder.rings = 1
   _vessel_meshes[kind] = cylinder
 var mesh: MeshInstance3D = p.mesh_node(_vessel_meshes[kind], mat, at, parent)
 mesh.scale = size
 return mesh

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
 return {"deck": _texture_ramp(),
  "edge": material(Color("e5b638")), "support": material(Color("26384b")), "accent": material(Color("68e1de"), 0.25),
  "pipe": blue, "pipe_clamp": coupler}
