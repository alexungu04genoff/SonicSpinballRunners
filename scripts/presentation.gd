class_name TablePresentation
extends Node3D
## No CollisionObject3D exists in this tree. This mapping is used for every visual.
const PinballModels = preload("res://scripts/pinball_models.gd")
## Optional slot overrides: rubber, face, trim, mark, paddle and base. Rebuild to apply.
@export var pinball_palette: Dictionary = {}
var _pinball_materials: Dictionary = {}
const SCALE: float = 0.01
const BALL_HEIGHT: float = 0.16
const RING_HEIGHT: float = 0.23
## Shared wall styling for generated rails and authored solid/path obstacles.
const RAIL_HEIGHT: float = 0.30
const RAIL_CAP_HEIGHT: float = preload("res://scripts/act_dimensions.gd").TERRAIN_HEIGHT_PIXELS * SCALE - RAIL_HEIGHT
const RAIL_SIDE_COLOR := Color("267f81")
const RAIL_TOP_COLOR := Color("64d6bd")
## Cosmetic timing only; character profiles control pickup radius, never flight speed.
const RING_PICKUP_DURATION: float = 0.20
const OVERLAY_HEIGHT: float = 0.015
const AuthoredActData := preload("res://scripts/act_editor/act_geometry.gd")
enum CameraPreset { TOP_DOWN, REAL_PINBALL, DRAMATIC_PINBALL }
const CAMERA_NAMES: Array[String] = ["Top-down reference", "Real Pinball", "Dramatic Pinball"]
var camera_preset: int = CameraPreset.REAL_PINBALL
var camera_follow_enabled: bool = true
var overview_zoom: float = 1.0
var overview_focus := Vector2.INF
## Distances are physics pixels, speed is pixels/second, response is inverse seconds.
## Zoom is a dimensionless multiplier on each source's default follow framing.
var camera_settings: Dictionary = {"zoom": 1.0, "dead_zone_y": 12.0, "dead_zone_x": 18.0, "look_ahead": 0.0, "screen_target_y": 0.38, "screen_margin_y": 0.22, "vertical_response": 28.0, "horizontal_response": 2.0, "max_speed": 4000.0}
const CAMERA_LIMITS: Dictionary = {"zoom": Vector2(0.6, 2.5), "dead_zone_y": Vector2(0, 250), "dead_zone_x": Vector2(0, 100), "look_ahead": Vector2(0, 250), "screen_target_y": Vector2(0.3, 0.6), "screen_margin_y": Vector2(0.1, 0.3), "vertical_response": Vector2(0.5, 60), "horizontal_response": Vector2(0.25, 6), "max_speed": Vector2(400, 8000)}
const FOLLOW_HEIGHT: float = 1100.0
const FOLLOW_REFERENCE_WIDTH: float = 800.0
const AUTHORED_FOLLOW_ZOOM: float = 2.0
const HORIZONTAL_TRAVEL: float = 55.0
var table_bounds: Rect2
var camera_target: Vector2
var camera_focus: Vector2
var _camera_offset: Vector3
var _camera_viewport_size: Vector2
var ball: PlaygroundBall
var flippers: Array[PlaygroundFlipper] = []
var ring_field: RingField
var ball_visual: MeshInstance3D
var flipper_visuals: Array[Node3D] = []
var flipper_retracted_visuals: Array[Node3D] = []
var checkpoint_visuals: Array[Dictionary] = []
var serve_visuals: Array[Dictionary] = []
var ring_visuals: Array[MeshInstance3D] = []
var ring_pickups: Dictionary = {}
var physics_overlay: Node3D
var chunk_overlay: Node3D
var connector_overlay: Node3D
var construction_grid_overlay: Node3D
var bumper_visuals: Dictionary = {}
var flash_times: Dictionary = {}
var camera: Camera3D
var _last_ball_position: Vector2
var dynamic_geometry: ImmediateMesh
var authored_mode := false
var authored_cell_size := 50.0
var _world_environment: WorldEnvironment
var _key_light: DirectionalLight3D

static func map_point(point: Vector2, height: float = 0.0) -> Vector3:
 return Vector3(point.x * SCALE, height, point.y * SCALE)

static func unmap_point(point: Vector3) -> Vector2:
 return Vector2(point.x / SCALE, point.z / SCALE)

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
 var result := StandardMaterial3D.new()
 result.albedo_color = color
 result.roughness = 0.65
 if glow > 0.0:
  result.emission_enabled = true
  result.emission = color
  result.emission_energy_multiplier = glow
 return result

func debug_material(color: Color) -> StandardMaterial3D:
 var result := material(color)
 result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 result.no_depth_test = true
 result.render_priority = 1
 return result

func mesh_node(mesh: Mesh, mat: Material, where: Vector3, parent: Node = self) -> MeshInstance3D:
 var instance := MeshInstance3D.new()
 instance.mesh = mesh
 instance.material_override = mat
 instance.position = where
 if mat is BaseMaterial3D and mat.no_depth_test:
  instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

func build(chunks: Array[TableChunk], junctions: Variant = [], bounds: Rect2 = Rect2()) -> void:
 authored_mode = false
 _build_shared(chunks, junctions, bounds)

func build_authored(runtime: Dictionary, bounds: Rect2, cell_size: float) -> void:
 # The shared camera, lights and moving visuals accept compiler data directly.
 # An authored Act never needs a generated chunk or procedural layout.
 authored_mode = true
 authored_cell_size = cell_size
 camera_follow_enabled = false
 _build_shared([], [], bounds)
 _build_authored_objects(runtime)
 _build_authored_grid(bounds, cell_size)

