extends "res://scripts/endless/endless_game.gd"
## Deterministic diagnostic course; the production streaming implementation is inherited.
var diagnostic_theme := "rooftop_run"
var next_theme := "chemical_plant"

func _source_paths() -> Array:
 var paths := Plan.PATHS.duplicate()
 # Both comparison modes load the identical canonical Act file and disk recipe.
 paths[2] = "res://data/acts/Authored/First Try Smooth Decor.tres"
 return paths

func _next_planned_zone(documents: Array) -> Array[Dictionary]:
 var zone: int = planner.sequence / 3
 var theme := diagnostic_theme if zone % 2 == 0 else next_theme
 var order := [2, 4, 3] if zone % 2 == 0 else [5, 6, 2]
 var result: Array[Dictionary] = []
 var variant := preload("res://scripts/atmosphere/variants.gd").new().choose(theme, 18, zone, "default")
 for id: int in order:
  var document: Resource = documents[id]
  var offset := Vector2.ZERO
  if planner.last_document != null: offset = Plan.aligned_offset(planner.last_document, planner.last_offset, document)
  result.append({"sequence": planner.sequence, "zone": zone, "act": planner.sequence % 3, "id": id,
   "theme": theme, "atmosphere": variant.duplicate(true), "offset": offset})
  planner.last_document = document
  planner.last_offset = offset
  planner.sequence += 1
 return result

func _build_presentation() -> void:
 super._build_presentation()
 # Match the normal single-Act Prototype camera, in this diagnostic subclass only.
 presentation.camera_settings.screen_target_y = 0.55
 presentation.set_camera_value("zoom", 1.3)
