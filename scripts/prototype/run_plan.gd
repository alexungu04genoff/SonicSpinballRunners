extends RefCounted
## The finite prototype uses the editable authored folder without rewriting its Acts.
const SOURCE_DIRECTORY := "res://data/acts/Authored"
const Configuration = preload("res://scripts/prototype/run_configuration.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const ACTS_PER_ZONE := Configuration.ACTS_PER_ZONE
# Default aliases retained for existing six-Act development probes.
const THEMES := ["green_hill", "chemical_plant"]
const ACT_COUNT := 6
const StreamPlan = preload("res://scripts/endless/endless_plan.gd")

static func source_paths(directory := SOURCE_DIRECTORY) -> Array:
 var paths: Array = []
 for file: String in DirAccess.get_files_at(directory):
  if file.get_extension() == "tres":
   var path := directory.path_join(file)
   if Document.load_document(path).document != null: paths.append(path)
 paths.sort()
 return paths

static func pool_error(documents: Array) -> String:
 if documents.size() < ACTS_PER_ZONE: return "The prototype needs at least three selected Acts."
 return StreamPlan.pool_error(documents)

static func target(sequence: int) -> int:
 return 1000 + 500 * maxi(0, sequence)

static func build(documents: Array, seed_value: int, configuration: RefCounted = null) -> Array[Dictionary]:
 if not pool_error(documents).is_empty(): return []
 if configuration == null: configuration = Configuration.new(source_paths())
 if not configuration.validation_error().is_empty() or documents.size() != configuration.selected_act_paths.size(): return []
 var shuffler := StreamPlan.new(seed_value)
 var theme_shuffler := StreamPlan.new(seed_value)
 var themes: Array = configuration.snapshot().selected_themes
 var theme_bag: Array = []
 var previous_theme := ""
 # IDs still index the caller's documents. Sort identities before any RNG use.
 var ids: Array = range(documents.size())
 ids.sort_custom(func(a: int, b: int): return configuration.selected_act_paths[a] < configuration.selected_act_paths[b])
 var uses := {}
 for id: int in ids: uses[id] = 0
 var entries: Array[Dictionary] = []
 var offset := Vector2.ZERO
 var previous_id := -1
 for zone in configuration.zone_count:
  if theme_bag.is_empty():
   theme_bag = theme_shuffler.shuffled(themes)
   if theme_bag.size() > 1 and theme_bag[0] == previous_theme:
    var swap: Variant = theme_bag[0]
    theme_bag[0] = theme_bag[1]
    theme_bag[1] = swap
  var theme: String = theme_bag.pop_front()
  previous_theme = theme
  var used_in_zone: Array = []
  for act in ACTS_PER_ZONE:
   # Least-used eligible sources first; seeded ties avoid excessive reuse.
   var candidates: Array = []
   var least := 2147483647
   for id: int in ids:
    if id in used_in_zone or id == previous_id: continue
    if uses[id] < least:
     least = uses[id]
     candidates.clear()
    if uses[id] == least: candidates.append(id)
   var id: int = shuffler.shuffled(candidates)[0]
   if previous_id >= 0: offset = StreamPlan.aligned_offset(documents[previous_id], offset, documents[id])
   entries.append({"sequence": entries.size(), "zone": zone, "act": act,
    "id": id, "theme": theme, "offset": offset})
   used_in_zone.append(id)
   uses[id] += 1
   previous_id = id
 return entries
