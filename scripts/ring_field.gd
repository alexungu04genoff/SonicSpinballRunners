class_name RingField
extends Node
## Rings stay at their authored positions. Collection never applies force to the ball.
signal collected(position: Vector2)
signal scoring_pickup(position: Vector2, source: String, multiplier: int)
signal pickup_claimed(index: int)
signal rack_reset
const CONTACT_RADIUS := PlaygroundBall.RADIUS + 12.0
## Per-instance geometry; ordinary tables retain their original 12 px ring contact.
var ring_radius := 12.0
var rings: Array[Dictionary] = []
var ball: PlaygroundBall
var tuning: PhysicsTuning
var previous_ball_position: Vector2
## Empty bounds preserve sandbox behavior; Zone mode collects only the active Act.
var collection_bounds := Rect2()

func ring_eligible(ring: Dictionary) -> bool:
 return not collection_bounds.has_area() or collection_bounds.has_point(ring.home)

func add_ring(at: Vector2) -> void:
 rings.append({"home": at, "position": at, "active": true})

func reset_rings() -> void:
 for ring: Dictionary in rings:
  if not ring_eligible(ring):
   continue
  ring.position = ring.home
  ring.active = true
 rack_reset.emit()

func claim_ring(index: int, source: String = "", multiplier: int = 1) -> bool:
 if index < 0 or index >= rings.size():
  return false
 var ring: Dictionary = rings[index]
 if not ring.active or not ring_eligible(ring):
  return false
 # One atomic claim is shared by contact, magnet and area abilities. Cosmetic
 # flight and legacy collection observers still receive exactly one event.
 ring.active = false
 pickup_claimed.emit(index)
 scoring_pickup.emit(ring.position, source, multiplier)
 collected.emit(ring.position)
 return true

func _physics_process(_delta: float) -> void:
 if ball.serve_pending or ball._teleport_pending:
  previous_ball_position = ball._teleport_position if ball._teleport_pending else ball.position
  return
 # Radius is measured from the swept ball center to the stationary ring center.
 # A disabled or small magnet must never shrink the existing direct-contact pickup.
 var radius := maxf(ball.radius + ring_radius, float(tuning.effective.ring_magnet_radius))
 for i in rings.size():
  var ring: Dictionary = rings[i]
  if not ring.active or not ring_eligible(ring):
   continue
  var closest: Vector2 = Geometry2D.get_closest_point_to_segment(ring.position, previous_ball_position, ball.position)
  if closest.distance_squared_to(ring.position) <= radius * radius:
   # Deactivate before notifying score/meter listeners, so overlapping pickup
   # methods and subsequent ticks cannot award this ring twice in one rack.
   claim_ring(i)
 previous_ball_position = ball.position