func rebuild_playfield(playfield: RefCounted, chunks: Array[TableChunk], layout: Dictionary) -> void:
 # The game owns one presentation/camera for every level source. Only disposable
 # terrain, moving-object meshes and per-layout feedback are replaced here.
 var overlays: Array[bool] = []
 for overlay: Node3D in [physics_overlay, chunk_overlay, connector_overlay, construction_grid_overlay]:
  overlays.append(is_instance_valid(overlay) and overlay.visible)
 var follow := camera_follow_enabled
 _clear_playfield_geometry()
 if playfield.document != null:
  build_authored(playfield.authored_runtime, playfield.bounds, float(playfield.document.cell_size))
 else:
  build(chunks, layout.get("junctions", []), playfield.bounds)
 camera_follow_enabled = follow
 reset_camera(ball.serve_position)
 var rebuilt: Array[Node3D] = [physics_overlay, chunk_overlay, connector_overlay, construction_grid_overlay]
 for i in rebuilt.size():
  rebuilt[i].visible = overlays[i]

func _clear_playfield_geometry() -> void:
 for child: Node in get_children():
  if child == camera or child is WorldEnvironment or child is Light3D or child.get_meta("keep_on_playfield_rebuild", false):
   continue
  remove_child(child)
  child.free()
 flipper_visuals.clear()
 flipper_retracted_visuals.clear()
 checkpoint_visuals.clear()
 serve_visuals.clear()
 ring_visuals.clear()
 ring_pickups.clear()
 bumper_visuals.clear()
 flash_times.clear()
 _last_ball_position = ball.position

