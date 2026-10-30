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
  {"id": "wall_switch", "label": "Wall Switch", "color": Color("599dff")},
  {"id": "spring", "label": "Spring", "color": Color("ff5968")},
  {"id": "spinner", "label": "Spinner", "color": Color("ffc76c")},
  {"id": "magnetic_field", "label": "Magnetic Field", "color": Color("ba8cff")},
  {"id": "elevated_rail", "label": "Elevated Ramp / Rail", "color": Color("6ee8dd")},
  {"id": "lane_barrier", "label": "Lane Barrier", "color": Color("66efd1")},
  {"id": "diverter", "label": "Diverter", "color": Color("f3b669")},
  {"id": "dash_panel", "label": "Dash Panel", "color": Color("56eaff")},
  {"id": "buzz_bomber", "label": "Enemy · Buzz Bomber", "color": Color("ffd548")},
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
  "buzz_bomber":
   var size_value := float(properties(placement).scale)
   for step in 32:
    points.append(Vector2(cos(TAU * step / 32.0) * 12.0, sin(TAU * step / 32.0) * 6.0) * size_value)
  "spring":
   for step in 48:
    points.append(Vector2.from_angle(TAU * step / 48.0) * float(properties(placement).width) * 0.5)
  "spinner", "one_way_gate":
   var width := float(properties(placement).width)
   var depth := 4.0
   points = PackedVector2Array([Vector2(-width / 2, -depth), Vector2(width / 2, -depth), Vector2(width / 2, depth), Vector2(-width / 2, depth)])
  "switch_target":
   for step in 48:
    points.append(Vector2.from_angle(TAU * step / 48.0) * switch_radius(placement))
  "wall_switch":
   var radius := switch_radius(placement)
   points = PackedVector2Array([Vector2(-radius, -4), Vector2(radius, -4), Vector2(radius, 0), Vector2(-radius, 0)])
  "lane_barrier":
   points = properties(placement).points.duplicate()
  "diverter":
   var props := properties(placement)
   var angle := deg_to_rad(float(props.state_a_angle if props.initial_state == "a" else props.state_b_angle))
   for point: Vector2 in [Vector2(-props.length / 2, -4), Vector2(props.length / 2, -4), Vector2(props.length / 2, 4), Vector2(-props.length / 2, 4)]:
    points.append(point.rotated(angle))
  "dash_panel":
   var width := float(properties(placement).width)
   points = PackedVector2Array([Vector2(-width / 2, -18), Vector2(width / 2, -18), Vector2(width / 2, 18), Vector2(-width / 2, 18)])
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
  "buzz_bomber": return {"scale": 1.0, "patrol_speed": 65.0, "starting_direction": "right", "patrol_left": -60.0, "patrol_right": 60.0}
  "round_bumper", "triangle_bumper": return {"scale": 1.0}
  "one_way_gate": return {"width": 80.0, "initial_state": "closed", "visual_mode": "auto"}
  "switch_target", "wall_switch": return {"scale": 1.0, "color": "blue", "label": "", "score_reward": 0.0}
  "lane_barrier": return {"points": PackedVector2Array([Vector2.ZERO, Vector2(80, 0)]), "post_radius": 9.0, "reward_type": "score", "lane_reward": 100.0, "completion_mode": "light_all", "completion_bonus": 500.0, "reset_delay": 1.5}
  "diverter": return {"length": 90.0, "state_a_angle": -35.0, "state_b_angle": 35.0, "initial_state": "a"}
  "dash_panel": return {"width": 50.0, "boost_strength": 350.0, "directional_influence": 70.0, "speed_cap": 2400.0}
  "spring": return {"width": 40.0, "launch_strength": 300.0, "color": "red"}
  "spinner": return {"width": 40.0, "tick_score": 5.0, "decay": 2.0, "max_spin": 40.0, "completion_enabled": true, "target_ticks": 10.0, "completion_bonus": 300.0}
  "magnetic_field": return {"radius": 100.0, "strength": 260.0, "mode": "attract"}
  "elevated_rail": return {"points": PackedVector2Array([Vector2.ZERO, Vector2(0, -100), Vector2(100, -170)]), "width": 40.0, "height": 40.0, "drag": 0.06, "entry_speed": 100.0, "rings_enabled": true, "ring_spacing": 25.0}
 return {}

static func properties(placement: Dictionary) -> Dictionary:
 var result := defaults(str(placement.get("type", "")))
 result.merge(placement.get("properties", {}), true)
 return result

