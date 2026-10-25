extends TablePresentation
## Collisionless themed renderer shared by generated and authored playfields.
## All gameplay shapes, cameras, and animated anchors remain owned by TablePresentation.
const DecorSlots = preload("res://scripts/act_editor/decor_slots.gd")
const GreenHillTheme = preload("res://scripts/themes/green_hill_theme.gd")
var theme_definition: RefCounted = GreenHillTheme.new()
## Replace this skin with another DecorSkin to reuse an Act's generic slots.
var decor_skin: RefCounted
var decor_root: Node3D
var skipped_decor_slots := PackedStringArray()

var terrain_root: Node3D
var scenery_root: Node3D
var _grass: Material
var _cliff: Material
var _wall_grass: Material
var _wall_soil: Material
var _outlines: Array[PackedVector2Array] = []
## Primitive presentation unions and exact stored composites; physics stays untouched.
var authored_terrain_polygons: Array[PackedVector2Array] = []
var authored_composite_polygons: Array[PackedVector2Array] = []
var authored_open_paths: Array[PackedVector2Array] = []
var authored_floor_outline := PackedVector2Array()
const LAND_DEPTH := 1.45

func _clear_playfield_geometry() -> void:
 super._clear_playfield_geometry()
 _outlines.clear()
 authored_terrain_polygons.clear()
 authored_composite_polygons.clear()
 authored_open_paths.clear()
 authored_floor_outline.clear()
 decor_root = null
 skipped_decor_slots.clear()

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
 for terrain: Dictionary in runtime.terrain:
  var points: PackedVector2Array = terrain.points.duplicate()
  if terrain.get("shape_id", "") == "composite":
   # Explicit sculpting has already produced the authoritative final contour.
   # Do not union it again with nearby stamps or quantize smoothed vertices.
   authored_composite_polygons.append(points)
  elif terrain.closed:
   _outlines.append(points)
  else:
   authored_open_paths.append(points)
 authored_terrain_polygons = _merge_authored_land(_outlines)
 authored_terrain_polygons.append_array(authored_composite_polygons)
 # The deck runs beneath the outer walls, with no exterior rectangular shelf.
 # This is a visual footprint only; it never fills or alters physical geometry.
 var floor_bounds := Rect2(bounds.position, bounds.size - Vector2(0, cell_size * AuthoredActData.RED_GUTTER_CELLS))
 authored_floor_outline = _authored_floor_boundary(floor_bounds)
 var floor_root := Node3D.new()
 floor_root.name = "AuthoredPlayfieldFloor"
 terrain_root.add_child(floor_root)
 _make_land(authored_floor_outline, LAND_DEPTH, floor_root, 0.0, 0.0)
 var wall_side := terrain_side_material()
 var wall_top := terrain_top_material()
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
 _build_authored_decor(runtime, cell_size)

func _build_authored_decor(runtime: Dictionary, cell_size: float) -> void:
 if decor_skin == null: decor_skin = theme_definition.create_decor(self)
 decor_root = Node3D.new()
 decor_root.name = "AuthoredDecor"
 terrain_root.add_child(decor_root)
 skipped_decor_slots.clear()
 for slot: Dictionary in runtime.get("decor_slots", []):
  if not DecorSlots.supported_by_terrain(slot.position, runtime.terrain, cell_size):
   skipped_decor_slots.append(slot.slot_id)
   continue
  var prop: Node3D = decor_skin.instantiate_slot(runtime.get("decor_seed", ""), slot)
  if prop == null: continue
  decor_root.add_child(prop)
  prop.position = map_point(slot.position, RAIL_HEIGHT + RAIL_CAP_HEIGHT)
  # Canvas +Y maps to +Z. Clockwise canvas angles require negative world yaw.
  prop.rotation.y = -deg_to_rad(float(slot.rotation_degrees))
  prop.scale = Vector3.ONE * cell_size * SCALE * float(slot.get("scale", 1.0))

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

