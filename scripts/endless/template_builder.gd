extends "res://scripts/endless/template_library.gd"
## Authoring-only construction and disk output. Normal Endless uses the base
## loader; --no-bakes explicitly selects this builder for diagnostic comparison.
const Presenter = preload("res://scripts/endless/template_presenter.gd")
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const BakeAssets = preload("res://scripts/endless/bake_assets.gd")
const WarmManifest = preload("res://scripts/endless/warm_manifest.gd")
var bake_only := true
var _assets := BakeAssets.new()
var _asset_theme := ""
var _worker: Thread

func _init() -> void:
 use_disk_bakes = false

func _load_bake(path: String) -> Resource:
 if bake_only: return ResourceLoader.load(path) if ResourceLoader.exists(path) else null
 return await super._load_bake(path)

func _build(theme_id: String, id: int) -> void:
 var started_at := Time.get_ticks_usec()
 last_warm_frames = 0
 progress.emit(("Baking %s · %s…" if bake_only else "Building diagnostic preview %s · %s…") % [Registry.NAMES[Registry.IDS.find(theme_id)], str(paths[id]).get_file().get_basename()])
 await get_tree().process_frame
 var fingerprint := await _fingerprint(theme_id)
 var bake_path := Bake.path_for(paths[id], theme_id)
 if not await _prepare_runtime(id):
  busy = false
  return
 if not bake_only:
  fallback_builds += 1
  print("ENDLESS_BAKE_FALLBACK | ", key(theme_id, id), " | ", bake_status, " | Run Bake Endless.cmd after authoring changes")
 if not themes.has(theme_id) or themes[theme_id] is Dictionary:
  if bake_only:
   # Offline work can block here. The headless renderer's texture RID storage
   # must not race threaded resource loads while constructing image textures.
   themes[theme_id] = Registry.create(theme_id)
  else:
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
 var runtime: Dictionary = runtimes[id].duplicate()
 runtime.ring_records = RingField.document_records(documents[id], "template")
 await p.prepare_act(runtime, Rect2(Vector2.ZERO, documents[id].red_gutter_bounds().end), documents[id].cell_size)
 p.stage = "environment"
 theme.configure_environment(p)
 await p.stream_checkpoint()
 p.stage = "capture"
 var recipe := Recipe.new()
 var excluded := [p.camera, p._world_environment, p._key_light, p.ball_visual, p.physics_overlay,
  p.construction_grid_overlay, p.scenery_root]
 for child: Node in p.get_children():
  if child not in excluded: await _capture(recipe, child, p)
 # Nearby framing belongs to the authored silhouette, not the synthetic Zone
 # rectangle. Keep it in the Act recipe but render it in the existing backdrop.
 p.stage = "local scenery"
 p.table_bounds = documents[id].terrain_bounds()
 await theme.build_edges(p)
 await p._finish_borders()
 for visual: GeometryInstance3D in p.scenery_root.find_children("*", "GeometryInstance3D", true, false):
  visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var local_start := recipe.records.size()
 for child: Node in p.scenery_root.get_children(): await _capture(recipe, child, p)
 for index in range(local_start, recipe.records.size()): recipe.records[index]["background"] = true
 recipe.finish(p)
 # Detach only the temporary authoring tree; its captured resources stay shared.
 var local_scenery: Node3D = p.scenery_root
 p.remove_child(local_scenery)
 await _dispose(local_scenery)
 p.scenery_root = Node3D.new()
 p.add_child(p.scenery_root)
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
 if not recipe.error.is_empty() or not backgrounds[theme_id].error.is_empty():
  error = recipe.error if not recipe.error.is_empty() else backgrounds[theme_id].error
  await _dispose(p)
  rings.free()
  busy = false
  return
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
  # Full recipes already contain their meshes. The old raw-geometry dictionary
  # was never used by disk-only play and duplicated data in every sidecar.
  baked.geometry_job_count = p.computed_jobs
  baked.collisions = shapes[id]
  baked.physics_validated = true
  baked.visual_recipe = recipe
  _assets.share(recipe)
  _assets.share(backgrounds[theme_id])
  if not _assets.error.is_empty():
   error = _assets.error
   await _dispose(p)
   rings.free()
   busy = false
   return
  var batcher = preload("res://scripts/endless/static_batches.gd").new()
  var act_batches: Dictionary = batcher.optimize(recipe)
  var background_batches: Dictionary = batcher.optimize(backgrounds[theme_id])
  var manifest := WarmManifest.new()
  manifest.prepare(recipe)
  manifest.prepare(backgrounds[theme_id])
  if not recipe.error.is_empty() or not backgrounds[theme_id].error.is_empty():
   error = recipe.error if not recipe.error.is_empty() else backgrounds[theme_id].error
   await _dispose(p)
   rings.free()
   busy = false
   return
  baked.retirement_dependencies = Retirement.dependencies(baked)
  print("ENDLESS_BATCHED | ", key(theme_id, id), " | Act=", act_batches, " | theme=", background_batches)
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
  for material: Material in _assets.materials.values(): unique_materials[manifest.material_probe_key(material)] = material
  theme_bake.preload_materials.assign(unique_materials.values())
  theme_bake.preload_recipe = manifest.build_probes(theme_bake.preload_materials)
  if not theme_bake.preload_recipe.error.is_empty():
   error = theme_bake.preload_recipe.error
   await _dispose(p)
   rings.free()
   busy = false
   return
  theme_bake.retirement_dependencies = Retirement.dependencies(theme_bake)
  DirAccess.make_dir_recursive_absolute(Bake.theme_path(theme_id).get_base_dir())
  result = ResourceSaver.save(theme_bake, Bake.theme_path(theme_id), ResourceSaver.FLAG_COMPRESS)
  if result != OK: error = "Could not save shared theme bake: " + error_string(result)
  _assets.visited.clear()
  print("ACT_BAKED | ", bake_path, " | jobs=", p.computed_jobs)
 else:
  p.set_camera_follow(false)
  p.reset_camera()
  await _warm(p, p._world_environment, true, {}, {}, p.physics_overlay)
 last_computed_jobs = p.computed_jobs
 last_reused_jobs = 0
 max_prepare_slice_ms = maxf(max_prepare_slice_ms, p.max_slice_ms)
 await _dispose(p)
 rings.free()
 _view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 visuals[key(theme_id, id)] = recipe
 _lru.append(key(theme_id, id))
 _finish_request(theme_id, id, started_at, "offline" if bake_only else "generated")

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

func _exit_tree() -> void:
 if _worker != null: _worker.wait_to_finish()
 super._exit_tree()
