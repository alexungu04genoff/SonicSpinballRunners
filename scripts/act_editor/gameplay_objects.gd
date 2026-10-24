class_name ActGameplayObjects
extends RefCounted
## Editor-only silhouettes in local pixels. No bodies or gameplay scripts.
const Dimensions = preload("res://scripts/act_editor/preview_dimensions.gd")
const FLIPPER_SWING_DEGREES := rad_to_deg(0.8)
const CURVE_STEPS := 24

static func definitions() -> Array[Dictionary]:
 return [
  {"id": "round_bumper", "label": "Round Bumper", "color": Color("53d5ed")},
  {"id": "triangle_bumper", "label": "Triangle Bumper / Sling", "color": Color("76cafa")},
  {"id": "left_flipper", "label": "Left Flipper", "color": Color("ffd76b")},
  {"id": "right_flipper", "label": "Right Flipper", "color": Color("ffd76b")},
 ]

static func get_definition(id: String) -> Dictionary:
 for definition: Dictionary in definitions():
  if definition.id == id:
   return definition
 return {}

static func make_placement(id: String) -> Dictionary:
 if get_definition(id).is_empty():
  return {}
 var angle := 0.0
 if id == "left_flipper":
  angle = rad_to_deg(0.32)
 elif id == "right_flipper":
  angle = rad_to_deg(PI - 0.32)
 return {"type": id, "position": Vector2.ZERO, "rotation_degrees": angle}

static func local_points(placement: Dictionary, cell_size: float) -> PackedVector2Array:
 # Rotation is applied by the caller around the saved center/pivot at (0,0).
 # The sling keeps its origin relative to the original silhouette, without re-centering.
 var points := PackedVector2Array()
 match placement.get("type", ""):
  "round_bumper":
   var radius := Dimensions.ROUND_RADIUS_CELLS * cell_size
   for step in range(CURVE_STEPS * 4):
    points.append(Vector2.RIGHT.rotated(TAU * float(step) / (CURVE_STEPS * 4)) * radius)
   points[0] = Vector2(radius, 0)
   points[CURVE_STEPS] = Vector2(0, radius)
   points[CURVE_STEPS * 2] = Vector2(-radius, 0)
   points[CURVE_STEPS * 3] = Vector2(0, -radius)
  "triangle_bumper":
   # Uniformly scale the original 90-pixel-tall triangle about its authored origin.
   var scale_factor := Dimensions.SLING_HEIGHT_CELLS * cell_size / 90.0
   for point: Vector2 in [Vector2(-40, 35), Vector2(-15, -55), Vector2(45, 35)]:
    points.append(point * scale_factor)
  "left_flipper", "right_flipper":
   # The paddle is a capsule around the pivot-to-tip centerline.
   # Both hands share this unrotated body; rest angle and swing sign differ.
   var length := Dimensions.FLIPPER_LENGTH_CELLS * cell_size
   var radius := Dimensions.FLIPPER_RADIUS_CELLS * cell_size
   for step in range(CURVE_STEPS * 2 + 1):
    var angle := PI * 0.5 + PI * float(step) / (CURVE_STEPS * 2)
    points.append(Vector2.RIGHT.rotated(angle) * radius)
   for step in range(CURVE_STEPS * 2 + 1):
    var angle := -PI * 0.5 + PI * float(step) / (CURVE_STEPS * 2)
    points.append(Vector2(length, 0) + Vector2.RIGHT.rotated(angle) * radius)
 return points
