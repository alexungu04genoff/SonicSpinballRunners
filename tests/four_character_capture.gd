extends SceneTree
## Same authored Zone room and falling approach for all four characters.
## Explicit initial position/velocity and full meter; only ordinary input follows.
var game: Node
var failures := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for index in count:
  await physics_frame
  await process_frame

func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 var error := root.get_texture().get_image().save_png("res://test-results/four-character-review/" + name + ".png")
 if error != OK:
  failures += 1

func run() -> void:
 if DisplayServer.get_name() == "headless":
  quit(1)
  return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/four-character-review"))
 for id: String in CharacterSpecials.CHARACTER_IDS:
  game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
  game.character_id = id
  game.zone_enabled = true
  game.generation_seed = 18
  root.add_child(game)
  await frames(6)
  var data: ChunkData = game.chunks[7].data
  var start := data.world_point(Vector2(500, 350))
  game.ball.teleport_to(start, Vector2(0, 350))
  game.ring_field.previous_ball_position = start
  game.presentation.set_camera_preset(TablePresentation.CameraPreset.REAL_PINBALL)
  game.presentation.reset_camera(data.world_point(Vector2(400, 350)))
  game.presentation.camera_follow_enabled = false
  game.controls.virtual_enabled = true
  game.controls.virtual_steering = -1
  await frames(3)
  game.special_meter = 100
  var result := {"character": id, "start": start, "initial_velocity": Vector2(0, 350), "events": [], "score": 0, "rings": 0, "meter": 0.0, "minimum_y": game.ball.position.y}
  game.specials.special_hit.connect(func(_body: Node2D, _multiplier: int): result.events.append("homing_hit"))
  game.specials.glide_impact.connect(func(_body: Node2D, _position: Vector2, _normal: Vector2): result.events.append("glide_impact"))
  game.specials.area_completed.connect(func(source: String, targets: int, rings: int): result.events.append({"source": source, "targets": targets, "rings": rings}))
  game.controls.special_requested.emit()
  if game.special_meter >= 100:
   failures += 1
  await frames(1)
  await capture(id + "-activation")
  var saved := false
  for tick in 220:
   await frames(1)
   result.minimum_y = minf(result.minimum_y, game.ball.position.y)
   if not saved and (not result.events.is_empty() or (id == "tails" and tick == 45)):
    await frames(2)
    await capture(id + "-outcome")
    saved = true
  result.score = game.score
  result.rings = game.rings_collected
  result.meter = game.special_meter
  result.final_position = game.ball.position
  result.feedback = game.specials.feedback
  results.append(result)
  print("CHARACTER CAPTURE | ", JSON.stringify(result))
  game.free()
  await frames(4)
 var file := FileAccess.open("res://test-results/four-character-review/results.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(results, " "))
 print("RESULT | Four character captures | %d failures" % failures)
 quit(1 if failures else 0)
