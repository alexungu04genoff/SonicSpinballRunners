extends RefCounted
## A small run-local catalogue. Bonuses are flat additions after combo/special scoring.
const CATALOG := {
 "ring_scout": {"name": "Ring Scout", "points": 10, "kinds": ["ring"], "trigger": "each ring collected"},
 "bumper_coach": {"name": "Bumper Coach", "points": 75, "kinds": ["bumper"], "trigger": "each bumper award"},
 "feature_fox": {"name": "Feature Fox", "points": 250, "kinds": ["ring_rack", "switch_bank", "spinner_goal", "lane_set"], "trigger": "each completed rack, bank,\nspinner goal or lane set"}
}
var levels: Dictionary = {}

func choose(id: String) -> bool:
 if not CATALOG.has(id) or int(levels.get(id, 0)) >= 2: return false
 levels[id] = int(levels.get(id, 0)) + 1
 return true

func offers() -> Array[Dictionary]:
 var choices: Array[Dictionary] = []
 for id: String in CATALOG:
  var level := int(levels.get(id, 0)) + 1
  if level > 2: continue
  var item: Dictionary = CATALOG[id]
  choices.append({"id": id, "name": item.name, "level": level, "description": "+%d points for %s.\nFlat bonus; no extra combo or special charge." % [int(item.points) * level, item.trigger]})
 return choices

func modifiers() -> Dictionary:
 var bonuses := {}
 for id: String in levels:
  bonuses[id] = {"kinds": CATALOG[id].kinds.duplicate(), "points": int(CATALOG[id].points) * int(levels[id])}
 return bonuses

func summary() -> String:
 var names := PackedStringArray()
 for id: String in levels: names.append("%s Lv.%d" % [CATALOG[id].name, levels[id]])
 return " · ".join(names) if not names.is_empty() else "No Buddies yet"

static func total(contributions: Dictionary) -> int:
 var amount := 0
 for value: int in contributions.values(): amount += value
 return amount
