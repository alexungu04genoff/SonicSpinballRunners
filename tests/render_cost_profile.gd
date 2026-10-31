extends SceneTree
## Stationary rendering probe. Diagnostic ablations never change saved settings.
const Run = preload("res://scripts/prototype/zone_run.gd")
const HardwareBatch = preload("res://scripts/pinball_mesh_batch.gd")
const Report = preload("res://tests/render_profile_support.gd")
var game: Node
var theme := "green_hill"
var overview := false
var mode := "prototype"
var output := "res://test-results/render-cost.json"
var ablations := false
var scale_trial := false
var shadow_audit := false
var shadow_distance := -1.0
var samples := 600
var geometry: Array[Dictionary] = []
var views: Array[Viewport] = []
var mesh_triangles := {}

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--profile-mode="): mode = arg.trim_prefix("--profile-mode=")
  if arg.begins_with("--profile-theme="): theme = arg.trim_prefix("--profile-theme=")
  if arg == "--profile-overview": overview = true
  if arg.begins_with("--profile-output="): output = arg.trim_prefix("--profile-output=")
  if arg.begins_with("--profile-samples="): samples = maxi(120, int(arg.trim_prefix("--profile-samples=")))
  if arg == "--profile-ablations": ablations = true
  if arg == "--profile-scale-only": scale_trial = true
  if arg == "--profile-shadow-audit": shadow_audit = true
  if arg.begins_with("--profile-shadow-distance="): shadow_distance = float(arg.trim_prefix("--profile-shadow-distance="))
  if arg == "--profile-unbatched": HardwareBatch.enabled = false
  if arg == "--profile-original-shadows": HardwareBatch.shadow_batch_enabled = false
 if not HardwareBatch.enabled and mode != "act":
  push_error("Unbatched A/B is available only for freshly constructed standalone Acts.")
  quit(1)
  return
 if DisplayServer.get_name() == "headless":
  push_error("Rendering measurements require a graphical renderer.")
  quit(1)
  return
 Engine.max_fps = 0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 seed(18)
 var start := Time.get_ticks_msec()
 if mode == "act":
  game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
  game.authored_act_path = "res://data/acts/Authored/RampMania.tres"
 elif mode == "endless":
  game = load("res://scripts/endless/endless_game.gd").new()
 else:
  game = Run.new()
  game.practice_mode = true
  var config := Run.RunPlan.Configuration.new([
   "res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/Reverse C Spring.tres", "res://data/acts/Authored/Secret Entry.tres"])
  config.zone_count = 1
  config.selected_theme_ids = [theme]
  game.run_configuration = config
 var startup_frames: Array = []
 var previous := Time.get_ticks_usec()
 root.add_child(game)
 # Native windows can receive desktop keystrokes while a probe is running.
 # Keep the served-ball workload stationary without stopping simulation.
 root.gui_disable_input = true
 Report.disable_native_input(game)
 game.controls.input_blocked = true
 if mode != "act":
  while not game.started and game.library.error.is_empty() and Time.get_ticks_msec() - start < 120000:
   await process_frame
   var now := Time.get_ticks_usec()
   startup_frames.append((now - previous) / 1000.0)
   previous = now
  if not game.started:
   push_error("Profile startup failed: " + game.library.error)
   quit(1)
   return
 var startup_ms := Time.get_ticks_msec() - start
 var ready_pipelines := Report.pipelines()
 var lookahead_frames: Array = []
 previous = Time.get_ticks_usec()
 var settled := 0
 while settled < 180 and Time.get_ticks_msec() - start < 180000:
  await process_frame
  var now := Time.get_ticks_usec()
  lookahead_frames.append((now - previous) / 1000.0)
  previous = now
  if mode == "act" or (not game.library.busy and game.building == null): settled += 1
  else: settled = 0
 if settled < 180:
  push_error("Preparation did not settle before the steady-state sample.")
  quit(1)
  return
 var settled_at_ms := Time.get_ticks_msec() - start
 if shadow_distance > 0.0: game.presentation._key_light.directional_shadow_max_distance = shadow_distance
 _inspect(root)
 var inventory := {}
 for item: Dictionary in geometry:
  if not inventory.has(item.category): inventory[item.category] = {"nodes": 0, "triangles": 0, "casters": 0}
  inventory[item.category].nodes += 1
  inventory[item.category].triangles += item.triangles
  inventory[item.category].casters += int(item.shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 var phases: Array[Dictionary] = []
 for index in 3:
  phases.append(await _sample("baseline-%d" % (index + 1), index == 0))
 if shadow_audit:
  # Category ablations measure stable submission counts, not timing tails.
  var baseline_samples := samples
  samples = mini(samples, 120)
  for category: String in inventory:
   if inventory[category].casters == 0: continue
   for item: Dictionary in geometry:
    if item.category == category: item.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   phases.append(await _sample("shadowless-" + category, true))
   for item: Dictionary in geometry:
    if item.category == category: item.node.cast_shadow = item.shadow
  var light: DirectionalLight3D = game.presentation._key_light
  var distance := light.directional_shadow_max_distance
  var splits := light.directional_shadow_mode
  for trial: float in [20.0, 12.0]:
   light.directional_shadow_max_distance = trial
   phases.append(await _sample("shadow-distance-%d" % trial, true))
  light.directional_shadow_max_distance = distance
  light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
  phases.append(await _sample("shadow-two-splits", true))
  light.directional_shadow_mode = splits
  if mode != "act":
   var visibility: Array[Dictionary] = []
   for act: RefCounted in game.resident:
    if act == game.active: continue
    visibility.append({"node": act.visual, "visible": act.visual.visible})
    act.visual.visible = false
   phases.append(await _sample("active-act-only", true))
   for state: Dictionary in visibility: state.node.visible = state.visible
  samples = baseline_samples
  phases.append(await _sample("baseline-return", true))
 if ablations:
  for category: String in ["rings", "mechanics", "borders", "terrain", "decor", "scenery", "other"]:
   _hide_category(category, true)
   phases.append(await _sample("without-" + category))
   _hide_category(category, false)
  var old_size := int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096))
  var old_depth := bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true))
  for shadow_size in [4096, 2048]:
   RenderingServer.directional_shadow_atlas_set_size(shadow_size, old_depth)
   phases.append(await _sample("shadow-%d" % shadow_size, true))
  RenderingServer.directional_shadow_atlas_set_size(old_size, old_depth)
  var light: DirectionalLight3D = game.presentation._key_light
  var shadows := light.shadow_enabled
  light.shadow_enabled = false
  phases.append(await _sample("without-shadows", true))
  light.shadow_enabled = shadows
  game.retro_filter.effect_layer.visible = false
  phases.append(await _sample("without-postpasses"))
  game.retro_filter.effect_layer.visible = true
 if ablations or scale_trial:
  var divisor: float = game.retro_filter._resolution_divisor
  var camera_state := _camera_state()
  game.retro_filter._resolution_divisor = divisor / 0.75
  game.retro_filter._refresh_output()
  await process_frame
  await process_frame
  _restore_camera(camera_state)
  phases.append(await _sample("render-scale-75-percent", true))
  game.retro_filter._resolution_divisor = divisor
  game.retro_filter._refresh_output()
  await process_frame
  await process_frame
  _restore_camera(camera_state)
  phases.append(await _sample("baseline-return"))
 var report := {"mode": mode, "seed": 18 if mode == "act" else game.run_seed, "samples_per_phase": samples,
  "startup_ms": startup_ms, "settled_at_ms": settled_at_ms,
  "scene_start_uptime_ms": start, "startup_frames": Report.timing(startup_frames),
  "lookahead_frames": Report.timing(lookahead_frames), "ready_pipelines": ready_pipelines,
  "window_size": [root.size.x, root.size.y], "world_size": [game.view.size.x, game.view.size.y],
  "physics_ticks": Engine.physics_ticks_per_second, "vsync": DisplayServer.window_get_vsync_mode(),
  "engine": Engine.get_version_info().string, "device": RenderingServer.get_video_adapter_name(),
  "node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
  "inventory": inventory, "phases": phases,
  "theme": game.theme_id if mode == "act" else game.active.plan.theme,
  "hardware_batching": HardwareBatch.enabled if mode == "act" else "baked",
  "shadow_batching": HardwareBatch.shadow_batch_enabled if mode == "act" else "baked",
  "course": game.course_snapshot() if mode == "prototype" else [],
  "note": "Served ball; no input. Preparation settled before sampling. VSync disabled; 120 Hz physics unchanged. Inventory includes hidden/offscreen stored geometry; rendered counters are in phases. Ablation savings overlap and are not additive."}
 report.merge(Report.metadata(), true)
 report["pipelines"] = Report.pipelines()
 if overview:
  game.presentation.set_camera_follow(false)
  for frame in 120: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.get_basename() + "-overview.png")
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file := FileAccess.open(output, FileAccess.WRITE)
 file.store_string(JSON.stringify(report, " "))
 file.close()
 if mode != "act": await game.prepare_to_close()
 game.free()
 quit(0)

