class_name AuthoredActRuntimeCompiler
extends RefCounted
## Compiles one immutable authoring document into ordinary 2D gameplay bodies.
## Primitive library points and stored composite outlines share the editor's transforms.
## Runtime never repeats authoring unions or smoothing.
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const BumperFactory = preload("res://scripts/bumper_factory.gd")
const Flipper = preload("res://scripts/flipper.gd")
const Mechanics = preload("res://scripts/authored_act/pinball_mechanics.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Dimensions = preload("res://scripts/act_dimensions.gd")

static func compile(document: Resource, tuning: PhysicsTuning, controls: PlaygroundInput, ball: PlaygroundBall, baked_shapes: Array = []) -> Dictionary:
 var started := Time.get_ticks_usec()
 var terrain: Array[Dictionary] = []
 var objects: Array[Dictionary] = []
 var flippers: Array[PlaygroundFlipper] = []
 var result := {"root": null, "cell_size": 0.0, "terrain": terrain, "objects": objects, "flippers": flippers, "timings": {"terrain_ms": 0.0, "objects_ms": 0.0, "total_ms": 0.0}, "error": ""}
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
 result.cell_size = cell_size
 # Pass immutable generic visual data through; decor never creates physics bodies.
 result.decor_slots = document.decor_slots.duplicate(true)
 result.decor_seed = document.decor_identity()
 var previous_radius := ball.radius
 ball.radius = Dimensions.BALL_RADIUS_CELLS * cell_size
 var act_root := Node2D.new()
 act_root.name = "AuthoredAct"
 var mechanics := Mechanics.new()
 mechanics.name = "PinballMechanics"
 mechanics.ball = ball
 mechanics.banks = document.switch_banks.duplicate(true)
 act_root.add_child(mechanics)
 result.mechanics = mechanics
 var wall_material := PhysicsMaterial.new()
 wall_material.friction = 0.0
 wall_material.bounce = float(tuning.effective.wall_restitution)
 var bumper_material := PhysicsMaterial.new()
 bumper_material.friction = 0.0
 bumper_material.bounce = 0.85
 var terrain_started := Time.get_ticks_usec()
 for index in document.placements.size():
  var placement: Dictionary = document.placements[index]
  var definition: Dictionary = Shapes.definition_for_placement(placement)
  var points := PackedVector2Array()
  var anchor := Shapes.placement_position(placement) * float(document.cell_size)
  for point: Vector2 in Shapes.transformed_points(placement):
   points.append(point * float(document.cell_size) + anchor)
  var body := StaticBody2D.new()
  body.name = "Terrain_%d" % index
  body.collision_layer = 1
  body.collision_mask = 2
  body.physics_material_override = wall_material
  var collision: Node2D
  if index < baked_shapes.size():
   collision = Node2D.new()
   for record: Dictionary in baked_shapes[index]:
    var piece := CollisionShape2D.new()
    piece.shape = record.shape
    piece.transform = record.transform
    body.add_child(piece)
  elif definition.closed:
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
  placement = placement.duplicate(true)
  placement["object_id"] = Objects.identity(placement, result.objects.size())
  var descriptor := placement.duplicate(true)
  var body: Node2D
  match placement.type:
   "spinner", "magnetic_field", "elevated_rail", "one_way_gate", "switch_target", "wall_switch", "spring", "lane_barrier", "diverter", "dash_panel":
    body = lane_barrier_body(placement, wall_material) if placement.type == "lane_barrier" else Node2D.new()
    body.position = placement.position
    body.rotation_degrees = placement.rotation_degrees
    mechanics.add_object(placement, descriptor)
   "round_bumper":
    descriptor.radius = Dimensions.ROUND_RADIUS_CELLS * cell_size * float(Objects.properties(placement).scale)
    body = BumperFactory.create({"kind": "circle", "position": placement.position, "rotation": deg_to_rad(float(placement.rotation_degrees)), "radius": descriptor.radius}, bumper_material)
   "triangle_bumper":
    descriptor.points = Dimensions.sling_points(cell_size)
    for i in descriptor.points.size(): descriptor.points[i] *= float(Objects.properties(placement).scale)
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
 var rail_error := _validate_rail_clearance(result, ball.radius)
 if not rail_error.is_empty():
  act_root.free()
  ball.radius = previous_radius
  result.error = rail_error
  return result
 result.timings.objects_ms = float(Time.get_ticks_usec() - objects_started) / 1000.0
 result.root = act_root
 result.timings.total_ms = float(Time.get_ticks_usec() - started) / 1000.0
 return result

static func lane_barrier_body(placement: Dictionary, material: PhysicsMaterial) -> StaticBody2D:
 var body := StaticBody2D.new()
 body.name = "LaneBarrierPosts"
 body.collision_layer = 1
 body.collision_mask = 2
 body.physics_material_override = material
 var props := Objects.properties(placement)
 for point: Vector2 in props.points:
  var collision := CollisionShape2D.new()
  var shape := CircleShape2D.new()
  shape.radius = float(props.post_radius)
  collision.shape = shape
  collision.position = point
  body.add_child(collision)
 return body

static func _near_outline(point: Vector2, points: PackedVector2Array, closed: bool, clearance: float) -> bool:
 if closed and Geometry2D.is_point_in_polygon(point, points): return true
 for i in (points.size() if closed else points.size() - 1):
  if Geometry2D.get_closest_point_to_segment(point, points[i], points[(i + 1) % points.size()]).distance_to(point) <= clearance: return true
 return false

static func _validate_rail_clearance(result: Dictionary, ball_radius: float) -> String:
 for item: Dictionary in result.mechanics.items:
  if item.type != "elevated_rail": continue
  if float(item.properties.width) < ball_radius * 2.0 + 2.0:
   return "Rail %s: width must exceed the ball diameter by at least 2 pixels." % item.object_id
  var path: Dictionary = item.path
  if path.length > 20000.0: return "Rail %s: route exceeds 20000 pixels." % item.object_id
  var count := ceili(float(path.length) / maxf(2.0, ball_radius * 0.5))
  for step in count + 1:
   var distance := float(path.length) * step / maxf(1.0, count)
   var point := Mechanics.RailPath.sample(path, distance)
   var height := Mechanics.RailPath.height(path, distance, item.properties.height)
   var margin := Dimensions.RAMP_DECK_THICKNESS_PIXELS + Dimensions.RAMP_CLEARANCE_GAP_PIXELS
   var footprint := maxf(ball_radius, float(item.properties.width) * 0.54)
   for terrain: Dictionary in result.terrain:
    if height < Dimensions.TERRAIN_HEIGHT_PIXELS + margin and _near_outline(point, terrain.points, terrain.closed, footprint):
     return "Rail %s: route needs %.1f px elevation above terrain here (currently %.1f). Raise the rail or move the crossing." % [item.object_id, Dimensions.TERRAIN_HEIGHT_PIXELS + margin, height]
   for object: Dictionary in result.objects:
    var touching := false
    var obstacle_height := 0.0
    if object.type == "round_bumper":
     touching = point.distance_to(object.position) < float(object.radius) + footprint
     obstacle_height = 42.0 * float(object.radius) / 38.0
    elif object.type == "triangle_bumper":
     var local := (point - Vector2(object.position)).rotated(-deg_to_rad(float(object.rotation_degrees)))
     touching = _near_outline(local, object.points, true, footprint)
     obstacle_height = float(result.cell_size) * 0.18 * float(Objects.properties(object).scale)
    elif object.type in ["left_flipper", "right_flipper"]:
     obstacle_height = 28.5 * float(object.radius) / Flipper.RADIUS
     for angle_step in 13:
      var angle := deg_to_rad(float(object.rotation_degrees)) - float(object.side) * 0.8 * angle_step / 12.0
      var tip: Vector2 = object.position + Vector2.from_angle(angle) * float(object.length)
      if Geometry2D.get_closest_point_to_segment(point, object.position, tip).distance_to(point) < footprint + float(object.radius): touching = true
    elif object.type in ["switch_target", "wall_switch"]:
     touching = point.distance_to(object.position) < footprint + Objects.switch_radius(object)
     obstacle_height = 14.0 * float(Objects.properties(object).scale)
    elif object.type in ["one_way_gate", "spring"]:
     var props := Objects.properties(object)
     var side := Vector2.RIGHT.rotated(deg_to_rad(float(object.rotation_degrees)))
     var depth := 4.0 if object.type == "one_way_gate" else float(props.width) * 0.5
     var half_segment := float(props.width) * 0.5 - depth
     var a: Vector2 = object.position - side * half_segment
     var b: Vector2 = object.position + side * half_segment
     touching = Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) < footprint + depth
     obstacle_height = 30.0 if object.type == "one_way_gate" else float(props.width) * 0.8
    elif object.type == "lane_barrier":
     for post: Vector2 in Objects.world_posts(object):
      if point.distance_to(post) < footprint + float(Objects.properties(object).post_radius): touching = true
     obstacle_height = 38.0
    elif object.type == "diverter":
     # Check the entire machinery sweep, not just its initially authored state.
     touching = point.distance_to(object.position) < footprint + float(Objects.properties(object).length) * 0.5 + 4.0
     obstacle_height = 24.0
    elif object.type == "dash_panel":
     var local := (point - Vector2(object.position)).rotated(-deg_to_rad(float(object.rotation_degrees)))
     touching = _near_outline(local, Objects.local_points(object, result.cell_size), true, footprint)
     obstacle_height = 7.0
    if touching and height < obstacle_height + margin:
     return "Rail %s: route overlaps lower gameplay hardware or a flipper sweep; needs %.1f px elevation here (currently %.1f). Move the mouth or raise the crossing." % [item.object_id, obstacle_height + margin, height]
 return ""
