extends SceneTree
const Run = preload("res://scripts/prototype/zone_run.gd")
class ProfileRun extends "res://scripts/prototype/zone_run.gd":
 func _default_run_seed() -> int: return 18
## Real disk-loaded three-Act CPU profile; --profile-atomic-attachment is the A/B control.
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var output := "res://test-results/act-attachment-profile.json"
 var theme := "green_hill"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
  if argument.begins_with("--theme="): theme = argument.trim_prefix("--theme=")
 if "--profile-stages" not in OS.get_cmdline_user_args():
  push_error("Pass -- --profile-stages [--theme=<id>] [--profile-atomic-attachment].")
  quit(1)
  return
 if theme not in Run.RunPlan.Configuration.Registry.IDS:
  push_error("Unknown profile theme: " + theme)
  quit(1)
  return
 var game := ProfileRun.new()
 game.practice_mode = true
 var config := Run.RunPlan.Configuration.new(["res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/Reverse C Spring.tres", "res://data/acts/Authored/Secret Entry.tres"])
 config.zone_count = 1
 config.selected_theme_ids = [theme]
 game.run_configuration = config
 root.add_child(game)
 var began := Time.get_ticks_usec()
 var frames := 0
 var deadline := Time.get_ticks_msec() + 120000
 while (not game.started or game.resident.size() < 3 or game.building != null or game.library.busy) and Time.get_ticks_msec() < deadline:
  if not game.library.error.is_empty(): break
  frames += 1
  await process_frame
 var report := {"theme": theme, "ready": game.started and game.resident.size() == 3 and game.building == null and not game.library.busy and game.library.error.is_empty(), "error": game.library.error, "cpu": game.library.profile_cpu.duplicate(true), "fallbacks": game.library.fallback_builds, "events": game.library.profile_events.duplicate(true)}
 report["wall_ms"] = (Time.get_ticks_usec() - began)/1000.0
 report["preparation_frames"] = frames
 report["atomic_attachment"] = "--profile-atomic-attachment" in OS.get_cmdline_user_args()
 report["cached_material_uniforms"] = "--profile-uncached-materials" not in OS.get_cmdline_user_args()
 report["legacy_material_copies"] = "--profile-redundant-material-copies" in OS.get_cmdline_user_args()
 report["chunked_materials"] = "--profile-whole-material-attachment" not in OS.get_cmdline_user_args() and not report.atomic_attachment
 report["game_sha256"] = FileAccess.get_sha256("res://scripts/endless/endless_game.gd")
 report["seed"] = game.run_seed
 report["configuration"] = config.snapshot()
 report["engine"] = Engine.get_version_info().string
 report["headless"] = DisplayServer.get_name() == "headless"
 report["scope"] = "CPU preparation/attachment stages; includes startup and does not measure driver compilation or Windows FPS."
 report["runtime_sha256"] = FileAccess.get_sha256("res://scripts/atmosphere/runtime.gd")
 report["bindings_sha256"] = FileAccess.get_sha256("res://scripts/atmosphere/material_bindings.gd")
 report["act_sha256"] = FileAccess.get_sha256("res://scripts/endless/streamed_act.gd")
 print("ACT_ATTACHMENT_CPU | ",JSON.stringify(report.cpu))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
 var file := FileAccess.open(output,FileAccess.WRITE)
 if file == null:
  push_error("Cannot write attachment profile: " + error_string(FileAccess.get_open_error()))
  await game.prepare_to_close()
  game.free()
  quit(1)
  return
 file.store_string(JSON.stringify(report,"  "))
 await game.prepare_to_close()
 game.free()
 quit(0 if report.ready and report.fallbacks == 0 else 1)
