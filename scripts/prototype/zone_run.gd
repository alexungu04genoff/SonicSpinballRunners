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
var starting_balls := BALLS_PER_ACT
var drafting := false
var pending_act: RefCounted
var buddies := Buddies.new()
var buddy_contributions: Dictionary:
 get: return buddies.contributions
var act_buddy_contributions: Dictionary:
 get: return buddies.act_contributions
var elapsed := 0.0
var act_started_at := 0.0
var act_start_ball := 1
var results: Array[Dictionary] = []
var _planned := false
var source_paths: Array = []
var run_plan: Array[Dictionary] = []
var run_configuration: RefCounted

var hint: Label
var player_hud: Control
var score_overlay: Control
var _ring_award_position := Vector2.INF
var goal_pending := false
var combo_glow: Node
var fps_label: Label
var fps_update := 0.0
var telemetry := preload("res://scripts/prototype/run_telemetry.gd").new()

func effective_configuration() -> RefCounted:
 if run_configuration == null: run_configuration = RunPlan.Configuration.new(source_paths if not source_paths.is_empty() else RunPlan.source_paths())
 return run_configuration

func course_snapshot() -> Array:
 var course: Array = []
 for entry: Dictionary in run_plan:
  course.append({"zone": entry.zone + 1, "act": entry.act + 1, "theme": entry.theme,
   "atmosphere": entry.get("atmosphere", {}).duplicate(true), "source": source_paths[entry.id], "target": RunPlan.target(entry.sequence)})
 return course

func _ready() -> void:
 buddies.virtual_rings_awarded.connect(func(amount: int, _id: String): award_virtual_rings(amount))
 scorecraft_config = scorecraft_config.duplicate()
 scorecraft_config.multiplier_cap = 4
 scorecraft_config.tiered_decay = true
 super._ready()
 scorecraft.combo_advanced.connect(func(kind: StringName, id: String, tier: int, began: bool): telemetry.combo_advanced(kind, id, tier, began, elapsed))
 scorecraft.combo_supported.connect(telemetry.combo_supported)
 scorecraft.combo_ended.connect(func(reason: String, chain: int, tier: int): telemetry.combo_ended(reason, chain, tier, elapsed))
 specials.special_activated.connect(func(_id: String): telemetry.action_used(specials.definition.character_type))
 specials.area_completed.connect(telemetry.area_completed)
 specials.homing_started.connect(func(target: Node2D, _direction: Vector2):
  telemetry.speed_started(ball.position.distance_to(target.global_position), specials.action.target_range))
 specials.homing_ended.connect(telemetry.speed_ended)
 specials.special_hit.connect(func(target: Node2D, _multiplier: int): telemetry.speed_hit("enemy" if target.has_meta("enemy_id") else "bumper"))
 specials.flight_started.connect(telemetry.flight_started)
 specials.flight_lift_applied.connect(telemetry.flight_lift_applied)
 specials.area_target_activated.connect(func(_source: String, target: Node2D, _multiplier: int): telemetry.area_target_activated("enemy" if target.has_meta("enemy_id") else "bumper"))
 combo_glow = preload("res://scripts/prototype/combo_glow.gd").new()
 combo_glow.game = self
 add_child(combo_glow)

func _add_scoring_hardware(runtime: Dictionary, document: Resource, offset: Vector2, visual_parent: Node3D, _owner_id: String) -> void:
 var goal := preload("res://scripts/prototype/goal_ring.gd").new()
 visual_parent.add_child(goal)
 goal.configure(document, offset)
 runtime["goal_ring"] = goal
 runtime.root.tree_exiting.connect(goal.queue_free)
 var warning := preload("res://scripts/prototype/exit_warning.gd").new()
 visual_parent.add_child(warning)
 warning.configure(document, offset)
 runtime["exit_warning"] = warning
 runtime.root.tree_exiting.connect(warning.queue_free)

func _sync_resident() -> void:
 super._sync_resident()
 if is_instance_valid(combo_glow): combo_glow.rebuild()
 if is_instance_valid(score_overlay):
  for label: Node in presentation.find_children("*", "Label3D", true, false):
   if not character.is_ancestor_of(label): score_overlay.track_label(label)

func _build_presentation() -> void:
 super._build_presentation()
 presentation.camera_settings.screen_target_y = 0.55
 presentation.set_camera_value("zoom", 1.3)
 var meter := preload("res://scripts/prototype/combo_meter.gd").new()
 meter.game = self
 character.marker.add_child(meter)