func _build_shared(chunks: Array[TableChunk], junctions: Variant, bounds: Rect2) -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 table_bounds = bounds
 if not table_bounds.has_area():
  for chunk: TableChunk in chunks:
   var chunk_bounds := chunk.data.world_rect(Rect2(Vector2.ZERO, Vector2(chunk.data.grid_dimensions) * ChunkData.GRID_SIZE))
   table_bounds = table_bounds.merge(chunk_bounds) if table_bounds.has_area() else chunk_bounds
 if not is_instance_valid(_world_environment):
  _world_environment = WorldEnvironment.new()
  _world_environment.environment = Environment.new()
  _world_environment.environment.background_mode = Environment.BG_COLOR
  _world_environment.environment.background_color = Color("08121e")
  _world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
  _world_environment.environment.ambient_light_color = Color("a6d1ed")
  _world_environment.environment.ambient_light_energy = 0.45
  add_child(_world_environment)
 if not is_instance_valid(_key_light):
  _key_light = DirectionalLight3D.new()
  _key_light.name = "TableKeyLight"
  _key_light.rotation_degrees = Vector3(-50, -30, 0)
  _key_light.light_energy = 1.15
  _key_light.shadow_enabled = true
  # Reserve shadow detail near the camera, including close-up views of the ball.
  _key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
  _key_light.directional_shadow_blend_splits = true
  _key_light.shadow_bias = 0.1
  _key_light.shadow_normal_bias = 2.0
  add_child(_key_light)
 _key_light.directional_shadow_max_distance = maxf(40.0, table_bounds.size.length() * SCALE * 2.5)
 if not is_instance_valid(camera):
  camera = Camera3D.new()
  camera.name = "TableCamera"
  add_child(camera)
 set_camera_preset(camera_preset)
 camera.current = true
 var floor_mesh := BoxMesh.new()
 floor_mesh.size = Vector3((table_bounds.size.x + 15.0) * SCALE, 0.32, (table_bounds.size.y + 50.0) * SCALE)
 var floor_visual := mesh_node(floor_mesh, material(Color("153c4b")), map_point(table_bounds.get_center(), -0.16))
 floor_visual.name = "TableFloor"
 # Receive object shadows without self-shadow artifacts on the large, flat slab.
 floor_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var rail_mat := terrain_side_material()
 var rail_top := terrain_top_material()
 _pinball_materials = PinballModels.materials(_pinball_theme_id(), pinball_palette)
 var gold := material(Color("ffd568"), 0.08)
 var grid_mat := material(Color("1b414c"))
 for x in range(int(table_bounds.position.x + 100), int(table_bounds.end.x), 100):
  _floor_line(Vector2(x, table_bounds.position.y + 80), Vector2(x, table_bounds.end.y - 30), grid_mat)
 for y in range(int(table_bounds.position.y + 100), int(table_bounds.end.y), 100):
  _floor_line(Vector2(table_bounds.position.x + 65, y), Vector2(table_bounds.end.x - 65, y), grid_mat)
 physics_overlay = Node3D.new()
 physics_overlay.name = "PhysicsGeometryOverlay"
 add_child(physics_overlay)
 physics_overlay.visible = false
 dynamic_geometry = ImmediateMesh.new()
 var dynamic_debug := MeshInstance3D.new()
 dynamic_debug.mesh = dynamic_geometry
 dynamic_debug.material_override = debug_material(Color("70ff85"))
 dynamic_debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 physics_overlay.add_child(dynamic_debug)
 chunk_overlay = Node3D.new()
 chunk_overlay.name = "ChunkBoundaryOverlay"
 add_child(chunk_overlay)
 chunk_overlay.visible = false
 connector_overlay = Node3D.new()
 connector_overlay.name = "ConnectorRegionOverlay"
 add_child(connector_overlay)
 connector_overlay.visible = false
 construction_grid_overlay = Node3D.new()
 construction_grid_overlay.name = "ConstructionGridOverlay"
 add_child(construction_grid_overlay)
 construction_grid_overlay.visible = false
 var debug_mat := debug_material(Color("70ff85"))
 var boundary_mat := debug_material(Color("d8a9ff"))
 for chunk: TableChunk in chunks:
  if not chunk.data.construction_grid.is_empty():
   _build_construction_grid(chunk.data)
  for item: Dictionary in chunk.descriptors:
   match item.kind:
    "rail":
     var rail := Node3D.new()
     rail.position = map_point(item.a)
     rail.rotation.y = -(item.b - item.a).angle()
     add_child(rail)
     var length: float = item.a.distance_to(item.b) * SCALE
     _paddle(length, item.radius * SCALE, RAIL_HEIGHT, 0.0, rail_mat, rail)
     _paddle(length, item.radius * SCALE * 0.68, RAIL_CAP_HEIGHT, RAIL_HEIGHT, rail_top, rail)
     if item.get("checkpoint_only", false):
      var guide := line(item.a, item.b, 0.025, 0.025, material(Color("82978d")))
      checkpoint_visuals.append({"visual": rail, "guide": guide, "body": item.body, "a": item.a, "b": item.b, "radius": item.radius})
     else:
      _capsule_outline(item.a, item.b, item.radius, debug_mat)
    "circle":
     var body_visual := Node3D.new()
     body_visual.position = map_point(item.position)
     add_child(body_visual)
     var radius: float = item.radius * SCALE
     PinballModels.round_bumper(self, body_visual, radius, 1.0, _pinball_materials)
     bumper_visuals[item.body.get_instance_id()] = body_visual
     _circle_outline(item.position, item.radius, debug_mat)
    "flipper_mount":
     var housing := mesh_node(_prism(item.points, 0.18, rail_mat, rail_top), null, map_point(item.position))
     housing.name = "WallFlipperHousing"
     # The bearing is part of the same solid footprint; the moving paddle sits
     # above its deck. No presentation object owns gameplay collisions.
     mesh_node(cylinder(ChunkData.MOUNT_RADIUS * SCALE, 0.05), rail_mat, map_point(item.position, 0.205))
     for i in item.points.size():
      line(item.position + item.points[i], item.position + item.points[(i + 1) % item.points.size()], 0.012, OVERLAY_HEIGHT, debug_mat, physics_overlay)
    "triangle":
     var body_visual := Node3D.new()
     body_visual.position = map_point(item.position)
     add_child(body_visual)
     PinballModels.triangle_bumper(self, body_visual, item.points, 0.34, _pinball_materials)
     bumper_visuals[item.body.get_instance_id()] = body_visual
     for i in item.points.size():
      line(item.position + item.points[i], item.position + item.points[(i + 1) % item.points.size()], 0.012, OVERLAY_HEIGHT, debug_mat, physics_overlay)
  var chunk_bounds := chunk.data.world_rect(Rect2(Vector2.ZERO, Vector2(chunk.data.grid_dimensions) * ChunkData.GRID_SIZE))
  _rect_outline(chunk_bounds, boundary_mat, chunk_overlay)
  for connection: Rect2 in [chunk.data.top_connection, chunk.data.bottom_connection]:
   if connection.size.x > 0:
    _rect_outline(chunk.data.world_rect(connection), boundary_mat, connector_overlay)
  var title := chunk.data.title
  var title_parts := title.split(" / ", true, 1)
  if title_parts.size() == 2 and title_parts[0].is_valid_int():
   title = title_parts[1]
  _label("%02d / %s" % [chunks.find(chunk) + 1, title], chunk.data.world_point(Vector2(chunk.data.grid_dimensions.x * 50.0, 95 if chunk == chunks[0] else 40)), 18, Color("71cbbf"))
 if junctions is Rect2:
  if junctions.has_area():
   _rect_outline(junctions, debug_mat, connector_overlay)
 else:
  for junction: Dictionary in junctions:
   if junction.passage.has_area():
    _rect_outline(junction.passage, debug_mat, connector_overlay)
 for ring: Dictionary in ring_field.rings:
  var torus := TorusMesh.new()
  torus.inner_radius = ring_field.ring_radius * SCALE * 0.55 if authored_mode else 0.075
  torus.outer_radius = ring_field.ring_radius * SCALE if authored_mode else 0.135
  torus.rings = 16
  torus.ring_segments = 8
  ring_visuals.append(mesh_node(torus, gold, map_point(ring.position, ring_height())))
 if not ring_field.pickup_claimed.is_connected(_on_ring_claimed):
  ring_field.pickup_claimed.connect(_on_ring_claimed)
 if not ring_field.rack_reset.is_connected(clear_ring_pickups):
  ring_field.rack_reset.connect(clear_ring_pickups)
 clear_ring_pickups()
 for flipper: PlaygroundFlipper in flippers:
  var pivot := Node3D.new()
  pivot.position = map_point(flipper.position)
  add_child(pivot)
  var height_scale := flipper.radius / PlaygroundFlipper.RADIUS if authored_mode else 1.0
  PinballModels.flipper(self, pivot, flipper.length * SCALE, flipper.radius * SCALE, height_scale, _pinball_materials)
  flipper_visuals.append(pivot)
  var retracted := Node3D.new()
  retracted.position = pivot.position
  add_child(retracted)
  _paddle(flipper.length * SCALE, flipper.radius * SCALE * 0.45, 0.02 * height_scale, 0.006, material(Color("82978d")), retracted)
  flipper_retracted_visuals.append(retracted)
 ball_visual = mesh_node(sphere(ball.radius * SCALE), material(Color("4f97ff"), 0.12), map_point(ball.position, ball_height()))
 var stripe := TorusMesh.new()
 stripe.inner_radius = ball.radius * SCALE * 0.96 if authored_mode else 0.134
 stripe.outer_radius = ball.radius * SCALE * 1.04 if authored_mode else 0.146
 mesh_node(stripe, material(Color("e5f4ff")), Vector3.ZERO, ball_visual)
 # Drain and serve guides have no gameplay collision.
 for chunk: TableChunk in chunks:
  if chunk.data.markers.has("serve"):
   _build_serve_marker(chunk.data)
  if chunk.data.markers.has("drain"):
   var drain := chunk.data.world_point(chunk.data.markers.drain)
   line(drain + Vector2(-40, -25), drain + Vector2(40, -25), 0.035, 0.01, material(Color("ef6473"), 0.4))
   _label("DRAIN", drain + Vector2(0, -60), 18, Color("ee8693"))
 _update_serve_markers()
 _update_checkpoint_visuals()

