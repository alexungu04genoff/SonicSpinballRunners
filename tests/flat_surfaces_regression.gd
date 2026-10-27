extends SceneTree
const Assets = preload("res://scripts/endless/bake_assets.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func _initialize() -> void:
 DirAccess.make_dir_recursive_absolute("res://test-results")
 var assets := Assets.new()
 # The optional artwork include may not exist in a clean source checkout.
 # Supply an in-memory fixture without writing or replacing any art file.
 var include_fixture: ShaderInclude
 var include_path := "res://scripts/themes/rooftop_normal.gdshaderinc"
 if not ResourceLoader.exists(include_path):
  include_fixture = ShaderInclude.new()
  include_fixture.code = "uniform sampler2D relief_normal : hint_normal; uniform float relief_strength=1.0; vec3 relief(vec3 position, vec3 geometric, vec2 coordinates, vec2 sample_uv) { return normalize(geometric + texture(relief_normal,sample_uv).xyz * relief_strength); }"
  include_fixture.take_over_path(include_path)
 var source := ShaderMaterial.new()
 source.shader = Shader.new()
 source.shader.code = 'shader_type spatial;\n' + assets.FlatSurfaces.RELIEF_INCLUDE + '\nuniform vec4 tint : source_color;\nvoid fragment() { ALBEDO=tint.rgb; NORMAL=relief(VERTEX,NORMAL,UV,UV); }'
 source.set_shader_parameter("tint", Color(0.2, 0.4, 0.6))
 source.set_shader_parameter("relief_normal", ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8)))
 var flat: ShaderMaterial = assets.share(source)
 check(flat != source and flat.shader != source.shader, "Baking clones materials and shaders without altering editor resources")
 check(source.shader.code.contains(assets.FlatSurfaces.RELIEF_INCLUDE), "Source shader retains its relief")
 check(not flat.shader.code.contains("rooftop_normal") and not flat.shader.code.contains("textureGrad"), "Flat bake omits derivative normal sampling")
 check(flat.get_shader_parameter("tint") == source.get_shader_parameter("tint"), "Color uniforms survive conversion")
 check(flat.get_shader_parameter("relief_normal") == null, "The baked material releases its normal texture")
 check(assets.share(source) == flat, "Repeated bindings share the same converted material")
 check(assets.materials.has(flat.get_instance_id()) and not assets.materials.has(source.get_instance_id()), "Warm-up collects only converted materials")
 var second: ShaderMaterial = source.duplicate()
 check(assets.share(second).shader == flat.shader, "Equivalent flat shaders share one resource")
 var file := "res://test-results/flat-material.res"
 check(ResourceSaver.save(flat, file) == OK, "Flat material saves to disk")
 var loaded: ShaderMaterial = ResourceLoader.load(file, "", ResourceLoader.CACHE_MODE_IGNORE)
 check(loaded.shader.code == flat.shader.code and loaded.get_shader_parameter("tint") == Color(0.2, 0.4, 0.6), "Disk round trip preserves shader and color")
 var standard := StandardMaterial3D.new()
 standard.normal_enabled = true
 standard.heightmap_enabled = true
 var simple: BaseMaterial3D = assets.share(standard)
 check(not simple.normal_enabled and not simple.heightmap_enabled and standard.normal_enabled, "Standard relief is disabled without changing its source")
 var water := ShaderMaterial.new()
 water.shader = Shader.new()
 water.shader.code = "shader_type spatial; void fragment() { NORMAL=normalize(NORMAL+vec3(sin(TIME)*0.1,0,0)); }"
 check(assets.share(water) == water, "Unrelated animated normal shaders remain untouched")
 var turf_path := "res://scripts/themes/green_hill_turf.gdshader"
 if ResourceLoader.exists(turf_path):
  var turf := ShaderMaterial.new()
  turf.shader = load(turf_path)
  var ground: ShaderMaterial = assets.share(turf)
  check(not ground.shader.code.contains("NORMAL=normalize(NORMAL-gradient)") and ground.shader.code.contains("ALBEDO=texture(surface_texture"), "Grass keeps its texture and drops procedural bump calculations")
 check(assets.error.is_empty(), "Conversion completes without errors")
 print("FLAT_SURFACES_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
