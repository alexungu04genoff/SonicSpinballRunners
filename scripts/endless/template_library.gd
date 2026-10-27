extends Node
## Bounded, demand-driven preparation. During play only the rolling lookahead
## requests variants; the offline authoring tool explicitly requests its bake set.
signal progress(message: String)
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Plan = preload("res://scripts/endless/endless_plan.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
const Retirement = preload("res://scripts/endless/resource_retirement.gd")
const MAX_VARIANTS := 8
const MAX_THEMES := 3
var documents: Array = []
var runtimes := {}
var shapes := {}
var themes := {}
var visuals := {}
var backgrounds := {}
var environments := {}
var lights := {}
var error := ""
var busy := false
var use_disk_bakes := true
var paths: Array = []
var bake_hits := 0
var last_computed_jobs := 0
var last_reused_jobs := 0
var requested_count := 0
var cache_hits := 0
var max_prepare_slice_ms := 0.0
var visual_bake_hits := 0
var theme_bake_hits := 0
var fallback_builds := 0
var last_prepare_ms := 0.0
var last_warm_frames := 0
var theme_prefetches := 0
var last_theme_prepare_ms := 0.0
var preparing_theme := ""
var theme_attempts := {}
var theme_materials := {}
var bake_status := "Not requested"
var profile_stage := "idle"
var profile_max_cpu_ms := {}
var profile_resource_wait_ms := 0.0
var profile_enabled := "--profile-stages" in OS.get_cmdline_user_args()
var profile_events: Array[Dictionary] = []
var profile_cpu := {}
var _fingerprints := {}
var _fingerprint_jobs := {}
var _primed_themes := {}
var _primed_paths := {}
var _warmed_features := {}
var _prepared_visuals := {}
var reused_visual_nodes := 0
var _act_bakes := {}
var _theme_bakes := {}
var retirement := Retirement.new()
var _lru: Array[String] = []
var _theme_lru: Array[String] = []
var _game: Node
var _view: SubViewport
var _retiring_physics: Array[Node] = []
var _retiring_runtime: Dictionary = {}

func _process(_delta: float) -> void:
 if not _retiring_physics.is_empty():
  var physics_started := Time.get_ticks_usec()
  _step_physics_retirement()
  _record_cpu("physics.retire", physics_started)
 if retirement.pending_count() == 0: return
 # Keep resources pinned until old live nodes have released their references;
 # otherwise the final node free could inherit the entire resource teardown.
 var retiring_nodes: Variant = _game.get("retire_nodes") if is_instance_valid(_game) else null
 if retiring_nodes is Array and not retiring_nodes.is_empty(): return
 var started_at := Time.get_ticks_usec()
 retirement.step(64, 500)
 _record_cpu("cache.retire", started_at)

func prepare(game: Node, act_paths: Array = Plan.PATHS, validate_pool := true, loaded_documents: Array = []) -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 _game = game
 paths = act_paths.duplicate()
 if not loaded_documents.is_empty():
  if loaded_documents.size() != paths.size():
   error = "The loaded Act pool does not match its source paths."
   return
  documents.assign(loaded_documents)
 else:
  for path: String in paths:
   var loaded := Document.load_document(path)
   if loaded.document == null:
    error = loaded.error
    return
   documents.append(loaded.document)
 if validate_pool: error = Plan.pool_error(documents)
 _view = SubViewport.new()
 _view.name = "StreamingWarmup"
 _view.size = Vector2i(256, 256)
 _view.own_world_3d = true
 _view.msaa_3d = game.view.msaa_3d
 _view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 add_child(_view)

func has_variant(theme_id: String, id: int) -> bool:
 return visuals.has(key(theme_id, id)) and backgrounds.has(theme_id)

func request_theme(theme_id: String) -> bool:
 # No Act file, physics template or gameplay node is needed for this request.
 if busy or not error.is_empty() or not use_disk_bakes: return false
 if backgrounds.has(theme_id) or theme_attempts.has(theme_id): return false
 theme_attempts[theme_id] = true
 preparing_theme = theme_id
 busy = true
 _prefetch_theme.call_deferred(theme_id)
 return true

func prime_theme(theme_id: String) -> void:
 # Disk reads and validation can overlap the current Act's staged graphics
 # work. This bounded hint loads only the next theme, never an Act variant.
 if not use_disk_bakes or _primed_themes.has(theme_id) or not error.is_empty(): return
 _primed_themes[theme_id] = true
 _start_fingerprint(theme_id)
 var path := Bake.theme_path(theme_id)
 if backgrounds.has(theme_id) or not ResourceLoader.exists(path): return
 var started_at := Time.get_ticks_usec()
 if ResourceLoader.load_threaded_request(path, "", true) == OK: _primed_paths[path] = true
 _record_cpu("theme.prime_request", started_at)

func _start_fingerprint(theme_id: String) -> void:
 if _fingerprints.has(theme_id) or _fingerprint_jobs.has(theme_id): return
 var worker := Thread.new()
 worker.start(Bake.pipeline_hash.bind(theme_id), Thread.PRIORITY_LOW)
 _fingerprint_jobs[theme_id] = worker

func _fingerprint(theme_id: String) -> String:
 profile_stage = "fingerprint.wait"
 var started_at := Time.get_ticks_usec()
 if not _fingerprints.has(theme_id):
  _start_fingerprint(theme_id)
  var worker: Thread = _fingerprint_jobs[theme_id]
  while worker.is_alive(): await get_tree().process_frame
  _fingerprints[theme_id] = worker.wait_to_finish()
  _fingerprint_jobs.erase(theme_id)
 _record_event("validation.wait", started_at, {"theme": theme_id})
 return _fingerprints[theme_id]

func _prefetch_theme(theme_id: String) -> void:
 var started_at := Time.get_ticks_usec()
 last_warm_frames = 0
 var fingerprint := await _fingerprint(theme_id)
 var ready := await _load_theme(theme_id, fingerprint)
 last_theme_prepare_ms = (Time.get_ticks_usec() - started_at) / 1000.0
 if ready: theme_prefetches += 1
 print("ENDLESS_THEME_PREFETCH | ", theme_id, " | ready=", ready, " | ms=", last_theme_prepare_ms,
  " | Act recipes=", visuals.size(), " | physics templates=", runtimes.size())
 preparing_theme = ""
 busy = false
 profile_stage = "idle"

func _load_theme(theme_id: String, fingerprint: String) -> bool:
 if backgrounds.has(theme_id): return true
 var background: Resource = await _load_bake(Bake.theme_path(theme_id))
 if not background is Bake or background.kind != "theme" or not background.matches_pipeline(theme_id, fingerprint) or background.visual_recipe == null: return false
 if not background.visual_recipe.has_warm_manifest() or background.preload_recipe == null or not background.preload_recipe.has_warm_manifest(): return false
 _theme_bakes[theme_id] = background
 environments[theme_id] = background.environment
 lights[theme_id] = background.light
 backgrounds[theme_id] = background.visual_recipe
 theme_materials[theme_id] = background.preload_materials
 themes[theme_id] = {"display_name": Registry.NAMES[Registry.IDS.find(theme_id)]}
 _theme_lru.erase(theme_id)
 _theme_lru.append(theme_id)
 # Tiny probes upload foreground textures and warm material/shadow features.
 # They contain no terrain, props, Act layout or collision data.
 var probes: Resource = background.preload_recipe
 if not probes.records.is_empty(): await _warm_recipe(probes, theme_id, "probes")
 await _warm_recipe(background.visual_recipe, theme_id, "background")
 theme_bake_hits += 1
 return true

func request(theme_id: String, id: int) -> void:
 var variant := key(theme_id, id)
 if has_variant(theme_id, id):
  cache_hits += 1
  _lru.erase(variant)
  _lru.append(variant)
  return
 if busy or not error.is_empty(): return
 busy = true
 requested_count += 1
 _build.call_deferred(theme_id, id)

func _build(theme_id: String, id: int) -> void:
 var started_at := Time.get_ticks_usec()
 last_warm_frames = 0
 progress.emit("Loading %s · %s and warming graphics…" % [Registry.NAMES[Registry.IDS.find(theme_id)], str(paths[id]).get_file().get_basename()])
 await get_tree().process_frame
 var fingerprint := await _fingerprint(theme_id)
 var saved: Resource = await _load_bake(Bake.path_for(paths[id], theme_id))
 bake_status = "missing" if saved == null else "stale or incomplete"
 if not saved is Bake or not saved.matches(documents[id], theme_id, fingerprint) or saved.visual_recipe == null or not saved.has_validated_collisions(documents[id]):
  error = "The %s bake is %s. Run Bake Endless.cmd, then restart Endless mode." % [key(theme_id, id), bake_status]
  busy = false
  return
 if not saved.visual_recipe.has_warm_manifest():
  error = "Missing offline warm-up metadata. Run Bake Endless.cmd."
  busy = false
  return
 if not backgrounds.has(theme_id) and not await _load_theme(theme_id, fingerprint):
  error = "The %s theme bake is missing or stale. Run Bake Endless.cmd." % theme_id
  busy = false
  return
 bake_status = "disk"
 bake_hits += 1
 if not await _prepare_runtime(id, saved, fingerprint):
  busy = false
  return
 _theme_lru.erase(theme_id)
 _theme_lru.append(theme_id)
 _act_bakes[key(theme_id, id)] = saved
 await _warm_recipe(saved.visual_recipe, theme_id, "act", key(theme_id, id))
 visuals[key(theme_id, id)] = saved.visual_recipe
 _lru.append(key(theme_id, id))
 visual_bake_hits += 1
 last_computed_jobs = 0
 last_reused_jobs = saved.geometry_job_count
 _finish_request(theme_id, id, started_at, "disk")

func _prepare_runtime(id: int, saved: Resource = null, fingerprint := "") -> bool:
 if runtimes.has(id): return true
 profile_stage = "physics.compile"
 var started_at := Time.get_ticks_usec()
 var runtime: Dictionary
 if saved != null:
  runtime = Compiler.compile_baked(documents[id], _game.tuning, _game.controls, _game.ball, saved, fingerprint)
 else:
  runtime = Compiler.compile(documents[id], _game.tuning, _game.controls, _game.ball)
 _record_cpu("physics.compile", started_at)
 _record_event("physics.prepare", started_at, {"act_path": paths[id], "validation_reused": runtime.get("validation_reused", false), "timings": runtime.get("timings", {})})
 if not runtime.error.is_empty():
  error = runtime.error
  return false
 runtimes[id] = runtime
 if saved != null:
  shapes[id] = saved.collisions
  return true
 var records: Array = []
 for item: Dictionary in runtime.terrain:
  var body: StaticBody2D = item.body
  var body_shapes: Array = []
  for owner: int in body.get_shape_owners():
   for i in body.shape_owner_get_shape_count(owner):
    body_shapes.append({"shape": body.shape_owner_get_shape(owner, i), "transform": body.shape_owner_get_transform(owner)})
  records.append(body_shapes)
  await get_tree().process_frame
 shapes[id] = records
 return true

func _finish_request(theme_id: String, id: int, started_at: int, source: String) -> void:
 last_prepare_ms = (Time.get_ticks_usec() - started_at) / 1000.0
 busy = false
 profile_stage = "idle"
 print("ENDLESS_PREPARED | ", key(theme_id, id), " | source=", source, " | ms=", last_prepare_ms, " | GPU warm frames=", last_warm_frames, " | cached=", visuals.size(), " | geometry loaded=", last_reused_jobs, " | geometry generated=", last_computed_jobs)

func _record_cpu(label: String, started_at: int) -> void:
 var elapsed := (Time.get_ticks_usec() - started_at) / 1000.0
 profile_max_cpu_ms[label] = maxf(profile_max_cpu_ms.get(label, 0.0), elapsed)
 if not profile_enabled: return
 if not profile_cpu.has(label): profile_cpu[label] = {"count": 0, "total_ms": 0.0, "max_ms": 0.0}
 var sample: Dictionary = profile_cpu[label]
 sample.count += 1
 sample.total_ms += elapsed
 sample.max_ms = maxf(sample.max_ms, elapsed)
 if elapsed >= 2.0: _record_event("cpu." + label, started_at)

func _record_event(label: String, started_at: int, details: Dictionary = {}, finished_at := -1) -> void:
 if not profile_enabled: return
 var event := details.duplicate()
 event.merge({"name": label, "start_us": started_at, "end_us": Time.get_ticks_usec() if finished_at < 0 else finished_at,
  "sequence": _game.get("active_sequence") if is_instance_valid(_game) else -1})
 event.elapsed_ms = (event.end_us - event.start_us) / 1000.0
 profile_events.append(event)

func _load_bake(path: String) -> Resource:
 profile_stage = "resource.request"
 if not ResourceLoader.exists(path): return null
 var started_at := Time.get_ticks_usec()
 if _primed_paths.has(path):
  _primed_paths.erase(path)
 elif ResourceLoader.load_threaded_request(path, "", true) != OK:
  return null
 _record_cpu("resource.request", started_at)
 profile_stage = "resource.wait"
 while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS: await get_tree().process_frame
 profile_resource_wait_ms += (Time.get_ticks_usec() - started_at) / 1000.0
 _record_event("resource.wait", started_at, {"path": path})
 if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED: return null
 profile_stage = "resource.collect"
 started_at = Time.get_ticks_usec()
 var result: Resource = ResourceLoader.load_threaded_get(path)
 _record_cpu("resource.collect", started_at)
 return result

func _warm_recipe(recipe: Resource, theme_id: String, kind := "act", retain_variant := "") -> void:
 profile_stage = "scene.instantiate"
 var started_at := Time.get_ticks_usec()
 var root := Node3D.new()
 root.process_mode = Node.PROCESS_MODE_DISABLED
 _view.add_child(root)
 var environment := WorldEnvironment.new()
 environment.environment = environments[theme_id].duplicate()
 var is_background: bool = recipe == backgrounds[theme_id]
 if not is_background:
  environment.environment.background_mode = Environment.BG_COLOR
  environment.environment.sky = null
  environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
  environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
 root.add_child(environment)
 var light := DirectionalLight3D.new()
 light.rotation = lights[theme_id].rotation
 light.light_color = lights[theme_id].color
 light.light_energy = lights[theme_id].energy
 if not is_background:
  for property: String in ["shadow_enabled", "directional_shadow_mode", "directional_shadow_blend_splits", "shadow_bias", "directional_shadow_max_distance"]:
   light.set(property, _game.presentation._key_light.get(property))
  light.shadow_normal_bias = lights[theme_id].bias
 root.add_child(light)
 var camera := Camera3D.new()
 root.add_child(camera)
 camera.position = Vector3(3, 16, 16)
 camera.look_at(Vector3(3, 0, 3))
 camera.far = 300.0
 camera.current = true
 var nodes: Array[Node] = []
 var signatures := {}
 var deadline := Time.get_ticks_usec() + 1000
 for i in recipe.records.size():
  var node_started := Time.get_ticks_usec()
  recipe.instantiate_one(i, nodes, root)
  signatures[nodes[-1].get_instance_id()] = recipe.records[i].warm_signatures
  _record_cpu("scene.node", node_started)
  if Time.get_ticks_usec() >= deadline:
   await get_tree().process_frame
   deadline = Time.get_ticks_usec() + 1000
 root.process_mode = Node.PROCESS_MODE_ALWAYS
 var instantiated_at := Time.get_ticks_usec()
 var details := {"theme": theme_id, "kind": kind, "nodes": nodes.size()}
 _record_event("warm.instantiate", started_at, details, instantiated_at)
 var feature_key := theme_id + (":background" if is_background else ":foreground")
 if not _warmed_features.has(feature_key): _warmed_features[feature_key] = {}
 await _warm(root, environment, false, _warmed_features[feature_key], signatures)
 var warmed_at := Time.get_ticks_usec()
 _record_event("warm.graphics", instantiated_at, details, warmed_at)
 if not retain_variant.is_empty():
  # Detach children before parents, so each tree operation handles one node.
  # Preserve recipe order and local transforms for incremental live attachment.
  root.process_mode = Node.PROCESS_MODE_DISABLED
  # Register ownership before the first yield during detachment, including
  # shutdown while only part of the graph has left the warm-up viewport.
  _prepared_visuals[retain_variant] = nodes
  deadline = Time.get_ticks_usec() + 1000
  for index in range(nodes.size() - 1, -1, -1):
   var node: Node = nodes[index]
   if node is GeometryInstance3D:
    node.visible = recipe.records[index].warm_visible
    node.extra_cull_margin = recipe.records[index].warm_cull_margin
   node.get_parent().remove_child(node)
   if Time.get_ticks_usec() >= deadline:
    await get_tree().process_frame
    deadline = Time.get_ticks_usec() + 1000
 await _dispose(root)
 _record_event("warm.handoff" if not retain_variant.is_empty() else "warm.retire", warmed_at, details)
 print("ENDLESS_DISK_WARM | ", theme_id, " | nodes=", nodes.size(), " | instantiate_ms=", (instantiated_at - started_at) / 1000.0, " | graphics_ms=", (warmed_at - instantiated_at) / 1000.0, " | retire_ms=", (Time.get_ticks_usec() - warmed_at) / 1000.0)
 _view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func take_prepared_visuals(variant: String) -> Array[Node]:
 var result: Array[Node] = []
 if not _prepared_visuals.has(variant): return result
 result.assign(_prepared_visuals[variant])
 _prepared_visuals.erase(variant)
 reused_visual_nodes += result.size()
 return result

func _warm(p: Node3D, world_environment: WorldEnvironment = null, warm_foreground := true, known_features: Dictionary = {}, baked_signatures: Dictionary = {}, overlay: Node = null) -> void:
 var renderables: Array[Node] = p.find_children("*", "GeometryInstance3D", true, false)
 var render_state := _begin_warm_visibility(renderables, overlay)
 _view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 # Render the sky on its own before introducing geometry/shader permutations.
 # Foreground recipes use a clear-color environment; waiting for an absent sky
 # added two idle frames to every probe and Act preparation.
 if world_environment.environment.background_mode == Environment.BG_SKY:
  await _draw_frames()
 await _warm_pass(renderables, overlay, known_features, baked_signatures, render_state)
 if warm_foreground:
  # The procedural fallback presenter mixes Act and background geometry. Disk
  # recipes instead warm only the environment in which they will actually draw.
  var foreground: Environment = world_environment.environment.duplicate()
  foreground.background_mode = Environment.BG_COLOR
  foreground.sky = null
  foreground.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
  foreground.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
  world_environment.environment = foreground
  await _warm_pass(renderables, overlay, {}, {}, render_state)
 # Retained nodes recover their authored state before detaching. Stop the
 # viewport first so restoration cannot submit the entire scene at once.
 _view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 _end_warm_visibility(render_state)

func _begin_warm_visibility(renderables: Array[Node], overlay: Node) -> Dictionary:
 var state := {"geometry": {}, "visibility": {}}
 # Visibility inherits through Node3D parents. Hide only each mesh's rendering
 # layers, otherwise warming a child after its parent leaves the child hidden.
 for node: GeometryInstance3D in renderables:
  state.geometry[node.get_instance_id()] = {"node": node, "layers": node.layers, "margin": node.extra_cull_margin}
  node.layers = 0
 # Disable all geometry before showing authored hidden parents. This includes
 # non-rendering ancestors such as retracted-object groups.
 for node: GeometryInstance3D in renderables:
  if overlay != null and (node == overlay or overlay.is_ancestor_of(node)): continue
  var ancestor: Node = node
  while ancestor is Node3D:
   var id := ancestor.get_instance_id()
   if state.visibility.has(id): break
   state.visibility[id] = {"node": ancestor, "visible": ancestor.visible}
   ancestor.show()
   ancestor = ancestor.get_parent()
 return state

func _end_warm_visibility(state: Dictionary) -> void:
 for item: Dictionary in state.geometry.values():
  item.node.layers = item.layers
  item.node.extra_cull_margin = item.margin
 for item: Dictionary in state.visibility.values(): item.node.visible = item.visible

func _warm_pass(renderables: Array[Node], overlay: Node, warmed: Dictionary = {}, baked_signatures: Dictionary = {}, render_state: Dictionary = {}) -> void:
 var owns_state := render_state.is_empty()
 if owns_state: render_state = _begin_warm_visibility(renderables, overlay)
 profile_stage = "graphics.queue"
 var batch: Array[GeometryInstance3D] = []
 var cold_features := 0
 # Cold shader features still get their own frame. Known features can upload
 # more meshes together; eight per frame made the 400 px/s tour outrun loading.
 var batch_limit := 32 if _game.get("started") == true else 64
 for node: GeometryInstance3D in renderables:
  var queue_started := Time.get_ticks_usec()
  if overlay != null and (node == overlay or overlay.is_ancestor_of(node)): continue
  var original_layers: int = render_state.geometry[node.get_instance_id()].layers
  node.layers = original_layers if original_layers != 0 else 1
  # Keep every material inside the frustum at least once, including off-camera
  # props. Use a generous AABB without altering any visible gameplay instance.
  node.extra_cull_margin = 16384.0
  var signatures: Variant
  if baked_signatures.has(node.get_instance_id()):
   signatures = baked_signatures[node.get_instance_id()]
  else:
   var signature_started := Time.get_ticks_usec()
   signatures = _shader_signatures(node)
   if profile_enabled: _record_cpu("graphics.signatures", signature_started)
  for signature: Variant in signatures:
   if not warmed.has(signature):
    warmed[signature] = true
    cold_features += 1
  batch.append(node)
  _record_cpu("graphics.queue", queue_started)
  # Colors and uniform values do not require a different shader. The previous
  # per-material-instance wait spent hundreds of frames on equivalent programs.
  if cold_features >= 1 or batch.size() >= batch_limit:
   await _draw_frames(1)
   for shown: GeometryInstance3D in batch: shown.layers = 0
   batch.clear()
   cold_features = 0
 if not batch.is_empty():
  await _draw_frames(1)
  for shown: GeometryInstance3D in batch: shown.layers = 0
 if owns_state: _end_warm_visibility(render_state)

func _shader_signatures(node: GeometryInstance3D) -> Array[int]:
 var materials: Array[Material] = []
 if node.material_override != null: materials.append(node.material_override)
 elif node is MeshInstance3D:
  for i in node.mesh.get_surface_count(): materials.append(node.get_active_material(i))
 elif node is MultiMeshInstance3D and node.multimesh != null:
  for i in node.multimesh.mesh.get_surface_count(): materials.append(node.multimesh.mesh.surface_get_material(i))
 var result: Array[int] = []
 for material: Material in materials:
  if material is ShaderMaterial: result.append(hash([node.get_class(), material.shader.get_instance_id()]))
  elif material is BaseMaterial3D:
   var features: Array = [node.get_class(), material.get_class()]
   for property: Dictionary in material.get_property_list():
    if int(property.usage) & PROPERTY_USAGE_STORAGE == 0: continue
    var value: Variant = material.get(property.name)
    if value is bool or value is int: features.append([property.name, value])
    elif value is Texture2D: features.append(property.name)
   result.append(hash(features))
 return result

func _draw_frames(count := 2) -> void:
 var previous_stage := profile_stage
 profile_stage = "graphics.draw"
 for i in count:
  last_warm_frames += 1
  await get_tree().process_frame
  if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
 profile_stage = previous_stage

func _dispose(root: Node) -> void:
 profile_stage = "scene.retire"
 var nodes: Array[Node] = [root]
 var index := 0
 while index < nodes.size():
  nodes[index].process_mode = Node.PROCESS_MODE_DISABLED
  nodes[index].set_process(false)
  nodes[index].set_physics_process(false)
  nodes.append_array(nodes[index].get_children())
  index += 1
 var deadline := Time.get_ticks_usec() + 1000
 while not nodes.is_empty():
  var free_started := Time.get_ticks_usec()
  nodes.pop_back().free()
  _record_cpu("scene.free", free_started)
  if Time.get_ticks_usec() >= deadline:
   await get_tree().process_frame
   deadline = Time.get_ticks_usec() + 1000

func trim(protected: Array, reserve_variant := 0, reserve_theme := 0) -> bool:
 var trim_started := Time.get_ticks_usec()
 var pinned := {}
 var pinned_themes := {}
 var pinned_ids := {}
 for entry: Dictionary in protected:
  pinned[key(entry.theme, entry.id)] = true
  pinned_themes[entry.theme] = true
  pinned_ids[entry.id] = true
 for variant: String in _lru.duplicate():
  if visuals.size() <= MAX_VARIANTS - reserve_variant: break
  if pinned.has(variant): continue
  if not _evict_variant(variant): return false
 for theme_id: String in _theme_lru.duplicate():
  if themes.size() <= MAX_THEMES - reserve_theme: break
  if pinned_themes.has(theme_id): continue
  for variant: String in _lru.duplicate():
   if variant.begins_with(theme_id + ":"):
    if not _evict_variant(variant): return false
  if _theme_bakes.has(theme_id):
   var baked: Resource = _theme_bakes[theme_id]
   if not retirement.enqueue(baked, baked.retirement_dependencies): return false
   _theme_bakes.erase(theme_id)
  elif not retirement.enqueue_unbaked([backgrounds.get(theme_id), environments.get(theme_id), theme_materials.get(theme_id)]):
   return false
  themes.erase(theme_id)
  backgrounds.erase(theme_id)
  environments.erase(theme_id)
  lights.erase(theme_id)
  theme_materials.erase(theme_id)
  theme_attempts.erase(theme_id)
  _primed_themes.erase(theme_id)
  _warmed_features.erase(theme_id + ":background")
  _warmed_features.erase(theme_id + ":foreground")
  _theme_lru.erase(theme_id)
 # Physics templates are independent of skins and have their own bounded cache.
 for id: int in runtimes.keys():
  if runtimes.size() <= MAX_VARIANTS: break
  if pinned_ids.has(id): continue
  # At most one detached physics tree retires at a time. Free leaves before
  # parents so a single call cannot recursively destroy the whole Act.
  if not _retiring_physics.is_empty(): return false
  _retiring_runtime = runtimes[id]
  _retiring_physics.append(_retiring_runtime.root)
  runtimes.erase(id)
  shapes.erase(id)
 _record_cpu("cache.release", trim_started)
 return visuals.size() <= MAX_VARIANTS - reserve_variant and themes.size() <= MAX_THEMES - reserve_theme

func _step_physics_retirement(max_steps := 64, budget_usec := 500) -> int:
 var steps := 0
 var deadline := Time.get_ticks_usec() + budget_usec
 while not _retiring_physics.is_empty() and steps < max_steps and Time.get_ticks_usec() < deadline:
  var node: Node = _retiring_physics.back()
  if node.get_child_count() > 0:
   _retiring_physics.append(node.get_child(0))
  else:
   _retiring_physics.pop_back()
   node.free()
  steps += 1
 if _retiring_physics.is_empty(): _retiring_runtime = {}
 return steps

func _evict_variant(variant: String) -> bool:
 # Prepared nodes belong to the imminent request and must be consumed first.
 if _prepared_visuals.has(variant): return false
 if _act_bakes.has(variant):
  var baked: Resource = _act_bakes[variant]
  if not retirement.enqueue(baked, baked.retirement_dependencies): return false
  _act_bakes.erase(variant)
 elif not retirement.enqueue_unbaked(visuals[variant]):
  return false
 visuals.erase(variant)
 _lru.erase(variant)
 return true

static func key(theme: String, id: int) -> String:
 return "%s:%d" % [theme, id]

func _exit_tree() -> void:
 if not _retiring_physics.is_empty(): _retiring_physics[0].free()
 _retiring_physics.clear()
 _retiring_runtime = {}
 for worker: Thread in _fingerprint_jobs.values(): worker.wait_to_finish()
 for path: String in _primed_paths: ResourceLoader.load_threaded_get(path)
 for nodes: Array in _prepared_visuals.values():
  for node: Node in nodes:
   if is_instance_valid(node) and node.get_parent() == null: node.free()
 for runtime: Dictionary in runtimes.values():
  if is_instance_valid(runtime.root): runtime.root.free()
