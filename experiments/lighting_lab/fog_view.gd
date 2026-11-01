extends RefCounted
## Native fog uses radial camera distance. Estimate the visible table's interval
## for authoring sliders without changing saved distances or runtime rendering.
static func table_distances(camera: Camera3D) -> Vector2:
 var size := camera.get_viewport().get_visible_rect().size
 var nearest := camera.far
 var farthest := camera.near
 var eye := camera.global_position
 for x: float in [0.0, 0.5, 1.0]:
  for y: float in [0.0, 0.5, 1.0]:
   var pixel := size * Vector2(x, y)
   var origin := camera.project_ray_origin(pixel)
   var direction := camera.project_ray_normal(pixel)
   if direction.y >= -0.0001: continue
   var travel := -origin.y / direction.y
   if travel < 0.0: continue
   var distance := clampf(eye.distance_to(origin + direction * travel), camera.near, camera.far)
   nearest = minf(nearest, distance)
   farthest = maxf(farthest, distance)
 # The camera's perpendicular foot is the radial minimum if it is in view.
 var foot := Vector3(eye.x, 0.0, eye.z)
 if not camera.is_position_behind(foot) and Rect2(Vector2.ZERO, size).has_point(camera.unproject_position(foot)):
  nearest = minf(nearest, absf(eye.y))
 if farthest < nearest: return Vector2(camera.near, camera.far)
 return Vector2(nearest, maxf(nearest + 0.01, farthest))
