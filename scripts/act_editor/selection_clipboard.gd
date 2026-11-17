extends RefCounted
## Session-local object clipboard. Source records and external links stay untouched.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Decor = preload("res://scripts/act_editor/decor_slots.gd")
const EditorSelectionData = preload("res://scripts/act_editor/editor_selection.gd")
const COLLECTIONS := {"terrain": "placements", "gameplay": "gameplay_objects", "decor": "decor_slots", "ring": "ring_trails"}

static func capture(document: Resource, selection: Dictionary) -> Dictionary:
 var copied := {"banks": [], "groups": [], "cell_size": float(document.cell_size)}
 var indices := {}
 var ids := {}
 var count := 0
 for kind: String in COLLECTIONS:
  copied[kind] = []
  indices[kind] = {}
  var records: Array = document.get(COLLECTIONS[kind])
  for index: int in selection.get(kind, []):
   var item: Dictionary = records[index].duplicate(true)
   if kind == "gameplay":
    item["object_id"] = Objects.identity(item, index)
    ids[item.object_id] = true
   indices[kind][index] = copied[kind].size()
   copied[kind].append(item)
   count += 1
 if count == 0: return {}
 for group: Dictionary in document.editor_groups:
  var members := EditorSelectionData.empty()
  var complete := true
  for kind: String in COLLECTIONS:
   for index: int in group.members.get(kind, []):
    if not indices[kind].has(index): complete = false
    else: members[kind].append(indices[kind][index])
  if complete: copied.groups.append({"name": group.name, "members": members})
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

static func append_to(document: Resource, copied: Dictionary, requested_offset: Vector2, clamp_to_bounds := true, validate_result := true) -> Dictionary:
 copied = for_cell_size(copied, float(document.cell_size))
 var adjusted := placement_offset(document, copied, requested_offset)
 if not adjusted.error.is_empty(): return adjusted
 if not clamp_to_bounds and Vector2(adjusted.offset) != requested_offset:
  return {"error": "The exact copy offset would move terrain outside the Act. Enlarge the grid first."}
 var cell := float(document.cell_size)
 var offset: Vector2 = adjusted.offset
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
 for original: Dictionary in copied.get("groups", []):
  var members := EditorSelectionData.empty()
  for kind: String in COLLECTIONS:
   for index: int in original.members.get(kind, []): members[kind].append(selection[kind][index])
  document.editor_groups.append({"name": original.name, "members": members})
 var errors: PackedStringArray = document.validation_errors() if validate_result else PackedStringArray()
 return {"selection": selection, "offset": offset, "error": "" if errors.is_empty() else errors[0]}

static func placement_offset(document: Resource, copied: Dictionary, requested_offset: Vector2) -> Dictionary:
 var lower := Vector2(-INF, -INF)
 var upper := Vector2(INF, INF)
 var cell := float(document.cell_size)
 for piece: Dictionary in copied.terrain:
  var position := Shapes.placement_position(piece)
  lower = lower.max(-position * cell)
  upper = upper.min((Vector2(document.grid_size) - position - Shapes.scaled_size(piece)) * cell)
 if lower.x > upper.x or lower.y > upper.y: return {"error": "The copied terrain does not fit in this Act."}
 return {"error": "", "offset": requested_offset.clamp(lower, upper)}

static func for_cell_size(copied: Dictionary, cell_size: float) -> Dictionary:
 var ratio := cell_size / float(copied.get("cell_size", cell_size))
 if is_equal_approx(ratio, 1.0): return copied
 var adapted := copied.duplicate(true)
 adapted.cell_size = cell_size
 for item: Dictionary in adapted.gameplay:
  item.position *= ratio
  # These four silhouettes already derive their dimensions from cell size.
  if item.type not in ["round_bumper", "triangle_bumper", "left_flipper", "right_flipper"]:
   item["properties"] = Objects.scaled_properties(item, ratio)
   if item.type == "elevated_rail": item.properties.ring_spacing *= ratio
 for slot: Dictionary in adapted.decor: slot.position *= ratio
 for trail: Dictionary in adapted.ring:
  trail.start *= ratio
  trail.end *= ratio
  trail.spacing *= ratio
 return adapted
