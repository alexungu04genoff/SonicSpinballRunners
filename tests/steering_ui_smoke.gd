extends SceneTree
## Run graphically to also capture test-results/steering-lab.png. Headless checks layout only.
var failures: int = 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String) -> void:
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error(label)

func run() -> void:
 var game: Node = load("res://scenes/playground.tscn").instantiate()
 root.add_child(game)
 await create_timer(0.2).timeout
 var original: Dictionary = game.tuning.base.as_values()
 game.tuning.set_value("gravity_scale", 1.25)
 game.debug_panel.steering_presets.item_selected.emit(3)
 await create_timer(0.1).timeout
 check(game.tuning.base.as_values() == original and game.tuning.effective.gravity_scale == 1.25 and game.tuning.effective.counter_steering_deceleration == 3600.0, "Preset UI changes only steering overrides; base resource and gravity remain intact")
 game.debug_panel.spinboxes.steering_acceleration.value = 1900
 check(game.debug_panel.steering_presets.selected == 0, "Independent field editing labels the preset as custom")
 game.tuning.select_profile(1)
 game.debug_panel.refresh_fields()
 check(game.debug_panel.steering_presets.selected == 1 and game.tuning.effective.counter_steering_deceleration == 1000.0, "Profile switch restores original steering and keeps UI selection truthful")
 game.tuning.select_profile(0)
 game.debug_panel.steering_presets.item_selected.emit(3)
 # Show a reproducible airborne counter-steering state without injecting OS input.
 game.controls.virtual_enabled = true
 game.controls.virtual_steering = 1.0
 game.ball.teleport_to(Vector2(630, 620), Vector2(-700, 300))
 await create_timer(0.15).timeout
 var panel: Control = game.debug_panel.panel
 var readout: Label = game.debug_panel.steering_telemetry
 check(readout.text.contains("Raw") and readout.text.contains("Impulse X") and readout.text.contains("Last reset") and readout.get_global_rect().end.y < panel.get_global_rect().end.y and panel.size.x <= 388.0, "Steering readout contains diagnostics and fits inside the panel")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  var error: Error = root.get_texture().get_image().save_png("res://test-results/steering-lab.png")
  check(error == OK, "Rendered steering lab screenshot saved")
 print("RESULT | Steering UI smoke | %d failures" % failures)
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
