class_name ScoreAttack
extends RefCounted
## Observes the shared score and 2D ball. It never awards points or changes physics.
signal changed
enum State { FREE_PLAY, LOCKED, UNLOCKED, COMPLETE }
const GOAL_RADIUS := 55.0
const CONTACT_RADIUS := GOAL_RADIUS + PlaygroundBall.RADIUS
const DEFAULT_TARGET := 1500
var state: State = State.FREE_PLAY
var target: int = DEFAULT_TARGET
var goal_position := Vector2.INF

static func find_goal(layout: Dictionary) -> Vector2:
 # Existing route markers have already passed the generator's connectivity check.
 # Prefer authored targets; otherwise use a clear upper route or collectible anchor.
 var upper: ChunkData = layout.chunks[0]
 var candidates := PackedVector2Array()
 if upper.markers.has("test_target"):
  candidates.append(upper.markers.test_target)
 candidates.append_array(upper.navigation_probes)
 candidates.append_array(upper.rings)
 var geometry: Array[Dictionary] = upper.gameplay_descriptors()
 var height := upper.grid_dimensions.y * ChunkData.GRID_SIZE
 for local: Vector2 in candidates:
  var point := upper.world_point(local)
  if local.y > height * 0.45 or local.y < height * 0.15:
   continue
  if Geometry2D.is_point_in_polygon(local, upper.playfield_outline) and TableGenerator.point_clear(point, geometry, GOAL_RADIUS):
   return point
 return Vector2.INF

func reset(enabled: bool, score_target: int, position: Vector2) -> void:
 target = clampi(score_target, 25, 1000000)
 goal_position = position
 state = State.LOCKED if enabled else State.FREE_PLAY
 changed.emit()

func observe_score(total: int) -> void:
 if state == State.LOCKED and total >= target:
  state = State.UNLOCKED
  changed.emit()

func observe_motion(previous: Vector2, current: Vector2) -> bool:
 if state != State.UNLOCKED:
  return false
 var closest := Geometry2D.get_closest_point_to_segment(goal_position, previous, current)
 if closest.distance_squared_to(goal_position) > CONTACT_RADIUS * CONTACT_RADIUS:
  return false
 state = State.COMPLETE
 changed.emit()
 return true
