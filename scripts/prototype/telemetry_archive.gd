extends RefCounted
## Stores the session's exact clipboard JSON. No alternate telemetry serializer.
const DIRECTORY := "user://telemetry/runs"

static func save(json: String, data: Dictionary, directory := DIRECTORY) -> Dictionary:
 var error := DirAccess.make_dir_recursive_absolute(directory)
 if error != OK: return _failed("create telemetry folder", error)
 var timestamp := str(data.ended_at_local).replace("T", "_").replace(":", "-")
 var status := "win" if data.won else ("loss" if data.termination_reason == "out_of_balls" else str(data.termination_reason))
 var stem := "%s_seed-%d_%s_%s" % [timestamp, int(data.run_seed), data.mode, status]
 # Only generated metadata enters the name; allow no separators or special paths.
 stem = RegEx.create_from_string("[^A-Za-z0-9_-]").sub(stem, "_", true)
 var suffix := 0
 while true:
  var filename := stem + ("_%d" % suffix if suffix > 0 else "") + ".json"
  var path := directory.path_join(filename)
  var reservation := path + ".pending"
  suffix += 1
  if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path): continue
  # An exclusive directory reservation also separates simultaneous game processes.
  error = DirAccess.make_dir_absolute(reservation)
  if error == ERR_ALREADY_EXISTS: continue
  if error != OK: return _failed("reserve telemetry file", error)
  if FileAccess.file_exists(path):
   DirAccess.remove_absolute(reservation)
   continue
  var temporary := reservation.path_join("run.tmp")
  var file := FileAccess.open(temporary, FileAccess.WRITE)
  if file == null:
   error = FileAccess.get_open_error()
  else:
   file.store_string(json)
   file.flush()
   error = file.get_error()
   file.close()
   if error == OK and FileAccess.get_file_as_string(temporary) != json: error = ERR_FILE_CORRUPT
  if error == OK:
   if FileAccess.file_exists(path): error = ERR_ALREADY_EXISTS
   else: error = DirAccess.rename_absolute(temporary, path)
  if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
  DirAccess.remove_absolute(reservation)
  if error == ERR_ALREADY_EXISTS: continue
  if error != OK: return _failed("write telemetry file", error)
  return {"path": path, "error": ""}
 return _failed("reserve telemetry file", ERR_CANT_CREATE)

static func _failed(operation: String, error: Error) -> Dictionary:
 return {"path": "", "error": "Could not %s: %s. Copy run data is still available." % [operation, error_string(error)]}

static func update_notes(path: String, previous_json: String, json: String) -> Dictionary:
 # Only update the file this session created, never another run or an external edit.
 var reservation := path + ".pending"
 var error := DirAccess.make_dir_absolute(reservation)
 if error != OK: return _failed("update run notes", error)
 var temporary := reservation.path_join("notes.tmp")
 if not FileAccess.file_exists(path) or FileAccess.get_file_as_string(path) != previous_json:
  DirAccess.remove_absolute(reservation)
  return {"path": "", "error": "Run notes were not saved because the archive changed outside the game. Copy run data is still available."}
 else:
  var file := FileAccess.open(temporary, FileAccess.WRITE)
  if file == null: error = FileAccess.get_open_error()
  else:
   file.store_string(json)
   file.flush()
   error = file.get_error()
   file.close()
   if error == OK and FileAccess.get_file_as_string(temporary) != json: error = ERR_FILE_CORRUPT
  # Same-volume replacement leaves the previous JSON intact if replacement fails.
  if error == OK: error = DirAccess.rename_absolute(temporary, path)
 if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
 DirAccess.remove_absolute(reservation)
 return {"path": path, "error": ""} if error == OK else _failed("update run notes", error)
