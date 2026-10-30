class_name Scorecraft
extends Node
## Calculates awards from existing contacts; game.gd still owns the run score.
signal combo_changed(chain: int, multiplier: int)
signal combo_ended(reason: String, chain: int, multiplier: int)
signal score_awarded(details: Dictionary)
signal combo_supported(kind: StringName, object_id: String)
signal combo_advanced(kind: StringName, object_id: String, tier: int, started: bool)
const BUMPER_POINTS := 100
const RING_POINTS := 15
const RACK_POINTS := 500
var config: ScorecraftConfig = preload("res://data/scorecraft.tres")
var enabled := true
var chain := 0
var multiplier := 1
var remaining := 0.0
var ring_progress := 0
var ring_link_available := false
var last_award: Dictionary = {}
var feedback_remaining := 0.0
var _builders_seen: Dictionary = {}
var _supports_seen: Dictionary = {}
var protected_rail := ""
var rail_protection_remaining := 0.0
var act_context := ""
var support_feedback_remaining := 0.0
var combo_feedback := ""
var combo_feedback_remaining := 0.0
## Optional run-owned bonuses. Empty for existing standalone and Endless play.
var award_bonuses: Dictionary = {}

func _ready() -> void:
 # Green Hill's UI root processes during pause; gameplay timers must not.
 process_mode = Node.PROCESS_MODE_PAUSABLE

func _advance(kind: StringName, object_id: String) -> void:
 var started := chain == 0
 var previous := multiplier
 multiplier = 1 if started else mini(multiplier + 1, clampi(config.multiplier_cap, 1, 4))
 # The visible tier is authoritative; there are no queued advances behind it.
 chain = multiplier
 remaining = maxf(0.5, config.combo_window)
 if multiplier >= clampi(config.multiplier_cap, 1, 4):
  ring_link_available = false
  ring_progress = 0
 if started or multiplier > previous:
  combo_advanced.emit(kind, object_id, multiplier, started)
  combo_feedback = "RING LINK · COMBO ×%d" % multiplier if kind == &"ring_link" else "COMBO ×%d" % multiplier
  combo_feedback_remaining = 1.5
 else:
  combo_supported.emit(&"builder_refresh", object_id)
 combo_changed.emit(chain, multiplier)

func builder_eligible(kind: StringName, object_id: String) -> bool:
 return enabled and not _builders_seen.has(String(kind) + ":" + object_id)

func _build(kind: StringName, object_id: String) -> bool:
 if not builder_eligible(kind, object_id): return false
 _builders_seen[String(kind) + ":" + object_id] = true
 _advance(kind, object_id)
 if multiplier < clampi(config.multiplier_cap, 1, 4) and not ring_link_available:
  ring_link_available = true
  ring_progress = 0
 return true

static func bumper_source(body: Node) -> String:
 return str(body.get_meta("scoring_source", body.get_instance_id()))

func bumper_can_build_multiplier(body: Node) -> bool:
 return is_instance_valid(body) and builder_eligible(&"bumper", bumper_source(body)) and (chain == 0 or multiplier < clampi(config.multiplier_cap, 1, 4))

func rings_can_build_multiplier() -> bool:
 return enabled and chain > 0 and ring_link_available and multiplier < clampi(config.multiplier_cap, 1, 4)

func award_bumper(body: Node, special_multiplier: int = 1) -> int:
 if special_multiplier > 1:
  return award_homing(&"bumper", bumper_source(body), BUMPER_POINTS, body.get_instance_id())
 var eligible := _build(&"bumper", bumper_source(body))
 var applied := multiplier if eligible else 1
 return _award("bumper", BUMPER_POINTS, applied, 0, eligible, body.get_instance_id(), bumper_source(body), "", eligible or not enabled)

func award_homing(kind: StringName, object_id: String, base: int, target_id := 0) -> int:
 # Cash out the pre-hit tier, including on an already-used target. No builder.
 var amount := _award(String(kind), base, multiplier if enabled else 1, 400, false, target_id, object_id, "homing", true)
 reset("Homing finish")
 return amount

func award_ring(object_id: String = "") -> int:
 if rings_can_build_multiplier():
  ring_progress += 1
  if ring_progress >= maxi(1, config.rings_per_link):
   ring_link_available = false
   ring_progress = 0
   _advance(&"ring_link", object_id)
  else:
   combo_changed.emit(chain, multiplier)
 # Extra rings earn the current multiplier but cannot sustain it indefinitely.
 return _award("ring", RING_POINTS, multiplier if enabled else 1, 0, false, 0, object_id, "", true)

func award_spinner(points: int) -> int:
 # Ticks use the current tier without advancing or sustaining the combo.
 return award_mechanic(&"spinner_tick", "", points)

func award_mechanic(kind: StringName, object_id: String, points: int) -> int:
 # Authored amounts remain authoritative. Completion payouts stay fixed even
 # when that completion advances the combo; no mechanic award charges Special.
 var amount := clampi(points, 0, 25) if kind in [&"spinner", &"spinner_tick"] else clampi(points, 0, 100000)
 if kind == &"spinner": kind = &"spinner_tick"
 if kind == &"wall_switch": kind = &"switch"
 if kind in [&"enemy", &"switch_bank", &"spinner_goal", &"lane_set"]:
  _build(kind, object_id)
 elif kind in [&"switch", &"lane"]:
  support_combo(kind, object_id)
 elif kind == &"ring_rack":
  support_combo(kind, object_id, false)
 var sensitive := kind in [&"enemy", &"switch", &"spinner_tick", &"lane"]
 return _award(String(kind), amount, multiplier if enabled and sensitive else 1, 0, false, 0, object_id, "", sensitive)

