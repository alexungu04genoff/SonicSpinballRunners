extends RefCounted
## Process-local, Zone-owned control. Native C leaves shader TIME and Flicky clocks
## untouched. References are weak; retired Acts cannot be retained by this owner.
const Registry = preload("res://scripts/theme_motion/registry.gd")
const Flicky = preload("res://scripts/decor/island_flicky.gd")
var theme := ""
var zone := 0
var candidate := "C"
var tier := "NATIVE"
var time := -1.0
var error := ""
var cpu_motion_usec := 0
var _age := 0.0
var _materials: Array[Dictionary] = []
var _bindings: Array[Dictionary] = []
var _flickies: Array[Dictionary] = []
var _gpu_nodes: Array[Dictionary] = []
var _seen_gpu_nodes := {}
var _seen := {}
var _seen_materials := {}
var _running := false
var _foreground_active := false

func configure(theme_id: String, zone_index := 0) -> void:
 theme = theme_id
 zone = zone_index
 _age = float(zone_index) * 1.731
 candidate = Registry.PRODUCTION.get(theme, "C")
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--motion-candidate="): candidate = argument.trim_prefix("--motion-candidate=").to_upper()
  if argument.begins_with("--motion-tier="): tier = argument.trim_prefix("--motion-tier=").to_upper()
 if candidate not in ["C", "A", "B"] or tier not in Registry.TIERS:
  error = "Invalid Theme Motion command-line selection."
  push_error(error)
  candidate = "C"
  tier = "NATIVE"

func attach(root: Node, scenery := false) -> void:
 if theme not in Registry.IDS: return
 var nodes: Array[Node] = [root]
 nodes.append_array(root.find_children("*", "", true, false))
 for node: Node in nodes:
  if _seen.has(node.get_instance_id()): continue
  _seen[node.get_instance_id()] = true
  if node.get_script() == Flicky:
   _flickies.append({"node":weakref(node), "process":node.is_processing(), "scenery":scenery, "mesh_count":_mesh_count(node)})
  if node.has_meta("theme_motion"):
   var raw: Variant = node.get_meta("theme_motion")
   var problem := Registry.binding_error(raw)
   if not problem.is_empty() or not node is Node3D:
    error = problem if not problem.is_empty() else "Theme Motion binding requires Node3D."
    push_error(error)
    continue
   var spec: Dictionary = raw
   var entry := {"node":weakref(node), "spec":spec.duplicate(true), "base":node.transform, "scenery":scenery, "mesh_count":_mesh_count(node)}
   if spec.kind == "signal":
    if not node is MeshInstance3D or node.mesh == null:
     error = "Theme Motion signal requires a material-bearing mesh."
     push_error(error)
     continue
    var material: Material = node.get_active_material(0)
    if not material is BaseMaterial3D and not material is ShaderMaterial:
     error = "Unsupported Theme Motion signal material."
     push_error(error)
     continue
    entry.material = weakref(material)
    entry.emission = material.get_shader_parameter("emission_energy") if material is ShaderMaterial else material.emission_energy_multiplier
    if entry.emission == null:
     error = "Theme Motion signal material has no emission_energy uniform."
     push_error(error)
     continue
   _bindings.append(entry)
  if node is GeometryInstance3D:
   _material(node.material_override, node)
   _material(node.material_overlay, node)
   if node is MeshInstance3D and node.mesh != null:
    for surface in node.mesh.get_surface_count(): _material(node.get_active_material(surface), node)
   elif node is MultiMeshInstance3D and node.material_override == null and node.multimesh != null and node.multimesh.mesh != null:
    for surface in node.multimesh.mesh.get_surface_count(): _material(node.multimesh.mesh.surface_get_material(surface), node)
 _apply()

func _mesh_count(node: Node) -> int:
 var count := 1 if node is MeshInstance3D else 0
 if node is MultiMeshInstance3D and node.multimesh != null: count += node.multimesh.instance_count
 for child: Node in node.get_children(): count += _mesh_count(child)
 return count

