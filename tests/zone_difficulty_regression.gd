extends "res://tests/score_attack_regression.gd"
## Exercise the actual F1 selector, mode-start path, replay, and failed-build state.

func run() -> void:
 green_hill = OS.get_cmdline_user_args().has("--green-hill")
 game = load("res://experiments/visual_lab/visual_lab.tscn" if green_hill else "res://scenes/playground.tscn").instantiate()
 game.generation_seed = 18
 game.generation_difficulty = TableGenerator.Difficulty.EASY
 root.add_child(game)
 await frames(6)
 var debug: PlaygroundDebugPanel = game.debug_panel
 var ui: ScoreAttackPanel = debug.challenge_panel
 check(game.zone_difficulty_override == -1 and debug.zone_difficulty_selector.selected == 0, "Development override defaults to the official Easy Zone")
 check(debug.grid_selector.get_item_text(1) == "Grid base" and debug.grid_caption.text.begins_with("Middle"), "Sandbox construction labels retain catalogue and individual recipe meanings")
 var sandbox_signature: String = game.layout.signature
 debug.zone_difficulty_selector.select(2)
 check(ui.start_run(), "Free Play can restart while a development Zone choice is pending")
 await frames(6)
 check(not game.zone_enabled and game.layout.signature == sandbox_signature and game.zone_difficulty_override == -1, "A pending Zone override does not change Free Play difficulty")

 ui.mode_selector.select(2)
 debug.zone_difficulty_selector.select(1)
 check(ui.start_run(), "Start / replay accepts the Normal development selection")
 await frames(6)
 check(game.zone_enabled and game.chunks.size() == 9 and game.generation_difficulty == TableGenerator.Difficulty.NORMAL and game.zone_difficulty_override == TableGenerator.Difficulty.NORMAL, "Normal development selection builds all nine chunks at Normal")
 check(game.zone_config.difficulty == TableGenerator.Difficulty.EASY and ui.zone_panel.heading.text.contains("DEV NORMAL"), "Official configuration remains Easy and the HUD identifies the development build")
 check(debug.grid_selector.get_item_text(0) == "Layout shuffle A" and debug.grid_selector.get_item_text(2) == "Layout shuffle C" and debug.generation_summary.text.contains("Layout shuffle A"), "Zone labels describe deterministic layout shuffles rather than individual grid recipes")
 if green_hill:
  check(game.layout_buttons[0].text == "Zone seed 18" and game.layout_buttons[2].text == "Layout shuffle B" and game.status_label.text.contains("Layout shuffle A"), "Green Hill footer identifies seeded Zone layouts and shuffles")
 var normal_signature: String = game.layout.signature
 debug.generation_buttons[2].pressed.emit()
 await frames(6)
 check(game.layout.signature == normal_signature and game.zone_difficulty_override == TableGenerator.Difficulty.NORMAL, "Repeat current layout retains the override and exact seeded geometry")

 debug.zone_difficulty_selector.select(2)
 debug.generation_buttons[1].pressed.emit()
 await frames(6)
 check(game.generation_seed == 19 and game.generation_difficulty == TableGenerator.Difficulty.HARD and game.zone_difficulty_override == TableGenerator.Difficulty.HARD and game.chunks.size() == 9, "Next seed applies the Hard development override to a full Zone")
 check(ui.zone_panel.heading.text.contains("DEV HARD") and debug.generation_summary.text.contains("DEV Hard"), "Both visible HUD and F1 summary identify Hard development geometry")

 var retained_signature: String = game.layout.signature
 var valid_config: ZoneConfig = game.zone_config
 var invalid_config: ZoneConfig = valid_config.duplicate(true)
 invalid_config.act_targets = []
 game.zone_config = invalid_config
 debug.zone_difficulty_selector.select(0)
 debug.generation_buttons[0].pressed.emit()
 await frames(6)
 check(game.layout.signature == retained_signature and game.zone_difficulty_override == TableGenerator.Difficulty.HARD and not game.generation_pending and game.status_message.to_lower().contains("failed"), "Rejected generation reports failure and preserves the active override and table")
 game.zone_config = valid_config

 debug.zone_difficulty_selector.select(0)
 check(ui.start_run(), "Official Easy can be selected again without restarting Godot")
 await frames(6)
 check(game.generation_difficulty == TableGenerator.Difficulty.EASY and game.zone_difficulty_override == -1 and not ui.zone_panel.heading.text.contains("DEV"), "Returning to official mode restores Easy geometry and clears the development badge")
 var canvas_height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
 check(debug.generation_panel.get_global_rect().end.y <= canvas_height and debug.generation_panel.get_global_rect().end.x < 235.0, "The expanded generator controls fit their canvas area without overlapping the Zone HUD")
 ui.mode_selector.select(0)
 check(ui.start_run(), "Free Play can resume after reviewing a Zone layout")
 await frames(6)
 check(not game.zone_enabled and debug.grid_selector.get_item_text(0) == "Existing catalogue" and debug.grid_selector.get_item_text(2) == "Grid variant" and debug.generation_summary.text.contains("Middle:"), "Returning to Free Play restores recipe-specific construction labels")
 if green_hill:
  check(game.layout_buttons[0].text == "Normal 18" and game.layout_buttons[2].text == "Grid base" and not game.status_label.text.contains("Layout shuffle"), "Green Hill footer restores sandbox preset and grid-recipe labels")
 print("RESULT | Zone development difficulty | %d checks | %d failures" % [checks, failures])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
