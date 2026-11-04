extends "res://tests/character_lab_regression.gd"
## Real collision fixtures plus shared scoring/lifecycle assertions. No geometry edits.
var areas: Array[Dictionary] = []

func run() -> void:
 game = create_game()

 root.add_child(game)
 await frames(5)
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 # These isolated bodies/rings have no corresponding authored visual meshes.
 game.presentation.process_mode = Node.PROCESS_MODE_DISABLED
 game.presentation.ring_visuals.clear()
 game.ring_field.pickup_claimed.disconnect(game.presentation._on_ring_claimed)
 game.debug_panel.act_controls.process_mode = Node.PROCESS_MODE_DISABLED
 game.controls.virtual_enabled = true
 game.specials.area_completed.connect(func(source: String, targets: int, rings: int): areas.append({"source": source, "targets": targets, "rings": rings}))
 var circle := CircleShape2D.new()
 circle.radius = 25
 target_body = collider(Vector2(2200, 2000), circle, true)
 var second := collider(Vector2(2000, 1800), circle, true)
 var far := collider(Vector2(2400, 2000), circle, true)
 for body: Node2D in [target_body, second, far]:
  game.playfield._add_bumper(body, 25.0)
 # Duplicate descriptor must not multiply a target award.
 game.playfield._add_bumper(target_body, 25.0)
 game.specials.select_character("knuckles")
 await place(Vector2(2000, 2000))
 game.ring_field.rings.clear()
 for position: Vector2 in [Vector2(2100, 1950), Vector2(1900, 1900), Vector2(2500, 2000)]:
  game.ring_field.add_ring(position)
 game.scorecraft.reset("Fixture")
 game.scorecraft.award_bumper(far)
 game.scorecraft.award_bumper(second)
 for index in 3:
  game.scorecraft.award_ring()
 # Actual mechanics state must stay untouched by radial area iteration.
 var mechanics: Node = game.authored_runtime.mechanics
 var excluded: Array[Dictionary] = []
 for kind: String in ["switch_target", "wall_switch", "drop_target_bank", "one_way_gate", "diverter", "slingshot", "spring", "elevated_rail", "dash_panel", "spinner", "lane_barrier"]:
  mechanics.add_object({"object_id": "excluded_" + kind, "type": kind, "position": Vector2(2000, 2000), "rotation_degrees": 0.0, "properties": {}}, {})
  excluded.append(mechanics.items.back().duplicate(true))
 var chain: int = game.scorecraft.chain
 var timer: float = game.scorecraft.remaining
 var before: int = game.score
 var contacts: int = game.ball.bumper_hit_count
 game.special_meter = 99
 check(not game.specials.activate() and game.special_meter == 99, "Power requires full charge")
 game.special_meter = 100
 check(game.specials.activate() and game.special_meter == 0, "Power spends full meter before remote awards")
 check(game.score - before == 230 and areas.back().targets == 2 and areas.back().rings == 2, "Table Smash pays two distinct bumpers and two rings at base value, excluding distant targets")
 check(game.ball.bumper_hit_count == contacts and game.scorecraft.chain == chain and game.scorecraft.remaining == timer, "Remote smash impersonates no contacts, combo links or timer refresh")
 for snapshot: Dictionary in excluded:
  check(mechanics.by_id[snapshot.object_id] == snapshot, "Table Smash excludes stateful system: " + snapshot.type)
 before = game.score
 check(not game.ring_field.claim_ring(0) and not game.activate_area_target(target_body, "table_smash", 1), "Overlapping claims and same-target area calls are deduplicated")
 game._on_bumper_hit(target_body)
 check(game.score == before and game.special_meter == 0, "Immediate physical callback after smash cannot duplicate points or meter")
 await frames(22)
 game._on_bumper_hit(target_body)
 check(game.score > before and game.special_meter == 2, "Later genuine contact can score and recharge normally")
 # Same smash area straddles an Act edge. Only active-Act objects qualify.
 var original_definition: CharacterDefinition = game.specials.definition
 game.specials.definition = original_definition.duplicate(true)
 game.specials.action.smash_radius = 5000
 check(not game.specials._area_contains("table_smash", Vector2.ZERO, Vector2(601, 0)), "Table Smash radius has a hard 600px safety ceiling even with oversized tuning")
 game.specials.definition.meter_cost = 60
 game.special_meter = 60
 check(game.specials.activate() and game.special_meter == 0, "Configured partial meter cost is spent exactly once without remote recharge")
 game.specials.definition = original_definition
 check(CharacterSpecials.CHARACTERS.sonic.type_action == CharacterSpecials.CHARACTERS.shadow.type_action, "Sonic and Shadow share the exact Speed tuning resource")
 check(CharacterSpecials.CHARACTERS.sonic.profile != CharacterSpecials.CHARACTERS.shadow.profile, "Shared Speed retains distinct character physics profiles")
 for id: String in CharacterSpecials.CHARACTER_IDS:
  game.specials.select_character(id)
  check(game.tuning.base == CharacterSpecials.CHARACTERS[id].profile, "Selection retains original profile: " + id)
  check(game.specials.definition.selection_label.contains(game.specials.action.label()), "Selection names the shared type action: " + id)
 var speed: TypeAction = CharacterSpecials.CHARACTERS.sonic.type_action
 var velocity := Vector2(-100, 150)
 var next := speed.guided_velocity(velocity, Vector2(398, 0), 44.0, 1.0 / 120.0)
 check(next.distance_to(velocity) <= speed.dash_acceleration / 120.0 + 0.001, "Guidance bounds per-step acceleration")
 check(speed.dash_duration(398, 0) > speed.dash_duration(48, 0), "Distance increases approach time, not speed")
 game.free()
 await frames(3)
 print("RESULT | Four shared type characters | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
