extends SceneTree
## Normal Challenge session driven only through player inputs, with isolated saves.
const Session = preload("res://scripts/prototype/session.gd")
const Report = preload("res://tests/render_profile_support.gd")
var game: Node
var input_ticks := 0
var measured := {}

func _initialize() -> void: call_deferred("run")

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Gameplay profiling requires a graphical renderer.")
  quit(1)
  return
 var output := "res://test-results/prototype-play.json"
 var theme := "green_hill"
 var seconds := 30.0
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--profile-output="): output = argument.trim_prefix("--profile-output=")
  if argument.begins_with("--profile-theme="): theme = argument.trim_prefix("--profile-theme=")
  if argument.begins_with("--profile-seconds="): seconds = maxf(1.0, float(argument.trim_prefix("--profile-seconds=")))
 Engine.max_fps = 0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var session := Session.new()
 session.settings_path = "user://renderer_profile_settings.cfg"
 session.archive_directory = "user://renderer_profile_telemetry"
 root.add_child(session)
 session.run_configuration = Session.Run.RunPlan.Configuration.new([
  "res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/Reverse C Spring.tres", "res://data/acts/Authored/Secret Entry.tres"])
 session.run_configuration.zone_count = 1
 session.run_configuration.selected_theme_ids = [theme]
 session.practice_mode = false
 # The menu validates the selected bakes asynchronously before Start is enabled.
 # Rebuild it for this course and follow that normal readiness gate.
 root.gui_disable_input = true
 var menu_at := Time.get_ticks_usec()
 session._show_menu()
 while session.setup_menu.checking and Time.get_ticks_usec() - menu_at < 180000000: await process_frame
 var menu_validation_ms := (Time.get_ticks_usec() - menu_at) / 1000.0
 if session.start_button.disabled:
  push_error("Play profile menu validation failed: " + session.setup_menu.reason.text)
  session.free()
  quit(1)
  return
 var start := Time.get_ticks_usec()
 await session.start_run()
 game = session.game
 if game == null:
  push_error("Play profile did not enter the run.")
  session.free()
  quit(1)
  return
 Report.disable_native_input(session)
 game.draft_started.connect(func(_result: Dictionary, offers: Array[Dictionary]):
  session.call_deferred("_choose_buddy", "" if offers.is_empty() else str(offers[0].id))
 )
 var startup_frames: Array = []
 var previous := start
 while not game.started and game.library.error.is_empty() and Time.get_ticks_usec() - start < 180000000:
  await process_frame
  var now := Time.get_ticks_usec()
  startup_frames.append((now - previous) / 1000.0)
  previous = now
 if not game.started:
  push_error("Play profile startup failed: " + game.library.error)
  await session._close_run("profile_failed")
  session.free()
  quit(1)
  return
 var ready_ms := (Time.get_ticks_usec() - start) / 1000.0
 var ready_pipelines := Report.pipelines()
 game.controls.virtual_enabled = true
 physics_frame.connect(_input_tick)
 game.launch_ball()
 var rows: Array[Dictionary] = []
 var playing_at := Time.get_ticks_usec()
 previous = playing_at
 while not game.finished and input_ticks < int(seconds * Engine.physics_ticks_per_second) and Time.get_ticks_usec() - playing_at < 120000000:
  await process_frame
  var now := Time.get_ticks_usec()
  var cpu := RenderingServer.get_frame_setup_time_cpu()
  var gpu := 0.0
  var views: Array[Viewport] = [root, game.view, game._composite_view, game.library._view]
  for background: Dictionary in game.backgrounds.values(): views.append(background.layer.view)
  for view: Viewport in views:
   var id := view.get_instance_id()
   if not measured.has(id):
    RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
    measured[id] = true
   if view is SubViewport and view.render_target_update_mode == SubViewport.UPDATE_DISABLED: continue
   cpu += RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())
   gpu += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
  rows.append({"frame_ms": (now - previous) / 1000.0,
   "draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
   "objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
   "render_cpu_ms": cpu, "render_gpu_ms": gpu, "resident_acts": game.resident.size(),
   "waiting": game.loading_boundary, "build_ms": game.last_build_ms, "stage": game.library.profile_stage})
  previous = now
 physics_frame.disconnect(_input_tick)
 var summary := Report.metadata()
 summary.merge({"theme": theme, "seed": game.run_seed, "practice": game.practice_mode,
  "physics_ticks": Engine.physics_ticks_per_second, "input_ticks": input_ticks,
  "window_size": [root.size.x, root.size.y], "world_size": [game.view.size.x, game.view.size.y],
  "ready_ms": ready_ms, "startup_frames": Report.timing(startup_frames),
  "menu_validation_ms": menu_validation_ms,
  "duration_ms": (Time.get_ticks_usec() - playing_at) / 1000.0,
  "timing": Report.timing(rows.map(func(row): return row.frame_ms)),
  "ready_pipelines": ready_pipelines, "pipelines": Report.pipelines(),
  "finished": game.finished, "score": game.score, "balls_remaining": game.balls_remaining,
  "resident_peak": rows.map(func(row): return row.resident_acts).max(),
  "waiting_ms": rows.reduce(func(total, row): return total + (row.frame_ms if row.waiting else 0.0), 0.0),
  "rebuilds": game.library.fallback_builds,
  "note": "Input-only Challenge session with HUD, sounds and telemetry. Launches and steers normally; no score grants, teleports or forced clears. Dynamic paths can diverge across runs."})
 for key: String in ["draws", "objects", "render_cpu_ms", "render_gpu_ms"]:
  var values: Array = rows.map(func(row): return row[key])
  values.sort()
  summary[key + "_median"] = values[values.size() / 2]
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file := FileAccess.open(output, FileAccess.WRITE)
 file.store_string(JSON.stringify({"summary": summary, "frames": rows}))
 file.close()
 print("PROTOTYPE_PLAY_PROFILE | ", JSON.stringify(summary))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.get_basename() + ".png")
 await session._close_run("profile_complete")
 session.free()
 quit(0)

func _input_tick() -> void:
 if not is_instance_valid(game) or game.finished or game.active == null: return
 input_ticks += 1
 var local: Vector2 = game.ball.position - Vector2(game.active.plan.offset)
 var height: float = game.active.document.terrain_bounds().size.y
 var aim_x: float = game.active.document.spawn_position.x
 if game.exit_unlocked: aim_x = (game.active.document.exit_start_x + game.active.document.exit_width * 0.5) * game.active.document.cell_size
 game.controls.virtual_steering = clampf((aim_x - local.x) * 0.04 - game.ball.linear_velocity.x * 0.02, -1.0, 1.0)
 game.controls.virtual_left = local.y > height - 180.0 and input_ticks % 60 < 12
 game.controls.virtual_right = game.controls.virtual_left
 if game.ball.serve_pending and game.respawn_time < 0.0: game.launch_ball()
