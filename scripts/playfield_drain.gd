class_name PlayfieldDrain
extends Area2D
## Actual 2D drain region, with a sweep so a fast ball cannot skip the sensor.
var bounds := Rect2()
var ball: PlaygroundBall
var active := false

func _ready() -> void:
 collision_layer = 0
 collision_mask = 2
 position = bounds.get_center()
 var collision := CollisionShape2D.new()
 var rectangle := RectangleShape2D.new()
 rectangle.size = bounds.size
 collision.shape = rectangle
 add_child(collision)

func crossed(previous: Vector2, current: Vector2) -> bool:
 if not active or ball.serve_pending or ball._teleport_pending or ball.linear_velocity.y <= 0.0:
  return false
 if overlaps_body(ball):
  return true
 var expanded := bounds.grow(PlaygroundBall.RADIUS)
 if expanded.has_point(current):
  return true
 var corners := [expanded.position, Vector2(expanded.end.x, expanded.position.y), expanded.end, Vector2(expanded.position.x, expanded.end.y)]
 for index in 4:
  if Geometry2D.segment_intersects_segment(previous, current, corners[index], corners[(index + 1) % 4]) != null:
   return true
 return false
