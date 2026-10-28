extends "res://scripts/endless/endless_game.gd"
## A finite authored playlist on the same streamed playfield and scoring engine.
signal completed(summary: Dictionary)
const ACTS := ["res://data/prototype/classic_pinball.tres", "res://data/prototype/switch_spinner.tres", "res://data/prototype/speedway_lane.tres"]
var finished := false
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
 if not initial and active == act: return
 if not initial: _record_act()
 super._activate(act, initial)
 act_started_at = elapsed
 act_start_ball = ball_number
 if not initial: status_message = "ACT %d · NEW SCORE TARGET %d" % [active_sequence + 1, act_score_target]

func _record_act() -> void:
 results.append({"act": active_sequence + 1, "title": active.document.title.trim_prefix("Scoring - "), "score": act_score, "target": act_score_target, "seconds": elapsed - act_started_at, "drains": ball_number - act_start_ball, "categories": act_score_breakdown.duplicate()})

func _observe_authored_motion(start: Vector2, finish: Vector2) -> void:
 if finished or not exit_unlocked: return
 if _has_next_act():
  super._observe_authored_motion(start, finish)
  return
 var crossed: Dictionary = ActLifecycle.crossings(active.document, start - Vector2(active.plan.offset), finish - Vector2(active.plan.offset))
 if not crossed.exit: return
 _record_act()
 finished = true
 ring_field.scoring_enabled = false
 for act: RefCounted in resident: act.runtime.mechanics.scoring_active = false
 specials.reset(false, "Run completed")
 scorecraft.reset("Run completed")
 ball.freeze = true
 controls.input_blocked = true
 get_tree().paused = true
 completed.emit({"score": score, "seconds": elapsed, "drains": ball_number - 1, "character": character_id, "acts": results.duplicate(true)})

func _accept_scoring(owner_id: String = "") -> bool:
 return not finished and not closing and super._accept_scoring(owner_id)

func scoring_target_eligible(body: Node2D) -> bool:
 return not finished and not closing and super.scoring_target_eligible(body)

func _on_ring_collected(where: Vector2, source: String = "", multiplier: int = 1) -> void:
 if not finished and not closing: super._on_ring_collected(where, source, multiplier)

func toggle_tour() -> void:
 pass # A camera tour cannot advance a player run.

func jump_tour_boundary() -> void:
 pass

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
  diagnostics.visible = not diagnostics.visible

func reset_ball(relaunch := false) -> void:
 if not finished and not closing: super.reset_ball(relaunch)

func launch_ball() -> void:
 if not finished and not closing: super.launch_ball()

func toggle_pause() -> void:
 if not finished and not closing: super.toggle_pause()

func _process(delta: float) -> void:
 super._process(delta)
 if not started or closing: return
 heading.text = "ACT %d / 3 · %s" % [active_sequence + 1, active.document.title.trim_prefix("Scoring - ").to_upper()]
 detail.text = "ACT SCORE   %s\nTOTAL SCORE   %d     COMBO ×%d\n%s SPECIAL   %s\n%s" % [act_score_text(), score, scorecraft.multiplier, character_id.to_upper(), "READY" if special_meter >= 100.0 else "%d%%" % int(special_meter), scoring_feedback_text()]
 hint.text = "Enter / X: launch" if ball.serve_pending else ("EXIT OPEN · Reach the lit exit" if exit_unlocked else "Earn %d more points to open the exit" % maxi(0, act_score_target - act_score))
 if respawn_time >= 0.0: hint.text = "DRAIN · Checkpoint retry · Your score is safe"
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
 help.text = "Q / E: flippers · Arrows: steer · Space: special · R: retry · Esc: pause"
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
