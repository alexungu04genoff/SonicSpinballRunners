extends SceneTree
## Same seeded continuous tour for before/after measurements. No diagnostic jumps.
const Game = preload("res://scripts/endless/endless_game.gd")
const Report = preload("res://tests/render_profile_support.gd")
var game: Node
var rows: Array[Dictionary] = []
var previous := 0
var render_started := 0
var render_wall_ms := 0.0
var measured := {}

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var output := "res://test-results/endless-stream-profile.json"
 var target := 6
 var speed := 100.0
 var unlimited := false
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--profile-output="): output = argument.trim_prefix("--profile-output=")
  if argument.begins_with("--profile-target="): target = int(argument.trim_prefix("--profile-target="))
  if argument.begins_with("--profile-speed="): speed = float(argument.trim_prefix("--profile-speed="))
  if argument == "--profile-unlimited": unlimited = true
 if unlimited and DisplayServer.get_name() != "headless":
  Engine.max_fps = 0
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 game = Game.new()
 var initialize_at := Time.get_ticks_msec()
 root.add_child(game)
 root.gui_disable_input = true
 Report.disable_native_input(game)
 game.controls.input_blocked = true
 var initialize_ms := Time.get_ticks_msec() - initialize_at
 var started_at := Time.get_ticks_msec()
 while not game.started and game.library.error.is_empty() and Time.get_ticks_msec() - started_at < 120000: await process_frame
 if not game.started:
  push_error("Profile startup failed: " + game.library.error)
  quit(1)
  return
 var startup_ms := Time.get_ticks_msec() - started_at
 var startup_cpu: Dictionary = game.library.profile_cpu.duplicate(true)
 var ready_pipelines := Report.pipelines()
 game.library.profile_cpu.clear()
 game.library.profile_max_cpu_ms.clear()
 game.library.profile_resource_wait_ms = 0.0
 var gameplay_started_us := Time.get_ticks_usec()
 RenderingServer.frame_pre_draw.connect(_pre_draw)
 RenderingServer.frame_post_draw.connect(_post_draw)
 game.toggle_tour()
 game.tour_speed = speed
 previous = Time.get_ticks_usec()
 var waiting_ms := 0.0
 while game.active_sequence < target and Time.get_ticks_msec() - started_at < 300000:
  await process_frame
  var now := Time.get_ticks_usec()
  var frame_ms := (now - previous) / 1000.0
  previous = now
  if game.loading_boundary: waiting_ms += frame_ms
  var views: Array[Viewport] = [root, game.view, game._composite_view, game.library._view]
  for background: Dictionary in game.backgrounds.values(): views.append(background.layer.view)
  var cpu := RenderingServer.get_frame_setup_time_cpu()
  var gpu := 0.0
  for view: Viewport in views:
   var id := view.get_instance_id()
   if not measured.has(id):
    RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
    measured[id] = true
   if view is SubViewport and view.render_target_update_mode == SubViewport.UPDATE_DISABLED: continue
   cpu += RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())
   gpu += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
  rows.append({"at_us": now, "frame_ms": frame_ms, "stage": game.library.profile_stage,
   "render_wall_ms": render_wall_ms, "render_cpu_ms": cpu, "render_gpu_ms": gpu,
   "engine_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
   "engine_physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
   "build_ms": game.last_build_ms, "blend": game.background_blend, "sequence": game.active_sequence, "waiting": game.loading_boundary,
   "act": Game.Plan.TITLES[game.active.plan.id], "theme": game.active.plan.theme,
   "resident_acts": game.resident.size(),
   "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
   "objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
   "memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
   "video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
   "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
 var frames: Array = rows.map(func(row: Dictionary): return row.frame_ms)
 frames.sort()
 var draws: Array = rows.map(func(row: Dictionary): return row.draw_calls)
 draws.sort()
 var worst: Array = rows.duplicate()
 worst.sort_custom(func(a: Dictionary, b: Dictionary): return a.frame_ms > b.frame_ms)
 var summary := {"startup_ms": startup_ms, "initialize_ms": initialize_ms, "sequence": game.active_sequence, "tour_speed": speed, "waiting_ms": waiting_ms,
  "gameplay_started_us": gameplay_started_us, "duration_ms": (Time.get_ticks_usec() - gameplay_started_us) / 1000.0,
  "device": RenderingServer.get_video_adapter_name(), "command_line": OS.get_cmdline_args(),
  "viewport_size": [game.view.size.x, game.view.size.y], "pool_size": Game.Plan.PATHS.size(),
  "startup_cpu": startup_cpu, "gameplay_cpu": game.library.profile_cpu,
  "reused_visual_nodes": game.library.reused_visual_nodes, "retirement_peak": game.library.retirement.peak_pending,
  "retirement_completed": game.library.retirement.completed,
  "rebuilds": game.library.fallback_builds, "shaders": game.retro_filter.display_name(),
  "resident_peak": rows.map(func(row): return row.resident_acts).max(),
  "frame_max_ms": frames[-1], "frame_p99_ms": frames[int(frames.size() * 0.99)],
  "frame_median_ms": frames[frames.size() / 2], "frame_p95_ms": frames[int(frames.size() * 0.95)],
  "sample_count": frames.size(), "frames_over_50_ms": frames.filter(func(ms: float): return ms > 50.0).size(),
  "frames_over_100_ms": frames.filter(func(ms: float): return ms > 100.0).size(),
  "draw_calls_median": draws[draws.size() / 2], "draw_calls_p95": draws[int(draws.size() * 0.95)],
  "cpu_max_ms": game.library.profile_max_cpu_ms, "threaded_resource_wall_ms": game.library.profile_resource_wait_ms,
  "worst_frames": worst.slice(0, 8)}
 summary["seed"] = game.run_seed
 summary.merge(Report.metadata(), true)
 summary["ready_pipelines"] = ready_pipelines
 summary["pipelines"] = Report.pipelines()
 for key: String in ["objects", "render_cpu_ms", "render_gpu_ms"]:
  var values: Array = rows.map(func(row): return row[key])
  values.sort()
  summary[key + "_median"] = values[values.size() / 2]
 summary["window_size"] = [root.size.x, root.size.y]
 summary["physics_ticks"] = Engine.physics_ticks_per_second
 summary["vsync"] = DisplayServer.window_get_vsync_mode() if DisplayServer.get_name() != "headless" else -1
 summary["active_frames"] = _frame_summary(rows.filter(func(row: Dictionary): return not row.waiting))
 summary["waiting_frames"] = _frame_summary(rows.filter(func(row: Dictionary): return row.waiting))
 print("ENDLESS_PROFILE | ", JSON.stringify(summary))
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file := FileAccess.open(output, FileAccess.WRITE)
 file.store_string(JSON.stringify({"summary": summary, "frames": rows, "events": game.library.profile_events}))
 file.close()
 RenderingServer.frame_pre_draw.disconnect(_pre_draw)
 RenderingServer.frame_post_draw.disconnect(_post_draw)
 game.set_process(false)
 game.set_physics_process(false)
 while game.library.busy: await process_frame
 var success: bool = game.active_sequence >= target and is_zero_approx(waiting_ms) and game.library.fallback_builds == 0
 game.free()
 quit(0 if success else 1)

func _pre_draw() -> void:
 render_started = Time.get_ticks_usec()

func _post_draw() -> void:
 render_wall_ms = (Time.get_ticks_usec() - render_started) / 1000.0

func _frame_summary(samples: Array) -> Dictionary:
 if samples.is_empty(): return {"count": 0}
 var times: Array = samples.map(func(row: Dictionary): return row.frame_ms)
 times.sort()
 return {"count": times.size(), "median_ms": times[times.size() / 2],
  "p95_ms": times[int(times.size() * 0.95)], "p99_ms": times[int(times.size() * 0.99)], "max_ms": times[-1]}
