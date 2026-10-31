extends "res://scripts/themes/theme_definition.gd"
## Original Green Hill art, separated from the shared geometry and gameplay renderer.
const GreenHillDecor = preload("res://scripts/decor/green_hill_decor.gd")

const TEXTURES := "res://assets/textures/green_hill/"

func _init() -> void:
 theme_id = "green_hill"
 display_name = "Green Hill"
 edge_trim_color = Color("549c24")
 floor_material = _texture_material("floor", Vector2(4, 4))
 top_material = _texture_material("top", Vector2(4, 4))
 cliff_material = _texture_material("cliff", Vector2(0.32, 0.32), false)
 side_material = ShaderMaterial.new()
 side_material.shader = preload("res://scripts/themes/green_hill_wall.gdshader")
 side_material.set_shader_parameter("soil_texture", load(TEXTURES + "soil.png"))
 side_material.set_shader_parameter("fringe_texture", load(TEXTURES + "wall-fringe.png"))
 side_material.set_shader_parameter("turf_height", TablePresentation.RAIL_HEIGHT)
 floor_border_material = _border_material("floor-border")
 top_border_material = _border_material("top-border")
 floor_border_width = 5.0
 top_border_width = 3.0

func _texture_material(name: String, repeat_size: Vector2, world_mapping := true) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = preload("res://scripts/themes/texture_surface.gdshader")
 result.set_shader_parameter("surface_texture", load(TEXTURES + name + ".png"))
 result.set_shader_parameter("repeat_size", repeat_size)
 result.set_shader_parameter("world_mapping", world_mapping)
 return result

func _border_material(name: String) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = preload("res://scripts/themes/terrain_border.gdshader")
 result.set_shader_parameter("border_texture", load(TEXTURES + name + ".png"))
 return result

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
 # Two staggered headlands follow each Act's actual silhouette, with an ocean
 # channel and one small flower island retaining the original scale variation.
 var bounds: Rect2 = p.table_bounds
 var width_scale := clampf(bounds.size.x / 600.0, 0.75, 1.35)
 var sand := material(Color("dfc179"))
 var decor := GreenHillDecor.new(p)
 var headlands := [
  {"name": "PalmHeadland", "side": -1, "at": 0.80, "span": 0.16, "width": 150.0},
  {"name": "LoopPromontory", "side": 1, "at": 0.24, "span": 0.18, "width": 170.0},
 ]
 for i: int in headlands.size():
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var plan: Dictionary = headlands[i]
  var side: int = plan.side
  var radius := Vector2(float(plan.width) * width_scale, maxf(85.0, bounds.size.y * float(plan.span)))
  var y := bounds.position.y + bounds.size.y * float(plan.at)
  # Include the beach and the full longitudinal prop footprint at curved edges.
  var edge := scenery_side_edge(p, side, y, radius.y * 1.12)
  var center := Vector2(edge + side * (55.0 + radius.x), y)
  var root := _coastal_landform(p, center, radius, i, side, sand)
  root.name = plan.name
  var near_shore := center + Vector2(-side * (radius.x - 55.0), radius.y * 0.36)
  if i == 1:
   # Reuse the existing collisionless landmark; this is scenery, not a new lane.
   var loop: Node3D = decor.factory.call("turf_loop")
   root.add_child(loop)
   loop.position = TablePresentation.map_point(center + Vector2(-side * radius.x * 0.1, radius.y * 0.42), -1.4)
   loop.scale = Vector3.ONE * 0.9
   loop.rotation.y = -0.18
  else:
   _palm(p, TablePresentation.map_point(near_shore, -1.4), side, 0.95 if i == 0 else 0.85, root)
  _flower(p, TablePresentation.map_point(near_shore + Vector2(side * 12.0, -radius.y * 0.42), -1.4), 0.85, root)
 # Keep a few of the original small flower/rock islands for scale and variety,
 # deliberately placed in the gaps instead of repeating them along every edge.
 var islets := [Vector3(1, 0.72, 44)]
 for i: int in islets.size():
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var spec: Vector3 = islets[i]
  var side := int(spec.x)
  var y := bounds.position.y + bounds.size.y * spec.y
  var edge := scenery_side_edge(p, side, y, spec.z + 20.0)
  var center := Vector2(edge + side * (70.0 + spec.z), y)
  _small_coastal_islet(p, center, spec.z, i)
  _flower(p, TablePresentation.map_point(center + Vector2(-side * 12, -5), -0.8), 0.78)
  _rock(p, TablePresentation.map_point(center + Vector2(side * 18, 16), -0.8), 0.22)
 # Background landmarks do not need additional shadow submissions. Streamed
 # backdrops also retain their existing non-shadow-casting directional light.
 for visual: GeometryInstance3D in p.scenery_root.find_children("*", "GeometryInstance3D", true, false):
  visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _coastal_landform(p: Node3D, center: Vector2, radius: Vector2, variation: int, side: int, sand: Material) -> Node3D:
 var root := Node3D.new()
 p.scenery_root.add_child(root)
 var shore: CylinderMesh = p.cylinder(radius.x * TablePresentation.SCALE * 1.10, 0.28)
 shore.radial_segments = 12
 var beach: MeshInstance3D = p.mesh_node(shore, sand, TablePresentation.map_point(center, -2.08), root)
 beach.scale.z = radius.y / radius.x
 var points := PackedVector2Array()
 # An inward cove interrupts the long course-facing edge. Mirroring the cove
 # keeps each shore open to the ocean instead of forming a second course wall.
 var coast := PackedVector2Array([Vector2(1, 0.03), Vector2(0.82, 0.54), Vector2(0.32, 0.88), Vector2(-0.24, 0.96), Vector2(-0.72, 0.72), Vector2(-0.88, 0.34), Vector2(-0.55, 0.03), Vector2(-0.92, -0.32), Vector2(-0.68, -0.72), Vector2(-0.15, -1), Vector2(0.48, -0.84), Vector2(0.9, -0.44)])
 for point: Vector2 in coast:
  var skew := 0.10 if variation % 2 == 0 else -0.06
  points.append(center + Vector2((point.x + point.y * skew) * radius.x * side, point.y * radius.y))
 # A broad turf cap and checker cliff carry the silhouette without a ring of
 # tiny edge cylinders. The low coast remains visibly separate from the course.
 p._make_land(points, 0.9, root, -1.4, 0.0)
 return root

