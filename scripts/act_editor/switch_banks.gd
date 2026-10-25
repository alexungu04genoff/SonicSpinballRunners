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
  if not bank is Dictionary or not bank.has_all(["bank_id", "label", "members", "gates"]) or bank.size() != 4:
   errors.append("Each switch bank needs bank_id, label, members and gates.")
   continue
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
    var expected := "switch_target" if key == "members" else "one_way_gate"
    if typeof(id) != TYPE_STRING or types.get(id) != expected or seen.has(id):
     errors.append("Switch bank %s contains a missing, wrong-type or duplicate object ID." % key)
    else: seen[id] = true
 return errors

static func fingerprint_records(banks: Variant) -> Array:
 if not banks is Array: return [banks]
 var result: Array = []
 for bank: Variant in banks:
  result.append([bank.get("bank_id"), bank.get("label"), bank.get("members"), bank.get("gates")] if bank is Dictionary else bank)
 return result

static func remove_objects(banks: Array, ids: Array) -> void:
 for i in range(banks.size() - 1, -1, -1):
  for id: String in ids:
   banks[i].members.erase(id)
   banks[i].gates.erase(id)
  if banks[i].members.is_empty(): banks.remove_at(i)
