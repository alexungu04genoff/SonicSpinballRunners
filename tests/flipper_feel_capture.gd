extends SceneTree
## Graphical witnesses in the actual nine-chunk Green Hill layout. Each ball gets
## one initial gravity-drop condition; subsequent motion uses ordinary physics
## and one virtual flipper press. This is a controlled shot, not a full-run claim.
## --rendering-driver opengl3_angle --fixed-fps 120 --script res://tests/flipper_feel_capture.gd
## -- --case=normal-garden [--miss] [--press-tick=N] [--ticks=600]
## [--output-directory=res://test-results/flipper-mount-review]
## Garden route cases: garden-progression, garden-scoring, garden-miss. Their
## default output directory is test-results/target-garden-routes-review.
## Add --write-movie <absolute .avi path> before -- to record the same sequence.

const CASES := {
 "normal-garden": {"seed": 28, "difficulty": TableGenerator.Difficulty.NORMAL, "chunk": 7, "id": "zone_normal_target_garden", "name": "Normal 28 · Target Garden", "source_start": Vector2(112, 200), "paddle": 0},
 "hard-vault": {"seed": 24, "difficulty": TableGenerator.Difficulty.HARD, "chunk": 7, "id": "zone_hard_bank_vault", "name": "Hard 24 · Bank Vault", "source_start": Vector2(525, 100), "paddle": 0},
 "hard-climb": {"seed": 24, "difficulty": TableGenerator.Difficulty.HARD, "chunk": 6, "id": "zone_hard_offset_climb", "name": "Hard 24 · Offset Climb", "source_start": Vector2(600, 200), "paddle": 0},
 "garden-progression": {"seed": 28, "difficulty": TableGenerator.Difficulty.NORMAL, "chunk": 7, "id": "zone_normal_target_garden", "name": "Normal 28 · Garden upper passage", "source_start": Vector2(688, 200), "paddle": 1, "trigger": 43.0, "goal": "upper_passage"},
 "garden-scoring": {"seed": 28, "difficulty": TableGenerator.Difficulty.NORMAL, "chunk": 7, "id": "zone_normal_target_garden", "name": "Normal 28 · Garden scoring route", "source_start": Vector2(688, 200), "paddle": 1, "trigger": 55.0, "goal": "score", "source_target": Vector2(600, 200)},
 "garden-miss": {"seed": 28, "difficulty": TableGenerator.Difficulty.NORMAL, "chunk": 7, "id": "zone_normal_target_garden", "name": "Normal 28 · Garden missed catch", "source_start": Vector2(688, 200), "paddle": 1, "trigger": 43.0, "goal": "miss", "miss": true},
}

var game: Node
var selected: PlaygroundFlipper
var tick_index := -1
var pressed_tick := -1
var strike_tick := -1
var target_tick := -1
var action_label: Label
var event_label: Label
var summary_label: Label
var miss := false
var case_name := "normal-garden"
var output_prefix := ""
var target := Vector2.ZERO
var result: Dictionary = {}
var route_goal := ""
var upper_opening := Rect2()
var pending_upper_crossing := Vector2.INF

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func argument(prefix: String, fallback: String) -> String:
 for value: String in OS.get_cmdline_user_args():
  if value.begins_with(prefix):
   return value.trim_prefix(prefix)
 return fallback

func label(text: String, font_size: int, color := Color.WHITE) -> Label:
 var node := Label.new()
 node.text = text
 node.add_theme_font_size_override("font_size", font_size)
 node.add_theme_color_override("font_color", color)
 return node

func build_overlay(title: String) -> void:
 game.lab_ui.hide()
 game.challenge_ui.hide()
 game.debug_panel.hide()
 game.view_container.offset_top = 112.0
 game.view_container.offset_bottom = 0.0
 var overlay := CanvasLayer.new()
 overlay.layer = 100
 root.add_child(overlay)
 var bar := ColorRect.new()
 bar.color = Color("091722")
 bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 bar.offset_bottom = 112.0
 overlay.add_child(bar)
 var stack := VBoxContainer.new()
 stack.position = Vector2(24, 10)
 stack.add_theme_constant_override("separation", 3)
 overlay.add_child(stack)
 stack.add_child(label("Controlled gravity drop · " + title, 25, Color("b9efff")))
 action_label = label("Miss: no input" if miss else "Gravity descent · waiting for the catch", 21)
 stack.add_child(action_label)
 event_label = label("One initial position · zero initial velocity · no steering", 17, Color("b6c6d4"))
 stack.add_child(event_label)
 summary_label = label("", 17, Color("b6c6d4"))
 summary_label.position = Vector2(24, 864)
 overlay.add_child(summary_label)

