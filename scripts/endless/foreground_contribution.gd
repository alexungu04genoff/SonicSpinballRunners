extends RefCounted
## Presentation only. Bounds are cached once per resident instance, never per frame.
## Unknown geometry fails open; visibility never changes processing or gameplay state.
const MechanicsVisual = preload("res://scripts/authored_act/mechanics_presentation.gd")
const Flicky = preload("res://scripts/decor/island_flicky.gd")
const GrassBounds = preload("res://scripts/themes/rooftop_grass_bounds.gd")
const RingSpin = preload("res://scripts/ring_spin.gd")
const GUARD := 0.25 # 25 table pixels, including halo/shell displacement and edge filtering.
var bounds := AABB()
var valid := false
var supported := true
var reason := "warming"
var capture_usec := 0
var _materials := {}
var _shader_checks := {}
var _vertex_write := RegEx.create_from_string("\\b(VERTEX|POSITION)\\s*(\\.[xyzrgb]{1,3})?\\s*[+*/-]?=")

func capture(act: RefCounted) -> void:
 var began := Time.get_ticks_usec()
 valid = false
 supported = true
 _materials.clear()
 _shader_checks.clear()
 _collect(act.visual)
 # Mutable nodes retain their own visibility/state. Enclose their complete motion,
 # including hidden death flashes, retracted paddles and initially hidden hardware.
 for index: int in act.recipe.flippers: _planar_motion(act.nodes[index])
 for index: int in act.recipe.rings: _planar_motion(act.nodes[index])
 for index: int in act.recipe.bumpers.values(): _scaled_motion(act.nodes[index], Vector3(1, 2, 1))
 for animation: Dictionary in act.recipe.animations:
  var node: Node3D = act.nodes[animation.index]
  if not act.visual.is_ancestor_of(node): continue # Separate scenery viewport.
  if animation.script == MechanicsVisual:
   for entry: Dictionary in node.enemies:
    var patrol := absf(entry.item.properties.patrol_right - entry.item.properties.patrol_left) * TablePresentation.SCALE
    _motion(entry.root, 3.0, Vector3(patrol, 0, 0))
   for entry: Dictionary in node.gimmicks:
    match entry.kind:
     "diverter": _planar_motion(entry.arm)
     "slingshot": _scaled_motion(entry.rubber, Vector3(1, 3, 1))
     "spring": _include(_subtree_bounds(entry.pad).grow(0.1))
     "switch": _include(_subtree_bounds(entry.pad).grow(0.1))
   for entry: Dictionary in node.spinners: _motion(entry.paddle)
   for entry: Dictionary in node.fields: _motion(entry.arcs, 1.0, Vector3(entry.radius, 0, entry.radius))
  elif animation.script == Flicky:
   _motion(node)
  else:
   supported = false
 if valid: bounds = bounds.grow(GUARD)
 _materials.clear()
 _shader_checks.clear()
 capture_usec = Time.get_ticks_usec() - began

func _include(box: AABB) -> void:
 if not box.position.is_finite() or not box.size.is_finite():
  supported = false
  return
 bounds = bounds.merge(box) if valid else box
 valid = true

func _collect(node: Node) -> void:
 if node is Node3D and node.top_level: supported = false
 if node is GeometryInstance3D:
  if node is MeshInstance3D or node is MultiMeshInstance3D or node is Label3D:
   var rotating := _ring_material(node.material_override) or _ring_material(node.material_overlay)
   var mesh: Mesh
   if node is MeshInstance3D: mesh = node.mesh
   elif node is MultiMeshInstance3D and node.multimesh != null: mesh = node.multimesh.mesh
   if mesh != null:
    for surface in mesh.get_surface_count():
     rotating = rotating or _ring_material(node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface))
   if rotating and not RingSpin.bound(node): supported = false
   var box: AABB = node.get_aabb()
   if node.custom_aabb != AABB(): box = box.merge(node.custom_aabb)
   var displacement := maxf(_check_material(node.material_override), _check_material(node.material_overlay))
   if mesh != null:
    for surface in mesh.get_surface_count():
     displacement = maxf(displacement, _check_material(node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface)))
   # The same finite envelope must reach Godot's per-mesh culler, not only this
   # Act-level test. Set once at attachment; larger authored margins survive.
   if displacement > node.extra_cull_margin: node.extra_cull_margin = displacement
   _include(node.global_transform * box.grow(node.extra_cull_margin))
   if node is Label3D: _motion(node) # Billboard orientation can change with camera.
  else:
   supported = false # Particles/deformation need an explicit finite envelope.
 elif node is Light3D or node is Decal or node is ReflectionProbe or node is AnimationMixer or node is Skeleton3D:
  supported = false
 for child: Node in node.get_children(): _collect(child)

