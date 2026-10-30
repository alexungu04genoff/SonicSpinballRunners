extends "res://scripts/endless/endless_game.gd"
## A finite authored playlist on the same streamed playfield and scoring engine.
signal completed(summary: Dictionary)
signal draft_started(act_result: Dictionary, offers: Array[Dictionary])
const Buddies = preload("res://scripts/prototype/buddies.gd")
const RunPlan = preload("res://scripts/prototype/run_plan.gd")
const BALLS_PER_ACT := 3
const SpawnTransfer = preload("res://scripts/prototype/spawn_transfer.gd")
var transfer: Node
var _ball_layer := 0
var _ball_mask := 0
var finished := false
var practice_mode := false
var balls_remaining := BALLS_PER_ACT
var drafting := false
var pending_act: RefCounted
var buddies := Buddies.new()
var buddy_contributions: Dictionary = {}
var act_buddy_contributions: Dictionary = {}
var elapsed := 0.0
var act_started_at := 0.0
var act_start_ball := 1
var results: Array[Dictionary] = []
var _planned := false
var source_paths: Array = []
var run_plan: Array[Dictionary] = []
var hint: Label

func _build_presentation() -> void:
 super._build_presentation()
 presentation.camera_settings.screen_target_y = 0.55
 presentation.set_camera_value("zoom", 1.3)

func _source_paths() -> Array:
 if source_paths.is_empty(): source_paths = RunPlan.source_paths()
 return source_paths

func _default_run_seed() -> int:
 return randi()

func _pool_error(documents: Array) -> String:
 return RunPlan.pool_error(documents)

func _next_planned_zone(documents: Array) -> Array[Dictionary]:
 if _planned: return []
 _planned = true
 run_plan = RunPlan.build(documents, run_seed)
 return run_plan.duplicate(true)

func _has_next_act() -> bool:
 return active_sequence + 1 < RunPlan.ACT_COUNT

func _score_target_for(_document: Resource, owner_id: String) -> int:
 return RunPlan.TARGETS[clampi(owner_id.get_slice(":", 1).to_int(), 0, RunPlan.ACT_COUNT - 1)]

func act_title(act: RefCounted) -> String:
 return str(source_paths[act.plan.id]).get_file().get_basename()

func progress_text() -> String:
 return "ZONE %d / %d · %s · ACT %d / %d" % [active.plan.zone + 1, RunPlan.THEMES.size(), library.themes[active.plan.theme].display_name.to_upper(), active.plan.act + 1, RunPlan.ACTS_PER_ZONE]

func _physics_process(delta: float) -> void:
 if closing or finished or not started or get_tree().paused: return
 if is_instance_valid(transfer): return
 if not ball.serve_pending: elapsed += delta
 super._physics_process(delta)

func _activate(act: RefCounted, initial := false) -> void:
 if finished or drafting or (not initial and active == act): return
 if not initial:
  _record_act(true)
  pending_act = act
  drafting = true
  controls.input_blocked = true
  get_tree().paused = true
  draft_started.emit(results.back().duplicate(true), buddies.offers())
  return
 _begin_act(act, initial)

func _begin_act(act: RefCounted, initial: bool) -> void:
 super._activate(act, initial)
 balls_remaining = BALLS_PER_ACT
 act_buddy_contributions.clear()
 scorecraft.award_bonuses = buddies.modifiers()
 act_started_at = elapsed
 act_start_ball = ball_number
 if not initial: status_message = "ACT %d · NEW SCORE TARGET %d" % [active_sequence + 1, act_score_target]

func choose_buddy(id: String) -> bool:
 if not drafting or finished or closing or pending_act == null: return false
 if not buddies.choose(id): return false
 _begin_act(pending_act, false)
 pending_act = null
 drafting = false
 get_tree().paused = false
 _start_transfer(false)
 return true

