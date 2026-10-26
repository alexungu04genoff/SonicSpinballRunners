extends RefCounted
## Free-flight estimates only: no incoming tangential velocity, steering or collisions.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Flipper = preload("res://scripts/flipper.gd")
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
 if type in ["left_flipper", "right_flipper"]:
  var flipper := Flipper.new()
  flipper.side = 1.0 if type == "left_flipper" else -1.0
  flipper.authored_rest_angle = angle
  # Sample face contact across swing timing and heel-to-tip position. Native
  # collision velocity can exceed this stationary-ball assistance estimate.
  for timing in [0.0, 0.5, 1.0]:
   flipper.rotation = lerpf(flipper.rest_angle(), flipper.active_angle(), timing)
   for fraction in [0.0, 0.35, 0.65, 1.0]:
    var axis := Vector2.RIGHT.rotated(flipper.rotation)
    var normal := Vector2(axis.y, -axis.x) * flipper.side
    var origin: Vector2 = item.position + axis * Objects.Dimensions.FLIPPER_LENGTH_CELLS * cell_size * fraction
    origin += normal * (radius + Objects.Dimensions.FLIPPER_RADIUS_CELLS * cell_size)
    var velocity := Flipper.assisted_velocity(Vector2.ZERO, flipper.strike_direction(fraction), fraction, stats)
    velocity.y = maxf(velocity.y, -float(stats.flipper_upward_speed_limit) * sqrt(radius / Ball.RADIUS))
    result.append({"origin": origin, "velocity": velocity})
  flipper.free()
 elif type in ["round_bumper", "triangle_bumper"]:
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
 # End at launch height for upward shots; show one second for horizontal/downward shots.
 var duration := maxf(1.0, -2.0 * velocity.y / gravity) if gravity > 0.0 else 1.0
 var points := PackedVector2Array()
 for i in 81:
  var t := duration * i / 80.0
  points.append(shot.origin + velocity * t + Vector2.DOWN * 0.5 * gravity * t * t)
 return points
