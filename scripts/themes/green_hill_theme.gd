extends "res://scripts/themes/theme_definition.gd"
## Original Green Hill art, separated from the shared geometry and gameplay renderer.
const GreenHillDecor = preload("res://scripts/decor/green_hill_decor.gd")
const Density = preload("res://scripts/presentation_density.gd")

const SELECTED := "res://assets/textures/green_hill/selected/"
var _selected_textures: Dictionary = {}

const TEXTURES := "res://assets/textures/green_hill/"

func _init() -> void:
 theme_id = "green_hill"
 display_name = "Green Hill"
 edge_trim_color = Color("549c24")
 floor_material = _texture_material("1A", Vector2(4, 4))
 top_material = _texture_material("5B", Vector2(2, 2))
 side_material = ShaderMaterial.new()
 side_material.shader = preload("res://scripts/themes/green_hill_wall.gdshader")
 side_material.set_shader_parameter("soil_texture", _selected_texture("3A"))
 side_material.set_shader_parameter("fringe_texture", _selected_texture("4B"))
 side_material.set_shader_parameter("turf_height", TablePresentation.RAIL_HEIGHT + TablePresentation.RAIL_CAP_HEIGHT)
 cliff_material = side_material.duplicate()
 cliff_material.set_shader_parameter("show_fringe", false)
 floor_border_material = _border_material("2B")
 top_border_material = _border_material("6B")
 floor_border_width = 5.0
 top_border_width = 3.0

func _selected_texture(id: String) -> Texture2D:
 if _selected_textures.has(id): return _selected_textures[id]
 var texture: Texture2D
 if OS.has_feature("editor"):
  var image := Image.load_from_file(ProjectSettings.globalize_path(SELECTED + id + ".png"))
  image.generate_mipmaps()
  texture = ImageTexture.create_from_image(image)
 else:
  texture = load(SELECTED + id + ".png")
 _selected_textures[id] = texture
 return texture

func _guard_material() -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = preload("res://scripts/themes/green_hill_guard.gdshader")
 result.set_shader_parameter("surface_texture", _selected_texture("8B"))
 return result

func wall_distances(points: PackedVector2Array) -> PackedFloat32Array:
 # Keep one continuous U coordinate around the contour, with a whole number
 # of texture repeats at the closing edge. All meshes share world-height rows.
 var distances := PackedFloat32Array([0.0])
 var anchor := 0
 for i in points.size():
  distances.append(distances[-1] + points[i].distance_to(points[(i + 1) % points.size()]) * TablePresentation.SCALE)
  if points[i].x < points[anchor].x or (is_equal_approx(points[i].x, points[anchor].x) and points[i].y < points[anchor].y):
   anchor = i
 var perimeter := distances[-1]
 var fitted_length := maxf(1.0, roundf(perimeter / 0.64)) * 0.64
 var scale_u := fitted_length / maxf(perimeter, 0.0001)
 var origin := distances[anchor]
 for i in distances.size(): distances[i] = (distances[i] - origin) * scale_u
 return distances

func wrap_wall_mesh(mesh: ArrayMesh, outline: PackedVector2Array) -> ArrayMesh:
 var points := outline.duplicate()
 if Geometry2D.is_polygon_clockwise(points): points.reverse()
 var distances := wall_distances(points)
 var arrays := mesh.surface_get_arrays(1)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var coords := PackedVector2Array()
 for i in points.size():
  for j in 6:
   var u := distances[i + 1] if j == 1 or j == 3 or j == 4 else distances[i]
   coords.append(Vector2(u, vertices[i * 6 + j].y))
 arrays[Mesh.ARRAY_TEX_UV] = coords
 var result := ArrayMesh.new()
 for i in mesh.get_surface_count():
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays if i == 1 else mesh.surface_get_arrays(i))
  result.surface_set_material(i, mesh.surface_get_material(i))
 return result

func _texture_material(name: String, repeat_size: Vector2, world_mapping := true) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = preload("res://scripts/themes/green_hill_turf.gdshader") if name in ["1A", "5B"] else preload("res://scripts/themes/texture_surface.gdshader")
 result.set_shader_parameter("surface_texture", load(TEXTURES + name + ".png") if name == "ramp" else _selected_texture(name))
 result.set_shader_parameter("repeat_size", repeat_size)
 result.set_shader_parameter("world_mapping", world_mapping)
 return result

func _border_material(name: String) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = preload("res://scripts/themes/terrain_border.gdshader")
 result.set_shader_parameter("border_texture", load(TEXTURES + name + ".png") if name == "ramp" else _selected_texture(name))
 return result

