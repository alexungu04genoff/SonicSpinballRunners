extends Node
## Bounded, demand-driven preparation. During play only the rolling lookahead
## requests variants; the offline authoring tool explicitly requests its bake set.
signal progress(message: String)
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Plan = preload("res://scripts/endless/endless_plan.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const Presenter = preload("res://scripts/endless/template_presenter.gd")
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
const BakeAssets = preload("res://scripts/endless/bake_assets.gd")
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
var bake_only := false
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
var _fingerprints := {}
var _assets := BakeAssets.new()
var _asset_theme := ""
var _lru: Array[String] = []
var _theme_lru: Array[String] = []
var _game: Node
var _view: SubViewport
var _worker: Thread

func prepare(game: Node, act_paths: Array = Plan.PATHS, validate_pool := true) -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 _game = game
 use_disk_bakes = "--no-bakes" not in OS.get_cmdline_user_args()
 paths = act_paths.duplicate()
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
 if busy or not error.is_empty() or bake_only or not use_disk_bakes: return false
 if backgrounds.has(theme_id) or theme_attempts.has(theme_id): return false
 theme_attempts[theme_id] = true
 preparing_theme = theme_id
 busy = true
 _prefetch_theme.call_deferred(theme_id)
 return true

func _fingerprint(theme_id: String) -> String:
 if not _fingerprints.has(theme_id):
  _worker = Thread.new()
  _worker.start(Bake.pipeline_hash.bind(theme_id), Thread.PRIORITY_LOW)
  while _worker.is_alive(): await get_tree().process_frame
  _fingerprints[theme_id] = _worker.wait_to_finish()
  _worker = null
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

func _load_theme(theme_id: String, fingerprint: String) -> bool:
 if backgrounds.has(theme_id): return true
 var background: Resource = await _load_bake(Bake.theme_path(theme_id))
 if not background is Bake or background.kind != "theme" or not background.matches_pipeline(theme_id, fingerprint) or background.visual_recipe == null: return false
 environments[theme_id] = background.environment
 lights[theme_id] = background.light
 backgrounds[theme_id] = background.visual_recipe
 theme_materials[theme_id] = background.preload_materials
 themes[theme_id] = {"display_name": Registry.NAMES[Registry.IDS.find(theme_id)]}
 _theme_lru.erase(theme_id)
 _theme_lru.append(theme_id)
 # Tiny probes upload foreground textures and warm material/shadow features.
 # They contain no terrain, props, Act layout or collision data.
 var probes := Recipe.new()
 var box := BoxMesh.new()
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
 var seen := {}
 var deadline := Time.get_ticks_usec() + 1000
 for material: Material in background.preload_materials:
  if Time.get_ticks_usec() >= deadline:
   await get_tree().process_frame
   deadline = Time.get_ticks_usec() + 1000
  var signature := _material_probe_key(material)
  if seen.has(signature): continue
  seen[signature] = true
  var probe := MeshInstance3D.new()
  probe.mesh = mesh
  probe.material_override = material
  probes.capture(probe)
  probe.free()
 if not probes.records.is_empty(): await _warm_recipe(probes, theme_id)
 await _warm_recipe(background.visual_recipe, theme_id)
 theme_bake_hits += 1
 return true

static func _material_probe_key(material: Material) -> String:
 # Uniform colors/numbers do not need another probe. Keep texture bindings,
 # shader code and feature flags distinct, including any next material pass.
 var features: Array = [material.get_class()]
 for property: Dictionary in material.get_property_list():
  if int(property.usage) & PROPERTY_USAGE_STORAGE == 0: continue
  var value: Variant = material.get(property.name)
  if value is Shader:
   features.append([property.name, value.code])
  elif value is Texture:
   features.append([property.name, value.resource_path if not value.resource_path.is_empty() else str(value.get_instance_id())])
  elif value is Material:
   features.append([property.name, _material_probe_key(value)])
  elif value is bool or value is int:
   features.append([property.name, value])
 return var_to_str(features).sha256_text()

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
 progress.emit(("Baking %s · %s…" if bake_only else "Loading %s · %s and warming graphics…") % [Registry.NAMES[Registry.IDS.find(theme_id)], str(paths[id]).get_file().get_basename()])
 await get_tree().process_frame
 var fingerprint := await _fingerprint(theme_id)
 var bake_path := Bake.path_for(paths[id], theme_id)
 var saved: Resource
 if not bake_only and use_disk_bakes:
  var candidate: Resource = await _load_bake(bake_path)
  if candidate is Bake and candidate.matches(documents[id], theme_id, fingerprint):
   saved = candidate
   bake_hits += 1
  bake_status = "disk" if saved != null else ("missing" if candidate == null else "stale")
  if not backgrounds.has(theme_id):
   if not await _load_theme(theme_id, fingerprint) and saved != null: bake_status = "theme missing or stale"
 elif not use_disk_bakes:
  bake_status = "disabled by --no-bakes"
 if not bake_only and use_disk_bakes and (saved == null or saved.visual_recipe == null or not backgrounds.has(theme_id)):
  error = "The %s bake is %s. Run Bake Endless.cmd, then restart Endless mode." % [key(theme_id, id), bake_status]
  busy = false
  return
 if not runtimes.has(id):
  # Physics is theme-independent and compiled once for a requested Act.
  var runtime := Compiler.compile(documents[id], _game.tuning, _game.controls, _game.ball, saved.collisions if saved != null else [])
  if not runtime.error.is_empty():
   error = runtime.error
   busy = false
   return
  runtimes[id] = runtime
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
 if not bake_only and saved != null and saved.visual_recipe != null and backgrounds.has(theme_id):
  # A full bake skips every procedural mesh, prop, scene capture and theme
  # constructor. Only staged instantiation and local GPU preparation remain.
  if not themes.has(theme_id): themes[theme_id] = {"display_name": Registry.NAMES[Registry.IDS.find(theme_id)]}
  _theme_lru.erase(theme_id)
  _theme_lru.append(theme_id)
  await _warm_recipe(saved.visual_recipe, theme_id)
  visuals[key(theme_id, id)] = saved.visual_recipe
  _lru.append(key(theme_id, id))
  visual_bake_hits += 1
  last_computed_jobs = 0
  last_reused_jobs = saved.geometry.size()
  _finish_request(theme_id, id, started_at, "disk")
  return
 if not bake_only:
  if saved != null and saved.visual_recipe == null: bake_status = "geometry only"
  fallback_builds += 1
  print("ENDLESS_BAKE_FALLBACK | ", key(theme_id, id), " | ", bake_status, " | Run Bake Endless.cmd after authoring changes")
 if not themes.has(theme_id) or themes[theme_id] is Dictionary:
  # Theme constructors create private resources, never live scene nodes. Decode
  # images and create materials without blocking the gameplay scene tree.
  _worker = Thread.new()
  _worker.start(Registry.create.bind(theme_id), Thread.PRIORITY_LOW)
  while _worker.is_alive(): await get_tree().process_frame
  themes[theme_id] = _worker.wait_to_finish()
  _worker = null
 _theme_lru.erase(theme_id)
 _theme_lru.append(theme_id)
 var theme: RefCounted = themes[theme_id]
 var p := Presenter.new()
 p.name = "IncrementalVisualBaker"
 p.ball = _game.ball
 var rings := RingField.new()
 rings.ball = _game.ball
 rings.tuning = _game.tuning
 rings.process_mode = Node.PROCESS_MODE_DISABLED
 rings.ring_radius = documents[id].cell_size * preload("res://scripts/act_dimensions.gd").RING_RADIUS_CELLS
 add_child(rings)
 p.ring_field = rings
 _view.add_child(p)
 p.set_theme_definition(theme)
 if saved != null: p.baked_geometry = saved.geometry
 var runtime: Dictionary = runtimes[id].duplicate()
 runtime.ring_trails = documents[id].ring_trails
 await p.prepare_act(runtime, Rect2(Vector2.ZERO, documents[id].red_gutter_bounds().end), documents[id].cell_size)
 p.stage = "environment"
 theme.configure_environment(p)
 await p.stream_checkpoint()
 p.stage = "capture"
 var recipe := Recipe.new()
 var excluded := [p.camera, p._world_environment, p._key_light, p.ball_visual, p.physics_overlay,
  p.chunk_overlay, p.connector_overlay, p.construction_grid_overlay, p.scenery_root]
 for child: Node in p.get_children():
  if child not in excluded: await _capture(recipe, child, p)
 recipe.finish(p)
 var bumpers := {}
 for i in runtime.objects.size():
  var body: Node = runtime.objects[i].body
  if recipe.bumpers.has(body.get_instance_id()): bumpers[i] = recipe.bumpers[body.get_instance_id()]
 recipe.bumpers = bumpers
 if not backgrounds.has(theme_id):
  p.table_bounds = Rect2(0, 0, 600, 1800)
  p.authored_mode = false
  p._outlines.assign([PackedVector2Array([Vector2.ZERO, Vector2(600, 0), Vector2(600, 1800), Vector2(0, 1800)])])
  p.authored_floor_outline = PackedVector2Array()
  p.stage = "background"
  await theme.build_background(p)
  p.stage = "edges"
  await theme.build_edges(p)
  await p._finish_borders()
  var background := Recipe.new()
  for child: Node in p.scenery_root.get_children(): await _capture(background, child, p)
  background.finish()
  backgrounds[theme_id] = background
  environments[theme_id] = p._world_environment.environment
  lights[theme_id] = {"rotation": p._key_light.rotation, "color": p._key_light.light_color,
   "energy": p._key_light.light_energy, "bias": p._key_light.shadow_normal_bias}
 else:
  p._world_environment.environment = environments[theme_id]
 # Render the actual new meshes in a private viewport. A hidden scene does not
 # compile Compatibility shaders. Warm a small number of renderables per frame.
 if bake_only:
  if _asset_theme != theme_id:
   _asset_theme = theme_id
   _assets.materials.clear()
   # A single-Act bake keeps the other verified Acts' material preload entries.
   var previous: Resource = await _load_bake(Bake.theme_path(theme_id))
   if previous is Bake and previous.matches_pipeline(theme_id, fingerprint):
    for material: Material in previous.preload_materials: _assets.materials[material.get_instance_id()] = material
  var baked := Bake.new()
  baked.source_fingerprint = documents[id].fingerprint()
  baked.pipeline_fingerprint = fingerprint
  baked.theme_id = theme_id
  baked.geometry = Bake.without_materials(p.baked_geometry)
  baked.collisions = shapes[id]
  baked.visual_recipe = recipe
  _assets.share(recipe)
  _assets.share(backgrounds[theme_id])
  if not _assets.error.is_empty(): error = _assets.error
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bake_path.get_base_dir()))
  var result := ResourceSaver.save(baked, bake_path, ResourceSaver.FLAG_COMPRESS)
  if result != OK: error = "Could not save geometry bake: " + error_string(result)
  var theme_bake := Bake.new()
  theme_bake.kind = "theme"
  theme_bake.theme_id = theme_id
  theme_bake.pipeline_fingerprint = fingerprint
  theme_bake.visual_recipe = backgrounds[theme_id]
  theme_bake.environment = environments[theme_id]
  theme_bake.light = lights[theme_id]
  var unique_materials := {}
  for material: Material in _assets.materials.values(): unique_materials[_material_probe_key(material)] = material
  theme_bake.preload_materials.assign(unique_materials.values())
  DirAccess.make_dir_recursive_absolute(Bake.theme_path(theme_id).get_base_dir())
  result = ResourceSaver.save(theme_bake, Bake.theme_path(theme_id), ResourceSaver.FLAG_COMPRESS)
  if result != OK: error = "Could not save shared theme bake: " + error_string(result)
  _assets.visited.clear()
  print("ACT_BAKED | ", bake_path, " | jobs=", p.computed_jobs)
 else:
  await _warm(p)
 last_computed_jobs = p.computed_jobs
 last_reused_jobs = p.reused_jobs
 max_prepare_slice_ms = maxf(max_prepare_slice_ms, p.max_slice_ms)
 await _dispose(p)
 rings.free()
 _view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 visuals[key(theme_id, id)] = recipe
 _lru.append(key(theme_id, id))
 _finish_request(theme_id, id, started_at, "offline" if bake_only else "generated")

