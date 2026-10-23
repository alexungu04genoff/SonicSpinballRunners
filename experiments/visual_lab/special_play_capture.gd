extends "res://tests/zone_play_survey.gd"
## Input-only gameplay witness: earned meter, ordinary launch/flippers/steering,
## and the player's Special request. No score, meter or trajectory injection.
## --fixed-fps 120 --script res://experiments/visual_lab/special_play_capture.gd
## -- --seconds=180 [--seed=18] [--grid=0] [--mode=0] [--character=sonic|tails] [--screenshots]
const CAPTURE_DIR := "res://experiments/visual_lab/captures/specials"
var capture_enabled := false
var capture_label: Label
var capture_directory := ""
var capture_frames := {"sonic": 0, "tails": 0}

func make_label() -> void:
 var overlay := CanvasLayer.new()
 overlay.layer = 30
 root.add_child(overlay)
 capture_label = Label.new()
 capture_label.position = Vector2(260, 32)
 capture_label.add_theme_font_size_override("font_size", 17)
 capture_label.add_theme_color_override("font_color", Color.WHITE)
 capture_label.add_theme_color_override("font_shadow_color", Color("071e26"))
 capture_label.add_theme_constant_override("shadow_offset_x", 2)
 capture_label.add_theme_constant_override("shadow_offset_y", 2)
 overlay.add_child(capture_label)

func capture(file_name: String, description: String, seconds: float) -> void:
 if not capture_enabled:
  return
 capture_label.text = "INPUT-ONLY PLAY · %s\n%.2fs · earned meter · %s" % [description, seconds, game.character.pose.to_upper()]
 await RenderingServer.frame_post_draw
 var result := root.get_texture().get_image().save_png(capture_directory.path_join(file_name + ".png"))
 if result != OK:
  push_error("Capture failed: " + file_name + " / " + error_string(result))

