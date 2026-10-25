extends RefCounted
## Editor-only scatter. Returned generic slots use the normal save/render path.
const Slots = preload("res://scripts/act_editor/decor_slots.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const MAX_SLOTS := 400
const MAX_FREQUENCY := 500.0
const RADII := {"small": .25, "medium": .42, "large": .85, "landmark": 1.65}

static func is_scattered(slot: Dictionary) -> bool:
 return slot.get("placement_source", "") == "scatter" and slot.slot_type in ["small", "medium"]

static func radius(slot: Dictionary, cell_size: float) -> float:
 return float(RADII[slot.slot_type]) * float(slot.get("scale", 1.0)) * cell_size

static func fits(point: Vector2, clearance: float, terrain: Array, occupied: Array, cell_size: float) -> bool:
 if not Slots.supported_by_terrain(point, terrain, cell_size): return false
 for side in 16:
  if not Slots.supported_by_terrain(point + Vector2.from_angle(TAU * side / 16.0) * clearance, terrain, cell_size): return false
 for other: Dictionary in occupied:
  if point.distance_to(other.position) < clearance + radius(other, cell_size) + cell_size * .08: return false
 return true

static func generate(document: Resource, frequency: float, seed_value: int, small_percent: float = 75.0) -> Array:
 var result: Array = []
 if frequency <= 0: return result
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value
 var cell_size := float(document.cell_size)
 var terrain: Array = []
 for placement: Dictionary in document.placements:
  var points: PackedVector2Array = Shapes.transformed_points(placement)
  for i in points.size(): points[i] = (points[i] + Shapes.placement_position(placement)) * cell_size
  terrain.append({"points": points, "closed": Shapes.definition_for_placement(placement).closed})
 var occupied: Array = []
 var used_ids: Dictionary = {}
 for slot: Dictionary in document.decor_slots:
  if not is_scattered(slot):
   occupied.append(slot)
   used_ids[slot.slot_id] = true
 var candidates: Array[Vector2] = []
 # Jittered samples cover disconnected and curved terrain without favoring large
 # overlapping stamps. Bound the sampling work for unusually large custom Acts.
 # Dense requests search more candidate gaps instead of relaxing prop clearance.
 var sampling_density := clampf(frequency / 100.0, 1.0, MAX_FREQUENCY / 100.0)
 var step := maxf(.4 / sqrt(sampling_density), sqrt(float(document.grid_size.x) * document.grid_size.y / 25000.0))
 for y in ceili(document.grid_size.y / step):
  for x in ceili(document.grid_size.x / step):
   var point := Vector2((x + rng.randf()) * step, (y + rng.randf()) * step) * cell_size
   if document.terrain_bounds().has_point(point) and Slots.supported_by_terrain(point, terrain, cell_size): candidates.append(point)
 for i in range(candidates.size() - 1, 0, -1):
  var j := rng.randi_range(0, i)
  var swap := candidates[i]
  candidates[i] = candidates[j]
  candidates[j] = swap
 # Normalize the finer sampling so frequency still describes the same area density.
 var target := mini(MAX_SLOTS, roundi(candidates.size() * step * step / .16 * clampf(frequency, 0, MAX_FREQUENCY) / 400.0))
 var medium_count := roundi(target * (1.0 - clampf(small_percent, 0, 100) / 100.0))
 # Interleave sizes so crowded terrain cannot consume its whole budget on
 # one size before the other gets a chance to fit. The rounded quotas also
 # support all-small and all-medium mixes without special placement paths.
 var remaining := {"small": target - medium_count, "medium": medium_count}
 var cursor := {"small": 0, "medium": 0}
 for index in target:
  var medium_turn := floori(float((index + 1) * medium_count) / target) > floori(float(index * medium_count) / target)
  var type := "medium" if remaining.medium > 0 and (medium_turn or remaining.small == 0) else "small"
  if remaining[type] == 0: break
  var placed := false
  while cursor[type] < candidates.size():
   var point: Vector2 = candidates[cursor[type]]
   cursor[type] += 1
   var scale := rng.randf_range(.85, 1.15)
   if not fits(point, float(RADII[type]) * scale * cell_size, terrain, occupied, cell_size): continue
   var id := "scatter-%016x-%08x" % [seed_value, rng.randi()]
   while used_ids.has(id): id = "scatter-%016x-%08x" % [seed_value, rng.randi()]
   used_ids[id] = true
   var slot := {"slot_id": id, "slot_type": type,
    "placement_hint": "surface", "position": point, "rotation_degrees": rng.randf_range(0, 360),
    "variant_mode": "auto", "scale": scale, "placement_source": "scatter"}
   result.append(slot)
   occupied.append(slot)
   remaining[type] -= 1
   placed = true
   break
  if not placed:
   remaining[type] = 0
 return result
