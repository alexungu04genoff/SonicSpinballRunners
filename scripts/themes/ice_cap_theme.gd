extends "res://scripts/themes/theme_definition.gd"
## Twilight glacier presentation. No surface properties or gameplay hooks.
const Decor = preload("res://scripts/decor/ice_cap_decor.gd")
var _library: RefCounted

func _init() -> void:
 theme_id = "ice_cap"
 display_name = "Ice Cap"
 edge_trim_color = Color("c6dce7")
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
 var sky := Sky.new()
 sky.sky_material = _shader(preload("res://scripts/themes/ice_sky.gdshader"))
 sky.radiance_size = Sky.RADIANCE_SIZE_128
 sky.process_mode = Sky.PROCESS_MODE_QUALITY
 world.background_mode = Environment.BG_SKY
 world.sky = sky
 world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.ambient_light_color = Color("a6c3e5")
 world.ambient_light_energy = 0.42
 world.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
 world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 world.glow_enabled = false
 var light: DirectionalLight3D = p._key_light
 light.rotation_degrees = Vector3(-48, -32, 0)
 light.light_color = Color("d9ecff")
 light.light_energy = 0.64
 light.shadow_normal_bias = 2.0

func build_background(p: Node3D) -> void:
 var center: Vector3 = p.map_point(p.table_bounds.get_center())
 var width: float = p.table_bounds.size.x * p.SCALE
 var length: float = p.table_bounds.size.y * p.SCALE
 var root := Node3D.new()
 root.name = "TwilightGlacier"
 p.scenery_root.add_child(root)
 var lake: MeshInstance3D = _library.box(root, "deep", center + Vector3(0, -6.4, 0), Vector3(220, 0.12, 220))
 lake.name = "DarkFrozenLake"
 var lake_mat := _shader(preload("res://scripts/themes/ice_lake.gdshader"))
 lake_mat.set_shader_parameter("center", Vector2(center.x, center.z))
 lake.material_override = lake_mat
 var landscape := Node3D.new()
 landscape.name = "WinterLandscape"
 root.add_child(landscape)
 # Remote faceted mountains frame open water. White caps occupy only the peaks.
 for i in 17:
  var angle := TAU * float(i) / 17.0
  var radius := 28.0 + (i % 3) * 5.0
  var height := 6.0 + (i * 7 % 9) * 0.6
  var at := center + Vector3(cos(angle) * (width * 0.5 + radius), -6.3, sin(angle) * (length * 0.5 + radius))
  _mountain(landscape, at, height, 6.0 + (i % 4))
  _mountain(landscape, at + Vector3(4.0, -0.2, 1.5), height * 0.62, 4.5)
 # Nearby floating ice shelves, small conifer groups, and one distant cavern.
 for i in 14:
  var side := -1.0 if i % 2 == 0 else 1.0
  var at := center + Vector3(side * (width * 0.5 + 4.0 + (i % 3) * 1.8), -5.9, (float(i / 2) - 3.0) * maxf(3.4, length * 0.22))
  var floe: MeshInstance3D = _library.piece(landscape, "facet", "ice", at, Vector3(1.6 + (i % 2), 0.8, 1.1))
  floe.rotation.y = i * 0.7
  _library.piece(landscape, "sphere", "snow", at + Vector3.UP * 0.44, Vector3(1.5 + (i % 2), 0.13, 1.03))
  if i % 3 == 0:
   _library.pine(landscape, at + Vector3.UP * 0.5, 2.4, 0.72)
  elif i % 3 == 1:
   _library.crystal(landscape, at + Vector3.UP * 0.5, 2.4, 0.45, -0.20, false)
 _library.arch(landscape, center + Vector3(-width * 0.5 - 7.0, -5.4, -length * 0.5 - 8.0), 6.8, 4.8, 2.3)
 _batch(landscape)
 var aurora := Node3D.new()
 aurora.name = "AuroraCurtains"
 root.add_child(aurora)
 for i in 3:
  var ribbon := make_aurora(i)
  ribbon.position = center + Vector3(0, 11.0 + i * 3.0, -length * 0.5 - 30.0 - i * 5.0)
  aurora.add_child(ribbon)
 _snow(root, center, width, length)

