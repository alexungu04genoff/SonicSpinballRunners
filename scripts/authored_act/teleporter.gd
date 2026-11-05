extends RefCounted
## One authored object owns both endpoints. Exit offsets and angle rotate with it.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Contact = preload("res://scripts/authored_act/gimmick_geometry.gd")
const SPEED_CAP := 2400.0

static func near_outline(point: Vector2, points: PackedVector2Array, closed: bool, radius: float) -> bool:
 if closed and Geometry2D.is_point_in_polygon(point, points): return true
 for i in (points.size() if closed else points.size() - 1):
  if point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[i], points[(i + 1) % points.size()])) <= radius: return true
 return false

static func hardware_clear(point: Vector2, radius: float, objects: Array, cell_size: float) -> bool:
 for item: Dictionary in objects:
  var props := Objects.properties(item)
  if item.type in ["teleporter", "magnetic_field", "elevated_rail", "spinner", "switch_target", "wall_switch", "dash_panel", "buzz_bomber"]: continue
  if item.type in ["left_flipper", "right_flipper"]:
   var length := Objects.flipper_length(item, cell_size)
   var side := 1.0 if item.type == "left_flipper" else -1.0
   for step in 13:
    var angle := deg_to_rad(float(item.rotation_degrees)) - side * 0.8 * step / 12.0
    var tip := Vector2(item.position) + Vector2.from_angle(angle) * length
    if Geometry2D.get_closest_point_to_segment(point, item.position, tip).distance_to(point) <= radius + cell_size * Objects.Dimensions.FLIPPER_RADIUS_CELLS + length * 0.8 / 24.0: return false
  elif item.type == "lane_barrier":
   for post: Vector2 in Objects.world_posts(item):
    if point.distance_to(post) <= radius + float(props.post_radius): return false
  elif item.type == "diverter":
   if point.distance_to(item.position) <= radius + float(props.length) * 0.5 + 4.0: return false
  else:
   var local := (point - Vector2(item.position)).rotated(-deg_to_rad(float(item.rotation_degrees)))
   if near_outline(local, Objects.local_points(item, cell_size), true, radius): return false
 return true

static func validation_error(runtime: Dictionary, bounds: Rect2, radius: float) -> String:
 for item: Dictionary in runtime.mechanics.items:
  if item.type != "teleporter": continue
  var exit := Objects.teleporter_exit(item)
  if not bounds.grow(-radius - 2.0).has_point(exit): return "Teleporter %s: exit must keep the whole ball inside the Act." % item.object_id
  for terrain: Dictionary in runtime.terrain:
   if near_outline(exit, terrain.points, terrain.closed, radius + 2.0): return "Teleporter %s: exit overlaps terrain. Move the OUT marker into clear space." % item.object_id
  if not hardware_clear(exit, radius + 2.0, runtime.objects, runtime.cell_size): return "Teleporter %s: exit overlaps gameplay hardware or a flipper sweep." % item.object_id
 return ""

static func build(table: TablePresentation, parent: Node3D, item: Dictionary) -> void:
 for endpoint in 2:
  var at: Vector2 = item.position if endpoint == 0 else Objects.teleporter_exit(item)
  var color := Color("bf81ee") if endpoint == 0 else Color("70ddc9")
  var radius := float(item.properties.radius) if endpoint == 0 else 10.0
  var ring := TorusMesh.new()
  ring.inner_radius = (radius - 3.0) * table.SCALE
  ring.outer_radius = radius * table.SCALE
  ring.rings = 16
  ring.ring_segments = 4
  table.mesh_node(ring, table.material(color), table.map_point(at, 0.025), parent).name = "TeleporterEntrance" if endpoint == 0 else "TeleporterExit"
  if endpoint == 1:
   var direction := Objects.teleporter_direction(item)
   var across := Vector2(-direction.y, direction.x)
   var mesh := SurfaceTool.new()
   mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
   for point: Vector2 in [at + direction * 24.0, at + direction * 12.0 + across * 6.0, at + direction * 12.0 - across * 6.0]:
    mesh.set_normal(Vector3.UP)
    mesh.add_vertex(table.map_point(point, 0.035))
   var material := table.material(color)
   material.cull_mode = BaseMaterial3D.CULL_DISABLED
   table.mesh_node(mesh.commit(), material, Vector3.ZERO, parent).name = "TeleporterExitDirection"
