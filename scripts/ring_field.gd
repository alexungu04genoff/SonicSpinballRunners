class_name RingField
extends Node
## Rings are gameplay objects. Their attraction never pulls the ball off its trajectory.
signal collected(position: Vector2)
var rings: Array[Dictionary] = []
var ball: PlaygroundBall
var tuning: PhysicsTuning
var previous_ball_position: Vector2

func add_ring(at: Vector2) -> void:
 rings.append({"home": at, "position": at, "active": true})

func reset_rings() -> void:
 for ring: Dictionary in rings:
  ring.position = ring.home
  ring.active = true

func _physics_process(delta: float) -> void:
 if ball.serve_pending:
  previous_ball_position = ball.position
  return
 for ring: Dictionary in rings:
  if not ring.active:
   continue
  var offset: Vector2 = ball.position - Vector2(ring.position)
  var distance: float = offset.length()
  if distance < float(tuning.effective.ring_magnet_radius):
   ring.position = Vector2(ring.position).move_toward(ball.position, float(tuning.effective.ring_magnet_strength) * delta)
  var closest: Vector2 = Geometry2D.get_closest_point_to_segment(ring.position, previous_ball_position, ball.position)
  if closest.distance_to(ring.position) < PlaygroundBall.RADIUS + 12.0:
   ring.active = false
   collected.emit(ring.position)
 previous_ball_position = ball.position
