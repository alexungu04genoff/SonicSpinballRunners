extends "res://tests/score_attack_regression.gd"
## Exercise the actual F1 selector, mode-start path, replay, and failed-build state.

func run() -> void:
 game = load("res://scenes/playground.tscn").instantiate()
 game.generation_seed = 18
 game.generation_difficulty = TableGenerator.Difficulty.EASY
 root.add_child(game)
 await frames(6)
 var debug: PlaygroundDebugPanel = game.debug_panel
 var ui: ScoreAttackPanel = debug.challenge_panel
 check(game.zone_difficulty_override == -1 and debug.zone_difficulty_selector.selected == 0, "Development override defaults to the official Easy Zone")
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
 print("RESULT | Zone development difficulty | %d checks | %d failures" % [checks, failures])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
