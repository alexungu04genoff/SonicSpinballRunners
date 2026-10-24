class_name ZoneRun
extends RefCounted
## Progress observes the existing score. Physics and UI consume these public events.
signal changed
signal exit_opened(act: int)
signal draft_started(act: int)
signal act_started(act: int)
signal completed
enum State { INACTIVE, PLAYING, DRAFT, COMPLETE }
var state: State = State.INACTIVE
var enabled := false
var active_act := 0
var completed_acts := 0
var act_score := 0
var exit_unlocked := false
var targets: Array[int] = []
var acquired: Array[String] = []
var completed_scores: Array[int] = []
var acts: Array = []
var config: ZoneConfig
var _score_at_entry := 0

func reset(active: bool, settings: ZoneConfig, layout: Dictionary) -> void:
 enabled = active
 config = settings
 targets = settings.act_targets.duplicate()
 acts = layout.get("acts", [])
 active_act = 0
 completed_acts = 0
 act_score = 0
 _score_at_entry = 0
 exit_unlocked = false
 acquired.clear()
 completed_scores.clear()
 state = State.PLAYING if enabled else State.INACTIVE
 changed.emit()

func observe_score(total: int) -> void:
 if state != State.PLAYING:
  return
 act_score = maxi(0, total - _score_at_entry)
 if not exit_unlocked and act_score >= targets[active_act]:
  exit_unlocked = true
  exit_opened.emit(active_act)
 changed.emit()

func observe_motion(previous: Vector2, current: Vector2) -> bool:
 if state != State.PLAYING or not exit_unlocked:
  return false
 var act: Dictionary = acts[active_act]
 var reached := false
 if active_act < 2:
  # Commit only above the incoming funnel's collision envelope. The funnel
  # and gate can then activate without moving the body or changing its velocity.
  var crossing_y: float = act.get("clear_y", act.exit_y - PlaygroundBall.RADIUS - ZoneGate.THICKNESS * 0.5 - 2.0)
  if previous.y >= crossing_y and current.y < crossing_y:
   var x := lerpf(previous.x, current.x, (crossing_y - previous.y) / (current.y - previous.y))
   reached = x >= act.exit_left and x <= act.exit_right
 else:
  var near := Geometry2D.get_closest_point_to_segment(act.goal_position, previous, current)
  reached = near.distance_squared_to(act.goal_position) <= ScoreAttack.CONTACT_RADIUS * ScoreAttack.CONTACT_RADIUS
 if not reached:
  return false
 completed_acts += 1
 completed_scores.append(act_score)
 state = State.DRAFT
 draft_started.emit(active_act)
 changed.emit()
 return true

func accept_reward(id: String, total: int) -> void:
 acquired.append(id)
 if active_act == 2:
  state = State.COMPLETE
  completed.emit()
 else:
  active_act += 1
  _score_at_entry = total
  act_score = 0
  exit_unlocked = false
  state = State.PLAYING
  act_started.emit(active_act)
 changed.emit()
