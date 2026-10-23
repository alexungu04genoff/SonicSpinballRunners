extends "res://tests/score_attack_regression.gd"
## Controlled trajectory fixtures use actual 120 Hz collisions and score callbacks.
## Input-only comparisons are in character_play_survey.gd.
var target_body: StaticBody2D
var wall: StaticBody2D
var homing_events: Array[String] = []
var homing_start: Dictionary = {}

func collider(at: Vector2, shape: Shape2D, bumper: bool) -> StaticBody2D:
 var body := StaticBody2D.new()
 body.position = at
 var collision := CollisionShape2D.new()
 collision.shape = shape
 body.add_child(collision)
 if bumper:
  body.set_meta("bumper", true)
 game.world.add_child(body)
 return body

func place(at: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
 game.specials.reset(true)
 game.ball.teleport_to(at, velocity)
 await frames(3)

func run() -> void:
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.generation_seed = 18
 root.add_child(game)
 await frames(5)
 game.specials.homing_started.connect(func(body: Node2D, direction: Vector2):
  homing_events.append("start")
  homing_start = {"target": body, "direction": direction, "remaining": game.specials.homing_remaining}
 )
 game.specials.homing_ended.connect(func(reason: String):
  homing_events.append("end:" + reason)
  check(game.specials.pending_target == null and game.specials.homing_remaining == 0 and game.specials.homing_direction == Vector2.ZERO, "Homing end observes cleared state: " + reason)
 )
 game.specials.special_hit.connect(func(_body: Node2D, _multiplier: int): homing_events.append("hit"))
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 var circle := CircleShape2D.new()
 circle.radius = 30
 target_body = collider(Vector2(2200, 2000), circle, true)
 var target_visual := Node3D.new()
 game.presentation.add_child(target_visual)
 game.presentation.bumper_visuals[target_body.get_instance_id()] = target_visual
 game.chunks[0].descriptors.append({"kind": "bumper", "body": target_body})
 var box := RectangleShape2D.new()
 box.size = Vector2(25, 500)
 wall = collider(Vector2(2100, 2000), box, false)
 await place(Vector2(2000, 2000))
 game.special_meter = 100
 check(game.specials.find_target() == null and not game.specials.activate() and game.special_meter == 100, "Wall blocks full-ball homing sweep; failed activation keeps charge")
 wall.position.y = 3000
 await frames(2)
 game.special_meter = 99
 check(not game.specials.activate() and game.special_meter == 99, "Insufficient charge cannot activate or spend")
 check(homing_events.is_empty(), "Failed activation emits no homing lifecycle events")
 for incoming: Vector2 in [Vector2.ZERO, Vector2(0, 400), Vector2(-250, -200), Vector2(0, 1200)]:
  await place(Vector2(2000, 2000), incoming)
  homing_events.clear()
  game.special_meter = 100
  var before: int = game.score
  check(game.specials.activate() and game.special_meter == 0, "Clear target activates bounded impulse: " + str(incoming))
  check(homing_start.target == target_body and homing_start.direction.is_equal_approx(game.ball.position.direction_to(target_body.position)) and homing_start.remaining == game.specials.definition.hit_window, "Homing start supplies target, direction and active duration")
  for tick in 90:
   await frames(1)
   if game.score > before:
    break
  check(game.score - before == 500 and game.specials.pending_target == null, "Physical contact awards one 5x hit: " + str(incoming))
  check(game.special_meter == 2, "Special hit uses ordinary bumper recharge")
  check(homing_events == ["start", "end:Hit", "hit"], "Actual hit ends homing once before impact feedback")
 await place(Vector2(3000, 2000))
 game.special_meter = 100
 check(not game.specials.activate() and game.special_meter == 100, "No nearby target keeps meter")
 # A wall introduced after activation must still stop the physical ball.
 await place(Vector2(2000, 2000))
 game.special_meter = 100
 check(game.specials.activate(), "Activate before a path closes")
 wall.position.y = 2000
 var before_block: int = game.score
 await frames(85)
 check(game.score == before_block and game.specials.pending_target == null, "Blocked shot expires without remote scoring or tunneling")
 check(homing_events.back() == "end:Expired", "Missed shot exposes expiry without an impact event")
 wall.position.y = 3000
 for reason: String in ["Drain", "Reset", "New run", "Character changed", "Act complete"]:
  await place(Vector2(2000, 2000))
  game.special_meter = 100
  homing_events.clear()
  game.specials.activate()
  if reason == "Act complete":
   game.specials.clear_homing(reason)
  else:
   game.specials.reset(false, reason)
  game.specials.reset(false, reason)
  check(homing_events == ["start", "end:" + reason], "Cancellation emits once with reason: " + reason)
 game.specials.select_character("tails")
 game.character_id = "tails"
 game.tuning.equip_chao("ice")
 var ordinary: Dictionary = game.tuning.effective.duplicate()
 await place(Vector2(3000, 2000), Vector2(0, 600))
 var ordinary_start: float = game.ball.position.y
 await frames(45)
 var ordinary_drop: float = game.ball.position.y - ordinary_start
 await place(Vector2(3000, 2000), Vector2(0, 600))
 game.special_meter = 100
 var flight_start: float = game.ball.position.y
 check(game.specials.activate() and game.special_meter == 0, "Tail Flight consumes full charge")
 check(game.tuning.effective.gravity_scale < ordinary.gravity_scale and game.tuning.effective.max_steering_speed > ordinary.max_steering_speed, "Flight combines with Ice through the shared stat resolver")
 game.tuning.modifier_enabled = true
 check(game.tuning.build_ids == ["practice"] and game.tuning._temporary.size() == 1 and game.tuning.effective.gravity_scale < ordinary.gravity_scale, "Practice toggle replaces Chao without stacking or removing flight")
 game.tuning.equip_chao("ice")
 await frames(45)
 var flight_drop: float = game.ball.position.y - flight_start
 print("FLIGHT RECOVERY | ordinary_drop=", ordinary_drop, " flight_drop=", flight_drop)
 check(flight_drop < ordinary_drop - 150, "Flight changes an actual falling trajectory")
 var remaining: float = game.specials.flight_remaining
 paused = true
 await frames(15)
 check(game.specials.flight_remaining == remaining, "Pause preserves remaining flight duration")
 paused = false
 await frames(120)
 var fading: float = game.tuning.effective.gravity_scale
 check(fading > ordinary.gravity_scale * 0.25 and fading < ordinary.gravity_scale, "Gravity smoothly restores during the final flight fraction")
 await frames(35)
 check(game.tuning.effective == ordinary and game.tuning._temporary.is_empty(), "Expiration removes the temporary modifier and preserves Ice")
 game.special_meter = 100
 check(game.specials.activate(), "Flight can activate again after recharge")
 game.specials.charge(12)
 game.reset_ball()
 check(game.specials.flight_remaining == 0 and game.special_meter == 12 and game.tuning.effective == ordinary, "Reset ends flight without refilling meter or losing Chao")
 await frames(5)
 game.specials.select_character("sonic")
 game.character_id = "sonic"
 check(game.tuning.base == PhysicsTuning.BALANCED and game.tuning.chao_id == "ice" and game.special_meter == 0, "Character change restores starting profile, retains equipped Chao and clears meter")
 target_body.free()
 wall.free()
 # Exercise the same UI entry points used by players, including replay.
 var ui: ScoreAttackPanel = game.debug_panel.challenge_panel
 ui.character_selector.select(1)
 ui.chao_lab.refresh()
 check(ui.chao_lab.heading.text.contains("Tails") and ui.chao_lab.cards.ice.stats.text.contains("135") and game.tuning.base == PhysicsTuning.BALANCED, "Chao preview uses pending Tails profile without changing the current run")
 for mode in [0, 1, 2]:
  paused = true
  ui.mode_selector.select(mode)
  ui.character_selector.select(1)
  check(ui.start_run(), "UI starts Tails mode %d" % mode)
  await frames(8)
  check(game.character_id == "tails" and game.specials.character_id == "tails" and game.special_meter == 0 and game.tuning._temporary.is_empty(), "Fresh character state in mode %d" % mode)
  check(game.debug_panel.spinboxes.steering_acceleration.value == 2400, "Editable physics fields show Tails baseline in mode %d" % mode)
  paused = false
 game.set_physics_process(true)
 game.ring_field.set_physics_process(true)
 # Closed Act gate remains a physical obstruction during flight.
 var gate: ZoneGate = game.zone_gates[0]
 var gate_y: float = gate.opening.position.y
 await place(Vector2(gate.opening.get_center().x, gate_y + 100), Vector2(0, -500))
 game.special_meter = 100
 check(game.specials.activate(), "Flight activates beneath the closed Act gate")
 var minimum_y: float = game.ball.position.y
 for tick in 35:
  await frames(1)
  minimum_y = minf(minimum_y, game.ball.position.y)
 check(minimum_y > gate_y and game.zone.active_act == 0, "Flight cannot bypass a locked Act gate")
 game.special_meter = 37
 game.zone.observe_score(10000)
 game.zone.observe_motion(Vector2(400, gate_y + 50), Vector2(400, gate_y - 60))
 game._sync_zone_gates()
 paused = true
 check(game.choose_zone_chao("spring") and game.special_meter == 37 and game.specials.flight_remaining > 0, "Act draft retains unused meter and paused flight")
 game.specials.reset(false, "Test drain setup")
 await place(game.zone.acts[1].entry + Vector2(0, -100), Vector2(0, 600))
 game.special_meter = 100
 game.specials.activate()
 game.special_meter = 19
 game.ball.teleport_to(Vector2(400, game.zone.acts[1].bounds.end.y - 30), Vector2(0, 400))
 await frames(8)
 check(game.respawn_time > 0 and game.specials.flight_remaining == 0 and game.special_meter == 19 and game.tuning._temporary.is_empty(), "Checkpoint drain ends flight and retains unused meter without refill")
 paused = true
 check(game.request_generation(18), "Replay request accepted")
 await frames(8)
 check(game.zone.active_act == 0 and game.special_meter == 0 and game.tuning.build_ids.is_empty() and game.specials.target == null, "Zone replay resets meter, acquired Chao and targeting")
 paused = false
 await frames(5)
 check(not game.presentation.get_node("SonicVisualAdapter").visible, "Tails hides the Sonic presentation without changing its artwork")
 game.special_meter = 100
 game.launch_ball()
 await frames(12)
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/character-lab-ready.png")
 game.controls.special_requested.emit()
 await frames(30)
 check(game.specials.flight_remaining > 0 and game.special_meter < 100, "Mapped Special request activates equipped Tails after replay")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/character-lab-tails.png")
 paused = false
 game.free()
 await frames(3)
 print("RESULT | Character Lab | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
