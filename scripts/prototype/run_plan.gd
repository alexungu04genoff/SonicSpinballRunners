extends RefCounted
## The finite prototype uses the editable authored folder without rewriting its Acts.
const SOURCE_DIRECTORY := "res://data/acts/Authored"
const THEMES := ["green_hill", "chemical_plant"]
const ACTS_PER_ZONE := 3
const ZONE_COUNT := 2
const ACT_COUNT := ACTS_PER_ZONE * ZONE_COUNT
const TARGETS := [1000, 1500, 2000, 2500, 3000, 3500]
const StreamPlan = preload("res://scripts/endless/endless_plan.gd")

static func source_paths() -> Array:
 var paths: Array = []
 for file: String in DirAccess.get_files_at(SOURCE_DIRECTORY):
  if file.get_extension() == "tres": paths.append(SOURCE_DIRECTORY.path_join(file))
 paths.sort()
 return paths

static func pool_error(documents: Array) -> String:
 if documents.size() < ACTS_PER_ZONE:
  return "The two-Zone prototype needs at least three Acts in data/acts/Authored."
 return StreamPlan.pool_error(documents)

static func build(documents: Array, seed_value: int) -> Array[Dictionary]:
 if not pool_error(documents).is_empty(): return []
 var shuffler := StreamPlan.new(seed_value)
 var order := shuffler.shuffled(range(documents.size()))
 while order.size() < ACT_COUNT:
  var next_order := shuffler.shuffled(range(documents.size()))
  if next_order[0] == order.back():
   var swap: Variant = next_order[0]
   next_order[0] = next_order[1]
   next_order[1] = swap
  order.append_array(next_order)
 var entries: Array[Dictionary] = []
 var offset := Vector2.ZERO
 for sequence in ACT_COUNT:
  var id: int = order[sequence]
  if sequence > 0:
   offset = StreamPlan.aligned_offset(documents[order[sequence - 1]], offset, documents[id])
  entries.append({"sequence": sequence, "zone": sequence / ACTS_PER_ZONE,
   "act": sequence % ACTS_PER_ZONE, "id": id, "theme": THEMES[sequence / ACTS_PER_ZONE], "offset": offset})
 return entries
