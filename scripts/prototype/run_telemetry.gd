extends RefCounted
## Passive snapshots on the existing gameplay clock. No RNG, I/O or scoring writes.
const FORMAT_VERSION := 5
const SpeedSamples = preload("res://scripts/prototype/ball_speed_telemetry.gd")
var ball_speed := SpeedSamples.new()
var slingshots := {}
var drop_targets := {}
var teleporters := {}
var _seen_targets := {}
var _action_type := ""
var _successful_uses := 0
var _speed := {}
var _fly := {}
var _power := {}
var _dash_active := false
var _dash_bucket := ""
var started_at := 0.0
var target_at: Variant = null
var goal_at: Variant = null
var score_at_target: Variant = null
var buddy_at_target: Variant = null
var score_by_category := {}
var combo_score_by_multiplier := {}
var combo_advances_by_source := {}
var combo_support_by_source := {}
var x4_activations := 0
var highest_multiplier := 1
var longest_combo_seconds := 0.0
var longest_combo_max_multiplier := 1
var type_actions := {}
var homing := {}
var enemies := {}
var _combo_started_at: Variant = null
var _combo_peak := 1

func begin_act(at: float, document: Resource = null, character := "") -> void:
 started_at = at
 target_at = null
 goal_at = null
 score_at_target = null
 buddy_at_target = null
 score_by_category = {}
 for kind: String in ["ring", "bumper", "enemy", "switch", "switch_bank", "spinner_tick", "spinner_goal", "lane", "lane_set", "ring_rack", "other"]:
  score_by_category[kind] = 0
 combo_score_by_multiplier = {"1": 0, "2": 0, "3": 0, "4": 0}
 combo_advances_by_source = {}
 for kind: String in ["bumper", "enemy", "ring_link", "switch_bank", "spinner_goal", "lane_set"]:
  combo_advances_by_source[kind] = 0
 combo_support_by_source = {}
 for kind: String in ["switch", "lane", "spring", "dash_panel", "elevated_rail", "ring_rack", "builder_refresh"]:
  combo_support_by_source[kind] = 0
 x4_activations = 0
 highest_multiplier = 1
 longest_combo_seconds = 0.0
 longest_combo_max_multiplier = 1
 _combo_started_at = null
 _combo_peak = 1
 type_actions = {"uses": 0, "successful_target_hits": 0, "affected_targets": 0, "affected_rings": 0}
 homing = {"finishers_used": 0, "successful_hits": 0, "normal_score": 0, "hits_by_target_type": {}}
 enemies = {"destructions": 0, "respawns": 0, "normal_score": 0, "by_type": {}}
 ball_speed.reset()
 slingshots = {"activations": 0, "by_object": {}}
 teleporters = {"transfers": 0, "by_object": {}}
 drop_targets = {"hits": 0, "unique_targets_hit": 0, "bank_completions": 0, "bank_resets": 0, "banks": {}}
 _seen_targets = {}
 _action_type = CharacterSpecials.CHARACTERS[character].character_type if CharacterSpecials.CHARACTERS.has(character) else ""
 _successful_uses = 0
 _dash_active = false
 _dash_bucket = ""
 _speed = {"targets_acquired": 0, "physical_target_hits": 0, "failed_approaches": 0,
  "failures_by_reason": {}, "hits_by_target_type": {}, "distance": {}, "target_range_px": null}
 for bucket: String in ["close", "medium", "far"]:
  _speed.distance[bucket] = {"acquired": 0, "hits": 0, "failed": 0}
 _fly = {"activations": 0, "successful_activations": 0, "active_seconds": 0.0, "rescue_lift_activations": 0}
 _power = {"uses": 0, "affected_total": 0, "affected_by_type": {"ring": 0, "bumper": 0, "enemy": 0}}
 if document != null:
  for item: Dictionary in document.gameplay_objects:
   if item.type == "slingshot": slingshots.by_object[item.object_id] = 0
   if item.type == "drop_target_bank":
    var properties := preload("res://scripts/act_editor/gameplay_objects.gd").properties(item)
    _add_bank(str(item.object_id), int(properties.target_count))

