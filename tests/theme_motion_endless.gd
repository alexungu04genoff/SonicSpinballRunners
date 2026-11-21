extends SceneTree
## The actual Endless engine and disk library, with only test theme order fixed.
const Report = preload("res://tests/render_profile_support.gd")
var output := "res://test-results/theme-motion/endless"
var checks := 0
var failures := 0
var receipt := {}

class SelectedEndless extends "res://scripts/endless/endless_game.gd":
 var motion_zone := 0
 func _next_planned_zone(documents: Array) -> Array[Dictionary]:
  planner.themes = [["rooftop_run", "casino_night", "ice_cap"][motion_zone % 3]]
  motion_zone += 1
  return planner.next_zone(documents)

func _initialize() -> void:
 Engine.time_scale = 0.0
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)

func run() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
 root.size = Vector2i(1440, 1000)
 preload("res://scripts/diagnostics/shadow_review.gd").position_review_window(root)
 DirAccess.make_dir_recursive_absolute(output)
 preload("res://scripts/rendering_options.gd").settings_path = output.path_join("graphics.cfg")
 if DisplayServer.get_name() == "headless":
  check(false, "Endless motion integration requires a graphical renderer")
  finish()
  return
 var game := SelectedEndless.new()
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 180000
 while (not game.started or not game._zone_ready(1) or game.resident.size() < 6) and Time.get_ticks_msec() < deadline:
  if not game.last_source_error.is_empty() or (is_instance_valid(game.library) and not game.library.error.is_empty()): break
  await process_frame
 var ready: bool = game.started and game._zone_ready(1) and game.resident.size() == 6
 check(ready, "Actual Endless loads both complete disk-backed Zones")
 if not ready:
  receipt.error = game.last_source_error if not game.last_source_error.is_empty() else game.library.error
  await game.prepare_to_close()
  game.free()
  finish()
  return
 paused = true
 game.set_process(false)
 game.set_physics_process(false)
 game.presentation.set_process(false)
 game.ball.freeze = true
 game.auto_launch_time = -1.0
 game.diagnostics.hide()
 Report.disable_native_input(game)
 game.retro_filter.set_effects(game.retro_filter.settings.default_effects)
 check(game.library.get_script() == preload("res://scripts/endless/template_library.gd"), "Endless retains production disk loader")
 check(game.library.fallback_builds == 0 and game.library.visual_bake_hits == 6 and game.library.theme_bake_hits == 2, "Six disk Acts and two shared themes, zero runtime fallback")
 var a: Node = game.backgrounds[0].layer
 var b: Node = game.backgrounds[1].layer
 var first_motion: RefCounted = a.motion
 var second_motion: RefCounted = b.motion
 check(first_motion.candidate == "C" and second_motion.candidate == "B", "Ordinary Endless loads Rooftop C and Casino B on separate Zone owners")
 check(first_motion != second_motion, "Each Endless Zone owns one distinct controller")
 var state := [game.ball.position, game.ball.linear_velocity, game.score, game.active_sequence]
 var identities: Array = game.resident.map(func(act: RefCounted): return act.nodes.map(func(node: Node): return node.get_instance_id()))
 receipt = {"authority":"Endless", "themes":["rooftop_run","casino_night"], "renderer":Report.metadata(),
  "disk_acts":game.library.visual_bake_hits,"disk_themes":game.library.theme_bake_hits,"fallback_builds":game.library.fallback_builds,"candidates":[],"crossfade":[]}
 for candidate: String in ["A", "B"]:
  first_motion.select(candidate, "FULL")
  second_motion.select(candidate, "FULL")
  first_motion.seek(7.25)
  second_motion.seek(11.75)
  check(first_motion.stats().bindings > 0 and second_motion.stats().bindings > 0, "Baked candidate bindings attach in both Endless themes: " + candidate)
  check(first_motion.stats().error.is_empty() and second_motion.stats().error.is_empty(), "Candidate binding restoration has no error: " + candidate)
  receipt.candidates.append({"candidate":candidate,"a":first_motion.stats(),"b":second_motion.stats()})
 for act: RefCounted in game.resident:
  check(act.contribution.valid and act.contribution.bounds.position.is_finite() and act.contribution.bounds.size.is_finite(), "Endless caches finite candidate contribution bounds")
 for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
  game._background_zone = 0
  game._last_atmosphere_blend = Vector3(-1, -1, -1)
  game.presentation.touring = true
  game.presentation.tour_focus = Vector2(game.resident[3].spawn().x, game.backgrounds[1].entrance_y + 200.0 - fraction * 450.0)
  game.presentation._update_camera(0.0)
  game._update_backgrounds()
  check(is_equal_approx(game.background_blend, smoothstep(0.0, 1.0, fraction)), "Endless distance-driven crossfade")
  check(first_motion.time == 7.25 and second_motion.time == 11.75, "Crossfade does not reset either environmental phase")
  if fraction == 0.0: check(b.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Incoming zero-weight viewport is disabled")
  if fraction == 1.0: check(a.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Outgoing zero-weight viewport is disabled")
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  if fraction == 0.5: root.get_texture().get_image().save_jpg(output.path_join("endless-crossfade.jpg"), 0.9)
  receipt.crossfade.append({"fraction":fraction,"blend":game.background_blend,"a":first_motion.stats(),"b":second_motion.stats()})
 check(state == [game.ball.position, game.ball.linear_velocity, game.score, game.active_sequence], "Endless motion leaves gameplay state untouched")
 check(identities == game.resident.map(func(act: RefCounted): return act.nodes.map(func(node: Node): return node.get_instance_id())), "Scrubbing and crossfade retain all streamed node identities")
 # Use the production retirement queue with processing held, then drain it in
 # the same post-order as the ordinary scheduler. No runtime rebuilding occurs.
 var outgoing: WeakRef = weakref(a)
 var incoming: WeakRef = weakref(b)
 var controller: WeakRef = weakref(first_motion)
 game.backgrounds.erase(0)
 game._queue_retirement(a)
 check(a.process_mode == Node.PROCESS_MODE_DISABLED, "Queued Zone disables processing immediately")
 while not game.retire_nodes.is_empty():
  var node: Node = game.retire_nodes.pop_back()
  if is_instance_valid(node): node.free()
 check(outgoing.get_ref() == null and first_motion.stats().bindings == 0, "Zone retirement frees layer and releases all motion registrations")
 first_motion = null
 a = null
 check(controller.get_ref() == null, "No project-owned controller survives retired Zone")
 await game.prepare_to_close()
 game.free()
 for frame in 3: await process_frame
 check(incoming.get_ref() == null and second_motion.stats().bindings == 0, "Scene close releases remaining Zone motion")
 second_motion = null
 finish()

func finish() -> void:
 receipt.checks = checks
 receipt.failures = failures
 FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(receipt, "  "))
 print("RESULT | Theme Motion Endless | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
