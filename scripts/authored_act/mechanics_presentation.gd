extends Node3D
## Collisionless pinball visuals; theme materials never alter the shared rail geometry.
const Hardware := preload("res://scripts/atmosphere/hardware_palette.gd")
const RailPath = preload("res://scripts/authored_act/rail_path.gd")
const Gimmicks = preload("res://scripts/authored_act/gimmick_models.gd")
const BuzzModel = preload("res://scripts/enemies/buzz_bomber_model.gd")
var table: TablePresentation
var spinners: Array[Dictionary] = []
var fields: Array[Dictionary] = []
var gimmicks: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var elapsed := 0.0

func build(presenter: TablePresentation, runtime: Dictionary) -> void:
 table = presenter
 name = "AuthoredPinballVisuals"
 process_mode = Node.PROCESS_MODE_PAUSABLE
 for descriptor: Dictionary in runtime.objects:
  if not descriptor.has("mechanic"): continue
  var item: Dictionary = descriptor.mechanic
  match item.type:
   "sonic_loop": preload("res://scripts/authored_act/loop_visual.gd").build(table, self, item)
   "teleporter": preload("res://scripts/authored_act/teleporter.gd").build(table, self, item)
   "buzz_bomber": enemies.append(BuzzModel.build(table, self, item))
   "spinner": _spinner(item)
   "magnetic_field": _field(item)
   "elevated_rail": await _rail(item)
   "launch_tube", "moving_bumper", "score_chute", "drop_target_bank", "slingshot", "one_way_gate", "switch_target", "wall_switch", "spring", "lane_barrier", "diverter", "dash_panel":
    var entry := Gimmicks.build(table, self, item)
    if item.type == "moving_bumper": table.bumper_visuals[descriptor.body.get_instance_id()] = entry.puck
    gimmicks.append(entry)
    Gimmicks.update(entry)

func _box(size: Vector3, color: Color, at: Vector3, parent: Node3D, palette_key := "", source_key := "") -> MeshInstance3D:
 var mesh := BoxMesh.new()
 mesh.size = size
 return table.mesh_node(mesh, table.material(color) if palette_key.is_empty() else Hardware.fixed(table, palette_key, 0.0, false, source_key), at, parent)

func _spinner(item: Dictionary) -> void:
 var frame := Node3D.new()
 frame.position = table.map_point(item.position, 0.20)
 frame.rotation.y = -deg_to_rad(float(item.rotation_degrees))
 add_child(frame)
 var width := float(item.properties.width) * table.SCALE
 for side: float in [-1.0, 1.0]:
  _box(Vector3(0.035, 0.23, 0.045), Color.WHITE, Vector3(side * width / 2, -0.10, 0), frame, "spinner_frame")
 _box(Vector3(width + 0.08, 0.025, 0.025), Color.WHITE, Vector3.ZERO, frame, "spinner_frame", "spinner_crossbar")
 var paddle := Node3D.new()
 frame.add_child(paddle)
 _box(Vector3(width * 0.8, 0.16, 0.035), Color.WHITE, Vector3.ZERO, paddle, "spinner_paddle")
 _box(Vector3(width * 0.5, 0.055, 0.038), Color.WHITE, Vector3.ZERO, paddle, "spinner_accent")
 spinners.append({"item": item, "paddle": paddle})

func _field(item: Dictionary) -> void:
 var center := Node3D.new()
 center.position = table.map_point(item.position, 0.018)
 add_child(center)
 var repel: bool = item.properties.mode == "repel"
 var color := Color("f68b6f") if repel else Color("a68ef5")
 var material := table.material(color, 0.1)
 material.albedo_color.a = 0.2
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 Hardware.protect(material)
 var radius := float(item.properties.radius) * table.SCALE
 var ring := TorusMesh.new()
 ring.inner_radius = maxf(0.01, radius - 0.012)
 ring.outer_radius = radius
 ring.rings = 48
 ring.ring_segments = 6
 table.mesh_node(ring, material, Vector3.ZERO, center)
 table.mesh_node(table.cylinder(0.035, 0.025), material, Vector3.ZERO, center)
 var arcs := Node3D.new()
 center.add_child(arcs)
 for i in 6:
  var marker := _box(Vector3(0.07, 0.012, 0.018), color, Vector3.ZERO, arcs)
  marker.material_override = material
  marker.rotation.y = -i * TAU / 6.0
 for mesh: Node in center.find_children("*", "GeometryInstance3D", true, false):
  mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 fields.append({"arcs": arcs, "radius": radius, "repel": repel})