func _start_transfer(drained: bool) -> void:
 controls.input_blocked = true
 ring_field.scoring_enabled = false
 for act: RefCounted in resident: act.runtime.mechanics.scoring_active = false
 respawn_time = -1.0
 auto_launch_time = -1.0
 specials.reset(false, "Checkpoint transfer")
 scorecraft.reset("Checkpoint transfer", true)
 presentation.clear_ring_pickups()
 ball.teleport_to(ball.position, Vector2.ZERO, true)
 ball.linear_velocity = Vector2.ZERO
 ball.angular_velocity = 0.0
 ball.freeze = true
 _ball_layer = ball.collision_layer
 _ball_mask = ball.collision_mask
 ball.collision_layer = 0
 ball.collision_mask = 0
 transfer = SpawnTransfer.new()
 add_child(transfer)
 transfer.arrived.connect(_transfer_arrived)
 transfer.begin(self, ball.serve_position, drained)

func _transfer_arrived() -> void:
 transfer = null
 if closing or finished: return
 ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
 previous_goal_position = ball.serve_position
 _goal_motion_ready = false
 ring_field.previous_ball_position = ball.serve_position
 ball.collision_layer = _ball_layer
 ball.collision_mask = _ball_mask
 ball.freeze = false
 ring_field.scoring_enabled = true
 active.runtime.mechanics.scoring_active = true
 controls.input_blocked = false
 auto_launch_time = 0.35

func _record_act(cleared: bool) -> void:
 results.append({"act": active_sequence + 1, "zone": active.plan.zone + 1, "zone_act": active.plan.act + 1, "theme": active.plan.theme, "source": source_paths[active.plan.id], "title": act_title(active), "cleared": cleared, "score": act_score, "target": act_score_target, "seconds": elapsed - act_started_at, "drains": ball_number - act_start_ball, "categories": act_score_breakdown.duplicate(), "buddy_contributions": act_buddy_contributions.duplicate(), "buddies": buddies.levels.duplicate(), "normal_score": act_score - Buddies.total(act_buddy_contributions)})

func _observe_authored_motion(start: Vector2, finish: Vector2) -> void:
 if finished or drafting or is_instance_valid(transfer) or not exit_unlocked: return
 if _has_next_act():
  super._observe_authored_motion(start, finish)
  return
 var crossed: Dictionary = ActLifecycle.crossings(active.document, start - Vector2(active.plan.offset), finish - Vector2(active.plan.offset))
 if not crossed.exit: return
 _finish_run(true)

func _finish_run(won: bool) -> void:
 if finished: return
 _record_act(won)
 finished = true
 respawn_time = -1.0
 auto_launch_time = -1.0
 ring_field.scoring_enabled = false
 for act: RefCounted in resident: act.runtime.mechanics.scoring_active = false
 specials.reset(false, "Run ended")
 scorecraft.reset("Run ended")
 ball.freeze = true
 controls.input_blocked = true
 get_tree().paused = true
 completed.emit({"won": won, "practice": practice_mode, "seed": run_seed, "score": score, "normal_score": score - Buddies.total(buddy_contributions), "buddy_contributions": buddy_contributions.duplicate(), "buddies": buddies.levels.duplicate(), "seconds": elapsed, "drains": ball_number - 1, "character": character_id, "acts": results.duplicate(true)})

func _on_ball_drained() -> void:
 if finished or closing or drafting or is_instance_valid(transfer) or respawn_time >= 0.0: return
 super._on_ball_drained()
 ball.linear_velocity = Vector2.ZERO
 ball.angular_velocity = 0.0
 ball.freeze = true
 if _spend_ball(): _start_transfer(true)

func _spend_ball() -> bool:
 if practice_mode: return true
 balls_remaining -= 1
 if balls_remaining > 0: return true
 _finish_run(false)
 return false

func _on_retry_requested() -> void:
 if not started or finished or closing or drafting or is_instance_valid(transfer) or get_tree().paused: return
 if ball.serve_pending or ball._teleport_pending or respawn_time >= 0.0: return
 ball_number += 1
 if _spend_ball(): _start_transfer(true)

func _on_score_awarded(details: Dictionary) -> void:
 if finished or closing or drafting or is_instance_valid(transfer): return
 super._on_score_awarded(details)
 for id: String in details.get("buddy_bonuses", {}):
  var bonus := int(details.buddy_bonuses[id])
  buddy_contributions[id] = int(buddy_contributions.get(id, 0)) + bonus
  act_buddy_contributions[id] = int(act_buddy_contributions.get(id, 0)) + bonus

