extends SceneTree
## Focused rack lifecycle checks use the actual main game and its scoring listeners.
const Trails = preload("res://scripts/act_editor/ring_trails.gd")
var game: Node
var field: RingField
var checks := 0
var failures := 0
var completions: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
 checks += 1
 if ok: print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func pattern(id: String, bonus := false) -> Dictionary:
 return {"pattern_id": id, "start": Vector2(100, 100), "end": Vector2(140, 100), "spacing": 20.0, "bonus_rack": bonus, "completion_bonus": 500}

func run() -> void:
 game = load("res://scenes/playground.tscn").instantiate()
 root.add_child(game)
 for i in 4:
  await physics_frame
  await process_frame
 game.set_physics_process(false)
 game.presentation.set_process(false)
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 game.ball.position = Vector2(2000, 500)
 field = game.ring_field
 field.set_physics_process(false)
 field.previous_ball_position = game.ball.position
 field.pickup_claimed.disconnect(game.presentation._on_ring_claimed)
 field.rack_reset.disconnect(game.presentation.clear_ring_pickups)
 field.feature_completed.connect(func(_kind: StringName, id: String, _bonus: int): completions.append(id))
 field.active_owner_id = "standalone"
 field.rings = RingField.pattern_records([pattern("ordinary"), pattern("bonus", true)], "standalone")
 game.score = 0
 game.rings_collected = 0
 game.special_meter = 0
 game.scorecraft.reset("Ring fixture", true)

 field.claim_ring(0)
 field.advance_racks(6.0)
 field.claim_ring(1)
 check(is_equal_approx(field.rings[0].rack.timeout_remaining, 19.0), "Later pickups do not extend the first-pickup timeout")
 field.advance_racks(19.0)
 check(field.rings[0].rack.ready and not field.claim_ring(2), "Expired partial pattern waits without collectible remnants")
 field.advance_racks(0.35)
 check(field.rings[0].active and field.rings[1].active and field.rings[2].active and completions.is_empty() and game.score == 30, "Incomplete ordinary pattern fully respawns at timeout without a bonus")

 field.claim_ring(3)
 field.claim_ring(4, "chaos_blast", 2)
 field.claim_ring(5)
 check(game.score == 590 and game.rings_collected == 5 and game.special_meter == 20 and completions == ["standalone:bonus"], "Contact and remote claims share one completion with fixed bonus and physical-only meter")
 check(not field.claim_ring(5) and completions.size() == 1, "Repeated claim cannot award the same completion twice")
 field.advance_racks(1.0)
 check(not field.rings[3].active, "Bonus Rack does not return after the historical one-second delay")
 field.advance_racks(9.99)
 check(not field.rings[3].active and field.rings[0].active, "Completed pattern waits independently while another pattern stays available")
 field.advance_racks(0.02)
 check(field.rings[3].rack.ready and not field.claim_ring(3), "Bonus Rack waits eleven seconds then enters safe reactivation")
 game.ball.position = Vector2(120, 100)
 field.advance_racks(2.0)
 check(not field.rings[3].active and field.rings[3].rack.fade == 0.0, "Ready rack cannot respawn around the Ball")
 game.ball.position = Vector2(2000, 500)
 field.advance_racks(0.2)
 check(not field.claim_ring(3) and RingField.visibility_alpha(field.rings[3]) > 0.0, "Fade is visible but not collectible")
 game.ball.position = Vector2(120, 100)
 field.advance_racks(0.2)
 check(field.rings[3].rack.fade == 0.0, "Returning Ball cancels the fade before activation")
 game.ball.position = Vector2(2000, 500)
 field.advance_racks(0.35)
 check(field.rings[3].active and field.rings[4].active and field.rings[5].active and field.rings[3].rack.remaining == 3, "Completion delay rearms only its own complete pattern")

 field.claim_ring(3)
 field.advance_racks(12.0)
 field.advance_racks(0.35)
 field.claim_ring(4)
 field.claim_ring(5)
 check(completions.size() == 1 and field.rings[3].active and field.rings[3].rack.remaining == 1, "Timeout discards partial progress and cannot create a phantom clear")
 var before_virtual: int = game.score
 var before_meter: int = game.special_meter
 var before_count: int = game.rings_collected
 game._on_mechanic_rings(&"lane", "virtual_lane", 10)
 check(game.rings_collected == before_count + 10 and game.score == before_virtual and game.special_meter == before_meter and field.rings[3].rack.remaining == 1 and completions.size() == 1, "Virtual lane rings affect only the counter, never rack progress, score, or meter")

 var neighbor := RingField.pattern_records([pattern("bonus", true)], "act:2")
 field.rings.append_array(neighbor)
 check(not field.claim_ring(6) and field.rings[6].active, "Loaded neighboring Act cannot yield physical rings")
 var active_timer: float = field.rings[3].rack.timeout_remaining
 field.active_owner_id = "act:2"
 game.active_scoring_id = "act:2"
 game.scorecraft.act_context = "act:2"
 field.claim_ring(6)
 field.advance_racks(4.0)
 check(is_equal_approx(field.rings[3].rack.timeout_remaining, active_timer) and is_equal_approx(field.rings[6].rack.timeout_remaining, 8.0), "Only active Act racks advance; neighboring instances keep independent state")
 field.scoring_enabled = false
 field.advance_racks(2.0)
 check(not field.claim_ring(7) and is_equal_approx(field.rings[6].rack.timeout_remaining, 8.0), "Drain/loading suspension stops claims and rack timers")
 field.scoring_enabled = true
 field.rings = neighbor
 check(field.rings[0].rack.timeout_remaining == 8.0 and field.rings[0].source_id == "act:2:bonus:ring_0", "Resident synchronization retains state and stable source identity")

 field.rings.clear()
 field.add_ring(Vector2(100, 100))
 var before_single: int = game.score
 field.claim_ring(0)
 check(game.score == before_single + 15 and completions.size() == 1, "Ordinary single ring never becomes an implicit +500 rack")
 field.advance_racks(1.0)
 check(not field.rings[0].active, "Ordinary full clear does not respawn after one second")
 field.advance_racks(16.99)
 check(not field.rings[0].rack.ready, "Ordinary full clear waits the full eighteen seconds")
 field.advance_racks(0.02)
 field.advance_racks(0.35)
 check(field.rings[0].active, "Ordinary full clear safely restores after eighteen seconds plus fade")
 field.reset_rings()
 check(field.rings[0].active and field.rings[0].rack.timeout_remaining == -1.0 and field.rings[0].rack.respawn_remaining == -1.0, "Explicit lifecycle reset clears rack clocks and restores physical rings")

 var invalid := pattern("bad")
 invalid.timeout = NAN
 check(not Trails.validation_error(invalid).is_empty(), "Non-finite rack timing is rejected")
 invalid = pattern("bad")
 invalid.completion_bonus = 500.5
 check(not Trails.validation_error(invalid).is_empty(), "Fractional fixed bonuses are rejected")
 print("RESULT | Ring racks | %d checks | %d failures" % [checks, failures])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