func ball_height() -> float:
 return (ball.radius * SCALE + authored_cell_size * SCALE * 0.02 if authored_mode else BALL_HEIGHT) + ball.ramp_height * SCALE

func ring_height() -> float:
 return ring_field.ring_radius * SCALE + authored_cell_size * SCALE * 0.03 if authored_mode else RING_HEIGHT

func _build_authored_objects(runtime: Dictionary) -> void:
 var mechanics_visual := preload("res://scripts/authored_act/mechanics_presentation.gd").new()
 add_child(mechanics_visual)
 mechanics_visual.build(self, runtime)
 var debug_mat := debug_material(Color("70ff85"))
 var overlay_vertices := PackedVector3Array()
 for item: Dictionary in runtime.objects:
  if item.type in ["left_flipper", "right_flipper"] or item.has("mechanic"):
   continue # Shared moving visuals above already use the real body dimensions.
  var visual := Node3D.new()
  visual.name = "Authored_" + str(item.type)
  visual.position = map_point(item.position)
  visual.rotation.y = -deg_to_rad(float(item.rotation_degrees))
  add_child(visual)
  if item.type == "round_bumper":
   var radius: float = item.radius * SCALE
   var height_scale := float(item.radius) / 38.0
   PinballModels.round_bumper(self, visual, radius, height_scale, _pinball_materials)
   for i in 32:
    overlay_vertices.append(map_point(item.position + Vector2.from_angle(i * TAU / 32) * item.radius, OVERLAY_HEIGHT))
    overlay_vertices.append(map_point(item.position + Vector2.from_angle((i + 1) * TAU / 32) * item.radius, OVERLAY_HEIGHT))
  else:
   var points: PackedVector2Array = item.points
   var height := authored_cell_size * SCALE * 0.18 * float(preload("res://scripts/act_editor/gameplay_objects.gd").properties(item).scale)
   PinballModels.triangle_bumper(self, visual, points, height, _pinball_materials)
   for i in points.size():
    var a: Vector2 = item.position + points[i].rotated(deg_to_rad(float(item.rotation_degrees)))
    var b: Vector2 = item.position + points[(i + 1) % points.size()].rotated(deg_to_rad(float(item.rotation_degrees)))
    overlay_vertices.append(map_point(a, OVERLAY_HEIGHT))
    overlay_vertices.append(map_point(b, OVERLAY_HEIGHT))
  bumper_visuals[item.body.get_instance_id()] = visual
 for terrain: Dictionary in runtime.terrain:
  var points: PackedVector2Array = terrain.points
  var count := points.size() if terrain.closed else points.size() - 1
  for i in count:
   overlay_vertices.append(map_point(points[i], OVERLAY_HEIGHT))
   overlay_vertices.append(map_point(points[(i + 1) % points.size()], OVERLAY_HEIGHT))
 if not overlay_vertices.is_empty():
  # Static authoring guides share one draw call, including every exact open-path
  # segment. Creating a cylinder node per segment made curved Acts slow to load.
  var arrays: Array = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = overlay_vertices
  var overlay_mesh := ArrayMesh.new()
  overlay_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
  var overlay := mesh_node(overlay_mesh, debug_mat, Vector3.ZERO, physics_overlay)
  overlay.name = "AuthoredStaticPhysicsLines"

func _build_authored_grid(bounds: Rect2, cell_size: float) -> void:
 var grid_mat := debug_material(Color("437f9e"))
 # The bounds include the automatic gutter, which has no terrain grid.
 var terrain_end := bounds.end - Vector2(0, cell_size * AuthoredActData.RED_GUTTER_CELLS)
 for x in range(int(round(bounds.size.x / cell_size)) + 1):
  var at := bounds.position.x + x * cell_size
  line(Vector2(at, bounds.position.y), Vector2(at, terrain_end.y), 0.005, OVERLAY_HEIGHT, grid_mat, construction_grid_overlay)
 for y in range(int(round((terrain_end.y - bounds.position.y) / cell_size)) + 1):
  var at := bounds.position.y + y * cell_size
  line(Vector2(bounds.position.x, at), Vector2(terrain_end.x, at), 0.005, OVERLAY_HEIGHT, grid_mat, construction_grid_overlay)

