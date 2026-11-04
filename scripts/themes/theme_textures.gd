extends RefCounted
## One imported production texture path in editor, captures, bakes and exports.
## Run the Godot import step after changing source artwork.
static var errors := 0

static func texture(path: String) -> Texture2D:
 var result := load(path) as Texture2D
 if result == null:
  errors += 1
  push_error("Missing production theme texture: " + path)
 return result
