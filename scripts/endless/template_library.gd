extends Node
## Bounded, demand-driven preparation. The library never visits the Act × theme
## product. Only the rolling lookahead requests variants; old entries are evicted.
signal progress(message: String)
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Plan = preload("res://scripts/endless/endless_plan.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const Presenter = preload("res://scripts/endless/template_presenter.gd")
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
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
var paths: Array = []
var bake_hits := 0
var last_computed_jobs := 0
var last_reused_jobs := 0
var requested_count := 0
var cache_hits := 0
var max_prepare_slice_ms := 0.0
var _lru: Array[String] = []
var _theme_lru: Array[String] = []
var _game: Node
var _view: SubViewport
var _worker: Thread

func prepare(game: Node, act_paths: Array = Plan.PATHS, validate_pool := true) -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 _game = game
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
 progress.emit("Preparing %s · %s…" % [Registry.NAMES[Registry.IDS.find(theme_id)], str(paths[id]).get_file().get_basename()])
 await get_tree().process_frame
 var bake_path := Bake.path_for(paths[id], theme_id)
 var saved: Resource
 if not bake_only and ResourceLoader.exists(bake_path):
  var result := ResourceLoader.load_threaded_request(bake_path, "", false, ResourceLoader.CACHE_MODE_IGNORE)
  if result == OK:
   while ResourceLoader.load_threaded_get_status(bake_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
    await get_tree().process_frame
   if ResourceLoader.load_threaded_get_status(bake_path) == ResourceLoader.THREAD_LOAD_LOADED:
    var candidate: Resource = ResourceLoader.load_threaded_get(bake_path)
    if candidate is Bake and candidate.matches(documents[id], theme_id):
     saved = candidate
     bake_hits += 1
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
 if not themes.has(theme_id):
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
 if not bake_only and not backgrounds.has(theme_id):
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
 elif not bake_only:
  p._world_environment.environment = environments[theme_id]
 # Render the actual new meshes in a private viewport. A hidden scene does not
 # compile Compatibility shaders. Warm a small number of renderables per frame.
 if bake_only:
  var baked := Bake.new()
  baked.source_fingerprint = documents[id].fingerprint()
  baked.pipeline_fingerprint = Bake.pipeline_hash(theme_id)
  baked.theme_id = theme_id
  baked.geometry = Bake.without_materials(p.baked_geometry)
  baked.collisions = shapes[id]
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bake_path.get_base_dir()))
  var result := ResourceSaver.save(baked, bake_path, ResourceSaver.FLAG_COMPRESS)
  if result != OK: error = "Could not save geometry bake: " + error_string(result)
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
 busy = false
 print("ENDLESS_PREPARED | ", key(theme_id, id), " | cached=", visuals.size(), " | baked jobs=", last_reused_jobs, " | computed jobs=", last_computed_jobs)

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

func _warm(p: Node3D) -> void:
 p.set_camera_follow(false)
 p.reset_camera()
 var renderables: Array[Node] = p.find_children("*", "GeometryInstance3D", true, false)
 for node: GeometryInstance3D in renderables: node.hide()
 _view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 # Render the sky on its own before introducing geometry/shader permutations.
 await _draw_frames()
 var warmed := {}
 var batch := 0
 for node: GeometryInstance3D in renderables:
  if p.physics_overlay.is_ancestor_of(node): continue
  node.show()
  # Keep every material inside the frustum at least once, including off-camera
  # props. Use a generous AABB without altering any visible gameplay instance.
  node.extra_cull_margin = 16384.0
  var signatures := _shader_signatures(node)
  var cold := false
  for signature: int in signatures:
   if not warmed.has(signature):
    warmed[signature] = true
    cold = true
  batch += 1
  if cold or batch % 16 == 0: await _draw_frames(1)
 await _draw_frames()
 # Warm the foreground lighting permutation too; the live gameplay viewport
 # deliberately has no sky while the separate backdrop viewports own their skies.
 var foreground: Environment = p._world_environment.environment.duplicate()
 foreground.background_mode = Environment.BG_COLOR
 foreground.sky = null
 foreground.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
 p._world_environment.environment = foreground
 await _draw_frames()

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
  elif material is BaseMaterial3D: result.append(material.get_instance_id())
 return result

func _draw_frames(count := 2) -> void:
 for i in count:
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