func _build_serve_marker(data: ChunkData) -> void:
 var serve := data.world_point(data.markers.serve)
 var marker := Node3D.new()
 marker.name = "ServeMarker_" + data.chunk_id
 add_child(marker)
 var ink := material(Color("82978d"))
 # Flat corner marks identify a starting position without suggesting a physical cup.
 for side_x: float in [-1.0, 1.0]:
  for side_y: float in [-1.0, 1.0]:
   var corner := serve + Vector2(side_x, side_y) * 22.0
   line(corner, corner - Vector2(side_x * 10.0, 0), 0.012, 0.02, ink, marker)
   line(corner, corner - Vector2(0, side_y * 10.0), 0.012, 0.02, ink, marker)
 # A dedicated parent keeps this gameplay hint visible in themed presentations.
 var hint := Label3D.new()
 hint.text = "ENTER / X\nROLL IN"
 hint.font_size = 18
 hint.pixel_size = 0.012
 hint.modulate = Color("ffe27a")
 hint.outline_size = 2
 hint.rotation.x = -PI / 2.0
 hint.position = map_point(serve + Vector2(100 if data.mirrored else -100, 55), 0.04)
 marker.add_child(hint)
 serve_visuals.append({"serve": serve, "ink": ink, "hint": hint})

func _update_serve_markers() -> void:
 for marker: Dictionary in serve_visuals:
  var active: bool = marker.serve.is_equal_approx(ball.serve_position)
  var waiting: bool = active and ball.serve_pending
  marker.hint.visible = waiting
  marker.ink.albedo_color = Color("ffe27a") if waiting else Color("82978d")

func _update_checkpoint_visuals() -> void:
 for checkpoint: Dictionary in checkpoint_visuals:
  var active: bool = is_instance_valid(checkpoint.body) and checkpoint.body.collision_layer != 0
  checkpoint.visual.visible = active
  checkpoint.guide.visible = not active
 for i in flippers.size():
  flipper_visuals[i].visible = flippers[i].enabled
  flipper_retracted_visuals[i].visible = not flippers[i].enabled
  flipper_retracted_visuals[i].rotation.y = -flippers[i].rotation

func set_camera_preset(index: int) -> void:
 camera_preset = clampi(index, CameraPreset.TOP_DOWN, CameraPreset.DRAMATIC_PINBALL)
 reset_camera()

func set_camera_follow(enabled: bool) -> void:
 if enabled != camera_follow_enabled:
  overview_zoom = 1.0
  overview_focus = Vector2.INF
 camera_follow_enabled = enabled
 reset_camera()

func handle_overview_input(event: InputEvent) -> bool:
 if camera_follow_enabled or not is_instance_valid(camera) or not camera.current:
  return false
 if event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_MIDDLE:
   return true
  if not event.pressed or event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
   return false
  var anchor := _overview_floor_point(event.position)
  var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
  overview_zoom = clampf(overview_zoom * pow(1.15, direction * event.factor), 0.25, 20.0)
  _configure_camera()
  camera_focus += anchor - _overview_floor_point(event.position)
 elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
  camera_focus += _overview_floor_point(event.position - event.relative) - _overview_floor_point(event.position)
 else:
  return false
 overview_focus = camera_focus
 camera_target = camera_focus
 camera.position = map_point(camera_focus) + _camera_offset
 return true

func _overview_floor_point(screen: Vector2) -> Vector2:
 var origin := camera.project_ray_origin(screen)
 var ray := camera.project_ray_normal(screen)
 if absf(ray.y) < 0.001:
  return camera_focus
 return unmap_point(origin - ray * (origin.y / ray.y))

func set_camera_value(key: String, value: float) -> void:
 if not CAMERA_LIMITS.has(key):
  return
 var limits: Vector2 = CAMERA_LIMITS[key]
 camera_settings[key] = clampf(value, limits.x, limits.y)
 if key == "zoom":
  reset_camera()

func reset_camera(at: Vector2 = Vector2.INF) -> void:
 if not is_instance_valid(camera):
  return
 var point := ball.position if at == Vector2.INF else at
 camera_focus = _clamp_focus(Vector2(_horizontal_follow_target(point.x), point.y)) if camera_follow_enabled else table_bounds.get_center()
 if not camera_follow_enabled and overview_focus != Vector2.INF:
  camera_focus = overview_focus
 camera_target = camera_focus
 _configure_camera()
 if camera_follow_enabled:
  camera_focus.y = _framed_focus(camera_focus, point).y
  camera_focus = _keep_ball_in_view(_clamp_focus(camera_focus), point)
  camera_target = camera_focus
  camera.position = map_point(camera_focus) + _camera_offset

func _follow_zoom() -> float:
 return float(camera_settings.zoom) * (AUTHORED_FOLLOW_ZOOM if authored_mode else 1.0)

func _follow_window_size() -> Vector2:
 # Authored gameplay uses a close local window. Overview still fits the full Act.
 # Zoom changes only framing, never the uniformly mapped physical world.
 var scale := ball.radius / PlaygroundBall.RADIUS
 var width := minf(table_bounds.size.x, FOLLOW_REFERENCE_WIDTH * scale) if authored_mode else table_bounds.size.x
 return (Vector2(width, minf(FOLLOW_HEIGHT * scale, table_bounds.size.y)) / _follow_zoom()).min(table_bounds.size)

func _horizontal_follow_target(x: float) -> float:
 var center := table_bounds.get_center().x
 if _follow_window_size().x < table_bounds.size.x:
  return x # A cropped play window must track side lanes as well as vertical play.
 return center + clampf((x - center) * 0.18, -HORIZONTAL_TRAVEL, HORIZONTAL_TRAVEL)

func _clamp_focus(point: Vector2) -> Vector2:
 var center := table_bounds.get_center()
 var half_window := _follow_window_size() * 0.5
 var x := clampf(point.x, center.x - HORIZONTAL_TRAVEL, center.x + HORIZONTAL_TRAVEL)
 if half_window.x * 2.0 < table_bounds.size.x:
  x = clampf(point.x, table_bounds.position.x + half_window.x, table_bounds.end.x - half_window.x)
 return Vector2(x, clampf(point.y, table_bounds.position.y + half_window.y, table_bounds.end.y - half_window.y))