func _material(material: Material, node: GeometryInstance3D) -> void:
 if material == null: return
 var id := Registry.shader_id(material)
 if Registry.SYSTEMS.get(id, "") == theme:
  # Existing background cull margins remain authoritative. Candidate cloud
  # motion adds only its explicitly bounded local displacement.
  var margin := 0.0
  if id == "green_hill_cloud": margin = 0.45
  elif id == "sanctuary_cloud_volume": margin = 1.2
  if margin > node.extra_cull_margin: node.extra_cull_margin = margin
  if id in ["green_hill_cloud", "sanctuary_cloud_volume", "ice_snow", "ice_aurora"] and not _seen_gpu_nodes.has(node.get_instance_id()):
   _seen_gpu_nodes[node.get_instance_id()] = true
   _gpu_nodes.append({"node":weakref(node), "system":id, "instances":node.multimesh.instance_count if node is MultiMeshInstance3D and node.multimesh != null else 1})
  if not _seen_materials.has(material.get_instance_id()):
   _seen_materials[material.get_instance_id()] = true
   _materials.append({"material":weakref(material), "system":id,
    "candidate_uniform":material.shader.code.contains("uniform int motion_candidate"),
    "time_uniform":material.shader.code.contains("uniform float time_override")})
 _material(material.next_pass, node)

func select(state := "C", quality := "NATIVE") -> bool:
 if theme not in Registry.IDS or state not in ["C", "A", "B"] or quality not in Registry.TIERS: return false
 candidate = state
 tier = quality
 _apply()
 return true

func seek(seconds: float) -> bool:
 if not is_finite(seconds) or (seconds < 0.0 and seconds != -1.0): return false
 time = seconds
 _apply()
 return true

func update(delta: float, visible := true) -> void:
 var changed := _running != visible
 _running = visible
 if changed:
  for entry: Dictionary in _flickies:
   var node: Node = entry.node.get_ref()
   if node != null and entry.scenery:
    node.set_process(visible and entry.process and time < 0.0 and _enabled("flicky"))
 cpu_motion_usec = 0
 _age += maxf(delta, 0.0)
 if not visible and not _foreground_active: return
 if delta <= 0.0: return
 if time >= 0.0 or tier == "STATIC": return
 if candidate == "C": return
 var started := Time.get_ticks_usec()
 _apply_nodes(true)
 cpu_motion_usec = Time.get_ticks_usec() - started

func _enabled(system: String) -> bool:
 return tier != "STATIC" and (tier != "SIGNATURE" or Registry.primary(theme, candidate, system))

func _apply() -> void:
 var started := Time.get_ticks_usec()
 _foreground_active = false
 for entry: Dictionary in _bindings:
  if entry.node.get_ref() != null and not entry.scenery and entry.spec.candidate == candidate and _enabled("binding"):
   _foreground_active = true
 for entry: Dictionary in _materials:
  var material: ShaderMaterial = entry.material.get_ref()
  if material == null: continue
  if entry.time_uniform: material.set_shader_parameter("time_override", time if _enabled(entry.system) else 0.0)
  if entry.candidate_uniform: material.set_shader_parameter("motion_candidate", ["C", "A", "B"].find(candidate))
 for entry: Dictionary in _flickies:
  var node: Node = entry.node.get_ref()
  if node == null: continue
  var controlled := time >= 0.0 or not _enabled("flicky")
  node.set_process(false if controlled else entry.process and (not entry.scenery or _running))
  if controlled: node.set_animation_time(time if _enabled("flicky") else 0.0)
 _apply_nodes()
 cpu_motion_usec = Time.get_ticks_usec() - started

