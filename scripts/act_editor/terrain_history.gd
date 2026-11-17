extends RefCounted
## Authoring-only source history, independent of collision and bake fingerprints.
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const MAX_DEPTH := 16
const MAX_SOURCES := 4096

static func placement_transform(piece: Dictionary) -> Transform2D:
 # Sample the existing transform convention, including screen-axis mirrors.
 var sample := piece.duplicate()
 sample.shape_id = "composite"
 sample.outline = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
 var points := Shapes.transformed_points(sample)
 return Transform2D(points[1] - points[0], points[2] - points[0], Shapes.placement_position(piece) + points[0])

static func remember(piece: Dictionary, sources: Array) -> void:
 var saved := sources.duplicate(true)
 for source: Dictionary in saved: _trim(source, MAX_DEPTH - 1)
 piece["editor_sources"] = {"reference": placement_transform(piece), "sources": saved}

static func set_transform(piece: Dictionary, transform: Transform2D) -> void:
 piece.quarter_turns = 0
 piece.flip_h = false
 piece.flip_v = transform.determinant() < 0.0
 piece["terrain_scale"] = transform.x.length()
 piece["fine_rotation_degrees"] = rad_to_deg(transform.x.angle())
 Shapes.set_placement_position(piece, Vector2.ZERO)
 Shapes.set_placement_position(piece, transform.origin - placement_transform(piece).origin)

static func _trim(piece: Dictionary, depth: int) -> void:
 if depth == 0:
  piece.erase("editor_sources")
 elif piece.has("editor_sources"):
  for source: Dictionary in piece.editor_sources.sources: _trim(source, depth - 1)

static func validation_error(history: Variant, depth := 0) -> String:
 if not history is Dictionary or not history.get("reference") is Transform2D or not history.get("sources") is Array:
  return "Saved terrain sources need a transform and source array."
 var reference: Transform2D = history.reference
 if not reference.is_finite() or absf(reference.determinant()) < 0.000001:
  return "Saved terrain source transform is invalid."
 if depth >= MAX_DEPTH or history.sources.is_empty() or history.sources.size() > MAX_SOURCES:
  return "Saved terrain source history exceeds its limits."
 for source: Variant in history.sources:
  if not source is Dictionary or not source.get("shape_id") is String or not source.get("base_size") is Vector2i:
   return "Saved terrain source is malformed."
  if not source.get("anchor") is Vector2i or not source.get("quarter_turns") is int or source.quarter_turns < 0 or source.quarter_turns > 3 or not source.get("flip_h") is bool or not source.get("flip_v") is bool:
   return "Saved terrain source has invalid transform fields."
  var offset: Variant = source.get("offset", Vector2.ZERO)
  if not offset is Vector2 or not offset.is_finite(): return "Saved terrain source has an invalid offset."
  for key: String in ["terrain_scale", "fine_rotation_degrees"]:
   var value: Variant = source.get(key, 1.0 if key == "terrain_scale" else 0.0)
   if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(value): return "Saved terrain source has an invalid numeric transform."
  if float(source.get("terrain_scale", 1.0)) <= 0.0 or Shapes.definition_for_placement(source).is_empty(): return "Saved terrain source shape is invalid."
  if source.has("editor_sources"):
   var error := validation_error(source.editor_sources, depth + 1)
   if not error.is_empty(): return error
 return ""

static func restore(piece: Dictionary) -> Dictionary:
 if not piece.has("editor_sources"): return {"error": "This piece has no saved sources. Older composites can only use available session Undo."}
 var error := validation_error(piece.editor_sources)
 if not error.is_empty(): return {"error": error}
 var reference: Transform2D = piece.editor_sources.reference
 var mapping := placement_transform(piece) * reference.affine_inverse()
 var sources: Array = piece.editor_sources.sources.duplicate(true)
 # Preserve original records exactly if the composite has not been transformed.
 if placement_transform(piece) == reference: return {"error": "", "sources": sources}
 for source: Dictionary in sources:
  if Shapes.definition_for_placement(source).is_empty(): return {"error": "A saved source shape is unavailable."}
  var transformed := mapping * placement_transform(source)
  set_transform(source, transformed)
 return {"error": "", "sources": sources}
