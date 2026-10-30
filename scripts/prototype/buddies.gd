extends RefCounted
## Run-local state. Only real physical/enemy events enter the reward hooks.
signal virtual_rings_awarded(amount: int, buddy_id: String)
const Catalog = preload("res://scripts/prototype/buddy_catalog.gd")
const CATALOG = Catalog.ENTRIES
const PERSISTENT_CAP := 5
var levels: Dictionary = {}
var run_seed := 0
var draft_index := 0
var _pending: Array[Dictionary] = []
var _draft_open := false
var next_act_balls := 0
var rescues_used: Dictionary = {}
var cadence: Dictionary = {}
var run_counters: Dictionary = {}
var zone_counters: Dictionary = {}
var act_counters: Dictionary = {}
var contributions: Dictionary = {}
var act_contributions: Dictionary = {}
var zone := -1

func persistent_slots() -> int:
 var count := 0
 for id: String in levels:
  if CATALOG[id].persistent: count += 1
 return count

func can_acquire(id: String) -> bool:
 if not CATALOG.has(id): return false
 var level := int(levels.get(id, 0))
 return level < int(CATALOG[id].max_level) and (level > 0 or not CATALOG[id].persistent or persistent_slots() < PERSISTENT_CAP)

func choose(id: String) -> bool:
 if not can_acquire(id): return false
 if _draft_open and not _pending.any(func(offer): return offer.id == id): return false
 levels[id] = int(levels.get(id, 0)) + 1
 for effect: Dictionary in CATALOG[id].effects:
  if effect.id == "next_act_balls": next_act_balls += int(_value(id, effect))
 _count("acquisitions")
 _pending.clear()
 _draft_open = false
 draft_index += 1
 return true

func offers() -> Array[Dictionary]:
 if _draft_open: return _pending.duplicate(true)
 var valid: Array[String] = []
 for id: String in CATALOG:
  if can_acquire(id): valid.append(id)
 var rng := RandomNumberGenerator.new()
 rng.seed = (str(run_seed) + ":buddy-draft:" + str(draft_index)).hash()
 while not valid.is_empty() and _pending.size() < 3:
  var index := rng.randi_range(0, valid.size() - 1)
  var id := valid[index]
  valid.remove_at(index)
  var item := Catalog.definition(id)
  item["level"] = int(levels.get(id, 0)) + 1
  item["description"] = item.descriptions[item.level - 1]
  item["acquired"] = levels.has(id)
  _pending.append(item)
 _draft_open = true
 return _pending.duplicate(true)

func _value(id: String, effect: Dictionary) -> Variant:
 return effect.values[int(levels[id]) - 1]

func modifiers() -> Dictionary:
 var bonuses := {}
 for id: String in levels:
  for effect: Dictionary in CATALOG[id].effects:
   if effect.id == "score_percent": bonuses[id] = {"kinds": effect.kinds.duplicate(), "percent": float(_value(id, effect))}
 return bonuses

func physics_modifier() -> PhysicsModifier:
 var modifier := PhysicsModifier.new()
 modifier.display_name = "Adventure Buddies"
 for id: String in levels:
  for effect: Dictionary in CATALOG[id].effects:
   if effect.id != "physics": continue
   var values: Dictionary = _value(id, effect)
   for key: String in values: modifier.multipliers[key] = float(modifier.multipliers.get(key, 1.0)) * float(values[key])
 return modifier

func begin_act(base_balls: int, practice: bool, zone_index: int) -> int:
 act_counters.clear()
 act_contributions.clear()
 if zone != zone_index:
  zone_counters.clear()
  zone = zone_index
 var stock := base_balls
 for id: String in levels:
  for effect: Dictionary in CATALOG[id].effects:
   if effect.id == "starting_balls" and not practice: stock += int(_value(id, effect))
 stock = maxi(1, stock) + next_act_balls
 next_act_balls = 0
 return stock

func rescue() -> bool:
 for id: String in levels:
  for effect: Dictionary in CATALOG[id].effects:
   if effect.id != "rescue" or int(rescues_used.get(id, 0)) >= int(_value(id, effect)): continue
   rescues_used[id] = int(rescues_used.get(id, 0)) + 1
   _count("rescues")
   return true
 return false

func physical_ring_collected() -> void:
 _count("physical_rings")
 for id: String in levels:
  for effect: Dictionary in CATALOG[id].effects:
   if effect.id != "physical_ring_cadence": continue
   cadence[id] = int(cadence.get(id, 0)) + 1
   if int(cadence[id]) >= int(effect.every):
    cadence[id] -= int(effect.every)
    _virtual_rings(int(_value(id, effect)), id)

func enemy_destroyed(_enemy_type: StringName, _object_id: String, _source: StringName) -> void:
 _count("enemies")
 for id: String in levels:
  for effect: Dictionary in CATALOG[id].effects:
   if effect.id == "enemy_rings": _virtual_rings(int(_value(id, effect)), id)

func _virtual_rings(amount: int, id: String) -> void:
 _count("virtual_rings", amount)
 _count("virtual_rings:" + id, amount)
 virtual_rings_awarded.emit(amount, id)

func record_score(details: Dictionary) -> void:
 for id: String in details.get("buddy_bonuses", {}):
  var bonus := int(details.buddy_bonuses[id])
  contributions[id] = int(contributions.get(id, 0)) + bonus
  act_contributions[id] = int(act_contributions.get(id, 0)) + bonus
 _count("score", int(details.total))

func _count(key: String, amount := 1) -> void:
 for counters: Dictionary in [run_counters, zone_counters, act_counters]: counters[key] = int(counters.get(key, 0)) + amount

func state() -> Dictionary:
 return {"rescues_used": rescues_used.duplicate(), "next_act_balls": next_act_balls, "cadence": cadence.duplicate(), "run": run_counters.duplicate(), "zone": zone_counters.duplicate(), "act": act_counters.duplicate(), "summary": summary()}

func summary() -> String:
 var names := PackedStringArray()
 for id: String in levels:
  var label := "%s Lv.%d" % [CATALOG[id].name, levels[id]]
  if not CATALOG[id].persistent: label = CATALOG[id].name + " (acquired)"
  for effect: Dictionary in CATALOG[id].effects:
   if effect.id == "rescue": label += " (rescue used)" if rescues_used.has(id) else " (rescue ready)"
  names.append(label)
 return " · ".join(names) if not names.is_empty() else "No Buddies yet"

static func total(values: Dictionary) -> int:
 var amount := 0
 for value: int in values.values(): amount += value
 return amount
