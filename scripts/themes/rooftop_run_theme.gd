extends "res://scripts/themes/theme_definition.gd"
## Sunny original city art, sharing only the existing presentation contract.
const Decor = preload("res://scripts/decor/rooftop_run_decor.gd")
const TEXTURES := "res://assets/textures/rooftop_run/"
const CANAL = preload("res://scripts/themes/rooftop_canal.gdshader")
const STREET_LEVEL := -4.8
var _library: RefCounted
var _terrain_track: Dictionary = {}
var material_maps = preload("res://scripts/themes/rooftop_material_maps.gd").new()

func _init() -> void:
 theme_id = "rooftop_run"
 display_name = "Rooftop Run"
 edge_trim_color = Color("e6c48e")
 floor_material = _texture_material("floor", Vector2(1.8, 1.8))
 top_material = _texture_material("top", Vector2(1.8, 1.5))
 side_material = _wall_material("wall")
 cliff_material = _wall_material("facade")
 cliff_material.set_shader_parameter("top_height", 0.0)
 floor_border_material = _border_material("floor-border")
 top_border_material = _border_material("top-border")
 floor_border_width = 12.0
 top_border_width = 8.0
 _library = Decor.new(null)
 _library.material_detail = material_maps
 _library.roof_material = top_material

func _shader(source: Shader) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = source
 return result

func _texture_material(name: String, repeat_size: Vector2, world_mapping := true) -> ShaderMaterial:
 var result := _shader(preload("res://scripts/themes/texture_surface.gdshader"))
 result.set_shader_parameter("surface_texture", material_maps.texture(material_maps.IDS[name], ""))
 result.set_shader_parameter("repeat_size", repeat_size)
 result.set_shader_parameter("world_mapping", world_mapping)
 return material_maps.apply(result,name,"surface_texture")

func _wall_material(name: String) -> ShaderMaterial:
 var result := _shader(preload("res://scripts/themes/texture_wall.gdshader"))
 if name == "facade":
  var shader:=Shader.new()
  shader.code=result.shader.code.replace("vec2(3.4, 1.45)","vec2(1.7, 0.85)")
  result.shader=shader
 result.set_shader_parameter("wall_texture",material_maps.texture("9B", "") if name=="facade" else load(TEXTURES+name+".png"))
 return material_maps.apply(result,name,"wall_texture")

func _border_material(name: String) -> ShaderMaterial:
 var result := _shader(preload("res://scripts/themes/terrain_border.gdshader"))
 if name=="floor-border":
  var shader:=Shader.new()
  shader.code=result.shader.code.replace("fract(UV.x)","fract(UV.x * 1.5)").replace("clamp(UV.y, 0.0, 1.0)","clamp(UV.y, 0.0, 1.0) * 0.375").replace("dFdx(UV)","dFdx(vec2(UV.x * 1.5, UV.y * 0.375))").replace("dFdy(UV)","dFdy(vec2(UV.x * 1.5, UV.y * 0.375))")
  result.shader=shader
 result.set_shader_parameter("border_texture",material_maps.texture("2A", "") if name=="floor-border" else load(TEXTURES+name+".png"))
 return material_maps.apply(result,name,"border_texture")

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
 world.ambient_light_energy = 0.28
 world.ambient_light_sky_contribution = 0.15
 world.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
 world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 world.glow_enabled = false
 var light: DirectionalLight3D = p._key_light
 light.rotation_degrees = Vector3(-42, -62, 0)
 light.light_color = Color("ffe9cc")
 light.light_energy = 1.05
 light.shadow_bias = 0.22
 light.directional_shadow_max_distance = 24.0
 light.shadow_normal_bias = 2.0

