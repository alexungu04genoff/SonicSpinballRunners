class_name AuthoredActRuntimeCompiler
extends RefCounted
## Compiles one immutable authoring document into ordinary 2D gameplay bodies.
## Points are read from the editor's canonical library; no generator is involved.
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const BumperFactory = preload("res://scripts/bumper_factory.gd")
const Flipper = preload("res://scripts/flipper.gd")
const Dimensions = preload("res://scripts/act_dimensions.gd")

static func compile(document: Resource, tuning: PhysicsTuning, controls: PlaygroundInput, ball: PlaygroundBall) -> Dictionary:
 var started := Time.get_ticks_usec()
 var terrain: Array[Dictionary] = []
 var objects: Array[Dictionary] = []
 var flippers: Array[PlaygroundFlipper] = []
 var result := {"root": null, "terrain": terrain, "objects": objects, "flippers": flippers, "timings": {"terrain_ms": 0.0, "objects_ms": 0.0, "total_ms": 0.0}, "error": ""}
 if document == null or document.get_script() != Document:
  result.error = "Choose a valid Act Geometry document."
  return result
 var errors: PackedStringArray = document.validation_errors()
 if not errors.is_empty():
  result.error = "\n".join(errors)
  return result
 if document.spawn_position == null:
  result.error = "This Act needs a Launch / Spawn marker before it can be played."
  return result
 if tuning == null or controls == null or ball == null:
  result.error = "Act compilation needs the shared physics tuning, input adapter and gameplay ball."
  return result
 var cell_size := float(document.cell_size)
 ball.radius = Dimensions.BALL_RADIUS_CELLS * cell_size
 var act_root := Node2D.new()
 act_root.name = "AuthoredAct"
 var wall_material := PhysicsMaterial.new()
 wall_material.friction = 0.0
 wall_material.bounce = float(tuning.effective.wall_restitution)
 var bumper_material := PhysicsMaterial.new()
 bumper_material.friction = 0.0
 bumper_material.bounce = 0.85
 var terrain_started := Time.get_ticks_usec()
 for index in document.placements.size():
  var placement: Dictionary = document.placements[index]
  var definition: Dictionary = Shapes.get_definition(placement.shape_id)
  var points := PackedVector2Array()
  var anchor := Vector2(placement.anchor) * float(document.cell_size)
  for point: Vector2 in Shapes.transformed_points(placement):
   points.append(point * float(document.cell_size) + anchor)
  var body := StaticBody2D.new()
  body.name = "Terrain_%d" % index
  body.collision_layer = 1
  body.collision_mask = 2
  body.physics_material_override = wall_material
  var collision: Node2D
  if definition.closed:
   var polygon := CollisionPolygon2D.new()
   polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS
   polygon.polygon = points
   collision = polygon
  else:
   # Concave segment pairs are two-sided wall surfaces, never an implicit solid.
   # Only consecutive authored vertices are connected; endpoints remain open.
   var segments := PackedVector2Array()
   for point_index in range(points.size() - 1):
    segments.append(points[point_index])
    segments.append(points[point_index + 1])
   var path := ConcavePolygonShape2D.new()
   path.segments = segments
   var segment_collision := CollisionShape2D.new()
   segment_collision.shape = path
   collision = segment_collision
  body.add_child(collision)
  act_root.add_child(body)
  result.terrain.append({"shape_id": placement.shape_id, "points": points, "closed": definition.closed, "body": body, "collision": collision, "color": definition.color})
 result.timings.terrain_ms = float(Time.get_ticks_usec() - terrain_started) / 1000.0
 var objects_started := Time.get_ticks_usec()
 for placement: Dictionary in document.gameplay_objects:
  var descriptor := {"type": placement.type, "position": placement.position, "rotation_degrees": placement.rotation_degrees}
  var body: Node2D
  match placement.type:
   "round_bumper":
    descriptor.radius = Dimensions.ROUND_RADIUS_CELLS * cell_size
    body = BumperFactory.create({"kind": "circle", "position": placement.position, "rotation": deg_to_rad(float(placement.rotation_degrees)), "radius": descriptor.radius}, bumper_material)
   "triangle_bumper":
    descriptor.points = Dimensions.sling_points(cell_size)
    body = BumperFactory.create({"kind": "triangle", "position": placement.position, "rotation": deg_to_rad(float(placement.rotation_degrees)), "points": descriptor.points}, bumper_material)
   "left_flipper", "right_flipper":
    var flipper := Flipper.new()
    flipper.name = "LeftFlipper" if placement.type == "left_flipper" else "RightFlipper"
    flipper.side = 1.0 if placement.type == "left_flipper" else -1.0
    flipper.length = Dimensions.FLIPPER_LENGTH_CELLS * cell_size
    flipper.radius = Dimensions.FLIPPER_RADIUS_CELLS * cell_size
    flipper.position = placement.position
    flipper.authored_rest_angle = deg_to_rad(float(placement.rotation_degrees))
    flipper.rotation = flipper.authored_rest_angle
    flipper.tuning = tuning
    flipper.controls = controls
    flipper.ball = ball
    descriptor.length = flipper.length
    descriptor.radius = flipper.radius
    descriptor.side = flipper.side
    result.flippers.append(flipper)
    body = flipper
  descriptor.body = body
  result.objects.append(descriptor)
  act_root.add_child(body)
 result.timings.objects_ms = float(Time.get_ticks_usec() - objects_started) / 1000.0
 result.root = act_root
 result.timings.total_ms = float(Time.get_ticks_usec() - started) / 1000.0
 return result
