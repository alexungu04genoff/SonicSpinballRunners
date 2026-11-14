extends SceneTree
## Exercise the packaged menu, disk bakes, Buddy draft, HUD and saved Results.
const Session = preload("res://scripts/prototype/session.gd")
const THEMES := ["casino_night", "rooftop_run", "green_hill", "aquarium_park", "ice_cap", "chemical_plant"]
var checks := 0
var failures := 0
var output := "user://playtest-verification"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "Capture " + label)

func run() -> void:
 var character := "sonic"
 var theme := "casino_night"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
  if argument.begins_with("--playtest-character="): character = argument.trim_prefix("--playtest-character=")
  if argument.begins_with("--playtest-theme="): theme = argument.trim_prefix("--playtest-theme=")
 DirAccess.make_dir_recursive_absolute(output)
 check(ProjectSettings.get_setting("display/window/size/mode") == 3, "Build starts fullscreen")
 check(Session.Run.RunPlan.Configuration.Profile.theme_ids() == THEMES, "Exactly six themes are available")
 check(Session.Run.RunPlan.Configuration.Profile.character_ids() == ["sonic", "tails"], "Only Sonic and Tails are available")
 var session := Session.new()
 session.settings_path = output.path_join("settings.cfg")
 session.archive_directory = output.path_join("telemetry")
 DirAccess.remove_absolute(session.settings_path)
 root.add_child(session)
 check(session.run_configuration.snapshot().selected_themes == Session.Run.RunPlan.Configuration._unique(THEMES) and session.selected_character == "sonic" and not session.practice_mode, "Fresh package defaults to all allowed themes, Sonic and Challenge")
 var setup: VBoxContainer = session.setup_menu
 check(session.available_act_paths.size() == 7 and setup.act_checks.values().all(func(checkbox): return checkbox.button_pressed), "All seven Acts start enabled")
 check(session.run_configuration.atmosphere_overrides.is_empty() and not setup.advanced.visible, "Random atmospheres and a collapsed Customize panel are the defaults")
 var menu_deadline := Time.get_ticks_msec() + 180000
 while setup.checking and Time.get_ticks_msec() < menu_deadline: await process_frame
 await capture("startup")
 check(setup.theme_checks.size() == 6 and setup.atmosphere_choices.size() == 6, "Theme and variant selectors use the packaged catalogue")
 var character_choices: Array = session.overlay_root.find_children("*", "OptionButton", true, false).filter(func(node): return node.item_count > 0 and node.get_item_metadata(0) == "sonic")
 check(character_choices.size() == 1 and character_choices[0].item_count == 2, "Character menu has two choices")
 if not character_choices.is_empty():
  character_choices[0].select(0 if character == "sonic" else 1)
  character_choices[0].item_selected.emit(character_choices[0].selected)
 setup.zones.value = 1
 for id: String in setup.theme_checks: setup.theme_checks[id].set_pressed_no_signal(id == theme)
 var sources := ["GateDash.tres", "DropTarget-SW-SP-DT.tres", "First Try Smooth Decor.tres"]
 for path: String in setup.act_checks: setup.act_checks[path].set_pressed_no_signal(path.get_file() in sources)
 var variant := "variant_1410883925" if theme == "casino_night" else "default"
 var picker: OptionButton = setup.atmosphere_choices[theme]
 for index in picker.item_count:
  if picker.get_item_metadata(index) == variant:
   picker.select(index)
   picker.item_selected.emit(index)
 setup._changed()
 var deadline := Time.get_ticks_msec() + 180000
 while setup.checking and Time.get_ticks_msec() < deadline: await process_frame
 check(not setup.checking and not session.start_button.disabled, "Selected packaged bakes pass menu validation")
 await capture("menu")
 if session.start_button.disabled:
  session.free()
  quit(1)
  return
 session.start_button.pressed.emit()
 deadline = Time.get_ticks_msec() + 240000
 while (not is_instance_valid(session.game) or not session.game.started) and Time.get_ticks_msec() < deadline and session.state != "error": await process_frame
 var ready: bool = is_instance_valid(session.game) and session.game.started
 check(ready, "Packaged game starts from disk bakes")
 if not ready:
  quit(1)
  return
 var game: Node = session.game
 check(game.character_id == character and game.run_plan.size() == 3, "Character and run length reach gameplay")
 check(game.run_plan.all(func(entry): return entry.theme == theme and entry.atmosphere.id == variant), "Chosen atmosphere reaches every Act")
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.ball.freeze = true
 game._update_hud(0.0)
 check(game.heading.text.is_valid_int() and game.player_hud.lives.text.begins_with("× ") and game.detail.text.split("\n").size() == 1, "Icon HUD shows essentials")
 check(game.retro_filter.selected_effects == game.retro_filter.settings.default_effects and not game.retro_filter.selected_effects.is_empty(), "Production Retro stack remains enabled")
 check(not game.fps_label.visible and not game.diagnostics.visible, "Debug counters start hidden")
 await capture("playing")
 if "--preview-only" in OS.get_cmdline_user_args():
  check(game.library.fallback_builds == 0, "Preview uses disk bakes without runtime rebuilds")
  await session._close_run("quit")
  session.free()
  print("RESULT | Playtest preview | %d checks | %d failures" % [checks, failures])
  quit(1 if failures else 0)
  return
 game.rings_collected = 17
 game.balls_remaining = 2
 game._update_hud(0.0)
 check(game.heading.text == "017" and game.player_hud.lives.text.ends_with("2"), "Rings and remaining Balls update")
 game.practice_mode = true
 game._update_hud(0.0)
 check("∞" in game.player_hud.lives.text, "Practice shows unlimited Balls")
 game.practice_mode = false
 for sequence in 3:
  game.ball.freeze = true
  game.ball.serve_pending = false
  game.ball._teleport_pending = false
  game.auto_launch_time = -1.0
  game.ball.position = game.active.spawn()
  game.active.runtime.mechanics.mechanic_score.emit(&"wall_switch", "playtest_verification", game.act_score_target)
  deadline = Time.get_ticks_msec() + 180000
  while game._has_next_act() and not game._next_ready() and Time.get_ticks_msec() < deadline: await process_frame
  check(game.active_sequence == sequence and game.act_score >= game.act_score_target, "Act target remains active")
  game._update_hud(0.0)
  check("GOAL READY" in game.detail.text, "Compact HUD announces Goal readiness")
  var goal: Vector2 = game.active.runtime.goal_ring.center
  game._observe_authored_motion(goal, goal)
  if sequence < 2:
   check(game.drafting, "Goal opens Buddy draft")
   if not game.drafting: break
   await capture("buddy-%d" % sequence)
   var offers: Array = game.buddies.offers()
   if offers.is_empty(): session._choose_buddy("")
   else: session._choose_buddy(offers[0].id)
   check(not game.buddies.levels.is_empty(), "Buddy selection grants a run upgrade")
   deadline = Time.get_ticks_msec() + 180000
   while is_instance_valid(game.transfer) and Time.get_ticks_msec() < deadline: await process_frame
   check(not is_instance_valid(game.transfer), "Next Act transfer completes")
 check(game.finished and session.last_summary.get("won", false), "Final Goal completes the run")
 check(game.library.fallback_builds == 0, "No runtime geometry rebuilds")
 check(not session.archive_result.get("path", "").is_empty() and session.archive_result.get("error", "missing").is_empty() and FileAccess.file_exists(session.archive_result.path), "Results telemetry archives locally")
 await capture("results")
 await game.prepare_to_close()
 session.free()
 paused = false
 print("RESULT | Playtest package %s/%s | %d checks | %d failures" % [character, theme, checks, failures])
 quit(1 if failures else 0)
