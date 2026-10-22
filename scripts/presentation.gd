class_name TablePresentation
extends Node3D
## No CollisionObject3D exists in this tree. This mapping is used for every visual.
const SCALE: float = 0.01
var ball: PlaygroundBall
var flippers: Array[PlaygroundFlipper] = []
var ring_field: RingField
var ball_visual: MeshInstance3D
var flipper_visuals: Array[Node3D] = []
var ring_visuals: Array[MeshInstance3D] = []
var physics_overlay: Node3D
var chunk_overlay: Node3D
var bumper_visuals: Dictionary = {}
var flash_times: Dictionary = {}
var camera: Camera3D
var _last_ball_position: Vector2
var dynamic_geometry: ImmediateMesh

static func map_point(point: Vector2, height: float = 0.0) -> Vector3:
 return Vector3((point.x - 400.0) * SCALE, height, (point.y - 700.0) * SCALE)

static func unmap_point(point: Vector3) -> Vector2:
 return Vector2(point.x / SCALE + 400.0, point.z / SCALE + 700.0)

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
 var result := StandardMaterial3D.new()
 result.albedo_color = color
 result.roughness = 0.65
 if glow > 0.0:
  result.emission_enabled = true
  result.emission = color
  result.emission_energy_multiplier = glow
 return result

func mesh_node(mesh: Mesh, mat: Material, where: Vector3, parent: Node = self) -> MeshInstance3D:
 var instance := MeshInstance3D.new()
 instance.mesh = mesh
 instance.material_override = mat
 instance.position = where
 parent.add_child(instance)
 return instance

func sphere(radius: float) -> SphereMesh:
 var mesh := SphereMesh.new()
 mesh.radius = radius
 mesh.height = radius * 2.0
 mesh.radial_segments = 16
 mesh.rings = 8
 return mesh

func cylinder(radius: float, height: float) -> CylinderMesh:
 var mesh := CylinderMesh.new()
 mesh.top_radius = radius
 mesh.bottom_radius = radius
 mesh.height = height
 mesh.radial_segments = 24
 return mesh

func line(a: Vector2, b: Vector2, radius: float, height: float, mat: Material, parent: Node = self) -> MeshInstance3D:
 var start: Vector3 = map_point(a, height)
 var end: Vector3 = map_point(b, height)
 var instance := mesh_node(cylinder(radius, start.distance_to(end)), mat, (start + end) * 0.5, parent)
 instance.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
 return instance