func build_background(p: Node3D) -> void:
 var root: Node3D = p.scenery_root
 var center: Vector3 = p.map_point(p.table_bounds.get_center())
 var width: float = p.table_bounds.size.x * p.SCALE
 var length: float = p.table_bounds.size.y * p.SCALE
 var city := Node3D.new()
 city.name = "SpagoniaCity"
 root.add_child(city)
 # Three paved land strips leave real openings for the lower canals. Broad,
 # muted stone gives the shadowless backdrop a readable common ground plane.
 var canal_offset := width * 0.5 + 1.30
 var canal_half_width := 0.675
 var ground: MeshInstance3D = _library.box(city, "stone", center + Vector3(0, STREET_LEVEL - 0.30, 0), Vector3((canal_offset - canal_half_width) * 2.0, 0.60, 180.0))
 ground.material_override = _street_material()
 for side: int in [-1, 1]:
  var outer_edge := canal_offset + canal_half_width
  var pavement: MeshInstance3D = _library.box(city, "stone", center + Vector3(side * (90.0 + outer_edge) * 0.5, STREET_LEVEL - 0.30, 0), Vector3(90.0 - outer_edge, 0.60, 180.0))
  pavement.material_override = _street_material()
 # Two canals and one bridge each frame the table without a surrounding grid.
 for side: int in [-1, 1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var canal_x := side * canal_offset
  var water := PlaneMesh.new()
  water.size = Vector2(canal_half_width * 2.0, 180.0)
  var water_mesh: MeshInstance3D = p.mesh_node(water, _shader(CANAL), center + Vector3(canal_x, STREET_LEVEL - 0.18, 0), root)
  water_mesh.name = "BackgroundCanal"
  for bank: int in [-1, 1]:
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
   _library.box(city, "stone", center + Vector3(canal_x + bank * 0.76, STREET_LEVEL - 0.08, 0), Vector3(0.16, 0.50, 180.0))
  var bridge: Node3D = _library.build_variant("aqueduct", false)
  city.add_child(bridge)
  bridge.position = center + Vector3(canal_x, STREET_LEVEL - 0.40, side * length * 0.22)
  bridge.scale = Vector3(1.0, 0.7, 1.5)
 # Offset city blocks, rather than isolated towers in a blank plane. The near
 # row has broad shutters; the outer row reduces to three faceted masses.
 for side: int in [-1, 1]:
  for layer in 2:
   var block_x := side * (width * 0.5 + 3.5 + layer * 3.4)
   # Continuous curb-height blocks join the buildings into streets. A darker
   # masonry course at each foot supplies contact without adding shadow lights.
   _library.box(city, "stone", center + Vector3(block_x, STREET_LEVEL + 0.09, layer * 1.65), Vector3(3.0, 0.18, 24.5))
   for i in 7:
    if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
    var at := center + Vector3(block_x, STREET_LEVEL + 0.18, (i - 3) * 3.5 + layer * 1.65)
    var size := Vector3(2.1 + (i % 2) * 0.45, 1.25 + float((i * 3 + layer) % 5) * 0.36, 2.3)
    var footing: MeshInstance3D = _library.box(city, "stone", at + Vector3.UP * 0.08, Vector3(size.x + 0.14, 0.16, size.z + 0.14))
    footing.material_override = _district_material("foundation", Color("99866c"))
    if layer == 0:
     _house(city, at, size, i)
    else:
     var body: MeshInstance3D = _library.box(city, "stone", at + Vector3.UP * size.y * 0.5, size)
     body.material_override = _district_material("wall", Color("a99f93"))
     var cornice: MeshInstance3D = _library.box(city, "cream", at + Vector3.UP * size.y, Vector3(size.x * 1.08, 0.12, size.z * 1.08))
     cornice.material_override = _district_material("trim", Color("beb4a1"))
     var roof: MeshInstance3D = _library.piece(city, "roof", "roof", at + Vector3.UP * (size.y + 0.06), Vector3(size.x * 1.14, 0.65, size.z * 1.14))
     roof.material_override = _district_material("roof", Color("9d6959"))
 # One short arcade and one clock retain the skyline's strongest silhouettes.
 var far_z: float = p.table_bounds.position.y * p.SCALE - 3.5
 var span := _library.build_variant("aqueduct", false) as Node3D
 city.add_child(span)
 span.position = Vector3(center.x - width * 0.30, STREET_LEVEL, far_z)
 span.scale = Vector3(2.0, 3.6, 1.8)
 var tower: Node3D = _library.build_variant("clock_tower", false)
 city.add_child(tower)
 tower.position = Vector3(center.x + width * 0.5 + 2.5, STREET_LEVEL, far_z - 1.0)
 tower.scale = Vector3(2.2, 2.8, 2.2)
 for i in 3:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var hill: MeshInstance3D = _library.piece(city, "sphere", "shutter", Vector3(center.x + (i - 1) * 11.0, -4.9, far_z - 17.0), Vector3(8.0, 3.2 + (i % 3), 4.0))
  hill.material_override = _haze_material(Color("4c7589"))
 for i in 3:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  _library.balloon(city, Vector3(center.x + (i - 1) * 6.0, 1.4 + i * 0.7, far_z - 5.0 - (i % 2) * 4.0), 0.60, i)
 await _batch_city(city, p)

func _street_material() -> Material:
 if not _library.materials.has("street"):
  var paving := material(Color("b2ad9d"))
  paving.albedo_texture = material_maps.texture("1A", "")
  paving.uv1_triplanar = true
  paving.uv1_world_triplanar = true
  paving.uv1_scale = Vector3.ONE * 0.25
  paving.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  paving.roughness = 0.95
  paving.metallic_specular = 0.15
  Atmosphere.color(paving, "architecture_tint", "tint")
  _library.materials.street = paving
 return _library.materials.street

func _district_material(key: String, color: Color) -> Material:
 var id := "district_" + key
 if not _library.materials.has(id):
  var mat := material(color)
  Atmosphere.color(mat, "roof_tint" if key == "roof" else "architecture_tint", "tint")
  _library.materials[id] = mat
 return _library.materials[id]

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
 # Existing facades/gardens remain local; far canals and skyline stay Zone-wide.
 var layout := scenery_layout(p)
 var gardens := ["hedge_planter", "garden_bench", "flower_urn"]
 for plan: Dictionary in layout.plans([{"side": -1, "at": 0.80}, {"side": 1, "at": 0.24}]):
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var group := Node3D.new()
  terraces.add_child(group)
  # Local terraces can cross a shared canal. Carry their masonry below the
  # waterline as well as into the street, so the garden slab has a real support.
  var foundation: MeshInstance3D = _library.box(group, "stone", Vector3(0, -0.44, 0), Vector3(1.94, 0.64, 1.94))
  foundation.material_override = _district_material("foundation", Color("99866c"))
  _library.box(group, "stone", Vector3(0, -0.12, 0), Vector3(2.1, 0.24, 2.1))
  _house(group, Vector3.ZERO, Vector3(1.35, layout.varied("height/" + str(plan.id), 3.21, 0.25), 1.20), layout.choice("facade/" + str(plan.id), plan.id % 2, 2))
  if layout.density >= 0.75:
   var prop := _library.build_variant(gardens[layout.choice("garden/" + str(plan.id), 0, gardens.size())]) as Node3D
   group.add_child(prop)
   prop.position = Vector3(0, 0, 0.88)
  group.rotation.y = layout.varied("yaw/" + str(plan.id), 0.0, 0.10)
  if not layout.place_group(p, group, plan.side, plan.at, 50.0, -4.56): group.free()
 p.scenery_group_count = layout.occupied.size()
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
 var preserved := preload("res://scripts/themes/motion_preserve.gd").take(root)
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
 preload("res://scripts/themes/motion_preserve.gd").restore(root, preserved)

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

func terrain_track_style() -> Dictionary:
 if _terrain_track.is_empty():
  var tile := _texture_material("top", Vector2(1.25, 1.8), false)
  var arch := _shader(preload("res://scripts/themes/rooftop_arch_stone.gdshader"))
  arch.set_shader_parameter("limestone", _library.materials.stone.albedo_color)
  _terrain_track = {"profile": &"masonry", "track": tile, "crown": tile,
   "wall": arch, "ramp_wall": side_material,
   "trim": _library.materials.cream, "support": _library.materials.stone}
 return _terrain_track

func ramp_materials() -> Dictionary:
 return {"deck": _texture_material("ramp", Vector2(1.2, 1.2), false),
  "edge": material_maps.guard(), "support": material(Color("b69b77")), "accent": material(Color("fff0c7")), "fascia": material_maps.guard()}