func _inspect(node: Node) -> void:
 if node is Viewport:
  views.append(node)
  RenderingServer.viewport_set_measure_render_time(node.get_viewport_rid(), true)
 if node is GeometryInstance3D:
  var mesh: Mesh
  var instances := 1
  if node is MeshInstance3D: mesh = node.mesh
  elif node is MultiMeshInstance3D and node.multimesh != null:
   mesh = node.multimesh.mesh
   instances = node.multimesh.instance_count
  var triangles := 0
  if mesh != null:
   var mesh_id := mesh.get_instance_id()
   if not mesh_triangles.has(mesh_id): mesh_triangles[mesh_id] = mesh.get_faces().size() / 3
   triangles = mesh_triangles[mesh_id] * instances
  geometry.append({"node": node, "category": _category(node), "layers": node.layers, "shadow": node.cast_shadow, "triangles": triangles})
 for child: Node in node.get_children(): _inspect(child)

func _category(node: Node) -> String:
 if node is MeshInstance3D and game.presentation.ring_visuals.has(node): return "rings"
 if mode != "act":
  if game.library.is_ancestor_of(node): return "preparation"
  for background: Dictionary in game.backgrounds.values():
   if background.layer.is_ancestor_of(node): return "scenery"
 var ancestor := node
 while ancestor != null and ancestor != game:
  if str(ancestor.name) == "AuthoredDecor": return "decor"
  ancestor = ancestor.get_parent()
 ancestor = node
 while ancestor != null and ancestor != game:
  var label := str(ancestor.name)
  if "Border" in label: return "borders"
  if label == "AuthoredDecor": return "decor"
  if "Scenery" in label: return "scenery"
  if shadow_audit:
   if label.begins_with("BuzzBomber_"): return "enemies"
   if label.begins_with("Spring_"): return "springs"
   if label.begins_with("SwitchTarget_") or label.begins_with("WallSwitch_"): return "switches"
   if label.begins_with("ElevatedRail_"): return "rails"
   if ancestor == game.presentation.ball_visual or ancestor == game.character: return "ball"
   if ancestor is Node3D:
    if game.presentation.flipper_visuals.has(ancestor) or game.presentation.flipper_retracted_visuals.has(ancestor): return "flippers"
    if game.presentation.bumper_visuals.values().has(ancestor): return "bumpers"
  if ancestor.get_script() == preload("res://scripts/authored_act/mechanics_presentation.gd"): return "mechanics"
  if ancestor is Node3D and (game.presentation.flipper_visuals.has(ancestor) or game.presentation.flipper_retracted_visuals.has(ancestor) or game.presentation.bumper_visuals.values().has(ancestor)): return "mechanics"
  if "Terrain" in label or "Floor" in label: return "terrain"
  ancestor = ancestor.get_parent()
 return "other"

