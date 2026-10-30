extends "res://tests/act_game_fixture.gd"
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
 game.playfield._add_bumper(body, 30.0)
 var visual := Node3D.new()
 game.presentation.add_child(visual)
 game.presentation.bumper_visuals[body.get_instance_id()] = visual
 return body

func run() -> void:
 var combo := Scorecraft.new()
 combo.config = ScorecraftConfig.new()
 combo.config.multiplier_cap = 4
 combo.config.tiered_decay = true
 root.add_child(combo)
 combo.set_physics_process(false)
 var a := Node.new()
 var b := Node.new()
 var c := Node.new()
 check(combo.award_ring() == 15 and combo.chain == 0, "Rings alone cannot start or grow a combo")
 check(combo.award_bumper(a) == 100 and combo.chain == 1 and combo.multiplier == 1, "First bumper starts at x1")
 combo._physics_process(0.4)
 var time_left := combo.remaining
 check(combo.award_bumper(a) == 100 and combo.remaining == time_left and combo.chain == 1, "Repeated bumper pays base and cannot refresh")
 check(combo.award_ring() == 15 and combo.award_ring() == 15 and combo.remaining == time_left, "Partial ring sequence does not refresh the window")
 check(combo.award_ring() == 30 and combo.multiplier == 2 and combo.remaining == 3.0, "Third ring advances to x2 and refreshes")
 combo._physics_process(0.3)
 time_left = combo.remaining
 check(combo.award_ring() == 30 and combo.remaining == time_left and combo.chain == 2, "Extra rings pay current multiplier without automatic refresh")
 check(combo.award_bumper(a) == 100 and not combo.ring_link_available and combo.remaining == time_left, "Ring collection cannot make an old bumper fresh again")
 check(combo.award_bumper(b) == 300 and combo.multiplier == 3 and combo.ring_link_available, "Different bumper visibly advances to x3")
 combo.award_ring()
 combo.award_ring()
 check(combo.award_ring() == 60 and combo.multiplier == 4 and combo.chain == 4 and not combo.ring_link_available, "Further valid link reaches x4 with no stored link")
 combo._physics_process(0.25)
 time_left = combo.remaining
 check(combo.award_bumper(a) == 100 and combo.award_bumper(b) == 100 and combo.remaining == time_left, "Alternating two already-used bumpers cannot sustain a chain")
 check(combo.award_rack() == 500 and combo.remaining == 3.0 and combo.chain == 4, "Rack award stays fixed and refreshes without advancing")
 check(combo.award_bumper(c, 5) == 800 and combo.chain == 0 and combo.last_award.special_bonus == 400, "Homing finisher uses pre-hit 100x4 + 400")
 check(combo.award_bumper(a, 5) == 500 and combo.chain == 0, "Unchained Homing keeps its original 500 points")
 combo.award_bumper(a)
 combo.award_bumper(b)
 check(combo.award_bumper(a, 5) == 600 and combo.chain == 0, "Repeated-target Homing retains the pre-hit x2 multiplier")
 combo.award_bumper(a)
 combo._physics_process(3.0)
 check(combo.chain == 0 and combo.multiplier == 1 and combo.award_bumper(a) == 100, "Expiry clears target history and restarts at x1")
 check(combo.award_bumper(b) == 200 and combo.award_bumper(c) == 300 and combo.multiplier == 3, "Each distinct bumper advances exactly one visible tier")
 combo.award_ring()
 combo.award_ring()
 check(combo.award_ring() == 60 and combo.multiplier == 4, "Mixing three rings into a bumper chain earns the top tier")
 combo.reset("Fixture")
 combo.config.combo_window = 1.2
 combo.config.rings_per_link = 2
 combo.config.multiplier_cap = 2
 combo.award_bumper(a)
 combo.award_ring()
 check(combo.award_ring() == 30 and combo.remaining == 1.2 and combo.award_bumper(b) == 200, "Window, ring threshold and cap are configurable")
 combo.reset("Baseline")
 combo.enabled = false
 check(combo.award_bumper(a) == 100 and combo.award_bumper(b) == 100 and combo.award_ring() == 15 and combo.award_bumper(c, 5) == 500 and combo.chain == 0, "Baseline mode uses V1 base awards without combos")
 combo.free()
 a.free()
 b.free()
 c.free()

 game = create_game()

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
 check(game.score == 160 and game.rings_collected == 3 and game.special_meter == 17 and game.scorecraft.multiplier == 2, "Actual ring pickup gives 15+15+30 while meter remains ordinary +5")
 var preserved_time: float = game.scorecraft.remaining
 paused = true
 await frames(20)
 check(game.scorecraft.remaining == preserved_time, "Pause freezes the combo even under Green Hill's always-processing UI")
 paused = false
 game.special_meter = 100
 var before: int = game.score
 check(game.specials.activate(), "Homing activates through the normal ability path")
 await frames(50)
 check(game.score - before == 600 and game.scorecraft.chain == 0 and game.special_meter == 2, "Real Homing contact cashes out x2 once without extra meter multiplication")
 first.free()
 second.free()
 paused = true
 var hud: ScorecraftPanel = game.debug_panel.act_controls.character_panel.combo_hud
 hud.toggle.button_pressed = false
 await frames(8)
 check(not game.scorecraft_enabled and not game.scorecraft.enabled and game.score == 0 and game.authored_act_path == "res://test-results/session-physics-act.tres", "Baseline HUD toggle replays the same Act with clean score")
 hud.toggle.button_pressed = true
 await frames(8)
 check(game.scorecraft.enabled and game.scorecraft.chain == 0 and game.scorecraft.last_award.is_empty(), "Re-enabling combos leaves no stale timer or award feedback")
 check(game.request_replay(), "Authored replay is accepted")
 await frames(8)
 check(game.score == 0 and game.scorecraft.chain == 0 and game.scorecraft.remaining == 0, "Replay clears totals, target history and combo timer")
 paused = false
 game.free()
 await frames(3)
 print("RESULT | Scorecraft | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
