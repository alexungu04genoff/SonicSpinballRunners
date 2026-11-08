extends "res://tests/vulkan_first_use_profile.gd"
## Isolates loading, detached construction, hidden attachment and first real draw.
## Uses actual validated recipe resources. This is not a gameplay performance claim.

func run() -> void:
 var kind := "probes"
 var attachment := "hidden"
 var probe_class := "all"
 var probe_material := "all"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--profile-theme="): theme = arg.trim_prefix("--profile-theme=")
  if arg.begins_with("--profile-output="): output = arg.trim_prefix("--profile-output=")
  if arg.begins_with("--recipe-kind="): kind = arg.trim_prefix("--recipe-kind=")
  if arg.begins_with("--attachment="): attachment = arg.trim_prefix("--attachment=")
  if arg.begins_with("--probe-class="): probe_class = arg.trim_prefix("--probe-class=")
  if arg.begins_with("--probe-material="): probe_material = arg.trim_prefix("--probe-material=")
 if kind not in ["probes", "background", "act"] or attachment not in ["hidden", "layers"] or probe_class not in ["all", "ordinary", "instanced"] or probe_material not in ["all", "standard", "custom"]:
  push_error("Unknown resource-probe condition.")
  quit(1)
  return
 if RenderingServer.get_current_rendering_method() != "forward_plus" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
  push_error("Resource preparation probes require Forward+/Vulkan.")
  quit(1)
  return
 Engine.max_fps = 0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var bake_script: Script = load("res://scripts/endless/geometry_bake.gd")
 var act_path := "res://data/acts/Authored/Reverse C Spring.tres"
 var path: String = bake_script.theme_path(theme) if kind != "act" else bake_script.path_for(act_path, theme)
 phase = "resource_load"
 mark("resource_request")
 ResourceLoader.load_threaded_request(path, "", true)
 while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS: await process_frame
 var bake: Resource = ResourceLoader.load_threaded_get(path)
 if bake == null or not bake.matches_pipeline(theme):
  push_error("Resource probe requires a valid disk bake: " + path)
  quit(1)
  return
 if kind == "act":
  var document: Resource = load("res://scripts/act_editor/act_geometry.gd").load_document(act_path).document
  if document == null or not bake.matches(document, theme) or not bake.has_validated_collisions(document):
   push_error("Resource probe requires the current authored Act and validated collisions: " + path)
   quit(1)
   return
 mark("resource_loaded")
 phase = "resource_only"
 for i in 120: await process_frame
 mark("resource_only_complete")
 var view := SubViewport.new()
 view.size = Vector2i(256, 256)
 view.own_world_3d = true
 load("res://scripts/rendering_options.gd").register_view(view)
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 extra_views.append(view)
 var environment := WorldEnvironment.new()
 environment.environment = bake.environment.duplicate() if kind != "act" else load(bake_script.theme_path(theme)).environment.duplicate()
 if kind != "background":
  environment.environment.background_mode = Environment.BG_COLOR
  environment.environment.sky = null
  environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
  environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
 view.add_child(environment)
 var camera := Camera3D.new()
 view.add_child(camera)
 camera.position = Vector3(3, 16, 16)
 camera.look_at(Vector3(3, 0, 3))
 camera.far = 300.0
 camera.current = true
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-55, -30, 0)
 light.shadow_enabled = kind != "background"
 load("res://scripts/rendering_options.gd").register_light(light)
 view.add_child(light)
 phase = "environment_first_draw"
 for i in 60: await process_frame
 mark("environment_ready")
 var recipe: Resource = bake.preload_recipe if kind == "probes" else bake.visual_recipe
 if kind != "probes" and (probe_class != "all" or probe_material != "all"):
  push_error("Filtering is restricted to independent probe records; production hierarchies stay intact.")
  quit(1)
  return
 var container := Node3D.new()
 container.process_mode = Node.PROCESS_MODE_DISABLED
 var nodes: Array[Node] = []
 phase = "detached_construction"
 var selected: Array[Dictionary] = []
 for i in recipe.records.size():
  var record: Dictionary = recipe.records[i]
  var state: SceneState = record.scene.get_state()
  var node_class := str(state.get_node_type(0))
  var material: Material
  for property in state.get_node_property_count(0):
   if state.get_node_property_name(0, property) == "material_override": material = state.get_node_property_value(0, property)
  if probe_class == "ordinary" and node_class != "MeshInstance3D": continue
  if probe_class == "instanced" and node_class != "MultiMeshInstance3D": continue
  if probe_material == "standard" and not material is BaseMaterial3D: continue
  if probe_material == "custom" and not material is ShaderMaterial: continue
  selected.append({"index": i, "class": node_class, "features": Array(record.warm_signatures),
   "material": material.resource_path if material != null else "", "shader": material.shader.resource_path if material is ShaderMaterial else ""})
  recipe.instantiate_one(i, nodes, container)
  if i % 32 == 31: await process_frame
 mark("detached_constructed")
 for i in 60: await process_frame
 mark("detached_settled")
 var geometries: Array[Node] = container.find_children("*", "GeometryInstance3D", true, false)
 var layers := {}
 for node: GeometryInstance3D in geometries:
  layers[node.get_instance_id()] = node.layers
  if attachment == "layers": node.layers = 0
  node.extra_cull_margin = 16384.0
 container.visible = attachment != "hidden"
 phase = "attached_" + attachment
 view.add_child(container)
 mark("attached")
 for i in 120: await process_frame
 mark("attached_settled")
 phase = "first_visible_draw"
 container.visible = true
 for node: GeometryInstance3D in geometries: node.layers = layers[node.get_instance_id()]
 mark("reveal")
 for i in 120: await process_frame
 mark("reveal_settled")
 await RenderingServer.frame_post_draw
 recording = false
 var counts := {}
 resources(bake, {}, counts)
 var report := {"metadata": Report.metadata(), "theme": theme, "kind": kind, "attachment": attachment,
  "path": path, "fingerprint": bake.pipeline_fingerprint, "marks": marks, "frames": frames,
  "inventory": counts, "recipe_nodes": nodes.size(), "selected": selected,
  "precompile_msaa": ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d"),
  "viewport_msaa": view.msaa_3d, "pipelines": pipelines(), "success": true}
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file := FileAccess.open(output, FileAccess.WRITE)
 file.store_string(JSON.stringify(report))
 file.close()
 view.free()
 quit(0)
