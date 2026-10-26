extends RefCounted
## Ballistic paths and bumper estimates. Flippers use isolated production-physics probes.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Ball = preload("res://scripts/ball.gd")
const Profile = preload("res://data/balanced.tres")

static func shots(item: Dictionary, cell_size: float, resolved_stats: Dictionary = {}) -> Array[Dictionary]:
 # The editor defaults to base Sonic; callers can supply the same resolved
 # character/Chao stats used by gameplay without duplicating response formulas.
 var stats := PhysicsTuning.resolve(Profile, {}, []) if resolved_stats.is_empty() else resolved_stats
 var result: Array[Dictionary] = []
 var type: String = item.get("type", "")
 var angle := deg_to_rad(float(item.get("rotation_degrees", 0.0)))
 var radius := Objects.Dimensions.BALL_RADIUS_CELLS * cell_size
 if type in ["round_bumper", "triangle_bumper"]:
  var points := Objects.local_points(item, cell_size)
  var count := 12 if type == "round_bumper" else 3
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
 for shot: Dictionary in result: shot["gravity_scale"] = float(stats.gravity_scale)
 return result

static func trajectory(shot: Dictionary) -> PackedVector2Array:
 var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 700.0)) * float(shot.get("gravity_scale", Profile.gravity_scale))
 var velocity: Vector2 = shot.velocity
 var points: PackedVector2Array = shot.get("path_prefix", PackedVector2Array()).duplicate()
 # Return to the original contact height, including the measured follow-through.
 var end_height: float = shot.origin.y if points.is_empty() else points[0].y
 var discriminant: float = velocity.y * velocity.y + 2.0 * gravity * (end_height - shot.origin.y)
 var duration := maxf(0.01 if not points.is_empty() else 1.0, (-velocity.y + sqrt(maxf(0.0, discriminant))) / gravity) if gravity > 0.0 else 1.0
 for i in 81:
  var t := duration * i / 80.0
  points.append(shot.origin + velocity * t + Vector2.DOWN * 0.5 * gravity * t * t)
 return points
