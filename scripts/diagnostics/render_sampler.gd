extends RefCounted
## Frame distributions are kept in memory; rich counters are sampled at 4 Hz.
## No scene traversal in the sampling path. Godot CPU/GPU counters are not additive wall time.
const Audit = preload("res://scripts/diagnostics/render_audit.gd")
const Report = preload("res://tests/render_profile_support.gd")
var game: Node
var phase := "startup"
var samples: Array[Dictionary] = []
var distributions := {}
var previous := 0
var next_sample := 0
var started := Time.get_ticks_usec()
var verbose := false
var measured := {}
var inventory_counts := {}
var owner_counts := {}
var checkpoint_directory := ""
var next_checkpoint := 0

func begin(owner_game: Node) -> void:
 game = owner_game
 previous = Time.get_ticks_usec()

func tick() -> void:
 var now := Time.get_ticks_usec()
 var frame_ms := (now - previous) / 1000.0
 previous = now
 var work := work_phase()
 var group := phase + "/" + work
 if not distributions.has(group): distributions[group] = []
 distributions[group].append(frame_ms)
 if not verbose and now < next_sample: return
 next_sample = now + 250000
 if not is_instance_valid(game) or not is_instance_valid(game.library): return
 var views: Array[Dictionary] = []
 var active_backgrounds := 0
 var active_3d := 0
 for entry: Dictionary in Audit.viewports(game):
  var view: Viewport = entry.node
  if RenderingServer.get_current_rendering_method() != "gl_compatibility" and not measured.has(view.get_instance_id()):
   RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
   measured[view.get_instance_id()] = true
  var state := Audit.viewport_state(view, entry.role, true)
  views.append(state)
  if state.active and not state.disable_3d and state.has_camera_3d: active_3d += 1
  if state.active and entry.role.begins_with("backdrop"): active_backgrounds += 1
 var acts: Array[Dictionary] = []
 for act: RefCounted in game.resident:
  acts.append({"sequence": act.plan.sequence, "theme": act.plan.theme, "act": game.library.paths[act.plan.id], "zone": act.plan.zone,
   "visible": act.visual.is_visible_in_tree(), "contribution_reason": act.contribution.reason, "supported": act.contribution.supported})
 var weights := {}
 for zone: int in game.backgrounds: weights[str(zone)] = game.backgrounds[zone].layer.modulate.a
 var casting := 0
 var shadow_only := 0
 var current_owners := {}
 for act: RefCounted in game.resident:
  var identity: int = act.visual.get_instance_id()
  current_owners[identity] = true
  if not owner_counts.has(identity):
   var counts := {"surfaces": 0, "shadow_only": 0}
   for node: Node in act.nodes:
    var mesh := Audit.mesh_of(node)
    if mesh == null: continue
    if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: counts.surfaces += mesh.get_surface_count()
    if node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: counts.shadow_only += 1
   owner_counts[identity] = counts
  casting += owner_counts[identity].surfaces
  shadow_only += owner_counts[identity].shadow_only
 for identity: int in owner_counts.keys():
  if not current_owners.has(identity): owner_counts.erase(identity)
 samples.append({"time_ms": (now - started) / 1000.0, "phase": phase, "work": work, "frame_ms": frame_ms,
  "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
  "render_setup_cpu_ms": RenderingServer.get_frame_setup_time_cpu(), "viewports": views, "acts": acts,
  "active_3d_viewports": active_3d, "active_backgrounds": active_backgrounds, "resident_acts": acts.size(),
  "foreground_contributing": acts.filter(func(act): return act.visible).size(), "background_weights": weights, "blend": game.background_blend,
  "waiting": game.loading_boundary, "stage": game.library.profile_stage, "building": game.building != null,
  "retiring_resources": game.library.retirement.pending_count(), "retiring_nodes": game.retire_nodes.size(), "build_ms": game.last_build_ms,
  "fallback_builds": game.library.fallback_builds, "pipelines": Report.pipelines(), "inventory_counts": inventory_counts,
  "resident_casting_surfaces": casting, "resident_shadow_only_meshes": shadow_only,
  "shadow_atlas": Audit.Options.shadow_resolution(), "cascades": Audit.Options.shadow_cascades(), "ultra_filter": Audit.Options.ultra_filter_enabled(),
  "retro": game.retro_filter.selected_effects.duplicate(),
  "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
  "video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
 if phase == "startup" and not checkpoint_directory.is_empty() and now >= next_checkpoint:
  next_checkpoint = now + 10000000
  var checkpoint := {"status": "startup_incomplete", "metadata": Report.metadata(), "last_samples": samples.slice(maxi(0, samples.size() - 32)),
   "timing_by_phase_and_work": summary(), "stage": game.library.profile_stage, "events": game.library.profile_events}
  FileAccess.open(checkpoint_directory.path_join("startup-checkpoint.json"), FileAccess.WRITE).store_string(JSON.stringify(checkpoint, "  "))
  print("GROUNDING_STARTUP | ", game.library.profile_stage, " | elapsed_ms=", (now - started) / 1000.0)

func work_phase() -> String:
 if not is_instance_valid(game) or not is_instance_valid(game.library): return "startup"
 if game.loading_boundary: return "boundary_wait"
 if game.library.profile_stage.begins_with("graphics"): return "shader_material_warmup"
 if game.library.busy: return "resource_preparation"
 if game.building != null: return "live_act_attachment"
 if not game.retire_nodes.is_empty() or game.library.retirement.pending_count() > 0: return "resource_retirement"
 if not game.started: return "startup"
 for background: Dictionary in game.backgrounds.values():
  if not background.ready: return "background_attachment_warmup"
 if game.background_blend > 0.0 and game.background_blend < 1.0: return "zone_overlap"
 return "settled"

func summary() -> Dictionary:
 var result := {}
 for key: String in distributions: result[key] = Report.timing(distributions[key])
 return result

func counter_summary() -> Dictionary:
 var groups := {}
 for row: Dictionary in samples:
  var key: String = row.phase + "/" + row.work
  if not groups.has(key): groups[key] = {}
  for view: Dictionary in row.viewports:
   var values: Dictionary = groups[key]
   for field: String in ["objects", "primitives", "draws"]:
    for kind: String in ["visible", "shadow", "canvas"]:
     var metric: String = view.role + "." + kind + "." + field
     if not values.has(metric): values[metric] = []
     values[metric].append(view[kind][field])
   for field: String in ["render_cpu_ms", "render_gpu_ms"]:
    if view[field] == null: continue
    var metric: String = view.role + "." + field
    if not values.has(metric): values[metric] = []
    values[metric].append(view[field])
 var result := {}
 for key: String in groups:
  result[key] = {}
  for metric: String in groups[key]:
   var values: Array = groups[key][metric]
   values.sort()
   result[key][metric] = {"count": values.size(), "median": values[values.size() / 2], "maximum": values[-1]}
 return result

func write(output: String, extra: Dictionary = {}, measured_settings: Dictionary = {}) -> void:
 DirAccess.make_dir_recursive_absolute(output)
 var result := {"metadata": Report.metadata(), "settings": Audit.settings(game) if measured_settings.is_empty() else measured_settings, "timing_by_phase_and_work": summary(),
  "sampled_counter_summary": counter_summary(), "samples": samples, "events": game.library.profile_events, "cpu_stage_totals": game.library.profile_cpu,
  "cpu_stage_maxima": game.library.profile_max_cpu_ms, "fallback_builds": game.library.fallback_builds,
  "note": "Frame distributions include every frame; counters are 4 Hz unless --grounding-verbose. TIME_PROCESS is Godot main-loop time, not OS process CPU time. GPU/CPU viewport counters may overlap. Unavailable Compatibility timings are null. Disabled viewport counters are zeroed because the engine can retain stale values."}
 result.merge(extra)
 FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
 var csv := FileAccess.open(output.path_join("samples.csv"), FileAccess.WRITE)
 csv.store_csv_line(PackedStringArray(["time_ms", "phase", "work", "frame_ms", "process_ms", "physics_ms", "resident_acts", "foreground_contributing", "active_backgrounds", "viewport", "visible_draws", "visible_objects", "visible_primitives", "shadow_draws", "shadow_objects", "shadow_primitives", "render_cpu_ms", "render_gpu_ms"]))
 for row: Dictionary in samples:
  for view: Dictionary in row.viewports:
   csv.store_csv_line(PackedStringArray([str(row.time_ms), row.phase, row.work, str(row.frame_ms), str(row.process_ms), str(row.physics_ms), str(row.resident_acts), str(row.foreground_contributing), str(row.active_backgrounds), view.role,
    str(view.visible.draws), str(view.visible.objects), str(view.visible.primitives), str(view.shadow.draws), str(view.shadow.objects), str(view.shadow.primitives), str(view.render_cpu_ms), str(view.render_gpu_ms)]))
