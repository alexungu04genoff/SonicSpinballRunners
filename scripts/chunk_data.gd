class_name ChunkData
extends Resource
## Grid units are 100 physics pixels. Chunks can translate or mirror, never rotate.
const GRID_SIZE := 100.0
const RAIL_RADIUS := 12.0
@export var chunk_id: String = "section"
@export var title: String = "Section"
@export var grid_position: Vector2i = Vector2i.ZERO
@export var grid_dimensions: Vector2i = Vector2i(8, 7)
@export var top_connection: Rect2 = Rect2(55, 0, 690, 20)
@export var bottom_connection: Rect2 = Rect2(55, 680, 690, 20)
@export var mirrored: bool = false
@export var horizontal_shift_cells: int = 0
@export var rails: Array[PackedVector2Array] = []
@export var bumpers: Array[Dictionary] = []
@export var rings: PackedVector2Array = PackedVector2Array()
@export var markers: Dictionary = {}
@export var visual_attachment: Dictionary = {"theme": "practice", "height": 0.0}
## Closed navigable footprint and representative routes for coarse clearance validation.
@export var playfield_outline: PackedVector2Array = PackedVector2Array()
@export var navigation_probes: PackedVector2Array = PackedVector2Array()

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

func gameplay_descriptors() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for rail: PackedVector2Array in rails:
  for i in range(rail.size() - 1):
   result.append({"kind": "rail", "a": world_point(rail[i]), "b": world_point(rail[i + 1]), "radius": RAIL_RADIUS})
 for bumper: Dictionary in bumpers:
  var item := bumper.duplicate(true)
  item.position = world_point(bumper.position)
  if item.kind == "triangle":
   var points := PackedVector2Array()
   for point: Vector2 in item.points:
    points.append(Vector2(-point.x if mirrored else point.x, point.y))
   item.points = points
  result.append(item)
 for point: Vector2 in rings:
  result.append({"kind": "ring", "position": world_point(point)})
 return result