func _rail(item: Dictionary) -> void:
 var path: Dictionary = item.path.duplicate()
 var width := float(item.properties.width) * table.SCALE
 var peak := float(item.properties.height)
 # Bound the inside offset by local bend radius so wide strips cannot fold
 # over themselves. This is visual edging only; the authoritative route is unchanged.
 var inside := PackedFloat32Array()
 for i in path.points.size():
  if table.has_method("stream_checkpoint"): await table.stream_checkpoint()
  var factor := 0.0
  if i > 0 and i < path.points.size() - 1:
   var incoming: Vector2 = path.points[i] - path.points[i - 1]
   var outgoing: Vector2 = path.points[i + 1] - path.points[i]
   var turn := incoming.angle_to(outgoing)
   if absf(turn) > 0.0001:
    var radius := (incoming.length() + outgoing.length()) * 0.5 / absf(turn)
    factor = signf(turn) * minf(1.0, radius * 0.8 / (float(item.properties.width) * 0.54))
  inside.append(factor)
 path["inside_edge_scale"] = inside
 if path.get("terrain_ramp", false):
  await _terrain_ramp(item, path, width, peak)
  return
 var style := table.ramp_materials()
 style.deck = Hardware.ramp_material(table, style.deck, "deck")
 style.accent = Hardware.ramp_material(table, style.accent, "accent")
 var thickness := preload("res://scripts/act_dimensions.gd").RAMP_DECK_THICKNESS_PIXELS * table.SCALE
 var root := Node3D.new()
 root.name = "ElevatedRail_" + str(item.get("object_id", "route"))
 add_child(root)
 # Three meshes keep a readable deck, edge trim and real fascia/underside.
 # All vertices follow the same elevation samples used by the physical ball.
 await _rail_strip(root, path, width, peak, Vector2(-0.5, 0.5), Vector2.ZERO, style.deck, "Deck")
 for side: float in [-1.0, 1.0]:
  if table.has_method("stream_checkpoint"): await table.stream_checkpoint()
  var border: Material = style.get("border", style.edge)
  await _rail_strip(root, path, width, peak, Vector2(side * 0.44, side * 0.54), Vector2(0.035, 0.035), border if border != null else style.edge, "EdgeCap", border != null and style.has("border"))
  await _rail_strip(root, path, width, peak, Vector2(side * 0.54, side * 0.54), Vector2(-thickness, 0.035), style.get("fascia",style.support), "Fascia")
  await _rail_strip(root, path, width, peak, Vector2(side * 0.44, side * 0.44), Vector2(0.0, 0.035), style.edge, "InnerEdge")
 await _rail_strip(root, path, width, peak, Vector2(0.54, -0.54), Vector2(-thickness, -thickness), style.support, "Underside")
 # Slim paired timber/metal/stone posts leave the lane center visually open.
 var distance := 50.0
 while distance < float(path.length) - 35.0:
  if table.has_method("stream_checkpoint"): await table.stream_checkpoint()
  var height := maxf(0.0, RailPath.height(path, distance, peak) * table.SCALE + 0.012 - thickness)
  if height > 0.06:
   var tangent := RailPath.tangent(path, distance)
   var across := Vector2(-tangent.y, tangent.x)
   var edge_index := clampi(path.lengths.bsearch(distance), 0, path.points.size() - 1)
   var edge_scale: float = path.inside_edge_scale[edge_index]
   for side: float in [-1.0, 1.0]:
    if table.has_method("stream_checkpoint"): await table.stream_checkpoint()
    var post_offset := side * float(item.properties.width) * 0.46
    if side * edge_scale > 0.0: post_offset *= absf(edge_scale)
    var post := BoxMesh.new()
    post.size = Vector3(0.045, height, 0.045)
    table.mesh_node(post, style.support, table.map_point(RailPath.sample(path, distance) + across * post_offset, height / 2.0), root)
  distance += 80.0
 # A small inlaid arrow replaces the oversized bright circular entry pad.
 var marker := SurfaceTool.new()
 marker.begin(Mesh.PRIMITIVE_TRIANGLES)
 for vertex: Vector2 in [Vector2(-0.18, 6.0), Vector2(0.18, 6.0), Vector2(0.0, 16.0)]:
  if table.has_method("stream_checkpoint"): await table.stream_checkpoint()
  var d := minf(vertex.y, float(path.length) * 0.15)
  var tangent := RailPath.tangent(path, d)
  var point := RailPath.sample(path, d) + Vector2(-tangent.y, tangent.x) * vertex.x * float(item.properties.width)
  marker.add_vertex(table.map_point(point, RailPath.height(path, d, peak) * table.SCALE + 0.014))
 marker.generate_normals()
 var arrow := table.mesh_node(marker.commit(), style.accent, Vector3.ZERO, root)
 arrow.name = "EntryArrow"
 # Keep the sloped marker's original normals; small rigid posts share local cells.
 if not "--profile-original-rail-shadows" in OS.get_cmdline_user_args():
  preload("res://scripts/authored_act/gimmick_shadows.gd").combine(root, table.has_method("stream_checkpoint"), [arrow], 2.0)