func _configure_camera() -> void:
 # Fit the floor and raised-object envelope mathematically at the current aspect.
 # Follow mode fits a local window; overview fits the complete playfield bounds.
 _camera_viewport_size = Vector2(camera.get_viewport().size)
 var aspect := _camera_viewport_size.x / maxf(1.0, _camera_viewport_size.y)
 var size := table_bounds.size + Vector2(15, 50)
 if camera_follow_enabled:
  size = _follow_window_size() + Vector2(15.0 + HORIZONTAL_TRAVEL * 2.0, 50.0) * (ball.radius / PlaygroundBall.RADIUS) / _follow_zoom()
 camera.near = 0.1
 camera.keep_aspect = Camera3D.KEEP_HEIGHT
 if camera_preset == CameraPreset.TOP_DOWN:
  camera.projection = Camera3D.PROJECTION_ORTHOGONAL
  camera.size = maxf(size.y, size.x / aspect) * SCALE / 0.94
  if not camera_follow_enabled:
   camera.size /= overview_zoom
  _camera_offset = Vector3(0, maxf(20.0, table_bounds.size.y * SCALE), 0)
  camera.position = map_point(camera_focus) + _camera_offset
  camera.look_at(map_point(camera_focus), Vector3.FORWARD)
 else:
  camera.projection = Camera3D.PROJECTION_PERSPECTIVE
  var dramatic := camera_preset == CameraPreset.DRAMATIC_PINBALL
  var elevation := deg_to_rad(50.0 if dramatic else 60.0)
  camera.fov = 52.0 if dramatic else 40.0
  var normal := Vector3(0, sin(elevation), cos(elevation))
  var screen_up := Vector3(0, cos(elevation), -sin(elevation))
  var tan_y := tan(deg_to_rad(camera.fov) * 0.5) * 0.94
  var tan_x := tan_y * aspect
  var distance := 1.0
  for x: float in [-size.x * SCALE * 0.5, size.x * SCALE * 0.5]:
   for z: float in [-size.y * SCALE * 0.5, size.y * SCALE * 0.5]:
    for height: float in [-0.32, 0.60]:
     var point := Vector3(x, height, z)
     distance = maxf(distance, point.dot(normal) + maxf(absf(point.x) / tan_x, absf(point.dot(screen_up)) / tan_y))
  _camera_offset = normal * distance
  if not camera_follow_enabled:
   _camera_offset /= overview_zoom
  camera.position = map_point(camera_focus) + _camera_offset
  camera.look_at(map_point(camera_focus))
 camera.far = _camera_offset.length() + table_bounds.size.length() * SCALE + 10.0

func _update_camera(delta: float) -> void:
 if Vector2(camera.get_viewport().size) != _camera_viewport_size:
  _configure_camera()
  if camera_follow_enabled:
   camera_focus = _keep_ball_in_view(camera_focus)
   camera.position = map_point(camera_focus) + _camera_offset
 if not camera_follow_enabled or delta <= 0.0:
  return
 # The ball only supplies observations. No transform or impulse is written to physics.
 var desired := _framed_focus(Vector2(_horizontal_follow_target(ball.position.x), ball.position.y))
 camera_target = camera_focus
 var horizontal_error := desired.x - camera_focus.x
 var horizontal_dead_zone := float(camera_settings.dead_zone_x) / _follow_zoom()
 if absf(horizontal_error) > horizontal_dead_zone:
  camera_target.x = desired.x - signf(horizontal_error) * horizontal_dead_zone
 var vertical_error := desired.y - camera_focus.y
 var dead_zone := float(camera_settings.dead_zone_y) / _follow_zoom()
 if absf(vertical_error) > dead_zone:
  camera_target.y = desired.y - signf(vertical_error) * dead_zone
 camera_target = _clamp_focus(camera_target)
 # Exponential response is frame-rate independent; the speed limit bounds impact jumps.
 var step := minf(delta, 0.05)
 var next := Vector2(lerpf(camera_focus.x, camera_target.x, 1.0 - exp(-float(camera_settings.horizontal_response) * step)), lerpf(camera_focus.y, camera_target.y, 1.0 - exp(-float(camera_settings.vertical_response) * step)))
 camera_focus += (next - camera_focus).limit_length(float(camera_settings.max_speed) * step)
 # Readability wins over damping, frame caps and table-edge framing. Apply this
 # after the normal movement cap, including at 1x zoom and after long frames.
 camera_focus = _keep_ball_in_view(_clamp_focus(camera_focus))
 camera.position = map_point(camera_focus) + _camera_offset

func _framed_focus(focus: Vector2, at: Vector2 = Vector2.INF) -> Vector2:
 var point := ball.position if at == Vector2.INF else at
 camera.position = map_point(focus) + _camera_offset
 var screen := camera.unproject_position(map_point(point, ball_height()))
 screen.y = _camera_viewport_size.y * float(camera_settings.screen_target_y)
 var framed := _focus_for_screen_point(focus, screen, point)
 return Vector2(focus.x, framed.y - float(camera_settings.look_ahead) / _follow_zoom())

func _keep_ball_in_view(focus: Vector2, at: Vector2 = Vector2.INF) -> Vector2:
 # Project on the ball's visual plane. Safety correction is deliberately not
 # speed-limited: even an upward shot during a frame hitch must remain visible.
 camera.position = map_point(focus) + _camera_offset
 var point := ball.position if at == Vector2.INF else at
 var world := map_point(point, ball_height())
 var screen := camera.unproject_position(world)
 var margin := Vector2(0.12, float(camera_settings.screen_margin_y))
 var safe := Rect2(_camera_viewport_size * margin, _camera_viewport_size * (Vector2.ONE - 2.0 * margin))
 var inside := screen.clamp(safe.position, safe.end)
 if inside.is_equal_approx(screen):
  return focus
 return _focus_for_screen_point(focus, inside, point)

