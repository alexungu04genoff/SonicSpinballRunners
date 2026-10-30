extends "res://tests/scoring_flow_regression.gd"
## Exercise production score wiring, physical ring claims and live feature state.
const V1_PATH := "res://test-results/economy-v1-act.tres"

func body_for(id: String) -> Node2D:
 for item: Dictionary in game.authored_runtime.objects:
  if item.object_id == id: return item.body
 return null

func spin(count: int) -> void:
 for i in count:
  manager.by_id.spinner.spin = PI * 1001.0
  manager.tick(0.001)
 manager.by_id.spinner.spin = 0.0

func cross(index: int) -> void:
 var posts: PackedVector2Array = manager.by_id.lanes.posts
 var at := (posts[index] + posts[index + 1]) * 0.5
 manager._observe_travel(null, at + Vector2(0, 35), at - Vector2(0, 35))

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var document := fixture()
 document.score_target = 0
 for i in 4:
  document.gameplay_objects.append(object("switch_target" if i < 3 else "wall_switch", "switch_%d" % i, Vector2(100 + i * 100, 200)))
 document.gameplay_objects.append(object("spinner", "spinner", Vector2(500, 200)))
 document.gameplay_objects.append(object("lane_barrier", "lanes", Vector2(100, 350), {"points": PackedVector2Array([Vector2.ZERO, Vector2(80, 0), Vector2(160, 0)])}))
 document.gameplay_objects.append(object("buzz_bomber", "enemy", Vector2(400, 800), {"patrol_left": 0.0, "patrol_right": 0.0}))
 document.switch_banks = [{"bank_id": "bank", "label": "Repeatable test", "members": ["switch_0", "switch_1", "switch_2", "switch_3"], "gates": [], "completion_bonus": 500.0, "reset_delay": 0.5}]
 document.ring_trails = [{"start": Vector2(100, 450), "end": Vector2(140, 450), "spacing": 20.0}]
 check(document.save_document(V1_PATH) == OK, "Save V1 integration fixture")
 game = ObservedGame.new()
 game.authored_act_path = V1_PATH
 game.scorecraft_config = ScorecraftConfig.new()
 game.scorecraft_config.multiplier_cap = 4
 game.scorecraft_config.tiered_decay = true
 root.add_child(game)
 await frames(6)
 check(game.last_source_error.is_empty(), "V1 fixture loads in the shared game", game.last_source_error)
 if not game.last_source_error.is_empty(): game.free(); quit(1); return
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.scorecraft.set_physics_process(false)
 game.specials.set_physics_process(false)
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.ball.position = Vector2(900, 900)
 manager = game.authored_runtime.mechanics
 var scoring: Scorecraft = game.scorecraft
 var awards: Array = []
 scoring.score_awarded.connect(func(details): awards.append(details))
 game._on_bumper_hit(body_for("bumper_a"))
 check(scoring.multiplier == 1 and scoring.chain == 1, "First real bumper award starts visible x1")
 game.ring_field.claim_ring(0)
 game.ring_field.claim_ring(1)
 game._on_bumper_hit(body_for("bumper_b"))
 check(scoring.multiplier == 2 and scoring.chain == 2 and scoring.ring_progress == 2, "Second builder reaches x2 and preserves Ring Link 2/3")
 game.ring_field.claim_ring(2)
 check(scoring.multiplier == 3 and scoring.chain == 3 and scoring.ring_progress == 0 and not scoring.ring_link_available, "Third physical ring reaches x3 exactly and consumes the link")
 spin(10)
 check(scoring.multiplier == 4 and scoring.chain == 4 and scoring.last_award.normal_total == 300 and not scoring.ring_link_available, "Actual ten-tick Spinner Goal pays fixed 300 and builds x4")
 scoring.remaining = 0.4
 var before: int = game.score
 spin(10)
 check(game.score - before == 500 and scoring.remaining == 0.4 and scoring.chain == 4, "Repeated Spinner Goal pays 10x5x4 + 300 without advancing or refreshing")
 scoring._physics_process(0.4)
 check(scoring.multiplier == 3 and scoring.chain == 3 and not scoring.ring_link_available, "Decay to x3 has no stored Ring Link or hidden tier")
 scoring._physics_process(3.0)
 check(scoring.multiplier == 2 and scoring.chain == 2, "Tiered decay reaches x2")
 scoring._physics_process(3.0)
 check(scoring.chain == 0, "Next decay ends the chain")
 spin(10)
 check(scoring.chain == 1, "Same Spinner Goal becomes a builder after the previous chain ends")

 # Four target awards at x4 plus a fixed bank completion must total 900.
 scoring.chain = 4
 scoring.multiplier = 4
 scoring.remaining = 0.2
 before = game.score
 manager._activate_switch(manager.by_id.switch_0)
 check(scoring.last_award.normal_total == 100 and scoring.remaining == 3.0, "Switch pays 25x4 and extends the active combo")
 for i in range(1, 4): manager._activate_switch(manager.by_id["switch_%d" % i])
 check(game.score - before == 900 and scoring.last_award.normal_total == 500, "Four switches plus bank pay 900, never 2400")
 manager.tick(0.5)
 scoring.remaining = 0.3
 before = game.score
 for i in 4: manager._activate_switch(manager.by_id["switch_%d" % i])
 check(game.score - before == 900 and scoring.remaining == 0.3, "Rearmed targets and bank pay again without farming support or tiers")
 scoring.reset("Outside combo")
 manager.tick(0.5)
 manager._activate_switch(manager.by_id.switch_0)
 check(scoring.chain == 0 and scoring.last_award.normal_total == 25, "A standalone switch activation cannot start a combo")

 scoring.award_bumper(body_for("bumper_a"))
 scoring.award_bumper(body_for("bumper_b"))
 scoring.remaining = 0.2
 cross(0)
 check(scoring.last_award.kind == "lane" and scoring.last_award.object_id.ends_with(":lane:0") and scoring.last_award.normal_total == 100 and scoring.remaining == 3.0, "First physical lane has its own stable source and pays 50x2")
 scoring.remaining = 0.2
 cross(1)
 check(scoring.last_award.kind == "lane_set" and scoring.last_award.normal_total == 500 and scoring.multiplier == 3, "Second lane supports independently and completes a fixed 500-point builder")
 manager.tick(1.5)
 scoring.remaining = 0.2
 cross(0)
 cross(1)
 check(scoring.remaining == 0.2 and scoring.multiplier == 3, "Repeating the same lanes and set cannot maintain this chain")
 var link_before := scoring.ring_link_available
 scoring.award_rack()
 check(scoring.last_award.normal_total == 500 and scoring.multiplier == 3 and scoring.remaining == 3.0 and scoring.ring_link_available == link_before, "Rack remains fixed and supports without a tier or another Ring Link")
 scoring.reset("Rack alone")
 scoring.award_rack()
 check(scoring.chain == 0 and not scoring.ring_link_available, "Rack completion alone cannot start a combo or enable a link")

 scoring.award_bumper(body_for("bumper_a"))
 scoring.remaining = 0.4
 check(not scoring.traversal_event(&"elevated_rail", "no_entry", &"completed") and scoring.remaining == 0.4, "Rail completion without genuine entry gives no support")
 scoring.traversal_event(&"elevated_rail", "ride", &"entered")
 scoring.traversal_event(&"elevated_rail", "ride", &"exited")
 check(scoring.remaining == 0.4, "Aborted or rolled-back rail exit cannot refresh")

 var enemies: RefCounted = manager.enemies
 var enemy: Dictionary = enemies.by_id.enemy
 before = game.score
 check(enemies.destroy("enemy") and game.score - before == 400 and scoring.multiplier == 2, "Enemy destruction builds one visible tier and pays 200x2")
 check(not enemies.destroy("enemy"), "Enemy destruction is atomic")
 enemies.tick(5.0)
 var remaining: float = enemy.respawn_remaining
 manager.reset_for_retry()
 check(remaining == 10.0 and enemy.respawn_remaining == remaining, "Soft retry preserves the exact enemy countdown")
 manager.scoring_active = false
 manager.tick(20.0)
 check(enemy.respawn_remaining == remaining, "Inactive Act cannot advance respawn")
 manager.scoring_active = true
 game.ball.serve_pending = true
 manager.tick(20.0)
 check(enemy.respawn_remaining == remaining, "Serve and protected transfer gating pause enemy timers")
 game.ball.serve_pending = false
 game.ball.position = enemy.anchor
 enemies.tick(10.0)
 enemies.tick(1.0)
 check(enemy.respawn_ready and not enemy.alive and enemy.respawn_fade == 0.0, "Expired enemy waits safely while the Ball occupies its spawn region")
 game.ball.position = Vector2(900, 900)
 enemies.tick(0.01) # The last swept position must also clear.
 enemies.tick(0.2)
 check(not enemy.alive and enemy.respawn_fade > 0 and game.enemy_targets().is_empty(), "Respawn appearance remains noninteractive")
 game.ball.position = enemy.anchor
 enemies.tick(0.1)
 check(enemy.respawn_fade == 0, "Returning Ball cancels an unsafe appearance")
 game.ball.position = Vector2(900, 900)
 enemies.tick(0.01)
 enemies.tick(0.35)
 check(enemy.alive and enemy.position == enemy.anchor and enemy.direction == 1.0 and enemy.pause_remaining == enemies.PATROL_PAUSE_SECONDS, "Safe respawn restores deterministic authored start and hover")
 scoring.remaining = 0.25
 before = game.score
 check(enemies.destroy("enemy") and game.score - before == 400 and scoring.multiplier == 2 and scoring.remaining == 0.25, "Same respawned source scores normally without rebuilding its still-active chain")

 # Both finishers consume a pre-hit x4 without an ordinary target award.
 scoring.chain = 4
 scoring.multiplier = 4
 game.specials.pending_target = body_for("bumper_a")
 game.specials.homing_remaining = 1.0
 game.specials.homing_direction = Vector2.UP
 before = game.score
 game._on_bumper_hit(body_for("bumper_a"))
 check(game.score - before == 800 and scoring.chain == 0, "Already-used bumper Homing cashes out 100x4 + 400 exactly once")
 enemies.tick(15.0)
 enemies.tick(0.35)
 scoring.chain = 4
 scoring.multiplier = 4
 game.specials.pending_target = body_for("enemy")
 game.specials.homing_remaining = 1.0
 game.specials.homing_direction = Vector2.UP
 before = game.score
 var event_count := awards.size()
 enemies.destroy("enemy")
 check(game.score - before == 1200 and scoring.chain == 0 and awards.size() == event_count + 1 and not enemy.alive, "Enemy Homing destroys once and cashes out 200x4 + 400 through one score event")
 scoring.award_bumper(body_for("bumper_a"))
 manager.tick(1.5)
 manager.by_id.lanes.properties.reward_type = "rings"
 manager.by_id.lanes.properties.completion_bonus = 0
 scoring.remaining = 0.2
 before = game.score
 var ring_progress := scoring.ring_progress
 var meter: float = game.special_meter
 cross(0)
 check(game.score == before and scoring.remaining == 3.0 and scoring.ring_progress == ring_progress and game.special_meter == meter, "Virtual-ring lane supports once without physical Ring score, Link progress or meter")
 cross(1)
 check(scoring.multiplier == 2 and game.score == before, "Explicit zero-bonus Lane Set still builds without inventing score")
 manager.tick(1.5)
 scoring.reset("Zero-score support")
 scoring.award_bumper(body_for("bumper_a"))
 manager.by_id.lanes.properties.lane_reward = 0
 scoring.remaining = 0.2
 cross(0)
 check(scoring.remaining == 3.0, "Zero-score lane still acts as an extender")
 for i in range(1, 4): manager._activate_switch(manager.by_id["switch_%d" % i])
 manager.tick(0.5)
 scoring.reset("Zero-score switch")
 scoring.award_bumper(body_for("bumper_a"))
 manager.by_id.switch_0.properties.score_reward = 0
 scoring.remaining = 0.2
 manager._activate_switch(manager.by_id.switch_0)
 check(scoring.remaining == 3.0, "Zero-score switch still acts as an extender")

 enemies.tick(15.0)
 enemies.tick(0.35)
 scoring.reset("Target priorities")
 game.ball.freeze = false
 game.ball.teleport_to(Vector2(100, 1000), Vector2.ZERO, false)
 await frames(3)
 game.ball.freeze = true
 check(game.specials.find_target() == body_for("bumper_a"), "Homing keeps nearest clear target within the fresh priority class")
 scoring.award_bumper(body_for("bumper_a"))
 check(game.specials.find_target() == body_for("bumper_b"), "Fresh farther bumper outranks the nearest already-used bumper")
 var owner: String = body_for("bumper_b").get_meta("scoring_owner")
 body_for("bumper_b").set_meta("scoring_owner", "inactive_neighbor")
 check(game.specials.find_target() == body_for("enemy"), "Inactive neighboring bumper cannot steal Homing priority")
 body_for("bumper_b").set_meta("scoring_owner", owner)
 scoring.award_bumper(body_for("bumper_b"))
 check(game.specials.find_target() == body_for("enemy"), "Fresh clear enemy outranks already-used bumpers")
 scoring.award_mechanic(&"enemy", str(body_for("enemy").get_meta("scoring_source")), 200)
 check(game.specials.find_target() == body_for("enemy"), "Already-used enemy remains preferable to already-used bumpers")
 game.ball.freeze = false
 game.ball.teleport_to(Vector2(950, 50), Vector2.ZERO, false)
 await frames(3)
 game.ball.freeze = true
 game.special_meter = 100
 check(not game.specials.activate() and game.special_meter == 100, "No valid clear Homing target retains all meter")
 game.free()
 await frames(3)
 print("RESULT | Economy V1 integration | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
