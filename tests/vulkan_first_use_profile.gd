extends SceneTree
## Explicit graphical diagnostic. No settings, resources or production policy are saved.
const Report = preload("res://tests/render_profile_support.gd")
var game: Node
var frames: Array[Dictionary] = []
var marks: Array[Dictionary] = []
var monitors := {}
var measured := {}
var last_us := 0
var pre_us := 0
var last_pipelines := {}
var before_draw := {}
var recording := true
var phase := "script_startup"
var output := "res://test-results/vulkan-first-use.json"
var theme := "green_hill"
var mode := "prototype"
var first_visible := false
var extra_views: Array[Viewport] = []

func _initialize() -> void:
 # Diagnostic hint only: registered production viewports still use their normal policy.
 if "--profile-precompile-msaa=4" in OS.get_cmdline_user_args():
  ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_4X)
 for name: String in ClassDB.class_get_integer_constant_list("Performance"):
  if name.begins_with("PIPELINE_COMPILATIONS_"):
   monitors[name] = ClassDB.class_get_integer_constant("Performance", name)
 last_us = Time.get_ticks_usec()
 last_pipelines = pipelines()
 mark("script_initialize")
 RenderingServer.frame_pre_draw.connect(_pre_draw)
 RenderingServer.frame_post_draw.connect(_post_draw)
 call_deferred("run")

func pipelines() -> Dictionary:
 var result := {}
 for name: String in monitors: result[name] = int(Performance.get_monitor(monitors[name]))
 return result

func difference(after: Dictionary, before: Dictionary) -> Dictionary:
 var result := {}
 for name: String in after: result[name] = after[name] - before.get(name, 0)
 return result

