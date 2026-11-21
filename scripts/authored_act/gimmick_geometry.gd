extends RefCounted
## Continuous 2D circle/segment contact queries. Independent of meshes and themes.

static func circle_hit(start: Vector2, motion: Vector2, center: Vector2, radius: float) -> Dictionary:
 var offset := start - center
 if offset.length_squared() <= radius * radius:
  return {"fraction": 0.0, "normal": offset.normalized() if not offset.is_zero_approx() else -motion.normalized()}
 var a := motion.length_squared()
 if a < 0.00000001: return {}
 var b := offset.dot(motion)
 var discriminant := b * b - a * (offset.length_squared() - radius * radius)
 if discriminant < 0.0: return {}
 var t := (-b - sqrt(discriminant)) / a
 if t < 0.0 or t > 1.0: return {}
 return {"fraction": t, "normal": (offset + motion * t).normalized()}

static func capsule_hit(start: Vector2, motion: Vector2, center: Vector2, forward: Vector2, half_segment: float, radius: float) -> Dictionary:
 var side := Vector2(-forward.y, forward.x)
 var relative := start - center
 var x := relative.dot(side)
 var y := relative.dot(forward)
 var dx := motion.dot(side)
 var dy := motion.dot(forward)
 var nearest := center + side * clampf(x, -half_segment, half_segment)
 if start.distance_squared_to(nearest) <= radius * radius:
  var normal := (start - nearest).normalized()
  if normal.is_zero_approx(): normal = forward
  return {"fraction": 0.0, "normal": normal}
 var result := {}
 for sign_value: float in [-1.0, 1.0]:
  var cap := circle_hit(start, motion, center + side * half_segment * sign_value, radius)
  if not cap.is_empty() and (result.is_empty() or cap.fraction < result.fraction): result = cap
  if absf(dy) < 0.00000001: continue
  var t := (sign_value * radius - y) / dy
  if t >= 0.0 and t <= 1.0 and absf(x + dx * t) <= half_segment and (result.is_empty() or t < result.fraction):
   result = {"fraction": t, "normal": forward * sign_value}
 return result

static func release_clear(ball: PlaygroundBall, mask: int, point: Vector2, direction: Vector2) -> bool:
 if direction.length_squared() < 0.9: return false
 var query := PhysicsShapeQueryParameters2D.new()
 var circle := CircleShape2D.new()
 circle.radius = ball.radius + 1.0
 query.shape = circle
 query.collision_mask = mask
 query.exclude = [ball.get_rid()]
 query.collide_with_areas = false
 for offset: float in [0.0, ball.radius * 2.0 + 2.0]:
  query.transform = Transform2D(0.0, point + direction * offset)
  if not ball.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(): return false
 query.transform = Transform2D(0.0, point)
 query.motion = direction * (ball.radius * 2.0 + 2.0)
 var clearance := ball.get_world_2d().direct_space_state.cast_motion(query)
 return clearance.size() == 2 and clearance[0] >= 1.0