func _hide_category(category: String, hide: bool) -> void:
 for item: Dictionary in geometry:
  if item.category != category: continue
  item.node.layers = 0 if hide else item.layers
  item.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if hide else item.shadow

func _sample(label: String, capture := false) -> Dictionary:
 for frame in 120: await process_frame
 var pipeline_start := Report.pipelines()
 var rows: Array[Dictionary] = []
 var previous := Time.get_ticks_usec()
 for frame in samples:
  await process_frame
  var now := Time.get_ticks_usec()
  var row := {"frame_ms": (now - previous) / 1000.0,
   "draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
   "objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
   "primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
   "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
   "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
   "color_draws": 0, "shadow_draws": 0, "render_cpu_ms": 0.0, "render_gpu_ms": 0.0}
  for view: Viewport in views:
   if view is SubViewport and view.render_target_update_mode == SubViewport.UPDATE_DISABLED: continue
   var rid := view.get_viewport_rid()
   row.color_draws += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
   row.shadow_draws += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
   row.render_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(rid)
   row.render_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(rid)
  rows.append(row)
  previous = now
 var result := {"phase": label, "sample_count": samples, "world_size": [game.view.size.x, game.view.size.y],
  "camera_transform": var_to_str(game.presentation.camera.transform), "camera_far": game.presentation.camera.far,
  "shadow_distance": game.presentation._key_light.directional_shadow_max_distance,
  "resident_acts": 1 if mode == "act" else game.resident.size()}
 for key: String in rows[0]:
  var values := rows.map(func(row): return row[key])
  values.sort()
  result[key + "_median"] = values[values.size() / 2]
  if key == "frame_ms":
   result.frame_p95_ms = values[int(values.size() * 0.95)]
   result.frame_p99_ms = values[int(values.size() * 0.99)]
   result.frame_max_ms = values[-1]
 print("RENDER_COST | ", JSON.stringify(result))
 result["timing"] = Report.timing(rows.map(func(row): return row.frame_ms))
 result["pipelines_start"] = pipeline_start
 result["pipelines_end"] = Report.pipelines()
 if capture:
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute(output.get_base_dir())
  root.get_texture().get_image().save_png(output.get_basename() + "-" + label + ".png")
 return result

func _camera_state() -> Dictionary:
 var p: Node = game.presentation
 return {"transform": p.camera.transform, "far": p.camera.far, "focus": p.camera_focus,
  "target": p.camera_target, "offset": p._camera_offset}

func _restore_camera(state: Dictionary) -> void:
 # Resizing normally reconfigures the camera against the growing streamed
 # bounds. Keep the same pose and far plane when isolating pixel resolution.
 var p: Node = game.presentation
 p._camera_viewport_size = Vector2(game.view.size)
 p.camera.transform = state.transform
 p.camera.far = state.far
 p.camera_focus = state.focus
 p.camera_target = state.target
 p._camera_offset = state.offset
