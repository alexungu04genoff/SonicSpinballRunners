extends RefCounted
## Read-only instance inventory. Invoked explicitly by the grounding lab.
const Options = preload("res://scripts/rendering_options.gd")
const Report = preload("res://tests/render_profile_support.gd")

static func mesh_of(node: Node) -> Mesh:
 if node is MeshInstance3D: return node.mesh
 if node is MultiMeshInstance3D and node.multimesh != null: return node.multimesh.mesh
 return null

static func triangles(mesh: Mesh) -> int:
 var result := 0
 if mesh == null: return result
 if mesh is ImmediateMesh: return 0 # Debug lines have no triangle surface arrays.
 for surface in mesh.get_surface_count():
  var arrays := mesh.surface_get_arrays(surface)
  if arrays.is_empty(): continue
  var indices: Variant = arrays[Mesh.ARRAY_INDEX]
  result += (indices.size() if indices != null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
 return result

static func material_state(material: Material) -> Dictionary:
 var result := {"lit": true, "receives_shadows": true, "transparent": false, "shader": "", "hue_role": "", "bindings": ""}
 if material != null:
  result.hue_role = str(material.get_meta("atmosphere_hue", ""))
  result.bindings = str(material.get_meta("atmosphere_bindings", {}))
 if material is BaseMaterial3D:
  result.lit = material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
  result.receives_shadows = not material.disable_receive_shadows and result.lit
  result.transparent = material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
 elif material is ShaderMaterial and material.shader != null:
  var code: String = material.shader.code
  result.shader = material.shader.resource_path
  # Only render modes establish these flags; comments/ALPHA mentions are not proof.
  var expression := RegEx.new()
  expression.compile("render_mode\\s+([^;]+);")
  var modes := ""
  for found: RegExMatch in expression.search_all(code): modes += found.get_string(1)
  result.lit = not "unshaded" in modes
  result.receives_shadows = result.lit and not "shadows_disabled" in modes
  expression.compile("\\bALPHA\\s*=")
  result.transparent = expression.search(code) != null
 return result

static func category(node: Node, world: String, game: Node = null) -> String:
 var path := str(node.get_path()).to_lower()
 if node.has_meta("grounding_proxy"): return "scenery_shadow_proxy"
 if world.begins_with("backdrop"):
  return "act_local_scenery" if "localscenery" in path else "shared_zone_scenery"
 if node is GeometryInstance3D and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: return "hardware_shadow_only"
 var ancestor := node
 while ancestor != null and not ancestor is Viewport:
  if ancestor.has_meta("decor_slot_id"): return "authored_decor"
  if ancestor.has_meta("rail_surface"): return "rails_supports"
  if game != null:
   if ancestor is MeshInstance3D and game.presentation.ring_visuals.has(ancestor): return "rings"
   if ancestor is Node3D and (game.presentation.flipper_visuals.has(ancestor) or game.presentation.flipper_retracted_visuals.has(ancestor) or game.presentation.bumper_visuals.values().has(ancestor)): return "bumpers_flippers"
  if ancestor.get_script() == preload("res://scripts/authored_act/mechanics_presentation.gd"): return "mechanisms"
  ancestor = ancestor.get_parent()
 if node.has_meta("rail_surface"): return "rails_supports"
 var mesh := mesh_of(node)
 if mesh != null:
  for surface in mesh.get_surface_count():
   var material: Material = node.get_active_material(surface) if node is MeshInstance3D else node.material_override
   if material == null: continue
   var role := str(material.get_meta("atmosphere_hue", ""))
   if role in ["terrain_borders", "terrain_ledges"]: return "borders_ledges"
   if role in ["terrain_ground", "terrain_upper", "terrain_walls"]: return "terrain"
   if role == "ramps": return "rails_supports"
   if role in ["decor", "foliage"] and world == "foreground": return "authored_decor_batch"
 if node is GeometryInstance3D and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: return "hardware_shadow_only"
 if "ring" in path: return "rings"
 if "flipper" in path or "bumper" in path: return "bumpers_flippers"
 if "rail" in path and not "terrain" in path: return "rails_supports"
 if "border" in path or "ledge" in path: return "borders_ledges"
 if "decor" in path: return "authored_decor"
 if "mechanic" in path or "gimmick" in path or "goal" in path: return "mechanisms"
 if "terrain" in path or "floor" in path or "facade" in path: return "terrain"
 if "staticbatch" in path: return "mixed_static_batch"
 if "sonic" in path or "character" in path or "ball" in path: return "character"
 return "other_foreground"

static func viewports(game: Node) -> Array[Dictionary]:
 var result: Array[Dictionary] = [{"role": "output", "node": game.get_viewport()}, {"role": "foreground", "node": game.view}, {"role": "composite", "node": game._composite_view}]
 if is_instance_valid(game.library) and is_instance_valid(game.library._view): result.append({"role": "warmup", "node": game.library._view})
 for zone: int in game.backgrounds:
  result.append({"role": "backdrop_%d" % zone, "node": game.backgrounds[zone].layer.view})
 return result

static func viewport_state(view: Viewport, role: String, counters := false) -> Dictionary:
 var update_mode: int = view.render_target_update_mode if view is SubViewport else SubViewport.UPDATE_ALWAYS
 var active := update_mode != SubViewport.UPDATE_DISABLED
 var result := {"role": role, "path": str(view.get_path()), "world_rid": str(view.find_world_3d().scenario) if not view.disable_3d else "2D", "size": [view.size.x, view.size.y],
  "native_3d_size": [roundi(view.size.x * view.scaling_3d_scale), roundi(view.size.y * view.scaling_3d_scale)], "scale": view.scaling_3d_scale,
  "msaa_samples": [0, 2, 4, 8][view.msaa_3d], "screen_space_aa": view.screen_space_aa,
  "disable_3d": view.disable_3d, "has_camera_3d": view.get_camera_3d() != null, "update_mode": update_mode, "active": active}
 if counters:
  var rid := view.get_viewport_rid()
  for kind: int in [RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS]:
   var counts := {}
   for index in 3:
    counts[["objects", "primitives", "draws"][index]] = RenderingServer.viewport_get_render_info(rid, kind, index) if active else 0
   result[["visible", "shadow", "canvas"][kind]] = counts
  var supported := RenderingServer.get_current_rendering_method() != "gl_compatibility"
  result["render_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(rid) if active and supported else null
  result["render_gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(rid) if active and supported else null
 return result

static func settings(game: Node) -> Dictionary:
 var views: Array[Dictionary] = []
 var active_3d := 0
 for entry: Dictionary in viewports(game):
  var state := viewport_state(entry.node, entry.role)
  views.append(state)
  if state.active and not state.disable_3d and state.has_camera_3d: active_3d += 1
 var light: DirectionalLight3D = game.presentation._key_light
 var directions: Array[Dictionary] = []
 var world_lights: Array = [{"world": "foreground", "light": light}]
 for zone: int in game.backgrounds: world_lights.append({"world": "backdrop_%d" % zone, "light": game.backgrounds[zone].layer.light})
 for entry: Dictionary in world_lights:
  var current: DirectionalLight3D = entry.light
  directions.append({"world": entry.world, "rotation_degrees": [current.rotation_degrees.x, current.rotation_degrees.y, current.rotation_degrees.z],
   "ray_direction": str(-current.global_basis.z), "color": str(current.light_color), "energy": current.light_energy,
   "shadows": current.shadow_enabled, "shadow_max_distance": current.directional_shadow_max_distance})
 return {"metadata": Report.metadata(), "pixel_profile": Options.pixel_profile(), "viewports": views,
  "directional_lights": directions,
  "active_3d_viewports": active_3d, "shadow_atlas_applied": Options.shadow_resolution(), "shadow_atlas_getter_available": false,
  "cascade_count": [1, 2, 4][light.directional_shadow_mode], "ultra_filter": Options.ultra_filter_enabled(),
  "filter_quality_submitted": Options.filter_quality(), "fxaa": game.view.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA,
  "shadow_blur": light.shadow_blur, "sun_angular_size_deg": light.light_angular_distance,
  "project_filter_quality": ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"),
  "project_msaa_hint": ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d"),
  "retro": game.retro_filter.selected_effects.duplicate(), "retro_name": game.retro_filter.display_name(),
  "light_rotation_degrees": [light.rotation_degrees.x, light.rotation_degrees.y, light.rotation_degrees.z],
  "light_color": str(light.light_color), "light_energy": light.light_energy, "light_shadows": light.shadow_enabled,
  "ambient_energy": game.presentation._world_environment.environment.ambient_light_energy,
  "exposure": game.presentation._world_environment.environment.tonemap_exposure}

static func inventory(game: Node) -> Dictionary:
 var rows: Array[Dictionary] = []
 var lights: Array[Dictionary] = []
 var semantic_nodes: Array[Dictionary] = []
 var animated_nodes: Array[Dictionary] = []
 for entry: Dictionary in viewports(game):
  if entry.role in ["output", "composite"]: continue
  var nodes: Array[Node] = [entry.node]
  while not nodes.is_empty():
   var node: Node = nodes.pop_back()
   nodes.append_array(node.get_children())
   if node.get_script() != null and (node.is_processing() or node.is_physics_processing()):
    animated_nodes.append({"world": entry.role, "path": str(node.get_path()), "script": node.get_script().resource_path,
     "process_enabled": node.is_processing(), "physics_process_enabled": node.is_physics_processing(), "can_process_now": node.can_process()})
   if not node.get_meta_list().is_empty():
    var tags := {}
    for key: StringName in node.get_meta_list(): tags[str(key)] = str(node.get_meta(key))
    semantic_nodes.append({"path": str(node.get_path()), "tags": tags})
   if node is Light3D:
    lights.append({"world": entry.role, "path": str(node.get_path()), "type": node.get_class(), "shadows": node.shadow_enabled,
     "visible": node.is_visible_in_tree(), "cull_mask": node.light_cull_mask})
   var mesh := mesh_of(node)
   if mesh == null: continue
   var count: int = node.multimesh.instance_count if node is MultiMeshInstance3D else 1
   var materials: Array[Dictionary] = []
   for surface in mesh.get_surface_count():
    var material: Material = node.get_active_material(surface) if node is MeshInstance3D else (node.material_override if node.material_override != null else mesh.surface_get_material(surface))
    materials.append(material_state(material))
   var metadata := {}
   for key: StringName in node.get_meta_list(): metadata[str(key)] = str(node.get_meta(key))
   rows.append({"path": str(node.get_path()), "world": entry.role, "category": category(node, entry.role, game), "class": node.get_class(), "mesh_resource": mesh.resource_path,
    "mesh_instance_id": mesh.get_instance_id(),
    "visible": node.is_visible_in_tree(), "cast_shadow": node.cast_shadow, "surfaces": mesh.get_surface_count(), "instances": count,
    "triangles": triangles(mesh) * count, "materials": materials, "layers": node.layers, "metadata": metadata,
    "transform": str(node.global_transform), "bounds": str(node.global_transform * node.get_aabb())})
 var enemies: Array[Dictionary] = []
 for act: RefCounted in game.resident:
  for animation: Dictionary in act.recipe.animations:
   if animation.script != preload("res://scripts/authored_act/mechanics_presentation.gd"): continue
   for entry: Dictionary in act.nodes[animation.index].enemies:
    var leaves: Array[Dictionary] = []
    for child: Node in entry.root.find_children("*", "GeometryInstance3D", true, false):
     leaves.append({"path": str(child.get_path()), "visible": child.visible, "in_tree": child.is_visible_in_tree(), "layers": child.layers,
      "cast": child.cast_shadow, "transform": var_to_str(child.global_transform), "bounds": str(child.global_transform * child.get_aabb())})
    enemies.append({"sequence": act.plan.sequence, "id": entry.item.object_id, "alive": entry.item.alive,
     "root_visible": entry.root.visible, "body_visible": entry.body.visible, "root_transform": var_to_str(entry.root.global_transform),
     "body_transform": var_to_str(entry.body.global_transform), "meshes": leaves})
 return {"settings": settings(game), "lights": lights, "meshes": rows, "semantic_nodes": semantic_nodes, "processing_nodes": animated_nodes, "enemy_visuals": enemies,
  "interpretation": "Inventory is live instance state, not actual visible pixels or shadow-pass submissions. Shader receive flags indicate eligibility; backdrop meshes cannot receive the foreground light. Static batches may mix authored categories. Unknown shader includes require source corroboration."}
