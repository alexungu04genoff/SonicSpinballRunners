extends SceneTree
const Registry = preload("res://scripts/themes/theme_registry.gd")
const Assets = preload("res://scripts/endless/bake_assets.gd")
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func _initialize() -> void:
 var assets := Assets.new()
 DirAccess.make_dir_recursive_absolute("res://test-results")
 for id: String in Registry.IDS:
  var theme := Registry.create(id)
  check(theme.theme_id == id, id + " resolves its own definition")
  for role: String in ["floor_material", "top_material", "side_material", "cliff_material", "floor_border_material", "top_border_material"]:
   var source: ShaderMaterial = theme.get(role)
   check(source != null and source.has_meta("atmosphere_hue"), id + " has prepared " + role)
   if source == null: continue
   var code := source.shader.code
   var shader := source.shader
   var baked: ShaderMaterial = assets.share(source)
   check(baked != source and baked.shader.code == code and source.shader == shader, id + " preserves source shader during baking")
   for uniform: Dictionary in shader.get_shader_uniform_list():
    var original: Variant = source.get_shader_parameter(uniform.name)
    var result: Variant = baked.get_shader_parameter(uniform.name)
    check(original == result, id + " preserves " + str(uniform.name))
   var path := "res://test-results/theme-material.res"
   check(ResourceSaver.save(baked, path) == OK, id + " saves")
   var loaded: ShaderMaterial = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
   check(loaded != null and loaded.shader.code == code, id + " disk shader matches live source")
 var standard := StandardMaterial3D.new()
 standard.normal_enabled = true
 standard.heightmap_enabled = true
 var baked: StandardMaterial3D = assets.share(standard)
 check(baked.normal_enabled and baked.heightmap_enabled, "Baking preserves explicitly authored relief")
 var p = preload("res://scripts/themes/themed_presentation.gd").new()
 check(p.theme_definition.floor_material.has_meta("atmosphere_hue"), "Default preview uses registry preparation")
 p.free()
 check(preload("res://scripts/themes/theme_textures.gd").errors == 0, "Every selected production texture loads")
 check(assets.error.is_empty(), "Bake resource sharing succeeds")
 print("THEME_RESOLUTION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
