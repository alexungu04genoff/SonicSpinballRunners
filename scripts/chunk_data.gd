class_name ChunkData
extends Resource
## Grid units are 100 physics pixels. Chunks can translate or mirror, never rotate.
const GRID_SIZE := 100.0
const RAIL_RADIUS := 12.0
const MOUNT_RADIUS := 18.0
const MOUNT_HALF_HEIGHT := 24.0
@export var chunk_id: String = "section"
@export var title: String = "Section"
@export var zone_role: String = ""
@export var shot_description: String = ""
## Provisional authored gameplay rating, independent of technical validity or character stats.
@export_range(0.0, 100.0, 1.0) var estimated_difficulty: float = 25.0
@export var grid_position: Vector2i = Vector2i.ZERO
@export var grid_dimensions: Vector2i = Vector2i(8, 7)
@export var top_connection: Rect2 = Rect2(55, 0, 690, 20)
@export var bottom_connection: Rect2 = Rect2(55, 680, 690, 20)
@export var mirrored: bool = false
@export var horizontal_shift_cells: int = 0
@export var rails: Array[PackedVector2Array] = []
## Retracted during upward entry, enabled only after this Act becomes a checkpoint.
@export var checkpoint_rails: Array[PackedVector2Array] = []
@export var bumpers: Array[Dictionary] = []
@export var rings: PackedVector2Array = PackedVector2Array()
@export var markers: Dictionary = {}
## Local pivot positions; side +1 is a left flipper and -1 is a right flipper.
## Optional length is the pivot-to-tip distance in physics pixels; legacy placements use 150.
@export var flipper_placements: Array[Dictionary] = []
@export var visual_attachment: Dictionary = {"theme": "practice", "height": 0.0}
## Closed navigable footprint and representative routes for coarse clearance validation.
@export var playfield_outline: PackedVector2Array = PackedVector2Array()
@export var navigation_probes: PackedVector2Array = PackedVector2Array()
## Optional construction recipe metadata; generated descriptors remain the runtime geometry.
@export var construction_grid: Dictionary = {}

func map_point(point: Vector2) -> Vector2:
 var mapped := point
 if mirrored:
  mapped.x = grid_dimensions.x * GRID_SIZE - mapped.x
 return mapped + Vector2(horizontal_shift_cells * GRID_SIZE, 0.0)

func world_point(point: Vector2) -> Vector2:
 return Vector2(grid_position) * GRID_SIZE + map_point(point)

func world_rect(rect: Rect2) -> Rect2:
 var a := world_point(rect.position)
 var b := world_point(rect.end)
 return Rect2(a.min(b), (b - a).abs())

func world_polygon(points: PackedVector2Array) -> PackedVector2Array:
 var result := PackedVector2Array()
 for point: Vector2 in points:
  result.append(world_point(point))
 return result

func world_flippers() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for placement: Dictionary in flipper_placements:
  var transformed := {"position": world_point(placement.position), "side": -float(placement.side) if mirrored else float(placement.side), "length": float(placement.get("length", PlaygroundFlipper.LENGTH))}
  if placement.get("checkpoint_only", false):
   transformed.checkpoint_only = true
  if placement.has("role"):
   transformed.role = placement.role
  if placement.get("wall_mount", false):
   transformed.wall_mount = true
  if placement.has("shot_target"):
   transformed.shot_target = world_point(placement.shot_target)
  if placement.has("shot_kind"):
   transformed.shot_kind = placement.shot_kind
  result.append(transformed)
 if flipper_placements.is_empty():
  for marker_name: String in ["left_flipper", "right_flipper"]:
   if markers.has(marker_name):
    var side := 1.0 if marker_name == "left_flipper" else -1.0
    result.append({"position": world_point(markers[marker_name]), "side": -side if mirrored else side, "length": PlaygroundFlipper.LENGTH})
 return result

func local_flipper_mounts() -> Array[Dictionary]:
 # Rebuild against the current boundary: connector collars can move it after
 # compilation. The compact bearing seals only the pivot against the wall;
 # placement validation prevents using it as an extension to a distant paddle.
 var result: Array[Dictionary] = []
 for index in flipper_placements.size():
  var paddle: Dictionary = flipper_placements[index]
  if not paddle.get("wall_mount", false):
   continue
  var side := 0 if paddle.side > 0 else 1
  if rails.size() <= side:
   continue
  var pivot: Vector2 = paddle.position
  var rear := PackedVector2Array()
  var rail: PackedVector2Array = rails[side]
  for y: float in [pivot.y - MOUNT_HALF_HEIGHT, pivot.y + MOUNT_HALF_HEIGHT]:
   for i in range(rail.size() - 1):
    var a := rail[i]
    var b := rail[i + 1]
    if y >= a.y and y <= b.y and b.y > a.y:
     rear.append(a.lerp(b, (y - a.y) / (b.y - a.y)))
     break
  if rear.size() != 2:
   continue # The compiler reports a missing or unsupported attachment.
  var hull_points := rear.duplicate()
  for point: Vector2 in rail:
   if point.y > rear[0].y and point.y < rear[1].y:
    hull_points.append(point)
  for step in 24:
   hull_points.append(pivot + Vector2.from_angle(step * TAU / 24.0) * MOUNT_RADIUS)
  var hull := Geometry2D.convex_hull(hull_points)
  hull.remove_at(hull.size() - 1) # Convex hull repeats its first vertex.
  for i in hull.size():
   hull[i] -= pivot
  result.append({"kind": "flipper_mount", "position": pivot, "points": hull,
   "wall_attachment": "left" if side == 0 else "right", "flipper_index": index, "rear_anchors": rear})
 return result

func gameplay_descriptors() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for rail: PackedVector2Array in rails:
  for i in range(rail.size() - 1):
   result.append({"kind": "rail", "a": world_point(rail[i]), "b": world_point(rail[i + 1]), "radius": RAIL_RADIUS})
 var solids := bumpers.duplicate()
 solids.append_array(local_flipper_mounts())
 for bumper: Dictionary in solids:
  var item := bumper.duplicate(true)
  item.position = world_point(bumper.position)
  if item.kind in ["triangle", "flipper_mount"]:
   var points := PackedVector2Array()
   for point: Vector2 in item.points:
    points.append(Vector2(-point.x if mirrored else point.x, point.y))
   item.points = points
  if item.kind == "flipper_mount":
   item.rear_anchors = world_polygon(item.rear_anchors)
   if mirrored:
    item.wall_attachment = "right" if item.wall_attachment == "left" else "left"
  result.append(item)
 for rail: PackedVector2Array in checkpoint_rails:
  for i in range(rail.size() - 1):
   result.append({"kind": "rail", "a": world_point(rail[i]), "b": world_point(rail[i + 1]), "radius": RAIL_RADIUS, "checkpoint_only": true})
 for point: Vector2 in rings:
  result.append({"kind": "ring", "position": world_point(point)})
 return result