func create_decor(presentation: Node3D) -> RefCounted:
 return GreenHillDecor.new(presentation)

func combine_static_scenery(p: Node3D) -> void:
 if not is_instance_valid(p) or p.theme_definition != self or not is_instance_valid(p.scenery_root): return
 var combiner = preload("res://scripts/themes/green_hill_static_scenery.gd")
 combiner.combine(p.scenery_root)
 if is_instance_valid(p.decor_root): combiner.combine(p.decor_root)

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
 # Reuse the original collision-matched mesh silhouettes with a cohesive toy palette.
 var palette := {
  "267f81": Color("ba622e"), "64d6bd": Color("ffe5a0"),
  "b34039": Color("cf3b36"), "ff8962": Color("fff3d1"),
  "ffd568": Color("ffd62e"), "307ac3": Color("e84535"),
  "b0e6ff": Color("fff2cb"), "4f97ff": Color("197ee5")
 }
 var result := super.material(palette.get(color.to_html(false), color), glow)
 if color.to_html(false) in ["287e38", "52ae36", "b9b497", "bbb595"]:
  result.albedo_color = Color.WHITE
  result.albedo_texture = _selected_texture("10A" if color.to_html(false) in ["287e38", "52ae36"] else "11B")
  result.uv1_triplanar = true
  result.uv1_scale = Vector3.ONE * 1.5
 result.roughness = 0.87
 result.metallic_specular = 0.16
 return result

