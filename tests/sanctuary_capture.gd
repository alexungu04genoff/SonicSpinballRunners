extends SceneTree
## Matched captures of the real main engine, with optional local authored files.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Filter = preload("res://scripts/retro/retro_filter.gd")
const OUTPUT := "res://test-results/sanctuary-review"
var game: Node
var failures := 0
var manifest: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func frames(count := 8) -> void:
 for i in count: await process_frame

func capture(label: String, framing: String) -> void:
 await frames(10)
 await RenderingServer.frame_post_draw
 var path := OUTPUT + "/" + label + ".png"
 if root.get_texture().get_image().save_png(path) != OK: failures += 1
 manifest.append({"path": path, "theme": game.theme_id, "act": game.authored_act_path, "fingerprint": game.authored_document.fingerprint(), "camera": str(game.presentation.camera.global_transform), "ball": str(game.ball.position), "filter": game.retro_filter.display_name(), "framing": framing, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
 print("CAPTURE | ", path)

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Captures require a graphical renderer.")
  quit(1)
  return
 root.size = Vector2i(1440, 1000)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var acts := ["res://data/acts/decor_terraces.tres", "res://data/acts/decor_curve_relay.tres"]
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--act="): acts = [argument.trim_prefix("--act=")]
 game = Game.new()
 game.authored_act_path = acts[0]
 root.add_child(game)
 await frames(20)
 paused = true
 for path: String in acts:
  if not game.request_authored_act(path):
   failures += 1
   continue
  for i in 120:
   await frames(1)
   if not game.loading_act: break
  if game.loading_act or not game.last_source_error.is_empty():
   failures += 1
   continue
  var original := FileAccess.get_file_as_bytes(path)
  var stem := path.get_file().get_basename().to_snake_case().replace(" ", "_")
  for framing: String in ["overview", "follow"]:
   game.presentation.set_camera_follow(framing == "follow")
   game.retro_filter.set_preset(Filter.Preset.OFF)
   for theme_id: String in Themes.IDS:
    if not game.set_theme(theme_id): failures += 1
    await capture(stem + "-" + theme_id + "-" + framing + "-off", framing)
   game.set_theme("sky_sanctuary")
   # Exactly the preferred production stack, including VHS.
   game.retro_filter.set_effects([Filter.Preset.N64, Filter.Preset.VHS, Filter.Preset.CRT])
   await capture(stem + "-sky_sanctuary-" + framing + "-retro", framing)
  if OS.get_cmdline_user_args().has("--city-study"):
   game.retro_filter.set_preset(Filter.Preset.OFF)
   game.presentation.set_camera_follow(false)
   var center: Vector3 = game.presentation.map_point(game.presentation.table_bounds.get_center())
   game.presentation.camera.position = center + Vector3(10, 6.5, 14)
   game.presentation.camera.look_at(center + Vector3(0, -0.8, -5))
   await capture(stem + "-sky_sanctuary-city-study", "city study; review camera only")
  if original != FileAccess.get_file_as_bytes(path): failures += 1
 # Each normal comparison group must share camera, ball and Act state.
 for entry: Dictionary in manifest:
  if entry.framing not in ["overview", "follow"]: continue
  for other: Dictionary in manifest:
   if entry.act != other.act or entry.framing != other.framing: continue
   if entry.camera != other.camera or entry.ball != other.ball or entry.fingerprint != other.fingerprint:
    push_error("Comparison changed camera, ball or authored layout")
    failures += 1
 var file := FileAccess.open(OUTPUT + "/manifest-" + str(acts[0].get_file().get_basename()).replace(" ", "_") + ".json", FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest, "  "))
 file.close()
 game.free()
 print("RESULT | Sanctuary captures | %d captures | %d failures" % [manifest.size(), failures])
 quit(0 if failures == 0 else 1)
