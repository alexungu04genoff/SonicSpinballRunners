class_name GridChunkRecipe
extends Resource
## The authoritative construction layout. Coordinates are 50-pixel grid units,
## independent of the existing 100-pixel chunk placement grid.
@export var recipe_id: String = "grid_relay"
@export var title: String = "GRID RELAY"
## Optional Zone composition intent; standalone recipes retain their original behavior.
@export var zone_role: String = ""
@export var shot_description: String = ""
@export var dimensions: Vector2i = Vector2i(14, 14)
@export_range(0.0, 100.0, 1.0) var estimated_difficulty: float = 28.0
## Inclusive rail-center endpoints on the top/bottom boundary, in grid units.
@export var top_span: Vector2i = Vector2i(1, 13)
@export var bottom_span: Vector2i = Vector2i(1, 13)
## Wall pieces name a left/right boundary chain. Objects need only an anchor cell.
@export var placements: Array[Dictionary] = []
@export var markers: Dictionary = {}
@export var navigation_cells: Array[Vector2i] = []