func configure_environment(p: Node3D) -> void:
 # Build routines finish synchronously; combine only after props are placed.
 if not p.has_method("stream_checkpoint"): combine_static_scenery.call_deferred(p)
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
 Atmosphere.color(sand, "local_sand")
 var decor := GreenHillDecor.new(p)
 var layout := scenery_layout(p)
 var headlands := layout.plans([
  {"name": "PalmHeadland", "side": -1, "at": 0.80, "span": 0.14, "width": 125.0},
  {"name": "LoopPromontory", "side": 1, "at": 0.24, "span": 0.14, "width": 135.0},
 ])
 for i: int in headlands.size():
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var plan: Dictionary = headlands[i]
  var side: int = plan.side
  var radius := Vector2(float(plan.width) * width_scale * layout.varied("width/" + str(i), 1.0, 0.10), maxf(85.0, bounds.size.y * float(plan.span)))
  var y := layout.fit(bounds, side, bounds.position.y + bounds.size.y * float(plan.at), radius.y * 1.12)
  if not is_finite(y): continue
  # Include the beach and the full longitudinal prop footprint at curved edges.
  var edge := scenery_side_edge(p, side, y, radius.y * 1.12)
  var center := Vector2(edge + side * (55.0 + radius.x), y)
  var top_height: float = [-1.15, -1.55, -0.90, -1.30, -1.65][i % 5]
  var root := _coastal_landform(p, center, radius, i, side, sand, top_height)
  root.name = plan.name
  var near_shore := center + Vector2(-side * (radius.x - 55.0), radius.y * 0.36)
  var has_loop := i == layout.choice("loop", 1, 2)
  if has_loop:
   # The coastal loop has short approaches; authored landmark footprints stay
   # unchanged. Both versions remain collisionless scenery.
   var loop: Node3D = decor.build_coastal_loop()
   root.add_child(loop)
   loop.position = TablePresentation.map_point(center + Vector2(-side * radius.x * 0.1, radius.y * 0.42), top_height)
   loop.scale = Vector3.ONE * 0.82
   loop.rotation.y = layout.varied("loop yaw", -0.18, 0.18)
  else:
   _palm(p, TablePresentation.map_point(near_shore, top_height), side, 0.95 if i == 0 else 0.85, root)
  if layout.density >= 0.75:
   _flower(p, TablePresentation.map_point(near_shore + Vector2(side * 12.0, -radius.y * 0.42), top_height), 0.85, root)
  if layout.density >= 0.75:
   # Broad rocks sit in the open foreground (or behind the loop opening), not
   # underneath the palm canopy. Reuse the textured, faceted prop library.
   var rock_at := center + (Vector2(side * 22, -radius.y * 0.25) if has_loop else Vector2(side * radius.x * 0.35, radius.y * 0.42))
   var rocks: Node3D = decor.factory.call("medium_rock")
   root.add_child(rocks)
   rocks.position = TablePresentation.map_point(rock_at, top_height)
   rocks.rotation.y = side * 0.35
   if not has_loop:
    var shrub: Node3D = decor.factory.call("shrub")
    root.add_child(shrub)
    shrub.position = TablePresentation.map_point(center + Vector2(-side * radius.x * 0.15, radius.y * 0.68), top_height)
    shrub.scale = Vector3.ONE * 0.75
 # Keep a few of the original small flower/rock islands for scale and variety,
 # deliberately placed in the gaps instead of repeating them along every edge.
 var islets := [Vector3(1, 0.72, 44)] if layout.density >= 1.0 else []
 if layout.density >= 1.25: islets.append(Vector3(-1, 0.46, 36))
 for i: int in islets.size():
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var spec: Vector3 = islets[i]
  var side := int(spec.x) * (-1 if layout.choice("islet side", 0, 2) == 1 else 1)
  var y := layout.fit(bounds, side, bounds.position.y + bounds.size.y * layout.varied("islet/" + str(i), spec.y, 0.06), spec.z + 20.0)
  if not is_finite(y): continue
  var edge := scenery_side_edge(p, side, y, spec.z + 20.0)
  var center := Vector2(edge + side * (70.0 + spec.z), y)
  var top_height := -1.65 if i == 0 else -1.05
  _small_coastal_islet(p, center, spec.z, i, top_height)
  _flower(p, TablePresentation.map_point(center + Vector2(-side * 12, -5), top_height), 0.78)
  _rock(p, TablePresentation.map_point(center + Vector2(side * 18, 16), top_height), 0.22)
 p.scenery_group_count = layout.occupied.size()
 # Background landmarks do not need additional shadow submissions. Streamed
 # backdrops also retain their existing non-shadow-casting directional light.
 for visual: GeometryInstance3D in p.scenery_root.find_children("*", "GeometryInstance3D", true, false):
  visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _coastal_landform(p: Node3D, center: Vector2, radius: Vector2, variation: int, side: int, sand: Material, top_height: float) -> Node3D:
 var root := Node3D.new()
 p.scenery_root.add_child(root)
 var shore: CylinderMesh = p.cylinder(radius.x * TablePresentation.SCALE * 1.10, 0.28)
 shore.radial_segments = 12
 var beach: MeshInstance3D = p.mesh_node(shore, sand, TablePresentation.map_point(center, -2.18), root)
 beach.scale.z = radius.y / radius.x
 var points := PackedVector2Array()
 # An inward cove interrupts the long course-facing edge. Mirroring the cove
 # keeps each shore open to the ocean instead of forming a second course wall.
 var coast := PackedVector2Array([Vector2(1, 0.03), Vector2(0.82, 0.54), Vector2(0.32, 0.88), Vector2(-0.24, 0.96), Vector2(-0.72, 0.72), Vector2(-0.88, 0.34), Vector2(-0.55, 0.03), Vector2(-0.92, -0.32), Vector2(-0.68, -0.72), Vector2(-0.15, -1), Vector2(0.48, -0.84), Vector2(0.9, -0.44)])
 if variation % 3 == 1:
  # A narrow seaward point and a wider loop-bearing shoulder.
  coast = PackedVector2Array([Vector2(1, 0), Vector2(0.52, 0.45), Vector2(0.15, 0.95), Vector2(-0.55, 0.80), Vector2(-0.90, 0.28), Vector2(-0.64, -0.15), Vector2(-0.78, -0.72), Vector2(-0.20, -0.95), Vector2(0.45, -0.60)])
 elif variation % 3 == 2:
  # A broad bluff with a shallow inlet, using the same conservative footprint.
  coast = PackedVector2Array([Vector2(0.90, 0.48), Vector2(0.45, 0.90), Vector2(-0.25, 0.88), Vector2(-0.88, 0.54), Vector2(-0.58, 0.08), Vector2(-0.92, -0.35), Vector2(-0.45, -0.92), Vector2(0.45, -0.82), Vector2(0.95, -0.25)])
 for point: Vector2 in coast:
  var skew := 0.10 if variation % 2 == 0 else -0.06
  points.append(center + Vector2((point.x + point.y * skew) * radius.x * side, point.y * radius.y))
 # A broad turf cap and checker cliff carry the silhouette without a ring of
 # tiny edge cylinders. The low coast remains visibly separate from the course.
 p._make_land(points, top_height + 2.3, root, top_height, 0.0)
 if variation % 3 != 1:
  var terrace_center := center + Vector2(side * radius.x * 0.33, -radius.y * 0.22)
  var terrace := PackedVector2Array()
  for i in 8:
   var direction := Vector2.from_angle(TAU * i / 8.0)
   terrace.append(terrace_center + direction * radius * Vector2(0.43, 0.40))
  p._make_land(terrace, 0.46, root, top_height + 0.46, 0.0)
  _palm(p, TablePresentation.map_point(terrace_center, top_height + 0.46), -side, 0.56, root)
 return root

