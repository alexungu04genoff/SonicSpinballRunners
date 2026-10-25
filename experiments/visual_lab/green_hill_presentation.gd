extends TablePresentation
## Collisionless Green Hill skin shared by generated and authored playfields.
## All gameplay shapes, cameras, and animated anchors remain owned by TablePresentation.

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
 vec2 p = UV * 2.2;
 vec2 cell = floor(p);
 vec2 blend = fract(p);
 blend = blend * blend * (3.0 - 2.0 * blend);
 float noise = mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
 float stripe = step(0.55, fract((UV.x + UV.y * 0.35) * 0.42));
 ALBEDO = mix(vec3(0.22, 0.56, 0.045), vec3(0.27, 0.63, 0.065), noise * 0.45 + stripe * 0.11);
 ROUGHNESS = 1.0;
}
"""
const CLIFF_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
void fragment() {
 vec2 tile = floor(UV * 2.0);
 float checker = mod(tile.x + tile.y, 2.0);
 vec2 edge = min(fract(UV * 2.0), 1.0 - fract(UV * 2.0));
 float seam = smoothstep(0.0, 0.035, min(edge.x, edge.y));
 vec3 dark = vec3(0.30, 0.105, 0.035);
 vec3 light = vec3(0.62, 0.30, 0.09);
 ALBEDO = mix(dark, light, checker) * mix(0.88, 1.0, seam);
 ROUGHNESS = 1.0;
}
"""

var terrain_root: Node3D
var scenery_root: Node3D
var _grass: ShaderMaterial
var _cliff: ShaderMaterial
var _outlines: Array[PackedVector2Array] = []
## Presentation-only union; the compiler's collision polygons remain untouched.
var authored_terrain_polygons: Array[PackedVector2Array] = []
var authored_open_paths: Array[PackedVector2Array] = []
const LAND_DEPTH := 1.45

func _clear_playfield_geometry() -> void:
 super._clear_playfield_geometry()
 _outlines.clear()
 authored_terrain_polygons.clear()
 authored_open_paths.clear()

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

func build(chunks: Array[TableChunk], junctions: Variant = [], bounds: Rect2 = Rect2()) -> void:
 super.build(chunks, junctions, bounds)
 _initialize_terrain_skin()
 for chunk: TableChunk in chunks:
  var outline := chunk.data.world_polygon(chunk.data.playfield_outline)
  if outline.size() >= 3:
   _outlines.append(outline)
 # Union touching chunk footprints before extrusion so the seam stays continuous.
 var terrain_polygons: Array[PackedVector2Array] = []
 for outline: PackedVector2Array in _outlines:
  var candidate := outline
  var remaining: Array[PackedVector2Array] = []
  for existing: PackedVector2Array in terrain_polygons:
   var merged := Geometry2D.merge_polygons(candidate, existing)
   if merged.size() == 1:
    candidate = merged[0]
   else:
    remaining.append(existing)
  remaining.append(candidate)
  terrain_polygons = remaining
 for outline: PackedVector2Array in terrain_polygons:
  _make_land(outline, LAND_DEPTH, terrain_root)
 _finish_terrain_skin()

