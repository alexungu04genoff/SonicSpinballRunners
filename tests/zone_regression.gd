extends "res://tests/score_attack_regression.gd"
## State fixtures plus real high-speed 2D gate collisions; not the input-only witness.
func run() -> void:
 game = load("res://scenes/playground.tscn").instantiate()
 game.zone_enabled = true
 game.score_attack_enabled = true
 game.generation_seed = 18
 root.add_child(game)
 await frames(5)
 check(game.layout.valid and game.chunks.size() == 9 and game.zone_gates.size() == 2, "Zone builds nine connected sections and two physical gates")
 check(game.zone.active_act == 0 and game.score == 0 and game.tuning.build_ids.is_empty(), "Zone starts Act 1 with empty score and build")
 check(not game.score_attack_enabled and game.score_attack.state == ScoreAttack.State.FREE_PLAY, "Zone and standalone challenge cannot both activate on startup")
 var identity: int = game.ball.get_instance_id()
 var gate_y: float = game.zone.acts[0].exit_y
 var gate_x: float = (game.zone.acts[0].exit_left + game.zone.acts[0].exit_right) * 0.5
 game.ball.teleport_to(Vector2(gate_x, gate_y + 90), Vector2(0, -12000))
 game.controls.virtual_enabled = true
 var crossed_locked := false
 for i in 24:
  await frames(1)
  crossed_locked = crossed_locked or game.ball.position.y < gate_y
 check(not crossed_locked and game.zone.completed_acts == 0, "12,000 px/s shot rebounds from locked gate without skipping Act")
 game.score = game.zone.targets[0] - 25
 game._observe_challenge_score()
 check(not game.zone.exit_unlocked, "Act exit remains locked below exact threshold")
 game._on_ring_collected(Vector2.ZERO)
 check(game.zone.exit_unlocked and game.zone.state == ZoneRun.State.PLAYING, "Existing ring score event unlocks exactly at target without completing Act")
 await frames(2)
 check(game.zone_gates[0].collision_layer == 0 and game.zone_gates[1].collision_layer == 1, "Only current unlocked gate opens; next Act remains gated")
 game.ball.teleport_to(Vector2(gate_x, gate_y + 90), Vector2(0, -1700))
 game._goal_motion_ready = false
 for i in 60:
  await frames(1)
  if game.zone.state == ZoneRun.State.DRAFT:
   break
 check(paused and game.zone.state == ZoneRun.State.DRAFT and game.zone.completed_acts == 1, "Physical upward crossing pauses at first mandatory Chao draft")
 var at_draft: Vector2 = game.ball.position
 var velocity: Vector2 = game.ball.linear_velocity
 game.toggle_pause()
 game.reset_ball(true)
 check(paused and game.ball.position == at_draft and not game.request_generation(19), "Pause/reset/regeneration cannot bypass mandatory reward")
 await frames(4)
 check(game.ball.position == at_draft and game.ball.linear_velocity == velocity, "Draft preserves exact ball position and velocity while paused")
 check(game.choose_zone_chao("spring"), "Accept first reward through centralized build resolver")
 check(not paused and game.zone.active_act == 1 and game.zone.act_score == 0 and game.score >= game.zone.targets[0], "Next Act resets only its score and resumes")
 check(game.ball.get_instance_id() == identity and game.ball.position == at_draft and game.ball.linear_velocity == velocity and not game.ball._teleport_pending, "Transition keeps same physics body and momentum without teleport")
 await frames(2)
 check(game.zone_gates[0].collision_layer == 1 and game.tuning.build_ids == ["spring"], "Completed boundary seals behind ball and reward equips once")
 var total: int = game.score
 game.ball.teleport_to(game.zone.acts[1].drain - Vector2(0, 30), Vector2(0, 800))
 game._goal_motion_ready = false
 await frames(3)
 check(game.respawn_time > 0, "Falling through the generated central opening triggers current checkpoint drain")
 await frames(110)
 check(game.zone.active_act == 1 and game.score >= total and game.tuning.build_ids == ["spring"] and game.ball.serve_position == game.zone.acts[1].entry, "Automatic checkpoint retry retains Act, total score and Chao")
 var future_ring: Dictionary = {}
 for ring: Dictionary in game.ring_field.rings:
  if game.zone.acts[2].bounds.has_point(ring.home):
   future_ring = ring
   break
 check(not game.ring_field.ring_eligible(future_ring), "Future Act ring rack cannot be farmed by an oversized boundary magnet")
 game.score += game.zone.targets[1]
 game._observe_challenge_score()
 await frames(2)
 gate_y = game.zone.acts[1].exit_y
 game.ball.teleport_to(Vector2(400, gate_y + 90), Vector2(0, -1700))
 game._goal_motion_ready = false
 for i in 60:
  await frames(1)
  if game.zone.state == ZoneRun.State.DRAFT:
   break
 check(game.zone.state == ZoneRun.State.DRAFT and game.choose_zone_chao("magnet"), "Second physical boundary awards second Chao")
 check(game.zone.active_act == 2 and game.zone.act_score == 0 and not game.zone.exit_unlocked and game.tuning.build_ids == ["spring", "magnet"], "Act 3 ignores earlier cumulative points and combines upgrades")
 game.ball.teleport_to(game.zone.acts[2].goal_position, Vector2.ZERO)
 game._goal_motion_ready = false
 await frames(3)
 check(game.zone.state == ZoneRun.State.PLAYING, "Locked final portal cannot finish from earlier Acts' total score")
 game.score += game.zone.targets[2]
 game._observe_challenge_score()
 game.ball.teleport_to(game.zone.acts[2].goal_position, Vector2.ZERO)
 game._goal_motion_ready = false
 await frames(3)
 check(game.zone.state == ZoneRun.State.DRAFT and game.zone.completed_acts == 3, "Unlocked final portal triggers third reward")
 check(game.choose_zone_chao("ice") and game.zone.state == ZoneRun.State.COMPLETE and paused, "Final reward appears in complete build before Zone victory")
 var signature: String = game.layout.signature
 check(game.request_generation(game.generation_seed), "Zone victory offers same-seed replay")
 await frames(6)
 check(game.layout.signature == signature and game.zone.active_act == 0 and game.zone.completed_acts == 0 and game.score == 0 and game.tuning.build_ids.is_empty() and not paused, "Replay clears gates, score, rewards and victory while keeping identical geometry")
 check(game.presentation.table_bounds == game.layout.bounds and game.layout.bounds.size.y == 6300, "Follow and overview derive full nine-chunk camera bounds")
 paused = true
 check(game.request_generation(18, 1, 0, {"zone": false, "enabled": true}), "Switch from Zone to standalone Score Attack")
 await frames(6)
 check(game.chunks.size() == 3 and game.zone_gates.is_empty() and game.zone.state == ZoneRun.State.INACTIVE and game.score_attack.state == ScoreAttack.State.LOCKED, "Standalone mode has no stale Zone gate, build or victory")
 check(not game.ring_field.collection_bounds.has_area(), "Sandbox ring collection restores unrestricted rack")
 game.tuning.equip_chao("ice")
 for mode in [1, 2]:
  game.request_generation(18, TableGenerator.Difficulty.HARD, mode, {"zone": true})
  await frames(6)
  var grid_signature: String = game.layout.signature
  check(game.generation_grid_mode == mode and game.generation_difficulty == TableGenerator.Difficulty.EASY and game.tuning.build_ids.is_empty(), "Zone uses selected grid %d with Easy geometry and fresh build" % mode)
  game.request_generation(18)
  await frames(6)
  check(game.layout.signature == grid_signature and game.generation_grid_mode == mode, "Same-seed Zone replay preserves grid %d" % mode)
 var before_invalid: String = game.layout.signature
 game.zone_config = game.zone_config.duplicate()
 game.zone_config.act_targets.assign([750])
 game.request_generation(19)
 await frames(4)
 check(game.layout.signature == before_invalid and game.zone.targets.size() == 3, "Invalid Zone configuration preserves active table and objective")
 game.zone_config.act_targets.assign([750, 1250, 1750])
 game.request_generation(18, 0, 0, {"zone": false, "enabled": false})
 await frames(6)
 check(game.tuning.build_ids == ["ice"] and game.zone.state == ZoneRun.State.INACTIVE, "Leaving Zone restores prior sandbox Chao without leaking acquired rewards")
 paused = false
 game.free()
 print("RESULT | Zone | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
