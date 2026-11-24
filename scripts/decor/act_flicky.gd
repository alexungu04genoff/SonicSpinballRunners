extends "res://scripts/decor/island_flicky.gd"
## One collisionless visitor on a clear bank in the active Act.
const Scatter = preload("res://scripts/act_editor/decor_scatter.gd")
const VISIT_CHANCE := 0.75

static func choose_perch(document: Resource, runtime: Dictionary, offset: Vector2, rng: RandomNumberGenerator, pool: Array) -> Dictionary:
 if pool.is_empty() or rng.randf() >= VISIT_CHANCE: return {}
 var size := float(document.cell_size)
 var solids: Array = runtime.terrain.filter(func(t: Dictionary): return t.closed and t.points.size() >= 3)
 if solids.is_empty(): return {}
 var bounds: Rect2 = document.terrain_bounds().grow(-size * 0.25)
 var floor_outline: PackedVector2Array = runtime.get("floor_outline", PackedVector2Array())
 var hardware: Array[Rect2] = []
 for item: Dictionary in runtime.objects:
  var footprint := Rect2(item.position, Vector2.ZERO).grow(size * 0.55)
  var transform := Transform2D(deg_to_rad(item.rotation_degrees), item.position)
  for point in ActGameplayObjects.local_points(item, size): footprint = footprint.expand(transform * point)
  hardware.append(footprint.grow(size * 0.2))
 for attempt in 36:
  var points: PackedVector2Array = solids[rng.randi_range(0, solids.size() - 1)].points
  var i := rng.randi_range(0, points.size() - 1)
  var next := points[(i + 1) % points.size()]
  var normal := points[i].direction_to(next).orthogonal()
  if normal.is_zero_approx(): continue
  var edge := points[i].lerp(next, rng.randf_range(0.15, 0.85))
  if not Geometry2D.is_point_in_polygon(edge + normal * size * 0.16, points): normal = -normal
  var perch := edge + normal * size * 0.16
  if not bounds.has_point(perch - offset): continue
  # Leave enough solid ground for both feet and an exposed lane beside the bank.
  var supported := true
  for foot: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
   if not Geometry2D.is_point_in_polygon(perch + foot * size * 0.09, points):
    supported = false
    break
  if not supported: continue
  var lane := edge - normal * size * 0.32
  if not bounds.has_point(lane - offset): continue
  if not floor_outline.is_empty() and not Geometry2D.is_point_in_polygon(lane - offset, floor_outline): continue
  if solids.any(func(t: Dictionary): return Geometry2D.is_point_in_polygon(lane, t.points)): continue
  if perch.distance_to(Vector2(document.spawn_position) + offset) < size: continue
  if hardware.any(func(area: Rect2): return area.has_point(perch)): continue
  var crowded := false
  for slot: Dictionary in document.decor_slots:
   if (perch - offset).distance_to(slot.position) < Scatter.radius(slot, size) + size * 0.18:
    crowded = true
    break
  if not crowded:
   return {"perch": perch, "phase": rng.randf(), "yaw": rng.randf_range(-0.55, 0.55), "species": pool[rng.randi_range(0, pool.size() - 1)]}
 return {}

func enter(table: TablePresentation, state: Dictionary, cell_size: float) -> void:
 visible = not state.is_empty()
 if visible:
  position = table.map_point(state.perch, table.RAIL_HEIGHT + table.RAIL_CAP_HEIGHT)
  rotation.y = state.yaw
  scale = Vector3.ONE * cell_size * table.SCALE * 0.62
  phase = state.phase
  species = state.species
  bind_model()
  visible = rig != null
 set_process(visible)
