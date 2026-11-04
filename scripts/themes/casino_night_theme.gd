extends "res://scripts/themes/theme_definition.gd"
## A luminous entertainment district, entirely outside gameplay authority.
const Decor = preload("res://scripts/decor/casino_night_decor.gd")
const Selected = preload("res://scripts/themes/casino_selected_materials.gd")
var _library: RefCounted
var _ramp_deck_material: Material
var _ramp_guard_material: Material
var _facade_outline := PackedVector2Array()
var _facade_distances := PackedFloat32Array()

func _init() -> void:
 theme_id = "casino_night"
 display_name = "Casino Night"
 edge_trim_color = Color("c48b35")
 floor_material = preload("res://scripts/themes/terrain_texture_sets.gd").material(theme_id, "floor")
 floor_border_width = 6.0
 top_border_width = 4.0
 # Phase 3: retained floor and neon lenses keep their current materials.
 top_material = Selected.surface("5A", 0, Vector2(1.6, 1.6))
 side_material = Selected.surface("3A", 1, Vector2(0.96, 1.0))
 cliff_material = Selected.surface("9A", 4, Vector2(0.96, 1.6))
 floor_border_material = Selected.surface("2A", 2, Vector2.ONE)
 top_border_material = Selected.surface("6B", 2, Vector2.ONE)
 _ramp_deck_material = Selected.surface("7Cards", 3, Vector2(1.0, 2.2))
 _ramp_guard_material = Selected.surface("8B", 2, Vector2.ONE)
 _library = Decor.new(null)

func _shader(source: Shader) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = source
 return result

func create_decor(_presentation: Node3D) -> RefCounted:
 return _library

func configure_environment(p: Node3D) -> void:
 var world: Environment = p._world_environment.environment
 var sky_material := ProceduralSkyMaterial.new()
 sky_material.sky_top_color = Color("080d27")
 sky_material.sky_horizon_color = Color("3c244b")
 sky_material.ground_bottom_color = Color("090d22")
 sky_material.ground_horizon_color = Color("35203d")
 sky_material.sky_curve = 0.3
 sky_material.sun_angle_max = 0.1
 var sky := Sky.new()
 sky.sky_material = sky_material
 world.background_mode = Environment.BG_SKY
 world.sky = sky
 world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.ambient_light_color = Color("c4c9ed")
 world.ambient_light_energy = 0.52
 world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 # Compatibility supports glow in recent Godot 4 versions. Use only its common
 # controls; no HDR viewport, renderer switch or global project changes needed.
 world.glow_enabled = true
 world.glow_intensity = 1.1
 world.glow_bloom = 0.12
 world.glow_hdr_threshold = 0.75
 world.glow_hdr_scale = 1.6
 var light: DirectionalLight3D = p._key_light
 light.rotation_degrees = Vector3(-52, -32, 0)
 light.light_color = Color("ffe1b5")
 light.light_energy = 0.78
 light.shadow_normal_bias = 2.0

