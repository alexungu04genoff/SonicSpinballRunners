extends "res://scripts/themes/theme_definition.gd"
## Sunny original city art, sharing only the existing presentation contract.
const Decor = preload("res://scripts/decor/rooftop_run_decor.gd")
const TEXTURES := "res://assets/textures/rooftop_run/"
const CANAL = preload("res://scripts/themes/rooftop_canal.gdshader")
var _library: RefCounted

func _init() -> void:
 theme_id = "rooftop_run"
 display_name = "Rooftop Run"
 edge_trim_color = Color("e6c48e")
 floor_material = _texture_material("floor", Vector2(4, 4))
 top_material = _texture_material("top", Vector2(5, 3.125))
 side_material = _wall_material("wall")
 cliff_material = _wall_material("facade")
 cliff_material.set_shader_parameter("top_height", 0.0)
 floor_border_material = _border_material("floor-border")
 top_border_material = _border_material("top-border")
 floor_border_width = 12.0
 top_border_width = 8.0
 _library = Decor.new(null)

func _shader(source: Shader) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = source
 return result

func _texture_material(name: String, repeat_size: Vector2, world_mapping := true) -> ShaderMaterial:
 var result := _shader(preload("res://scripts/themes/texture_surface.gdshader"))
 result.set_shader_parameter("surface_texture", load(TEXTURES + name + ".png"))
 result.set_shader_parameter("repeat_size", repeat_size)
 result.set_shader_parameter("world_mapping", world_mapping)
 return result

func _wall_material(name: String) -> ShaderMaterial:
 var result := _shader(preload("res://scripts/themes/texture_wall.gdshader"))
 result.set_shader_parameter("wall_texture", load(TEXTURES + name + ".png"))
 return result

func _border_material(name: String) -> ShaderMaterial:
 var result := _shader(preload("res://scripts/themes/terrain_border.gdshader"))
 result.set_shader_parameter("border_texture", load(TEXTURES + name + ".png"))
 return result

func create_decor(_presentation: Node3D) -> RefCounted:
 return _library

func configure_environment(p: Node3D) -> void:
 var world: Environment = p._world_environment.environment
 var sky_material := ProceduralSkyMaterial.new()
 sky_material.sky_top_color = Color("217aca")
 sky_material.sky_horizon_color = Color("a8cfdd")
 sky_material.ground_bottom_color = Color("507e9d")
 sky_material.ground_horizon_color = Color("a8cfdd")
 sky_material.sky_curve = 0.25
 sky_material.sun_angle_max = 1.5
 var sky := Sky.new()
 sky.sky_material = sky_material
 world.background_mode = Environment.BG_SKY
 world.sky = sky
 world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.ambient_light_color = Color("b8cee2")
 world.ambient_light_energy = 0.32
 world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 world.glow_enabled = false
 var light: DirectionalLight3D = p._key_light
 light.rotation_degrees = Vector3(-49, -37, 0)
 light.light_color = Color("ffe6c5")
 light.light_energy = 0.95
 light.shadow_normal_bias = 2.0

