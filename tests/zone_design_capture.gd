extends "res://tests/zone_play_survey.gd"
## Rendered comparison fixtures, not claims of input-only play success.
## Run graphically with --rendering-driver opengl3_angle; -- --baseline keeps
## reference images separate from the final design review captures.

var capture_rows: Array[Dictionary] = []
var capture_failures := 0
var capture_prefix := "zone-design"

func capture(label: String) -> void:
 await frames(4)
 await RenderingServer.frame_post_draw
 var path := "res://test-results/%s-%s.png" % [capture_prefix, label]
 var error: Error = game.view.get_texture().get_image().save_png(path)
 if error != OK:
  capture_failures += 1
  push_error("Capture failed: %s (%s)" % [path, error_string(error)])
 else:
  print("ZONE DESIGN CAPTURE | ", path)

func build_layout(seed_value: int, difficulty: int, is_zone: bool) -> bool:
 paused = true
 var accepted: bool = game.request_generation(seed_value, difficulty, 0, {"zone": is_zone, "zone_difficulty": difficulty, "enabled": false})
 await frames(8)
 if not accepted or game.generation_seed != seed_value or game.zone_enabled != is_zone or game.generation_difficulty != difficulty:
  capture_failures += 1
  push_error("Requested comparison layout failed: %s" % game.status_message)
  return false
 # Apply the ordinary deferred serve reset before freezing the review image.
 # Switching from three chunks to nine moves the serve in physics space.
 paused = false
 await frames(2)
 paused = true
 if not game.ball.serve_pending or game.ball.position.distance_to(game.ball.serve_position) > 0.1:
  capture_failures += 1
  push_error("Comparison capture did not settle at its generated serve marker.")
  return false
 return true

func record_layout(label: String) -> void:
 var row := {"label": label, "seed": game.generation_seed, "difficulty": game.generation_difficulty, "zone": game.zone_enabled, "signature": game.layout.signature, "chunks": [], "flippers": []}
 for chunk: TableChunk in game.chunks:
  var paddles: Array[Dictionary] = []
  for paddle: Dictionary in chunk.data.world_flippers():
   paddles.append({"position": str(paddle.position), "role": paddle.get("role", "recovery"), "shot_target": str(paddle.get("shot_target", Vector2.INF))})
  row.chunks.append({"id": chunk.data.chunk_id, "mirror": chunk.data.mirrored, "shift": chunk.data.horizontal_shift_cells, "role": chunk.data.zone_role, "shot_description": chunk.data.shot_description, "paddles": paddles})
 if game.layout.has("composition"):
  row.composition = game.layout.composition
 for paddle: PlaygroundFlipper in game.flippers:
  row.flippers.append({"position": str(paddle.position), "side": paddle.side, "length": paddle.length, "enabled": paddle.enabled})
 capture_rows.append(row)

func overview(label: String) -> void:
 game.view_container.stretch = false
 game.view.size = Vector2i(640, 4800 if game.zone_enabled else 1800)
 game.presentation.set_camera_follow(false)
 game.presentation.set_camera_preset(TablePresentation.CameraPreset.TOP_DOWN)
 record_layout(label)
 await capture(label)

func room_closeup(chunk_index: int, label: String) -> void:
 game.view_container.stretch = false
 game.view.size = Vector2i(1280, 1000)
 game.presentation.set_camera_preset(TablePresentation.CameraPreset.REAL_PINBALL)
 game.presentation.set_camera_follow(true)
 game.presentation.reset_camera(game.chunks[chunk_index].data.world_point(Vector2(400, 410)))
 await capture(label)

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Zone design capture requires a graphical renderer.")
  quit(1)
  return
 if OS.get_cmdline_user_args().has("--baseline"):
  capture_prefix += "-baseline"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.generation_seed = 24
 game.generation_difficulty = TableGenerator.Difficulty.HARD
 root.add_child(game)
 await frames(5)
 var comparisons := [
  [24, TableGenerator.Difficulty.HARD, false, "hard-free-play-24"],
  [24, TableGenerator.Difficulty.HARD, true, "hard-zone-24"],
  [29, TableGenerator.Difficulty.NORMAL, false, "normal-free-play-29"],
  [28, TableGenerator.Difficulty.NORMAL, true, "normal-zone-28"],
  [18, TableGenerator.Difficulty.NORMAL, true, "normal-zone-18"],
  [41, TableGenerator.Difficulty.NORMAL, true, "normal-zone-41"],
  [18, TableGenerator.Difficulty.HARD, true, "hard-zone-18"],
  [41, TableGenerator.Difficulty.HARD, true, "hard-zone-41"],
  [29, TableGenerator.Difficulty.HARD, true, "hard-zone-29"],
 ]
 var only := ""
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--only="):
   only = argument.trim_prefix("--only=")
 for comparison: Array in comparisons:
  if not only.is_empty() and comparison[3] != only:
   continue
  if not await build_layout(comparison[0], comparison[1], comparison[2]):
   continue
  await overview(comparison[3])
  if comparison[3] in ["hard-zone-24", "normal-zone-28"]:
   await room_closeup(7, comparison[3] + "-interaction")
   await room_closeup(6, comparison[3] + "-approach")
   await room_closeup(8, comparison[3] + "-recovery")
 var manifest := FileAccess.open("res://test-results/%s%s-manifest.json" % [capture_prefix, "-" + only if not only.is_empty() else ""], FileAccess.WRITE)
 manifest.store_string(JSON.stringify(capture_rows, " "))
 manifest.close()
 print("RESULT | Zone design captures | %d comparisons | %d failures" % [capture_rows.size(), capture_failures])
 paused = false
 game.free()
 await frames(3)
 quit(0 if capture_failures == 0 else 1)