func _source_paths() -> Array:
 if source_paths.is_empty(): source_paths = effective_configuration().selected_act_paths.duplicate()
 return source_paths

func _default_run_seed() -> int:
 return randi()

func _pool_error(documents: Array) -> String:
 var error: String = effective_configuration().validation_error()
 return error if not error.is_empty() else RunPlan.pool_error(documents, effective_configuration().single_act_test)

func _uses_authoring_builder() -> bool:
 if effective_configuration().single_act_test:
  return not effective_configuration().single_act_use_bakes
 return super._uses_authoring_builder()

func _next_planned_zone(documents: Array) -> Array[Dictionary]:
 if _planned: return []
 _planned = true
 run_plan = RunPlan.build(documents, run_seed, effective_configuration())
 return run_plan.duplicate(true)

func _has_next_act() -> bool:
 return active_sequence + 1 < run_plan.size()

func _score_target_for(_document: Resource, owner_id: String) -> int:
 return RunPlan.target(owner_id.get_slice(":", 1).to_int())

func act_title(act: RefCounted) -> String:
 return str(source_paths[act.plan.id]).get_file().get_basename()

func progress_text() -> String:
 if effective_configuration().single_act_test: return "ACT TEST · %s · %s" % [act_title(active), library.themes[active.plan.theme].display_name.to_upper()]
 return "ZONE %d / %d · %s · ACT %d / %d" % [active.plan.zone + 1, effective_configuration().zone_count, library.themes[active.plan.theme].display_name.to_upper(), active.plan.act + 1, RunPlan.ACTS_PER_ZONE]

func act_score_text() -> String:
 return super.act_score_text().replace("EXIT OPEN", "GOAL READY")

func _physics_process(delta: float) -> void:
 if closing or finished or not started or get_tree().paused or is_instance_valid(transfer):
  telemetry.ball_speed.observe(0.0, 0.0, false)
  return
 if not ball.serve_pending: elapsed += delta
 var ordinary_motion := not ball.serve_pending and not ball._teleport_pending and not ball.freeze and not loading_act and respawn_time < 0.0
 telemetry.observe_motion(delta, ball.linear_velocity.length(), ordinary_motion and not ball.on_ramp and specials.homing_remaining <= 0.0,
  specials.flight_remaining if ordinary_motion else 0.0)
 super._physics_process(delta)

func _foreground_safety_hold() -> bool:
 return super._foreground_safety_hold() or drafting or pending_act != null or is_instance_valid(transfer)

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
 active.runtime.exit_warning.visible = not initial
 buddies.run_seed = run_seed
 starting_balls = buddies.begin_act(BALLS_PER_ACT, practice_mode, int(act.plan.zone))
 balls_remaining = starting_balls
 scorecraft.award_bonuses = buddies.modifiers()
 tuning.set_temporary("run_buddies", buddies.physics_modifier())
 act_started_at = elapsed
 telemetry.begin_act(elapsed, act.document, character_id)
 if exit_unlocked: telemetry.target_ready(elapsed, act_score, 0)
 act_start_ball = ball_number
 active.runtime.goal_ring.set_unlocked(exit_unlocked)
 if not initial: status_message = "ACT %d · NEW SCORE TARGET %d" % [active_sequence + 1, act_score_target]

func choose_buddy(id: String) -> bool:
 if not drafting or finished or closing or pending_act == null: return false
 if id.is_empty():
  if not buddies.offers().is_empty(): return false
 elif not buddies.choose(id): return false
 _begin_act(pending_act, false)
 pending_act = null
 drafting = false
 get_tree().paused = false
 _start_transfer(false)
 return true

func _start_transfer(drained: bool) -> void:
 if is_instance_valid(ball.mechanics): ball.mechanics.reset_for_retry()
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

func _act_result(cleared: bool) -> Dictionary:
 var row := {"act": active_sequence + 1, "zone": active.plan.zone + 1, "zone_act": active.plan.act + 1, "theme": active.plan.theme, "source": source_paths[active.plan.id], "title": act_title(active), "cleared": cleared, "score": act_score, "target": act_score_target, "seconds": elapsed - act_started_at, "drains": ball_number - act_start_ball, "categories": act_score_breakdown.duplicate(), "buddy_contributions": act_buddy_contributions.duplicate(), "buddies": buddies.levels.duplicate(), "buddy_state": buddies.state(), "normal_score": act_score - Buddies.total(act_buddy_contributions)}
 row["authored_difficulty"] = active.document.authored_difficulty
 row["authored_difficulty_label"] = active.document.difficulty_label()
 row["act_fingerprint"] = active.document.fingerprint()
 row["character"] = character_id
 row["character_type"] = specials.definition.character_type
 row["design_thesis"] = active.document.design_thesis
 row["telemetry"] = telemetry.finish_act(row, elapsed)
 return row