func _mountain(root: Node3D, at: Vector3, height: float, radius: float) -> void:
 # Asymmetric ridge facets with irregular snowlines, rather than stacked cones.
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var peak := at + Vector3(radius * 0.21, height, radius * -0.1)
 for i in 7:
  var angle_a := TAU * i / 7.0
  var angle_b := TAU * (i + 1) / 7.0
  var a := at + Vector3(cos(angle_a) * radius, 0, sin(angle_a) * radius * 0.67)
  var b := at + Vector3(cos(angle_b) * radius, 0, sin(angle_b) * radius * 0.67)
  var snow_a := a.lerp(peak, 0.48 + sin(i * 2.1 + height) * 0.15)
  var snow_b := b.lerp(peak, 0.48 + sin((i + 1) * 2.1 + height) * 0.15)
  var normal := (peak - a).cross(b - a).normalized()
  for vertex: Vector3 in [a, b, snow_a, b, snow_b, snow_a]:
   surface.set_normal(normal)
   surface.set_color(Color("344c70") if i % 2 else Color("456080"))
   surface.add_vertex(vertex)
  for vertex: Vector3 in [snow_a, snow_b, peak]:
   surface.set_normal(normal)
   surface.set_color(Color("a4b9cf") if i % 2 else Color("c3d1dd"))
   surface.add_vertex(vertex)
 var mesh := MeshInstance3D.new()
 mesh.mesh = surface.commit()
 var mat := StandardMaterial3D.new()
 mat.vertex_color_use_as_albedo = true
 mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 mat.roughness = 1.0
 mesh.material_override = mat
 root.add_child(mesh)

func make_aurora(index: int) -> MeshInstance3D:
 var plane := PlaneMesh.new()
 plane.orientation = PlaneMesh.FACE_Z
 plane.size = Vector2(110, 27)
 plane.subdivide_width = 96
 plane.subdivide_depth = 8
 var ribbon := MeshInstance3D.new()
 ribbon.name = "Curtain%d" % index
 ribbon.mesh = plane
 var mat := _shader(preload("res://scripts/themes/ice_aurora.gdshader"))
 mat.set_shader_parameter("phase", index * 2.1)
 mat.set_shader_parameter("strength", 0.68 - index * 0.13)
 ribbon.material_override = mat
 ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 ribbon.extra_cull_margin = 5.0
 return ribbon

func _snow(root: Node3D, center: Vector3, width: float, length: float) -> void:
 var flakes := MultiMesh.new()
 flakes.transform_format = MultiMesh.TRANSFORM_3D
 var mesh := SphereMesh.new()
 mesh.radius = 0.025
 mesh.height = 0.05
 mesh.radial_segments = 4
 mesh.rings = 2
 flakes.mesh = mesh
 flakes.instance_count = 48
 for i in flakes.instance_count:
  var side := -1.0 if i % 2 == 0 else 1.0
  var at := center + Vector3(side * (width * 0.5 + 2.0 + (i % 7)), float(i % 9) - 5.0, (float(i * 13 % 47) / 47.0 - 0.5) * (length + 14.0))
  flakes.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
 var instance := MultiMeshInstance3D.new()
 instance.name = "SparsePeripheralSnow"
 instance.multimesh = flakes
 instance.material_override = _shader(preload("res://scripts/themes/ice_snow.gdshader"))
 instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 instance.extra_cull_margin = 6.0
 root.add_child(instance)

func _collect(node: Node3D, transform: Transform3D, batches: Dictionary) -> void:
 var local := transform * node.transform
 if node is MeshInstance3D:
  var key := str(node.mesh.get_instance_id()) + "/" + str(node.material_override.get_instance_id())
  if not batches.has(key): batches[key] = {"mesh": node.mesh, "material": node.material_override, "transforms": []}
  batches[key].transforms.append(local)
 for child: Node in node.get_children(): _collect(child, local, batches)

func _batch(root: Node3D) -> void:
 var batches := {}
 for child: Node in root.get_children(): _collect(child, Transform3D.IDENTITY, batches)
 for child: Node in root.get_children():
  root.remove_child(child)
  child.free()
 for key: String in batches:
  var data: Dictionary = batches[key]
  var multi := MultiMesh.new()
  multi.transform_format = MultiMesh.TRANSFORM_3D
  multi.mesh = data.mesh
  multi.instance_count = data.transforms.size()
  for i in data.transforms.size(): multi.set_instance_transform(i, data.transforms[i])
  var instance := MultiMeshInstance3D.new()
  instance.multimesh = multi
  instance.material_override = data.material
  instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root.add_child(instance)

func ramp_materials() -> Dictionary:
 return {"deck": _texture_ramp(), "edge": _library.materials.snow, "support": _library.materials.ice, "accent": _library.materials.glow}

func build_study(_p: Node3D, parent: Node3D, origin: Vector3) -> void:
 parent.position = origin
 var base: MeshInstance3D = _library.box(parent, "ice", Vector3(0, -0.18, 0), Vector3(2.8, 0.36, 2.8))
 base.material_override = cliff_material
 var top: MeshInstance3D = _library.box(parent, "snow", Vector3(0, 0.01, 0), Vector3(2.8, 0.03, 2.8))
 top.material_override = floor_material
 _library.crystal(parent, Vector3(-0.9, 0.04, -0.8), 0.9, 0.15)
 _library.pine(parent, Vector3(0.9, 0.04, -0.8), 1.0, 0.32)
