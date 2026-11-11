extends SceneTree
## Fixed-theme continuous tour with the normal scheduler, lookahead and residency.
class FixedTheme extends "res://scripts/endless/endless_game.gd":
 var fixed_theme := "green_hill"
 var next_theme := ""
 func _next_planned_zone(documents: Array) -> Array[Dictionary]:
  var entries: Array[Dictionary] = super._next_planned_zone(documents)
  for entry: Dictionary in entries:
   entry.theme = next_theme if entry.zone % 2 == 1 and not next_theme.is_empty() else fixed_theme
   entry.atmosphere = {"id": "default", "values": {}}
  return entries
func _initialize() -> void: run.call_deferred()
func run() -> void:
 Engine.max_fps = 60
 var output := "res://test-results/stream-material-tour.json"
 var game := FixedTheme.new()
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
  if argument.begins_with("--theme="): game.fixed_theme = argument.trim_prefix("--theme=")
  if argument.begins_with("--next-theme="): game.next_theme = argument.trim_prefix("--next-theme=")
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 120000
 while not game.started and game.library.error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
 if not game.started: push_error(game.library.error); quit(1); return
 game.controls.input_blocked = true
 game.toggle_tour()
 game.tour_speed = 400.0
 var waiting := 0.0
 var frame_intervals: Array = []
 var max_variants: int = game.library.visuals.size()
 var max_themes: int = game.library.themes.size()
 var previous := Time.get_ticks_usec()
 while game.active_sequence < 3 and Time.get_ticks_msec() < deadline:
  await process_frame
  var now := Time.get_ticks_usec()
  frame_intervals.append((now-previous)/1000.0)
  max_variants = maxi(max_variants,game.library.visuals.size())
  max_themes = maxi(max_themes,game.library.themes.size())
  if game.loading_boundary: waiting += (now-previous)/1000.0
  previous = now
 var report := {"theme": game.fixed_theme, "seed": game.run_seed, "tour_speed": game.tour_speed, "atomic_attachment": "--profile-atomic-attachment" in OS.get_cmdline_user_args(), "engine": Engine.get_version_info().string, "act_sha256": FileAccess.get_sha256("res://scripts/endless/streamed_act.gd"), "sequence": game.active_sequence, "boundary_wait_ms": waiting, "fallbacks": game.library.fallback_builds,"max_build_ms": game.max_build_ms, "cpu": game.library.profile_cpu.duplicate(true)}
 report["cached_material_uniforms"] = "--profile-uncached-materials" not in OS.get_cmdline_user_args()
 report["legacy_material_copies"] = "--profile-redundant-material-copies" in OS.get_cmdline_user_args()
 report["chunked_materials"] = "--profile-whole-material-attachment" not in OS.get_cmdline_user_args() and not report.atomic_attachment
 report["next_theme"] = game.next_theme
 report["frame_intervals"] = preload("res://tests/render_profile_support.gd").timing(frame_intervals)
 report["max_cached_variants"] = max_variants
 report["max_cached_themes"] = max_themes
 report["game_sha256"] = FileAccess.get_sha256("res://scripts/endless/endless_game.gd")
 report["bindings_sha256"] = FileAccess.get_sha256("res://scripts/atmosphere/material_bindings.gd")
 print("STREAM_BUDGET_TOUR | ",JSON.stringify(report))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
 var file := FileAccess.open(output,FileAccess.WRITE)
 if file == null:
  push_error("Cannot write tour report: " + error_string(FileAccess.get_open_error()))
 else:
  file.store_string(JSON.stringify(report,"  "))
 var within_limits: bool = max_variants <= game.library.MAX_VARIANTS and max_themes <= game.library.MAX_THEMES
 await game.prepare_to_close()
 game.free()
 quit(0 if file != null and report.sequence >= 3 and waiting == 0.0 and report.fallbacks == 0 and within_limits else 1)