func _record_act(cleared: bool) -> void:
 results.append(_act_result(cleared))

func _observe_authored_motion(start: Vector2, finish: Vector2) -> void:
 if finished or drafting or is_instance_valid(transfer) or not exit_unlocked: return
 if not active.runtime.goal_ring.crossed(start, finish, ball.radius): return
 telemetry.goal_touched(elapsed)
 if _has_next_act():
  if not _next_ready():
   goal_pending = true
   ball.freeze = true
   _wait_for_next()
   return
  for act: RefCounted in resident:
   if act.plan.sequence == active_sequence + 1:
    _activate(act)
    return
  return
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
 completed.emit(run_summary(won, "completed" if won else "out_of_balls"))

func run_summary(won := false, reason := "returned_to_menu") -> Dictionary:
 # Snapshot a partial Act without changing the recorder or gameplay lifecycle.
 var rows: Array[Dictionary] = results.duplicate(true)
 if not finished and started and active != null and (rows.is_empty() or int(rows.back().act) != active_sequence + 1):
  rows.append(_act_result(false))
 return {"run_configuration": effective_configuration().snapshot(), "configuration_fingerprint": effective_configuration().fingerprint(), "course": course_snapshot(), "won": won, "completed": won, "termination_reason": reason, "started": started, "practice": practice_mode, "seed": run_seed, "score": score, "normal_score": score - Buddies.total(buddy_contributions), "buddy_contributions": buddy_contributions.duplicate(), "buddies": buddies.levels.duplicate(), "buddy_state": buddies.state(), "seconds": elapsed, "drains": ball_number - 1, "character": character_id, "acts": rows}

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
 if buddies.rescue():
  balls_remaining = 1
  status_message = "CHIP RESCUE · Emergency Ball"
  return true
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
 telemetry.record_score(details)
 active.runtime.goal_ring.set_unlocked(exit_unlocked)
 if is_instance_valid(score_overlay): score_overlay.add_award(details, _award_position(details))
 status_message = status_message.replace("EXIT OPEN", "GOAL READY")
 buddies.record_score(details)

 if exit_unlocked:
  telemetry.target_ready(elapsed, act_score, Buddies.total(act_buddy_contributions))

func _wire_scoring_runtime(runtime: Dictionary, owner_id: String) -> void:
 super._wire_scoring_runtime(runtime, owner_id)
 runtime.mechanics.drop_target_event.connect(_on_drop_target_event.bind(owner_id))

func _on_drop_target_event(bank_id: String, target_id: String, phase: StringName, targets: int, owner_id: String) -> void:
 if _accept_scoring(owner_id): telemetry.drop_target_event(bank_id, target_id, phase, targets)

func _on_traversal_event(kind: StringName, object_id: String, phase: StringName, owner_id: String = "") -> void:
 super._on_traversal_event(kind, object_id, phase, owner_id)
 if phase == &"used" and kind == &"teleporter" and _accept_scoring(owner_id): telemetry.teleporter_used(object_id)
 # Slingshots retain Spring's existing combo contract; only the passive counter differs.
 if phase == &"used" and kind == &"spring" and _accept_scoring(owner_id) and telemetry.slingshots.get("by_object", {}).has(object_id):
  telemetry.slingshot_activated(object_id)

func _award_position(details: Dictionary) -> Vector2:
 if _ring_award_position.is_finite(): return _ring_award_position
 var target_id := int(details.get("target_id", 0))
 if target_id != 0 and is_instance_id_valid(target_id):
  var target := instance_from_id(target_id) as Node2D
  if target != null: return target.global_position
 if active != null:
  var object_id := str(details.get("object_id", "")).trim_prefix(active_scoring_id + ":").get_slice(":lane:", 0)
  var item: Dictionary = active.runtime.mechanics.by_id.get(object_id, {})
  if item.has("position"): return item.position
 return ball.position

func _accept_scoring(owner_id: String = "") -> bool:
 return not finished and not closing and not drafting and not is_instance_valid(transfer) and super._accept_scoring(owner_id)

func scoring_target_eligible(body: Node2D) -> bool:
 return not finished and not closing and not drafting and not is_instance_valid(transfer) and super.scoring_target_eligible(body)