func _finish_request(theme_id: String, id: int, started_at: int, source: String) -> void:
 last_prepare_ms = (Time.get_ticks_usec() - started_at) / 1000.0
 busy = false
 print("ENDLESS_PREPARED | ", key(theme_id, id), " | source=", source, " | ms=", last_prepare_ms, " | GPU warm frames=", last_warm_frames, " | cached=", visuals.size(), " | geometry loaded=", last_reused_jobs, " | geometry generated=", last_computed_jobs)

func _load_bake(path: String) -> Resource:
 if not ResourceLoader.exists(path): return null
 if ResourceLoader.load_threaded_request(path, "", true) != OK: return null
 while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS: await get_tree().process_frame
 if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED: return null
 return ResourceLoader.load_threaded_get(path)

func _warm_recipe(recipe: Resource, theme_id: String) -> void:
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
 var deadline := Time.get_ticks_usec() + 1000
 for i in recipe.records.size():
  recipe.instantiate_one(i, nodes, root)
  if Time.get_ticks_usec() >= deadline:
   await get_tree().process_frame
   deadline = Time.get_ticks_usec() + 1000
 root.process_mode = Node.PROCESS_MODE_ALWAYS
 var instantiated_at := Time.get_ticks_usec()
 await _warm(root, environment, false)
 var warmed_at := Time.get_ticks_usec()
 await _dispose(root)
 print("ENDLESS_DISK_WARM | ", theme_id, " | nodes=", nodes.size(), " | instantiate_ms=", (instantiated_at - started_at) / 1000.0, " | graphics_ms=", (warmed_at - instantiated_at) / 1000.0, " | retire_ms=", (Time.get_ticks_usec() - warmed_at) / 1000.0)
 _view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _capture(recipe: RefCounted, root: Node, p: Node) -> void:
 var stack: Array = [[root, -1]]
 while not stack.is_empty():
  var item: Array = stack.pop_back()
  var node: Node = item[0]
  var index: int = recipe.records.size()
  recipe.capture(node, item[1], false)
  var children := node.get_children()
  children.reverse()
  for child: Node in children: stack.append([child, index])
  await p.stream_checkpoint()

