extends RefCounted
## A gap is a swept corridor, narrowed by the ball radius and its physical posts.
## State records an entry side until the entire ball leaves the opposite side.
const HALF_DEPTH := 6.0

static func make_lane() -> Dictionary:
 return {"side": 0, "latched": false, "lit": false, "passes": 0, "pulse": 0.0}

static func observe(lane: Dictionary, start: Vector2, end: Vector2, a: Vector2, b: Vector2, post_radius: float, ball_radius: float) -> bool:
 var tangent := (b - a).normalized()
 var normal := Vector2(-tangent.y, tangent.x)
 var p := Vector2((start - a).dot(tangent), (start - a).dot(normal))
 var q := Vector2((end - a).dot(tangent), (end - a).dot(normal))
 var clearance := post_radius + ball_radius + 0.5
 var far := a.distance_to(b) - clearance
 var depth := HALF_DEPTH + ball_radius
 var outside := absf(p.y) > depth + 0.1 or p.x < clearance or p.x > far
 if lane.latched:
  if not outside: return false
  lane.latched = false
  lane.side = 0
 if far <= clearance: return false
 var dy := q.y - p.y
 if absf(dy) < 0.00001:
  if q.x < clearance or q.x > far: lane.side = 0
  return false
 var t0 := (-depth - p.y) / dy
 var t1 := (depth - p.y) / dy
 var enter := maxf(0.0, minf(t0, t1))
 var leave := minf(1.0, maxf(t0, t1))
 if enter > leave: # Fully outside the strip; discard interrupted passages.
  lane.side = 0
  return false
 var x0 := lerpf(p.x, q.x, enter)
 var x1 := lerpf(p.x, q.x, leave)
 if minf(x0, x1) < clearance or maxf(x0, x1) > far:
  lane.side = 0
  lane.latched = true # Side entry / post clipping cannot become a clean shot.
  return false
 if lane.side == 0:
  if p.y < -depth: lane.side = -1
  elif p.y > depth: lane.side = 1
  else:
   lane.latched = true # Spawn, rest or vibration inside the strip earns nothing.
   return false
 if q.y * float(lane.side) < -depth:
  lane.passes += 1
  lane.lit = true
  lane.pulse = 0.3
  lane.latched = true
  lane.side = 0
  return true
 if q.y * float(lane.side) > depth: lane.side = 0
 return false
