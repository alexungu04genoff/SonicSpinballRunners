extends SceneTree
## Real disk-loaded sessions; weak observations never prolong production ownership.
const Session = preload("res://scripts/prototype/session.gd")
const Options = preload("res://scripts/rendering_options.gd")
const Report = preload("res://tests/render_profile_support.gd")
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []
var output := "res://test-results/lifecycle-audit/repeated.json"

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func observe(refs: Dictionary, label: String, value: Object) -> void:
 if is_instance_valid(value): refs[label] = {"reference": weakref(value), "id": value.get_instance_id(), "class": value.get_class()}

func runtime_refs(game: Node) -> Dictionary:
 var refs := {}
 for key: String in ["library", "ring_field", "hub", "tuning", "controls", "scorecraft", "specials", "buddies", "telemetry", "run_configuration", "view", "_composite_view", "presentation"]:
  observe(refs, key, game.get(key))
 observe(refs, "game", game)
 observe(refs, "combo_celebration", game.combo_celebration)
 observe(refs, "character_pose", game.combo_celebration.character_pose)
 observe(refs, "flight_rig", game.combo_celebration.character_pose.flight)
 observe(refs, "retirement", game.library.retirement)
 observe(refs, "warm_view", game.library._view)
 for act: RefCounted in game.resident:
  var prefix := "act%d/" % act.plan.sequence
  observe(refs, prefix + "owner", act)
  observe(refs, prefix + "contribution", act.contribution)
  observe(refs, prefix + "mechanics", act.runtime.mechanics)
  observe(refs, prefix + "visual", act.visual)
  observe(refs, prefix + "recipe", act.recipe)
 for key: int in game.backgrounds:
  var layer: Node = game.backgrounds[key].layer
  var prefix := "zone%d/" % key
  observe(refs, prefix + "layer", layer)
  observe(refs, prefix + "atmosphere", layer.atmosphere)
  observe(refs, prefix + "bindings", layer.atmosphere.bindings)
  observe(refs, prefix + "environment", layer.atmosphere.environment)
  observe(refs, prefix + "light", layer.light)
  observe(refs, prefix + "view", layer.view)
 return refs

func surviving(refs: Dictionary) -> Array:
 var result := []
 for label: String in refs:
  if refs[label].reference.get_ref() != null:
   result.append({"label": label, "id": refs[label].id, "class": refs[label].class})
 return result

func census() -> Dictionary:
 return {"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
  "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
  "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
  "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
  "registered_view_slots": Options._views.size(), "registered_light_slots": Options._lights.size(),
  "live_registered_views": Options._views.filter(func(ref): return ref.get_ref() != null).size(),
  "live_registered_lights": Options._lights.filter(func(ref): return ref.get_ref() != null).size(),
  "pre_draw_connections": RenderingServer.get_signal_connection_list("frame_pre_draw").size(),
  "post_draw_connections": RenderingServer.get_signal_connection_list("frame_post_draw").size(),
  "close_connections": root.get_signal_connection_list("close_requested").size()}

func settle() -> void:
 # Observe ordinary queued deletion and renderer frames; no cleanup is performed here.
 for frame in 8:
  await process_frame
  await RenderingServer.frame_post_draw

func run() -> void:
 if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
  push_error("Lifecycle ownership requires graphical Forward+/Vulkan.")
  quit(1)
  return
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--lifecycle-output="): output = arg.trim_prefix("--lifecycle-output=")
 root.gui_disable_input = true
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 Options.settings_path = output.get_basename() + "-graphics.cfg"
 await settle()
 var initial := census()
 var default_scale := int(Options.initial_quality(RenderingServer.get_video_adapter_name()).scale_percent) / 100.0
 for cycle in 3:
  var session := Session.new()
  session.settings_path = output.get_basename() + "-session.cfg"
  session.archive_directory = output.get_basename() + "-archives"
  session.run_configuration = Session.Run.RunPlan.Configuration.new([
   "res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/Reverse C Spring.tres", "res://data/acts/Authored/Secret Entry.tres"])
  session.run_configuration.zone_count = 1
  session.run_configuration.selected_theme_ids = ["green_hill"]
  session.sound_enabled = false
  root.add_child(session)
  var session_ref: WeakRef = weakref(session)
  var finished_runs: Array[Dictionary] = []
  for run_index in 2:
   while is_instance_valid(session.setup_menu) and session.setup_menu.checking: await process_frame
   session.selected_character = "tails" if run_index == 1 else "sonic"
   await session.start_run()
   var game: Node = session.game
   var deadline := Time.get_ticks_msec() + 180000
   while (not game.started or game.library.busy or game.building != null or game.resident.size() < 3) and game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline:
    await process_frame
   check(game.started and game.resident.size() == 3, "Three normal resident Acts attach")
   if not finished_runs.is_empty():
    check(surviving(finished_runs.back()).is_empty(), "Starting a new run releases the previous replay configuration and retired owners")
   check(game.library.fallback_builds == 0, "Session uses validated disk bakes")
   check(game.view.msaa_3d == Viewport.MSAA_2X and is_equal_approx(game.view.scaling_3d_scale, default_scale), "Production pixel defaults remain intact")
   game.launch_ball()
   for tick in 30: await physics_frame
   game.set_celebration_retro(run_index == 1)
   game.combo_celebration.consider(game.character_id, 5, 100)
   game.combo_celebration._process(0.3)
   check(game.combo_celebration.visible, "Retire a live cut-in in each rendering layer")
   var refs := runtime_refs(game)
   var record := {"cycle": cycle, "run": run_index, "live": census()}
   await session.return_to_menu()
   record["after_close"] = surviving(refs)
   await session.return_to_menu()
   await settle()
   record["after_frames"] = surviving(refs)
   record["menu"] = census()
   # Results replay deliberately retains this plain configuration until the next
   # run or Session disposal. It must not retain any Game, Act or renderer owner.
   check(record.after_frames.size() == 1 and record.after_frames[0].label == "run_configuration"
    and refs.run_configuration.reference.get_ref() == session.last_run_configuration,
    "Only the Session replay configuration outlives the retired runtime")
   observations.append(record)
   print("LIFECYCLE_RUN | ", JSON.stringify(record))
   finished_runs.append(refs)
  session.queue_free()
  await settle()
  check(session_ref.get_ref() == null, "Session and its menu leave the tree")
  var retained_after_session: Array = []
  for refs: Dictionary in finished_runs: retained_after_session.append_array(surviving(refs))
  check(retained_after_session.is_empty(), "Session disposal releases every run owner, including the replay configuration")
  var idle := census()
  check(idle.live_registered_views == 0 and idle.live_registered_lights == 0, "Device registries retain no live session targets")
  check(idle.nodes == initial.nodes and idle.orphans == initial.orphans, "Node and orphan counts return to the pre-session baseline")
  observations.append({"cycle": cycle, "idle": idle, "retained_after_session": retained_after_session})
  print("LIFECYCLE_IDLE | ", JSON.stringify(idle))
 var file := FileAccess.open(output, FileAccess.WRITE)
 file.store_string(JSON.stringify({"metadata": Report.metadata(), "initial": initial, "observations": observations, "checks": checks, "failures": failures}, "  "))
 file.close()
 print("RESULT | Prototype lifecycle | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