func _warm(p: Node3D, world_environment: WorldEnvironment = null, warm_foreground := true) -> void:
 var overlay: Node
 if p is Presenter:
  p.set_camera_follow(false)
  p.reset_camera()
  overlay = p.physics_overlay
  world_environment = p._world_environment
 var renderables: Array[Node] = p.find_children("*", "GeometryInstance3D", true, false)
 for node: GeometryInstance3D in renderables: node.hide()
 _view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 # Render the sky on its own before introducing geometry/shader permutations.
 await _draw_frames()
 await _warm_pass(renderables, overlay)
 if not warm_foreground: return
 # The procedural fallback presenter mixes Act and background geometry. Disk
 # recipes instead warm only the environment in which they will actually draw.
 var foreground: Environment = world_environment.environment.duplicate()
 foreground.background_mode = Environment.BG_COLOR
 foreground.sky = null
 foreground.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 foreground.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
 world_environment.environment = foreground
 await _warm_pass(renderables, overlay)

func _warm_pass(renderables: Array[Node], overlay: Node) -> void:
 var warmed := {}
 var batch: Array[GeometryInstance3D] = []
 var cold_features := 0
 var batch_limit := 8 if _game.get("started") == true else 64
 for node: GeometryInstance3D in renderables:
  if overlay != null and overlay.is_ancestor_of(node): continue
  node.show()
  # Keep every material inside the frustum at least once, including off-camera
  # props. Use a generous AABB without altering any visible gameplay instance.
  node.extra_cull_margin = 16384.0
  var signatures := _shader_signatures(node)
  for signature: int in signatures:
   if not warmed.has(signature):
    warmed[signature] = true
    cold_features += 1
  batch.append(node)
  # Colors and uniform values do not require a different shader. The previous
  # per-material-instance wait spent hundreds of frames on equivalent programs.
  if cold_features >= 1 or batch.size() >= batch_limit:
   await _draw_frames(1)
   for shown: GeometryInstance3D in batch: shown.hide()
   batch.clear()
   cold_features = 0
 if not batch.is_empty():
  await _draw_frames(1)
  for shown: GeometryInstance3D in batch: shown.hide()

