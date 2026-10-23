class_name ZoneGate
extends StaticBody2D
## A real 2D gate, covered by a separate collisionless presentation marker.
const THICKNESS := 20.0
var opening := Rect2()
var closed := true

func _ready() -> void:
 collision_layer = 1
 collision_mask = 2
 position = opening.get_center()
 var collision := CollisionShape2D.new()
 var shape := RectangleShape2D.new()
 # Overlap the connector rails so high-speed diagonal shots cannot pass an edge.
 shape.size = Vector2(opening.size.x + 32.0, THICKNESS)
 collision.shape = shape
 add_child(collision)
 physics_material_override = PhysicsMaterial.new()
 physics_material_override.friction = 0.0
 physics_material_override.bounce = 0.65

func set_closed(value: bool) -> void:
 closed = value
 set_deferred("collision_layer", 1 if value else 0)
 set_deferred("collision_mask", 2 if value else 0)