func _terrain_ramp(item: Dictionary, path: Dictionary, width: float, peak: float) -> void:
 var root := Node3D.new()
 root.name = "TerrainRamp_" + str(item.object_id)
 add_child(root)
 var style := table.terrain_ramp_materials()
 var profile: StringName = style.get("profile", &"cliff")
 var toe := 0.61
 if profile == &"glacier": toe = 0.69
 if profile in [&"masonry", &"cabinet", &"bridge"]: toe = 0.56
 if profile == &"bridge": path["stringer_depth"] = width * 0.21
 await _rail_strip(root, path, width, peak, Vector2(-0.5, 0.5), Vector2.ZERO, style.deck, "Deck")
 for side: float in [-1.0, 1.0]:
  # The verge follows the camber. A shallow battered face anchors it to the floor.
  await _rail_strip(root, path, width, peak, Vector2(side * 0.5, side * 0.56), Vector2(0, -0.012), style.trim, "Verge", true)
  await _rail_strip(root, path, width, peak, Vector2(side * 0.56, side * toe), Vector2(-0.012, 0), style.wall, "Bank")
 if profile == &"bridge":
  await _rail_strip(root, path, width, peak, Vector2(toe, -toe), Vector2.ZERO, style.support, "Soffit")
  for fraction: float in [0.33, 0.67]:
   var distance := fraction * float(path.length)
   var point := RailPath.sample(path, distance)
   var tangent := RailPath.tangent(path, distance)
   var shoulder := Vector2(-tangent.y, tangent.x) * float(item.properties.width) * 0.42
   var height := RailPath.height(path, distance, peak) * table.SCALE - float(path.stringer_depth)
   if height <= 0.0: continue
   for side: float in [-1.0, 1.0]:
    var post := BoxMesh.new()
    post.size = Vector3(width * 0.13, height, width * 0.13)
    var support := table.mesh_node(post, style.support, table.map_point(point + shoulder * side, height * 0.5), root)
    support.rotation.y = -tangent.angle()