func build_authored(runtime: Dictionary, bounds: Rect2, cell_size: float) -> void:
 super.build_authored(runtime, bounds, cell_size)
 _initialize_terrain_skin()
 # Grass means playable floor in both sources. Authored stamps describe blocked
 # terrain, not the footprint of that floor. Keep the drain gutter uncovered.
 var floor_bounds := Rect2(bounds.position, bounds.size - Vector2(0, cell_size * AuthoredActData.RED_GUTTER_CELLS))
 var floor_outline := PackedVector2Array([floor_bounds.position, Vector2(floor_bounds.end.x, floor_bounds.position.y), floor_bounds.end, Vector2(floor_bounds.position.x, floor_bounds.end.y)])
 var floor_root := Node3D.new()
 floor_root.name = "AuthoredPlayfieldFloor"
 terrain_root.add_child(floor_root)
 _make_land(floor_outline, LAND_DEPTH, floor_root)
 for terrain: Dictionary in runtime.terrain:
  var points: PackedVector2Array = terrain.points.duplicate()
  if terrain.closed:
   _outlines.append(points)
  else:
   authored_open_paths.append(points)
 authored_terrain_polygons = _merge_authored_land(_outlines)
 var wall_side := material(RAIL_SIDE_COLOR)
 var wall_top := material(RAIL_TOP_COLOR)
 for outline: PackedVector2Array in authored_terrain_polygons:
  var obstacle := mesh_node(_prism(outline, RAIL_HEIGHT + RAIL_CAP_HEIGHT, wall_side, wall_top), null, Vector3.ZERO, terrain_root)
  obstacle.name = "SolidTerrainObstacle"
 for path: PackedVector2Array in authored_open_paths:
  # A narrow ribbon follows consecutive segments only. There is no final-to-first
  # segment and no filled interior, including for U-shaped or curved open walls.
  var rail := Node3D.new()
  rail.name = "OpenTerrainRail"
  terrain_root.add_child(rail)
  for ribbon: PackedVector2Array in Geometry2D.offset_polyline(path, cell_size * 0.02, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
   mesh_node(_prism(ribbon, RAIL_HEIGHT + RAIL_CAP_HEIGHT, wall_side, wall_top), null, Vector3.ZERO, rail)
 _finish_terrain_skin()

func _merge_authored_land(outlines: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
 var result: Array[PackedVector2Array] = []
 for outline: PackedVector2Array in outlines:
  var candidate := outline
  var index := 0
  while index < result.size():
   var merged := Geometry2D.merge_polygons(candidate, result[index])
   # Multiple contours may include holes. Keeping their original solids avoids
   # accidentally painting over those holes; only a single valid contour merges.
   if merged.size() == 1 and not Geometry2D.triangulate_polygon(merged[0]).is_empty():
    candidate = merged[0]
    result.remove_at(index)
    index = 0 # A union may now touch an earlier, previously separate solid.
   else:
    index += 1
  result.append(candidate)
 return result

func _initialize_terrain_skin() -> void:
 var old_floor := get_node_or_null("TableFloor")
 if old_floor != null:
  remove_child(old_floor)
  old_floor.free()
 _grass = _shader_material(GRASS_SHADER)
 _cliff = _shader_material(CLIFF_SHADER)
 terrain_root = Node3D.new()
 terrain_root.name = "GreenHillTerrain"
 add_child(terrain_root)
 scenery_root = Node3D.new()
 scenery_root.name = "GreenHillScenery"
 add_child(scenery_root)

func _finish_terrain_skin() -> void:
 _configure_daylight()
 _build_distant_landscape()
 _decorate_edges()
 camera.far = maxf(camera.far, 180.0)

func _floor_line(_a: Vector2, _b: Vector2, _mat: Material) -> void:
 # The procedural grass is the visual surface; the diagnostic overlay is unchanged.
 pass

func _label(text: String, point: Vector2, font_size: int, color: Color, parent: Node3D = self) -> void:
 if text == "DRAIN" or parent != self:
  super._label(text, point, font_size, color, parent)

func _configure_camera() -> void:
 super._configure_camera()
 camera.far = maxf(camera.far, 180.0)

func _shader_material(source: String) -> ShaderMaterial:
 var shader := Shader.new()
 shader.code = source
 var result := ShaderMaterial.new()
 result.shader = shader
 return result

func _configure_daylight() -> void:
 for child: Node in get_children():
  if child is WorldEnvironment:
   var world: Environment = child.environment
   var sky_material := ProceduralSkyMaterial.new()
   sky_material.sky_top_color = Color("168bdb")
   sky_material.sky_horizon_color = Color("bcecf0")
   sky_material.ground_bottom_color = Color("47bfc0")
   sky_material.ground_horizon_color = Color("bcecf0")
   sky_material.sky_curve = 0.22
   sky_material.sun_angle_max = 7.0
   var sky := Sky.new()
   sky.sky_material = sky_material
   world.background_mode = Environment.BG_SKY
   world.sky = sky
   world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
   world.ambient_light_color = Color("d3eeff")
   world.ambient_light_energy = 0.30
   world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
  elif child is DirectionalLight3D:
   child.rotation_degrees = Vector3(-55, -38, 0)
   child.light_color = Color("fff2cf")
   child.light_energy = 0.78
   child.shadow_normal_bias = 2.0

func _make_land(outline: PackedVector2Array, depth: float, parent: Node3D, top_height: float = 0.0, turf_width: float = 0.045) -> void:
 var points := outline.duplicate()
 if Geometry2D.is_polygon_clockwise(points):
  points.reverse()
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(_grass)
 for index: int in Geometry2D.triangulate_polygon(points):
  var vertex := map_point(points[index], top_height - 0.003)
  surface.set_normal(Vector3.UP)
  surface.set_uv(Vector2(vertex.x, vertex.z))
  surface.add_vertex(vertex)
 var grass_mesh := mesh_node(surface.commit(), null, Vector3.ZERO, parent)
 grass_mesh.name = "GrassCap"
 grass_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(_cliff)
 var distance := 0.0
 for i: int in points.size():
  var a := map_point(points[i], top_height)
  var b := map_point(points[(i + 1) % points.size()], top_height)
  var segment := a.distance_to(b)
  var outward := Vector3((b - a).z, 0, -(b - a).x).normalized()
  var bottom_a := a - Vector3.UP * depth
  var bottom_b := b - Vector3.UP * depth
  var vertices: Array[Vector3] = [a, bottom_a, b, b, bottom_a, bottom_b]
  var coords: Array[Vector2] = [Vector2(distance, 0), Vector2(distance, depth), Vector2(distance + segment, 0), Vector2(distance + segment, 0), Vector2(distance, depth), Vector2(distance + segment, depth)]
  for j: int in vertices.size():
   surface.set_normal(outward)
   surface.set_uv(coords[j])
   surface.add_vertex(vertices[j])
  distance += segment
 var cliff_mesh := mesh_node(surface.commit(), null, Vector3.ZERO, parent)
 cliff_mesh.name = "CheckerCliff"
 if turf_width <= 0.0:
  return # Authored silhouettes stop exactly at the physical polygon boundary.
 # A narrow, irregular turf lip makes the edge readable without covering any collider.
 var turf := material(Color("549c24"))
 for i: int in points.size():
  var a: Vector2 = points[i]
  var b: Vector2 = points[(i + 1) % points.size()]
  line(a, b, turf_width, top_height - turf_width, turf, parent)

func _boundary_at_y(y: float) -> Vector2:
 if authored_mode:
  # Decoration stays outside the Act, including empty spaces between authored solids.
  return Vector2(table_bounds.position.x, table_bounds.end.x)
 var low := INF
 var high := -INF
 for outline: PackedVector2Array in _outlines:
  for i: int in outline.size():
   var a: Vector2 = outline[i]
   var b: Vector2 = outline[(i + 1) % outline.size()]
   if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
    var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
    low = minf(low, x)
    high = maxf(high, x)
 return Vector2(low, high)

func _decorate_edges() -> void:
 var rows := maxi(3, int(table_bounds.size.y / 285.0))
 for row: int in rows:
  var y := table_bounds.position.y + 120.0 + row * 280.0
  if y > table_bounds.end.y - 190.0:
   continue
  var edge := _boundary_at_y(y)
  if not is_finite(edge.x):
   continue
  for side: int in [-1, 1]:
   var base_x := edge.x if side < 0 else edge.y
   var palm_here := (row + (1 if side > 0 else 0)) % 3 == 0
   var x := base_x + side * (100.0 if palm_here else 70.0)
   var center := Vector2(x, y + (25.0 if side > 0 else -25.0))
   _small_island(center, 62.0 if palm_here else 44.0, row)
   if palm_here:
    _palm(map_point(center), side, 1.0 + float(row % 2) * 0.13)
    _flower(map_point(center + Vector2(side * -18.0, 28.0)), 0.68)
   else:
    _flower(map_point(center + Vector2(-12, 5)), 0.8 + float(row % 2) * 0.15)
    _flower(map_point(center + Vector2(16, -11)), 0.58)
    _rock(map_point(center + Vector2(15, 20)), 0.16 + float(row % 3) * 0.035)

func _small_island(center: Vector2, radius: float, variation: int) -> void:
 var points := PackedVector2Array()
 for i: int in 10:
  var angle := float(i) * TAU / 10.0
  var modulation := 0.92 + 0.08 * sin(float(i * 7 + variation))
  points.append(center + Vector2(cos(angle), sin(angle)) * radius * modulation)
 _make_land(points, 1.0 + float(variation % 3) * 0.13, scenery_root)

func _palm(base: Vector3, side: int, size: float, target: Node3D = null) -> void:
 var palm := Node3D.new()
 palm.name = "ProceduralPalm"
 palm.position = base
 palm.scale = Vector3.ONE * size
 (scenery_root if target == null else target).add_child(palm)
 var bark := material(Color("b7863b"))
 var bark_light := material(Color("d6ad59"))
 var previous := Vector3.ZERO
 var tip := Vector3.ZERO
 for step: int in 7:
  var progress := float(step + 1) / 7.0
  tip = Vector3(side * progress * progress * 0.32, progress * 1.75, -0.10 * progress)
  var stem := cylinder(lerpf(0.12, 0.065, progress), previous.distance_to(tip))
  stem.radial_segments = 7
  var piece := mesh_node(stem, bark if step % 2 == 0 else bark_light, (previous + tip) * 0.5, palm)
  piece.quaternion = Quaternion(Vector3.UP, (tip - previous).normalized())
  previous = tip
 for leaf: int in 8:
  var angle := float(leaf) * TAU / 8.0 + 0.16
  _palm_frond(tip, angle, 1.10 + float(leaf % 3) * 0.09, leaf % 2 == 0, palm)
 var coconut := material(Color("704425"))
 for offset: Vector3 in [Vector3(-0.11, -0.07, 0), Vector3(0.10, -0.09, 0.06), Vector3(0, -0.12, -0.10)]:
  mesh_node(sphere(0.11), coconut, tip + offset, palm)

func _palm_frond(base: Vector3, angle: float, length: float, bright: bool, parent: Node3D) -> void:
 var direction := Vector3(cos(angle), 0, sin(angle))
 var sideways := Vector3(-sin(angle), 0, cos(angle))
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for segment: int in 5:
  var a := float(segment) / 5.0
  var b := float(segment + 1) / 5.0
  var center_a := base + direction * length * a + Vector3.UP * (sin(a * PI) * 0.33 - a * 0.42)
  var center_b := base + direction * length * b + Vector3.UP * (sin(b * PI) * 0.33 - b * 0.42)
  var width_a := sin(a * PI) * 0.24
  var width_b := sin(b * PI) * 0.24
  for sign_value: int in [-1, 1]:
   var outer_a := center_a + sideways * width_a * sign_value - Vector3.UP * width_a * 0.30
   var outer_b := center_b + sideways * width_b * sign_value - Vector3.UP * width_b * 0.30
   for vertex: Vector3 in [center_a, outer_a, center_b, center_b, outer_a, outer_b]:
    surface.set_normal(Vector3.UP)
    surface.add_vertex(vertex)
 var leaves := material(Color("62be30") if bright else Color("329a36"))
 leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
 mesh_node(surface.commit(), leaves, Vector3.ZERO, parent)

func _flower(base: Vector3, size: float, target: Node3D = null) -> void:
 var flower := Node3D.new()
 flower.name = "WildSunflower"
 flower.position = base
 flower.scale = Vector3.ONE * size
 (scenery_root if target == null else target).add_child(flower)
 var green := material(Color("278c3e"))
 mesh_node(cylinder(0.018, 0.37), green, Vector3(0, 0.185, 0), flower)
 var leaves := sphere(0.1)
 var leaf := mesh_node(leaves, green, Vector3(0.08, 0.15, 0), flower)
 leaf.scale = Vector3(1.2, 0.22, 0.55)
 leaf.rotation.z = 0.45
 var petals := material(Color("ffcf24"))
 for i: int in 8:
  var angle := float(i) * TAU / 8.0
  var petal := mesh_node(sphere(0.075), petals, Vector3(cos(angle) * 0.115, 0.42 + sin(angle) * 0.115, 0), flower)
  petal.scale = Vector3(0.7, 1.0, 0.35)
  petal.rotation.z = angle - PI * 0.5
 var heart := mesh_node(cylinder(0.082, 0.05), material(Color("6f3c25")), Vector3(0, 0.42, 0.02), flower)
 heart.rotation.x = PI * 0.5

func _rock(base: Vector3, size: float) -> void:
 var mesh := SphereMesh.new()
 mesh.radius = size
 mesh.height = size * 1.4
 mesh.radial_segments = 6
 mesh.rings = 3
 var rock := mesh_node(mesh, material(Color("bbb595")), base + Vector3.UP * size * 0.45, scenery_root)
 rock.rotation.y = base.z * 0.7
 rock.scale = Vector3(1.15, 0.8, 0.85)

func _build_distant_landscape() -> void:
 var water := PlaneMesh.new()
 water.size = Vector2(150, 150)
 var ocean := material(Color("24afc0"))
 ocean.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 mesh_node(water, ocean, map_point(table_bounds.get_center(), -2.3), scenery_root)
 var sand := material(Color("dfc179"))
 var distant_green := material(Color("77b64c"))
 var distant_dark := material(Color("408e5c"))
 var distant_stone := material(Color("66949b"))
 var center := table_bounds.get_center() * SCALE
 for side: int in [-1, 1]:
  for i: int in 6:
   var position := Vector3(center.x + side * (12.0 + float(i % 2) * 4.0), -1.7, center.y - 23.0 + float(i) * 8.0)
   var shore := cylinder(2.6 + float(i % 3) * 0.4, 0.5)
   shore.radial_segments = 9
   mesh_node(shore, sand, position, scenery_root)
   var mound := cylinder(2.35 + float(i % 3) * 0.4, 1.2)
   mound.top_radius = 1.5
   mound.radial_segments = 9
   mesh_node(mound, distant_green if i % 2 == 0 else distant_dark, position + Vector3.UP * 0.6, scenery_root)
   var peak_height := 1.8 + float(i % 3) * 0.65
   var peak := cylinder(0.95, peak_height)
   peak.top_radius = 0.32
   peak.radial_segments = 6
   var rock_peak := mesh_node(peak, distant_stone, position + Vector3(0, 1.0 + peak_height * 0.5, 0), scenery_root)
   rock_peak.rotation.z = side * 0.12
 # Soft clouds and distant green peaks give the lower camera a readable horizon.
 var cloud_material := material(Color("f5ffff"))
 cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 for i: int in 7:
  var cloud := Node3D.new()
  cloud.position = Vector3(center.x - 25.0 + float(i) * 8.0, 6.5 + float(i % 2) * 1.3, table_bounds.position.y * SCALE - 17.0 - float(i % 3) * 4.0)
  scenery_root.add_child(cloud)
  for j: int in 4:
   var puff := mesh_node(sphere(1.2 + float(j % 2) * 0.3), cloud_material, Vector3(float(j) * 1.1, float(j % 2) * 0.2, 0), cloud)
   puff.scale = Vector3(1.2, 0.58, 0.8)



func build_study(parent: Node3D, origin: Vector3) -> void:
 # A separate presentation-only diorama keeps close study clear of gameplay rails.
 parent.position = origin
 var outline := PackedVector2Array()
 for i: int in 24:
  outline.append(Vector2.from_angle(float(i) * TAU / 24.0) * 145.0)
 _make_land(outline, origin.y + 2.3, parent)
 _palm(Vector3(-0.95, 0, -0.85), -1, 0.78, parent)
 _palm(Vector3(1.03, 0, -0.80), 1, 0.70, parent)
 _flower(Vector3(-1.00, 0, 0.55), 0.85, parent)
 _flower(Vector3(-1.17, 0, 0.25), 0.60, parent)
 _flower(Vector3(1.08, 0, 0.34), 0.76, parent)
 _flower(Vector3(0.88, 0, 0.67), 0.56, parent)