func _ring_material(material: Material) -> bool:
 if material == null: return false
 return RingSpin.is_material(material) or _ring_material(material.next_pass)

func _check_material(material: Material) -> float:
 if material == null: return 0.0
 if _materials.has(material): return _materials[material]
 _materials[material] = 0.0
 var displacement := 0.0
 if material is ShaderMaterial and material.shader != null:
  # Vertex programs are not CPU mesh bounds. Unknown writes fail open. Includes
  # are inspected once too (current palette/normal includes do not move vertices).
  var code: String = material.shader.code
  var grass_vertex := GrassBounds.vertex_code()
  if material.has_meta("grass_shell_fraction") and code.contains(grass_vertex):
   displacement = GrassBounds.MAX_OFFSET
   # Recognize only the shared clamped program. Remaining code/includes still
   # undergo the ordinary unknown-deformation check; a tag alone grants nothing.
   code = code.replace(grass_vertex, "")
  if RingSpin.is_material(material): code = code.replace(RingSpin.vertex_code(), "")
  var key: String = material.shader.resource_path.get_base_dir() + "\n" + code
  if not _shader_checks.has(key): _shader_checks[key] = _shader_bounded(code, material.shader.resource_path.get_base_dir(), {})
  if not _shader_checks[key]: supported = false
 elif material is BaseMaterial3D and (material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or material.grow):
  supported = false
 displacement = maxf(displacement, _check_material(material.next_pass))
 _materials[material] = displacement
 return displacement

func _shader_bounded(code: String, directory: String, visited: Dictionary) -> bool:
 if not _vertex_write.search_all(code).is_empty(): return false
 var includes := RegEx.create_from_string('#include\\s+"([^"]+)"')
 for found: RegExMatch in includes.search_all(code):
  var path := found.get_string(1)
  if not path.begins_with("res://") and not path.begins_with("user://"): path = directory.path_join(path)
  if visited.has(path): continue
  visited[path] = true
  var include := load(path) as ShaderInclude
  if include == null or not _shader_bounded(include.code, path.get_base_dir(), visited): return false
 return true

func _subtree_bounds(node: Node3D) -> AABB:
 var box := AABB(node.global_position, Vector3.ZERO)
 if node is GeometryInstance3D:
  var geometry: AABB = node.get_aabb()
  if node.custom_aabb != AABB(): geometry = geometry.merge(node.custom_aabb)
  box = box.merge(node.global_transform * geometry.grow(node.extra_cull_margin))
 for child: Node in node.get_children():
  if child is Node3D: box = box.merge(_subtree_bounds(child))
 return box

func _planar_motion(node: Node3D) -> void:
 var box := _subtree_bounds(node)
 var radius := 0.0
 for i in 8:
  var offset := box.get_endpoint(i) - node.global_position
  radius = maxf(radius, Vector2(offset.x, offset.z).length())
 _include(AABB(Vector3(node.global_position.x - radius, box.position.y, node.global_position.z - radius), Vector3(radius * 2, box.size.y, radius * 2)))

func _scaled_motion(node: Node3D, maximum: Vector3) -> void:
 var box := _subtree_bounds(node)
 var local := node.global_transform.affine_inverse() * box
 _include(node.global_transform * AABB(local.position * maximum, local.size * maximum))

