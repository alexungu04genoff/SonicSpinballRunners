extends RefCounted
## Passive snapshots on the existing gameplay clock. No RNG, I/O or scoring writes.
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
var homing := {}
var enemies := {}
var _combo_started_at: Variant = null
var _combo_peak := 1

func begin_act(at: float) -> void:
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
 homing = {"finishers_used": 0, "successful_hits": 0, "normal_score": 0, "hits_by_target_type": {}}
 enemies = {"destructions": 0, "respawns": 0, "normal_score": 0, "by_type": {}}

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

func homing_used() -> void:
 homing.finishers_used += 1

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
  "homing": homing.duplicate(true), "enemies": enemies.duplicate(true)
 }

static func export_run(summary: Dictionary) -> Dictionary:
 var buddies := {}
 var buddy_score := 0
 for points: int in summary.buddy_contributions.values(): buddy_score += points
 for id: String in summary.buddies:
  buddies[id] = {"level": summary.buddies[id], "score_contribution": summary.buddy_contributions.get(id, 0)}
 var acts: Array = []
 for row: Dictionary in summary.acts: acts.append(row.telemetry.duplicate(true))
 return {"telemetry_format_version": 2, "run_seed": summary.seed,
  "run_configuration": summary.get("run_configuration", {}).duplicate(true),
  "configuration_fingerprint": summary.get("configuration_fingerprint", ""),
  "course": summary.get("course", []).duplicate(true),
  "mode": "practice" if summary.practice else "challenge", "character": summary.character,
  "won": summary.won, "completed": summary.get("completed", summary.won),
  "termination_reason": summary.get("termination_reason", "completed" if summary.won else "out_of_balls"),
  "run_feel": summary.get("run_feel", ""),
  "ended_at_local": summary.get("ended_at_local", ""), "started": summary.get("started", true),
  "total_score": summary.score, "normal_score": summary.normal_score,
  "buddy_score": buddy_score, "total_time_seconds": summary.seconds,
  "balls_lost": summary.drains, "buddies": buddies,
  "buddy_state": summary.get("buddy_state", {}).duplicate(true), "acts": acts}