func _shader_signatures(node: GeometryInstance3D) -> Array[int]:
 var materials: Array[Material] = []
 if node.material_override != null: materials.append(node.material_override)
 elif node is MeshInstance3D:
  for i in node.mesh.get_surface_count(): materials.append(node.get_active_material(i))
 elif node is MultiMeshInstance3D and node.multimesh != null:
  for i in node.multimesh.mesh.get_surface_count(): materials.append(node.multimesh.mesh.surface_get_material(i))
 var result: Array[int] = []
 for material: Material in materials:
  if material is ShaderMaterial: result.append(material.shader.get_instance_id())
  elif material is BaseMaterial3D:
   var features: Array = [material.get_class()]
   for property: Dictionary in material.get_property_list():
    if int(property.usage) & PROPERTY_USAGE_STORAGE == 0: continue
    var value: Variant = material.get(property.name)
    if value is bool or value is int: features.append([property.name, value])
    elif value is Texture2D: features.append(property.name)
   result.append(hash(features))
 return result

func _draw_frames(count := 2) -> void:
 for i in count:
  last_warm_frames += 1
  await get_tree().process_frame
  if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func _dispose(root: Node) -> void:
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
  nodes.pop_back().free()
  if Time.get_ticks_usec() >= deadline:
   await get_tree().process_frame
   deadline = Time.get_ticks_usec() + 1000

