extends RefCounted
## Authored relationships only. Runtime completion never mutates these records.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")

static func validation_errors(banks: Variant, objects: Variant) -> PackedStringArray:
 var errors := PackedStringArray()
 if not banks is Array:
  return PackedStringArray(["Switch banks must be an array."])
 if not objects is Array: return errors
 var types := {}
 for i in objects.size():
  if objects[i] is Dictionary: types[Objects.identity(objects[i], i)] = objects[i].get("type")
 var ids := {}
 for bank: Variant in banks:
  if not bank is Dictionary or not bank.has_all(["bank_id", "label", "members", "gates"]):
   errors.append("Each switch bank needs bank_id, label, members and gates.")
   continue
  for key: Variant in bank:
   if key not in ["bank_id", "label", "members", "gates", "actions", "completion_bonus", "reset_delay"]: errors.append("Unknown switch bank field: " + str(key))
  if typeof(bank.bank_id) != TYPE_STRING or bank.bank_id.is_empty() or ids.has(bank.bank_id):
   errors.append("Switch bank IDs must be nonempty and unique.")
  else: ids[bank.bank_id] = true
  if typeof(bank.label) != TYPE_STRING or bank.label.length() > 80:
   errors.append("Switch bank label must be a string of at most 80 characters.")
  for key: String in ["members", "gates"]:
   if not bank[key] is Array:
    errors.append("Switch bank %s must be an array of object IDs." % key)
    continue
   if key == "members" and bank[key].is_empty(): errors.append("A switch bank needs at least one member.")
   var seen := {}
   for id: Variant in bank[key]:
    var expected := ["switch_target", "wall_switch"] if key == "members" else ["one_way_gate"]
    if typeof(id) != TYPE_STRING or types.get(id) not in expected or seen.has(id):
     errors.append("Switch bank %s contains a missing, wrong-type or duplicate object ID." % key)
    else: seen[id] = true
  var linked := {}
  if bank.gates is Array:
   for id: Variant in bank.gates: linked[id] = true
  if not bank.get("actions", []) is Array:
   errors.append("Bank actions must be an array.")
  else:
   for action: Variant in bank.get("actions", []):
    if not action is Dictionary or action.size() != 2 or not action.has_all(["object_id", "action"]):
     errors.append("Bank action needs object_id and action.")
     continue
    var type: Variant = types.get(action.object_id)
    if typeof(action.object_id) != TYPE_STRING or linked.has(action.object_id) or (type == "one_way_gate" and action.action != "open") or (type == "diverter" and action.action not in ["set_a", "set_b", "toggle"]) or type not in ["one_way_gate", "diverter"]:
     errors.append("Unsupported, duplicate or missing switch bank action target.")
    linked[action.object_id] = true
  for key: String in ["completion_bonus", "reset_delay"]:
   var value: Variant = bank.get(key, 0.0)
   if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) or float(value) < 0.0 or float(value) > (10.0 if key == "reset_delay" else 100000.0):
    errors.append("Invalid bank " + key)
 return errors

static func fingerprint_records(banks: Variant) -> Array:
 if not banks is Array: return [banks]
 var result: Array = []
 for bank: Variant in banks:
  if not bank is Dictionary:
   result.append(bank)
   continue
  var links: Variant = bank.get("actions", [])
  var ordered: Array = []
  if links is Array:
   for link: Variant in links: ordered.append([link.get("object_id"), link.get("action")] if link is Dictionary else link)
  else: ordered.append(links)
  var bonus: Variant = bank.get("completion_bonus", 0.0)
  var delay: Variant = bank.get("reset_delay", 0.0)
  result.append([bank.get("bank_id"), bank.get("label"), bank.get("members"), bank.get("gates"), ordered, float(bonus) if typeof(bonus) in [TYPE_INT, TYPE_FLOAT] else bonus, float(delay) if typeof(delay) in [TYPE_INT, TYPE_FLOAT] else delay])
 return result

static func remove_objects(banks: Array, ids: Array) -> void:
 for i in range(banks.size() - 1, -1, -1):
  for id: String in ids:
   banks[i].members.erase(id)
   banks[i].gates.erase(id)
   if banks[i].has("actions"):
    banks[i].actions = banks[i].actions.filter(func(action): return action.object_id != id)
  if banks[i].members.is_empty(): banks.remove_at(i)

static func actions(bank: Dictionary) -> Array:
 # Legacy gate links enter the same explicit-action dispatcher as new links.
 var result: Array = bank.get("actions", []).duplicate(true)
 for id: String in bank.gates: result.append({"object_id": id, "action": "open"})
 return result