func build(chunks: Array[TableChunk]) -> void:
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("08121e")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color("a6d1ed")
 environment.environment.ambient_light_energy = 0.65
 add_child(environment)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-65, -25, 0)
 light.light_energy = 1.4
 add_child(light)
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 15.4
 camera.position = Vector3(0, 18, 6.5)
 add_child(camera)
 camera.look_at(Vector3.ZERO)
 camera.current = true
 var floor_mesh := BoxMesh.new()
 floor_mesh.size = Vector3(8.15, 0.18, 14.5)
 mesh_node(floor_mesh, material(Color("102b38")), Vector3(0, -0.17, 0))
 var rail_mat := material(Color("40bba9"), 0.15)
 var bumper_mat := material(Color("ed6a53"), 0.12)
 var gold := material(Color("ffcf52"), 0.5)
 var grid_mat := material(Color("1b414c"))
 for x in range(100, 800, 100):
  line(Vector2(x, 80), Vector2(x, 1370), 0.009, -0.065, grid_mat)
 for y in range(100, 1400, 100):
  line(Vector2(65, y), Vector2(735, y), 0.009, -0.065, grid_mat)
 physics_overlay = Node3D.new()
 physics_overlay.name = "PhysicsGeometryOverlay"
 add_child(physics_overlay)
 physics_overlay.visible = false
 dynamic_geometry = ImmediateMesh.new()
 var dynamic_debug := MeshInstance3D.new()
 dynamic_debug.mesh = dynamic_geometry
 dynamic_debug.material_override = material(Color("70ff85"), 0.7)
 physics_overlay.add_child(dynamic_debug)
 chunk_overlay = Node3D.new()
 chunk_overlay.name = "ChunkBoundaryOverlay"
 add_child(chunk_overlay)
 chunk_overlay.visible = false
 var debug_mat := material(Color("70ff85"), 0.7)
 var boundary_mat := material(Color("d8a9ff"), 0.7)
 for chunk: TableChunk in chunks:
  for item: Dictionary in chunk.descriptors:
   match item.kind:
    "rail":
     line(item.a, item.b, 0.12, 0.12, rail_mat)
     mesh_node(sphere(0.12), rail_mat, map_point(item.a, 0.12))
     mesh_node(sphere(0.12), rail_mat, map_point(item.b, 0.12))
     _capsule_outline(item.a, item.b, 12.0, debug_mat)
    "circle":
     var body_visual := mesh_node(cylinder(float(item.radius) * SCALE, 0.30), bumper_mat, map_point(item.position, 0.15))
     bumper_visuals[item.body.get_instance_id()] = body_visual
     mesh_node(cylinder(float(item.radius) * SCALE * 0.7, 0.05), gold, map_point(item.position, 0.325))
     _circle_outline(item.position, item.radius, debug_mat)
    "triangle":
     var body_visual := mesh_node(_prism(item.points, 0.30), bumper_mat, map_point(item.position))
     bumper_visuals[item.body.get_instance_id()] = body_visual
     for i in item.points.size():
      line(item.position + item.points[i], item.position + item.points[(i + 1) % item.points.size()], 0.018, 0.37, debug_mat, physics_overlay)
  var origin: Vector2 = chunk.position
  var size: Vector2 = Vector2(chunk.data.grid_dimensions) * 100.0
  line(origin, origin + Vector2(size.x, 0), 0.018, 0.38, boundary_mat, chunk_overlay)
  line(origin + Vector2(0, size.y), origin + size, 0.018, 0.38, boundary_mat, chunk_overlay)
  for connection: Rect2 in [chunk.data.top_connection, chunk.data.bottom_connection]:
   if connection.size.x > 0:
    line(origin + connection.position, origin + connection.position + Vector2(connection.size.x, 0), 0.04, 0.39, debug_mat, chunk_overlay)
 for ring: Dictionary in ring_field.rings:
  var torus := TorusMesh.new()
  torus.inner_radius = 0.075
  torus.outer_radius = 0.135
  torus.rings = 16
  torus.ring_segments = 8
  ring_visuals.append(mesh_node(torus, gold, map_point(ring.position, 0.18)))
 for flipper: PlaygroundFlipper in flippers:
  var pivot := Node3D.new()
  pivot.position = map_point(flipper.position, 0.13)
  add_child(pivot)
  var flipper_mat := material(Color("6ab8ff"), 0.2)
  var bar := BoxMesh.new()
  bar.size = Vector3(PlaygroundFlipper.LENGTH * SCALE, 0.23, PlaygroundFlipper.RADIUS * 2 * SCALE)
  mesh_node(bar, flipper_mat, Vector3(0.75, 0, 0), pivot)
  mesh_node(cylinder(0.13, 0.23), flipper_mat, Vector3.ZERO, pivot)
  mesh_node(cylinder(0.13, 0.23), flipper_mat, Vector3(1.5, 0, 0), pivot)
  flipper_visuals.append(pivot)
 ball_visual = mesh_node(sphere(PlaygroundBall.RADIUS * SCALE), material(Color("4f97ff"), 0.25), map_point(ball.position, 0.16))
 var stripe := TorusMesh.new()
 stripe.inner_radius = 0.134
 stripe.outer_radius = 0.146
 mesh_node(stripe, material(Color("e5f4ff")), Vector3.ZERO, ball_visual)
 # Drain and serve guides have no gameplay collision.
 line(Vector2(360, 1395), Vector2(440, 1395), 0.035, 0.01, material(Color("ef6473"), 0.4))
 _label("SKY GARDEN", Vector2(400, 95), 22, Color("71cbbf"))
 _label("LAUNCH DECK", Vector2(400, 740), 18, Color("678eaa"))
 _label("DRAIN", Vector2(400, 1360), 18, Color("ee8693"))