func build_background(p: Node3D) -> void:
 var city := Node3D.new()
 city.name = "CasinoEntertainmentDistrict"
 p.scenery_root.add_child(city)
 var center: Vector3 = p.map_point(p.table_bounds.get_center())
 var width: float = p.table_bounds.size.x * p.SCALE
 var length: float = p.table_bounds.size.y * p.SCALE
 var far_z: float = p.table_bounds.position.y * p.SCALE - 4.5
 # Skyline sits below and outside the table. Large dark gaps separate buildings.
 _library.box(city, "dark", center + Vector3(0, -5.9, 0), Vector3(180, 0.15, 180))
 for i in 13:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var height := 2.3 + float((i * 7) % 6) * 0.5
  var at := Vector3(center.x + (i - 6) * 2.5, -5.8, far_z - 7.0 - (i % 3) * 1.5)
  _library.box(city, "navy", at + Vector3.UP * height * 0.5, Vector3(1.5, height, 1.4))
  _library.box(city, "purple", at + Vector3.UP * height, Vector3(1.60, 0.14, 1.50))
  for row in 3:
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
   for column in 2:
    if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
    # Warm broad windows, deliberately weaker than foreground neon.
    _library.box(city, "gold_light", at + Vector3((column - 0.5) * 0.65, height * (0.25 + row * 0.24), 0.72), Vector3(0.26, 0.18, 0.03))
 # Monumental casino facade and lanterns establish the pinball-machine scale.
 var palace: Node3D = _library.build_variant("jackpot_palace")
 city.add_child(palace)
 palace.position = Vector3(center.x, -4.8, far_z)
 palace.scale = Vector3(2.7, 2.6, 2.2)
 await _batch_background(city, p)
 # Text is a single original sign, separate from the static primitive batches.
 var sign := Label3D.new()
 sign.name = "CasinoMarquee"
 sign.text = "CASINO NIGHT"
 sign.font_size = 64
 sign.pixel_size = 0.007
 sign.modulate = Color("ffbb60")
 Atmosphere.tag(sign, "modulate", "marquee")
 sign.outline_modulate = Color("5b163b")
 sign.outline_size = 18
 sign.position = Vector3(center.x, -0.432, far_z + 1.02)
 p.scenery_root.add_child(sign)
 # Exactly two unshadowed fill lights: local spill, not a light per bulb.
 for side: int in [-1, 1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var fill := OmniLight3D.new()
  fill.name = "CasinoWarmSpill" if side < 0 else "CasinoBlueSpill"
  fill.light_color = Color("ffae55") if side < 0 else Color("557fff")
  Atmosphere.tag(fill, "light_color", "warm_spill" if side < 0 else "blue_spill")
  fill.light_energy = 2.4
  fill.omni_range = 4.8
  fill.omni_attenuation = 1.5
  fill.shadow_enabled = false
  fill.position = center + Vector3(side * (width * 0.5 + 0.6), 0.70, -length * 0.2)
  p.scenery_root.add_child(fill)
  # Visible crown sconces identify the two real light sources. Reuse the decor
  # geometry without adding a new variant or attaching lights to every prop.
  var sconce: Node3D = _library.build_variant("crown_lamp")
  sconce.name = "WarmSpillSconce" if side < 0 else "BlueSpillSconce"
  sconce.position = fill.position - Vector3.UP * 1.024
  sconce.scale = Vector3.ONE * 1.6
  _library.box(p.scenery_root, "gold", sconce.position - Vector3(side * 0.3, 0.04, 0), Vector3(0.65, 0.08, 0.22))
  for part: MeshInstance3D in sconce.get_children():
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
   if part.material_override == _library.materials.amber and side > 0:
    part.material_override = _library.materials.aqua
  p.scenery_root.add_child(sconce)

func build_edges(p: Node3D) -> void:
 # Bounded existing landmarks follow the local silhouette; palace/skyline stay shared.
 var local := Node3D.new()
 local.name = "LocalCasinoLandmarks"
 p.scenery_root.add_child(local)
 var layout := scenery_layout(p)
 var variants := ["star_lantern", "reel_tower", "casino_pylon"]
 for plan: Dictionary in layout.plans([{"side": -1, "at": 0.84}, {"side": 1, "at": 0.24}]):
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var group := Node3D.new()
  local.add_child(group)
  var variant := layout.choice("landmark/" + str(plan.id), plan.id % 2, variants.size())
  var tower: Node3D = _library.build_variant(variants[variant])
  group.add_child(tower)
  tower.scale = Vector3.ONE * layout.varied("scale/" + str(plan.id), 1.65, 0.12)
  tower.rotation.y = layout.varied("yaw/" + str(plan.id), 0.0, 0.14)
  if layout.density >= 0.75:
   var palm: Node3D = _library.build_variant("neon_palm")
   group.add_child(palm)
   palm.position = Vector3(plan.side * 0.95, 0, 0.6)
   palm.scale = Vector3.ONE * 1.3
  if not layout.place_group(p, group, plan.side, plan.at, 45.0, -2.1): group.free()
 p.scenery_group_count = layout.occupied.size()
 await _batch_background(local, p)

func ramp_materials() -> Dictionary:
 return {"deck": _ramp_deck_material, "border": _ramp_guard_material,
  "edge": material(Color("e7bd62")), "support": material(Color("742641")),
  "accent": material(Color("b52349"))}

func _collect(node: Node3D, transform: Transform3D, batches: Dictionary) -> void:
 var local := transform * node.transform
 if node is MeshInstance3D:
  var key := str(node.mesh.get_instance_id()) + "/" + str(node.material_override.get_instance_id())
  if not batches.has(key): batches[key] = {"mesh": node.mesh, "material": node.material_override, "transforms": []}
  batches[key].transforms.append(local)
 for child: Node in node.get_children(): _collect(child, local, batches)

func _batch_background(root: Node3D, scheduler: Node = null) -> void:
 var batches := {}
 for child: Node in root.get_children():
  if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
  _collect(child, Transform3D.IDENTITY, batches)
 for child: Node in root.get_children():
  if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
  root.remove_child(child)
  child.free()
 for key: String in batches:
  if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
  var data: Dictionary = batches[key]
  var multimesh := MultiMesh.new()
  multimesh.transform_format = MultiMesh.TRANSFORM_3D
  multimesh.mesh = data.mesh
  multimesh.instance_count = data.transforms.size()
  for i in data.transforms.size():
   if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
   _set_instance_transform(multimesh, i, data.transforms[i])
  var instance := MultiMeshInstance3D.new()
  instance.multimesh = multimesh
  instance.material_override = data.material
  root.add_child(instance)

func build_study(_p: Node3D, parent: Node3D, origin: Vector3) -> void:
 parent.position = origin
 var plinth: MeshInstance3D = _library.box(parent, "gold", Vector3(0, -0.15, 0), Vector3(2.8, 0.30, 2.8))
 plinth.material_override = side_material
 var top: MeshInstance3D = _library.box(parent, "blue", Vector3(0, 0.01, 0), Vector3(2.8, 0.035, 2.8))
 top.material_override = floor_material

func wall_distances(points: PackedVector2Array) -> PackedFloat32Array:
 # A fixed physical pitch keeps separate wall and facade meshes at the same scale.
 # Do not stretch each outline independently to fit a whole number of bays.
 var distances := PackedFloat32Array([0.0])
 var anchor := 0
 for i in points.size():
  distances.append(distances[-1] + points[i].distance_to(points[(i + 1) % points.size()]) * TablePresentation.SCALE)
  if points[i].x < points[anchor].x or (is_equal_approx(points[i].x, points[anchor].x) and points[i].y < points[anchor].y):
   anchor = i
 var origin := distances[anchor]
 for i in distances.size(): distances[i] -= origin
 return distances

func set_facade_reference(points: PackedVector2Array) -> void:
 _facade_outline = points.duplicate()
 _facade_distances = wall_distances(points)

func _facade_coordinate(point: Vector2) -> Vector2:
 var closest := INF
 var coordinate := 0.0
 for i in _facade_outline.size():
  var a := _facade_outline[i]
  var b := _facade_outline[(i + 1) % _facade_outline.size()]
  var projected := Geometry2D.get_closest_point_to_segment(point, a, b)
  var separation := point.distance_to(projected)
  if separation < closest:
   closest = separation
   coordinate = _facade_distances[i] + a.distance_to(projected) * TablePresentation.SCALE
 return Vector2(coordinate, closest)

func _shared_facade_span(a: Vector2, b: Vector2) -> PackedFloat32Array:
 if _facade_outline.is_empty(): return PackedFloat32Array()
 var start := _facade_coordinate(a)
 var end := _facade_coordinate(b)
 var middle := _facade_coordinate((a + b) * 0.5)
 # Only coincident edges inherit the facade coordinates. Interior walls keep
 # their own continuous contour mapping instead of projecting across corners.
 if maxf(maxf(start.y, end.y), middle.y) > 0.05: return PackedFloat32Array()
 var length := a.distance_to(b) * TablePresentation.SCALE
 var perimeter := _facade_distances[-1] - _facade_distances[0]
 var delta := end.x - start.x
 if absf(delta) > perimeter * 0.5: delta -= signf(delta) * perimeter
 if absf(absf(delta) - length) > 0.001: return PackedFloat32Array()
 return PackedFloat32Array([start.x, start.x + delta])

func wrap_wall_mesh(mesh: ArrayMesh, outline: PackedVector2Array) -> ArrayMesh:
 var points := outline.duplicate()
 if Geometry2D.is_polygon_clockwise(points): points.reverse()
 var distances := wall_distances(points)
 var arrays := mesh.surface_get_arrays(1)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var coords := PackedVector2Array()
 # Anchor the rest of the contour to the first shared exterior edge as well.
 for i in points.size():
  var shared := _shared_facade_span(points[i], points[(i + 1) % points.size()])
  if shared.size() == 2:
   var offset := shared[0] - distances[i]
   for j in distances.size(): distances[j] += offset
   break
 for i in points.size():
  var shared := _shared_facade_span(points[i], points[(i + 1) % points.size()])
  var start_u := shared[0] if shared.size() == 2 else distances[i]
  var end_u := shared[1] if shared.size() == 2 else distances[i + 1]
  for j in 6:
   var u := end_u if j == 1 or j == 3 or j == 4 else start_u
   coords.append(Vector2(u, vertices[i * 6 + j].y))
 arrays[Mesh.ARRAY_TEX_UV] = coords
 var result := ArrayMesh.new()
 for i in mesh.get_surface_count():
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays if i == 1 else mesh.surface_get_arrays(i))
  result.surface_set_material(i, mesh.surface_get_material(i))
 return result
