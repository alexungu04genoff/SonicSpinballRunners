extends "res://tests/zone_play_survey.gd"
## Identical seed and movement policy for all characters. No score, meter, position
## or velocity injection. Specials activate only from ordinary earned charge.
## -- --seconds=180 --grid=0 --mode=2 [--green-hill] [--character=knuckles]

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var results: Array[Dictionary] = []
 var mode := option("--mode=", 2)
 var graphical := OS.get_cmdline_user_args().has("--green-hill")
 var only_character := ""
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--character="):
   only_character = argument.trim_prefix("--character=")
 for id: String in CharacterSpecials.CHARACTER_IDS:
  if not only_character.is_empty() and id != only_character:
   continue
  game = load("res://experiments/visual_lab/visual_lab.tscn" if graphical else "res://scenes/playground.tscn").instantiate()
  game.character_id = id
  game.generation_seed = option("--seed=", 18)
  game.generation_grid_mode = option("--grid=", 0)
  game.generation_difficulty = option("--difficulty=", TableGenerator.Difficulty.EASY)
  game.zone_difficulty_override = option("--difficulty=", -1)
  game.zone_enabled = mode == 2
  game.score_attack_enabled = mode == 1
  root.add_child(game)
  await frames(5)
  var result := {"character": id, "seed": game.generation_seed, "grid": game.generation_grid_mode, "mode": mode, "seconds": 0.0, "activations": 0, "homing_hits": 0, "first_ready": -1.0, "minimum_y": game.ball.position.y, "score": 0, "rings": 0, "balls": 0, "acts": 0, "complete": false, "escaped": false}
  game.specials.special_activated.connect(func(_id: String): result.activations += 1)
  game.specials.special_hit.connect(func(_target: Node2D, _multiplier: int): result.homing_hits += 1)
  result.glide_impacts = 0
  result.area_targets = 0
  result.area_rings = 0
  game.specials.glide_impact.connect(func(_body: Node2D, _at: Vector2, _normal: Vector2): result.glide_impacts += 1)
  game.specials.area_completed.connect(func(_source: String, targets: int, rings: int):
   result.area_targets += targets
   result.area_rings += rings)
  game.controls.virtual_enabled = true
  game.launch_ball()
  var cooldown := 0
  var captured := false
  for tick in option("--seconds=", 180) * 120:
   result.seconds = float(tick) / 120.0
   if game.zone.state == ZoneRun.State.DRAFT:
    game.choose_zone_chao(["spring", "ice", "magnet"][game.zone.active_act])
   if game.zone.state == ZoneRun.State.COMPLETE or game.score_attack.state == ScoreAttack.State.COMPLETE:
    result.complete = true
    break
   cooldown = maxi(0, cooldown - 1)
   game.controls.virtual_left = cooldown > 15
   game.controls.virtual_right = cooldown > 15
   if cooldown == 0 and game.ball.linear_velocity.y > 0:
    for paddle: PlaygroundFlipper in game.flippers:
     var near := Geometry2D.get_closest_point_to_segment(game.ball.position, paddle.position, paddle.position + Vector2.RIGHT.rotated(paddle.rest_angle()) * paddle.length)
     if game.ball.position.y < paddle.position.y + 15 and near.distance_to(game.ball.position) < 58:
      cooldown = 30
      game.controls.virtual_left = true
      game.controls.virtual_right = true
      break
   game.controls.virtual_steering = steering(tick, 2)
   if game.specials.ready_to_use() and game.specials.can_use():
    if result.first_ready < 0:
     result.first_ready = result.seconds
    if (id == "sonic" and is_instance_valid(game.specials.target)) or (id == "tails" and game.ball.linear_velocity.y > 300) or (id == "knuckles" and absf(game.ball.linear_velocity.x) > 100) or (id == "shadow" and blast_opportunities() >= 3):
     game.controls.special_requested.emit()
   await frames(1)
   if graphical and not captured and (game.specials.homing_remaining > 0 or game.specials.flight_remaining > 0) and DisplayServer.get_name() != "headless":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://test-results/character-play-%s.png" % id)
    captured = true
   result.minimum_y = minf(result.minimum_y, game.ball.position.y)
   var outside: bool = not game.ball.position.is_finite() or game.ball.position.x < -20 or game.ball.position.x > 820 or game.ball.position.y < -20
   # A drained ball remains physical below the open bottom during retry delay.
   # It may move sideways there; preserve that witness without calling it a live
   # side-wall escape. Non-finite motion or any above-bottom escape still fails.
   var retrying: bool = game.respawn_time >= 0 or game.ball._teleport_pending or game.ball.serve_pending
   if outside and game.ball.position.is_finite() and retrying and game.ball.position.y > game.layout.bounds.end.y:
    if not result.has("post_drain_departure"):
     result.post_drain_departure = {"position": game.ball.position, "seconds": result.seconds, "respawn_time": game.respawn_time}
    outside = false
   if outside and not result.escaped:
    result.escape_witness = {"position": game.ball.position, "velocity": game.ball.linear_velocity, "seconds": result.seconds, "respawn_time": game.respawn_time, "glide_remaining": game.specials.glide_remaining, "bounds": game.layout.bounds}
   result.escaped = result.escaped or outside
  result.score = game.score
  result.difficulty = game.generation_difficulty
  result.rings = game.rings_collected
  result.balls = game.ball_number
  result.acts = game.zone.completed_acts
  results.append(result)
  print("CHARACTER PLAY | ", JSON.stringify(result))
  paused = false
  game.free()
  await frames(4)
 var path := "res://test-results/character-play-seed%d-tier%d-mode%d-grid%d%s.json" % [option("--seed=", 18), option("--difficulty=", -1), mode, option("--grid=", 0), "-green-hill" if graphical else ""]
 if not only_character.is_empty():
  path = path.trim_suffix(".json") + "-" + only_character + ".json"
 var output := FileAccess.open(path, FileAccess.WRITE)
 output.store_string(JSON.stringify(results, " "))
 output.close()
 quit(1 if results.is_empty() or results.any(func(item: Dictionary): return item.escaped or item.activations == 0) else 0)

func blast_opportunities() -> int:
 var count := 0
 for chunk: TableChunk in game.chunks:
  for item: Dictionary in chunk.descriptors:
   var body := item.get("body") as Node2D
   if game.scoring_target_eligible(body) and game.ball.position.distance_to(body.global_position) <= game.specials.definition.blast_radius:
    count += 1
 for ring: Dictionary in game.ring_field.rings:
  if ring.active and game.ring_field.ring_eligible(ring) and game.ball.position.distance_to(ring.home) <= game.specials.definition.blast_radius:
   count += 1
 return count