func _accept_scoring(owner_id: String = "") -> bool:
 return not finished and not closing and not drafting and not is_instance_valid(transfer) and super._accept_scoring(owner_id)

func scoring_target_eligible(body: Node2D) -> bool:
 return not finished and not closing and not drafting and not is_instance_valid(transfer) and super.scoring_target_eligible(body)

func _on_ring_collected(where: Vector2, source: String = "", multiplier: int = 1) -> void:
 if not finished and not closing and not drafting and not is_instance_valid(transfer): super._on_ring_collected(where, source, multiplier)

func toggle_tour() -> void:
 pass # A camera tour cannot advance a player run.

func jump_tour_boundary() -> void:
 pass

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
  diagnostics.visible = not diagnostics.visible

func reset_ball(relaunch := false) -> void:
 if not finished and not closing and not drafting and not is_instance_valid(transfer): super.reset_ball(relaunch)

func launch_ball() -> void:
 if not finished and not closing and not drafting and not is_instance_valid(transfer): super.launch_ball()

func toggle_pause() -> void:
 if not finished and not closing and not drafting: super.toggle_pause()

func prepare_to_close() -> void:
 if is_instance_valid(transfer):
  transfer.set_process(false)
  transfer.queue_free()
  transfer = null
 await super.prepare_to_close()

func _process(delta: float) -> void:
 super._process(delta)
 if not started or closing: return
 heading.text = progress_text() + "\n" + act_title(active)
 detail.text = "ACT   %s\nTOTAL   %d     COMBO ×%d\nBALLS   %s     SPECIAL   %s" % [act_score_text(), score, scorecraft.multiplier, "Unlimited" if practice_mode else "%d / %d" % [balls_remaining, BALLS_PER_ACT], "READY" if special_meter >= 100.0 else "%d%%" % int(special_meter)]
 if not buddies.levels.is_empty(): detail.text += "\n" + buddies.summary()
 if not scoring_feedback_text().is_empty(): detail.text += "\n" + scoring_feedback_text()
 var bonus := Buddies.total(scorecraft.last_award.get("buddy_bonuses", {}))
 if bonus > 0 and scorecraft.feedback_remaining > 0.0: detail.text += "\nBuddy bonus included: +%d" % bonus
 hint.text = ""
 if is_instance_valid(transfer): hint.text = "Returning to spawn…" if transfer.drain else "Next Act…"
 if respawn_time >= 0.0: hint.text = "BALL LOST · Retrying…"
 if loading_boundary: hint.text = "Preparing the next Act…"
 hint.visible = not hint.text.is_empty()

func _build_hud() -> void:
 hud = CanvasLayer.new()
 hud.layer = 20
 add_child(hud)
 var backing := PanelContainer.new()
 backing.position = Vector2(20, 18)
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.025, 0.055, 0.09, 0.35)
 style.set_content_margin_all(8)
 style.set_corner_radius_all(8)
 backing.add_theme_stylebox_override("panel", style)
 hud.add_child(backing)
 var stack := VBoxContainer.new()
 backing.add_child(stack)
 heading = Label.new()
 heading.add_theme_font_size_override("font_size", 18)
 stack.add_child(heading)
 detail = Label.new()
 detail.add_theme_font_size_override("font_size", 16)
 stack.add_child(detail)
 hint = Label.new()
 hint.add_theme_font_size_override("font_size", 14)
 hint.add_theme_color_override("font_color", Color("ffe07a"))
 stack.add_child(hint)
 _button("Pause / menu", toggle_pause, stack).add_theme_font_size_override("font_size", 14)
 diagnostics = Label.new()
 diagnostics.hide()
 stack.add_child(diagnostics)
 loading_panel = ColorRect.new()
 loading_panel.color = Color("101b2c")
 loading_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.add_child(loading_panel)
 loading_label = Label.new()
 loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 loading_label.add_theme_font_size_override("font_size", 22)
 loading_panel.add_child(loading_label)
