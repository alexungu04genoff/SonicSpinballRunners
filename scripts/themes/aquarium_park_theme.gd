extends "res://scripts/themes/theme_definition.gd"
## A lantern-lit park above a lagoon. No gameplay water or theme-specific physics.
const Decor = preload("res://scripts/decor/aquarium_park_decor.gd")
var _library: RefCounted

func _init() -> void:
 theme_id = "aquarium_park"
 display_name = "Aquarium Park"
 edge_trim_color = Color("a3bdb8")
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
 sky_material.sky_top_color = Color("030c25")
 sky_material.sky_horizon_color = Color("173650")
 sky_material.ground_bottom_color = Color("071525")
 sky_material.ground_horizon_color = Color("173650")
 sky_material.sun_angle_max = 1.2
 var sky := Sky.new()
 sky.sky_material = sky_material
 world.background_mode = Environment.BG_SKY
 world.sky = sky
 world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.ambient_light_color = Color("b5d5ed")
 world.ambient_light_energy = 0.65
 world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 world.glow_enabled = true
 world.glow_intensity = 0.60
 world.glow_bloom = 0.035
 world.glow_hdr_threshold = 1.1
 world.glow_hdr_scale = 1.0
 var light: DirectionalLight3D = p._key_light
 light.rotation_degrees = Vector3(-48,-28,0)
 light.light_color = Color("c1def0")
 light.light_energy = 0.85
 light.shadow_normal_bias = 2.0

