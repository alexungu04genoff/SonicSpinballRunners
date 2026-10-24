extends SceneTree
## Before/after mounting review using the ordinary Green Hill HUD and camera.
## No controlled drop, custom camera values, telemetry overlay or physics edits.
## --rendering-driver opengl3_angle --fixed-fps 120 --script res://tests/flipper_mount_capture.gd
## -- --phase=before (or --phase=after [--mirrors])
## -- --phase=perimeter --garden-only captures only Garden seeds 28 and 14 in
## test-results/target-garden-perimeter-review, preserving earlier comparisons.
## --phase=routes captures the same Garden-only views in target-garden-routes-review.

const CASES := [
 {"name": "normal-28-target-garden", "seed": 28, "difficulty": TableGenerator.Difficulty.NORMAL, "chunk": 7, "id": "zone_normal_target_garden", "mirrored": true, "opposite_seed": 14},
 {"name": "hard-24-bank-vault", "seed": 24, "difficulty": TableGenerator.Difficulty.HARD, "chunk": 7, "id": "zone_hard_bank_vault", "mirrored": false, "opposite_seed": 1},
 {"name": "hard-24-offset-climb", "seed": 24, "difficulty": TableGenerator.Difficulty.HARD, "chunk": 6, "id": "zone_hard_offset_climb", "mirrored": false, "opposite_seed": 2},
]

var failures := 0
var manifest: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func capture_cases(include_mirrors: bool, garden_only: bool) -> Array[Dictionary]:
 var cases: Array[Dictionary] = []
 for original: Dictionary in CASES:
  if not garden_only or original.id == "zone_normal_target_garden":
   cases.append(original)
 if not include_mirrors:
  return cases
 var originals: Array[Dictionary] = cases.duplicate()
 for original: Dictionary in originals:
  # Actual generated witnesses found during the mount review. Fixed fixtures
  # avoid searching the full catalogue every time screenshots are refreshed.
  var opposite: Dictionary = original.duplicate()
  opposite.seed = original.opposite_seed
  opposite.mirrored = not original.mirrored
  opposite.name = original.name + "-opposite-mirror-seed-%d" % opposite.seed
  cases.append(opposite)
 return cases

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Flipper mount review requires a graphical renderer.")
  quit(1)
  return
 var phase := "before"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--phase="):
   phase = argument.trim_prefix("--phase=")
 if phase not in ["before", "after", "perimeter", "routes"]:
  push_error("Mount review phase must be before, after, perimeter or routes.")
  quit(1)
  return
 var directory := "res://test-results/flipper-mount-review/"
 if phase == "perimeter":
  directory = "res://test-results/target-garden-perimeter-review/"
 elif phase == "routes":
  directory = "res://test-results/target-garden-routes-review/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 # The perimeter prototype is deliberately restricted to the single Garden room.
 var garden_only := phase in ["perimeter", "routes"] or OS.get_cmdline_user_args().has("--garden-only")
 var include_mirrors := phase in ["perimeter", "routes"] or OS.get_cmdline_user_args().has("--mirrors")
 for spec: Dictionary in capture_cases(include_mirrors, garden_only):
  var game: Node = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
  game.zone_enabled = true
  game.generation_seed = spec.seed
  game.zone_difficulty_override = spec.difficulty
  root.add_child(game)
  await frames(5)
  if not is_instance_valid(game.ball) or not game.layout.valid:
   failures += 1
   push_error("Mount review layout failed: " + spec.name)
   game.free()
   continue
  var data: ChunkData = game.chunks[spec.chunk].data
  if data.chunk_id != spec.id or data.mirrored != spec.mirrored:
   failures += 1
   push_error("Mount review room changed: " + data.chunk_id)
   game.free()
   continue
  # Use the ordinary follow-camera framing and untouched default tuning. Freeze
  # its position after aiming at the room; the ball remains at its ordinary serve.
  game.presentation.set_camera_preset(TablePresentation.CameraPreset.REAL_PINBALL)
  game.presentation.set_camera_follow(true)
  game.presentation.reset_camera(data.world_point(Vector2(400, 410)))
  game.presentation.camera_follow_enabled = false
  await frames(4)
  await RenderingServer.frame_post_draw
  var filename: String = "seed-%d.png" % spec.seed if phase in ["perimeter", "routes"] else phase + "-" + spec.name + ".png"
  var path: String = directory + filename
  var saved: Error = root.get_texture().get_image().save_png(path)
  if saved != OK:
   failures += 1
   push_error("Could not save " + path)
  else:
   print("FLIPPER MOUNT CAPTURE | ", path)
  var paddles: Array[Dictionary] = []
  for placement: Dictionary in data.world_flippers():
   paddles.append({"position": placement.position, "side": placement.side, "length": placement.length, "role": placement.get("role", "recovery")})
  manifest.append({"case": spec.name, "phase": phase, "seed": spec.seed, "room": data.chunk_id, "mirrored": data.mirrored, "signature": game.layout.signature, "camera_preset": game.presentation.camera_preset, "camera_settings": game.presentation.camera_settings.duplicate(), "camera_position": game.presentation.camera.position, "camera_rotation": game.presentation.camera.rotation, "viewport_size": game.view.size, "paddles": paddles, "image": path})
  game.free()
  await frames(3)
 var output := FileAccess.open(directory + phase + "-manifest.json", FileAccess.WRITE)
 output.store_string(JSON.stringify(manifest, " "))
 output.close()
 print("RESULT | Flipper mount review | ", manifest.size(), " captures | ", failures, " failures")
 quit(1 if failures else 0)
