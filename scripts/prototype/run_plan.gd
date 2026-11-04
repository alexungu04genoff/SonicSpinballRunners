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

static func pool_error(documents: Array, single_act_test := false) -> String:
 if single_act_test:
  return "An Act test needs one Act with a Spawn." if documents.size() != 1 or documents[0].spawn_position == null else ""
 if documents.size() < ACTS_PER_ZONE: return "The prototype needs at least three selected Acts."
 return StreamPlan.pool_error(documents)

static func target(sequence: int) -> int:
 return 1000 + 500 * maxi(0, sequence)

static func build(documents: Array, seed_value: int, configuration: RefCounted = null) -> Array[Dictionary]:
 if configuration == null: configuration = Configuration.new(source_paths())
 if not pool_error(documents, configuration.single_act_test).is_empty(): return []
 if not configuration.validation_error().is_empty() or documents.size() != configuration.selected_act_paths.size(): return []
 if configuration.single_act_test:
  var theme: String = configuration.selected_theme_ids[0]
  var atmosphere := preload("res://scripts/atmosphere/variants.gd").new().choose(theme, seed_value, 0, configuration.atmosphere_overrides.get(theme, ""))
  if not configuration.atmosphere_preview.is_empty():
   atmosphere = {"id": "lab_preview", "name": configuration.atmosphere_preview.get("name", "Lab preview"), "enabled": true, "weight": 1.0, "values": configuration.atmosphere_preview.values.duplicate(true)}
  return [{"sequence": 0, "zone": 0, "act": 0, "id": 0, "theme": theme, "atmosphere": atmosphere, "offset": Vector2.ZERO}]
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
  var atmosphere := preload("res://scripts/atmosphere/variants.gd").new().choose(theme, seed_value, zone, configuration.atmosphere_overrides.get(theme, ""))
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
    "id": id, "theme": theme, "atmosphere": atmosphere.duplicate(true), "offset": offset})
   used_in_zone.append(id)
   uses[id] += 1
   previous_id = id
 return entries