func _small_coastal_islet(p: Node3D, center: Vector2, radius: float, variation: int) -> void:
 var points := PackedVector2Array()
 for i: int in 10:
  var angle := float(i) * TAU / 10.0
  var modulation := 0.92 + 0.08 * sin(float(i * 7 + variation))
  points.append(center + Vector2(cos(angle), sin(angle)) * radius * modulation)
 p._make_land(points, 1.5, p.scenery_root, -0.8, 0.0)

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
 p.mesh_node(water, ocean, TablePresentation.map_point(p.table_bounds.get_center(), -2.3), p.scenery_root).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var sand = material(Color("dfc179"))
 var distant_green = material(Color("77b64c"))
 var distant_dark = material(Color("408e5c"))
 var distant_stone = material(Color("66949b"))
 var center = p.table_bounds.get_center() * TablePresentation.SCALE
 for i: int in 2:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var side := -1 if i == 0 else 1
  var position := Vector3(center.x + side * (p.table_bounds.size.x * TablePresentation.SCALE * 0.5 + 9.0), -1.7, (p.table_bounds.position.y + p.table_bounds.size.y * (0.22 if i == 0 else 0.73)) * TablePresentation.SCALE)
  var shore = p.cylinder(2.4, 0.5)
  shore.radial_segments = 9
  p.mesh_node(shore, sand, position, p.scenery_root)
  var mound = p.cylinder(2.1, 0.9)
  mound.top_radius = 1.3
  mound.radial_segments = 9
  p.mesh_node(mound, distant_green if i == 0 else distant_dark, position + Vector3.UP * 0.6, p.scenery_root)
  var peak_height := 1.5 if i == 0 else 2.0
  var peak = p.cylinder(0.75, peak_height)
  peak.top_radius = 0.24
  peak.radial_segments = 6
  var rock_peak = p.mesh_node(peak, distant_stone, position + Vector3(0, 1.0 + peak_height * 0.5, 0), p.scenery_root)
  rock_peak.rotation.z = side * 0.12
 # Soft clouds and distant green peaks give the lower camera a readable horizon.
 var cloud_material = material(Color("f5ffff"))
 cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 for i: int in 3:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var cloud = Node3D.new()
  cloud.position = Vector3(center.x - 12.0 + float(i) * 12.0, 6.5 + float(i % 2) * 1.3, p.table_bounds.position.y * TablePresentation.SCALE - 7.0 - float(i % 3) * 4.0)
  p.scenery_root.add_child(cloud)
  for j: int in 3:
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
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
 return {"deck": _texture_material("ramp", Vector2(0.64, 1.04), false),
  "edge": top_material, "support": material(Color("704322")), "accent": material(Color("ffe6a1"))}
