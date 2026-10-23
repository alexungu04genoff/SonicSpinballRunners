extends SceneTree
## Standalone lifecycle/placement checks. Run without --headless to save HUD captures.
var checks := 0
var failures := 0
var game: Node
var green_hill := false

func _initialize() -> void:
 call_deferred("run")

func frames(count: int = 4) -> void:
 for i in count:
  await physics_frame
  await process_frame

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless":
  return
 await create_timer(0.25).timeout
 await RenderingServer.frame_post_draw
 var directory := "res://test-results"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 var prefix := "green-hill-score-attack-" if green_hill else "score-attack-"
 var result := root.get_texture().get_image().save_png(directory.path_join(prefix + label + ".png"))
 if result != OK:
  failures += 1
  push_error("Capture failed: " + error_string(result))

func run() -> void:
 green_hill = OS.get_cmdline_user_args().has("--green-hill")
 var state := ScoreAttack.new()
 var goal := Vector2(400, 250)
 state.reset(true, 1500, goal)
 check(not state.observe_motion(goal, goal), "Locked goal cannot complete, even with physical contact")
 state.observe_score(1499)
 check(state.state == ScoreAttack.State.LOCKED, "Below target remains locked")
 state.observe_score(1500)
 check(state.state == ScoreAttack.State.UNLOCKED and not state.observe_motion(Vector2(400, 1900), Vector2(450, 1900)), "Exact threshold unlocks; bottom score farming cannot win")
 check(state.observe_motion(goal - Vector2(100, 0), goal + Vector2(100, 0)) and not state.observe_motion(goal, goal), "Fast swept contact completes exactly once")
 state.reset(false, 1500, goal)
 state.observe_score(999999)
 check(state.state == ScoreAttack.State.FREE_PLAY and not state.observe_motion(goal, goal), "Free Play ignores goal and score threshold")
 var anchors_valid := true
 var transforms := 0
 for source: ChunkData in TableGenerator.CATALOGUE:
  var local_goal := ScoreAttack.find_goal({"chunks": [source]})
  for mirrored: bool in [false, true]:
   for shift: int in TableGenerator.allowed_shifts(source):
    var chunk: ChunkData = source.duplicate(true)
    chunk.mirrored = mirrored
    chunk.horizontal_shift_cells = shift
    chunk.grid_position = Vector2i(2, 3)
    var transformed := ScoreAttack.find_goal({"chunks": [chunk]})
    anchors_valid = anchors_valid and transformed.is_finite() and transformed.is_equal_approx(chunk.world_point(local_goal)) and TableGenerator.point_clear(transformed, chunk.gameplay_descriptors(), ScoreAttack.GOAL_RADIUS)
    transforms += 1
 check(anchors_valid, "All %d catalogue mirror/shift/translation transforms retain clear upper goal anchors" % transforms)
 var scene := "res://experiments/visual_lab/visual_lab.tscn" if green_hill else "res://scenes/playground.tscn"
 game = load(scene).instantiate()
 root.add_child(game)
 await frames()
 var ui: ScoreAttackPanel = game.debug_panel.challenge_panel
 if green_hill:
  var visible_before := ui.is_visible_in_tree()
  game.toggle_debug()
  await frames()
  var visible_debug := ui.is_visible_in_tree()
  game.toggle_debug()
  game._set_close_view(true)
  await frames()
  game._set_close_view(false)
  check(visible_before and visible_debug and ui.is_visible_in_tree() and not paused, "Green Hill preserves mode controls across debug and character-study views")
 check(game.score_attack.state == ScoreAttack.State.FREE_PLAY and not game.presentation.get_node("ScoreAttackGoal").visible, "Default scene is Free Play without a visible goal")
 game._on_ring_collected(Vector2.ZERO)
 check(game.score == 25 and game.rings_collected == 1, "Existing ring scoring stays unchanged in Free Play")
 await capture("free-play")
 ui.mode_selector.select(1)
 ui.target_field.get_line_edit().text = "250"
 ui.start_button.pressed.emit()
 await frames()
 check(game.score_attack.state == ScoreAttack.State.LOCKED and game.score_attack.target == 250 and game.score == 0 and game.ball.serve_pending, "Mode UI applies typed target and starts a fresh run")
 var first_signature: String = game.layout.signature
 var first_goal: Vector2 = game.score_attack.goal_position
 var first_visual: Node = game.presentation.get_node("ScoreAttackGoal")
 game.presentation.set_camera_follow(false)
 await capture("locked")
 var bumper: Node
 for chunk: TableChunk in game.chunks:
  for descriptor: Dictionary in chunk.descriptors:
   if descriptor.kind == "circle":
    bumper = descriptor.body
    break
 game._on_bumper_hit(bumper)
 game._on_bumper_hit(bumper)
 game._on_ring_collected(Vector2.ZERO)
 check(game.score == 225 and game.score_attack.state == ScoreAttack.State.LOCKED, "Real score callbacks remain locked one ring below target")
 game._on_ring_collected(Vector2.ZERO)
 check(game.score == 250 and game.score_attack.state == ScoreAttack.State.UNLOCKED, "Existing ring event unlocks at the exact target")
 game.launch_ball()
 await frames(10)
 check(not paused and game.score_attack.state == ScoreAttack.State.UNLOCKED, "Unlock at the bottom does not complete the challenge")
 check(not game.request_generation(99, -1, -1, {"enabled": false}) and game.score_attack_enabled, "In-flight mode change is rejected without changing the active run")
 # Teleport only in this lifecycle fixture; the separate play survey uses inputs only.
 game.ball.teleport_to(Vector2(400, game.layout.bounds.end.y + 100))
 await frames(120)
 check(game.ball_number == 2 and game.score >= 250 and game.score_attack.state == ScoreAttack.State.UNLOCKED and game.respawn_time < 0, "Real drain respawns automatically and preserves score/unlocked goal")
 game.reset_ball()
 await frames()
 check(game.ball.serve_pending and not paused and game.score_attack.state == ScoreAttack.State.UNLOCKED, "Ball reset cannot create a swept goal hit or clear progress")
 game.presentation.set_camera_follow(true)
 game.ball.teleport_to(first_goal, Vector2.ZERO)
 game.previous_goal_position = first_goal
 await frames(8)
 check(paused and game.score_attack.state == ScoreAttack.State.COMPLETE and ui.victory.visible, "Physical upper contact pauses on the victory panel")
 game.presentation.reset_camera(first_goal)
 await capture("victory")
 var won_score: int = game.score
 game._on_bumper_hit(bumper)
 game._on_ring_collected(Vector2.ZERO)
 game.toggle_pause()
 check(paused and game.score == won_score, "Victory is latched; late score events and pause cannot resume it")
 ui.replay_button.pressed.emit()
 await frames(8)
 check(not paused and game.score == 0 and game.rings_collected == 0 and game.ball_number == 1 and game.ball.serve_pending and game.score_attack.state == ScoreAttack.State.LOCKED and not ui.victory.visible, "Replay clears victory, counters, timers and ball and resumes at serve")
 check(game.layout.signature == first_signature and game.score_attack.goal_position == first_goal and not is_instance_valid(first_visual) and game.presentation.get_node("ScoreAttackGoal").position.is_equal_approx(TablePresentation.map_point(first_goal, 0.04)), "Same-seed replay replaces the goal skin at the identical transformed location")
 var racks_reset := true
 for ring: Dictionary in game.ring_field.rings:
  racks_reset = racks_reset and ring.active
 check(racks_reset and game.ring_reset_time < 0 and game.respawn_time < 0 and game.auto_launch_time < 0, "Replay restores every ring and clears pending timers")
 # Rack-clear bonus must use the same unlock path too.
 game.request_generation(game.generation_seed, -1, -1, {"target": 525})
 await frames()
 for ring: Dictionary in game.ring_field.rings:
  ring.active = false
 game._on_ring_collected(Vector2.ZERO)
 check(game.score == 525 and game.score_attack.state == ScoreAttack.State.UNLOCKED, "Existing +500 rack bonus participates in the same threshold")
 game.ball.teleport_to(game.score_attack.goal_position)
 game.previous_goal_position = game.score_attack.goal_position
 await frames(8)
 var next_seed: int = (game.generation_seed + 1) % 2147483648
 ui.next_button.pressed.emit()
 await frames(8)
 check(game.generation_seed == next_seed and game.score_attack.state == ScoreAttack.State.LOCKED and game.score == 0 and not paused and not ui.victory.visible, "Victory Next table advances the seed and starts a fresh challenge")
 game.toggle_pause()
 game.request_generation(1)
 await frames()
 check(paused and game.score_attack.state == ScoreAttack.State.LOCKED and game.ball.serve_pending, "Paused regeneration preserves pause and clears objective state")
 game.toggle_pause()
 var placements_ok := true
 for difficulty in 3:
  for grid_mode in 3:
   for seed_value: int in [1, 2, 12]:
    game.request_generation(seed_value, difficulty, grid_mode)
    await frames()
    var upper: ChunkData = game.layout.chunks[0]
    var point: Vector2 = game.score_attack.goal_position
    var geometry: Array[Dictionary] = []
    for chunk: ChunkData in game.layout.chunks:
     geometry.append_array(chunk.gameplay_descriptors())
    for junction: Dictionary in game.layout.junctions:
     geometry.append_array(junction.junction_rails)
    var route_errors := PackedStringArray()
    var checked_upper: ChunkData = upper.duplicate(true)
    # Revalidate the chosen anchor explicitly, including the complete generated route.
    var local: Vector2 = point - Vector2(upper.grid_position + Vector2i(upper.horizontal_shift_cells, 0)) * ChunkData.GRID_SIZE
    if upper.mirrored:
     local.x = upper.grid_dimensions.x * ChunkData.GRID_SIZE - local.x
    checked_upper.markers["test_target"] = local
    var checked_chunks: Array[ChunkData] = [checked_upper, game.layout.chunks[1], game.layout.chunks[2]]
    TableGenerator._check_routes(checked_chunks, geometry, route_errors)
    placements_ok = placements_ok and game.generation_seed == seed_value and game.generation_grid_mode == grid_mode and point.is_finite() and route_errors.is_empty() and game.score == 0 and game.score_attack.state == ScoreAttack.State.LOCKED and game.presentation.get_node("ScoreAttackGoal").visible
 check(placements_ok, "27 seeded Easy/Normal/Hard catalogue/grid builds retain reachable goals and fresh challenge state")
 game.request_generation(1, -1, -1, {"enabled": false})
 await frames()
 check(game.score_attack.state == ScoreAttack.State.FREE_PLAY and not game.presentation.get_node("ScoreAttackGoal").visible and not ui.victory.visible, "Switch back to Free Play removes goal and victory state")
 var controls_rect: Rect2 = ui.get_child(0).get_global_rect()
 var fits: bool = controls_rect.end.x < (1000 if green_hill else 880) and controls_rect.end.y < (190 if green_hill else 148)
 check(fits, "Mode controls fit the active presentation without clipping")
 print("RESULT | Score Attack%s | %d checks | %d failures" % [" / Green Hill" if green_hill else "", checks, failures])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