func build_background(p: Node3D) -> void:
 var center: Vector3 = p.map_point(p.table_bounds.get_center())
 var width: float = p.table_bounds.size.x*p.SCALE
 var length: float = p.table_bounds.size.y*p.SCALE
 var root := Node3D.new()
 root.name = "AquariumPark"
 p.scenery_root.add_child(root)
 _water(root,"NightLagoon",center+Vector3(0,-5.8,0),Vector2(width+160,length+160))
 var buildings := Node3D.new()
 buildings.name = "TerracesAndPavilions"
 root.add_child(buildings)
 for x: int in [-1,1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  for z: int in [-1,1]:
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
   var foot := center+Vector3(x*width*0.32,-3.60,z*length*0.32)
   _library.box(buildings,"stone",foot,Vector3(0.7,4.3,0.7))
   _library.box(buildings,"wood",foot+Vector3.UP*1.95,Vector3(1.1,0.25,1.1))
 # Three heights, set outside the table footprint, give the overview a park below it.
 for side: int in [-1,1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  for i in 3:
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
   var at := center+Vector3(side*(width*0.5+3.8),-4.6,(i-1)*maxf(5.5,length*0.38))
   _library.box(buildings,"stone",at,Vector3(4.8,0.48,4.4))
   _library.box(buildings,"wood",at+Vector3.UP*0.26,Vector3(4.55,0.04,4.15))
   _water(root,"TerracePool",at+Vector3.UP*0.31,Vector2(3.8,3.2))
   var prop: Node3D = _library.build_variant("waterside_pavilion" if i%2 == 0 else "reef_aquarium")
   buildings.add_child(prop)
   prop.position = at+Vector3(side*0.9,0.33,-0.5)
   prop.scale = Vector3.ONE*(2.7 if i%2 == 0 else 3.5)
   _library.coral(buildings,at+Vector3(-side*1.4,0.32,0.7),1.1)
   _library.lantern(buildings,at+Vector3(-side*1.7,1.2,-1.3),0.22)
   if i < 2:
    var span: Node3D = _library.build_variant("moon_bridge")
    buildings.add_child(span)
    span.position = at+Vector3(0,0.1,maxf(5.5,length*0.38)*0.5)
    span.rotation.y = PI*0.5
    span.scale = Vector3(maxf(1.2,(maxf(5.5,length*0.38)-3.0)/2.9),1.8,1.5)
  # Large blue tanks and warm palaces alternate, never overhang the physical table.
  var far_at := center+Vector3(side*(width*0.5+10.5),-5.5,-length*0.30)
  _library.tank(buildings,far_at,3.5,9.0,true)
  _library.roof(buildings,far_at+Vector3.UP*9.2,8.0,8.0)
  var palace: Node3D = _library.build_variant("lantern_palace")
  buildings.add_child(palace)
  palace.position = center+Vector3(side*(width*0.5+4.8),-4.4,-length*0.5-7.5)
  palace.scale = Vector3.ONE*3.2
 # A remote aquarium gallery forms the skyline between the two palace silhouettes.
 var back := center+Vector3(0,-5.2,-length*0.5-13.0)
 _library.box(buildings,"stone",back,Vector3(width+14.0,0.7,4.2))
 for i in 5:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var at := back+Vector3((i-2)*(width+10.0)/5.0,0.38,0)
  _library.tank(buildings,at,1.3,3.7)
  _library.roof(buildings,at+Vector3.UP*3.9,3.0,3.0)
 # Sparse perimeter markers help the eye judge scale without cluttering the table.
 for side: int in [-1,1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  for i in 9:
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
   var at := center+Vector3(side*(width*0.5+1.6),-4.8,(float(i)/8.0-0.5)*(length+6.0))
   _library.box(buildings,"stone",at,Vector3(0.42,0.32,0.42))
   _library.bar(buildings,"wood",at,at+Vector3.UP*1.2,0.09)
   _library.lantern(buildings,at+Vector3.UP*1.20,0.17)
 await _batch(buildings, p)
 # Two real spill lights with visible fixtures. Other lanterns use emissive paper.
 for side: int in [-1,1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var at := center+Vector3(side*(width*0.5+1.1),0.3,-length*0.20)
  var lamp := OmniLight3D.new()
  lamp.name = "LanternSpillLeft" if side < 0 else "LanternSpillRight"
  lamp.position = at
  lamp.light_color = Color("ffb86a")
  Atmosphere.tag(lamp, "light_color", "lantern_left" if side < 0 else "lantern_right")
  lamp.light_energy = 1.4
  lamp.omni_range = maxf(5.5,width*0.6)
  lamp.omni_attenuation = 1.8
  lamp.shadow_enabled = false
  root.add_child(lamp)
  _library.bar(root,"wood",at-Vector3.UP*4.8,at+Vector3.UP*0.4,0.12)
  _library.lantern(root,at,0.30)

func _water(root: Node3D, label: String, at: Vector3, size: Vector2) -> void:
 var plane := PlaneMesh.new()
 plane.size = size
 var mesh := MeshInstance3D.new()
 mesh.name = label
 mesh.mesh = plane
 mesh.material_override = _library.materials.water
 mesh.position = at
 mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(mesh)

func _collect(node: Node3D, transform: Transform3D, batches: Dictionary, glass: Array) -> void:
 var local := transform*node.transform
 if node is MeshInstance3D:
  if node.material_override == _library.materials.glass:
   # Keep separate transparent objects for back-to-front sorting between tanks.
   glass.append({"mesh":node.mesh,"transform":local})
  else:
   var key := str(node.mesh.get_instance_id())+"/"+str(node.material_override.get_instance_id())
   if not batches.has(key): batches[key] = {"mesh":node.mesh,"material":node.material_override,"transforms":[]}
   batches[key].transforms.append(local)
 for child: Node in node.get_children(): _collect(child,local,batches,glass)

func _batch(root: Node3D, scheduler: Node = null) -> void:
 var batches := {}
 var glass := []
 for child: Node in root.get_children():
  if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
  _collect(child,Transform3D.IDENTITY,batches,glass)
 for child: Node in root.get_children():
  if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
  root.remove_child(child)
  child.free()
 for key: String in batches:
  if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
  var data: Dictionary = batches[key]
  var multi := MultiMesh.new()
  multi.transform_format = MultiMesh.TRANSFORM_3D
  multi.mesh = data.mesh
  multi.instance_count = data.transforms.size()
  for i in data.transforms.size():
   if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
   _set_instance_transform(multi, i,data.transforms[i])
  var instance := MultiMeshInstance3D.new()
  instance.multimesh = multi
  instance.material_override = data.material
  instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root.add_child(instance)
 for data: Dictionary in glass:
  if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
  var instance := MeshInstance3D.new()
  instance.name = "AquariumGlass"
  instance.mesh = data.mesh
  instance.material_override = _library.materials.glass
  instance.transform = data.transform
  instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root.add_child(instance)

func ramp_materials() -> Dictionary:
 return {"deck":_texture_ramp(),"edge":_library.materials.gold,"support":_library.materials.wood,"accent":_library.materials.cyan}

func build_study(_p: Node3D, parent: Node3D, origin: Vector3) -> void:
 parent.position = origin
 var base: MeshInstance3D = _library.box(parent,"stone",Vector3(0,-0.18,0),Vector3(2.8,0.36,2.8))
 base.material_override = cliff_material
 var cap: MeshInstance3D = _library.box(parent,"stone",Vector3(0,0.01,0),Vector3(2.8,0.03,2.8))
 cap.material_override = floor_material
 _library.lantern(parent,Vector3(-0.8,0.38,-0.8),0.15)
 _library.coral(parent,Vector3(0.7,0.03,-0.8),0.55)
