extends SceneTree
## Minimal packaged runtime proves registry reads do not need Lab user data.
func _initialize() -> void:
 var folder := "res://test-results/atmosphere-variants/export"
 DirAccess.make_dir_recursive_absolute(folder)
 FileAccess.open(folder.path_join("project.godot"), FileAccess.WRITE).store_string("config_version=5\n[application]\nconfig/name=\"Atmosphere export probe\"\n")
 var probe := "extends SceneTree\nfunc _initialize():\n var registry = preload(\"res://scripts/atmosphere/variants.gd\").new()\n for theme in registry.THEMES:\n  var records = registry.read(theme)\n  if not registry.error.is_empty() or records.is_empty():\n   push_error(registry.error)\n   quit(1)\n   return\n print(\"ATMOSPHERE_PACKAGED | eight Theme registries available\")\n quit()\n"
 FileAccess.open(folder.path_join("probe.gd"), FileAccess.WRITE).store_string(probe)
 var pack := PCKPacker.new()
 var path := folder.path_join("probe.pck")
 assert(pack.pck_start(path) == OK)
 assert(pack.add_file("res://project.godot", folder.path_join("project.godot")) == OK)
 assert(pack.add_file("res://probe.gd", folder.path_join("probe.gd")) == OK)
 for source: String in ["res://scripts/portable_workspace.gd", "res://scripts/atmosphere/variants.gd", "res://scripts/atmosphere/fields.gd", "res://scripts/themes/theme_atmosphere.gd"]:
  assert(pack.add_file(source, source) == OK)
 for theme: String in preload("res://scripts/atmosphere/variants.gd").THEMES:
  var source := "res://data/atmospheres/" + theme + ".cfg"
  assert(pack.add_file(source, source) == OK)
 assert(pack.flush() == OK)
 var output: Array = []
 var result := OS.execute(OS.get_executable_path(), ["--headless", "--main-pack", ProjectSettings.globalize_path(path), "--script", "res://probe.gd"], output, true)
 for line: String in output: print(line)
 quit(result)
