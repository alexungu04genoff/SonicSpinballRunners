extends "res://scripts/themes/theme_definition.gd"
## A mineral shelf above a deep volcanic chamber. Presentation only.
const Decor = preload("res://scripts/decor/lava_reef_decor.gd")
var _library: RefCounted
## Review opt-in only; the default avoids screen-copy cost and retro shimmer.
var heat_haze_enabled := OS.get_cmdline_user_args().has("--lava-heat-haze")

func _init() -> void:
 theme_id = "lava_reef"
 display_name = "Lava Reef"
 edge_trim_color = Color("c79855")
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
 world.background_mode = Environment.BG_COLOR
 world.background_color = Color("020204")
 world.sky = null
 world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.ambient_light_color = Color("b6b9d4")
 world.ambient_light_energy = 0.55
 world.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 world.glow_enabled = true
 world.glow_intensity = 0.55
 world.glow_bloom = 0.025
 world.glow_hdr_threshold = 1.05
 world.glow_hdr_scale = 1.0
 var light: DirectionalLight3D = p._key_light
 light.rotation_degrees = Vector3(-46, -30, 0)
 light.light_color = Color("ffd0a2")
 light.light_energy = 0.72
 light.shadow_normal_bias = 2.0

func build_background(p: Node3D) -> void:
 var center: Vector3 = p.map_point(p.table_bounds.get_center())
 var width: float = p.table_bounds.size.x * p.SCALE
 var length: float = p.table_bounds.size.y * p.SCALE
 var root := Node3D.new()
 root.name = "VolcanicChamber"
 p.scenery_root.add_child(root)
 _lava_plane(root, "MagmaLake", center + Vector3(0,-7.2,0), Vector2(width+100,length+110), false, 0.78)
 var geology := Node3D.new()
 geology.name = "CavernGeology"
 root.add_child(geology)
 var cavern_materials := {}
 for key: String in ["basalt","facet","deep"]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var rock := _shader(preload("res://scripts/themes/lava_cavern.gdshader"))
  rock.set_shader_parameter("rock_color",Color("386d58") if key == "facet" else (Color("245447") if key == "basalt" else Color("193a3b")))
  cavern_materials[key] = rock
 # Camera-facing rocks form a cutaway. Never put an opaque roof over the deck:
 # the generic top-down/long-Zone overview can sit above any fixed roof height.
 # Nested walls and pillars enclose the lake without placing a roof over cameras.
 # Heights are all scenery coordinates, independent of authored Act geometry.
 for layer in 2:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  for i in 19:
   if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
   var angle := TAU * (float(i)+0.2) / 19.0
   var radius_x := width * 0.5 + 14.0 + layer * 13.0
   var radius_z := length * 0.5 + 15.0 + layer * 14.0
   var at := center + Vector3(cos(angle)*radius_x,-7.4,sin(angle)*radius_z)
   var height := 13.0 + (i*7%6) * 1.1 + layer*4.0
   if sin(angle) > 0.35: height = 7.0 + layer * 2.0
   # Bulbous mineral towers with pointed crowns, as in the original green cave.
   for segment in 5:
    if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
    var taper := 1.0-float(segment)*0.13
    var rock: MeshInstance3D = _library.piece(geology,"boulder","deep" if layer == 1 else "basalt",at+Vector3.UP*height*(0.10+segment*0.19),Vector3((5.0+layer*2.0)*taper,height*0.28,(4.8+layer*2.0)*taper))
    rock.rotation.y = angle*0.7+segment*0.5
   for tooth in 3:
    if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
    _library.piece(geology,"cone","facet",at+Vector3((tooth-1)*1.3,height,0),Vector3(0.75,2.2-abs(tooth-1)*0.6,0.8))
   if layer == 0:
    _library.column(geology,at+Vector3(-1.6,0,2.0),height*0.83,1.55)
    var hanging: MeshInstance3D = _library.piece(geology,"cone","facet",at+Vector3(2.5,height-2.0,0),Vector3(1.6,5.0,1.6))
    hanging.rotation.z = PI
 # Lower side shelves create parallax and show crystals lit from the lake.
 for i in 12:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var side := -1.0 if i%2 == 0 else 1.0
  var at := center + Vector3(side*(width*0.5+4.3+(i%3)*1.6),-6.8,(float(i/2)-2.5)*maxf(3.0,length*0.22))
  _library.column(geology,at,2.3+(i%3)*0.75,1.15)
  if i%3 != 0:
   for j in 3:
    if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
    _library.crystal(geology,at+Vector3((j-1)*0.50,2.7+(i%3)*0.55,0),1.8-abs(j-1)*0.6,0.26,(1-j)*0.20)
  else:
   _library.pipe(geology,at+Vector3(-1.0,2.8,0.3),at+Vector3(1.0,2.8,0.3),0.21)
 # Two monumental falls frame a remote mining terrace. No objects cover the deck.
 var back: float = center.z-length*0.5-7.5
 for side: int in [-1,1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var at := Vector3(center.x+side*(width*0.5+2.6),-1.8,back+1.0)
  _library.column(geology,at+Vector3(-2.0,-5.4,-0.4),12.0,1.3)
  _library.column(geology,at+Vector3(2.0,-5.4,-0.4),10.6,1.15)
  _library.box(geology,"basalt",at+Vector3(0,5.25,-0.20),Vector3(3.4,0.6,0.85))
  _lava_plane(root,"DistantLavaFall",at,Vector2(2.3,10.8),true,1.03)
  if heat_haze_enabled: _heat(root,at+Vector3(0,0,0.12))
 var hoist: Node3D = _library.build_variant("mine_hoist")
 geology.add_child(hoist)
 hoist.position = Vector3(center.x-2.3,-5.1,back+1.8)
 hoist.scale = Vector3.ONE*4.0
 var relic: Node3D = _library.build_variant("shrine_fragment")
 geology.add_child(relic)
 relic.position = Vector3(center.x+3.5,-5.3,back+2.0)
 relic.scale = Vector3.ONE*3.0
 _library.box(geology,"basalt",Vector3(center.x,-5.8,back+1.8),Vector3(14,1.2,4))
 _library.pipe(geology,Vector3(center.x-7,-4.3,back+3.1),Vector3(center.x+7,-4.3,back+3.1),0.48)
 # Oversized purple plumbing and gold junctions are a recurring Act 1 landmark.
 for side: int in [-1,1]:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var pipe_x := center.x+side*(width*0.5+3.5)
  _library.pipe(geology,Vector3(pipe_x,-4.8,back+2),Vector3(pipe_x,2.6,back+2),0.72)
  _library.pipe(geology,Vector3(pipe_x,2.6,back+2),Vector3(pipe_x+side*5.5,2.6,back+2),0.72)
  _library.box(geology,"brass",Vector3(pipe_x,2.6,back+2),Vector3(1.7,1.7,1.7))
  _library.box(geology,"rust",Vector3(pipe_x,2.6,back+2.88),Vector3(1.25,1.25,0.12))
 # Broad crust rafts break the lake into channels, rather than an orange horizon.
 for i in 17:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var side := -1.0 if i%2 == 0 else 1.0
  var at := center+Vector3(side*(width*0.5+6.0+(i%4)*3.0),-7.10,(float(i*7%17)/17.0-0.5)*(length+38))
  var raft: MeshInstance3D = _library.piece(geology,"rock","deep",at,Vector3(2.6+(i%3),0.35,1.7+(i%2)))
  raft.rotation.y = i*1.8
 _cavern_materials(geology,cavern_materials)
 await _batch(geology, p)
 # Three shadowless pools plus procedural wall bounce; never one light per prop.
 for i in 3:
  if p.has_method("stream_checkpoint"): await p.stream_checkpoint()
  var lamp := OmniLight3D.new()
  lamp.name = "MagmaBounce%d" % i
  lamp.position = center+Vector3((-1.0 if i%2 == 0 else 1.0)*(width*0.5+1.5),-0.8,(i-1)*length*0.35)
  lamp.light_color = Color("ff732b")
  lamp.light_energy = 1.1
  lamp.omni_range = maxf(10.0,width*0.7)
  lamp.omni_attenuation = 1.6
  lamp.shadow_enabled = false
  root.add_child(lamp)
 _embers(root,center,width,length)

func _lava_plane(root: Node3D, label: String, at: Vector3, size: Vector2, vertical: bool, radiance: float) -> void:
 var plane := PlaneMesh.new()
 plane.size = size
 plane.orientation = PlaneMesh.FACE_Z if vertical else PlaneMesh.FACE_Y
 var mesh := MeshInstance3D.new()
 mesh.name = label
 mesh.mesh = plane
 mesh.position = at
 var mat := _shader(preload("res://scripts/themes/lava_molten.gdshader"))
 mat.set_shader_parameter("pattern_scale",size*(Vector2(1.1,0.7) if vertical else Vector2(0.65,0.65)))
 mat.set_shader_parameter("flow",Vector2(0.015,-0.3) if vertical else Vector2(0.035,-0.018))
 mat.set_shader_parameter("radiance",radiance)
 mat.set_shader_parameter("lake_edges",not vertical)
 mat.set_shader_parameter("phase",at.x*0.1)
 mesh.material_override = mat
 mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(mesh)

func _heat(root: Node3D, at: Vector3) -> void:
 var plane := PlaneMesh.new()
 plane.orientation = PlaneMesh.FACE_Z
 plane.size = Vector2(3.0,10.6)
 var mesh := MeshInstance3D.new()
 mesh.name = "OptionalLocalHeatHaze"
 mesh.mesh = plane
 mesh.material_override = _shader(preload("res://scripts/themes/lava_heat.gdshader"))
 mesh.position = at
 mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(mesh)

func _embers(root: Node3D, center: Vector3, width: float, length: float) -> void:
 var multi := MultiMesh.new()
 multi.transform_format = MultiMesh.TRANSFORM_3D
 var ember := BoxMesh.new()
 ember.size = Vector3(0.025,0.045,0.018)
 multi.mesh = ember
 multi.instance_count = 32
 for i in multi.instance_count:
  var side := -1.0 if i%2 == 0 else 1.0
  var at := center+Vector3(side*(width*0.5+3.0+i%5),-6.8,(float(i*13%31)/31.0-0.5)*(length+12))
  _set_instance_transform(multi, i,Transform3D(Basis.IDENTITY,at))
 var instance := MultiMeshInstance3D.new()
 instance.name = "SparsePeripheralEmbers"
 instance.multimesh = multi
 instance.material_override = _shader(preload("res://scripts/themes/lava_embers.gdshader"))
 instance.extra_cull_margin = 3.5
 instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(instance)

func _collect(node: Node3D, transform: Transform3D, batches: Dictionary) -> void:
 var local := transform*node.transform
 if node is MeshInstance3D:
  var key := str(node.mesh.get_instance_id())+"/"+str(node.material_override.get_instance_id())
  if not batches.has(key): batches[key] = {"mesh":node.mesh,"material":node.material_override,"transforms":[]}
  batches[key].transforms.append(local)
 for child: Node in node.get_children(): _collect(child,local,batches)

func _cavern_materials(node: Node3D, replacements: Dictionary) -> void:
 if node is MeshInstance3D:
  for key: String in replacements:
   if node.material_override == _library.materials[key]:
    node.material_override = replacements[key]
    break
 for child: Node in node.get_children(): _cavern_materials(child,replacements)

func _batch(root: Node3D, scheduler: Node = null) -> void:
 var batches := {}
 for child: Node in root.get_children():
  if scheduler != null and scheduler.has_method("stream_checkpoint"): await scheduler.stream_checkpoint()
  _collect(child,Transform3D.IDENTITY,batches)
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

func ramp_materials() -> Dictionary:
 return {"deck":_texture_ramp(),"edge":_library.materials.iron,"support":_library.materials.rust,"accent":_library.materials.brass}

func build_study(_p: Node3D, parent: Node3D, origin: Vector3) -> void:
 parent.position = origin
 var base: MeshInstance3D = _library.box(parent,"basalt",Vector3(0,-0.18,0),Vector3(2.8,0.36,2.8))
 base.material_override = cliff_material
 var cap: MeshInstance3D = _library.box(parent,"mineral",Vector3(0,0.01,0),Vector3(2.8,0.03,2.8))
 cap.material_override = floor_material
 _library.crystal(parent,Vector3(-0.8,0.03,-0.8),0.9,0.15)
 _library.pipe(parent,Vector3(0.4,0.14,-0.8),Vector3(1.0,0.14,-0.8),0.09)