func _label(text: String, point: Vector2, font_size: int, color: Color) -> void:
 var label := Label3D.new()
 label.text = text
 label.font_size = font_size
 label.pixel_size = 0.012
 label.modulate = color
 label.outline_size = 0
 label.rotation.x = -PI / 2.0
 label.position = map_point(point, -0.05)
 add_child(label)

func _circle_outline(center: Vector2, radius: float, mat: Material) -> void:
 for i in 32:
  line(center + Vector2.from_angle(i * TAU / 32) * radius, center + Vector2.from_angle((i + 1) * TAU / 32) * radius, 0.012, 0.37, mat, physics_overlay)

func _capsule_outline(a: Vector2, b: Vector2, radius: float, mat: Material) -> void:
 var normal := (b - a).normalized().orthogonal() * radius
 line(a + normal, b + normal, 0.012, 0.37, mat, physics_overlay)
 line(a - normal, b - normal, 0.012, 0.37, mat, physics_overlay)
 _circle_outline(a, radius, mat)
 _circle_outline(b, radius, mat)

func _prism(points: PackedVector2Array, height: float) -> ArrayMesh:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var indices: PackedInt32Array = Geometry2D.triangulate_polygon(points)
 for index in indices:
  surface.add_vertex(Vector3(points[index].x * SCALE, height, points[index].y * SCALE))
 for i in points.size():
  var a := Vector3(points[i].x * SCALE, 0, points[i].y * SCALE)
  var b := Vector3(points[(i + 1) % points.size()].x * SCALE, 0, points[(i + 1) % points.size()].y * SCALE)
  for vertex: Vector3 in [a, a + Vector3.UP * height, b, b, a + Vector3.UP * height, b + Vector3.UP * height]:
   surface.add_vertex(vertex)
 surface.generate_normals()
 return surface.commit()

func flash_bumper(body: Node) -> void:
 flash_times[body.get_instance_id()] = 0.12

func _process(delta: float) -> void:
 if not is_instance_valid(ball_visual):
  return
 ball_visual.position = map_point(ball.position, 0.16)
 var travel: Vector2 = ball.position - _last_ball_position
 if travel.length() > 0.001 and travel.length() < 100:
  ball_visual.rotate(Vector3(travel.y, 0, -travel.x).normalized(), travel.length() / PlaygroundBall.RADIUS)
 _last_ball_position = ball.position
 for i in flippers.size():
  flipper_visuals[i].rotation.y = -flippers[i].rotation
 for i in ring_visuals.size():
  ring_visuals[i].visible = ring_field.rings[i].active
  ring_visuals[i].position = map_point(ring_field.rings[i].position, 0.18)
 for id: int in flash_times.keys():
  flash_times[id] -= delta
  var mesh: MeshInstance3D = bumper_visuals[id]
  mesh.scale.y = 1.0 + maxf(0, float(flash_times[id])) * 2.0
  if flash_times[id] <= 0:
   mesh.scale.y = 1.0
   flash_times.erase(id)
 if physics_overlay.visible:
  _draw_dynamic_geometry()

func _draw_dynamic_geometry() -> void:
 dynamic_geometry.clear_surfaces()
 dynamic_geometry.surface_begin(Mesh.PRIMITIVE_LINES)
 _debug_circle(ball.position, PlaygroundBall.RADIUS)
 for flipper: PlaygroundFlipper in flippers:
  var a: Vector2 = flipper.position
  var b: Vector2 = flipper.tip()
  var offset := (b - a).normalized().orthogonal() * PlaygroundFlipper.RADIUS
  for point: Vector2 in [a + offset, b + offset, a - offset, b - offset]:
   dynamic_geometry.surface_add_vertex(map_point(point, 0.40))
  _debug_circle(a, PlaygroundFlipper.RADIUS)
  _debug_circle(b, PlaygroundFlipper.RADIUS)
 dynamic_geometry.surface_end()

func _debug_circle(center: Vector2, radius: float) -> void:
 for i in 32:
  dynamic_geometry.surface_add_vertex(map_point(center + Vector2.from_angle(i * TAU / 32) * radius, 0.40))
  dynamic_geometry.surface_add_vertex(map_point(center + Vector2.from_angle((i + 1) * TAU / 32) * radius, 0.40))