func _add_bank(id: String, targets: int) -> void:
 if not drop_targets.banks.has(id):
  drop_targets.banks[id] = {"targets": targets, "hits": 0, "unique_targets_hit": 0, "completions": 0, "resets": 0}

func slingshot_activated(id: String) -> void:
 slingshots.activations += 1
 slingshots.by_object[id] = int(slingshots.by_object.get(id, 0)) + 1

func teleporter_used(id: String) -> void:
 teleporters.transfers += 1
 teleporters.by_object[id] = int(teleporters.by_object.get(id, 0)) + 1

func drop_target_event(bank_id: String, target_id: String, phase: StringName, targets: int) -> void:
 _add_bank(bank_id, targets)
 var bank: Dictionary = drop_targets.banks[bank_id]
 match phase:
  &"hit":
   drop_targets.hits += 1
   bank.hits += 1
   if not _seen_targets.has(target_id):
    _seen_targets[target_id] = true
    drop_targets.unique_targets_hit += 1
    bank.unique_targets_hit += 1
  &"completed":
   drop_targets.bank_completions += 1
   bank.completions += 1
  &"reset":
   drop_targets.bank_resets += 1
   bank.resets += 1

func speed_started(distance: float, target_range: float) -> void:
 _dash_active = true
 _dash_bucket = "close" if distance <= target_range / 3.0 else ("medium" if distance <= target_range * 2.0 / 3.0 else "far")
 _speed.target_range_px = target_range
 _speed.targets_acquired += 1
 _speed.distance[_dash_bucket].acquired += 1

func speed_ended(reason: String) -> void:
 if not _dash_active or reason == "Hit": return # The physical-hit signal follows Hit.
 _dash_active = false
 _speed.failed_approaches += 1
 _speed.distance[_dash_bucket].failed += 1
 var key := reason.to_lower().replace(" ", "_")
 _speed.failures_by_reason[key] = int(_speed.failures_by_reason.get(key, 0)) + 1

func speed_hit(kind: String) -> void:
 if not _dash_active: return
 _dash_active = false
 _successful_uses += 1
 _speed.physical_target_hits += 1
 _speed.distance[_dash_bucket].hits += 1
 _speed.hits_by_target_type[kind] = int(_speed.hits_by_target_type.get(kind, 0)) + 1

func flight_started() -> void:
 _successful_uses += 1
 _fly.successful_activations += 1

func flight_lift_applied() -> void:
 _fly.rescue_lift_activations += 1

func observe_motion(delta: float, speed: float, eligible: bool, flight_remaining: float) -> void:
 ball_speed.observe(delta, speed, eligible)
 _fly.active_seconds += minf(maxf(0.0, delta), maxf(0.0, flight_remaining))

func area_target_activated(kind: String) -> void:
 _power.affected_by_type[kind] = int(_power.affected_by_type.get(kind, 0)) + 1

func _action_snapshot() -> Dictionary:
 var result := {"type": _action_type if not _action_type.is_empty() else null,
  "uses": type_actions.uses, "successful_uses": _successful_uses}
 match _action_type:
  "speed":
   result["speed"] = _speed.duplicate(true)
   result.speed["pending_approaches"] = 1 if _dash_active else 0
  "fly": result["fly"] = _fly.duplicate(true)
  "power": result["power"] = _power.duplicate(true)
 return result

func record_score(details: Dictionary) -> void:
 var kind := str(details.kind)
 var category := kind if score_by_category.has(kind) else "other"
 var normal := int(details.normal_total)
 score_by_category[category] += normal
 if details.get("combo_sensitive", false):
  var tier := str(clampi(int(details.multiplier), 1, 4))
  # Fixed completion and Homing's +400 are not attributed to a combo tier.
  combo_score_by_multiplier[tier] += int(details.get("combo_score", 0))
 if kind == "enemy": enemies.normal_score += normal
 if details.get("ability", "") == "homing":
  type_actions.successful_target_hits += 1
  homing.successful_hits += 1
  homing.normal_score += normal
  homing.hits_by_target_type[kind] = int(homing.hits_by_target_type.get(kind, 0)) + 1

