extends RefCounted
## Passive snapshots on the existing gameplay clock. No RNG, I/O or scoring writes.
var started_at := 0.0
var target_at: Variant = null
var goal_at: Variant = null
var score_at_target: Variant = null
var buddy_at_target: Variant = null

func begin_act(at: float) -> void:
 started_at = at
 target_at = null
 goal_at = null
 score_at_target = null
 buddy_at_target = null

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
 return {
  "zone": row.zone, "act": row.zone_act, "run_act": row.act,
  "title": row.title, "source": row.source, "cleared": row.cleared,
  "target": row.target,
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
  "score_per_second": ratio(row.score, duration),
  "score_per_second_until_target": null if until_target == null else ratio(float(score_at_target), float(until_target)),
  "final_score_over_target": ratio(row.score, row.target),
  "buddy_score_percent": ratio(buddy_score * 100.0, row.score)
 }

static func export_run(summary: Dictionary) -> Dictionary:
 var buddies := {}
 var buddy_score := 0
 for points: int in summary.buddy_contributions.values(): buddy_score += points
 for id: String in summary.buddies:
  buddies[id] = {"level": summary.buddies[id], "score_contribution": summary.buddy_contributions.get(id, 0)}
 var acts: Array = []
 for row: Dictionary in summary.acts: acts.append(row.telemetry.duplicate(true))
 return {"telemetry_format_version": 1, "run_seed": summary.seed,
  "mode": "practice" if summary.practice else "challenge", "character": summary.character,
  "won": summary.won, "total_score": summary.score, "normal_score": summary.normal_score,
  "buddy_score": buddy_score, "total_time_seconds": summary.seconds,
  "balls_lost": summary.drains, "buddies": buddies, "acts": acts}
