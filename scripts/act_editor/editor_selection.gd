extends RefCounted
## Authoring-only groups and locks. Indices are remapped when collections change.
const COLLECTIONS := {"terrain": "placements", "gameplay": "gameplay_objects", "decor": "decor_slots", "ring": "ring_trails"}
const KINDS := ["terrain", "gameplay", "decor", "ring", "markers"]

static func empty() -> Dictionary:
 return {"terrain": [], "gameplay": [], "decor": [], "ring": [], "markers": []}

static func count(selection: Dictionary) -> int:
 var total := 0
 for kind: String in KINDS: total += selection.get(kind, []).size()
 return total

static func fingerprint_records(document: Resource) -> Array:
 var groups: Array = []
 for item: Dictionary in document.editor_groups: groups.append([item.name, _ordered_selection(item.members)])
 return [groups, _ordered_selection(document.editor_locks), _ordered_selection(document.editor_hidden)]

static func _ordered_selection(selection: Dictionary) -> Array:
 var result: Array = []
 for kind: String in KINDS:
  var indices: Array = selection.get(kind, []).duplicate()
  indices.sort()
  result.append(indices)
 return result

static func single(kind: String, index: Variant) -> Dictionary:
 var result := empty()
 result[kind].append(index)
 return result

static func merge(into: Dictionary, other: Dictionary) -> void:
 for kind: String in KINDS:
  if not into.has(kind): into[kind] = []
  for index: Variant in other.get(kind, []):
   if not into[kind].has(index): into[kind].append(index)

static func intersects(a: Dictionary, b: Dictionary) -> bool:
 for kind: String in KINDS:
  for index: Variant in a.get(kind, []):
   if b.get(kind, []).has(index): return true
 return false

static func locked(document: Resource, kind: String, index: Variant) -> bool:
 return document.editor_locks.get(kind, []).has(index)

static func hidden(document: Resource, kind: String, index: Variant) -> bool:
 return document.editor_hidden.get(kind, []).has(index)

static func expanded(document: Resource, selection: Dictionary, unlocked_only := true) -> Dictionary:
 var result := empty()
 merge(result, selection)
 for group: Dictionary in document.editor_groups:
  if intersects(result, group.members): merge(result, group.members)
 if unlocked_only:
  # A partly locked/hidden group cannot be moved as an incomplete assembly.
  for item: Dictionary in document.editor_groups:
   if not intersects(result, item.members): continue
   if intersects(item.members, document.editor_locks) or intersects(item.members, document.editor_hidden):
    for kind: String in KINDS:
     for index: Variant in item.members.get(kind, []): result[kind].erase(index)
  for kind: String in KINDS:
   result[kind] = result[kind].filter(func(index): return not locked(document, kind, index) and not hidden(document, kind, index))
 return result

static func group(document: Resource, selection: Dictionary) -> void:
 var members := expanded(document, selection)
 members.markers = []
 if count(members) < 2: return
 ungroup(document, members)
 document.editor_groups.append({"name": "Group %d" % (document.editor_groups.size() + 1), "members": members})

static func ungroup(document: Resource, selection: Dictionary) -> void:
 document.editor_groups = document.editor_groups.filter(func(item): return not intersects(item.members, selection))

static func remap(document: Resource, kind: String, mapping: Dictionary) -> void:
 # Missing keys are removed. Many-to-one mappings preserve membership after Merge.
 for selection: Dictionary in [document.editor_locks, document.editor_hidden] + document.editor_groups.map(func(item): return item.members):
  var indices: Array = []
  for old: Variant in selection.get(kind, []):
   if not mapping.has(old): continue
   var replacements: Array = mapping[old] if mapping[old] is Array else [mapping[old]]
   for replacement: int in replacements:
    if not indices.has(replacement): indices.append(replacement)
  selection[kind] = indices
 document.editor_groups = document.editor_groups.filter(func(item): return count(item.members) >= 2)

static func remove_indices(document: Resource, kind: String, removed: Array) -> void:
 var mapping := {}
 var next := 0
 for index in document.get(COLLECTIONS[kind]).size():
  if removed.has(index): continue
  mapping[index] = next
  next += 1
 remap(document, kind, mapping)

static func units(document: Resource, selection: Dictionary) -> Array[Dictionary]:
 # Alignment treats each saved group as one unit, preserving its internal layout.
 var result: Array[Dictionary] = []
 var covered := empty()
 for item: Dictionary in document.editor_groups:
  if intersects(item.members, selection):
   var members := expanded(document, item.members)
   if count(members) > 0:
    result.append(members)
    merge(covered, members)
 for kind: String in COLLECTIONS:
  for index: int in selection.get(kind, []):
   if not covered[kind].has(index): result.append(single(kind, index))
 return result

static func validation_error(document: Resource) -> String:
 if not document.editor_groups is Array or not document.editor_locks is Dictionary or not document.editor_hidden is Dictionary: return "Editor groups, visibility and locks have invalid container types."
 var occupied := empty()
 for item: Variant in document.editor_groups:
  if not item is Dictionary or not item.get("name") is String or not item.get("members") is Dictionary: return "Editor group needs a name and member selection."
  var error := _selection_error(document, item.members)
  if not error.is_empty(): return error
  if count(item.members) < 2 or not item.members.get("markers", []).is_empty(): return "Groups need at least two objects; lifecycle markers stay independent."
  if intersects(occupied, item.members): return "An object cannot belong to more than one group."
  merge(occupied, item.members)
 var error := _selection_error(document, document.editor_locks)
 return error if not error.is_empty() else _selection_error(document, document.editor_hidden)

static func _selection_error(document: Resource, selection: Dictionary) -> String:
 for kind: Variant in selection:
  if kind not in KINDS or not selection[kind] is Array: return "Invalid editor selection category."
  var seen: Array = []
  for index: Variant in selection[kind]:
   if seen.has(index): return "Duplicate editor selection member."
   seen.append(index)
   if kind == "markers":
    if index not in ["spawn", "goal", "activation"]: return "Unknown locked lifecycle marker."
   elif not index is int or index < 0 or not document.get(COLLECTIONS[kind]) is Array or index >= document.get(COLLECTIONS[kind]).size():
    return "Editor member references a missing object."
 return ""
