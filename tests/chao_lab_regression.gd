extends "res://tests/act_game_fixture.gd"
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
 # Count physics ticks directly: render waits can skip extra physics steps.
 for tick in ticks:
  await physics_frame
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
 game = create_game()

 root.add_child(game)
 await frames(6)
 var original_signature: String = game.authored_document.fingerprint()
 var lab: ChaoLabPanel = game.debug_panel.act_controls.chao_lab
 check(game.tuning.chao_id == "none", "Authored play starts without an upgrade")
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
 check(not paused and not lab.visible and game.tuning.chao_id == "ice" and game.ball.serve_pending and game.authored_document.fingerprint() == original_signature, "UI equips Ice into a fresh run on the exact same table")
 game.debug_panel.practice_toggle.button_pressed = true
 await frames(8)
 check(game.tuning.chao_id == "practice" and game.debug_panel.practice_toggle.button_pressed, "Legacy toggle starts a fresh run with only Practice equipped")
 lab.open_lab()
 lab.choose("magnet")
 lab.apply_choice()
 await frames(8)
 check(game.tuning.chao_id == "magnet" and not game.debug_panel.practice_toggle.button_pressed and game.tuning.effective.flipper_launch_strength == game.tuning.preview_chao("none").flipper_launch_strength, "Lab selection removes Practice and synchronizes its toggle")
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
 check(not game.request_replay({"chao": "spring"}) and game.tuning.chao_id == "magnet", "Active play rejects loadout swaps without pause or reset")
 game.reset_ball(false)
 await frames(2)
 check(game.tuning.chao_id == "magnet" and game.score == score_after, "Ball reset keeps equipment and earned progress")
 game.ball.teleport_to(Vector2(400, game.playfield.bounds.end.y + 80), Vector2(0, 200))
 await frames(125)
 check(game.ball_number == 2 and not game.ball.serve_pending and game.tuning.chao_id == "magnet", "Drain automatically respawns and relaunches with the same equipped Chao")
 paused = true
 lab.open_lab()
 lab.choose("spring")
 lab.apply_choice()
 await frames(8)
 check(game.score == 0 and game.tuning.chao_id == "spring" and game.authored_document.fingerprint() == original_signature and paused, "Chao replay preserves the Act and caller pause state")
 check(not game.request_replay({"chao": "unknown"}) and game.tuning.chao_id == "spring", "Invalid choices preserve the active run")
 check(game.request_authored_act("res://missing-act.tres", {"chao": "ice"}), "Invalid path reaches validation")
 await frames(6)
 check(game.tuning.chao_id == "spring" and game.authored_document.fingerprint() == original_signature and not game.loading_act, "Rejected Act cannot change the equipped Chao or active geometry")
 await capture("chao-equipped")
 game.free()
 paused = false
 print("RESULT | Chao Lab | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
