@tool
extends EditorPlugin
## Enabled only inside the export snapshot, never in the user's editor project.
var exporter: EditorExportPlugin

class SourceAssets extends EditorExportPlugin:
 func _get_name() -> String:
  return "PrototypeSourceAssets"

 func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
  # Godot exports imported textures, but bake validation hashes original PNGs.
  # Keep both representations so the packaged pipeline verifies identically.
  if path.begins_with("res://assets/") and path.ends_with(".png"):
   add_file(path, FileAccess.get_file_as_bytes(path), false)

func _enter_tree() -> void:
 exporter = SourceAssets.new()
 add_export_plugin(exporter)

func _exit_tree() -> void:
 remove_export_plugin(exporter)