func _motion(node: Node3D, maximum_scale := 1.0, translation := Vector3.ZERO) -> void:
 # Triangle inequality through the hierarchy encloses arbitrary child rotations.
 # 3x covers current pulse/death scaling (maximum 2.5x); 0.2 local units covers
 # spring compression, Flicky hops and Buzz hover. Long flippers use real meshes.
 var scale_value := node.global_basis.get_scale().abs()
 var radius := (_radius(node) * maximum_scale + 0.2) * maxf(scale_value.x, maxf(scale_value.y, scale_value.z))
 var reach := Vector3.ONE * radius + translation
 _include(AABB(node.global_position - reach, reach * 2.0))

func _radius(node: Node3D) -> float:
 var radius := 0.0
 if node is GeometryInstance3D:
  var box: AABB = node.get_aabb()
  if node.custom_aabb != AABB(): box = box.merge(node.custom_aabb)
  box = box.grow(node.extra_cull_margin)
  for i in 8: radius = maxf(radius, box.get_endpoint(i).length())
 for child: Node in node.get_children():
  if child is Node3D:
   var s: Vector3 = child.scale.abs()
   radius = maxf(radius, child.position.length() + maxf(s.x, maxf(s.y, s.z)) * _radius(child))
 return radius

static func intersects(box: AABB, planes: Array[Plane]) -> bool:
 # Godot frustum normals point outwards. Reject only a box wholly outside a plane.
 for plane: Plane in planes:
  var nearest := box.position
  for axis in 3:
   if plane.normal[axis] < 0.0: nearest[axis] += box.size[axis]
  if plane.distance_to(nearest) > 0.0: return false
 return true

static func shadow_reaches(box: AABB, light: DirectionalLight3D, receiver_floor: float, camera: Camera3D, planes: Array[Plane]) -> bool:
 var direction := -light.global_basis.z.normalized()
 var spread := sin(deg_to_rad(clampf(light.light_angular_distance, 0.0, 90.0)))
 var downward := -direction.y - spread
 if downward <= 0.01: return true # Horizon/upward light: fail open.
 var distance := maxf(0.0, box.end.y - receiver_floor) / downward
 # Shadow distance is a camera-depth limit, NOT a maximum caster-to-receiver ray.
 # Never clamp the extrusion to it. Use it only to overestimate shadow texel/bias
 # padding; keeping the full camera frustum also covers all cascade configurations.
 var viewport_size := camera.get_viewport().get_visible_rect().size
 var aspect_guard := maxf(1.0, viewport_size.x / maxf(1.0, viewport_size.y))
 var depth := maxf(maxf(camera.far, camera.size), light.directional_shadow_max_distance) * aspect_guard
 var atlas := float(preload("res://scripts/rendering_options.gd").shadow_resolution())
 var bias_guard := depth * 8.0 / atlas * (absf(light.shadow_normal_bias) + absf(light.shadow_bias) + 1.0)
 var padding := distance * spread * (1.0 + 1.0 / -direction.y) + bias_guard + GUARD
 # Test the swept convex volume directly. Its world AABB invents high floating
 # receivers at the far end of a downward ray and keeps distant Acts needlessly.
 var endpoints := PackedVector3Array()
 for i in 8:
  var corner := box.get_endpoint(i)
  endpoints.append(corner)
  endpoints.append(corner + direction * maxf(0.0, corner.y - receiver_floor) / -direction.y)
 for plane: Plane in planes:
  var nearest := INF
  for point: Vector3 in endpoints: nearest = minf(nearest, plane.distance_to(point))
  if nearest > padding: return false
 return true

func contributes(planes: Array[Plane], light: DirectionalLight3D, receiver_floor: float, camera: Camera3D) -> bool:
 if not valid or not supported:
  reason = "unbounded"
  return true
 if intersects(bounds, planes):
  reason = "camera"
  return true
 if is_instance_valid(light) and light.shadow_enabled:
  if shadow_reaches(bounds, light, receiver_floor, camera, planes):
   reason = "shadow"
   return true
 reason = "outside"
 return false
