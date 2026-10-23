extends "res://tests/score_attack_regression.gd"
## Actual 120 Hz bodies plus the shared loadout UI/lifecycle. No test framework.

func fixture(id: String, profile: int = 0, spawn: Vector2 = Vector2.ZERO) -> Dictionary:
 var node := Node2D.new()
 root.add_child(node)
 var tuning := PhysicsTuning.new()
 tuning.select_profile(profile)
 tuning.equip_chao(id)
 node.add_child(tuning)
 var controls := PlaygroundInput.new()
 controls.virtual_enabled = true
 node.add_child(controls)
 var ball := PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 ball.position = spawn
 node.add_child(ball)
 return {"node": node, "tuning": tuning, "controls": controls, "ball": ball}

func steering_trial(id: String, incoming_x: float, ticks: int) -> Dictionary:
 var f := fixture(id)
 f.ball.teleport_to(Vector2.ZERO, Vector2(incoming_x, 0))
 f.controls.virtual_steering = 1.0
 await frames(ticks)
 var result := {"vx": f.ball.linear_velocity.x, "x": f.ball.position.x, "contribution": f.ball.steering_contribution}
 f.node.free()
 await frames(2)
 return result

func flip_trial(id: String, profile: int) -> Dictionary:
 var start := Vector2.RIGHT.rotated(0.32) * 130 * 0.65 + Vector2(0, -65)
 var f := fixture(id, profile, start)
 var paddle := PlaygroundFlipper.new()
 paddle.length = 130
 paddle.ball = f.ball
 paddle.tuning = f.tuning
 paddle.controls = f.controls
 f.node.add_child(paddle)
 f.ball.teleport_to(start, Vector2(0, 180))
 var press := -1
 var minimum_y: float = start.y
 var peak_up := 0.0
 var finite := true
 for tick in 420:
  var near := Geometry2D.get_closest_point_to_segment(f.ball.position, paddle.position, paddle.tip())
  if press < 0 and f.ball.linear_velocity.y > 0 and near.distance_to(f.ball.position) < 43:
   press = tick
  f.controls.virtual_left = press >= 0 and tick - press < 15
  await frames(1)
  minimum_y = minf(minimum_y, f.ball.position.y)
  peak_up = maxf(peak_up, -f.ball.linear_velocity.y)
  finite = finite and f.ball.position.is_finite() and f.ball.linear_velocity.is_finite()
 var result := {"chao": id, "profile": profile, "strikes": paddle.strikes, "rise": -minimum_y, "peak_up": peak_up, "finite": finite}
 f.node.free()
 await frames(2)
 return result

