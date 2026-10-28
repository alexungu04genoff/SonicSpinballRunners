extends SceneTree
## Real streaming game, real resident Acts, real reward and activation callbacks.
## Seed 34 starts Secret Entry, RampMania: different heights, both with ring trails.
const Game = preload("res://scripts/endless/endless_game.gd")
const Exit = preload("res://scripts/authored_act/score_exit.gd")
var game: Node
var checks := 0
var failures := 0
var deadline := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
 checks += 1
 if ok: print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func next_act() -> RefCounted:
 for act: RefCounted in game.resident:
  if act.plan.sequence == game.active_sequence + 1: return act
 return null

func first_bumper(act: RefCounted) -> Node2D:
 for item: Dictionary in act.runtime.objects:
  if item.body.has_meta("bumper"): return item.body
 return null

func ring_index(owner: String, active_only := true) -> int:
 for index in game.ring_field.rings.size():
  var ring: Dictionary = game.ring_field.rings[index]
  if ring.rack.owner_id == owner and (not active_only or ring.active): return index
 return -1

func crossing(act: RefCounted) -> void:
 var line: Vector2 = act.plan.offset + Vector2(act.document.terrain_bounds().size.x * 0.5, act.document.activation_y)
 game._observe_authored_motion(line + Vector2.DOWN * 10, line + Vector2.UP * 10)

func finish() -> void:
 game.set_process(false)
 game.set_physics_process(false)
 while game.library != null and game.library.busy and Time.get_ticks_msec() < deadline:
  await process_frame
 print("RESULT | Endless scoring | %d checks | %d failures" % [checks, failures])
 game.free()
 quit(0 if failures == 0 else 1)

