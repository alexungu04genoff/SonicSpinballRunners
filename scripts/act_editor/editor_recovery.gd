extends RefCounted
## Recovery copies never overwrite an authored Act. Named checkpoints are retained.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const DIRECTORY := "user://act_editor_recovery"

static func save_copy(document: Resource, source: String, session_id: String, label: String, automatic: bool) -> Dictionary:
 var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
 if error != OK: return {"error": error_string(error)}
 var key := source.replace("\\", "/").to_lower() if not source.is_empty() else session_id
 var stem := "auto_" + key.sha256_text().left(24) if automatic else "checkpoint_" + Objects.new_id()
 var path := DIRECTORY.path_join(stem + ".tres")
 error = document.save_document(path)
 if error != OK: return {"error": "Recovery copy could not be saved: " + error_string(error)}
 var metadata := ConfigFile.new()
 metadata.set_value("snapshot", "source", source)
 metadata.set_value("snapshot", "label", "Autosave" if automatic else label.strip_edges().left(80))
 metadata.set_value("snapshot", "time", Time.get_unix_time_from_system())
 # Metadata is optional. Even if its write fails, the validated Act is recoverable.
 metadata.save(path.get_basename() + ".cfg")
 return {"error": "", "path": path}

static func entries() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 var directory := DirAccess.open(DIRECTORY)
 if directory == null: return result
 for filename: String in directory.get_files():
  if filename.get_extension() != "tres" or ".staging-" in filename: continue
  var path := DIRECTORY.path_join(filename)
  var metadata := ConfigFile.new()
  # An interrupted atomic save can leave the prior valid copy under a backup name.
  var backup := ".backup-" in filename
  metadata.load(path.get_basename().get_slice(".backup-", 0) + ".cfg")
  var stamp := float(metadata.get_value("snapshot", "time", FileAccess.get_modified_time(path)))
  result.append({"path": path, "label": "Interrupted save backup" if backup else str(metadata.get_value("snapshot", "label", filename.get_basename())),
   "source": str(metadata.get_value("snapshot", "source", "")), "time": stamp})
 result.sort_custom(func(a, b): return a.time > b.time)
 return result