func mark(label: String) -> void:
 marks.append({"name": label, "at_us": Time.get_ticks_usec(), "pipelines": pipelines(),
  "resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
  "memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC))})

func _pre_draw() -> void:
 if not recording: return
 pre_us = Time.get_ticks_usec()
 before_draw = pipelines()

func _post_draw() -> void:
 if not recording: return
 var now := Time.get_ticks_usec()
 var counts := pipelines()
 var row := {"start_us": last_us, "end_us": now, "frame_ms": (now - last_us) / 1000.0,
  "render_wall_ms": (now - pre_us) / 1000.0, "phase": phase,
  "pipelines": counts, "delta": difference(counts, last_pipelines),
  "before_draw": before_draw, "draw_interval_delta": difference(counts, before_draw),
  "resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
  "memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
  "video_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
  "draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
  "objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)}
 var views: Array[Viewport] = [root]
 views.append_array(extra_views)
 if is_instance_valid(game) and is_instance_valid(game.get("library")):
  row.stage = game.library.profile_stage
  row.batch_context = game.library._warm_context.duplicate(true)
  row.batch = game.library._warm_batch.duplicate(true)
  row.started = game.started
  row.loading_boundary = game.loading_boundary
  row.resident_acts = game.resident.size()
  row.sequence = game.active_sequence
  row.act_bakes = game.library._act_bakes.keys()
  row.theme_bakes = game.library._theme_bakes.keys()
  if game.started and not first_visible:
   first_visible = true
   mark("first_visible_game_frame_post_draw")
  views.append(game.view)
  views.append(game._composite_view)
  views.append(game.library._view)
  for background: Dictionary in game.backgrounds.values(): views.append(background.layer.view)
 var cpu := RenderingServer.get_frame_setup_time_cpu()
 var gpu := 0.0
 for view: Viewport in views:
  if not is_instance_valid(view): continue
  if not measured.has(view.get_instance_id()):
   RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
   measured[view.get_instance_id()] = true
  if view is SubViewport and view.render_target_update_mode == SubViewport.UPDATE_DISABLED: continue
  cpu += RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())
  gpu += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
 row.render_cpu_ms = cpu
 row.render_gpu_ms = gpu
 frames.append(row)
 last_us = now
 last_pipelines = counts

func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--profile-theme="): theme = arg.trim_prefix("--profile-theme=")
  if arg.begins_with("--profile-output="): output = arg.trim_prefix("--profile-output=")
  if arg.begins_with("--profile-mode="): mode = arg.trim_prefix("--profile-mode=")
 if mode not in ["prototype", "endless"]:
  push_error("Unknown first-use profiling mode: " + mode)
  quit(1)
  return
 if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
  push_error("First-use profiling requires graphical Forward+/Vulkan.")
  quit(1)
  return
 Engine.max_fps = 0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 root.gui_disable_input = true
 var settings := {}
 for property: Dictionary in ProjectSettings.get_property_list():
  if "pipeline" in str(property.name) or "shader_cache" in str(property.name) or "msaa_3d" in str(property.name): settings[property.name] = ProjectSettings.get_setting(property.name)
 var metadata := Report.metadata()
 metadata.merge({"monitors": monitors, "settings": settings, "user_data_dir": OS.get_user_data_dir(),
  "script_initialize_us": last_us, "theme": theme, "mode": mode,
  "note": "Application-cache conditions belong to the runner receipt. GPU driver cache is uncontrolled. Counters count requests, not compiler duration. CPU/GPU timings are delayed viewport work, not additive wall components."})
 phase = "game_construction"
 mark("before_game_script_load")
 var script: Script = load("res://scripts/endless/endless_game.gd" if mode == "endless" else "res://scripts/prototype/zone_run.gd")
 mark("after_game_script_load")
 if script == null or not script.can_instantiate():
  push_error("The production game script could not be loaded.")
  quit(1)
  return
 game = script.new()
 if mode == "prototype":
  game.practice_mode = true
  var config: RefCounted = game.RunPlan.Configuration.new([
   "res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/Reverse C Spring.tres", "res://data/acts/Authored/Secret Entry.tres"])
  config.zone_count = 1
  config.selected_theme_ids = [theme]
  game.run_configuration = config
 var start_us := Time.get_ticks_usec()
 root.add_child(game)
 game.library.profile_enabled = true
 game.library.warm_probes_enabled = not "--profile-no-probes" in OS.get_cmdline_user_args()
 Report.disable_native_input(game)
 mark("game_attached")
 phase = "startup"
 var ready_us := -1
 var settled := 0
 while settled < 180 and Time.get_ticks_usec() - start_us < 240000000:
  await process_frame
  if game.started and ready_us < 0:
   ready_us = Time.get_ticks_usec()
   mark("first_act_ready")
   phase = "lookahead"
  if game.started and not game.library.busy and game.building == null: settled += 1
  else: settled = 0
  if not game.library.error.is_empty(): break
 mark("lookahead_settled")
 var success: bool = settled >= 180 and game.library.error.is_empty() and game.library.fallback_builds == 0
 if success:
  phase = "steady"
  for i in 300: await process_frame
  mark("steady_complete")
  if mode == "endless":
   phase = "traversal"
   game.toggle_tour()
   game.tour_speed = 400.0
   var tour_start := Time.get_ticks_usec()
   while game.active_sequence < 6 and Time.get_ticks_usec() - tour_start < 180000000: await process_frame
   mark("traversal_complete")
   success = game.active_sequence >= 6 and game.library.fallback_builds == 0
 await RenderingServer.frame_post_draw
 recording = false
 var report := {"metadata": metadata, "success": success, "error": game.library.error,
  "ready_ms": (ready_us - start_us) / 1000.0 if ready_us >= 0 else -1,
  "ready_from_engine_ms": ready_us / 1000.0, "marks": marks, "frames": frames,
  "events": game.library.profile_events.duplicate(true), "pipelines": pipelines(),
  "resident_acts": game.resident.size(), "rebuilds": game.library.fallback_builds,
  "visual_reuse": game.library.reused_visual_nodes, "course": game.course_snapshot() if mode == "prototype" else [],
  "world_size": [game.view.size.x, game.view.size.y], "window_size": [root.size.x, root.size.y],
  "camera": {"transform": str(game.presentation.camera.global_transform)},
  "quality": load("res://scripts/rendering_options.gd").pixel_profile(),
  "inventory": inventory(game.library), "recipe_inventory": recipe_inventories(game.library),
  "live_inventory": live_inventory(game),
  "timing": Report.timing(frames.map(func(row): return row.frame_ms))}
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file := FileAccess.open(output, FileAccess.WRITE)
 file.store_string(JSON.stringify(report))
 file.close()
 print("VULKAN_FIRST_USE | theme=%s ready_ms=%.3f worst_ms=%.3f success=%s" % [theme, report.ready_ms, report.timing.max_ms, success])
 # Readback occurs after all measurements and inventory.
 root.get_texture().get_image().save_png(output.get_basename() + ".png")
 await game.prepare_to_close()
 game.free()
 quit(0 if success else 1)

func inventory(library: Node) -> Dictionary:
 var visited := {}
 var counts := {}
 for bake: Resource in library._act_bakes.values(): resources(bake, visited, counts)
 for bake: Resource in library._theme_bakes.values(): resources(bake, visited, counts)
 return counts

func live_inventory(owner: Node) -> Dictionary:
 var visited := {}
 var counts := {}
 var geometry_count := 0
 for node: Node in owner.find_children("*", "GeometryInstance3D", true, false):
  geometry_count += 1
  resources(node.material_override, visited, counts)
  resources(node.material_overlay, visited, counts)
  if node is MeshInstance3D and node.mesh != null:
   resources(node.mesh, visited, counts)
   for surface in node.mesh.get_surface_count(): resources(node.get_active_material(surface), visited, counts)
  elif node is MultiMeshInstance3D and node.multimesh != null:
   resources(node.multimesh.mesh, visited, counts)
 return {"counts": counts, "resources": visited, "geometry_nodes": geometry_count}

func recipe_inventories(library: Node) -> Dictionary:
 var result := {}
 var bakes: Dictionary = library._act_bakes.duplicate()
 for key: String in library._theme_bakes: bakes[key] = library._theme_bakes[key]
 for key: String in bakes:
  var visited := {}
  var counts := {}
  resources(bakes[key], visited, counts)
  result[key] = {"counts": counts, "resources": visited, "path": bakes[key].resource_path,
   "pipeline_fingerprint": bakes[key].pipeline_fingerprint,
   "records": bakes[key].visual_recipe.records.size()}
 return result

func resources(value: Variant, visited: Dictionary, counts: Dictionary) -> void:
 if value is Array:
  for item: Variant in value: resources(item, visited, counts)
 elif value is Dictionary:
  for item: Variant in value.values(): resources(item, visited, counts)
 elif value is Resource:
  if visited.has(value.get_instance_id()): return
  visited[value.get_instance_id()] = {}
  var category := "other"
  if value is Material: category = "materials"
  elif value is Mesh: category = "meshes"
  elif value is Shader: category = "shaders"
  elif value is Texture: category = "textures"
  counts[category] = counts.get(category, 0) + 1
  visited[value.get_instance_id()] = {"category": category, "path": value.resource_path}
  if value is Shader: visited[value.get_instance_id()]["code_sha256"] = value.code.sha256_text()
  if value is PackedScene:
   var state: SceneState = value.get_state()
   for node in state.get_node_count():
    for property in state.get_node_property_count(node): resources(state.get_node_property_value(node, property), visited, counts)
  else:
   for property: Dictionary in value.get_property_list():
    if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script": resources(value.get(property.name), visited, counts)
