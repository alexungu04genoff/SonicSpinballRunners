extends RefCounted
## Writable authoring data shared by the two standalone tools, never the source project.

static func enabled() -> bool:
 return bool(ProjectSettings.get_setting("portable_tools/enabled", false))

static func root_directory() -> String:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--workspace="):
   return argument.trim_prefix("--workspace=").simplify_path()
 return OS.get_executable_path().get_base_dir()

static func atmosphere_directory() -> String:
 return root_directory().path_join("Atmospheres") if enabled() else "res://data/atmospheres"

static func act_directory() -> String:
 return root_directory().path_join("Acts")

static func external_act_path(path: String) -> String:
 if enabled() and path.begins_with("res://data/acts/"):
  return act_directory().path_join(path.trim_prefix("res://data/acts/"))
 return path

static func prepare() -> Error:
 if not enabled(): return OK
 var result := _copy_missing("res://data/acts", act_directory())
 if result != OK: return result
 return _copy_missing("res://data/atmospheres", atmosphere_directory())

static func _copy_missing(source: String, destination: String) -> Error:
 var result := DirAccess.make_dir_recursive_absolute(destination)
 if result != OK: return result
 for file: String in DirAccess.get_files_at(source):
  if file.get_extension() not in ["tres", "cfg"]: continue
  var target := destination.path_join(file)
  if FileAccess.file_exists(target): continue
  result = DirAccess.copy_absolute(source.path_join(file), target)
  if result != OK: return result
 for folder: String in DirAccess.get_directories_at(source):
  if folder.ends_with(".bake") or folder.begins_with("."): continue
  result = _copy_missing(source.path_join(folder), destination.path_join(folder))
  if result != OK: return result
 return OK
