extends RefCounted
## Session-local object clipboard. Source records and external links stay untouched.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Decor = preload("res://scripts/act_editor/decor_slots.gd")
const COLLECTIONS := {"terrain": "placements", "gameplay": "gameplay_objects", "decor": "decor_slots", "ring": "ring_trails"}

static func capture(document: Resource, selection: Dictionary) -> Dictionary:
 var copied := {"banks": []}
 var ids := {}
 var count := 0
 for kind: String in COLLECTIONS:
  copied[kind] = []
  var records: Array = document.get(COLLECTIONS[kind])
  for index: int in selection.get(kind, []):
   var item: Dictionary = records[index].duplicate(true)
   if kind == "gameplay":
    item["object_id"] = Objects.identity(item, index)
    ids[item.object_id] = true
   copied[kind].append(item)
   count += 1
 if count == 0: return {}
 # Only complete copied objectives carry their membership. Targets outside the
 # copied selection are deliberately excluded, never wired to original objects.
 for bank: Dictionary in document.switch_banks:
  if not bank.members.all(func(id): return ids.has(id)): continue
  var clone := bank.duplicate(true)
  clone.gates = clone.gates.filter(func(id): return ids.has(id))
  if clone.has("actions"):
   clone.actions = clone.actions.filter(func(action): return ids.has(action.object_id))
  copied.banks.append(clone)
 copied["count"] = count
 return copied

static func append_to(document: Resource, copied: Dictionary, requested_offset: Vector2) -> Dictionary:
 # Clamp one shared offset, so terrain stays in bounds without distorting a group.
 var lower := Vector2(-INF, -INF)
 var upper := Vector2(INF, INF)
 var cell := float(document.cell_size)
 for piece: Dictionary in copied.terrain:
  var position := Shapes.placement_position(piece)
  lower = lower.max(-position * cell)
  upper = upper.min((Vector2(document.grid_size) - position - Shapes.scaled_size(piece)) * cell)
 if lower.x > upper.x or lower.y > upper.y: return {"error": "The copied terrain does not fit in this Act."}
 var offset := requested_offset.clamp(lower, upper)
 var selection := {"terrain": [], "gameplay": [], "decor": [], "ring": []}
 var ids := {}
 for kind: String in COLLECTIONS:
  var records: Array = document.get(COLLECTIONS[kind])
  for original: Dictionary in copied[kind]:
   var item := original.duplicate(true)
   match kind:
    "terrain": Shapes.set_placement_position(item, Shapes.placement_position(item) + offset / cell)
    "gameplay":
     item["object_id"] = Objects.new_id()
     ids[original.object_id] = item.object_id
     item.position += offset
    "decor":
     item.slot_id = Decor.new_id()
     item.position += offset
     item.erase("placement_source")
    "ring":
     item["pattern_id"] = "ring_" + Objects.new_id()
     item.start += offset
     item.end += offset
   selection[kind].append(records.size())
   records.append(item)
 for original: Dictionary in copied.banks:
  var bank := original.duplicate(true)
  bank.bank_id = "bank_" + Objects.new_id()
  bank.members = bank.members.map(func(id): return ids[id])
  bank.gates = bank.gates.map(func(id): return ids[id])
  for action: Dictionary in bank.get("actions", []): action.object_id = ids[action.object_id]
  document.switch_banks.append(bank)
 var errors: PackedStringArray = document.validation_errors()
 return {"selection": selection, "error": "" if errors.is_empty() else errors[0]}