func trim(protected: Array, reserve_variant := 0, reserve_theme := 0) -> void:
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
  visuals.erase(variant)
  _lru.erase(variant)
 for theme_id: String in _theme_lru.duplicate():
  if themes.size() <= MAX_THEMES - reserve_theme: break
  if pinned_themes.has(theme_id): continue
  for variant: String in _lru.duplicate():
   if variant.begins_with(theme_id + ":"):
    visuals.erase(variant)
    _lru.erase(variant)
  themes.erase(theme_id)
  backgrounds.erase(theme_id)
  environments.erase(theme_id)
  lights.erase(theme_id)
  theme_materials.erase(theme_id)
  theme_attempts.erase(theme_id)
  _theme_lru.erase(theme_id)
 # Physics templates are independent of skins and have their own bounded cache.
 for id: int in runtimes.keys():
  if runtimes.size() <= MAX_VARIANTS: break
  if pinned_ids.has(id): continue
  runtimes[id].root.free()
  runtimes.erase(id)
  shapes.erase(id)

static func key(theme: String, id: int) -> String:
 return "%s:%d" % [theme, id]

func _exit_tree() -> void:
 if _worker != null: _worker.wait_to_finish()
 for runtime: Dictionary in runtimes.values():
  if is_instance_valid(runtime.root): runtime.root.free()