func _apply_nodes(visible_only := false) -> void:
 var seconds := time if time >= 0.0 else _age
 for entry: Dictionary in _bindings:
  var node: Node3D = entry.node.get_ref()
  if node == null: continue
  if visible_only and (not node.is_visible_in_tree() or node.process_mode == Node.PROCESS_MODE_DISABLED): continue
  if visible_only and entry.scenery and not _running: continue
  var spec: Dictionary = entry.spec
  var selected: bool = candidate == spec.candidate
  var t := seconds if _enabled("binding") else 0.0
  var angle := TAU * fposmod(t, float(spec.period)) / float(spec.period) + float(spec.get("phase", 0.0))
  if spec.kind == "signal":
   var material: Material = entry.material.get_ref()
   if material == null: continue
   var value: float = float(entry.emission) * (0.86 + 0.14 * sin(angle) if selected else 1.0)
   if material is ShaderMaterial: material.set_shader_parameter("emission_energy", value)
   else: material.emission_energy_multiplier = value
  else:
   var pose: Transform3D = entry.base
   if selected:
    var axis: Vector3 = spec.axis.normalized()
    if spec.kind == "drift": pose.origin += axis * float(spec.amplitude) * sin(angle)
    elif spec.kind == "rotate": pose.basis = entry.base.basis * Basis(axis, fposmod(angle, TAU) * float(spec.amplitude) / TAU)
   # One native transform submission per changed pose. Inactive candidates and
   # repeated paused seeks do not dirty unchanged descendants or render bounds.
   if node.transform != pose: node.transform = pose

func stats() -> Dictionary:
 var systems: Array[String] = []
 var material_count := 0
 for entry: Dictionary in _materials:
  if entry.material.get_ref() == null: continue
  var animated := _enabled(entry.system)
  if entry.system in ["green_hill_cloud", "sanctuary_cloud_volume"]: animated = animated and candidate == "A"
  elif entry.system == "sanctuary_clouds": animated = animated and candidate == "B"
  if animated:
   material_count += 1
   if entry.system not in systems: systems.append(entry.system)
 var moving := 0
 var active_bindings := 0
 var signal_materials := {}
 for entry: Dictionary in _gpu_nodes:
  if entry.node.get_ref() == null or entry.system not in systems: continue
  moving += entry.instances
 var native_callbacks := 0
 for entry: Dictionary in _bindings:
  if entry.node.get_ref() == null or entry.spec.candidate != candidate or not _enabled("binding"): continue
  active_bindings += 1
  if entry.spec.kind == "signal":
   var material: Material = entry.material.get_ref()
   if material != null: signal_materials[material.get_instance_id()] = true
  else: moving += entry.mesh_count
 for entry: Dictionary in _flickies:
  var node: Node = entry.node.get_ref()
  if node == null: continue
  if _enabled("flicky"):
   moving += entry.mesh_count
   if "flicky" not in systems: systems.append("flicky")
  if node.is_processing() and node.can_process(): native_callbacks += 1
 if active_bindings > 0 and "binding" not in systems: systems.append("binding")
 var shared_callback := 1 if (_running or _foreground_active) and active_bindings > 0 and time < 0.0 and tier != "STATIC" else 0
 var diagnostic_driver := 1 if time >= 0.0 else 0
 return {"theme":theme, "zone":zone, "candidate":candidate, "tier":tier, "time":time,
  "animated_materials":material_count + signal_materials.size(), "moving_meshes":moving,
  "cpu_callbacks":native_callbacks + shared_callback + diagnostic_driver,
  "native_cpu_callbacks":native_callbacks + shared_callback, "diagnostic_driver_callbacks":diagnostic_driver,
  "cpu_motion_usec":cpu_motion_usec, "systems":systems, "controllers":1, "bindings":_bindings.size(), "error":error}

func release() -> void:
 _materials.clear()
 _bindings.clear()
 _flickies.clear()
 _gpu_nodes.clear()
 _seen.clear()
 _seen_materials.clear()
 _seen_gpu_nodes.clear()
 _running = false
 _foreground_active = false