func _small_coastal_islet(p: Node3D, center: Vector2, radius: float, variation: int, top_height: float) -> void:
 var points := PackedVector2Array()
 for i: int in 10:
  var angle := float(i) * TAU / 10.0
  var modulation := 0.92 + 0.08 * sin(float(i * 7 + variation))
  points.append(center + Vector2(cos(angle), sin(angle)) * radius * modulation)
 p._make_land(points, top_height + 2.3, p.scenery_root, top_height, 0.0)

func _palm(p: Node3D, base: Vector3, side: int, size: float, target: Node3D = null) -> void:
 var palm = Node3D.new()
 palm.name = "ProceduralPalm"
 palm.position = base
 palm.scale = Vector3.ONE * size
 (p.scenery_root if target == null else target).add_child(palm)
 var wood := preload("res://scripts/themes/green_hill_palette.gd").wood(self)
 var bark = material(wood[0])
 var bark_light = material(wood[1])
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
  p.mesh_node(Density.sphere(0.11, Density.Family.TINY), coconut, tip + offset, palm)

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
 Atmosphere.foliage(leaves)
 leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
 p.mesh_node(surface.commit(), leaves, Vector3.ZERO, parent)

func _flower(p: Node3D, base: Vector3, size: float, target: Node3D = null) -> void:
 var flower = Node3D.new()
 flower.name = "WildSunflower"
 flower.position = base
 flower.scale = Vector3.ONE * size
 (p.scenery_root if target == null else target).add_child(flower)
 var green = material(Color("278c3e"))
 Atmosphere.foliage(green)
 var parts = preload("res://scripts/decor/sunflower_meshes.gd")
 p.mesh_node(parts.get_part("stem"), green, Vector3(0, 0.185, 0), flower)
 p.mesh_node(parts.get_part("leaf"), green, Vector3(0.08, 0.15, 0), flower)
 var petals = material(Color("ffcf24"))
 for i: int in 8:
  var angle = float(i) * TAU / 8.0
  var petal = p.mesh_node(parts.get_part("petal"), petals, Vector3(cos(angle) * 0.115, 0.42 + sin(angle) * 0.115, 0), flower)
  petal.rotation.z = angle - PI * 0.5
 var heart = p.mesh_node(parts.get_part("center"), material(Color("6f3c25")), Vector3(0, 0.42, 0.02), flower)
 heart.rotation.x = PI * 0.5

func _rock(p: Node3D, base: Vector3, size: float) -> void:
 var mesh = SphereMesh.new()
 mesh.radius = size
 mesh.height = size * 1.4
 mesh.radial_segments = 6
 mesh.rings = 3
 var stone := material(Color("bbb595"))
 Atmosphere.color(stone, "rock_tint", "tint")
 var rock = p.mesh_node(mesh, stone, base + Vector3.UP * size * 0.45, p.scenery_root)
 rock.rotation.y = base.z * 0.7
 rock.scale = Vector3(1.15, 0.8, 0.85)

func _offshore_cliff(radius: float, height: float, taper: float, stretch: float) -> ArrayMesh:
 # Explicit side-only UVs avoid CylinderMesh's half-height side chart. Measure
 # each stretched facet at mid-height so all eight faces keep the same density.
 var outline := PackedVector3Array()
 var distances := PackedFloat32Array([0.0])
 for i in 9:
  var angle := TAU * float(i) / 8.0
  outline.append(Vector3(sin(angle) * radius, 0, cos(angle) * radius * stretch))
  if i > 0: distances.append(distances[-1] + outline[i - 1].distance_to(outline[i]) * (1.0 + taper) * 0.5)
 var fitted_length := maxf(1.0, roundf(distances[-1] / 0.64)) * 0.64
 var fit := fitted_length / distances[-1]
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 8:
  var a := outline[i]
  var b := outline[i + 1]
  var c := b * taper + Vector3.UP * height
  var d := a * taper + Vector3.UP * height
  var normal := (b - a).cross(d - a).normalized()
  var vertices := [a, d, c, a, c, b]
  var along := [distances[i], distances[i], distances[i + 1], distances[i], distances[i + 1], distances[i + 1]]
  for j in 6:
   surface.set_normal(normal)
   surface.set_uv(Vector2(along[j] * fit, 2.04 - vertices[j].y) / 0.64)
   surface.add_vertex(vertices[j])
 return surface.commit()