static func property_limits(type: String) -> Dictionary:
 match type:
  "buzz_bomber": return {"scale": [0.35, 2.5], "patrol_speed": [0.0, 400.0], "patrol_left": [-2000.0, 0.0], "patrol_right": [0.0, 2000.0]}
  "round_bumper", "triangle_bumper": return {"scale": [0.35, 2.5]}
  "one_way_gate": return {"width": [20.0, 500.0]}
  "switch_target", "wall_switch": return {"scale": [0.35, 2.5], "score_reward": [0.0, 1000.0]}
  "lane_barrier": return {"post_radius": [5.0, 25.0], "lane_reward": [0.0, 1000.0], "completion_bonus": [0.0, 100000.0], "reset_delay": [0.2, 10.0]}
  "diverter": return {"length": [24.0, 400.0], "state_a_angle": [-180.0, 180.0], "state_b_angle": [-180.0, 180.0]}
  "dash_panel": return {"width": [40.0, 200.0], "boost_strength": [0.0, 2400.0], "directional_influence": [0.0, 100.0], "speed_cap": [100.0, 3000.0]}
  "spring": return {"width": [20.0, 100.0], "launch_strength": [100.0, 2400.0]}
  "spinner": return {"width": [10.0, 300.0], "tick_score": [0.0, 25.0], "decay": [0.5, 8.0], "max_spin": [1.0, 60.0], "target_ticks": [1.0, 1000.0], "completion_bonus": [0.0, 100000.0]}
  "magnetic_field": return {"radius": [15.0, 500.0], "strength": [0.0, 600.0]}
  "elevated_rail": return {"width": [18.0, 120.0], "height": [10.0, 200.0], "drag": [0.0, 1.0], "entry_speed": [30.0, 600.0], "ring_spacing": [12.0, 200.0]}
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
   elif key == "target_ticks" and float(values[key]) != floorf(float(values[key])):
    errors.append("Spinner target ticks must be a whole number.")
  elif key in ["completion_enabled", "rings_enabled"] and typeof(values[key]) != TYPE_BOOL:
   errors.append("Enable flags must be boolean.")
  elif key == "starting_direction" and values[key] not in ["left", "right"]:
   errors.append("Starting direction must be left or right.")
  elif key == "mode" and values[key] not in ["attract", "repel"]:
   errors.append("mode must be attract or repel.")
  elif key == "initial_state" and values[key] not in (["a", "b"] if placement.type == "diverter" else ["closed", "open"]):
   errors.append("Unsupported initial state.")
  elif key == "reward_type" and values[key] not in ["score", "rings"]:
   errors.append("Reward type must be score or rings.")
  elif key == "completion_mode" and values[key] not in ["off", "light_all"]:
   errors.append("Completion mode must be off or light_all.")
  elif key == "visual_mode" and values[key] != "auto":
   errors.append("visual_mode must be auto.")
  elif key == "color" and values[key] not in (["red", "yellow", "blue"] if placement.type == "spring" else ["blue", "red", "yellow", "green"]):
   errors.append("Unsupported color channel.")
  elif key == "label" and (typeof(values[key]) != TYPE_STRING or values[key].length() > 80):
   errors.append("Switch label must be a string of at most 80 characters.")
  elif key == "points":
   var radius: Variant = properties(placement).get("post_radius", 9.0)
   var safe_radius := float(radius) if typeof(radius) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(radius)) else 9.0
   var error := lane_points_error(values[key], safe_radius) if placement.type == "lane_barrier" else RailPath.validation_error(values[key])
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

static func switch_radius(item: Dictionary) -> float:
 return SWITCH_RADIUS * float(properties(item).scale)

const MAX_POSTS := 12

static func lane_points_error(points: Variant, radius: float) -> String:
 if not points is PackedVector2Array or points.size() < 2 or points.size() > MAX_POSTS:
  return "Lane Barrier needs 2–12 ordered post positions."
 for i in points.size():
  if not points[i].is_finite() or points[i].length() > 20000.0: return "Post positions must be finite and within 20000 pixels."
  for j in i:
   if points[i].distance_to(points[j]) <= radius * 2.0 + 2.0: return "Barrier posts must not overlap."
 return ""

static func world_posts(item: Dictionary) -> PackedVector2Array:
 var result: PackedVector2Array = properties(item).points.duplicate()
 for i in result.size(): result[i] = Vector2(item.position) + result[i].rotated(deg_to_rad(float(item.rotation_degrees)))
 return result

static func diverter_forward(item: Dictionary, state: String) -> Vector2:
 var props := properties(item)
 return forward(item).rotated(deg_to_rad(float(props.state_a_angle if state == "a" else props.state_b_angle)))

static func dash_velocity(incoming: Vector2, item: Dictionary) -> Vector2:
 var props := properties(item)
 var facing := forward(item)
 var direction := incoming.normalized() if incoming.length_squared() > 0.0001 else facing
 # Rotate on the unit circle: opposite directions never cancel into a zero vector.
 direction = facing if float(props.directional_influence) >= 100.0 else direction.rotated(direction.angle_to(facing) * float(props.directional_influence) / 100.0)
 return direction * minf(incoming.length() + float(props.boost_strength), float(props.speed_cap))
