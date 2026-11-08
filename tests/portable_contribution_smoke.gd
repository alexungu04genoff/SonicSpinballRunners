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
  if "--pixel-controls" in OS.get_cmdline_user_args():
   var options := preload("res://scripts/rendering_options.gd")
   var controls: Node
   for child: Node in game.get_children():
    if child.get_script() == load("res://scripts/pixel_profile_controls.gd"): controls = child
   passed = passed and controls != null
   if controls != null:
    game.set_process(false)
    var layout: Vector2i = game.view.size
    var key := InputEventKey.new()
    key.pressed = true
    key.keycode = KEY_F6
    for expected: int in [0, 2, 4]:
     controls._unhandled_key_input(key)
     passed = passed and options.pixel_profile().msaa == expected
     passed = passed and game.view.msaa_3d == {0:0, 2:1, 4:2}[expected]
     for backdrop: Dictionary in game.backgrounds.values():
      passed = passed and backdrop.layer.view.msaa_3d == game.view.msaa_3d
    key.keycode = KEY_F7
    for expected: int in [75, 85, 100]:
     controls._unhandled_key_input(key)
     passed = passed and is_equal_approx(game.view.scaling_3d_scale, expected / 100.0)
     passed = passed and game.view.size == layout and game._composite_view.scaling_3d_scale == 1.0
    print("PORTABLE_PIXELS | live_keys=F6/F7 defaults_restored=", options.pixel_profile(), " passed=", passed)
 else: push_error("Portable Prototype failed: " + game.library.error)
 await game.prepare_to_close()
 game.queue_free()
 await get_tree().process_frame
 get_tree().quit(0 if passed else 1)
