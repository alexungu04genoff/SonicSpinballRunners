extends "res://scripts/themes/theme_definition.gd"
## A cloudborne ruin skin. All dressing lives outside authoritative Act geometry.
const Decor = preload("res://scripts/decor/sky_sanctuary_decor.gd")
const FLOOR = preload("res://scripts/themes/sanctuary_floor.gdshader")
const WALL = preload("res://scripts/themes/sanctuary_wall.gdshader")
const CLOUDS = preload("res://scripts/themes/sanctuary_clouds.gdshader")
var _library: RefCounted

func _init() -> void:
 theme_id = "sky_sanctuary"
 display_name = "Sky Sanctuary"
 edge_trim_color = Color("b7b68e")
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
 sky_material.sky_top_color = Color("388ec4")
 sky_material.sky_horizon_color = Color("bbdeeb")
 sky_material.ground_bottom_color = Color("729fbc")
 sky_material.ground_horizon_color = Color("bbdeeb")
 sky_material.sky_curve = 0.22
 sky_material.sun_angle_max = 1.2
 var sky := Sky.new()
 sky.sky_material = sky_material
 world.background_mode = Environment.BG_SKY
 world.sky = sky
 world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.ambient_light_color = Color("adcbdc")
 world.ambient_light_energy = 0.36
 world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 world.glow_enabled = false
 var light: DirectionalLight3D = p._key_light
 light.rotation_degrees = Vector3(-46, -35, 0)
 light.light_color = Color("fff1d5")
 light.light_energy = 0.70
 light.shadow_normal_bias = 2.0

func build_background(p: Node3D) -> void:
 var center: Vector3 = p.map_point(p.table_bounds.get_center())
 var width: float = p.table_bounds.size.x * p.SCALE
 var length: float = p.table_bounds.size.y * p.SCALE
 var root := Node3D.new()
 root.name = "CloudborneSanctuary"
 p.scenery_root.add_child(root)
 # This remote cloud deck has no terrain, shoreline, water, or collision.
 var sea := PlaneMesh.new()
 sea.size = Vector2(240, maxf(240, length * 3.0))
 var layer: MeshInstance3D = p.mesh_node(sea, _shader(CLOUDS), center + Vector3(0, -13, 0), root)
 layer.name = "DistantCloudSea"
 layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var clouds := Node3D.new()
 clouds.name = "CloudBanks"
 root.add_child(clouds)
 # Repeated rounded low-poly lobes give the sea volume and shaded blue troughs.
 var cloud_mat := _shader(preload("res://scripts/themes/sanctuary_cloud_volume.gdshader"))
 for i in 60:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var x := float((i * 17) % 29 - 14) * 3.4
  var z := float((i * 11) % 31 - 15) * maxf(2.8, length / 18.0)
  var at := center + Vector3(x, -10.6 + sin(i * 2.3) * 1.15, z)
  for lobe in 3:
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
   var cloud: MeshInstance3D = _library.piece(clouds, "sphere", "pale", at + Vector3((lobe - 1) * 1.9, sin(lobe * 2.0 + i) * 0.4, lobe * 0.6), Vector3(3.8, 1.3 + (i % 3) * 0.2, 2.7))
   cloud.material_override = cloud_mat
   cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 await _batch(clouds, p)
 _orbital_silhouette(root, center + Vector3(-width * 0.5 - 11.0, 1.0, -length * 0.5 - 24.0))

func build_edges(p: Node3D) -> void:
 var ruins := Node3D.new()
 ruins.name = "FloatingRuins"
 p.scenery_root.add_child(ruins)
 # Two broken vertical ruins follow each Act's local silhouette,
 # with cloud gaps instead of platform-like patios alongside the playable deck.
 # Side, longitudinal fraction, variant, scale, yaw, base height, half Z span, X clearance.
 var landmarks := [
  [-1, 0.80, "sanctuary_belfry", 1.6, -0.10, -3.0, 0.45, 1.5],
  [1, 0.24, "sky_aqueduct", 1.5, PI * 0.5 - 0.10, -2.3, 1.8, 0.9],
 ]
 for i in landmarks.size():
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var spec: Array = landmarks[i]
  var side: int = spec[0]
  var y := lerpf(p.table_bounds.position.y, p.table_bounds.end.y, spec[1])
  var edge := scenery_side_edge(p, side, y, spec[6] / p.SCALE)
  var at: Vector3 = p.map_point(Vector2(edge, y), spec[5]) + Vector3(side * spec[7], 0, 0)
  var island := Node3D.new()
  island.name = "FloatingRuin%d" % i
  island.position = at
  island.rotation.y = spec[4]
  ruins.add_child(island)
  var variant: String = spec[2]
  var prop := _floating_fragment(variant)
  island.add_child(prop)
  prop.scale = Vector3.ONE * float(spec[3])
  # Detached narrow masonry signals a broken floating ruin, not a landing deck.
  for j in 2:
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
   var fragment: MeshInstance3D = _library.box(island, "warm", Vector3(side * (0.55 + j * 0.48), -0.8 - j * 0.62, 0.15), Vector3(0.25, 0.55, 0.25))
   fragment.rotation = Vector3(j * 0.3, j * 0.7, 0.25)
  _atmosphere(island, 0.08)
 await _batch(ruins, p)