func _focus_for_screen_point(focus: Vector2, screen: Vector2, point: Vector2) -> Vector2:
 var world := map_point(point, ball_height())
 var origin := camera.project_ray_origin(screen)
 var ray := camera.project_ray_normal(screen)
 if absf(ray.y) < 0.001:
  return focus
 var on_plane := origin + ray * ((world.y - origin.y) / ray.y)
 return focus + unmap_point(world - on_plane)

func terrain_side_material() -> Material:
 return material(RAIL_SIDE_COLOR)

func terrain_top_material() -> Material:
 return material(RAIL_TOP_COLOR)

func _paddle(length: float, radius: float, height: float, base: float, mat: Material, parent: Node3D) -> void:
 # Extrude the exact 2D capsule footprint; only the inset top trim is smaller.
 var bar := BoxMesh.new()
 bar.size = Vector3(length, height, radius * 2.0)
 mesh_node(bar, mat, Vector3(length * 0.5, base + height * 0.5, 0), parent)
 mesh_node(cylinder(radius, height), mat, Vector3(0, base + height * 0.5, 0), parent)
 mesh_node(cylinder(radius, height), mat, Vector3(length, base + height * 0.5, 0), parent)

func _floor_line(a: Vector2, b: Vector2, mat: Material) -> void:
 # Flat markings avoid tiny cylinder silhouettes and shadows flickering at shallow angles.
 var plane := PlaneMesh.new()
 plane.size = Vector2(a.distance_to(b) * SCALE, 0.014)
 var marking := mesh_node(plane, mat, map_point((a + b) * 0.5, 0.006))
 marking.rotation.y = -(b - a).angle()
 marking.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _rect_outline(rect: Rect2, mat: Material, parent: Node3D) -> void:
 var points: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
 for i in 4:
  line(points[i], points[(i + 1) % 4], 0.018, OVERLAY_HEIGHT, mat, parent)

func _build_construction_grid(data: ChunkData) -> void:
 var metadata: Dictionary = data.construction_grid
 var size: float = metadata.cell_size
 var dimensions: Vector2i = metadata.dimensions
 var grid_material := debug_material(Color("437f9e"))
 var footprint_material := debug_material(Color("dfab63"))
 for x in range(dimensions.x + 1):
  line(data.world_point(Vector2(x, 0) * size), data.world_point(Vector2(x, dimensions.y) * size), 0.007, OVERLAY_HEIGHT, grid_material, construction_grid_overlay)
  _label(str(x), data.world_point(Vector2(x, 0.35) * size), 16, Color("a7daee"), construction_grid_overlay)
 for y in range(dimensions.y + 1):
  line(data.world_point(Vector2(0, y) * size), data.world_point(Vector2(dimensions.x, y) * size), 0.007, OVERLAY_HEIGHT, grid_material, construction_grid_overlay)
  _label(str(y), data.world_point(Vector2(0.35, y) * size), 16, Color("a7daee"), construction_grid_overlay)
 for placement: Dictionary in metadata.placements:
  var footprint: Rect2 = placement.footprint
  # Footprints describe authoring extents, not colliders or guaranteed free space.
  if footprint.has_area():
   _rect_outline(data.world_rect(Rect2(footprint.position * size, footprint.size * size)), footprint_material, construction_grid_overlay)
  var cell: Vector2i = placement.cell
  _label("%d,%d" % [cell.x, cell.y], data.world_point((Vector2(cell) + Vector2(0.25, 0.35)) * size), 13, Color("ffcf8c"), construction_grid_overlay)

func _label(text: String, point: Vector2, font_size: int, color: Color, parent: Node3D = self) -> void:
 var label := Label3D.new()
 label.text = text
 label.font_size = font_size
 label.pixel_size = 0.012
 label.modulate = color
 label.outline_size = 0
 label.rotation.x = -PI / 2.0
 label.position = map_point(point, 0.01)
 if parent == construction_grid_overlay:
  label.no_depth_test = true
  label.pixel_size = 0.016
 parent.add_child(label)

func _circle_outline(center: Vector2, radius: float, mat: Material) -> void:
 for i in 32:
  line(center + Vector2.from_angle(i * TAU / 32) * radius, center + Vector2.from_angle((i + 1) * TAU / 32) * radius, 0.012, OVERLAY_HEIGHT, mat, physics_overlay)

func _capsule_outline(a: Vector2, b: Vector2, radius: float, mat: Material) -> void:
 var normal := (b - a).normalized().orthogonal() * radius
 line(a + normal, b + normal, 0.012, OVERLAY_HEIGHT, mat, physics_overlay)
 line(a - normal, b - normal, 0.012, OVERLAY_HEIGHT, mat, physics_overlay)
 _circle_outline(a, radius, mat)
 _circle_outline(b, radius, mat)

