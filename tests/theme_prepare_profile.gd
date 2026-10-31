extends SceneTree
## Fresh-process player startup and lookahead, including per-batch warm-up events.
const Run = preload("res://scripts/prototype/zone_run.gd")

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var theme := "chemical_plant"
 var output := "res://test-results/theme-prepare.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--profile-theme="): theme = arg.trim_prefix("--profile-theme=")
  if arg.begins_with("--profile-output="): output = arg.trim_prefix("--profile-output=")
 Engine.max_fps = 0
 if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var game := Run.new()
 game.practice_mode = true
 var config := Run.RunPlan.Configuration.new([
  "res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/Reverse C Spring.tres", "res://data/acts/Authored/Secret Entry.tres"])
 config.zone_count = 1
 config.selected_theme_ids = [theme]
 game.run_configuration = config
 var started_at := Time.get_ticks_usec()
 root.add_child(game)
 game.library.profile_enabled = true
 game.library.warm_probes_enabled = not "--profile-no-probes" in OS.get_cmdline_user_args()
 game.library.warm_instanced_probes = not "--profile-ordinary-probes" in OS.get_cmdline_user_args()
 var frames: Array[Dictionary] = []
 var previous := started_at
 var ready_ms := -1.0
 var settled := 0
 while settled < 180 and Time.get_ticks_usec() - started_at < 180000000:
  var stage: String = game.library.profile_stage
  await process_frame
  var now := Time.get_ticks_usec()
  frames.append({"ms": (now - previous) / 1000.0, "stage": stage, "started": game.started})
  previous = now
  if game.started and ready_ms < 0.0: ready_ms = (now - started_at) / 1000.0
  if game.started and not game.library.busy and game.building == null: settled += 1
  else: settled = 0
  if not game.library.error.is_empty(): break
 var prepare_ms := (Time.get_ticks_usec() - started_at) / 1000.0
 var times := frames.map(func(row): return row.ms)
 times.sort()
 var report := {"theme": theme, "ready_ms": ready_ms, "settled_ms": prepare_ms,
  "worst_frame_ms": times[-1], "resident_acts": game.resident.size(), "rebuilds": game.library.fallback_builds,
  "error": game.library.error, "device": RenderingServer.get_video_adapter_name(),
  "command_line": OS.get_cmdline_args(), "seed": game.run_seed,
  "physics_ticks": Engine.physics_ticks_per_second, "window_size": [root.size.x, root.size.y],
  "world_size": [game.view.size.x, game.view.size.y],
  "warm_probes": game.library.warm_probes_enabled, "instanced_probes": game.library.warm_instanced_probes,
  "engine": Engine.get_version_info().string, "events": game.library.profile_events.duplicate(true),
  "cpu": game.library.profile_cpu.duplicate(true), "frames": frames}
 if game.library._theme_bakes.has(theme): report["manifest"] = _manifest_summary(game.library, theme)
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file := FileAccess.open(output, FileAccess.WRITE)
 file.store_string(JSON.stringify(report, " "))
 file.close()
 print("THEME_PREPARE | theme=%s ready_ms=%.3f settled_ms=%.3f worst_ms=%.3f error=%s" % [theme, ready_ms, prepare_ms, times[-1], game.library.error])
 var success: bool = settled >= 180 and game.library.error.is_empty()
 await game.prepare_to_close()
 game.free()
 quit(0 if success else 1)

func _manifest_summary(library: Node, theme: String) -> Dictionary:
 var shaders := {}
 var materials := {}
 var textures := {}
 var visited := {}
 for bake: Resource in library._act_bakes.values(): _resources(bake, visited, shaders, materials, textures)
 for bake: Resource in library._theme_bakes.values(): _resources(bake, visited, shaders, materials, textures)
 var sources := {}
 for shader: Shader in shaders.values():
  var key := shader.code.sha256_text()
  if not sources.has(key): sources[key] = []
  sources[key].append(shader.resource_path)
 var feature_set := {}
 var usage := {}
 for bake: Resource in library._act_bakes.values(): _recipe_usage(bake.visual_recipe, "foreground", usage)
 for bake: Resource in library._theme_bakes.values(): _recipe_usage(bake.visual_recipe, "background", usage)
 var probes: Resource = library._theme_bakes[theme].preload_recipe
 for record: Dictionary in probes.records:
  for signature: String in record.warm_signatures: feature_set[signature] = true
 return {"probe_nodes": probes.records.size(), "probe_features": feature_set.size(), "materials": materials.size(),
  "textures": textures.size(), "shader_resources": shaders.size(), "shader_sources": sources, "usage": usage}

func _recipe_usage(recipe: Resource, kind: String, usage: Dictionary) -> void:
 for record: Dictionary in recipe.records:
  var node: Node = record.scene.instantiate()
  var mesh: Mesh = null
  if node is MeshInstance3D: mesh = node.mesh
  elif node is MultiMeshInstance3D: mesh = record.get("instance_mesh")
  if mesh != null:
   for surface in mesh.get_surface_count():
    var material: Material = node.material_override
    if material == null: material = node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface)
    var key: String = material.shader.code.sha256_text() if material is ShaderMaterial and material.shader != null else "standard"
    if not usage.has(key): usage[key] = {}
    var path := kind + ":" + node.get_class() + ":shadow=" + str(node.cast_shadow)
    usage[key][path] = int(usage[key].get(path, 0)) + 1
  node.free()

func _resources(value: Variant, visited: Dictionary, shaders: Dictionary, materials: Dictionary, textures: Dictionary) -> void:
 if value is Array:
  for item: Variant in value: _resources(item, visited, shaders, materials, textures)
 elif value is Dictionary:
  for item: Variant in value.values(): _resources(item, visited, shaders, materials, textures)
 elif value is Resource:
  var id: int = value.get_instance_id()
  if visited.has(id): return
  visited[id] = true
  if value is Shader: shaders[id] = value
  if value is Material: materials[id] = value
  if value is Texture: textures[id] = true
  if value is PackedScene:
   var state: SceneState = value.get_state()
   for node in state.get_node_count():
    for property in state.get_node_property_count(node):
     _resources(state.get_node_property_value(node, property), visited, shaders, materials, textures)
  else:
   for property: Dictionary in value.get_property_list():
    if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script":
     _resources(value.get(property.name), visited, shaders, materials, textures)