func _floating_fragment(variant: String) -> Node3D:
 # Reuse the existing masonry builders without the decor variants' broad bases.
 var root := Node3D.new()
 if variant == "sanctuary_belfry":
  for side: int in [-1, 1]:
   _library.column(root, Vector3(side * 0.35, 0, 0), 1.40, 0.16, true)
  _library.box(root, "warm", Vector3(0, 1.53, 0), Vector3(1.22, 0.16, 0.34))
  _library.arch(root, Vector3(0, 1.65, 0), 0.78, 0.75, 0.30, true)
  _library.vine(root, Vector3(0.46, 1.52, 0.19), 1.10)
 else:
  for side: int in [-1, 1]:
   _library.arch(root, Vector3(side * 0.72, 0, 0), 1.40, 1.1, 0.30, side > 0)
  _library.box(root, "warm", Vector3(-0.45, 1.20, 0), Vector3(1.85, 0.14, 0.32))
  _library.vine(root, Vector3(-0.95, 1.20, 0.19), 0.76)
 return root

func _atmosphere(node: Node3D, amount: float) -> void:
 if node is MeshInstance3D:
  var original: StandardMaterial3D = node.material_override
  var key := "haze_" + str(original.get_instance_id()) + "_" + str(amount)
  if not _library.materials.has(key):
   var faded: StandardMaterial3D = original.duplicate()
   faded.albedo_color = original.albedo_color.lerp(Color("99bfd1"), amount)
   Atmosphere.tag(faded, "albedo_color", "ruin_haze", "haze", {"unhazed": original.albedo_color, "amount": amount, "authored": Color("99bfd1")})
   _library.materials[key] = faded
  node.material_override = _library.materials[key]
  node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for child: Node in node.get_children(): _atmosphere(child, amount)

func _orbital_silhouette(parent: Node3D, at: Vector3) -> void:
 var station := Node3D.new()
 station.name = "DistantOrbitalRelic"
 station.position = at
 parent.add_child(station)
 var shell: MeshInstance3D = _library.piece(station, "sphere", "shadow", Vector3.ZERO, Vector3(2.6, 2.85, 2.6))
 shell.material_override = material(Color("8ba9bd"))
 # Original abstract orbital face: recessed eyes, equatorial belt, segmented brow.
 for side: int in [-1, 1]:
  var eye: MeshInstance3D = _library.box(station, "shadow", Vector3(side * 0.75, 0.35, 2.41), Vector3(0.60, 0.16, 0.08))
  eye.material_override = material(Color("708da5"))
 var belt: MeshInstance3D = _library.piece(station, "cylinder", "shadow", Vector3(0, -0.20, 0), Vector3(2.66, 0.13, 2.66))
 belt.material_override = material(Color("7b9bb1"))
 _batch(station)

func _collect(node: Node3D, transform: Transform3D, batches: Dictionary) -> void:
 var local := transform * node.transform
 if node is MeshInstance3D:
  var key := str(node.mesh.get_instance_id()) + "/" + str(node.material_override.get_instance_id())
  if not batches.has(key): batches[key] = {"mesh": node.mesh, "material": node.material_override, "transforms": []}
  batches[key].transforms.append(local)
 for child: Node in node.get_children(): _collect(child, local, batches)

func _batch(root: Node3D, scheduler: Node = null) -> void:
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
  instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root.add_child(instance)

func build_study(_p: Node3D, parent: Node3D, origin: Vector3) -> void:
 parent.position = origin
 var plinth: MeshInstance3D = _library.box(parent, "stone", Vector3(0, -0.18, 0), Vector3(2.8, 0.36, 2.8))
 plinth.material_override = cliff_material
 var top: MeshInstance3D = _library.box(parent, "pale", Vector3(0, 0.01, 0), Vector3(2.8, 0.03, 2.8))
 top.material_override = floor_material
 for side: int in [-1, 1]: _library.column(parent, Vector3(side, 0.03, -0.9), 1.0, 0.15, true)

func ramp_materials() -> Dictionary:
 return {"deck": _texture_ramp(),
  "edge": material(Color("c8c4a2")), "support": material(Color("9da98f")), "accent": material(Color("72bfca"))}
