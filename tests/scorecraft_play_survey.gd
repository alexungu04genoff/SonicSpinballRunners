extends "res://tests/zone_play_survey.gd"
## Input-only comparison. No score, meter, position or velocity injection.
## -- --mode=0 --seconds=120 --case=-1 --grid=0 [--route] [--screenshots]
## Cases: bumper-seeking Sonic, ring-seeking Sonic, ring-seeking + Homing, Tails flight.

func aim_input(tick: int, style: int) -> float:
 if OS.get_cmdline_user_args().has("--route") or (game.zone_enabled and game.zone.active_act == 2 and game.zone.exit_unlocked and game.ball.position.y < 650):
  return steering(tick, 2)
 var target := Vector2.INF
 var distance := 420.0
 if style > 0 and game.ball.linear_velocity.y < -100:
  for ring: Dictionary in game.ring_field.rings:
   if ring.active and game.ring_field.ring_eligible(ring) and ring.position.y < game.ball.position.y:
    var cost: float = game.ball.position.distance_to(ring.position)
    if cost < distance:
     distance = cost
     target = ring.position
 else:
  for chunk: TableChunk in game.chunks:
   for item: Dictionary in chunk.descriptors:
    if item.has("body") and item.body.has_meta("bumper"):
     var position: Vector2 = item.body.global_position
     if game.zone_enabled and not game.zone.acts[game.zone.active_act].bounds.has_point(position):
      continue
     var cost: float = game.ball.position.distance_to(position)
     if cost < distance:
      distance = cost
      target = position
 return clampf((target.x - game.ball.position.x) / 100.0, -0.8, 0.8) if target.is_finite() else steering(tick, 2)

func run() -> void:
 var results: Array[Dictionary] = []
 var mode := option("--mode=", 0)
 var capture_requested := OS.get_cmdline_user_args().has("--screenshots")
 var styles: Array = [0, 1, 2, 3] if option("--case=", -1) < 0 else [option("--case=", 1)]
 for style: int in styles:
  for enabled: bool in [false, true]:
   if capture_requested and not enabled:
    continue
   game = load("res://experiments/visual_lab/visual_lab.tscn" if capture_requested else "res://scenes/playground.tscn").instantiate()
   game.generation_seed = option("--seed=", 18)
   game.generation_grid_mode = option("--grid=", 0)
   game.generation_difficulty = TableGenerator.Difficulty.EASY
   game.zone_enabled = mode == 2
   game.score_attack_enabled = mode == 1
   game.character_id = "tails" if style == 3 else "sonic"
   game.scorecraft_enabled = enabled
   game.scorecraft_config = game.scorecraft_config.duplicate(true)
   game.scorecraft_config.combo_window = float(option("--window-ms=", 3000)) / 1000.0
   root.add_child(game)
   await frames(5)
   var result := {"style": ["bumper-seeking", "ring-seeking", "homing", "flight"][style], "combos": enabled, "mode": mode, "grid": game.generation_grid_mode, "route_policy": OS.get_cmdline_user_args().has("--route"), "seconds": 0.0, "act_start": 0.0, "unlocks": [], "crossings": [], "awards": 0, "bumper_awards": 0, "ring_awards": 0, "repeat_bumpers": 0, "boosted_awards": 0, "baseline_points": 0, "combo_bonus": 0, "x3_seconds": 0.0, "chains": 0, "activations": 0, "homing_hits": 0, "score": 0, "rings": 0, "balls": 1, "acts": 0, "complete": false, "escaped": false}
   game.scorecraft.score_awarded.connect(func(info: Dictionary):
    result.awards += 1
    result.baseline_points += info.base + info.special_bonus
    result.combo_bonus += info.total - info.base - info.special_bonus
    result.boosted_awards += int(info.multiplier > 1)
    result.bumper_awards += int(info.kind == "bumper")
    result.ring_awards += int(info.kind == "ring")
    result.repeat_bumpers += int(enabled and info.kind == "bumper" and not info.fresh_bumper)
   )
   game.scorecraft.combo_changed.connect(func(chain: int, _multiplier: int): result.chains += int(chain == 1 and game.scorecraft.ring_progress == 0))
   game.specials.special_activated.connect(func(_id: String): result.activations += 1)
   game.specials.special_hit.connect(func(_target: Node2D, _multiplier: int): result.homing_hits += 1)
   game.zone.exit_opened.connect(func(act: int): result.unlocks.append({"act": act + 1, "run_seconds": result.seconds, "act_seconds": result.seconds - result.act_start, "score": game.zone.act_score}))
   game.zone.act_started.connect(func(_act: int): result.act_start = result.seconds)
   game.controls.virtual_enabled = true
   game.launch_ball()
   var cooldown := 0
   for tick in option("--seconds=", 120) * 120:
    result.seconds = float(tick) / 120.0
    if game.zone.state == ZoneRun.State.DRAFT:
     result.crossings.append({"act": game.zone.active_act + 1, "seconds": result.seconds, "score": game.zone.act_score})
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
    game.controls.virtual_steering = aim_input(tick, style)
    if style >= 2 and game.specials.ready_to_use() and game.specials.can_use():
     if (style == 2 and is_instance_valid(game.specials.target)) or (style == 3 and game.ball.linear_velocity.y > 300):
      game.controls.special_requested.emit()
    await frames(1)
    result.x3_seconds += 1.0 / 120.0 if game.scorecraft.multiplier == 3 else 0.0
    # A drained ball keeps moving below the open table during the respawn delay.
    # Only count side escapes at playfield height; non-finite/top escapes always fail.
    var beside_table: bool = game.ball.position.x < game.layout.bounds.position.x - 20 or game.ball.position.x > game.layout.bounds.end.x + 20
    var outside: bool = not game.ball.position.is_finite() or game.ball.position.y < game.layout.bounds.position.y - 20 or (beside_table and game.ball.position.y <= game.layout.bounds.end.y + PlaygroundBall.RADIUS)
    if outside and not result.escaped:
     result.escape_sample = {"seconds": result.seconds, "position": str(game.ball.position), "bounds": str(game.layout.bounds), "respawn": game.respawn_time}
    result.escaped = result.escaped or outside
    if capture_requested and game.scorecraft.multiplier == 3 and DisplayServer.get_name() != "headless":
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png("res://test-results/scorecraft-play.png")
     break
   result.score = game.score
   result.rings = game.rings_collected
   result.balls = game.ball_number
   result.acts = game.zone.completed_acts
   result.erase("act_start")
   results.append(result)
   print("SCORECRAFT PLAY | ", JSON.stringify(result))
   paused = false
   game.free()
   await frames(4)
 var suffix := "-route" if OS.get_cmdline_user_args().has("--route") else ""
 if capture_requested:
  suffix += "-capture"
 var path := "res://test-results/scorecraft-play-mode%d-case%d-grid%d%s.json" % [mode, option("--case=", -1), option("--grid=", 0), suffix]
 var output := FileAccess.open(path, FileAccess.WRITE)
 output.store_string(JSON.stringify(results, " "))
 output.close()
 quit(1 if results.any(func(item: Dictionary): return item.escaped) else 0)
