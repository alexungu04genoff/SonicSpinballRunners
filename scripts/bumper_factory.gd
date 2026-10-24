extends RefCounted
## Shared construction for the existing ball-driven bumper response.
## The ball recognizes the bumper metadata and applies the resolved profile impulse.

static func create(item: Dictionary, material: PhysicsMaterial) -> StaticBody2D:
 var body := StaticBody2D.new()
 body.name = "Bumper"
 body.collision_layer = 1
 body.collision_mask = 2
 body.position = item.position
 body.rotation = float(item.get("rotation", 0.0))
 body.physics_material_override = material
 body.set_meta("bumper", true)
 if item.kind == "circle":
  var collision := CollisionShape2D.new()
  var circle := CircleShape2D.new()
  circle.radius = item.radius
  collision.shape = circle
  body.add_child(collision)
 else:
  var polygon := CollisionPolygon2D.new()
  polygon.polygon = item.points
  body.add_child(polygon)
 return body
