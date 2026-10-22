extends SceneTree
## Run without --headless for rendered review captures of the four sample seeds.
var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var game: Node = load("res://scenes/playground.tscn").instantiate()
 root.add_child(game)
 await create_timer(0.2).timeout
 var ui: PlaygroundDebugPanel = game.debug_panel
 check(ui.panel.size.x <= 388 and ui.generation_panel.get_global_rect().end.x <= 225, "Generation controls and existing lab fit their side margins")
 check(ui.steering_presets.selected == 2, "Quick / Tight shown on startup")
 ui.seed_field.get_line_edit().text = "12"
 ui.generation_buttons[0].pressed.emit()
 await create_timer(0.2).timeout
 check(game.generation_seed == 12 and game.layout.upper.chunk_id == "outer_return", "Build button commits an entered seed without requiring Enter first")
 ui.generation_buttons[1].pressed.emit()
 await create_timer(0.2).timeout
 check(game.generation_seed == 13, "Next seed advances current seed")
 var signature: String = game.layout.signature
 ui.seed_field.value = 42
 ui.generation_buttons[2].pressed.emit()
 await create_timer(0.2).timeout
 check(game.layout.signature == signature and ui.seed_field.value == 13, "Repeat uses current seed rather than an unbuilt edit")
 game.launch_ball()
 await create_timer(0.2).timeout
 check(ui.generation_buttons[0].disabled and not game.can_regenerate(), "Generation buttons disable during flight")
 game.toggle_pause()
 await create_timer(0.2).timeout
 check(not ui.generation_buttons[0].disabled, "Generation buttons enable while paused")
 ui.generation_buttons[0].pressed.emit()
 await create_timer(0.2).timeout
 check(paused and game.ball.serve_pending, "UI rebuild safely resets a paused table")
 game.toggle_pause()
 for seed_value: int in [1, 2, 10, 12]:
  ui.seed_field.get_line_edit().text = str(seed_value)
  ui.generation_buttons[0].pressed.emit()
  await create_timer(0.25).timeout
  check(game.generation_seed == seed_value and ui.generation_summary.text.contains(game.layout.upper.chunk_id), "Seed %d summary matches selected layout" % seed_value)
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png("res://test-results/table-seed-%d.png" % seed_value) == OK, "Rendered seed %d captured" % seed_value)
 game.presentation.physics_overlay.visible = true
 game.presentation.chunk_overlay.visible = true
 game.presentation.connector_overlay.visible = true
 await create_timer(0.15).timeout
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png("res://test-results/table-connectors.png") == OK, "Collision / chunk / connector overlays captured")
 print("RESULT | Generation UI | %d checks | %d failures" % [checks, failures])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
