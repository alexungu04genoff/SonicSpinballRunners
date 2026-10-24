class_name TableChunk
extends Node2D
## Authoritative collision geometry; descriptors feed a separate renderer.
var data: ChunkData
var descriptors: Array[Dictionary] = []
var wall_material: PhysicsMaterial
var bumper_material: PhysicsMaterial
## World-space closure rails produced by the connector validator.
var junction_rails: Array[Dictionary] = []

func build() -> void:
 position = Vector2(data.grid_position) * 100.0
 wall_material = PhysicsMaterial.new()
 wall_material.friction = 0.0
 wall_material.bounce = 0.72
 bumper_material = PhysicsMaterial.new()
 bumper_material.friction = 0.0
 bumper_material.bounce = 0.85
 var geometry := data.gameplay_descriptors()
 geometry.append_array(junction_rails)
 for item: Dictionary in geometry:
  if item.kind == "rail":
   _rail(item)
  elif item.kind == "ring":
   descriptors.append(item)
  elif item.kind == "flipper_mount":
   var body := _body()
   body.name = "FlipperHousing"
   body.position = item.position - position
   body.physics_material_override = wall_material
   var polygon := CollisionPolygon2D.new()
   polygon.polygon = item.points
   body.add_child(polygon)
   var descriptor := item.duplicate(true)
   descriptor.body = body
   descriptors.append(descriptor)
  else:
   _bumper(item)
 for marker_name: String in data.markers:
  var marker := Marker2D.new()
  marker.name = marker_name
  marker.position = data.map_point(data.markers[marker_name])
  add_child(marker)

func _body() -> StaticBody2D:
 var body := StaticBody2D.new()
 body.collision_layer = 1
 body.collision_mask = 2
 add_child(body)
 return body

func _rail(item: Dictionary) -> void:
 var a: Vector2 = item.a - position
 var b: Vector2 = item.b - position
 var body := _body()
 body.name = "Rail"
 body.physics_material_override = wall_material
 body.position = (a + b) / 2.0
 var collision := CollisionShape2D.new()
 var shape := CapsuleShape2D.new()
 shape.radius = 12.0
 shape.height = a.distance_to(b) + 24.0
 collision.shape = shape
 collision.rotation = (b - a).angle() + PI / 2.0
 body.add_child(collision)
 var descriptor := item.duplicate(true)
 descriptor.body = body
 descriptors.append(descriptor)

func set_checkpoint_active(active: bool) -> void:
 for item: Dictionary in descriptors:
  if item.get("checkpoint_only", false):
   item.body.set_deferred("collision_layer", 1 if active else 0)
   item.body.set_deferred("collision_mask", 2 if active else 0)

func _bumper(item: Dictionary) -> void:
 var body := _body()
 body.name = "Bumper"
 body.position = item.position - position
 body.physics_material_override = bumper_material
 body.set_meta("bumper", true)
 var descriptor: Dictionary = item.duplicate(true)
 descriptor.position = body.position + position
 descriptor["body"] = body
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
 descriptors.append(descriptor)