func _prism(points: PackedVector2Array, height: float, side_mat: Material, top_mat: Material) -> ArrayMesh:
 # Mirrored chunks reverse polygon winding; normalize only the visual copy.
 points = points.duplicate()
 if Geometry2D.is_polygon_clockwise(points):
  points.reverse()
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(top_mat)
 var indices: PackedInt32Array = Geometry2D.triangulate_polygon(points)
 for index in indices:
  surface.add_vertex(Vector3(points[index].x * SCALE, height, points[index].y * SCALE))
 surface.generate_normals()
 var mesh := surface.commit()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(side_mat)
 for i in points.size():
  var a := Vector3(points[i].x * SCALE, 0, points[i].y * SCALE)
  var b := Vector3(points[(i + 1) % points.size()].x * SCALE, 0, points[(i + 1) % points.size()].y * SCALE)
  # Keep each vertical face's outward normal. Averaging across acute corners
  # cancels opposing normals and produces black wedges in wall texture blending.
  surface.set_normal(Vector3((b - a).z, 0, -(b - a).x).normalized())
  for vertex: Vector3 in [a, b, a + Vector3.UP * height, b, b + Vector3.UP * height, a + Vector3.UP * height]:
   surface.add_vertex(vertex)
 return surface.commit(mesh)

func flash_bumper(body: Node) -> void:
 flash_times[body.get_instance_id()] = 0.12

func _on_ring_claimed(index: int) -> void:
 var visual := ring_visuals[index]
 # Start from the authored position even if the rack reset and pickup share a frame.
 visual.position = map_point(ring_field.rings[index].position, ring_height())
 visual.scale = Vector3.ONE
 visual.visible = true
 ring_pickups[index] = {"start": visual.position, "elapsed": 0.0}

func clear_ring_pickups() -> void:
 # Reset/drain cancels only presentation; already awarded rings stay collected.
 ring_pickups.clear()
 for i in ring_visuals.size():
  ring_visuals[i].visible = ring_field.rings[i].active
  ring_visuals[i].position = map_point(ring_field.rings[i].position, ring_height())
  ring_visuals[i].scale = Vector3.ONE

func _update_ring_visuals(delta: float) -> void:
 for i in ring_visuals.size():
  var visual := ring_visuals[i]
  if ring_pickups.has(i):
   var pickup: Dictionary = ring_pickups[i]
   pickup.elapsed = minf(float(pickup.elapsed) + delta, RING_PICKUP_DURATION)
   var progress: float = pickup.elapsed / RING_PICKUP_DURATION
   # Quadratic ease-in accelerates toward the current visible ball every frame.
   # Once claimed, neither distance nor the gameplay radius can interrupt flight.
   visual.position = (pickup.start as Vector3).lerp(ball_visual.position, progress * progress)
   visual.scale = Vector3.ONE * lerpf(1.0, 0.25, smoothstep(0.7, 1.0, progress))
   if progress >= 1.0:
    visual.visible = false
    ring_pickups.erase(i)
  else:
   visual.visible = ring_field.rings[i].active
   if visual.visible:
    visual.position = map_point(ring_field.rings[i].position, ring_height())
    visual.scale = Vector3.ONE

func _process(delta: float) -> void:
 if get_tree().paused:
  delta = 0.0
 if not is_instance_valid(ball_visual):
  return
 _update_camera(delta)
 ball_visual.position = map_point(ball.position, ball_height())
 var travel: Vector2 = ball.position - _last_ball_position
 if travel.length() > 0.001 and travel.length() < 100:
  ball_visual.rotate(Vector3(travel.y, 0, -travel.x).normalized(), travel.length() / ball.radius)
 _last_ball_position = ball.position
 for i in flippers.size():
  flipper_visuals[i].rotation.y = -flippers[i].rotation
 _update_checkpoint_visuals()
 _update_serve_markers()
 _update_ring_visuals(delta)
 for id: int in flash_times.keys():
  flash_times[id] -= delta
  var mesh: Node3D = bumper_visuals[id]
  mesh.scale.y = 1.0 + maxf(0, float(flash_times[id])) * 2.0
  if flash_times[id] <= 0:
   mesh.scale.y = 1.0
   flash_times.erase(id)
 if physics_overlay.visible:
  _draw_dynamic_geometry()

func _draw_dynamic_geometry() -> void:
 dynamic_geometry.clear_surfaces()
 dynamic_geometry.surface_begin(Mesh.PRIMITIVE_LINES)
 _debug_circle(ball.position, ball.radius)
 for checkpoint: Dictionary in checkpoint_visuals:
  if checkpoint.body.collision_layer != 0:
   _debug_capsule(checkpoint.a, checkpoint.b, checkpoint.radius)
 for flipper: PlaygroundFlipper in flippers:
  if not flipper.enabled:
   continue
  var a: Vector2 = flipper.position
  var b: Vector2 = flipper.tip()
  _debug_capsule(a, b, flipper.radius)
 dynamic_geometry.surface_end()

func _debug_capsule(a: Vector2, b: Vector2, radius: float) -> void:
 var offset := (b - a).normalized().orthogonal() * radius
 for point: Vector2 in [a + offset, b + offset, a - offset, b - offset]:
  dynamic_geometry.surface_add_vertex(map_point(point, OVERLAY_HEIGHT))
 _debug_circle(a, radius)
 _debug_circle(b, radius)

func _debug_circle(center: Vector2, radius: float) -> void:
 for i in 32:
  dynamic_geometry.surface_add_vertex(map_point(center + Vector2.from_angle(i * TAU / 32) * radius, OVERLAY_HEIGHT))
  dynamic_geometry.surface_add_vertex(map_point(center + Vector2.from_angle((i + 1) * TAU / 32) * radius, OVERLAY_HEIGHT))

func ramp_materials() -> Dictionary:
 return {"deck": material(Color("9bb9c8")), "edge": material(Color("587788")),
  "support": material(Color("4c647b")), "accent": material(Color("dbe7ef"))}

func _pinball_theme_id() -> String:
 # Base and themed renderers share hardware without depending on theme scripts.
 for property in get_property_list():
  if property.name == "theme_definition":
   var definition: RefCounted = get("theme_definition")
   return str(definition.theme_id)
 return "default"
