extends "res://scripts/themes/themed_presentation.gd"
## A private staging viewport builds cold variants cooperatively. Terrain band
## triangulation runs on a resource-only worker; all scene nodes stay on main.
var baked_geometry: Dictionary = {}
var computed_jobs := 0
var reused_jobs := 0
var _job_counts := {}
var stage := "shared objects"
var _slice_start := 0
var max_slice_ms := 0.0
var _border_jobs: Array[Dictionary] = []
var _worker: Thread
var _land_jobs: Array[Dictionary] = []
const VisualDetail = preload("res://scripts/endless/visual_detail.gd")

func stream_checkpoint(force := false) -> void:
 var elapsed := Time.get_ticks_usec() - _slice_start
 if _slice_start > 0 and elapsed > 20000: print("ENDLESS_PREPARE_SLICE | ", stage, " ms=", elapsed / 1000.0)
 max_slice_ms = maxf(max_slice_ms, elapsed / 1000.0) if _slice_start > 0 else 0.0
 if force or elapsed >= 1000:
  await get_tree().process_frame
  _slice_start = Time.get_ticks_usec()

func _finish_terrain_skin() -> void:
 camera.far = maxf(camera.far, 180.0)

func prepare_act(runtime: Dictionary, bounds: Rect2, cell_size: float) -> void:
 authored_mode = true
 authored_cell_size = cell_size
 _build_shared([], [], bounds)
 set_process(false)
 await stream_checkpoint(true)
 await _moving_objects(runtime)
 _initialize_terrain_skin()
 for terrain: Dictionary in runtime.terrain:
  await stream_checkpoint()
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
 for i in authored_terrain_polygons.size():
  authored_terrain_polygons[i] = VisualDetail.contour(authored_terrain_polygons[i])
 # The deck runs beneath the outer walls, with no exterior rectangular shelf.
 # This is a visual footprint only; it never fills or alters physical geometry.
 var floor_bounds := Rect2(bounds.position, bounds.size - Vector2(0, cell_size * AuthoredActData.RED_GUTTER_CELLS))
 stage = "floor outline"
 authored_floor_outline = await _cached_job("footprint", _authored_floor_boundary.bind(floor_bounds))
 authored_floor_outline = VisualDetail.contour(authored_floor_outline)
 await stream_checkpoint()
 stage = "floor mesh"
 var floor_root := Node3D.new()
 floor_root.name = "AuthoredPlayfieldFloor"
 terrain_root.add_child(floor_root)
 _make_land(authored_floor_outline, LAND_DEPTH, floor_root, 0.0, 0.0)
 await _finish_land()
 await stream_checkpoint()
 stage = "wall meshes"
 var floor_obstacles: Array[PackedVector2Array] = authored_terrain_polygons.duplicate()
 var wall_side := terrain_side_material()
 var wall_top := terrain_top_material()
 for outline: PackedVector2Array in authored_terrain_polygons:
  await stream_checkpoint()
  var mesh: ArrayMesh = await _cached_job("wall", _prism.bind(outline, RAIL_HEIGHT + RAIL_CAP_HEIGHT, wall_side, wall_top))
  _bind_materials(mesh, [wall_top, wall_side])
  var obstacle := mesh_node(mesh, null, Vector3.ZERO, terrain_root)
  obstacle.name = "SolidTerrainObstacle"
  _add_border(outline, [], theme_definition.top_border_width, RAIL_HEIGHT + RAIL_CAP_HEIGHT, theme_definition.top_border_material, obstacle, "TopSurfaceBorder")
 for path: PackedVector2Array in authored_open_paths:
  await stream_checkpoint()
  # A narrow ribbon follows consecutive segments only. There is no final-to-first
  # segment and no filled interior, including for U-shaped or curved open walls.
  var rail := Node3D.new()
  rail.name = "OpenTerrainRail"
  terrain_root.add_child(rail)
  for ribbon: PackedVector2Array in Geometry2D.offset_polyline(path, cell_size * 0.02, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
   ribbon = VisualDetail.contour(ribbon)
   await stream_checkpoint()
   var mesh: ArrayMesh = await _cached_job("wall", _prism.bind(ribbon, RAIL_HEIGHT + RAIL_CAP_HEIGHT, wall_side, wall_top))
   _bind_materials(mesh, [wall_top, wall_side])
   mesh_node(mesh, null, Vector3.ZERO, rail)
   floor_obstacles.append(ribbon)
   # Thin open rails keep a center strip: cap width is at most a quarter of rail width.
   _add_border(ribbon, [], minf(theme_definition.top_border_width, cell_size * 0.01), RAIL_HEIGHT + RAIL_CAP_HEIGHT, theme_definition.top_border_material, rail, "TopSurfaceBorder")
 _add_border(authored_floor_outline, floor_obstacles, theme_definition.floor_border_width, 0.0, theme_definition.floor_border_material, floor_root, "FloorPathBorder")
 _finish_terrain_skin()
 stage = "decor"
 for slot: Dictionary in runtime.get("decor_slots", []):
  await stream_checkpoint()
  _build_authored_decor({"decor_slots": [slot], "decor_seed": runtime.decor_seed, "terrain": runtime.terrain}, cell_size)
  await stream_checkpoint()
 await _finish_borders()

func _moving_objects(runtime: Dictionary) -> void:
 var gold := material(Color("ffd568"), 0.08)
 var torus := TorusMesh.new()
 torus.inner_radius = ring_field.ring_radius * SCALE * 0.55
 torus.outer_radius = ring_field.ring_radius * SCALE
 torus.rings = 16
 torus.ring_segments = 8
 for trail: Dictionary in runtime.get("ring_trails", []):
  for point: Vector2 in preload("res://scripts/act_editor/ring_trails.gd").positions(trail):
   ring_visuals.append(mesh_node(torus, gold, map_point(point, ring_height())))
   await stream_checkpoint()
 for flipper: PlaygroundFlipper in runtime.flippers:
  var pivot := Node3D.new()
  pivot.position = map_point(flipper.position)
  pivot.rotation.y = -flipper.rotation
  add_child(pivot)
  var height_scale := flipper.radius / PlaygroundFlipper.RADIUS
  PinballModels.flipper(self, pivot, flipper.length * SCALE, flipper.radius * SCALE, height_scale, _pinball_materials)
  flipper_visuals.append(pivot)
  var retracted := Node3D.new()
  retracted.position = pivot.position
  add_child(retracted)
  _paddle(flipper.length * SCALE, flipper.radius * SCALE * 0.45, 0.02 * height_scale, 0.006, material(Color("82978d")), retracted)
  flipper_retracted_visuals.append(retracted)
  await stream_checkpoint()
 for item: Dictionary in runtime.objects:
  var single := {"objects": [item], "terrain": [], "cell_size": runtime.cell_size}
  if item.has("mechanic"):
   var mechanics_visual := preload("res://scripts/authored_act/mechanics_presentation.gd").new()
   add_child(mechanics_visual)
   await mechanics_visual.build(self, single)
  else:
   _build_authored_objects(single)
  await stream_checkpoint()

func _add_border(outline: PackedVector2Array, holes: Array[PackedVector2Array], width: float, height: float, mat: Material, parent: Node3D, label: String) -> void:
 if width <= 0 or mat == null: return
 _border_jobs.append({"outline": outline, "holes": holes.duplicate(), "width": width,
  "height": height, "material": mat, "parent": parent, "label": label})

func _finish_borders() -> void:
 await _finish_land()
 for job: Dictionary in _border_jobs:
  var mesh: ArrayMesh = await _cached_job("border", TerrainBorder.build.bind(job.outline, job.holes, job.width, job.height + 0.001, job.material))
  if mesh == null: continue
  _bind_materials(mesh, [job.material])
  var visual := mesh_node(mesh, null, Vector3.ZERO, job.parent)
  visual.name = job.label
  visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  # Match the optional authored Rooftop grass layers when the art branch has them.
  if theme_definition.get("material_maps") != null and theme_definition.theme_id == "rooftop_run":
   if job.material == theme_definition.floor_border_material and theme_definition.material_maps.has_method("grass_shells"):
    for shell_material: ShaderMaterial in theme_definition.material_maps.grass_shells():
     var shell := mesh_node(mesh, shell_material, Vector3.ZERO, job.parent)
     shell.name = job.label + "GrassLayer"
     shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  await stream_checkpoint()
 _border_jobs.clear()

func _exit_tree() -> void:
 if _worker != null: _worker.wait_to_finish()

func _cached_job(kind: String, job: Callable) -> Variant:
 var index: int = _job_counts.get(kind, 0)
 _job_counts[kind] = index + 1
 var key := "%s:%d" % [kind, index]
 if baked_geometry.has(key):
  reused_jobs += 1
  return baked_geometry[key]
 var result: Variant = await _resource_job(job)
 baked_geometry[key] = result
 computed_jobs += 1
 return result

func _bind_materials(mesh: ArrayMesh, materials: Array) -> void:
 for i in mini(mesh.get_surface_count(), materials.size()):
  if mesh.surface_get_material(i) != materials[i]: mesh.surface_set_material(i, materials[i])

func _resource_job(job: Callable) -> Variant:
 # These callbacks operate only on private polygon arrays and mesh resources.
 # The staging scene is not processing; no live scene/node APIs run on workers.
 _worker = Thread.new()
 _worker.start(job, Thread.PRIORITY_LOW)
 while _worker.is_alive(): await stream_checkpoint(true)
 var result: Variant = _worker.wait_to_finish()
 _worker = null
 return result

func _make_land(outline: PackedVector2Array, depth: float, parent: Node3D, top_height: float = 0.0, turf_width: float = 0.045) -> void:
 _land_jobs.append({"outline": outline, "depth": depth, "parent": parent, "height": top_height, "turf": turf_width})

func _finish_land() -> void:
 for job: Dictionary in _land_jobs:
  if theme_definition.theme_id == "casino_night" and theme_definition.has_method("set_facade_reference"):
   theme_definition.set_facade_reference(job.outline)
  var meshes: Array = await _cached_job("land", _land_meshes.bind(job.outline, job.depth, job.height))
  _bind_materials(meshes[0], [_grass])
  _bind_materials(meshes[1], [_cliff])
  var grass := mesh_node(meshes[0], null, Vector3.ZERO, job.parent)
  grass.name = "GrassCap"
  grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  mesh_node(meshes[1], null, Vector3.ZERO, job.parent).name = "CheckerCliff"
  if not authored_mode:
   _add_border(job.outline, [], theme_definition.floor_border_width, job.height, theme_definition.floor_border_material, job.parent, "FloorPathBorder")
  if job.turf > 0:
   var turf := material(theme_definition.edge_trim_color)
   for i in job.outline.size():
    line(job.outline[i], job.outline[(i + 1) % job.outline.size()], job.turf, job.height - job.turf, turf, job.parent)
    await stream_checkpoint()
 _land_jobs.clear()

func _land_meshes(outline: PackedVector2Array, depth: float, top_height: float) -> Array:
 var points := outline.duplicate()
 if Geometry2D.is_polygon_clockwise(points):
  points.reverse()
 if theme_definition.has_method("set_facade_reference"):
  theme_definition.set_facade_reference(points)
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(_grass)
 for index: int in Geometry2D.triangulate_polygon(points):
  var vertex := map_point(points[index], top_height - 0.003)
  surface.set_normal(Vector3.UP)
  surface.set_uv(Vector2(vertex.x, vertex.z))
  surface.add_vertex(vertex)
 var grass_mesh := surface.commit()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(_cliff)
 var distance := 0.0
 var green_hill_distances := PackedFloat32Array()
 if theme_definition.has_method("wall_distances"):
  green_hill_distances = theme_definition.wall_distances(points)
 for i: int in points.size():
  var a := map_point(points[i], top_height)
  var b := map_point(points[(i + 1) % points.size()], top_height)
  var segment := a.distance_to(b)
  var outward := Vector3((b - a).z, 0, -(b - a).x).normalized()
  var bottom_a := a - Vector3.UP * depth
  var bottom_b := b - Vector3.UP * depth
  var vertices: Array[Vector3] = [a, bottom_a, b, b, bottom_a, bottom_b]
  var coords: Array[Vector2] = [Vector2(distance, 0), Vector2(distance, depth), Vector2(distance + segment, 0), Vector2(distance + segment, 0), Vector2(distance, depth), Vector2(distance + segment, depth)]
  if not green_hill_distances.is_empty():
   for j in coords.size():
    coords[j].x = green_hill_distances[i + 1] if j == 2 or j == 3 or j == 5 else green_hill_distances[i]
  for j: int in vertices.size():
   surface.set_normal(outward)
   surface.set_uv(coords[j])
   surface.add_vertex(vertices[j])
  distance += segment
 return [grass_mesh, surface.commit()]
