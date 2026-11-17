extends RefCounted
## Native Act recipes keep exact transforms and switch links in a local library.
const Act = preload("res://scripts/act_editor/act_geometry.gd")
const Clipboard = preload("res://scripts/act_editor/selection_clipboard.gd")
const Selection = preload("res://scripts/act_editor/editor_selection.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const DIRECTORY := "user://act_editor_assemblies"

static func entries() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 var directory := DirAccess.open(DIRECTORY)
 if directory == null: return result
 for filename: String in directory.get_files():
  if filename.get_extension() != "tres": continue
  var path := DIRECTORY.path_join(filename)
  var loaded := Act.load_document(path)
  if loaded.document != null: result.append({"title": loaded.document.title, "path": path})
 result.sort_custom(func(a, b): return String(a.title).naturalnocasecmp_to(b.title) < 0)
 return result

static func save_selection(document: Resource, selection: Dictionary, title: String) -> Dictionary:
 title = title.strip_edges()
 if title.is_empty() or title.length() > 80: return {"error": "Use an assembly name of 1–80 characters."}
 var copied := Clipboard.capture(document, selection)
 if copied.is_empty(): return {"error": "Select objects to save as an assembly. Lifecycle markers are not reusable objects."}
 var recipe := Act.new()
 recipe.title = title
 recipe.cell_size = document.cell_size
 recipe.grid_size = document.grid_size
 var appended := Clipboard.append_to(recipe, copied, Vector2.ZERO)
 if not appended.error.is_empty(): return appended
 var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
 if error != OK: return {"error": "Could not create the assembly library: " + error_string(error)}
 var path := DIRECTORY.path_join(Objects.new_id() + ".tres")
 error = recipe.save_document(path)
 return {"error": "" if error == OK else error_string(error), "path": path}

static func load_copy(path: String, cell_size: float) -> Dictionary:
 var loaded := Act.load_document(path)
 if loaded.document == null: return {"error": loaded.error}
 var recipe: Resource = loaded.document
 var selection := Selection.empty()
 for kind: String in Selection.COLLECTIONS: selection[kind] = range(recipe.get(Selection.COLLECTIONS[kind]).size())
 var copied := Clipboard.for_cell_size(Clipboard.capture(recipe, selection), cell_size)
 if copied.is_empty(): return {"error": "This assembly contains no objects."}
 return {"error": "", "copied": copied, "title": recipe.title}