func _rail_strip(parent: Node3D, path: Dictionary, width: float, peak: float, edges: Vector2, offsets: Vector2, material: Material, label: String, contour_texture := false) -> void:
 contour_texture = contour_texture or bool(material.get_meta("route_strip_uv",false))
 var tread_stations := PackedFloat32Array()
 if label == "Deck" and material.has_meta("playing_card_lane"):
  # Printed cards use the length over the crest, including the change in height.
  tread_stations.append(0.0)
  var previous_height := 0.0
  for i in range(1, path.points.size()):
   var height := RailPath.height(path, path.lengths[i], peak)
   var span: float = path.lengths[i] - path.lengths[i - 1]
   tread_stations.append(tread_stations[-1] + Vector2(span, height - previous_height).length() * table.SCALE)
   previous_height = height
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in path.points.size() - 1:
  if table.has_method("stream_checkpoint"): await table.stream_checkpoint()
  var corners: Array[Vector3] = []
  var uvs: Array[Vector2] = []
  var bank_elevation := PackedVector2Array()
  for index: int in [i, i + 1]:
   if table.has_method("stream_checkpoint"): await table.stream_checkpoint()
   var distance: float = path.lengths[index]
   var tangent := RailPath.tangent(path, distance)
   var side := Vector3(-tangent.y, 0, tangent.x)
   var center := table.map_point(path.points[index], RailPath.height(path, distance, peak) * table.SCALE + 0.012)
   var edge_scale: float = path.inside_edge_scale[index]
   var left := edges.x * absf(edge_scale) if edges.x * edge_scale > 0.0 else edges.x
   var right := edges.y * absf(edge_scale) if edges.y * edge_scale > 0.0 else edges.y
   corners.append(center + side * width * left + Vector3.UP * offsets.x)
   corners.append(center + side * width * right + Vector3.UP * offsets.y)
   if label == "Bank":
    corners[-1].y = maxf(0.0, corners[-2].y - float(path.get("stringer_depth", INF)))
    for y: float in [corners[-2].y, corners[-1].y]:
     bank_elevation.append(Vector2(distance * table.SCALE, y))
     uvs.append(Vector2(distance * table.SCALE, corners[-2].y - y))
    continue
   if not tread_stations.is_empty():
    var face_uv := Vector2(tread_stations[-1] / width, tread_stations[index])
    uvs.append(face_uv)
    uvs.append(face_uv)
    continue
   if label == "Soffit":
    var bottom := maxf(0.0, center.y - 0.012 - float(path.stringer_depth))
    corners[-2].y = bottom
    corners[-1].y = bottom
   uvs.append(Vector2(width * edges.x, distance * table.SCALE))
   uvs.append(Vector2(width * edges.y, distance * table.SCALE))
  var order := [0, 1, 2, 1, 3, 2] if label in ["Bank", "Verge"] and edges.x < 0.0 else [0, 2, 1, 1, 2, 3]
  for vertex: int in order:
   if table.has_method("stream_checkpoint"): await table.stream_checkpoint()
   # Edge artwork follows distance along the route and spans the complete trim.
   # Geometry and the normalized full-deck UV2 used by panel/card decks stay intact.
   surface.set_uv(Vector2(uvs[vertex].y / 0.48, float(vertex % 2)) if contour_texture else uvs[vertex])
   if label == "Bank": surface.set_uv2(bank_elevation[vertex])
   else:
    var across := (edges.x if vertex % 2 == 0 else edges.y) + 0.5
    var station := uvs[vertex].y / width if not tread_stations.is_empty() else uvs[vertex].y
    surface.set_uv2(Vector2(across, station))
   surface.add_vertex(corners[vertex])
 surface.generate_normals()
 # Edge winding reverses on the opposite side; both faces must remain visible.
 var double_sided: Material = material.duplicate()
 if double_sided is BaseMaterial3D: double_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
 var strip := table.mesh_node(surface.commit(), double_sided, Vector3.ZERO, parent)
 strip.name = label
 strip.set_meta("rail_surface", label)


func _process(delta: float) -> void:
 elapsed += delta
 for entry: Dictionary in enemies: BuzzModel.update(entry, elapsed, table)
 for entry: Dictionary in gimmicks: Gimmicks.update(entry)
 for entry: Dictionary in spinners: entry.paddle.rotation.x = float(entry.item.angle)
 for field: Dictionary in fields:
  for i in field.arcs.get_child_count():
   var phase := fposmod(elapsed * 0.4 + float(i) / 6, 1.0)
   if not field.repel: phase = 1.0 - phase
   var angle: float = i * TAU / 6.0
   field.arcs.get_child(i).position = Vector3(cos(angle), 0.012, sin(angle)) * float(field.radius) * lerpf(0.2, 0.88, phase)
