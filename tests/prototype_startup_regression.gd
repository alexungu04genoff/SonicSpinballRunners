extends SceneTree
## Compare menu inspection policies against the same exported PCK and renderer.
const Session = preload("res://scripts/prototype/session.gd")
const Bake = preload("res://scripts/endless/geometry_bake.gd")
var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)

func run() -> void:
 var baseline := "--baseline" in OS.get_cmdline_user_args()
 var started := Time.get_ticks_msec()
 var session := Session.new()
 session.settings_path = "user://startup-regression-%d.cfg" % OS.get_process_id()
 root.add_child(session)
 var setup: VBoxContainer = session.setup_menu
 # The editor executable runs standalone test scripts; match the template policy.
 if not baseline: setup.inspect_bakes = false
 var deadline := Time.get_ticks_msec() + 120000
 while setup.checking and Time.get_ticks_msec() < deadline: await process_frame
 var menu_ms := Time.get_ticks_msec() - started
 check(not setup.checking and not session.start_button.disabled, "All selected packaged levels enable Play")
 print("STARTUP_TIMING | menu_ms=", menu_ms, " | themes=", session.run_configuration.selected_theme_ids.size(), " | acts=", session.available_act_paths.size())
 if not baseline:
  check(setup.theme_fingerprints.is_empty() and setup.theme_validity.is_empty(), "Packaged menu leaves deep inspection to export and runtime")
  for theme: String in session.run_configuration.selected_theme_ids:
   check(not ResourceLoader.has_cached(Bake.theme_path(theme)), "Menu does not load theme graphics: " + theme)
   for path: String in session.available_act_paths:
    check(not ResourceLoader.has_cached(Bake.path_for(path, theme)), "Menu does not load level graphics: " + theme + ":" + path)
  var missing: String = await setup._bake_error("res://data/acts/Authored/__missing_startup_test__.tres", session.run_configuration.selected_theme_ids[0])
  check(not missing.is_empty(), "Missing bake files still block the packaged menu")
  var selected: Array = session.run_configuration.selected_act_paths.duplicate()
  for checkbox: CheckBox in setup.act_checks.values(): checkbox.set_pressed_no_signal(false)
  setup._changed()
  check(session.start_button.disabled, "An invalid level pool still blocks Play")
  for path: String in setup.act_checks: setup.act_checks[path].set_pressed_no_signal(path in selected)
  setup._changed()
  while setup.checking: await process_frame
  started = Time.get_ticks_msec()
  session.start_button.pressed.emit()
  deadline = Time.get_ticks_msec() + 120000
  while (not is_instance_valid(session.game) or not session.game.started) and Time.get_ticks_msec() < deadline and session.state != "error": await process_frame
  var ready: bool = is_instance_valid(session.game) and session.game.started
  check(ready, "Run reaches the first Act with deferred validation")
  print("STARTUP_TIMING | first_act_ms=", Time.get_ticks_msec() - started)
  if ready:
   check(session.game.library.fallback_builds == 0, "Runtime uses validated disk bakes without rebuilding")
   check(not session.game.library._fingerprints.is_empty(), "Runtime still checks pipeline fingerprints")
   check(session.game.retro_filter.selected_effects == session.game.retro_filter.settings.default_effects, "Retro defaults are preserved")
   await session.game.prepare_to_close()
   session.game.free()
   session.game = null
 session.free()
 DirAccess.remove_absolute("user://startup-regression-%d.cfg" % OS.get_process_id())
 for frame in 5: await process_frame
 print("RESULT | Packaged startup | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
