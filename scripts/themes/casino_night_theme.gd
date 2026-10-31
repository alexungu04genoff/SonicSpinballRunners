extends "res://scripts/themes/theme_definition.gd"
## A luminous entertainment district, entirely outside gameplay authority.
const Decor = preload("res://scripts/decor/casino_night_decor.gd")
const FLOOR = preload("res://scripts/themes/casino_floor.gdshader")
const WALL = preload("res://scripts/themes/casino_wall.gdshader")
var _library: RefCounted

func _init() -> void:
 theme_id = "casino_night"
 display_name = "Casino Night"
 edge_trim_color = Color("c48b35")
 _apply_texture_set()
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
 # One landmark per side follows the local silhouette, including narrow bends.
 # Keep the palace and distant skyline in the shared Zone background.
 var local := Node3D.new()
 local.name = "LocalCasinoLandmarks"
 p.scenery_root.add_child(local)
 for side: int in [-1, 1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var y := lerpf(p.table_bounds.position.y, p.table_bounds.end.y, 0.84 if side < 0 else 0.24)
  var edge := scenery_side_edge(p, side, y, 65.0)
  var at: Vector3 = p.map_point(Vector2(edge + side * 115.0, y), -2.1)
  var tower: Node3D = _library.build_variant("star_lantern" if side < 0 else "reel_tower")
  local.add_child(tower)
  tower.position = at
  tower.scale = Vector3.ONE * 1.65
  var palm: Node3D = _library.build_variant("neon_palm")
  local.add_child(palm)
  palm.position = at + Vector3(side * 0.95, 0, 0.6)
  palm.scale = Vector3.ONE * 1.3
 await _batch_background(local, p)

func ramp_materials() -> Dictionary:
 return {"deck": _texture_ramp(),
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
