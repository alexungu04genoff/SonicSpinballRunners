class_name ChunkData
extends Resource
## Grid units are 100 physics pixels. Chunks can translate or mirror, never rotate.
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

func map_point(point: Vector2) -> Vector2:
 var mapped := point
 if mirrored:
  mapped.x = grid_dimensions.x * 100.0 - mapped.x
 return mapped + Vector2(horizontal_shift_cells * 100.0, 0.0)