func run() -> void:
 deadline = Time.get_ticks_msec() + 240000
 game = Game.new()
 root.add_child(game)
 while not game.started and Time.get_ticks_msec() < deadline:
  await process_frame
 check(game.started and game.resident.size() >= 2, "Actual Endless builds its opening resident Acts within 240 seconds")
 if not game.started:
  await finish()
  return
 game.set_process(false)
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.scorecraft.set_process(false)
 game.ball.freeze = true
 game.ball.serve_pending = false
 game.ball._teleport_pending = false
 var first: RefCounted = game.active
 var second: RefCounted = next_act()
 check(second != null and not first.ring_data.is_empty() and not second.ring_data.is_empty(), "Selected published Acts contain physical ring patterns")
 if second == null or first.ring_data.is_empty() or second.ring_data.is_empty():
  await finish()
  return
 var first_owner := "act:%d" % first.plan.sequence
 var second_owner := "act:%d" % second.plan.sequence
 check(game.act_score_target == 0 and game.exit_unlocked, "Existing target-free Endless starts with an open exit")
 check(first.document.grid_size != second.document.grid_size and second.plan.offset == Game.Plan.aligned_offset(first.document, first.plan.offset, second.document), "Different authored Act heights retain actual connector alignment")
 check(first.runtime.mechanics.scoring_active and not second.runtime.mechanics.scoring_active, "Loaded neighboring mechanics are distinct from the active scoring Act")

 first.runtime.mechanics.complete_feature(&"switch_bank", "stream_fixture", 1000)
 var total: int = game.score
 second.runtime.mechanics.mechanic_score.emit(&"spinner_tick", "inactive_spinner", 5)
 second.runtime.mechanics.complete_feature(&"switch_bank", "inactive_bank", 500)
 var inactive_index := ring_index(second_owner)
 check(not game.ring_field.claim_ring(inactive_index, "chaos_blast") and game.score == total, "Inactive resident rewards and remote physical ring claims produce no score")
 var first_index := ring_index(first_owner)
 check(game.ring_field.claim_ring(first_index) and game.score == total + 25, "Active resident physical ring uses the main Scorecraft award path")
 var first_rack: Dictionary = game.ring_field.rings[first_index].rack
 game.ring_field.advance_racks(2.0)
 var first_remaining: float = first_rack.timeout_remaining
 var first_body := first_bumper(first)
 var second_body := first_bumper(second)
 check(is_instance_valid(first_body) and is_instance_valid(second_body), "Published scoring fixtures expose real authored bumper bodies")
 if is_instance_valid(first_body):
  game._on_bumper_hit(first_body)
 check(game.scorecraft.chain > 0, "First resident's actual bumper callback starts Scorecraft")
 total = game.score

 # Opt in one actual streamed document without editing an authored file or bake.
 second.document = second.document.copy_document()
 second.document.score_target = 500
 var barrier := Exit.new()
 second.root.add_child(barrier)
 barrier.configure(second.document, second.plan.offset, game.presentation, true)
 second.runtime.score_exit = barrier
 var position_before: Vector2 = game.ball.position
 crossing(second)
 check(game.active == second and game.act_score == 0 and game.score == total and game.scorecraft.chain == 0, "Real activation crossing resets only Act score and combo, preserving cumulative score")
 check(game.ball.position == position_before and game.ball.serve_position == second.spawn(), "Activation transfers checkpoint without teleporting the ball")
 check(game.act_score_target == 500 and not game.exit_unlocked and not barrier.unlocked, "Prior Act's larger total cannot unlock the next scored Act")
 await process_frame
 check(barrier.collision_layer == 1, "Scored streamed Exit installs its separate physical barrier")
 var expected_exit: Vector2 = second.plan.offset + Vector2((second.document.exit_start_x + second.document.exit_width * 0.5) * second.document.cell_size, 0)
 check(barrier.position.is_equal_approx(expected_exit), "Scored Exit uses the streamed Act's world offset and authored connector width")
 crossing(second)
 check(game.active == second and game.act_score == 0, "Repeating the same activation cannot reset the current scoring window")

 var before_inactive: int = game.score
 first.runtime.mechanics.mechanic_score.emit(&"switch_bank", "old_bank", 500)
 if is_instance_valid(first_body):
  check(not game.activate_area_target(first_body, "chaos_blast", 1), "Character area scoring rejects a previous resident Act's actual bumper")
 game.ring_field.advance_racks(2.0)
 check(game.score == before_inactive and is_equal_approx(first_rack.timeout_remaining, first_remaining), "Previous Act rewards and ring timers stop when its scoring context ends")
 var second_index := ring_index(second_owner)
 var meter: float = game.special_meter
 game.ring_field.claim_ring(second_index, "chaos_blast")
 check(game.act_score == 25 and game.special_meter == meter, "Active remote physical pickup scores locally without charging the special meter")
 if is_instance_valid(second_body): game.activate_area_target(second_body, "chaos_blast", 1)
 check(game.act_score == 125 and game.scorecraft.chain == 0, "Active area bumper score enters the new Act ledger without creating combos")
 var needed: int = game.act_score_target - game.act_score
 var before_bonus: int = game.score
 second.runtime.mechanics.complete_feature(&"switch_bank", "unlock_bank", needed)
 check(game.score == before_bonus + needed and game.act_score == 500 and game.exit_unlocked and barrier.unlocked, "One fixed completion award unlocks the Act exactly once through shared listeners")
 check(game.ball.position == position_before, "Reaching a streamed Act target leaves the physical ball in place")
 await process_frame
 check(barrier.collision_layer == 0, "Unlocking removes only the score barrier's collision")
 var breakdown_total := 0
 for points: int in game.act_score_breakdown.values(): breakdown_total += points
 check(breakdown_total == game.act_score, "Actual award categories sum to the current Act ledger")

 var before_drain: int = game.score
 game.ball.position.y = second.document.red_gutter_bounds().end.y + second.plan.offset.y + 1.0
 game._physics_process(1.0 / 120.0)
 check(game.respawn_time > 0.0 and game.score == before_drain and game.act_score == 500 and game.exit_unlocked and not game.ring_field.scoring_enabled, "Actual checkpoint drain retains earned score and unlocked Exit while suspending physical pickups")
 game._physics_process(0.7)
 check(game.score == before_drain and game.act_score == 500 and game.exit_unlocked and game.ring_field.scoring_enabled, "Ordinary checkpoint retry retains both score ledgers and the unlocked Exit")
 game.auto_launch_time = -1.0
 game.ball.serve_pending = true
 game.ball._teleport_pending = false

 # Let the same rolling streamer prepare the next Act, then exercise retirement.
 game.set_process(true)
 while not game._next_ready() and Time.get_ticks_msec() < deadline:
  await process_frame
 game.set_process(false)
 var third: RefCounted = next_act()
 check(third != null and game._next_ready(), "Normal rolling streamer supplies the third Act before the shared deadline")
 if third != null:
  game.ball.serve_pending = false
  var total_before_third: int = game.score
  var line: Vector2 = third.plan.offset + Vector2(third.document.terrain_bounds().size.x * 0.5, third.document.activation_y)
  game.previous_goal_position = line + Vector2.DOWN * 10
  game._goal_motion_ready = true
  game.ball.position = line + Vector2.UP * 10
  game.ball.on_ramp = true
  game._physics_process(1.0 / 120.0)
  check(game.active == third and game.act_score == 0 and game.score == total_before_third and game.exit_unlocked, "Main physics loop activates the next Act even during authoritative rail travel")
  check(game.ball.on_ramp and game.ball.position == line + Vector2.UP * 10, "Rail-state activation leaves the constrained ball and its movement state intact")
  game.ball.on_ramp = false
  game.presentation.camera_focus = third.bounds().get_center()
  game._retire_behind()
  check(not game.resident.has(first) and not game.hub.runtimes.has(first.runtime.mechanics), "Actual retirement removes the old Act from resident physics and mechanics ownership")
  first.runtime.mechanics.mechanic_score.emit(&"spinner_tick", "retired_spinner", 5)
  check(game.score == total_before_third and ring_index(first_owner, false) == -1 and not game.ring_field.ring_eligible(first.ring_data[0]), "Retired Act callbacks and old physical ring records cannot affect the active score")
 await finish()