func capture(suffix: String) -> void:
 await RenderingServer.frame_post_draw
 var path := output_prefix + "-" + suffix + ".png"
 var error := root.get_texture().get_image().save_png(path)
 if error != OK:
  result.capture_errors += 1
  push_error("Could not save flipper capture: " + path)
 else:
  print("FLIPPER FEEL CAPTURE | ", path)

func on_shot(contact: Vector2, impulse: Vector2, fraction: float) -> void:
 strike_tick = tick_index
 result.strike = {"tick": tick_index, "contact": contact, "impulse": impulse, "fraction": fraction}
 event_label.text = "Physical flipper strike · contact %.0f%% · impulse (%.0f, %.0f)" % [fraction * 100.0, impulse.x, impulse.y]
 event_label.modulate = Color("8de9af")

func on_bumper(body: Node) -> void:
 result.bumper_hits.append({"tick": tick_index, "position": body.global_position, "score": game.score, "after_strike": strike_tick >= 0})
 if strike_tick >= 0 and body.global_position.distance_to(target) < 1.0:
  target_tick = tick_index
  result.target_scored = true
  event_label.text = "Target bumper hit after the strike · real contact, ordinary scoring"
  event_label.modulate = Color("ffe183")

func observe_upper_passage(previous: Vector2) -> void:
 if strike_tick < 0 or result.upper_passage or game.ball.serve_pending or game.ball._teleport_pending:
  return
 var position: Vector2 = game.ball.position
 var seam_y := upper_opening.position.y
 if previous.y >= seam_y and position.y < seam_y and game.ball.linear_velocity.y < 0.0:
  var crossing := previous.lerp(position, (previous.y - seam_y) / (previous.y - position.y))
  var inset := PlaygroundBall.RADIUS + ChunkData.RAIL_RADIUS
  if crossing.x > upper_opening.position.x + inset and crossing.x < upper_opening.end.x - inset:
   pending_upper_crossing = crossing
 if position.y >= seam_y:
  pending_upper_crossing = Vector2.INF
 # Require the body to pass completely above the real seam after a clear upward
 # crossing. A collected exit ring or a near miss cannot satisfy this outcome.
 if pending_upper_crossing.is_finite() and position.y < seam_y - PlaygroundBall.RADIUS and game.ball.linear_velocity.y < 0.0:
  result.upper_passage = true
  result.upper_passage_tick = tick_index
  result.upper_crossing = pending_upper_crossing
  result.passage_score = game.score
  result.passage_rings = game.rings_collected
  event_label.text = "Upper room entered · physical passage · score %d · %d rings" % [game.score, game.rings_collected]
  event_label.modulate = Color("8de9af")

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Flipper feel capture needs a graphical renderer.")
  quit(1)
  return
 case_name = argument("--case=", "normal-garden")
 miss = OS.get_cmdline_user_args().has("--miss")
 if not CASES.has(case_name):
  push_error("Unknown capture case: " + case_name)
  quit(1)
  return
 var spec: Dictionary = CASES[case_name]
 route_goal = spec.get("goal", "")
 miss = miss or bool(spec.get("miss", false))
 var fixed_press := int(argument("--press-tick=", "-1"))
 var trigger_distance := float(argument("--trigger=", str(spec.get("trigger", 43.0))))
 var duration := clampi(int(argument("--ticks=", "600")), 120, 1200)
 var default_directory := "res://test-results/target-garden-routes-review" if not route_goal.is_empty() else "res://test-results/flipper-feel-review"
 var output_directory := argument("--output-directory=", default_directory)
 var basename := case_name if not route_goal.is_empty() else case_name + ("-miss" if miss else "-timed")
 output_prefix = output_directory.path_join(basename)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.zone_enabled = true
 game.generation_seed = spec.seed
 game.zone_difficulty_override = spec.difficulty
 root.add_child(game)
 await frames(5)
 if not is_instance_valid(game.ball) or not game.layout.valid:
  push_error("Capture layout failed to generate.")
  quit(1)
  return
 var data: ChunkData = game.chunks[spec.chunk].data
 if data.chunk_id != spec.id:
  push_error("Capture seed no longer contains the expected room: " + data.chunk_id)
  quit(1)
  return
 var placement: Dictionary = data.world_flippers()[spec.paddle]
 for paddle: PlaygroundFlipper in game.flippers:
  if paddle.position.distance_to(placement.position) < 0.1 and paddle.side == placement.side:
   selected = paddle
   break
 if not is_instance_valid(selected):
  push_error("Capture paddle was not found in the actual Zone.")
  quit(1)
  return
 target = placement.shot_target
 if spec.has("source_target"):
  target = data.world_point(spec.source_target)
 upper_opening = data.world_rect(data.top_connection)
 var start: Vector2 = data.world_point(spec.source_start)
 if not TableGenerator.point_clear(start, data.gameplay_descriptors(), PlaygroundBall.RADIUS + 6.0):
  push_error("Controlled gravity-drop position intersects geometry.")
  quit(1)
  return
 build_overlay(spec.name)
 await frames(3)
 game.presentation.set_camera_preset(TablePresentation.CameraPreset.REAL_PINBALL)
 game.presentation.set_camera_follow(true)
 game.presentation.set_camera_value("look_ahead", 0.0)
 game.presentation.reset_camera(data.world_point(Vector2(400, 365)))
 # Freeze only the review camera; ball, visuals, collisions and gameplay continue.
 game.presentation.camera_follow_enabled = false
 game.controls.virtual_enabled = true
 game.controls.virtual_steering = 0.0
 result = {"case": case_name, "seed": spec.seed, "signature": game.layout.signature, "miss": miss, "goal": route_goal, "shot_kind": placement.get("shot_kind", "score"), "initial_position": start, "initial_velocity": Vector2.ZERO, "paddle_position": selected.position, "paddle_side": selected.side, "target": target, "trigger_distance": trigger_distance, "fixed_press_tick": fixed_press, "pressed_tick": -1, "target_scored": false, "upper_opening": upper_opening, "upper_passage": false, "upper_passage_tick": -1, "rise": 0.0, "room_missed": false, "lower_return_tick": -1, "lower_return_after_target": false, "bumper_hits": [], "ring_events": [], "score_events": [], "trajectory": [], "capture_errors": 0}
 selected.shot_fired.connect(on_shot)
 game.ball.bumper_hit.connect(on_bumper)
 game.scorecraft.score_awarded.connect(func(details: Dictionary) -> void:
  var event: Dictionary = details.duplicate()
  event.tick = tick_index
  event.position = game.ball.position
  event.total_after_award = game.score + int(details.total)
  result.score_events.append(event))
 result.housing_contacts = []
 game.ball.body_entered.connect(func(body: Node) -> void:
  if body.name.begins_with("FlipperHousing"):
   result.housing_contacts.append({"tick": tick_index, "position": game.ball.position}))
 game.ring_field.collected.connect(func(position: Vector2) -> void:
  result.ring_events.append({"tick": tick_index, "position": position, "score": game.score, "after_strike": strike_tick >= 0})
  if strike_tick >= 0 and position.distance_to(target) < 1.0:
   result.target_scored = true
   target_tick = tick_index
   event_label.text = "Target ring collected after the strike · ordinary scoring")
 # The only trajectory setup. No position, velocity or strength changes below.
 game.ball.teleport_to(start, Vector2.ZERO)
 game.ring_field.previous_ball_position = start
 game.previous_goal_position = start
 game._goal_motion_ready = false
 var room_bottom: float = data.world_point(Vector2(400, data.grid_dimensions.y * ChunkData.GRID_SIZE)).y
 var shot_captured := false
 var outcome_captured := false
 var outcome_tick := -1
 var risk_captured := false
 for tick in duration:
  tick_index = tick
  var previous: Vector2 = game.ball.position
  var nearest := Geometry2D.get_closest_point_to_segment(game.ball.position, selected.position, selected.tip())
  var catch_ready: bool = game.ball.linear_velocity.y > 0.0 and game.ball.position.y < selected.position.y + 15.0 and nearest.distance_to(game.ball.position) < trigger_distance
  if not miss and pressed_tick < 0 and (tick == fixed_press if fixed_press >= 0 else catch_ready):
   pressed_tick = tick
   result.pressed_tick = tick
  var held := pressed_tick >= 0 and tick - pressed_tick < 15
  game.controls.virtual_left = held and selected.side > 0.0
  game.controls.virtual_right = held and selected.side < 0.0
  if held:
   action_label.text = "Press %s · tick %d · %.2f seconds" % ["LEFT / Q" if selected.side > 0.0 else "RIGHT / E", pressed_tick, pressed_tick / 120.0]
   action_label.modulate = Color("8de9af")
  elif pressed_tick >= 0:
   action_label.text = "Released · ball follows its physical trajectory"
  await frames(1)
  observe_upper_passage(previous)
  if tick % 12 == 0:
   result.trajectory.append({"tick": tick, "position": game.ball.position, "velocity": game.ball.linear_velocity})
  summary_label.text = "%.2f s · score %d · rings %d · strikes %d · bumper contacts %d" % [tick / 120.0, game.score, game.rings_collected, selected.strikes, game.ball.bumper_hit_count]
  if tick == 2:
   await capture("drop")
  if strike_tick >= 0 and tick >= strike_tick + 10 and not shot_captured:
   await capture("strike")
   shot_captured = true
  if game.ball.position.y > room_bottom + PlaygroundBall.RADIUS:
   result.room_missed = true
   if result.lower_return_tick < 0:
    result.lower_return_tick = tick
   if target_tick >= 0 and tick > target_tick:
    result.lower_return_after_target = true
  if strike_tick >= 0:
   result.rise = maxf(result.rise, float(result.strike.contact.y) - game.ball.position.y)
  var useful_climb: bool = case_name == "hard-climb" and result.rise >= 300.0
  if useful_climb and not result.target_scored:
   event_label.text = "Recovered more than 300 px upward · Act gate remains locked"
  if miss and result.room_missed:
   event_label.text = "Missed catch · ball falls into the recovery section below"
  elif route_goal == "score" and result.lower_return_after_target:
   event_label.text = "Scoring return · ball falls back into the lower recovery section"
   if not risk_captured:
    await capture("return-risk")
    risk_captured = true
  var passage_ready: bool = route_goal == "upper_passage" and result.upper_passage
  var score_ready: bool = route_goal != "upper_passage" and target_tick >= 0 and tick >= target_tick + 2
  if not outcome_captured and (passage_ready or score_ready or useful_climb or (miss and result.room_missed)):
   await capture("outcome")
   outcome_captured = true
   outcome_tick = tick
   result.outcome_tick = tick
   result.outcome_score = game.score
   result.outcome_rings = game.rings_collected
   result.outcome_bumper_contacts = game.ball.bumper_hit_count
  if route_goal.is_empty() and outcome_tick >= 0 and tick >= outcome_tick + 180:
   break
  if not route_goal.is_empty() and game.respawn_time >= 0.0:
   result.drain_tick = tick
   event_label.text = "Shot drained · ordinary checkpoint retry is queued"
   await capture("drain")
   break
  if game.ball.serve_pending:
   break
 result.strikes = selected.strikes
 result.score = game.score
 result.rings = game.rings_collected
 result.drains = game.ball_number - 1
 result.simulated_ticks = tick_index + 1
 result.target_tick = target_tick
 result.final_position = game.ball.position
 var useful: bool = result.target_scored or (case_name == "hard-climb" and result.rise >= 300.0)
 if route_goal == "upper_passage":
  useful = result.upper_passage
 paused = true
 action_label.text = "Miss comparison complete · replay paused for review" if miss else "Controlled shot complete · replay paused for review"
 await capture("final")
 result.success = result.capture_errors == 0 and (selected.strikes == 0 and result.room_missed if miss else selected.strikes == 1 and useful)
 var report := FileAccess.open(output_prefix + ".json", FileAccess.WRITE)
 report.store_string(JSON.stringify(result, " "))
 report.close()
 print("FLIPPER FEEL RESULT | ", JSON.stringify(result))
 # Keep each default MovieMaker example approximately 5.5 seconds long. The
 # clearly labeled pause lets the viewer inspect the outcome without body edits.
 await frames(maxi(60, duration + 60 - tick_index))
 paused = false
 game.free()
 await frames(3)
 quit(0 if result.success else 1)
