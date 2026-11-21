extends RefCounted
## Spatial checks belong to Play/Bake and the inspector. Draft placement stays editable.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Obstacle = preload("res://scripts/authored_act/teleporter.gd")
const Path = Objects.LoopPath

static func editor_warning(document: Resource, placement: Dictionary) -> String:
 var terrain := []
 for piece: Dictionary in document.placements:
  var points: PackedVector2Array = document.SHAPES.transformed_points(piece)
  var anchor: Vector2 = document.SHAPES.placement_position(piece)
  for i in points.size(): points[i] = (points[i] + anchor) * float(document.cell_size)
  terrain.append({"points":points, "closed":document.SHAPES.definition_for_placement(piece).closed})
 var item := placement.duplicate()
 item.properties = Objects.properties(placement)
 return check(item, document.terrain_bounds(), terrain, document.gameplay_objects, document.cell_size, float(document.cell_size) * Objects.Dimensions.BALL_RADIUS_CELLS)

static func check(item: Dictionary, bounds: Rect2, terrain: Array, hardware: Array, cell: float, radius: float) -> String:
 var scale_value := float(item.properties.scale)
 var half_width := Path.HALF_WIDTH * scale_value
 var label := "Loop %s: " % item.get("object_id", "")
 if half_width < radius + 1.0: return label + "mouth is too narrow for this Act’s Ball."
 var length := Path.LENGTH * scale_value
 var step_length := minf(4.0, radius * 0.5)
 var forward := Objects.forward(item)
 var clearance := radius * 2.0 + 2.0
 var steps := ceili((length + 2.0 * clearance) / step_length)
 for i in steps + 1:
  var distance := lerpf(-clearance, length + clearance, float(i) / steps)
  var on_track := clampf(distance, 0.0, length)
  var sample := Path.sample(item, on_track)
  var at := Vector2(sample.x, sample.z) + forward * (distance - on_track)
  var section := "entrance" if distance <= Path.LEAD * scale_value else ("exit" if distance >= length - Path.LEAD * scale_value else "track")
  if not bounds.grow(-half_width).has_point(at): return label + section + " extends outside the Act."
  if sample.y <= Objects.Dimensions.TERRAIN_HEIGHT_PIXELS + Objects.Dimensions.RAMP_DECK_THICKNESS_PIXELS + 2.0:
   for piece: Dictionary in terrain:
    if Obstacle.near_outline(at, piece.points, piece.closed, half_width + step_length * 0.5):
     return label + section + " intersects terrain below safe crossing height."
   if not Obstacle.hardware_clear(at, half_width + step_length * 0.5, hardware, cell):
    return label + section + " intersects solid hardware or a flipper sweep."
   for other: Dictionary in hardware:
    if other.type != "moving_bumper": continue
    var props := Objects.properties(other)
    var near := Vector2(other.position) + Vector2.RIGHT * clampf(at.x - float(other.position.x), props.patrol_left, props.patrol_right)
    if near.distance_to(at) < half_width + float(props.width) * 0.5:
     return label + section + " intersects a moving bumper’s patrol."
 return ""
