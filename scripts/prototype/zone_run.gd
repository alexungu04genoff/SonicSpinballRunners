extends "res://scripts/endless/endless_game.gd"
## A finite authored playlist on the same streamed playfield and scoring engine.
signal completed(summary: Dictionary)
signal draft_started(act_result: Dictionary, offers: Array[Dictionary])
const Buddies = preload("res://scripts/prototype/buddies.gd")
const BALLS_PER_ACT := 3
const ACTS := ["res://data/prototype/classic_pinball.tres", "res://data/prototype/switch_spinner.tres", "res://data/prototype/speedway_lane.tres"]
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
var hint: Label

func _source_paths() -> Array:
 return ACTS

func _next_planned_zone(documents: Array) -> Array[Dictionary]:
 if _planned: return []
 _planned = true
 var entries: Array[Dictionary] = []
 var offset := Vector2.ZERO
 for index in documents.size():
  if index > 0: offset = Plan.aligned_offset(documents[index - 1], offset, documents[index])
  entries.append({"sequence": index, "zone": 0, "act": index, "id": index, "theme": "green_hill", "offset": offset})
 return entries

func _has_next_act() -> bool:
 return active_sequence + 1 < ACTS.size()

func _prefetch_next_theme() -> void:
 pass # This prototype is one authored Zone.

func _physics_process(delta: float) -> void:
 if closing or finished or not started or get_tree().paused: return
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
 controls.input_blocked = false
 get_tree().paused = false
 return true

func _record_act(cleared: bool) -> void:
 results.append({"act": active_sequence + 1, "title": active.document.title.trim_prefix("Scoring - "), "cleared": cleared, "score": act_score, "target": act_score_target, "seconds": elapsed - act_started_at, "drains": ball_number - act_start_ball, "categories": act_score_breakdown.duplicate(), "buddy_contributions": act_buddy_contributions.duplicate(), "buddies": buddies.levels.duplicate(), "normal_score": act_score - Buddies.total(act_buddy_contributions)})

func _observe_authored_motion(start: Vector2, finish: Vector2) -> void:
 if finished or drafting or not exit_unlocked: return
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
 completed.emit({"won": won, "practice": practice_mode, "score": score, "normal_score": score - Buddies.total(buddy_contributions), "buddy_contributions": buddy_contributions.duplicate(), "buddies": buddies.levels.duplicate(), "seconds": elapsed, "drains": ball_number - 1, "character": character_id, "acts": results.duplicate(true)})

func _on_ball_drained() -> void:
 if finished or closing or drafting or respawn_time >= 0.0: return
 super._on_ball_drained()
 _spend_ball()

func _spend_ball() -> bool:
 if practice_mode: return true
 balls_remaining -= 1
 if balls_remaining > 0: return true
 _finish_run(false)
 return false

func _on_retry_requested() -> void:
 if not started or finished or closing or drafting or get_tree().paused: return
 if ball.serve_pending or ball._teleport_pending or respawn_time >= 0.0: return
 ball_number += 1
 if _spend_ball(): super.reset_ball(true)

func _on_score_awarded(details: Dictionary) -> void:
 if finished or closing or drafting: return
 super._on_score_awarded(details)
 for id: String in details.get("buddy_bonuses", {}):
  var bonus := int(details.buddy_bonuses[id])
  buddy_contributions[id] = int(buddy_contributions.get(id, 0)) + bonus
  act_buddy_contributions[id] = int(act_buddy_contributions.get(id, 0)) + bonus

func _accept_scoring(owner_id: String = "") -> bool:
 return not finished and not closing and not drafting and super._accept_scoring(owner_id)

func scoring_target_eligible(body: Node2D) -> bool:
 return not finished and not closing and not drafting and super.scoring_target_eligible(body)

func _on_ring_collected(where: Vector2, source: String = "", multiplier: int = 1) -> void:
 if not finished and not closing and not drafting: super._on_ring_collected(where, source, multiplier)

func toggle_tour() -> void:
 pass # A camera tour cannot advance a player run.

func jump_tour_boundary() -> void:
 pass

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
  diagnostics.visible = not diagnostics.visible

func reset_ball(relaunch := false) -> void:
 if not finished and not closing and not drafting: super.reset_ball(relaunch)

func launch_ball() -> void:
 if not finished and not closing and not drafting: super.launch_ball()

func toggle_pause() -> void:
 if not finished and not closing and not drafting: super.toggle_pause()

func _process(delta: float) -> void:
 super._process(delta)
 if not started or closing: return
 heading.text = "ACT %d / 3 · %s" % [active_sequence + 1, active.document.title.trim_prefix("Scoring - ").to_upper()]
 detail.text = "ACT SCORE   %s\nTOTAL SCORE   %d     COMBO ×%d\nBALLS LEFT   %s\n%s SPECIAL   %s\n%s\nBUDDIES   %s" % [act_score_text(), score, scorecraft.multiplier, "Unlimited · Practice" if practice_mode else "%d / %d" % [balls_remaining, BALLS_PER_ACT], character_id.to_upper(), "READY" if special_meter >= 100.0 else "%d%%" % int(special_meter), scoring_feedback_text(), buddies.summary()]
 var bonus := Buddies.total(scorecraft.last_award.get("buddy_bonuses", {}))
 if bonus > 0 and scorecraft.feedback_remaining > 0.0: detail.text += "\nBuddy bonus included: +%d" % bonus
 hint.text = "Enter / X: launch" if ball.serve_pending else ("EXIT OPEN · Reach the lit exit" if exit_unlocked else "Earn %d more points to open the exit" % maxi(0, act_score_target - act_score))
 if respawn_time >= 0.0: hint.text = "BALL LOST · Checkpoint retry · Your score is safe"
 if loading_boundary: hint.text = "Preparing the next Act…"

func _build_hud() -> void:
 hud = CanvasLayer.new()
 hud.layer = 20
 add_child(hud)
 var backing := PanelContainer.new()
 backing.position = Vector2(20, 18)
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.025, 0.055, 0.09, 0.9)
 style.set_content_margin_all(12)
 style.set_corner_radius_all(8)
 backing.add_theme_stylebox_override("panel", style)
 hud.add_child(backing)
 var stack := VBoxContainer.new()
 backing.add_child(stack)
 heading = Label.new()
 heading.add_theme_font_size_override("font_size", 23)
 stack.add_child(heading)
 detail = Label.new()
 detail.add_theme_font_size_override("font_size", 20)
 stack.add_child(detail)
 hint = Label.new()
 hint.add_theme_color_override("font_color", Color("ffe07a"))
 stack.add_child(hint)
 var help := Label.new()
 help.text = "Q / E: flippers · Arrows: steer · Space: special · Esc: pause\nR: retry%s" % ("" if practice_mode else " (uses one ball)")
 stack.add_child(help)
 _button("Pause / menu", toggle_pause, stack)
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
