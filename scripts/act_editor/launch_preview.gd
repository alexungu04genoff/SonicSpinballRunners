extends RefCounted
## Ballistic paths and bumper estimates. Flippers use isolated production-physics probes.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Ball = preload("res://scripts/ball.gd")
const Profile = preload("res://data/balanced.tres")
const Mechanics = preload("res://scripts/authored_act/pinball_mechanics.gd")
const Enemies = preload("res://scripts/enemies/enemy_runtime.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const SAMPLE_SPEED := 300.0

static func description(type: String) -> String:
 return {"spring": "Fixed launch speed · forward-face contact",
  "terrain": "300 px/s contact · sample exposed edges · wall restitution",
  "slingshot": "Active rubber launch · back and ends rebound passively",
  "dash_panel": "300 px/s approach · authored boost, influence and speed cap",
  "teleporter": "300 px/s arrival · speed preserved along the exit arrow",
  "magnetic_field": "300 px/s flybys · gravity and the authored field force",
  "elevated_rail": "Entry at least 300 px/s · slope, height and drag · may roll back",
  "buzz_bomber": "300 px/s top contact · enemy bounce response",
  "diverter": "300 px/s contact · gold: state A / teal: state B",
  "one_way_gate": "300 px/s contact · blocked face only when closed",
  "spinner": "300 px/s pass-through · spinner does not deflect the ball",
  "switch_target": "300 px/s pass-through · switch does not deflect the ball",
  "wall_switch": "300 px/s pass-through · switch sensor; terrain supplies rebound",
  "drop_target_bank": "300 px/s contact · standing targets rebound, then drop",
  "lane_barrier": "300 px/s contact · solid posts; gaps allow passage"}.get(type,
  "Gold: minimum / teal: maximum rebound · representative contact normals")

static func shots(item: Dictionary, cell_size: float, resolved_stats: Dictionary = {}) -> Array[Dictionary]:
 # The editor defaults to base Sonic; callers can supply the same resolved
 # character/modifier stats used by gameplay without duplicating response formulas.
 var stats := PhysicsTuning.resolve(Profile, {}, []) if resolved_stats.is_empty() else resolved_stats
 var result: Array[Dictionary] = []
 var type: String = item.get("type", "")
 var angle := deg_to_rad(float(item.get("rotation_degrees", 0.0)))
 var radius := Objects.Dimensions.BALL_RADIUS_CELLS * cell_size
 if type == "terrain": return _terrain_shots(item.placement, cell_size, stats)
 if type in ["round_bumper", "triangle_bumper"]:
  var points := Objects.local_points(item, cell_size)
  var count := 8 if type == "round_bumper" else 3
  for i in count:
   var normal: Vector2
   var contact: Vector2
   if type == "round_bumper":
    normal = Vector2.UP.rotated(TAU * i / count)
    contact = normal * points[0].length()
   else:
    var a := points[i]
    var b := points[(i + 1) % 3]
    normal = Vector2((b - a).y, -(b - a).x).normalized().rotated(angle)
    contact = ((a + b) * 0.5).rotated(angle)
   for incoming in [0.0, 100000.0]:
    result.append({"origin": item.position + contact + normal * radius,
     "velocity": normal * Ball.bumper_rebound_speed(incoming, stats)})
 var props := Objects.properties(item)
 var facing := Objects.forward(item)
 var origin: Vector2 = item.position
 match type:
  "spring", "slingshot":
   var depth := float(props.width) * 0.5 if type == "spring" else 4.0
   var speed := float(props.launch_strength) if type == "spring" else float(props.strength)
   result.append({"origin": origin + facing * (depth + radius), "velocity": facing * speed})
  "dash_panel":
   for offset in [-0.45, 0.0, 0.45]:
    result.append({"origin": origin, "velocity": Objects.dash_velocity(facing.rotated(offset) * SAMPLE_SPEED, item)})
  "teleporter":
   result.append({"origin": Objects.teleporter_exit(item), "velocity": Objects.teleporter_direction(item) * SAMPLE_SPEED})
  "magnetic_field":
   var field := item.duplicate(true)
   field.properties = props
   for offset in [-0.6, 0.0, 0.6]:
    var at := origin + Vector2(-float(props.radius), float(props.radius) * offset)
    var velocity := Vector2.RIGHT * SAMPLE_SPEED
    var path := PackedVector2Array([at])
    var gravity := Vector2.DOWN * _gravity(stats)
    for step in 240:
     velocity += (gravity + Mechanics.magnetic_acceleration(field, at).limit_length(Mechanics.MAX_FIELD_ACCELERATION)) / 120.0
     at += velocity / 120.0
     if step % 3 == 2: path.append(at)
    result.append({"path": path})
  "elevated_rail":
   if props.points.size() >= 2: result.append(_rail_shot(item, stats))
  "buzz_bomber":
   var at := origin + Vector2.UP * (6.0 * float(props.scale) + radius)
   var velocity := Enemies.contact_velocity(Vector2.DOWN * SAMPLE_SPEED, at - Vector2.DOWN, at, origin, {"normal": Vector2.UP})
   result.append({"origin": at, "velocity": velocity})
  "diverter":
   for state in ["a", "b"]:
    var normal := Objects.diverter_forward(item, state)
    result.append(_rebound(origin + normal * (4.0 + radius), normal, stats, true))
  "one_way_gate":
   if props.initial_state == "closed": result.append(_rebound(origin + facing * (4.0 + radius), facing, stats, true))
   else: result.append({"origin": origin, "velocity": -facing * SAMPLE_SPEED})
  "drop_target_bank":
   var offsets := Objects.drop_positions(item)
   for index in [0, offsets.size() / 2, offsets.size() - 1]:
    result.append(_rebound(origin + offsets[index].rotated(angle) + facing * (4.0 + radius), facing, stats))
  "lane_barrier":
   var posts := Objects.world_posts(item)
   for index in [0, posts.size() - 1]:
    result.append(_rebound(posts[index] + Vector2.UP * (float(props.post_radius) + radius), Vector2.UP, stats))
  "spinner", "switch_target", "wall_switch":
   result.append({"origin": origin, "velocity": -facing * SAMPLE_SPEED})
 for shot: Dictionary in result: shot["gravity_scale"] = float(stats.gravity_scale)
 return result

static func _gravity(stats: Dictionary) -> float:
 return float(ProjectSettings.get_setting("physics/2d/default_gravity", 700.0)) * float(stats.gravity_scale)

static func _terrain_shots(placement: Dictionary, cell_size: float, stats: Dictionary) -> Array[Dictionary]:
 var points := Shapes.transformed_points(placement)
 var closed: bool = Shapes.definition_for_placement(placement).closed
 var area := 0.0
 for i in points.size(): area += points[i].cross(points[(i + 1) % points.size()])
 var edges: Array[Dictionary] = []
 for i in points.size() if closed else points.size() - 1:
  var a := points[i]
  var b := points[(i + 1) % points.size()]
  var edge := b - a
  if edge.length_squared() < 0.000001: continue
  var normal := Vector2(edge.y, -edge.x).normalized()
  if closed and area < 0.0: normal = -normal
  if not closed and normal.y > 0.0: normal = -normal
  if normal.y > 0.15: continue
  edges.append({"origin": ((a + b) * 0.5 + Shapes.placement_position(placement)) * cell_size + normal * Objects.Dimensions.BALL_RADIUS_CELLS * cell_size,
   "normal": normal, "length": edge.length() * maxf(0.2, -normal.y)})
 edges.sort_custom(func(a, b): return a.length > b.length)
 var result: Array[Dictionary] = []
 for edge: Dictionary in edges.slice(0, 3):
  var shot := _rebound(edge.origin, edge.normal, stats, true)
  shot.gravity_scale = float(stats.gravity_scale)
  result.append(shot)
 return result

static func _rebound(origin: Vector2, normal: Vector2, stats: Dictionary, preserve_tangent := false) -> Dictionary:
 var incoming := -normal.rotated(0.3) * SAMPLE_SPEED
 var restitution := float(stats.wall_restitution)
 var velocity := incoming - normal * incoming.dot(normal) * (1.0 + restitution) if preserve_tangent else incoming.bounce(normal) * restitution
 return {"origin": origin, "velocity": velocity}

static func _rail_shot(item: Dictionary, stats: Dictionary) -> Dictionary:
 var props := Objects.properties(item)
 var path := Objects.RailPath.build(props.points)
 var angle := deg_to_rad(float(item.rotation_degrees))
 # Match the runtime's fixed-step rail integration in world coordinates.
 for i in path.points.size(): path.points[i] = Vector2(item.position) + path.points[i].rotated(angle)
 var progress := 0.0
 var speed := maxf(SAMPLE_SPEED, float(props.entry_speed))
 var trace := PackedVector2Array([path.points[0]])
 for step in 1800:
  var tangent := Objects.RailPath.tangent(path, progress)
  var rise := Objects.RailPath.height(path, progress + 0.5, props.height) - Objects.RailPath.height(path, progress - 0.5, props.height)
  var metric := sqrt(1.0 + rise * rise)
  var acceleration := _gravity(stats) * (tangent.y - rise) / metric if step <= 1440 else -180.0
  speed = clampf((speed + acceleration / 120.0) * exp(-float(props.drag) / 120.0), -2400.0, 2400.0)
  progress += speed / (120.0 * metric)
  var finished: bool = progress >= path.length or (progress <= 0.0 and speed < 0.0)
  progress = clampf(progress, 0.0, path.length)
  var at := Objects.RailPath.sample(path, progress)
  if step % 4 == 0 or finished: trace.append(at)
  if finished:
   return {"origin": at, "velocity": Objects.RailPath.tangent(path, progress) * speed, "path_prefix": trace, "duration": 1.5}
 return {"path": trace}

static func trajectory(shot: Dictionary) -> PackedVector2Array:
 if shot.has("path"): return shot.path.duplicate()
 var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 700.0)) * float(shot.get("gravity_scale", Profile.gravity_scale))
 var velocity: Vector2 = shot.velocity
 var points: PackedVector2Array = shot.get("path_prefix", PackedVector2Array()).duplicate()
 # Return to the original contact height, including the measured follow-through.
 var end_height: float = shot.origin.y if points.is_empty() else points[0].y
 var discriminant: float = velocity.y * velocity.y + 2.0 * gravity * (end_height - shot.origin.y)
 var duration := maxf(0.01 if not points.is_empty() else 1.0, (-velocity.y + sqrt(maxf(0.0, discriminant))) / gravity) if gravity > 0.0 else 1.0
 duration = float(shot.get("duration", duration))
 for i in 81:
  var t := duration * i / 80.0
  points.append(shot.origin + velocity * t + Vector2.DOWN * 0.5 * gravity * t * t)
 return points
