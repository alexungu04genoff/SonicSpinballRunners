extends Node
## Export verification: actual three-Act Prototype, with source construction.
const Run = preload("res://scripts/prototype/zone_run.gd")

func _ready() -> void:
 var game := Run.new()
 var config := Run.RunPlan.Configuration.new(["res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/Reverse C Spring.tres", "res://data/acts/Authored/Secret Entry.tres"])
 config.zone_count = 1
 config.selected_theme_ids = ["green_hill"]
 game.run_configuration = config
 game.practice_mode = true
 add_child(game)
 var deadline := Time.get_ticks_msec() + 180000
 while (not game.started or game.resident.size() < 3 or game.library.busy or game.building != null) and Time.get_ticks_msec() < deadline:
  if not game.library.error.is_empty(): break
  await get_tree().process_frame
 var passed := game.started and game.resident.size() == 3
 if passed:
  for frame in 10: await get_tree().process_frame
  game._update_foreground_contribution()
  var legacy := "--foreground-contribution=legacy" in OS.get_cmdline_user_args()
  passed = game.active.visual.visible and game.foreground_contribution_enabled != legacy
  passed = passed and game.foreground_contributing == (3 if legacy else 2)
  passed = passed and game.view.msaa_3d == Viewport.MSAA_4X and game.score == 0
  print("PORTABLE_CONTRIBUTION | legacy=", legacy, " resident=", game.resident.size(), " contributing=", game.foreground_contributing, " passed=", passed)
 else: push_error("Portable Prototype failed: " + game.library.error)
 await game.prepare_to_close()
 game.queue_free()
 await get_tree().process_frame
 get_tree().quit(0 if passed else 1)
