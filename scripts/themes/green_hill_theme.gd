extends "res://scripts/themes/theme_definition.gd"
## Original Green Hill art, separated from the shared geometry and gameplay renderer.
const GreenHillDecor = preload("res://scripts/decor/green_hill_decor.gd")

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform bool raised_turf = false;
varying vec3 terrain_position;
void vertex() { terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
 vec2 ground = terrain_position.xz;
 vec2 p = ground * 3.0;
 vec2 cell = floor(p);
 vec2 blend = fract(p);
 blend = blend * blend * (3.0 - 2.0 * blend);
 float noise = mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
 // Staggered little grass tufts, with broad patches underneath. World-space
 // coordinates keep the same texture density on curved stamps and rail caps.
 vec2 blades = ground * 28.0;
 blades.x += mod(floor(blades.y), 2.0) * 0.5;
 vec2 blade = fract(blades) - 0.5;
 float tuft = (1.0 - smoothstep(0.055, 0.14, abs(abs(blade.x) - (blade.y + 0.35) * 0.32))) * step(-0.3, blade.y) * step(blade.y, 0.28);
 vec3 dark = raised_turf ? vec3(0.14, 0.49, 0.025) : vec3(0.16, 0.40, 0.045);
 vec3 light = raised_turf ? vec3(0.40, 0.78, 0.035) : vec3(0.28, 0.55, 0.065);
 ALBEDO = mix(dark, light, 0.35 + noise * 0.40 + tuft * 0.22);
 ROUGHNESS = 1.0;
}
"""
const CLIFF_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
void fragment() {
 vec2 tile = floor(UV * 6.25);
 float checker = mod(tile.x + tile.y, 2.0);
 vec2 edge = min(fract(UV * 6.25), 1.0 - fract(UV * 6.25));
 float seam = smoothstep(0.0, 0.035, min(edge.x, edge.y));
 vec3 dark = vec3(0.30, 0.095, 0.025);
 vec3 light = vec3(0.72, 0.32, 0.075);
 ALBEDO = mix(dark, light, checker) * mix(0.88, 1.0, seam);
 ROUGHNESS = 1.0;
}
"""
const WALL_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float turf_height = 0.30;
varying vec3 terrain_position;
varying vec3 terrain_normal;
void vertex() {
 terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 // Triplanar checker soil wraps both straight and curved walls without stretching.
 vec3 tile = terrain_position * 6.25;
 float checker_x = mod(floor(tile.z) + floor(tile.y), 2.0);
 float checker_z = mod(floor(tile.x) + floor(tile.y), 2.0);
 vec2 weights = pow(abs(terrain_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 float checker = dot(vec2(checker_x, checker_z), weights);
 vec3 soil = mix(vec3(0.30, 0.095, 0.025), vec3(0.72, 0.32, 0.075), checker);
 float fringe = abs(fract((terrain_position.x + terrain_position.z) * 24.0) - 0.5) * 0.045;
 float depth = turf_height - terrain_position.y;
 vec3 grass = mix(vec3(0.13, 0.39, 0.025), vec3(0.49, 0.79, 0.035), 1.0 - smoothstep(0.0, 0.08, depth));
 ALBEDO = mix(soil, grass, step(depth, 0.065 + fringe));
 ROUGHNESS = 1.0;
}
"""

func _init() -> void:
 theme_id = "green_hill"
 display_name = "Green Hill"
 edge_trim_color = Color("549c24")
 floor_material = _shader_material(GRASS_SHADER)
 cliff_material = _shader_material(CLIFF_SHADER)
 top_material = _shader_material(GRASS_SHADER)
 top_material.set_shader_parameter("raised_turf", true)
 side_material = _shader_material(WALL_SHADER)
 side_material.set_shader_parameter("turf_height", TablePresentation.RAIL_HEIGHT)

func create_decor(presentation: Node3D) -> RefCounted:
 return GreenHillDecor.new(presentation)

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
 # Reuse the original collision-matched mesh silhouettes with a cohesive toy palette.
 var palette := {
  "267f81": Color("ba622e"), "64d6bd": Color("ffe5a0"),
  "b34039": Color("cf3b36"), "ff8962": Color("fff3d1"),
  "ffd568": Color("ffd62e"), "307ac3": Color("e84535"),
  "b0e6ff": Color("fff2cb"), "4f97ff": Color("197ee5")
 }
 var result := super.material(palette.get(color.to_html(false), color), glow)
 result.roughness = 0.87
 result.metallic_specular = 0.16
 return result

func configure_environment(p: Node3D) -> void:
 for child: Node in p.get_children():
  if child is WorldEnvironment:
   var world: Environment = child.environment
   var sky_material = ProceduralSkyMaterial.new()
   sky_material.sky_top_color = Color("168bdb")
   sky_material.sky_horizon_color = Color("bcecf0")
   sky_material.ground_bottom_color = Color("47bfc0")
   sky_material.ground_horizon_color = Color("bcecf0")
   sky_material.sky_curve = 0.22
   sky_material.sun_angle_max = 7.0
   var sky = Sky.new()
   sky.sky_material = sky_material
   world.background_mode = Environment.BG_SKY
   world.sky = sky
   world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
   world.ambient_light_color = Color("d3eeff")
   world.ambient_light_energy = 0.30
   world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
   world.glow_enabled = false
  elif child is DirectionalLight3D:
   child.rotation_degrees = Vector3(-55, -38, 0)
   child.light_color = Color("fff2cf")
   child.light_energy = 0.78
   child.shadow_normal_bias = 2.0

func build_edges(p: Node3D) -> void:
 var rows = maxi(3, int(p.table_bounds.size.y / 285.0))
 for row: int in rows:
  var y = p.table_bounds.position.y + 120.0 + row * 280.0
  if y > p.table_bounds.end.y - 190.0:
   continue
  var edge = p._boundary_at_y(y)
  if not is_finite(edge.x):
   continue
  for side: int in [-1, 1]:
   var base_x = edge.x if side < 0 else edge.y
   var palm_here = (row + (1 if side > 0 else 0)) % 3 == 0
   var x = base_x + side * (100.0 if palm_here else 70.0)
   var center = Vector2(x, y + (25.0 if side > 0 else -25.0))
   _small_island(p, center, 62.0 if palm_here else 44.0, row)
   if palm_here:
    _palm(p, TablePresentation.map_point(center), side, 1.0 + float(row % 2) * 0.13)
    _flower(p, TablePresentation.map_point(center + Vector2(side * -18.0, 28.0)), 0.68)
   else:
    _flower(p, TablePresentation.map_point(center + Vector2(-12, 5)), 0.8 + float(row % 2) * 0.15)
    _flower(p, TablePresentation.map_point(center + Vector2(16, -11)), 0.58)
    _rock(p, TablePresentation.map_point(center + Vector2(15, 20)), 0.16 + float(row % 3) * 0.035)

func _small_island(p: Node3D, center: Vector2, radius: float, variation: int) -> void:
 var points = PackedVector2Array()
 for i: int in 10:
  var angle = float(i) * TAU / 10.0
  var modulation = 0.92 + 0.08 * sin(float(i * 7 + variation))
  points.append(center + Vector2(cos(angle), sin(angle)) * radius * modulation)
 p._make_land(points, 1.0 + float(variation % 3) * 0.13, p.scenery_root)

func _palm(p: Node3D, base: Vector3, side: int, size: float, target: Node3D = null) -> void:
 var palm = Node3D.new()
 palm.name = "ProceduralPalm"
 palm.position = base
 palm.scale = Vector3.ONE * size
 (p.scenery_root if target == null else target).add_child(palm)
 var bark = material(Color("b7863b"))
 var bark_light = material(Color("d6ad59"))
 var previous = Vector3.ZERO
 var tip = Vector3.ZERO
 for step: int in 7:
  var progress = float(step + 1) / 7.0
  tip = Vector3(side * progress * progress * 0.32, progress * 1.75, -0.10 * progress)
  var stem = p.cylinder(lerpf(0.12, 0.065, progress), previous.distance_to(tip))
  stem.radial_segments = 7
  var piece = p.mesh_node(stem, bark if step % 2 == 0 else bark_light, (previous + tip) * 0.5, palm)
  piece.quaternion = Quaternion(Vector3.UP, (tip - previous).normalized())
  previous = tip
 for leaf: int in 8:
  var angle = float(leaf) * TAU / 8.0 + 0.16
  _palm_frond(p, tip, angle, 1.10 + float(leaf % 3) * 0.09, leaf % 2 == 0, palm)
 var coconut = material(Color("704425"))
 for offset: Vector3 in [Vector3(-0.11, -0.07, 0), Vector3(0.10, -0.09, 0.06), Vector3(0, -0.12, -0.10)]:
  p.mesh_node(p.sphere(0.11), coconut, tip + offset, palm)

func _palm_frond(p: Node3D, base: Vector3, angle: float, length: float, bright: bool, parent: Node3D) -> void:
 var direction = Vector3(cos(angle), 0, sin(angle))
 var sideways = Vector3(-sin(angle), 0, cos(angle))
 var surface = SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for segment: int in 5:
  var a = float(segment) / 5.0
  var b = float(segment + 1) / 5.0
  var center_a = base + direction * length * a + Vector3.UP * (sin(a * PI) * 0.33 - a * 0.42)
  var center_b = base + direction * length * b + Vector3.UP * (sin(b * PI) * 0.33 - b * 0.42)
  var width_a = sin(a * PI) * 0.24
  var width_b = sin(b * PI) * 0.24
  for sign_value: int in [-1, 1]:
   var outer_a = center_a + sideways * width_a * sign_value - Vector3.UP * width_a * 0.30
   var outer_b = center_b + sideways * width_b * sign_value - Vector3.UP * width_b * 0.30
   for vertex: Vector3 in [center_a, outer_a, center_b, center_b, outer_a, outer_b]:
    surface.set_normal(Vector3.UP)
    surface.add_vertex(vertex)
 var leaves = material(Color("62be30") if bright else Color("329a36"))
 leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
 p.mesh_node(surface.commit(), leaves, Vector3.ZERO, parent)

func _flower(p: Node3D, base: Vector3, size: float, target: Node3D = null) -> void:
 var flower = Node3D.new()
 flower.name = "WildSunflower"
 flower.position = base
 flower.scale = Vector3.ONE * size
 (p.scenery_root if target == null else target).add_child(flower)
 var green = material(Color("278c3e"))
 p.mesh_node(p.cylinder(0.018, 0.37), green, Vector3(0, 0.185, 0), flower)
 var leaves = p.sphere(0.1)
 var leaf = p.mesh_node(leaves, green, Vector3(0.08, 0.15, 0), flower)
 leaf.scale = Vector3(1.2, 0.22, 0.55)
 leaf.rotation.z = 0.45
 var petals = material(Color("ffcf24"))
 for i: int in 8:
  var angle = float(i) * TAU / 8.0
  var petal = p.mesh_node(p.sphere(0.075), petals, Vector3(cos(angle) * 0.115, 0.42 + sin(angle) * 0.115, 0), flower)
  petal.scale = Vector3(0.7, 1.0, 0.35)
  petal.rotation.z = angle - PI * 0.5
 var heart = p.mesh_node(p.cylinder(0.082, 0.05), material(Color("6f3c25")), Vector3(0, 0.42, 0.02), flower)
 heart.rotation.x = PI * 0.5

func _rock(p: Node3D, base: Vector3, size: float) -> void:
 var mesh = SphereMesh.new()
 mesh.radius = size
 mesh.height = size * 1.4
 mesh.radial_segments = 6
 mesh.rings = 3
 var rock = p.mesh_node(mesh, material(Color("bbb595")), base + Vector3.UP * size * 0.45, p.scenery_root)
 rock.rotation.y = base.z * 0.7
 rock.scale = Vector3(1.15, 0.8, 0.85)

func build_background(p: Node3D) -> void:
 var water = PlaneMesh.new()
 water.size = Vector2(150, 150)
 var ocean = material(Color("24afc0"))
 ocean.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 p.mesh_node(water, ocean, TablePresentation.map_point(p.table_bounds.get_center(), -2.3), p.scenery_root)
 var sand = material(Color("dfc179"))
 var distant_green = material(Color("77b64c"))
 var distant_dark = material(Color("408e5c"))
 var distant_stone = material(Color("66949b"))
 var center = p.table_bounds.get_center() * TablePresentation.SCALE
 for side: int in [-1, 1]:
  for i: int in 6:
   var position = Vector3(center.x + side * (12.0 + float(i % 2) * 4.0), -1.7, center.y - 23.0 + float(i) * 8.0)
   var shore = p.cylinder(2.6 + float(i % 3) * 0.4, 0.5)
   shore.radial_segments = 9
   p.mesh_node(shore, sand, position, p.scenery_root)
   var mound = p.cylinder(2.35 + float(i % 3) * 0.4, 1.2)
   mound.top_radius = 1.5
   mound.radial_segments = 9
   p.mesh_node(mound, distant_green if i % 2 == 0 else distant_dark, position + Vector3.UP * 0.6, p.scenery_root)
   var peak_height = 1.8 + float(i % 3) * 0.65
   var peak = p.cylinder(0.95, peak_height)
   peak.top_radius = 0.32
   peak.radial_segments = 6
   var rock_peak = p.mesh_node(peak, distant_stone, position + Vector3(0, 1.0 + peak_height * 0.5, 0), p.scenery_root)
   rock_peak.rotation.z = side * 0.12
 # Soft clouds and distant green peaks give the lower camera a readable horizon.
 var cloud_material = material(Color("f5ffff"))
 cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 for i: int in 7:
  var cloud = Node3D.new()
  cloud.position = Vector3(center.x - 25.0 + float(i) * 8.0, 6.5 + float(i % 2) * 1.3, p.table_bounds.position.y * TablePresentation.SCALE - 17.0 - float(i % 3) * 4.0)
  p.scenery_root.add_child(cloud)
  for j: int in 4:
   var puff = p.mesh_node(p.sphere(1.2 + float(j % 2) * 0.3), cloud_material, Vector3(float(j) * 1.1, float(j % 2) * 0.2, 0), cloud)
   puff.scale = Vector3(1.2, 0.58, 0.8)

func build_study(p: Node3D, parent: Node3D, origin: Vector3) -> void:
 # A separate presentation-only diorama keeps close study clear of gameplay rails.
 parent.position = origin
 var outline = PackedVector2Array()
 for i: int in 24:
  outline.append(Vector2.from_angle(float(i) * TAU / 24.0) * 145.0)
 p._make_land(outline, origin.y + 2.3, parent)
 _palm(p, Vector3(-0.95, 0, -0.85), -1, 0.78, parent)
 _palm(p, Vector3(1.03, 0, -0.80), 1, 0.70, parent)
 _flower(p, Vector3(-1.00, 0, 0.55), 0.85, parent)
 _flower(p, Vector3(-1.17, 0, 0.25), 0.60, parent)
 _flower(p, Vector3(1.08, 0, 0.34), 0.76, parent)
 _flower(p, Vector3(0.88, 0, 0.67), 0.56, parent)

func ramp_materials() -> Dictionary:
 return {"deck": _ramp_deck(Color("b97d3f"), Color("d2a15d"), 0),
  "edge": top_material, "support": material(Color("704322")), "accent": material(Color("ffe6a1"))}
