extends SceneTree
const Session = preload("res://scripts/prototype/session.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func settle(session: Control) -> void:
 var deadline := Time.get_ticks_msec() + 120000
 while session.setup_menu.checking and Time.get_ticks_msec() < deadline: await process_frame
 check(not session.setup_menu.checking, "Bake validation completes")

func run() -> void:
 var session := Session.new()
 session.settings_path = "user://prototype-setup-regression.cfg"
 DirAccess.remove_absolute(session.settings_path)
 root.add_child(session)
 await settle(session)
 var setup: VBoxContainer = session.setup_menu
 check(not session.start_button.disabled and session.run_configuration.zone_count == 2 and session.run_configuration.selected_theme_ids == Session.Run.RunPlan.THEMES and session.run_configuration.selected_act_paths == session.available_act_paths, "Fresh menu defaults and valid bakes enable Start")
 check(setup.theme_checks.size() == 8 and setup.act_checks.size() == session.available_act_paths.size(), "Menu discovers the production catalogue")
 if DisplayServer.get_name() != "headless":
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/prototype-run-setup.png")
 for checkbox: CheckBox in setup.theme_checks.values(): checkbox.set_pressed_no_signal(false)
 setup._changed()
 check(session.start_button.disabled and "theme" in setup.reason.text, "Select none themes disables Start with reason")
 await session.start_run()
 check(session.game == null and session.state == "menu", "Invalid menu cannot start through direct action")
 setup.theme_checks.green_hill.set_pressed_no_signal(true)
 for count in 3:
  var index := 0
  for checkbox: CheckBox in setup.act_checks.values():
   checkbox.set_pressed_no_signal(index < count)
   index += 1
  setup._changed()
  check(session.start_button.disabled and "3 Acts" in setup.reason.text, "%d Acts disables Start with reason" % count)
 for checkbox: CheckBox in setup.act_checks.values(): checkbox.set_pressed_no_signal(true)
 setup.zones.value = 7
 setup._changed()
 await settle(session)
 check(not session.start_button.disabled and "21 Acts" in setup.reason.text, "Seven-Zone configuration is ready")
 var expected: Dictionary = session.run_configuration.snapshot()
 session.free()
 session = Session.new()
 session.settings_path = "user://prototype-setup-regression.cfg"
 root.add_child(session)
 await settle(session)
 check(session.run_configuration.snapshot() == expected, "Actual session reload restores setup")
 var reset: Button
 for button: Node in session.setup_menu.find_children("*", "Button", true, false):
  if button.text == "Reset run setup": reset = button
 reset.pressed.emit()
 await settle(session)
 check(session.run_configuration.zone_count == 2 and session.run_configuration.selected_theme_ids == Session.Run.RunPlan.THEMES and session.run_configuration.selected_act_paths == session.available_act_paths, "Reset restores defaults")
 # Full all-theme validation uses existing bakes only, with no builder present.
 for checkbox: CheckBox in session.setup_menu.theme_checks.values(): checkbox.set_pressed_no_signal(true)
 session.setup_menu._changed()
 await settle(session)
 check(not session.start_button.disabled, "Every production Act/theme combination has valid offline data")
 session.free()
 DirAccess.remove_absolute("user://prototype-setup-regression.cfg")
 # Let renderer cleanup finish before shutting down the test process.
 for i in 5: await process_frame
 print("RESULT | Prototype setup | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