func run() -> void:
 capture_enabled = OS.get_cmdline_user_args().has("--screenshots") and DisplayServer.get_name() != "headless"
 capture_directory = ProjectSettings.globalize_path(CAPTURE_DIR)
 DirAccess.make_dir_recursive_absolute(capture_directory)
 var ignore := FileAccess.open(capture_directory.path_join(".gdignore"), FileAccess.WRITE)
 if ignore != null:
  ignore.close()
 if capture_enabled:
  make_label()
 var results: Array[Dictionary] = []
 var mode := option("--mode=", 0)
 var requested_character := "both"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--character="):
   requested_character = argument.trim_prefix("--character=")
 for id: String in ["sonic", "tails"]:
  if requested_character != "both" and requested_character != id:
   continue
  game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
  game.character_id = id
  game.generation_seed = option("--seed=", 18)
  game.generation_grid_mode = option("--grid=", 0)
  game.generation_difficulty = TableGenerator.Difficulty.EASY
  game.zone_enabled = mode == 2
  game.score_attack_enabled = mode == 1
  root.add_child(game)
  await frames(5)
  var result := {"character": id, "seed": game.generation_seed, "grid": game.generation_grid_mode, "mode": mode, "seconds": 0.0, "activations": 0, "homing_hits": 0, "first_ready": -1.0, "homing_seen": false, "impact_seen": false, "flight_seen": false, "flight_phase_b_seen": false, "return_seen": false, "score": 0, "rings": 0, "balls": 0, "escaped": false, "sequence_fps": 30, "bookmarks": []}
  game.specials.special_activated.connect(func(_id: String): result.activations += 1)
  game.specials.special_hit.connect(func(_target: Node2D, _multiplier: int): result.homing_hits += 1)
  game.controls.virtual_enabled = true
  game.launch_ball()
  var cooldown := 0
  var special_start := -1
  var special_ended := false
  var sequence_end := -1
  var phase_a_tick := -1
  for tick in option("--seconds=", 180) * 120:
   result.seconds = float(tick) / 120.0
   if game.zone.state == ZoneRun.State.DRAFT:
    game.choose_zone_chao(["spring", "ice", "magnet"][game.zone.active_act])
   if game.zone.state == ZoneRun.State.COMPLETE or game.score_attack.state == ScoreAttack.State.COMPLETE:
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
    if (id == "sonic" and is_instance_valid(game.specials.target)) or (id == "tails" and game.ball.linear_velocity.y > 300):
     game.controls.special_requested.emit()
   await frames(1)
   var actor: Node3D = game.character
   var active: bool = actor.state in [actor.State.HOMING, actor.State.FLIGHT]
   if active and special_start < 0:
    special_start = tick
    sequence_end = tick + 300
    result.bookmarks.append({"event": "activation", "seconds": result.seconds, "position": str(game.ball.position), "meter": game.special_meter})
   if actor.state == actor.State.HOMING and not result.homing_seen and actor.uncurl_amount > 0.7 and actor._pose_time >= 0.07:
    result.homing_seen = true
    result.bookmarks.append({"event": "homing_pose", "seconds": result.seconds})
    await capture("sonic_homing", "SONIC / target-facing burst", result.seconds)
   if actor.state == actor.State.IMPACT and not result.impact_seen and actor._pose_time >= 0.07:
    result.impact_seen = true
    result.bookmarks.append({"event": "physical_impact", "seconds": result.seconds, "score": game.score})
    await capture("sonic_impact", "SONIC / actual homing impact", result.seconds)
   if actor.state == actor.State.FLIGHT and special_start >= 0:
    if tick - special_start >= 36 and not result.flight_seen:
     result.flight_seen = true
     phase_a_tick = tick
     result.bookmarks.append({"event": "flight_phase_a", "seconds": result.seconds})
     await capture("tails_flight_a", "TAILS / flight rotor phase A", result.seconds)
    elif phase_a_tick >= 0 and tick - phase_a_tick >= 15 and not result.flight_phase_b_seen:
     result.flight_phase_b_seen = true
     result.bookmarks.append({"event": "flight_phase_b", "seconds": result.seconds})
     await capture("tails_flight_b", "TAILS / flight rotor phase B", result.seconds)
   if special_start >= 0 and game.specials.homing_remaining <= 0 and game.specials.flight_remaining <= 0:
    special_ended = true
   var presentation_seen: bool = result.impact_seen if id == "sonic" else result.flight_phase_b_seen
   if special_ended and presentation_seen and actor.state == actor.State.SPIN and actor.uncurl_amount < 0.001 and not result.return_seen:
    result.return_seen = true
    result.bookmarks.append({"event": "return_to_spin", "seconds": result.seconds})
    sequence_end = mini(sequence_end, tick + 24)
    await capture(id + "_return_to_spin", id.to_upper() + " / returned to spin", result.seconds)
   if capture_enabled and special_start >= 0 and tick <= sequence_end and (tick - special_start) % 4 == 0:
    await capture("%s_sequence_%04d" % [id, capture_frames[id]], id.to_upper() + " / live special sequence", result.seconds)
    capture_frames[id] += 1
   result.escaped = result.escaped or not game.ball.position.is_finite() or game.ball.position.x < -20 or game.ball.position.x > 820 or game.ball.position.y < -20
   if result.return_seen and tick >= sequence_end:
    break
   # A missed homing window may be followed by a later earned activation.
   if special_start >= 0 and tick > sequence_end and not presentation_seen:
    special_start = -1
    special_ended = false
  result.score = game.score
  result.rings = game.rings_collected
  result.balls = game.ball_number
  result.sequence_frames = capture_frames[id]
  results.append(result)
  print("SPECIAL_PLAY | ", JSON.stringify(result))
  paused = false
  game.free()
  await frames(4)
 var output := FileAccess.open(capture_directory.path_join("input_only_play_%s_mode%d.json" % [requested_character, mode]), FileAccess.WRITE)
 output.store_string(JSON.stringify(results, " "))
 output.close()
 var failed := results.is_empty() or results.any(func(item: Dictionary): return item.escaped or not item.return_seen or (item.character == "sonic" and (not item.homing_seen or item.homing_hits == 0)) or (item.character == "tails" and not item.flight_phase_b_seen))
 quit(1 if failed else 0)