func run() -> void:
 var tuning := PhysicsTuning.new()
 var base := tuning.effective.duplicate()
 for id: String in ["ice", "spring", "magnet"]:
  tuning.equip_chao(id)
  var expected := tuning.preview_chao(id)
  tuning.equip_chao(id)
  tuning.rebuild()
  check(tuning.effective == expected and tuning.base.as_values() == base, id + " resolves once without mutating the profile")
 tuning.modifier_enabled = true
 check(tuning.chao_id == "practice" and tuning.effective == PhysicsTuning.resolve(tuning.base, {}, [PhysicsTuning.EXAMPLE_MODIFIER]), "Practice replaces the lab slot rather than stacking")
 tuning.equip_chao("spring")
 tuning.modifier_enabled = false
 check(tuning.chao_id == "spring" and not tuning.modifier_enabled, "A stale practice-off command cannot unequip another Chao")
 tuning.set_value("flipper_launch_strength", 2000)
 check(tuning.effective.flipper_launch_strength == 2200, "Chao respects centralized limits after session overrides")
 tuning.select_profile(1)
 check(tuning.chao_id == "spring" and tuning.overrides.is_empty() and tuning.effective == tuning.preview_chao("spring"), "Profile changes preserve Chao and clear session overrides")
 tuning.equip_chao("none")
 check(tuning.effective == tuning.base.as_values(), "None restores the unmodified profile")
 tuning.free()

 var normal := await steering_trial("none", 0, 60)
 var ice := await steering_trial("ice", 0, 60)
 var normal_brake := await steering_trial("none", -100, 15)
 var ice_brake := await steering_trial("ice", -100, 15)
 var cap := await steering_trial("ice", 0, 240)
 print("CHAO STEERING | baseline=", normal, " | ice=", ice, " | brake baseline=", normal_brake, " | ice=", ice_brake, " | cap=", cap)
 check(ice.x > normal.x * 1.25 and ice.vx > normal.vx, "Ice changes actual lateral travel under the same half-second input")
 check(ice_brake.vx > normal_brake.vx + 20, "Ice brakes an opposing real-body trajectory faster")
 check(absf(cap.contribution - 150) < 0.1 and cap.vx <= 150.1, "Ice retains a bounded 150 px/s steering contribution")
 for profile in 2:
  var ordinary := await flip_trial("none", profile)
  var spring := await flip_trial("spring", profile)
  print("CHAO FLIP | ", ordinary, " | ", spring)
  # Native moving-paddle contact also contributes velocity, so a 35% modifier
  # is not a promise of 35% more speed. Require a measurable gain in both profiles.
  check(ordinary.strikes == 1 and spring.strikes == 1 and spring.finite and spring.peak_up > ordinary.peak_up * 1.1 and spring.rise > ordinary.rise * 1.15, "Spring increases real strike speed and height without repeated impulses: profile %d" % profile)

 # Use the real score listener and cosmetic pickup signal at an 80 px offset.
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.generation_seed = 18
 root.add_child(game)
 await frames(6)
 green_hill = true
 var original_signature: String = game.layout.signature
 var lab: ChaoLabPanel = game.debug_panel.challenge_panel.chao_lab
 check(game.tuning.chao_id == "none" and game.score_attack.state == ScoreAttack.State.FREE_PLAY, "Free Play starts without an upgrade")
 lab.open_lab()
 lab.choose("spring")
 lab.hide()
 await frames(2)
 check(not paused and game.tuning.chao_id == "none", "Closing a preview restores play state without equipping")
 lab.open_lab()
 lab.choose("ice")
 check(game.tuning.chao_id == "none" and paused, "Preview pauses safely without changing equipped stats")
 await capture("chao-lab")
 lab.apply_choice()
 await frames(8)
 check(not paused and not lab.visible and game.tuning.chao_id == "ice" and game.ball.serve_pending and game.layout.signature == original_signature, "UI equips Ice into a fresh run on the exact same table")
 game.debug_panel.practice_toggle.button_pressed = true
 await frames(8)
 check(game.tuning.chao_id == "practice" and game.debug_panel.practice_toggle.button_pressed, "Legacy toggle starts a fresh run with only Practice equipped")
 lab.open_lab()
 lab.choose("magnet")
 lab.apply_choice()
 await frames(8)
 check(game.tuning.chao_id == "magnet" and not game.debug_panel.practice_toggle.button_pressed and game.tuning.effective.flipper_launch_strength == 1050, "Lab selection removes Practice and synchronizes its toggle")
 var field: RingField = game.ring_field
 var ring: Dictionary = field.rings[0]
 var home: Vector2 = ring.home
 game.ball.position = home + Vector2(80, 0)
 game.ball.serve_pending = false
 field.previous_ball_position = game.ball.position
 var velocity: Vector2 = game.ball.linear_velocity
 game.tuning.equip_chao("none")
 field._physics_process(0)
 var outside: bool = ring.active
 game.tuning.equip_chao("magnet")
 var before: int = game.score
 var claims: Array[int] = []
 field.pickup_claimed.connect(func(index: int): claims.append(index))
 field._physics_process(0)
 var score_after: int = game.score
 field._physics_process(0)
 check(outside and not ring.active and claims.has(0) and game.score > before and game.score == score_after and ring.position == home and game.ball.linear_velocity == velocity, "Magnet claims an 80 px ring immediately and once, through existing score/visual signals without moving the ball")
 check(not game.request_generation(18, -1, -1, {"chao": "spring"}) and game.tuning.chao_id == "magnet", "Active play rejects loadout swaps without pause or reset")
 game.reset_ball(false)
 await frames(2)
 check(game.tuning.chao_id == "magnet" and game.score == score_after, "Ball reset keeps equipment and earned progress")
 game.ball.teleport_to(Vector2(400, game.layout.bounds.end.y + 80), Vector2(0, 200))
 await frames(125)
 check(game.ball_number == 2 and not game.ball.serve_pending and game.tuning.chao_id == "magnet", "Drain automatically respawns and relaunches with the same equipped Chao")
 paused = true
 game.debug_panel.challenge_panel.mode_selector.select(1)
 game.debug_panel.challenge_panel.target_field.get_line_edit().text = "25"
 lab.open_lab()
 lab.choose("spring")
 lab.apply_choice()
 await frames(8)
 check(game.score == 0 and game.tuning.chao_id == "spring" and game.layout.signature == original_signature and game.score_attack.state == ScoreAttack.State.LOCKED and game.score_attack.target == 25 and paused, "Chao UI applies the selected mode/typed target on the same seed and preserves pause")
 game._on_ring_collected(Vector2.ZERO)
 check(game.score_attack.state == ScoreAttack.State.UNLOCKED, "Chao leaves the existing score threshold intact")
 var goal: Vector2 = game.score_attack.goal_position
 game.score_attack.observe_motion(goal, goal)
 await frames(2)
 game.debug_panel.challenge_panel.replay_button.pressed.emit()
 await frames(8)
 check(game.tuning.chao_id == "spring" and game.score == 0 and game.score_attack.state == ScoreAttack.State.LOCKED and not paused, "Victory replay retains one Chao, clears progress and resumes at serve")
 game.request_generation(8, TableGenerator.Difficulty.EASY, 2)
 await frames(8)
 check(game.tuning.chao_id == "spring" and game.tuning.effective.flipper_launch_strength == 1417.5 and game.generation_grid_mode == 2, "Regeneration preserves one equipped modifier across difficulty and grid changes")
 check(not game.request_generation(8, -1, -1, {"chao": "unknown"}) and game.tuning.chao_id == "spring", "Invalid choices leave the active run intact")
 var recipe: GridChunkRecipe = game.GRID_EASY_RECIPES[0]
 var placements := recipe.placements.duplicate(true)
 recipe.placements.append({"piece": "invalid_chao_fixture", "cell": Vector2i(0, 0)})
 game.request_generation(8, TableGenerator.Difficulty.EASY, 1, {"chao": "ice"})
 await frames(6)
 recipe.placements = placements
 check(game.tuning.chao_id == "spring" and game.generation_grid_mode == 2 and not game.generation_pending, "Rejected geometry cannot change the equipped Chao")
 await capture("chao-equipped")
 game.free()
 paused = false
 print("RESULT | Chao Lab | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