func build_background(p: Node3D) -> void:
 var root: Node3D = p.scenery_root
 var center: Vector3 = p.map_point(p.table_bounds.get_center())
 var width: float = p.table_bounds.size.x * p.SCALE
 var length: float = p.table_bounds.size.y * p.SCALE
 var city := Node3D.new()
 city.name = "SpagoniaCity"
 root.add_child(city)
 # A quiet continuous plaza gives the sparse architecture room to breathe.
 _library.box(city, "dark", center + Vector3(0, -4.85, 0), Vector3(180.0, 0.10, 180.0))
 # Two canals and one bridge each frame the table without a surrounding grid.
 for side: int in [-1, 1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var canal_x := side * (width * 0.5 + 1.30)
  var water := PlaneMesh.new()
  water.size = Vector2(1.35, length + 6.0)
  var water_mesh: MeshInstance3D = p.mesh_node(water, _shader(CANAL), center + Vector3(canal_x, -4.6, 0), root)
  water_mesh.name = "BackgroundCanal"
  for bank: int in [-1, 1]:
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
   _library.box(city, "stone", center + Vector3(canal_x + bank * 0.76, -4.5, 0), Vector3(0.16, 0.25, length + 6.0))
  var bridge: Node3D = _library.build_variant("aqueduct", false)
  city.add_child(bridge)
  bridge.position = center + Vector3(canal_x, -4.5, side * length * 0.22)
  bridge.scale = Vector3(1.0, 0.7, 1.5)
 # One short arcade and one clock retain the skyline's strongest silhouettes.
 var far_z: float = p.table_bounds.position.y * p.SCALE - 3.5
 var span := _library.build_variant("aqueduct", false) as Node3D
 city.add_child(span)
 span.position = Vector3(center.x - width * 0.30, -4.8, far_z)
 span.scale = Vector3(2.0, 3.6, 1.8)
 var tower: Node3D = _library.build_variant("clock_tower", false)
 city.add_child(tower)
 tower.position = Vector3(center.x + width * 0.5 + 2.5, -4.8, far_z - 1.0)
 tower.scale = Vector3(2.2, 2.8, 2.2)
 for i in 3:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var hill: MeshInstance3D = _library.piece(city, "sphere", "shutter", Vector3(center.x + (i - 1) * 11.0, -4.9, far_z - 17.0), Vector3(8.0, 3.2 + (i % 3), 4.0))
  hill.material_override = _haze_material(Color("4c7589"))
 for i in 3:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  _library.balloon(city, Vector3(center.x + (i - 1) * 6.0, 1.4 + i * 0.7, far_z - 5.0 - (i % 2) * 4.0), 0.60, i)
 await _batch_city(city, p)

func _haze_material(color: Color) -> Material:
 var key := "haze_" + color.to_html()
 if not _library.materials.has(key):
  _library.materials[key] = material(color)
  Atmosphere.color(_library.materials[key], "distant_haze")
 return _library.materials[key]

func _house(root: Node3D, at: Vector3, size: Vector3, variation: int) -> void:
 var group := Node3D.new()
 group.name = "CourtyardHouse"
 group.position = at
 root.add_child(group)
 _library.box(group, "stone" if variation % 2 == 0 else "ochre", Vector3(0, size.y * 0.5, 0), size)
 _library.box(group, "cream", Vector3(0, size.y - 0.04, 0), Vector3(size.x * 1.06, 0.10, size.z * 1.06))
 _library.roof(group, Vector3(0, size.y, 0), Vector3(size.x * 1.12, 0.46, size.z * 1.12))
 # Fit rows inside the facade, including short buildings. Each visible layer
 # sits fully in front of the preceding face rather than intersecting it.
 var rows := 2 if size.y >= 1.2 else 1
 var window_height := minf(0.40, size.y * 0.28)
 var window_width := minf(0.26, size.x * 0.22)
 for x: float in [-0.28, 0.28]:
  for row in rows:
   var position := Vector3(x * size.x, size.y * (row + 0.5) / rows, size.z * 0.5 + 0.026)
   _library.box(group, "cream", position, Vector3(window_width, window_height, 0.04))
   _library.box(group, "shutter", position + Vector3(0, 0, 0.032), Vector3(window_width * 0.66, window_height * 0.78, 0.018))

func build_edges(p: Node3D) -> void:
 var terraces := Node3D.new()
 terraces.name = "ExteriorRoofGardens"
 p.scenery_root.add_child(terraces)
 # Two local facades per Act; far canals and skyline remain Zone-wide.
 # Garden props sit beside the houses, never through a roof or window row.
 for side: int in [-1, 1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var y := lerpf(p.table_bounds.position.y, p.table_bounds.end.y, 0.80 if side < 0 else 0.24)
  var edge := scenery_side_edge(p, side, y, 105.0)
  var at: Vector3 = p.map_point(Vector2(edge + side * 160.0, y), -4.56)
  _library.box(terraces, "stone", at - Vector3.UP * 0.12, Vector3(2.1, 0.24, 2.1))
  _house(terraces, at, Vector3(1.35, 3.21, 1.20), 0 if side < 0 else 1)
  var prop := _library.build_variant("hedge_planter") as Node3D
  terraces.add_child(prop)
  prop.position = at + Vector3(0, 0, 0.88)
 await _batch_city(terraces, p)

func _collect_meshes(node: Node3D, transform: Transform3D, batches: Dictionary) -> void:
 var local := transform * node.transform
 if node is MeshInstance3D:
  var key := str(node.mesh.get_instance_id()) + "/" + str(node.material_override.get_instance_id())
  if not batches.has(key): batches[key] = {"mesh": node.mesh, "material": node.material_override, "transforms": []}
  batches[key].transforms.append(local)
 for child: Node in node.get_children():
  _collect_meshes(child, local, batches)

func _batch_city(root: Node3D, scheduler: Node = null) -> void:
 # Concrete draw-call reduction for the repeated district. Authored props retain
 # their own roots/metadata; only static background geometry is instanced here.
 var batches := {}
 for child: Node in root.get_children():
  if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
  _collect_meshes(child, Transform3D.IDENTITY, batches)
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
 var plinth: MeshInstance3D = _library.box(parent, "stone", Vector3(0, -0.15, 0), Vector3(2.8, 0.30, 2.8))
 plinth.material_override = side_material
 var top: MeshInstance3D = _library.box(parent, "cream", Vector3(0, 0.01, 0), Vector3(2.8, 0.035, 2.8))
 top.material_override = floor_material
 for side: int in [-1, 1]:
  var prop := _library.build_variant("cypress_terrace") as Node3D
  parent.add_child(prop)
  prop.position = Vector3(side * 1.0, 0.04, -0.9)
  prop.scale = Vector3.ONE * 0.65

func ramp_materials() -> Dictionary:
 return {"deck": _texture_material("ramp", Vector2(0.48, 0.44), false),
  "edge": material(Color("e8cba0")), "support": material(Color("b69b77")), "accent": material(Color("fff0c7"))}