func award_rack() -> int:
 # Rack completion can refresh an active combo but cannot start or advance it.
 return award_mechanic(&"ring_rack", "", RACK_POINTS)

func award_area(kind: String, source: String, scale: int, body: Node = null, object_id: String = "") -> int:
 # Area abilities pay fixed base awards. They neither advance nor refresh a
 # chain, and their bonus never receives the current combo multiplier.
 var base := BUMPER_POINTS if kind == "bumper" else RING_POINTS
 if is_instance_valid(body): object_id = str(body.get_meta("scoring_source", body.get_instance_id()))
 return _award(kind, base, clampi(scale, 1, 2), 0, false, body.get_instance_id() if is_instance_valid(body) else 0, object_id, source)

func _award(kind: String, base: int, applied: int, bonus: int, eligible: bool, target_id: int = 0, object_id: String = "", ability: String = "", combo_sensitive := false) -> int:
 var amount := base * applied + bonus
 if amount <= 0: return 0
 var normal_total := amount
 var buddy_bonuses := {}
 for id: String in award_bonuses:
  var modifier: Dictionary = award_bonuses[id]
  if kind not in modifier.kinds and "*" not in modifier.kinds: continue
  # Each contribution uses the completed normal award, never another Buddy's
  # contribution. Round each positive contribution to the nearest whole point.
  var extra := maxi(0, roundi(normal_total * float(modifier.get("percent", 0.0))) + clampi(int(modifier.get("points", 0)), 0, 100000))
  if extra <= 0: continue
  buddy_bonuses[id] = extra
  amount += extra
 last_award = {"kind": kind, "base": base, "multiplier": applied, "special_bonus": bonus, "normal_total": normal_total, "buddy_bonuses": buddy_bonuses, "total": amount, "chain": chain, "fresh_bumper": eligible, "target_id": target_id, "object_id": object_id, "act_id": act_context, "ability": ability, "combo_sensitive": combo_sensitive, "combo_score": base * applied if combo_sensitive else 0}
 feedback_remaining = 2.0
 score_awarded.emit(last_award.duplicate())
 return amount

func traversal_event(kind: StringName, object_id: String, phase: StringName) -> bool:
 if kind == &"elevated_rail" and phase in [&"exited", &"completed"]:
  var travelled := protected_rail == object_id
  if protected_rail == object_id:
   protected_rail = ""
   rail_protection_remaining = 0.0
  return support_combo(kind, object_id) if travelled and phase == &"completed" else false
 if not enabled or chain <= 0: return false
 if kind == &"elevated_rail" and phase == &"entered":
  # A repeated entry notification cannot refill an existing ride's budget.
  if protected_rail.is_empty():
   protected_rail = object_id
   rail_protection_remaining = clampf(config.rail_protection_budget, 0.0, 5.0)
  return false
 if kind not in [&"spring", &"dash_panel", &"lane"] or phase != &"used": return false
 return support_combo(kind, object_id)

func support_combo(kind: StringName, object_id: String, once := true) -> bool:
 if not enabled or chain <= 0: return false
 var key := String(kind) + ":" + object_id
 if once and _supports_seen.has(key): return false
 if once: _supports_seen[key] = true
 remaining = maxf(0.5, config.combo_window)
 support_feedback_remaining = 1.5
 combo_supported.emit(kind, object_id)
 return true

func reset(reason: String, clear_feedback: bool = false) -> void:
 var previous_chain := chain
 var previous_multiplier := multiplier
 chain = 0
 multiplier = 1
 remaining = 0.0
 ring_progress = 0
 ring_link_available = false
 _builders_seen.clear()
 _supports_seen.clear()
 protected_rail = ""
 rail_protection_remaining = 0.0
 support_feedback_remaining = 0.0
 combo_feedback = ""
 combo_feedback_remaining = 0.0
 if clear_feedback:
  last_award.clear()
  feedback_remaining = 0.0
 if previous_chain > 0:
  combo_ended.emit(reason, previous_chain, previous_multiplier)
  combo_changed.emit(chain, multiplier)

func _physics_process(delta: float) -> void:
 combo_feedback_remaining = maxf(0.0, combo_feedback_remaining - delta)
 feedback_remaining = maxf(0.0, feedback_remaining - delta)
 support_feedback_remaining = maxf(0.0, support_feedback_remaining - delta)
 if chain > 0:
  var protected_time := minf(delta, rail_protection_remaining) if not protected_rail.is_empty() else 0.0
  rail_protection_remaining = maxf(0.0, rail_protection_remaining - protected_time)
  delta -= protected_time
  remaining = maxf(0.0, remaining - delta)
  if remaining == 0.0:
   if config.tiered_decay and multiplier > 2:
    multiplier -= 1
    chain = multiplier
    remaining = maxf(0.5, config.combo_window)
    combo_changed.emit(chain, multiplier)
   else:
    reset("Expired")