func build_background(p: Node3D) -> void:
 var water = PlaneMesh.new()
 water.size = Vector2(150, 150)
 var ocean := ShaderMaterial.new()
 ocean.shader = preload("res://scripts/themes/green_hill_ocean.gdshader")
 p.mesh_node(water, ocean, TablePresentation.map_point(p.table_bounds.get_center(), -2.3), p.scenery_root).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var sand = material(Color("dfc179"))
 var distant_green = material(Color("c4dcae"))
 var distant_dark = material(Color("a4caa8"))
 for turf: StandardMaterial3D in [distant_green, distant_dark]:
  turf.albedo_texture = _selected_texture("5B")
  turf.uv1_triplanar = true
  turf.uv1_world_triplanar = true
  turf.uv1_scale = Vector3.ONE * 0.38
 Atmosphere.color(sand, "shore_tint", "tint")
 Atmosphere.color(distant_green, "vegetation_tint", "tint")
 Atmosphere.color(distant_dark, "vegetation_tint", "tint")
 var distant_soil := material(Color("b5916f"))
 distant_soil.albedo_texture = _selected_texture("3A")
 Atmosphere.color(distant_soil, "shore_tint", "tint")
 var center = p.table_bounds.get_center() * TablePresentation.SCALE
 var decor := GreenHillDecor.new(p)
 # Four separated offshore silhouettes, rather than two matching cone stacks.
 # Different shelf heights and footprints retain broad stretches of open sea.
 for i: int in 4:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var side := -1 if i % 2 == 0 else 1
  var offset: float = [3.4, 4.0, 5.3, 5.8][i]
  var fraction: float = [0.43, 0.48, 0.67, 1.02][i]
  var radius: float = [1.8, 1.7, 1.5, 1.1][i]
  var height: float = [1.3, 0.7, 1.8, 0.95][i]
  var island := Node3D.new()
  island.name = "OffshoreBluff"
  island.position = Vector3(center.x + side * (p.table_bounds.size.x * TablePresentation.SCALE * 0.5 + offset), -2.2, (p.table_bounds.position.y + p.table_bounds.size.y * fraction) * TablePresentation.SCALE)
  var stretch := 0.70 + 0.18 * (i % 3)
  island.rotation.y = -0.25 + i * 0.34
  p.scenery_root.add_child(island)
  var shore = p.cylinder(radius * 1.12, 0.32)
  shore.radial_segments = 8
  p.mesh_node(shore, sand, Vector3.ZERO, island).scale.z = stretch
  var taper := 0.72 if i % 2 == 0 else 0.90
  p.mesh_node(_offshore_cliff(radius, height, taper, stretch), distant_soil, Vector3.UP * 0.16, island)
  var cap = p.cylinder(radius * taper * 1.03, 0.10)
  cap.radial_segments = 8
  p.mesh_node(cap, distant_green if i % 2 == 0 else distant_dark, Vector3.UP * (0.16 + height), island).scale.z = stretch
  # A few readable silhouettes give every island a destination. Stretch only
  # the land meshes, keeping palms, flowers and rocks in their original shapes.
  var top := height + 0.21
  var palm_size: float = [0.66, 0.48, 0.66, 0.54][i]
  var palm_front := 0.40 if i == 1 else 0.10
  _palm(p, Vector3(side * radius * 0.18, top, radius * stretch * palm_front), -side, palm_size, island)
  if i % 2 == 0:
   _palm(p, Vector3(-side * radius * 0.32, top, -radius * stretch * 0.18), side, 0.52, island)
  var rocks: Node3D = decor.factory.call("medium_rock" if i % 2 else "tall_rock")
  island.add_child(rocks)
  rocks.position = Vector3(-side * radius * 0.30, top, radius * stretch * 0.25)
  rocks.scale = Vector3.ONE * (0.60 if i == 3 else 0.72)
  rocks.rotation.y = i * 0.70
  _flower(p, Vector3(side * radius * 0.32, top, radius * stretch * 0.36), 0.95 if i == 1 else 0.70, island)
 # Soft clouds and distant green peaks give the lower camera a readable horizon.
 var cloud_material := ShaderMaterial.new()
 cloud_material.shader = preload("res://scripts/themes/green_hill_cloud.gdshader")
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
  "edge": _guard_material(), "support": material(Color("704322")), "accent": material(Color("ffe6a1"))}