func _on_ring_collected(where: Vector2, source: String = "", multiplier: int = 1) -> void:
 if _accept_scoring():
  _ring_award_position = where
  super._on_ring_collected(where, source, multiplier)
  buddies.physical_ring_collected()
  _ring_award_position = Vector2.INF

func _on_enemy_destroyed(enemy_type: StringName, object_id: String, points: int, source: StringName, owner_id: String = "") -> void:
 if not _accept_scoring(owner_id): return
 super._on_enemy_destroyed(enemy_type, object_id, points, source, owner_id)
 telemetry.enemy_event(enemy_type, "destructions")
 buddies.enemy_destroyed(enemy_type, object_id, source)

func _on_enemy_respawned(enemy_type: StringName, _object_id: String, owner_id: String = "") -> void:
 if _accept_scoring(owner_id): telemetry.enemy_event(enemy_type, "respawns")

func toggle_tour() -> void:
 pass # A camera tour cannot advance a player run.

func jump_tour_boundary() -> void:
 pass

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
  diagnostics.visible = not diagnostics.visible
  fps_label.visible = diagnostics.visible

func reset_ball(relaunch := false) -> void:
 if not finished and not closing and not drafting and not is_instance_valid(transfer): super.reset_ball(relaunch)

func launch_ball() -> void:
 if not finished and not closing and not drafting and not is_instance_valid(transfer): super.launch_ball()

func toggle_pause() -> void:
 if not finished and not closing and not drafting: super.toggle_pause()

func prepare_to_close() -> void:
 if is_instance_valid(tuning): tuning.clear_temporary("run_buddies")
 if is_instance_valid(transfer):
  transfer.set_process(false)
  transfer.queue_free()
  transfer = null
 await super.prepare_to_close()

func _update_hud(delta: float) -> void:
 fps_update -= delta
 if is_instance_valid(fps_label) and fps_update <= 0.0:
  fps_label.text = "%d FPS" % Engine.get_frames_per_second()
  fps_update = 0.25
 if not started or closing: return
 if goal_pending and _next_ready():
  goal_pending = false
  _observe_authored_motion(active.runtime.goal_ring.center, active.runtime.goal_ring.center)
 var state: Array = [rings_collected, practice_mode, balls_remaining, active_sequence, run_plan.size(), act_score, act_score_target, exit_unlocked, int(special_meter)]
 if state != _hud_detail_state:
  _hud_detail_state = state
  heading.text = "%03d" % rings_collected
  detail.text = "ACT %d / %d    %s" % [active_sequence + 1, run_plan.size(), "GOAL READY" if exit_unlocked else "%d / %d" % [act_score, act_score_target]]
  player_hud.update_values(character_id, "∞" if practice_mode else str(balls_remaining), special_meter)
 var hint_text := ""
 if is_instance_valid(transfer): hint_text = "Returning to spawn…" if transfer.drain else "Next Act…"
 if respawn_time >= 0.0: hint_text = "BALL LOST · Retrying…"
 if loading_boundary: hint_text = "Preparing the next Act…"
 hint.text = hint_text
 hint.visible = not hint_text.is_empty()

func _build_hud() -> void:
 hud = CanvasLayer.new()
 hud.layer = 20
 add_child(hud)
 score_overlay = preload("res://scripts/prototype/score_overlay.gd").new()
 score_overlay.game = self
 hud.add_child(score_overlay)
 fps_label = Label.new()
 fps_label.name = "FPSCounter"
 fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 fps_label.add_theme_font_size_override("font_size", 16)
 fps_label.add_theme_color_override("font_shadow_color", Color.BLACK)
 fps_label.add_theme_constant_override("shadow_offset_x", 1)
 fps_label.add_theme_constant_override("shadow_offset_y", 1)
 fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 hud.add_child(fps_label)
 fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 fps_label.offset_left = -120
 fps_label.offset_right = -18
 fps_label.offset_top = 18
 fps_label.offset_bottom = 42
 fps_label.hide()
 player_hud = preload("res://scripts/prototype/arcade_hud.gd").new()
 hud.add_child(player_hud)
 heading = player_hud.rings
 detail = player_hud.progress
 hint = player_hud.message
 var pause_button := _button("Ⅱ", toggle_pause, hud)
 pause_button.tooltip_text = "Pause"
 pause_button.add_theme_font_size_override("font_size", 14)
 pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 pause_button.offset_left = -62
 pause_button.offset_right = -18
 pause_button.offset_top = 22
 pause_button.offset_bottom = 60
 diagnostics = Label.new()
 diagnostics.hide()
 diagnostics.position = Vector2(30, 140)
 hud.add_child(diagnostics)
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
