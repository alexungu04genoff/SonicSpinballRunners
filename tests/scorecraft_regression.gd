extends "res://tests/score_attack_regression.gd"
## Formula cases plus real contact/collection and shared mode lifecycle fixtures.

func bumper(at: Vector2) -> StaticBody2D:
 var body := StaticBody2D.new()
 body.position = at
 body.set_meta("bumper", true)
 var shape := CircleShape2D.new()
 shape.radius = 30
 var collision := CollisionShape2D.new()
 collision.shape = shape
 body.add_child(collision)
 game.world.add_child(body)
 game.chunks[0].descriptors.append({"kind": "bumper", "body": body})
 var visual := Node3D.new()
 game.presentation.add_child(visual)
 game.presentation.bumper_visuals[body.get_instance_id()] = visual
 return body

func active_bumper() -> Node2D:
 for chunk: TableChunk in game.chunks:
  for item: Dictionary in chunk.descriptors:
   if item.has("body") and item.body.has_meta("bumper") and (not game.zone_enabled or game.zone.acts[game.zone.active_act].bounds.has_point(item.body.global_position)):
    return item.body
 return null

func run() -> void:
 var combo := Scorecraft.new()
 combo.config = ScorecraftConfig.new()
 root.add_child(combo)
 combo.set_physics_process(false)
 var a := Node.new()
 var b := Node.new()
 var c := Node.new()
 check(combo.award_ring() == 25 and combo.chain == 0, "Rings alone cannot start or grow a combo")
 check(combo.award_bumper(a) == 100 and combo.chain == 1 and combo.multiplier == 1, "First bumper starts at x1")
 combo._physics_process(0.4)
 var time_left := combo.remaining
 check(combo.award_bumper(a) == 100 and combo.remaining == time_left and combo.chain == 1, "Repeated bumper pays base and cannot refresh")
 check(combo.award_ring() == 25 and combo.award_ring() == 25 and combo.remaining == time_left, "Partial ring sequence does not refresh the window")
 check(combo.award_ring() == 50 and combo.multiplier == 2 and combo.remaining == 3.0, "Third ring advances to x2 and refreshes")
 combo._physics_process(0.3)
 time_left = combo.remaining
 check(combo.award_ring() == 50 and combo.remaining == time_left and combo.chain == 2, "Extra rings pay current multiplier without automatic refresh")
 check(combo.award_bumper(a) == 100 and not combo.ring_link_available and combo.remaining == time_left, "Ring collection cannot make an old bumper fresh again")
 check(combo.award_bumper(b) == 300 and combo.multiplier == 3 and combo.ring_link_available, "Different bumper advances to capped x3")
 combo.award_ring()
 combo.award_ring()
 check(combo.award_ring() == 75 and combo.multiplier == 3 and combo.chain == 4, "Further valid links stay capped")
 combo._physics_process(0.25)
 time_left = combo.remaining
 check(combo.award_bumper(a) == 100 and combo.award_bumper(b) == 100 and combo.remaining == time_left, "Alternating two already-used bumpers cannot sustain a chain")
 check(combo.award_rack() == 500 and combo.remaining == time_left and combo.chain == 4, "Rack award stays fixed and cannot extend combos")
 check(combo.award_bumper(c, 5) == 700 and combo.chain == 0 and combo.last_award.special_bonus == 400, "Homing finisher is 100x3 + 400, never 100x5x3")
 check(combo.award_bumper(a, 5) == 500 and combo.chain == 0, "Unchained Homing keeps its original 500 points")
 combo.award_bumper(a)
 combo.award_bumper(b)
 check(combo.award_bumper(a, 5) == 500 and combo.chain == 0, "Repeated-target Homing retains special bonus but gets no combo multiplier")
 combo.award_bumper(a)
 combo._physics_process(3.0)
 check(combo.chain == 0 and combo.multiplier == 1 and combo.award_bumper(a) == 100, "Expiry clears target history and restarts at x1")
 check(combo.award_bumper(b) == 200 and combo.award_bumper(c) == 200 and combo.multiplier == 2, "Bumper-only chains cannot reach x3 without a ring link")
 combo.award_ring()
 combo.award_ring()
 check(combo.award_ring() == 75 and combo.multiplier == 3, "Mixing three rings into a bumper chain earns the top tier")
 combo.reset("Fixture")
 combo.config.combo_window = 1.2
 combo.config.rings_per_link = 2
 combo.config.multiplier_cap = 2
 combo.award_bumper(a)
 combo.award_ring()
 check(combo.award_ring() == 50 and combo.remaining == 1.2 and combo.award_bumper(b) == 200, "Window, ring threshold and cap are configurable")
 combo.reset("Baseline")
 combo.enabled = false
 check(combo.award_bumper(a) == 100 and combo.award_bumper(b) == 100 and combo.award_ring() == 25 and combo.award_bumper(c, 5) == 500 and combo.chain == 0, "Baseline mode exactly preserves original awards")
 combo.free()
 a.free()
 b.free()
 c.free()

 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.generation_seed = 18
 root.add_child(game)
 await frames(5)
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 var first := bumper(Vector2(2200, 2000))
 var second := bumper(Vector2(3200, 2000))
 game.ball.teleport_to(Vector2(2000, 2000), Vector2(800, -70))
 await frames(45)
 check(game.score == 100 and game.scorecraft.chain == 1, "Actual 2D bumper contact starts the shared combo and score")
 game.ball.teleport_to(Vector2(3000, 2000), Vector2.ZERO)
 await frames(3)
 game.ring_field.previous_ball_position = game.ball.position
 for i in 3:
  game.ring_field.rings[i].home = game.ball.position + Vector2(i * 10, 0)
  game.ring_field.rings[i].position = game.ring_field.rings[i].home
  game.ring_field.rings[i].active = true
 game.ring_field._physics_process(0.0)
 check(game.score == 200 and game.rings_collected == 3 and game.special_meter == 17 and game.scorecraft.multiplier == 2, "Actual ring pickup gives 25+25+50 while meter remains ordinary +5")
 var preserved_time: float = game.scorecraft.remaining
 paused = true
 await frames(20)
 check(game.scorecraft.remaining == preserved_time, "Pause freezes the combo even under Green Hill's always-processing UI")
 paused = false
 game.special_meter = 100
 var before: int = game.score
 check(game.specials.activate(), "Homing activates through the normal ability path")
 await frames(50)
 check(game.score - before == 700 and game.scorecraft.chain == 0 and game.special_meter == 2, "Real Homing contact finishes x3 once without extra meter multiplication")
 first.free()
 second.free()
 paused = true
 var hud: ScorecraftPanel = game.debug_panel.challenge_panel.character_panel.combo_hud
 hud.toggle.button_pressed = false
 await frames(8)
 check(not game.scorecraft_enabled and not game.scorecraft.enabled and game.score == 0 and game.generation_seed == 18, "Baseline HUD toggle replays the same seed with clean score")
 hud.toggle.button_pressed = true
 await frames(8)
 check(game.scorecraft.enabled and game.scorecraft.chain == 0 and game.scorecraft.last_award.is_empty(), "Re-enabling combos leaves no stale timer or award feedback")
 for mode in [1, 2]:
  check(game.request_generation(18, -1, -1, {"enabled": mode == 1, "zone": mode == 2, "target": 200}), "Start scoring mode %d" % mode)
  await frames(8)
  var target := active_bumper()
  game._on_bumper_hit(target)
  game._on_ring_collected(Vector2.ZERO)
  game._on_ring_collected(Vector2.ZERO)
  game._on_ring_collected(Vector2.ZERO)
  check(game.score == 200 and (game.zone.act_score == 200 if mode == 2 else game.score_attack.state == ScoreAttack.State.UNLOCKED), "Existing objective observes the same combo-adjusted total in mode %d" % mode)
 if game.zone_enabled:
  var target := active_bumper()
  while not game.zone.exit_unlocked:
   game._on_bumper_hit(target)
  var gate_y: float = game.zone.acts[0].exit_y
  game.zone.observe_motion(Vector2(400, gate_y + 50), Vector2(400, gate_y - 60))
  game._sync_zone_gates()
  preserved_time = game.scorecraft.remaining
  var preserved_score: int = game.score
  await frames(20)
  check(game.zone.state == ZoneRun.State.DRAFT and game.scorecraft.remaining == preserved_time, "Chao draft freezes an active combo")
  check(game.choose_zone_chao("ice") and game.scorecraft.chain == 0 and game.score == preserved_score and game.zone.act_score == 0, "Act advancement clears combo but preserves cumulative score and equips Chao")
  game._on_bumper_hit(active_bumper())
  game.set_physics_process(true)
  game.ball.teleport_to(Vector2(400, game.zone.acts[1].bounds.end.y - 30), Vector2(0, 400))
  await frames(8)
  check(game.respawn_time > 0 and game.scorecraft.chain == 0, "Actual checkpoint drain ends the combo")
  preserved_score = game.score
  game._on_bumper_hit(active_bumper())
  game._on_ring_collected(Vector2.ZERO)
  check(game.score == preserved_score and game.scorecraft.chain == 0, "Late contacts during drain cannot restart or score a combo")
  game.reset_ball()
  check(game.scorecraft.chain == 0 and game.tuning.chao_id == "ice", "Ball reset retains Chao while clearing combo")
 paused = true
 check(game.request_generation(19, -1, 2), "Regeneration accepts a different seed and grid variant")
 await frames(8)
 check(game.score == 0 and game.scorecraft.chain == 0 and game.scorecraft.remaining == 0, "Regeneration clears totals, target history and combo timer")
 paused = false
 game.free()
 await frames(3)
 print("RESULT | Scorecraft | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