func _authored_floor_boundary(bounds: Rect2) -> PackedVector2Array:
 var rectangle := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
 var boundaries: Array[PackedVector2Array] = _outlines.duplicate()
 for path: PackedVector2Array in authored_open_paths:
  boundaries.append_array(Geometry2D.offset_polyline(path, authored_cell_size * 0.02, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND))
 # Join copies of every wall type for floor inference: a composite may continue
 # into ordinary stamps. Keep the authoritative obstacle contours untouched.
 boundaries.append_array(authored_composite_polygons)
 boundaries = _merge_authored_land(boundaries)
 var left: Array[PackedVector2Array] = []
 var right: Array[PackedVector2Array] = []
 var rows: Array[float] = [bounds.position.y, bounds.end.y]
 for polygon: PackedVector2Array in boundaries:
  var extent := Rect2(polygon[0], Vector2.ZERO)
  for point: Vector2 in polygon:
   extent = extent.expand(point)
  # Long connected side walls define a table envelope. Small interior obstacles
  # never pinch the floor, and loose/unbounded authoring drafts retain a full deck.
  if extent.size.y < bounds.size.y * 0.5:
   continue
  var on_left := extent.position.x < bounds.position.x + bounds.size.x * 0.3
  var on_right := extent.end.x > bounds.end.x - bounds.size.x * 0.3
  if on_left:
   left.append(polygon)
  if on_right:
   right.append(polygon)
  if on_left or on_right:
   for point: Vector2 in polygon:
    # Samples on both sides preserve horizontal steps without bridging notches.
    for offset: float in [-0.001, 0.0, 0.001]:
     var y := clampf(point.y + offset, bounds.position.y, bounds.end.y)
     if not rows.has(y): rows.append(y)
 if left.is_empty() or right.is_empty():
  return rectangle
 rows.sort()
 var left_edge := PackedVector2Array()
 var right_edge := PackedVector2Array()
 for y: float in rows:
  var low := _outer_wall_x(left, y, true)
  var high := _outer_wall_x(right, y, false)
  if not is_finite(low) or not is_finite(high) or low >= high:
   return rectangle # Incomplete side boundaries cannot define a reliable envelope.
  left_edge.append(Vector2(clampf(low, bounds.position.x, bounds.end.x), y))
  right_edge.append(Vector2(clampf(high, bounds.position.x, bounds.end.x), y))
 right_edge.reverse()
 left_edge.append_array(right_edge)
 if Geometry2D.triangulate_polygon(left_edge).is_empty():
  return rectangle
 return left_edge

func _outer_wall_x(polygons: Array[PackedVector2Array], y: float, left: bool) -> float:
 var result := INF if left else -INF
 for polygon: PackedVector2Array in polygons:
  for index: int in polygon.size():
   var a := polygon[index]
   var b := polygon[(index + 1) % polygon.size()]
   if y < minf(a.y, b.y) or y > maxf(a.y, b.y):
    continue
   var x := (minf(a.x, b.x) if left else maxf(a.x, b.x)) if is_equal_approx(a.y, b.y) else lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
   result = minf(result, x) if left else maxf(result, x)
 return result

func _initialize_terrain_skin() -> void:
 var old_floor := get_node_or_null("TableFloor")
 if old_floor != null:
  remove_child(old_floor)
  old_floor.free()
 _grass = theme_definition.floor_material
 _cliff = theme_definition.cliff_material
 terrain_root = Node3D.new()
 terrain_root.name = theme_definition.display_name.replace(" ", "") + "Terrain"
 add_child(terrain_root)
 scenery_root = Node3D.new()
 scenery_root.name = theme_definition.display_name.replace(" ", "") + "Scenery"
 add_child(scenery_root)

func _finish_terrain_skin() -> void:
 theme_definition.configure_environment(self)
 theme_definition.build_background(self)
 theme_definition.build_edges(self)
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
 var turf := material(theme_definition.edge_trim_color)
 for i: int in points.size():
  var a: Vector2 = points[i]
  var b: Vector2 = points[(i + 1) % points.size()]
  line(a, b, turf_width, top_height - turf_width, turf, parent)

func _boundary_at_y(y: float) -> Vector2:
 var low := INF
 var high := -INF
 var outlines: Array[PackedVector2Array] = _outlines
 if authored_mode:
  outlines = []
  outlines.append(authored_floor_outline)
 for outline: PackedVector2Array in outlines:
  for i: int in outline.size():
   var a: Vector2 = outline[i]
   var b: Vector2 = outline[(i + 1) % outline.size()]
   if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
    var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
    low = minf(low, x)
    high = maxf(high, x)
 return Vector2(low, high)


func set_theme_definition(definition: RefCounted) -> void:
 theme_definition = definition
 _grass = definition.floor_material
 _cliff = definition.cliff_material
 _wall_grass = definition.top_material
 _wall_soil = definition.side_material
 decor_skin = definition.create_decor(self)

func terrain_top_material() -> Material:
 _wall_grass = theme_definition.top_material
 return _wall_grass

func terrain_side_material() -> Material:
 _wall_soil = theme_definition.side_material
 return _wall_soil

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
 return theme_definition.material(color, glow)

func build_study(parent: Node3D, origin: Vector3) -> void:
 theme_definition.build_study(self, parent, origin)

# Compatibility hooks for the established Green Hill prop factory.
func _palm(base: Vector3, side: int, size: float, target: Node3D = null) -> void:
 if theme_definition.has_method("_palm"):
  theme_definition._palm(self, base, side, size, target)

func _flower(base: Vector3, size: float, target: Node3D = null) -> void:
 if theme_definition.has_method("_flower"):
  theme_definition._flower(self, base, size, target)
