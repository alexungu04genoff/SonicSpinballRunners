extends SceneTree
## Run without --headless for rendered review captures of the three difficulty tiers.
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
 ui.camera_presets.select(TablePresentation.CameraPreset.DRAMATIC_PINBALL)
 ui.camera_presets.item_selected.emit(TablePresentation.CameraPreset.DRAMATIC_PINBALL)
 ui.seed_field.get_line_edit().text = "12"
 ui.generation_buttons[0].pressed.emit()
 await create_timer(0.2).timeout
 check(game.generation_seed == 12 and game.generation_difficulty == TableGenerator.Difficulty.NORMAL and game.layout.signature == TableGenerator.generate(12).signature, "Build button commits entered seed and selected preference")
 check(ui.generation_summary.text.contains("Transitions: " + game.layout.transition_summary) and ui.generation_summary.text.contains("Join 1: " + game.layout.junctions[0].transition_style), "Generator panel reports requested and actual connector styles")
 check(game.presentation.camera_preset == TablePresentation.CameraPreset.DRAMATIC_PINBALL and ui.camera_presets.selected == TablePresentation.CameraPreset.DRAMATIC_PINBALL, "Generating a new difficulty layout preserves the selected perspective camera")
 ui.difficulty_selector.select(TableGenerator.Difficulty.HARD)
 ui.generation_buttons[1].pressed.emit()
 await create_timer(0.2).timeout
 check(game.generation_seed == 13 and game.generation_difficulty == TableGenerator.Difficulty.HARD, "Next seed advances current seed and applies selected preference")
 var signature: String = game.layout.signature
 ui.seed_field.value = 42
 ui.difficulty_selector.select(TableGenerator.Difficulty.EASY)
 ui.generation_buttons[2].pressed.emit()
 await create_timer(0.2).timeout
 check(game.layout.signature == signature and ui.seed_field.value == 13 and ui.difficulty_selector.selected == TableGenerator.Difficulty.HARD, "Repeat restores current seed and difficulty despite unbuilt edits")
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
 ui.camera_presets.select(TablePresentation.CameraPreset.REAL_PINBALL)
 ui.camera_presets.item_selected.emit(TablePresentation.CameraPreset.REAL_PINBALL)
 for preference in 3:
  ui.seed_field.get_line_edit().text = "1"
  ui.difficulty_selector.select(preference)
  ui.generation_buttons[0].pressed.emit()
  await create_timer(0.25).timeout
  check(game.generation_seed == 1 and game.generation_difficulty == preference and game.layout.preference_available and game.layout.difficulty_estimate.band == preference and ui.generation_summary.text.contains(game.layout.chunks[0].chunk_id) and ui.generation_summary.text.contains("Largest ledge") and ui.generation_summary.text.contains("Estimate:"), "Preference %s displays a matching layout, estimate and reasons" % TableGenerator.DIFFICULTY_NAMES[preference])
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png("res://test-results/table-difficulty-%d.png" % preference) == OK, "Rendered preference %d captured" % preference)
 check(ui.generation_panel.get_global_rect().end.y < 835 and ui.generation_panel.get_global_rect().end.x <= 225, "Expanded difficulty controls fit beside the table")
 # Exercise the summary presenter with an intentionally limited catalogue, then
 # restore the actual scene's layout before taking any collision-overlay capture.
 var actual_layout: Dictionary = game.layout
 game.layout = TableGenerator.generate_pair(1, TableGenerator.Difficulty.HARD, [TableGenerator.CATALOGUE[0]])
 ui.refresh_generation()
 await create_timer(0.15).timeout
 check(ui.generation_summary.text.contains("No valid Hard candidate; using") and ui.generation_summary.text.contains(TableGenerator.DIFFICULTY_NAMES[game.layout.difficulty_estimate.band]) and ui.generation_panel.get_global_rect().end.y < 835, "Missing tier is explicit and its longer notice remains visible")
 game.layout = actual_layout
 ui.refresh_generation()
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
