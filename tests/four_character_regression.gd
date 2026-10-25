extends "res://tests/character_lab_regression.gd"
## Real collision fixtures plus shared scoring/lifecycle assertions. No geometry edits.
var areas: Array[Dictionary] = []
var endings: Array[String] = []
var impacts: Array[Dictionary] = []

func run() -> void:
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.generation_seed = 18
 root.add_child(game)
 await frames(5)
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 # These isolated bodies/rings have no corresponding authored visual meshes.
 game.presentation.process_mode = Node.PROCESS_MODE_DISABLED
 game.presentation.ring_visuals.clear()
 game.ring_field.pickup_claimed.disconnect(game.presentation._on_ring_claimed)
 game.debug_panel.challenge_panel.process_mode = Node.PROCESS_MODE_DISABLED
 game.controls.virtual_enabled = true
 game.specials.area_completed.connect(func(source: String, targets: int, rings: int): areas.append({"source": source, "targets": targets, "rings": rings}))
 game.specials.glide_ended.connect(func(reason: String): endings.append(reason))
 game.ball.physical_impact.connect(func(body: Node2D, normal: Vector2, speed: float):
  if speed > 180:
   impacts.append({"body": body.name, "normal": normal, "speed": speed, "gliding": game.specials.glide_remaining}))
 var circle := CircleShape2D.new()
 circle.radius = 25
 target_body = collider(Vector2(2200, 2000), circle, true)
 var second := collider(Vector2(2000, 1800), circle, true)
 var far := collider(Vector2(2400, 2000), circle, true)
 for body: Node2D in [target_body, second, far]:
  game.chunks[0].descriptors.append({"kind": "circle", "body": body})
 # Duplicate descriptor must not multiply a target award.
 game.chunks[0].descriptors.append({"kind": "circle", "body": target_body})
 game.playfield = PlayfieldData.from_generated(game.chunks, game.layout)
 game.specials.select_character("shadow")
 await place(Vector2(2000, 2000))
 game.ring_field.rings.clear()
 for position: Vector2 in [Vector2(2100, 1950), Vector2(1900, 1900), Vector2(2500, 2000)]:
  game.ring_field.add_ring(position)
 game.scorecraft.reset("Fixture")
 game.scorecraft.award_bumper(far)
 game.scorecraft.award_bumper(second)
 for index in 3:
  game.scorecraft.award_ring()
 var chain: int = game.scorecraft.chain
 var timer: float = game.scorecraft.remaining
 var before: int = game.score
 var contacts: int = game.ball.bumper_hit_count
 game.special_meter = 99
 check(not game.specials.activate() and game.special_meter == 99, "Shadow requires full charge")
 game.special_meter = 100
 check(game.specials.activate() and game.special_meter == 0, "Shadow spends full meter before remote awards")
 check(game.score - before == 250 and areas.back().targets == 2 and areas.back().rings == 2, "Blast pays two distinct bumpers and two rings at base value, excluding distant targets")
 check(game.ball.bumper_hit_count == contacts and game.scorecraft.chain == chain and game.scorecraft.remaining == timer, "Remote blast impersonates no contacts, combo links or timer refresh")
 before = game.score
 check(not game.ring_field.claim_ring(0) and not game.activate_area_target(target_body, "chaos_blast", 1), "Overlapping claims and same-target area calls are deduplicated")
 game._on_bumper_hit(target_body)
 check(game.score == before and game.special_meter == 0, "Immediate physical callback after blast cannot duplicate points or meter")
 await frames(22)
 game._on_bumper_hit(target_body)
 check(game.score > before and game.special_meter == 2, "Later genuine contact can score and recharge normally")
 # Same blast area straddles an Act edge. Only active-Act objects qualify.
 game.zone_enabled = true
 game.zone.state = ZoneRun.State.PLAYING
 game.zone.active_act = 0
 game.zone.acts = [{"bounds": Rect2(1800, 1900, 600, 500)}]
 game.zone.targets.assign([100000])
 game.zone._score_at_entry = 0
 game.ring_field.collection_bounds = game.zone.acts[0].bounds
 await place(Vector2(2000, 2000))
 game.ring_field.rings.clear()
 game.ring_field.add_ring(Vector2(1900, 1950))
 game.ring_field.add_ring(Vector2(1900, 1850))
 before = game.score
 game.special_meter = 100
 game.specials.activate()
 check(game.score - before == 625 and areas.back().targets == 1 and areas.back().rings == 1, "Blast clips to current Act, including the ordinary 500-point eligible-rack bonus")
 check(game.ring_field.rings[1].active and not game.zone.exit_unlocked, "Future-Act ring and locked exit remain untouched")
 var original_definition: CharacterDefinition = game.specials.definition
 game.specials.definition = original_definition.duplicate(true)
 game.specials.definition.blast_radius = 5000
 check(not game.specials._area_contains("chaos_blast", Vector2.ZERO, Vector2(601, 0)), "Blast radius has a hard 600px safety ceiling even with oversized tuning")
 game.specials.definition.meter_cost = 60
 game.special_meter = 60
 check(game.specials.activate() and game.special_meter == 0, "Configured partial meter cost is spent exactly once without remote recharge")
 game.specials.definition = original_definition
 game.zone_enabled = false
 game.zone.state = ZoneRun.State.INACTIVE
 game.ring_field.collection_bounds = Rect2()
 game.ring_field.rings.clear()
 game.specials.select_character("knuckles")
 game.tuning.equip_chao("ice")
 var baseline: Dictionary = game.tuning.effective.duplicate()
 var box := RectangleShape2D.new()
 box.size = Vector2(25, 1600)
 wall = collider(Vector2(2250, 2200), box, false)
 game.chunks[0].descriptors.append({"kind": "rail", "body": wall})
 game.playfield = PlayfieldData.from_generated(game.chunks, game.layout)
 target_body.position = Vector2(2210, 1750)
 second.position = Vector2(2500, 2100)
 far.position = Vector2(2800, 2000)
 await place(Vector2(2000, 2000))
 game.controls.virtual_steering = 0
 await frames(2)
 game.special_meter = 100
 check(not game.specials.activate() and game.special_meter == 100, "Stationary Knuckles must choose a direction; no guess or spend")
 game.ring_field.add_ring(Vector2(2120, 1850))
 game.ring_field.add_ring(Vector2(3000, 1850))
 game.controls.virtual_steering = 1
 await frames(2)
 before = game.score
 game.special_meter = 100
 var area_count := areas.size()
 var start_y: float = game.ball.position.y
 check(game.specials.activate() and game.special_meter == 0, "Knuckles launches a paid lateral glide")
 check(game.tuning.effective.gravity_scale == baseline.gravity_scale and game.tuning._temporary.size() == 1, "Glide keeps gravity and combines once with Ice through the resolver")
 var remaining: float = game.specials.glide_remaining
 paused = true
 await frames(8)
 check(game.specials.glide_remaining == remaining, "Pause freezes glide time")
 paused = false
 var max_x := 0.0
 for tick in 120:
  await frames(1)
  max_x = maxf(max_x, game.ball.position.x)
  if areas.size() > area_count:
   break
 print("WALL GLIDE | max_x=", max_x, " position=", game.ball.position, " areas=", areas, " ends=", endings, " impacts=", impacts)
 check(areas.size() == area_count + 1 and endings.back() == "Impact", "Real side-wall impact releases exactly one shockwave")
 check(max_x < 2250 and game.ball.position.y > start_y, "Glide collides with the wall while gravity pulls down; no upward launch")
 check(areas.back().targets == 1 and areas.back().rings == 1 and game.score - before == 250, "Vertical shockwave activates an exposed target and ring at exactly 2x base")
 check(game.special_meter == 0 and game.tuning.effective == baseline, "Remote wave cannot refill meter; impact removes only glide modifier")
 var barrier_shape := RectangleShape2D.new()
 barrier_shape.size = Vector2(180, 25)
 var barrier := collider(Vector2(2200, 1900), barrier_shape, false)
 await frames(2)
 check(not game.specials._wave_visible(Vector2(2220, 2050), target_body.position, target_body), "An intervening physical barrier blocks the vertical shockwave")
 check(not game.specials._area_contains("shockwave", Vector2(2220, 2050), Vector2(2500, 1800)), "Shockwave excludes targets outside its configured column")
 await place(Vector2(2000, 2000))
 game.special_meter = 100
 game.specials.activate()
 game.specials._on_impact(barrier, Vector2.LEFT, 650)
 check(game.specials.glide_remaining > 0, "Unrelated collider cannot trigger a shockwave even with a strong lateral impact")
 area_count = areas.size()
 game.specials._on_impact(wall, Vector2.LEFT, 650)
 game.specials.reset(false, "Drain")
 await frames(2)
 check(areas.size() == area_count and not game.specials._area_pending, "Reset invalidates a queued impact before it can award targets")
 barrier.free()
 await place(Vector2(2220, 2000))
 game.special_meter = 100
 area_count = areas.size()
 game.specials.activate()
 await frames(8)
 check(areas.size() == area_count + 1, "A glide begun beside a wall still detects its immediate physical impact")
 # A real bumper impact also qualifies and receives one 2x award, not contact + wave.
 wall.position.x = 3000
 target_body.position = Vector2(2200, 2050)
 game.ring_field.rings.clear()
 await place(Vector2(2000, 2000))
 game.controls.virtual_steering = 1
 await frames(2)
 game.special_meter = 100
 before = game.score
 area_count = areas.size()
 game.specials.activate()
 for tick in 100:
  await frames(1)
  if areas.size() > area_count:
   break
 print("BUMPER GLIDE | position=", game.ball.position, " score=", game.score - before, " meter=", game.special_meter, " ends=", endings, " impacts=", impacts)
 check(areas.size() > area_count and game.score - before == 200 and game.special_meter == 2, "Actual bumper impact scores 2x once and recharges only its ordinary physical contact")
 # No eligible impact: expiry, not automatic wave or rescue.
 target_body.position = Vector2(2500, 1000)
 second.position = Vector2(2500, 1100)
 await place(Vector2(2000, 3000))
 game.controls.virtual_steering = -1
 await frames(2)
 game.special_meter = 100
 area_count = areas.size()
 game.specials.activate()
 await frames(110)
 check(endings.back() == "Expired" and areas.size() == area_count and game.tuning._temporary.is_empty(), "Missed glide expires safely without targets or leftover effects")
 for reason: String in ["Drain", "Reset", "Character changed", "New run", "Zone complete"]:
  await place(Vector2(2000, 3000))
  game.special_meter = 100
  game.specials.activate()
  game.specials.charge(17)
  game.specials.reset(false, reason)
  check(game.specials.glide_remaining == 0 and game.tuning._temporary.is_empty() and game.special_meter == 17, "Glide cancellation clears state without checkpoint refill: " + reason)
 # Temporary state survives a draft pause, but cannot carry into a new Act.
 await place(Vector2(2000, 3000))
 game.special_meter = 100
 game.specials.activate()
 game.zone.state = ZoneRun.State.DRAFT
 paused = true
 remaining = game.specials.glide_remaining
 await frames(10)
 check(game.specials.glide_remaining == remaining, "Chao draft freezes glide duration")
 game.specials.act_advanced()
 check(game.specials.glide_remaining == 0 and game.tuning._temporary.is_empty(), "Act advance clears glide while keeping earned meter")
 game.zone.state = ZoneRun.State.INACTIVE
 paused = false
 # Free all fixture bodies before regeneration replaces their descriptor owners.
 for body: Node in [target_body, second, far, wall]:
  body.free()
 var ui: ScoreAttackPanel = game.debug_panel.challenge_panel
 ui.process_mode = Node.PROCESS_MODE_ALWAYS
 check(ui.character_selector.item_count == 4, "Shared character selector exposes all four choices")
 for mode in [0, 1, 2]:
  for id: String in ["knuckles", "shadow"]:
   paused = true
   ui.mode_selector.select(mode)
   ui.character_selector.select(CharacterSpecials.CHARACTER_IDS.find(id))
   ui.chao_lab.refresh()
   check(ui.chao_lab.heading.text.contains(id.capitalize()), "Pending Chao preview follows " + id)
   check(ui.start_run(), "Start / replay accepts %s in mode %d" % [id, mode])
   await frames(8)
   check(game.character_id == id and game.special_meter == 0 and game.tuning._temporary.is_empty() and not game.character.model_available, "Fresh %s state and explicit placeholder in mode %d" % [id, mode])
   check(game.debug_panel.profiles.selected == PhysicsTuning.PROFILES.find(game.tuning.base), "Physics Lab identifies the selected character profile")
   if mode < 2:
    check(game.tuning.chao_id == "ice", "Character change retains sandbox Chao")
   paused = false
 # Real generated Act gate and drain with the new ability, not fake collisions.
 paused = true
 ui.character_selector.select(2)
 ui.start_run()
 await frames(8)
 paused = false
 game.set_physics_process(true)
 game.ring_field.set_physics_process(true)
 var gate: ZoneGate = game.zone_gates[0]
 var gate_y: float = gate.opening.position.y
 await place(Vector2(gate.opening.get_center().x, gate_y + 90), Vector2(0, -900))
 game.controls.virtual_steering = -1
 await frames(2)
 game.special_meter = 100
 game.specials.activate()
 var minimum_y: float = game.ball.position.y
 for tick in 25:
  await frames(1)
  minimum_y = minf(minimum_y, game.ball.position.y)
 check(minimum_y > gate_y and game.zone.active_act == 0, "Gliding Knuckles cannot bypass a real locked Act gate")
 game.special_meter = 19
 game.ring_field.previous_ball_position = game.zone.acts[0].drain - Vector2(0, 30)
 game.ball.teleport_to(game.zone.acts[0].drain - Vector2(0, 30), Vector2(0, 400))
 await frames(8)
 print("DRAIN STATE | respawn=", game.respawn_time, " glide=", game.specials.glide_remaining, " meter=", game.special_meter, " modifiers=", game.tuning._temporary, " ball=", game.ball.position, " drain=", game.zone.acts[0].drain)
 check(game.respawn_time > 0 and game.specials.glide_remaining == 0 and game.special_meter == 19 and game.tuning._temporary.is_empty(), "Actual checkpoint drain clears glide, preserves meter and queues normal retry")
 game.free()
 await frames(3)
 print("RESULT | Four characters | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