func combo_advanced(kind: StringName, _object_id: String, tier: int, started: bool, at: float) -> void:
 if started:
  _combo_started_at = at
  _combo_peak = 1
 _combo_peak = maxi(_combo_peak, tier)
 highest_multiplier = maxi(highest_multiplier, tier)
 combo_advances_by_source[String(kind)] = int(combo_advances_by_source.get(String(kind), 0)) + 1
 if tier == 4: x4_activations += 1

func combo_supported(kind: StringName, _object_id: String) -> void:
 combo_support_by_source[String(kind)] = int(combo_support_by_source.get(String(kind), 0)) + 1

func combo_ended(_reason: String, _chain: int, _tier: int, at: float) -> void:
 if _combo_started_at == null: return
 var duration := maxf(0.0, at - float(_combo_started_at))
 if duration >= longest_combo_seconds:
  longest_combo_seconds = duration
  longest_combo_max_multiplier = _combo_peak
 _combo_started_at = null

func action_used(type_id: String) -> void:
 _action_type = type_id
 type_actions.uses += 1
 if type_id == "speed": homing.finishers_used += 1
 if type_id == "fly": _fly.activations += 1
 if type_id == "power": _power.uses += 1

func area_completed(_source: String, targets: int, rings: int) -> void:
 type_actions.affected_targets += targets
 type_actions.affected_rings += rings
 _power.affected_total += targets + rings
 _power.affected_by_type.ring += rings
 if targets + rings > 0: _successful_uses += 1

func enemy_event(type: StringName, event: String) -> void:
 enemies[event] += 1
 if not enemies.by_type.has(String(type)):
  enemies.by_type[String(type)] = {"destructions": 0, "respawns": 0}
 enemies.by_type[String(type)][event] += 1

func target_ready(at: float, score: int, buddy_score: int) -> void:
 if target_at != null: return
 target_at = at
 score_at_target = score
 buddy_at_target = buddy_score

func goal_touched(at: float) -> void:
 if goal_at == null: goal_at = at

static func ratio(numerator: float, denominator: float) -> Variant:
 return numerator / denominator if denominator > 0.0 else null

