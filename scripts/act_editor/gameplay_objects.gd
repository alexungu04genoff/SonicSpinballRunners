class_name ActGameplayObjects
extends RefCounted
## Shared authored object definitions, properties and collisionless silhouettes.
const RailPath = preload("res://scripts/authored_act/rail_path.gd")
const Dimensions = preload("res://scripts/act_dimensions.gd")
const FLIPPER_SWING_DEGREES := rad_to_deg(0.8)
const CURVE_STEPS := 24

static func definitions() -> Array[Dictionary]:
 return [
  {"id": "round_bumper", "label": "Round Bumper", "color": Color("53d5ed")},
  {"id": "triangle_bumper", "label": "Triangle Bumper / Sling", "color": Color("76cafa")},
  {"id": "left_flipper", "label": "Left Flipper", "color": Color("ffd76b")},
  {"id": "right_flipper", "label": "Right Flipper", "color": Color("ffd76b")},
  {"id": "one_way_gate", "label": "One-Way Gate", "color": Color("66e0b2")},
  {"id": "switch_target", "label": "Switch Target", "color": Color("599dff")},
  {"id": "spring", "label": "Spring", "color": Color("ff5968")},
  {"id": "spinner", "label": "Spinner", "color": Color("ffc76c")},
  {"id": "magnetic_field", "label": "Magnetic Field", "color": Color("ba8cff")},
  {"id": "elevated_rail", "label": "Elevated Ramp / Rail", "color": Color("6ee8dd")},
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
 return {"type": id, "position": Vector2.ZERO, "rotation_degrees": angle, "object_id": new_id(), "properties": defaults(id)}

static func local_points(placement: Dictionary, cell_size: float) -> PackedVector2Array:
 # Rotation is applied by the caller around the saved center/pivot at (0,0).
 # The sling keeps its origin relative to the original silhouette, without re-centering.
 var points := PackedVector2Array()
 match placement.get("type", ""):
  "spring":
   for step in 48:
    points.append(Vector2.from_angle(TAU * step / 48.0) * float(properties(placement).width) * 0.5)
  "spinner", "one_way_gate":
   var width := float(properties(placement).width)
   var depth := 4.0
   points = PackedVector2Array([Vector2(-width / 2, -depth), Vector2(width / 2, -depth), Vector2(width / 2, depth), Vector2(-width / 2, depth)])
  "switch_target":
   for step in 48:
    points.append(Vector2.from_angle(TAU * step / 48.0) * SWITCH_RADIUS)
  "magnetic_field":
   for step in 64:
    points.append(Vector2.from_angle(TAU * step / 64.0) * float(properties(placement).radius))
  "elevated_rail":
   points = RailPath.build(properties(placement).points).points
  "round_bumper":
   var radius := Dimensions.ROUND_RADIUS_CELLS * cell_size
   for step in range(CURVE_STEPS * 4):
    points.append(Vector2.RIGHT.rotated(TAU * float(step) / (CURVE_STEPS * 4)) * radius)
   points[0] = Vector2(radius, 0)
   points[CURVE_STEPS] = Vector2(0, radius)
   points[CURVE_STEPS * 2] = Vector2(-radius, 0)
   points[CURVE_STEPS * 3] = Vector2(0, -radius)
  "triangle_bumper":
   points = Dimensions.sling_points(cell_size)
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
 if placement.get("type") in ["round_bumper", "triangle_bumper"]:
  for i in points.size(): points[i] *= float(properties(placement).scale)
 return points

static func new_id() -> String:
 return "obj_" + Crypto.new().generate_random_bytes(12).hex_encode()

static func defaults(type: String) -> Dictionary:
 match type:
  "round_bumper", "triangle_bumper": return {"scale": 1.0}
  "one_way_gate": return {"width": 80.0, "initial_state": "closed", "visual_mode": "auto"}
  "switch_target": return {"color": "blue", "label": "", "score_reward": 0.0}
  "spring": return {"width": 40.0, "launch_strength": 900.0, "color": "red"}
  "spinner": return {"width": 40.0, "tick_score": 5.0, "decay": 2.0, "max_spin": 40.0}
  "magnetic_field": return {"radius": 100.0, "strength": 260.0, "mode": "attract"}
  "elevated_rail": return {"points": PackedVector2Array([Vector2.ZERO, Vector2(0, -100), Vector2(100, -170)]), "width": 40.0, "height": 40.0, "drag": 0.06, "entry_speed": 100.0}
 return {}

static func properties(placement: Dictionary) -> Dictionary:
 var result := defaults(str(placement.get("type", "")))
 result.merge(placement.get("properties", {}), true)
 return result

static func property_limits(type: String) -> Dictionary:
 match type:
  "round_bumper", "triangle_bumper": return {"scale": [0.35, 2.5]}
  "one_way_gate": return {"width": [20.0, 500.0]}
  "switch_target": return {"score_reward": [0.0, 1000.0]}
  "spring": return {"width": [20.0, 100.0], "launch_strength": [100.0, 2400.0]}
  "spinner": return {"width": [10.0, 300.0], "tick_score": [0.0, 25.0], "decay": [0.5, 8.0], "max_spin": [1.0, 60.0]}
  "magnetic_field": return {"radius": [15.0, 500.0], "strength": [0.0, 600.0]}
  "elevated_rail": return {"width": [18.0, 120.0], "height": [10.0, 200.0], "drag": [0.0, 1.0], "entry_speed": [30.0, 600.0]}
 return {}

static func property_errors(placement: Dictionary) -> PackedStringArray:
 var errors := PackedStringArray()
 if placement.has("object_id") and (typeof(placement.object_id) != TYPE_STRING or placement.object_id.is_empty()):
  errors.append("object_id must be a nonempty string.")
 if typeof(placement.get("properties", {})) != TYPE_DICTIONARY:
  errors.append("properties must be a dictionary.")
  return errors
 var values: Dictionary = placement.get("properties", {})
 var expected := defaults(str(placement.get("type", "")))
 var limits := property_limits(str(placement.get("type", "")))
 for key: Variant in values:
  if not expected.has(key):
   errors.append("Unknown property: " + str(key))
  elif limits.has(key):
   if typeof(values[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(values[key])) or float(values[key]) < limits[key][0] or float(values[key]) > limits[key][1]:
    errors.append(str(key) + " is outside its supported finite range.")
  elif key == "mode" and values[key] not in ["attract", "repel"]:
   errors.append("mode must be attract or repel.")
  elif key == "initial_state" and values[key] not in ["closed", "open"]:
   errors.append("initial_state must be closed or open.")
  elif key == "visual_mode" and values[key] != "auto":
   errors.append("visual_mode must be auto.")
  elif key == "color" and values[key] not in (["red", "yellow", "blue"] if placement.type == "spring" else ["blue", "red", "yellow", "green"]):
   errors.append("Unsupported color channel.")
  elif key == "label" and (typeof(values[key]) != TYPE_STRING or values[key].length() > 80):
   errors.append("Switch label must be a string of at most 80 characters.")
  elif key == "points":
   var error := RailPath.validation_error(values[key])
   if not error.is_empty(): errors.append(error)
 return errors

static func identity(item: Dictionary, index: int) -> String:
 return item.get("object_id", "legacy_" + var_to_bytes([index, item.get("type"), item.get("position"), item.get("rotation_degrees")]).hex_encode().sha256_text().left(24))

const SWITCH_RADIUS := 18.0
const COLORS := {"blue": Color("2689ff"), "red": Color("ff414c"), "yellow": Color("ffcf35"), "green": Color("40e99b")}

static func forward(item: Dictionary) -> Vector2:
 return Vector2.UP.rotated(deg_to_rad(float(item.rotation_degrees)))

static func spring_trajectory(item: Dictionary, gravity_scale: float, ball_radius: float = Dimensions.BALL_RADIUS_CELLS * 50.0) -> PackedVector2Array:
 var result := PackedVector2Array()
 var velocity := forward(item) * float(properties(item).launch_strength)
 var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 700.0)) * gravity_scale
 # Start at the forward edge of the pad. No steering, drag or collisions.
 var origin: Vector2 = item.position + forward(item) * (float(properties(item).width) * 0.5 + ball_radius)
 for i in 81:
  var t := float(i) / 40.0
  result.append(origin + velocity * t + Vector2.DOWN * gravity * t * t * 0.5)
 return result
