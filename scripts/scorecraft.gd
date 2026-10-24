class_name Scorecraft
extends Node
## Calculates awards from existing contacts; game.gd still owns the run score.
signal combo_changed(chain: int, multiplier: int)
signal combo_ended(reason: String, chain: int, multiplier: int)
signal score_awarded(details: Dictionary)
const BUMPER_POINTS := 100
const RING_POINTS := 25
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
var _bumpers_seen: Dictionary = {}
var has_ring_link := false

func _ready() -> void:
 # Green Hill's UI root processes during pause; gameplay timers must not.
 process_mode = Node.PROCESS_MODE_PAUSABLE

func _advance() -> void:
 chain += 1
 # Fresh bumpers can build x2; the top tier requires a completed ring link.
 multiplier = mini(chain, mini(clampi(config.multiplier_cap, 1, 3), 3 if has_ring_link else 2))
 remaining = maxf(0.5, config.combo_window)
 combo_changed.emit(chain, multiplier)

func award_bumper(body: Node, special_multiplier: int = 1) -> int:
 var eligible := enabled and not _bumpers_seen.has(body.get_instance_id())
 if eligible:
  _bumpers_seen[body.get_instance_id()] = true
  ring_progress = 0
  ring_link_available = true
  _advance()
 var applied := multiplier if eligible else 1
 # The existing x5 special is base + 400. Multiply the base only, once.
 var bonus := BUMPER_POINTS * maxi(0, special_multiplier - 1)
 var amount := _award("bumper", BUMPER_POINTS, applied, bonus, eligible, body.get_instance_id())
 if bonus > 0:
  reset("Homing finish")
 return amount

func award_ring() -> int:
 if enabled and chain > 0 and ring_link_available:
  ring_progress += 1
  if ring_progress >= maxi(1, config.rings_per_link):
   ring_link_available = false
   has_ring_link = true
   _advance()
  else:
   combo_changed.emit(chain, multiplier)
 # Extra rings earn the current multiplier but cannot sustain it indefinitely.
 return _award("ring", RING_POINTS, multiplier if enabled else 1, 0, false)

func award_rack() -> int:
 # Rack completion is a fixed award, never a combo link or timer refresh.
 return _award("rack", RACK_POINTS, 1, 0, false)

func _award(kind: String, base: int, applied: int, bonus: int, eligible: bool, target_id: int = 0) -> int:
 var amount := base * applied + bonus
 last_award = {"kind": kind, "base": base, "multiplier": applied, "special_bonus": bonus, "total": amount, "chain": chain, "fresh_bumper": eligible, "target_id": target_id}
 feedback_remaining = 2.0
 score_awarded.emit(last_award.duplicate())
 return amount

func reset(reason: String, clear_feedback: bool = false) -> void:
 var previous_chain := chain
 var previous_multiplier := multiplier
 chain = 0
 multiplier = 1
 remaining = 0.0
 ring_progress = 0
 ring_link_available = false
 _bumpers_seen.clear()
 has_ring_link = false
 if clear_feedback:
  last_award.clear()
  feedback_remaining = 0.0
 if previous_chain > 0:
  combo_ended.emit(reason, previous_chain, previous_multiplier)
  combo_changed.emit(chain, multiplier)

func _physics_process(delta: float) -> void:
 feedback_remaining = maxf(0.0, feedback_remaining - delta)
 if chain > 0:
  remaining = maxf(0.0, remaining - delta)
  if remaining == 0.0:
   reset("Expired")
