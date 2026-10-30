extends SceneTree
const RunPlan = preload("res://scripts/prototype/run_plan.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func _initialize() -> void:
 var paths := RunPlan.source_paths()
 var documents: Array = []
 var fingerprints: Array = []
 for path: String in paths:
  var loaded := Document.load_document(path)
  documents.append(loaded.document)
  fingerprints.append(loaded.document.fingerprint())
 check(paths.size() >= 3 and RunPlan.pool_error(documents).is_empty(), "Production pool discovers valid compatible sources")
 var configuration := RunPlan.Configuration.new(paths)
 var defaults := RunPlan.build(documents, 18, configuration)
 check(defaults.size() == 6 and defaults == RunPlan.build(documents, 18, configuration), "Default two-Zone run is reproducible")
 var targets: Array = []
 for i in 6: targets.append(RunPlan.target(i))
 check(targets == [1000, 1500, 2000, 2500, 3000, 3500] and RunPlan.target(20) == 11000, "Targets extend the unchanged progression through Act 21")
 for count in [1, 2, 7]:
  for pool_size in range(3, paths.size() + 1):
   for themes: Array in [["ice_cap"], ["green_hill", "chemical_plant"], RunPlan.Configuration.Registry.IDS.duplicate()]:
    configuration = RunPlan.Configuration.new(paths.slice(0, pool_size))
    configuration.zone_count = count
    configuration.selected_theme_ids = themes
    var valid := true
    for seed_value in 30:
     var selected_docs := documents.slice(0, pool_size)
     var entries := RunPlan.build(selected_docs, seed_value, configuration)
     valid = valid and entries.size() == count * 3 and entries == RunPlan.build(selected_docs, seed_value, configuration)
     var used := {}
     var theme_cycle: Array = []
     var counts := {}
     for i in entries.size():
      var entry: Dictionary = entries[i]
      if i % 3 == 0:
       used.clear()
       if theme_cycle.size() == themes.size(): theme_cycle.clear()
       valid = valid and entry.theme not in theme_cycle
       theme_cycle.append(entry.theme)
       if i > 0 and themes.size() > 1: valid = valid and entry.theme != entries[i - 1].theme
      valid = valid and not used.has(entry.id) and entry.theme in themes and entry.zone == i / 3 and entry.act == i % 3
      used[entry.id] = true
      counts[entry.id] = counts.get(entry.id, 0) + 1
      if i > 0:
       valid = valid and entry.id != entries[i - 1].id
       valid = valid and entry.offset == RunPlan.StreamPlan.aligned_offset(selected_docs[entries[i - 1].id], entries[i - 1].offset, selected_docs[entry.id])
     valid = valid and counts.values().max() - counts.values().min() <= 2
    check(valid, "%d Zones, %d Acts, %d themes: 30 seeded courses preserve uniqueness, coverage, balance and connectors" % [count, pool_size, themes.size()])
 configuration = RunPlan.Configuration.new(paths)
 var reversed_docs := documents.duplicate()
 reversed_docs.reverse()
 var forward := RunPlan.build(documents, 18, configuration)
 configuration.selected_act_paths.reverse()
 configuration.selected_theme_ids.reverse()
 var backward := RunPlan.build(reversed_docs, 18, configuration)
 var stable := true
 for i in forward.size(): stable = stable and paths[forward[i].id] == configuration.selected_act_paths[backward[i].id] and forward[i].theme == backward[i].theme
 check(stable, "Input order does not change source or theme sequence")
 configuration = RunPlan.Configuration.new(paths)
 configuration.zone_count = 7
 var larger := RunPlan.build(documents, 18, configuration)
 configuration.selected_act_paths = paths.slice(0, 3)
 var smaller := RunPlan.build(documents.slice(0, 3), 18, configuration)
 var same_themes := true
 for i in larger.size(): same_themes = same_themes and larger[i].theme == smaller[i].theme
 check(same_themes, "Theme sequence depends on seed and themes independently of the Act pool")
 var unchanged := true
 for i in documents.size(): unchanged = unchanged and documents[i].fingerprint() == fingerprints[i]
 check(unchanged, "Planning preserves authored fingerprints")
 configuration.selected_theme_ids = []
 check(not configuration.validation_error().is_empty() and RunPlan.build(documents, 18, configuration).is_empty(), "No themes is invalid")
 for size in 3:
  configuration = RunPlan.Configuration.new(paths.slice(0, size))
  check(not configuration.validation_error().is_empty(), "%d selected Acts is invalid" % size)
 configuration = RunPlan.Configuration.new(paths)
 configuration.zone_count = 7
 configuration.selected_theme_ids = ["lava_reef"]
 configuration.selected_act_paths.erase(paths[0])
 var settings := ConfigFile.new()
 configuration.write_preferences(settings, paths)
 settings.save("user://run-configuration-regression.cfg")
 var loaded := ConfigFile.new()
 loaded.load("user://run-configuration-regression.cfg")
 var restored := RunPlan.Configuration.new()
 restored.read_preferences(loaded, paths)
 check(restored.snapshot() == configuration.snapshot() and restored.fingerprint() == configuration.fingerprint(), "Preferences survive disk reload")
 var available := paths.slice(1)
 available.append("res://data/acts/Authored/New Act.tres")
 available.sort()
 restored.read_preferences(loaded, available)
 check(restored.selected_act_paths == available, "Missing Act ignored and newly discovered Act selected")
 configuration.selected_theme_ids = []
 configuration.selected_act_paths = []
 configuration.write_preferences(settings, paths)
 restored.read_preferences(settings, paths)
 check(restored.selected_theme_ids.is_empty() and restored.selected_act_paths.is_empty(), "Explicit Select none persists without defaults returning")
 var directory := "user://run-discovery-regression"
 DirAccess.make_dir_recursive_absolute(directory)
 var fixture := directory.path_join("New Act.tres")
 ResourceSaver.save(documents[0], fixture)
 check(RunPlan.source_paths(directory) == [fixture], "A new valid authored resource is discovered without UI changes")
 DirAccess.remove_absolute(fixture)
 DirAccess.remove_absolute(directory)
 DirAccess.remove_absolute("user://run-configuration-regression.cfg")
 print("RESULT | Prototype plan | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
