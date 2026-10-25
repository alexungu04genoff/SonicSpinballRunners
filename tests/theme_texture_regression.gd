extends SceneTree
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Sets = preload("res://scripts/themes/terrain_texture_sets.gd")
const Presentation = preload("res://scripts/themes/themed_presentation.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func _initialize() -> void:
 var p := Presentation.new()
 var housing := PackedVector2Array([Vector2(0, 0), Vector2(35, 0), Vector2(25, 30), Vector2(0, 30)])
 var original := housing.duplicate()
 for id: String in Themes.IDS:
  var theme: RefCounted = Themes.create(id)
  p.set_theme_definition(theme)
  p.authored_mode = false
  var mesh: ArrayMesh = p._prism(housing, 0.18, theme.side_material, theme.top_material)
  check(mesh.get_surface_count() == 3 and mesh.surface_get_material(2) == theme.top_border_material, "Generated wall housing has its missing cap border: " + id)
  p.authored_mode = true
  mesh = p._prism(housing, 0.325, theme.side_material, theme.top_material)
  check(mesh.get_surface_count() == 2, "Authored walls avoid duplicate coplanar borders: " + id)
  check(housing == original, "Border leaves stored housing outline unchanged: " + id)
  if not Sets.SETS.has(id): continue
  var materials := [theme.floor_material, theme.top_material, theme.side_material, theme.cliff_material, theme.ramp_materials().deck, theme.floor_border_material, theme.top_border_material]
  for i in materials.size():
   var mat: ShaderMaterial = materials[i]
   for name: String in ["albedo", "emission", "surface"]:
    var texture: Texture2D = mat.get_shader_parameter(name + "_texture")
    check(texture != null and texture.get_width() > 0 and texture.get_height() > 0, "Imported texture exists: %s/%s/%s" % [id, i, name])
    if texture == null: continue
    var settings := ConfigFile.new()
    check(settings.load(texture.resource_path + ".import") == OK and settings.get_value("params", "mipmaps/generate", false) and settings.get_value("params", "compress/mode", -1) == 0, "Texture retains lossless mipmapped import: " + texture.resource_path)
   if i == 4: check(mat.get_shader_parameter("mapping") in [3, 4], "Ramp image follows route instead of world coordinates: " + id)
 p.free()
 print("RESULT | Theme texture coverage | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
