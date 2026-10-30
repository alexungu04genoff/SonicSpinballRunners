extends SceneTree
const Telemetry = preload("res://scripts/prototype/run_telemetry.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error(message)
func _initialize() -> void:
 var telemetry := Telemetry.new()
 var row := {"zone": 2, "zone_act": 1, "act": 4, "title": "Fixture", "source": "fixture.tres", "cleared": true, "target": 1000, "score": 1800, "drains": 2, "buddy_contributions": {"feature_fox": 500}}
 telemetry.begin_act(10.0)
 telemetry.target_ready(15.0, 1100, 250)
 telemetry.target_ready(18.0, 1600, 500)
 telemetry.goal_touched(23.0)
 telemetry.goal_touched(29.0)
 var result := telemetry.finish_act(row, 30.0)
 check(result.target_ready_time_seconds == 15.0 and result.score_at_target == 1100 and result.buddy_score_at_target == 250, "First target snapshot is immutable, including Buddy overshoot")
 check(result.time_to_target_seconds == 5.0 and result.time_target_to_goal_seconds == 8.0 and result.total_time_seconds == 13.0, "Goal contact time excludes later streaming waits")
 check(result.score_after_target == 700 and result.buddy_score_after_target == 250 and result.normal_score == 1300, "Post-target totals reconcile")
 check(result.balls_lost == 2 and result.act == 1 and result.run_act == 4, "Act identity and lost balls preserved")
 check(is_equal_approx(result.score_per_second_until_target, 220.0) and is_equal_approx(result.final_score_over_target, 1.8), "Derived ratios retain raw inputs")
 telemetry.begin_act(40.0)
 row.cleared = false
 row.score = 0
 row.buddy_contributions = {}
 result = telemetry.finish_act(row, 45.0)
 check(result.target_ready_time_seconds == null and result.score_at_target == null and result.score_after_target == null and result.buddy_score_after_target == null, "Failed Act without target exports unavailable snapshots as null")
 check(result.goal_touched_time_seconds == null and result.time_target_to_goal_seconds == null and result.total_time_seconds == 5.0, "Failure retains actual end time without inventing goal contact")
 check(result.buddy_score_percent == null, "Zero-score ratio is unavailable")
 row.score = 1200
 telemetry.target_ready(44.0, 1000, 0)
 result = telemetry.finish_act(row, 45.0)
 check(result.time_to_target_seconds == 4.0 and result.time_target_to_goal_seconds == null, "Failure after target retains readiness but no goal time")
 check(Telemetry.ratio(10, 0) == null, "Zero-duration rates do not produce infinity")
 var summary := {"won": false, "seed": 18, "practice": true, "character": "sonic", "score": 1800, "normal_score": 1300, "buddy_contributions": {"feature_fox": 500}, "buddies": {"feature_fox": 2}, "seconds": 45.0, "drains": 2, "acts": [{"telemetry": result}]}
 var exported := Telemetry.export_run(summary)
 check(exported.mode == "practice" and exported.buddy_score == 500 and exported.buddies.feature_fox.level == 2, "Run mode and Buddy build exported")
 check(JSON.parse_string(JSON.stringify(exported)).acts[0].goal_touched_time_seconds == null, "JSON round trip preserves nulls")
 print("RESULT | Run telemetry | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