func finish_act(row: Dictionary, ended_at: float) -> Dictionary:
 var buddy_score := 0
 for points: int in row.buddy_contributions.values(): buddy_score += points
 var end: float = float(goal_at) if row.cleared and goal_at != null else ended_at
 var duration := maxf(0.0, end - started_at)
 var until_target: Variant = null if target_at == null else maxf(0.0, float(target_at) - started_at)
 var longest := longest_combo_seconds
 var peak := longest_combo_max_multiplier
 if _combo_started_at != null and end - float(_combo_started_at) >= longest:
  longest = maxf(0.0, end - float(_combo_started_at))
  peak = _combo_peak
 return {
  "zone": row.zone, "act": row.zone_act, "run_act": row.act,
  "title": row.title, "source": row.source, "cleared": row.cleared,
  "authored_difficulty": row.get("authored_difficulty"),
  "authored_difficulty_label": row.get("authored_difficulty_label"),
  "act_fingerprint": row.get("act_fingerprint"),
  "character": row.get("character"), "character_type": row.get("character_type"),
  "design_thesis": row.get("design_thesis", ""),
  "target": row.target, "theme": row.get("theme", ""),
  "act_start_time_seconds": started_at, "target_ready_time_seconds": target_at,
  "goal_touched_time_seconds": goal_at, "act_end_time_seconds": end,
  "time_to_target_seconds": until_target,
  "time_target_to_goal_seconds": null if target_at == null or goal_at == null else maxf(0.0, float(goal_at) - float(target_at)),
  "total_time_seconds": duration,
  "score_at_target": score_at_target, "final_score": row.score,
  "score_after_target": null if score_at_target == null else row.score - int(score_at_target),
  "buddy_score_at_target": buddy_at_target, "final_buddy_score": buddy_score,
  "buddy_score_after_target": null if buddy_at_target == null else buddy_score - int(buddy_at_target),
  "normal_score": row.score - buddy_score, "balls_lost": row.drains,
  "buddy_state": row.get("buddy_state", {}).duplicate(true),
  "score_per_second": ratio(row.score, duration),
  "score_per_second_until_target": null if until_target == null else ratio(float(score_at_target), float(until_target)),
  "final_score_over_target": ratio(row.score, row.target),
  "buddy_score_percent": ratio(buddy_score * 100.0, row.score),
  "score_by_category": score_by_category.duplicate(true),
  "combo_score_by_multiplier": combo_score_by_multiplier.duplicate(true),
  "combo_advances_by_source": combo_advances_by_source.duplicate(true),
  "combo_support_by_source": combo_support_by_source.duplicate(true),
  "x4_activations": x4_activations, "highest_multiplier": highest_multiplier,
  "longest_combo_seconds": longest, "longest_combo_max_multiplier": peak,
  "type_actions": type_actions.duplicate(true), "homing": homing.duplicate(true), "enemies": enemies.duplicate(true),
  "slingshots": slingshots.duplicate(true), "drop_targets": drop_targets.duplicate(true), "teleporters": teleporters.duplicate(true),
  "character_action": _action_snapshot(), "ball_speed": ball_speed.snapshot(),
  "wide_spring": null
 }

static func export_run(summary: Dictionary) -> Dictionary:
 var buddies := {}
 var buddy_score := 0
 for points: int in summary.buddy_contributions.values(): buddy_score += points
 for id: String in summary.buddies:
  buddies[id] = {"level": summary.buddies[id], "score_contribution": summary.buddy_contributions.get(id, 0)}
 var acts: Array = []
 for row: Dictionary in summary.acts: acts.append(row.telemetry.duplicate(true))
 var difficulties := {}
 var actions := {"uses": 0, "successful_uses": 0}
 for act: Dictionary in acts:
  if act.get("cleared", false) and act.get("authored_difficulty") != null:
   var key := str(act.authored_difficulty)
   difficulties[key] = int(difficulties.get(key, 0)) + 1
  var action: Dictionary = act.get("character_action", {})
  var uses: Variant = action.get("uses", act.get("type_actions", {}).get("uses"))
  actions.uses = null if uses == null or actions.uses == null else int(actions.uses) + int(uses)
  var successes: Variant = action.get("successful_uses")
  actions.successful_uses = null if successes == null or actions.successful_uses == null else int(actions.successful_uses) + int(successes)
 return {"telemetry_format_version": FORMAT_VERSION, "run_seed": summary.seed,
  "completed_act_difficulties": difficulties, "action_totals": actions,
  "run_configuration": summary.get("run_configuration", {}).duplicate(true),
  "configuration_fingerprint": summary.get("configuration_fingerprint", ""),
  "course": summary.get("course", []).duplicate(true),
  "mode": "practice" if summary.practice else "challenge", "character": summary.character,
  "character_type": CharacterSpecials.CHARACTERS[summary.character].character_type,
  "type_action": CharacterSpecials.CHARACTERS[summary.character].type_action.action_name,
  "won": summary.won, "completed": summary.get("completed", summary.won),
  "termination_reason": summary.get("termination_reason", "completed" if summary.won else "out_of_balls"),
  "run_feel": summary.get("run_feel", ""),
  "ended_at_local": summary.get("ended_at_local", ""), "started": summary.get("started", true),
  "total_score": summary.score, "normal_score": summary.normal_score,
  "buddy_score": buddy_score, "total_time_seconds": summary.seconds,
  "balls_lost": summary.drains, "buddies": buddies,
  "buddy_state": summary.get("buddy_state", {}).duplicate(true), "acts": acts}
