extends SceneTree
## Explicit shader-to-image authoring tool. Never runs during ordinary gameplay.
const Sets = preload("res://scripts/themes/terrain_texture_sets.gd")
var viewport: SubViewport
var swatch: ColorRect
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func replace_regex(code: String, pattern: String, replacement: String) -> String:
 var regex := RegEx.new()
 regex.compile(pattern)
 return regex.sub(code, replacement, true)

func source(theme: String, surface: String) -> Dictionary:
 var config: Dictionary = Sets.SETS[theme]
 var prefix: String = config.source
 var vertical := surface in ["wall", "facade"]
 var name := prefix + ("_wall" if vertical else "_floor")
 var parameters := {"raised_surface": surface == "top", "top_height": 0.0 if surface == "facade" else 0.325}
 var repeat_size: Vector2 = Vector2(config.wall, Sets.DEPTH) if vertical else config.floor
 if surface == "ramp":
  repeat_size = config.ramp
  if theme == "chemical_plant": name = "chemical_ramp_panels"
  elif theme == "casino_night": name = "casino_ramp_cards"
  elif theme == "sky_sanctuary":
   name = "ramp_deck"
   parameters.merge({"surface_kind": 2, "base_color": Color("40646f"), "alternate_color": Color("829d9e")})
  else: parameters.raised_surface = theme != "ice_cap"
 var code := FileAccess.get_file_as_string("res://scripts/themes/" + name + ".gdshader")
 # Make the initial recipes tileable while retaining their existing visual motifs.
 # Runtime reads the images; these adjustments are not extra procedural shading.
 if prefix == "lava":
  var rock := FileAccess.get_file_as_string("res://scripts/themes/lava_rock.gdshaderinc")
  rock = rock.replace("sin(dot(p,", "sin(dot(mod(p, vec2(8.0)),")
  code = code.replace('#include "res://scripts/themes/lava_rock.gdshaderinc"', rock)
 if prefix == "sanctuary":
  code = code.replace("vec2 cell = floor(p);", "vec2 cell = mod(floor(p), vec2(14.0));")
  code = code.replace("vec2(2.8, 4.8)", "vec2(4.117647059, 4.8)")
  code = code.replace("p.x * 150.0", "p.x * 44.351896286")
  code = code.replace("p.x * 3.1", "p.x * 2.941176471")
 if prefix == "ice":
  code = code.replace("p.x * 1.8 +", "p.x * 1.570796327 +").replace("p.y * 1.1", "p.y * 0.785398163")
  code = code.replace("p.y * 2.2 - p.x * 0.65", "p.y * 2.35619449 - p.x * 0.785398163")
  code = code.replace("p.y * 5.0", "p.y * 4.71238898").replace("p.x * 2.0", "p.x * 2.35619449")
  code = code.replace("p.x * 2.8 + p.y * 1.9", "p.x * 3.141592654 + p.y * 1.570796327").replace("p.y * 2.5", "p.y * 2.35619449")
  code = code.replace("p.x * 1.85", "p.x * 2.0").replace("floor(column) * 0.27", "floor(column) * 0.25")
  code = code.replace("p.x * 8.0", "p.x * 7.853981634").replace("p.x * 19.0", "p.x * 18.84955592")
 if prefix == "aquarium":
  code = code.replace("p.x*2.0", "p.x*2.408554368").replace("p.y*1.4", "p.y*1.675516082")
 var specular := 0.0 if code.contains("specular_disabled") else 0.5
 code = code.replace("shader_type spatial;", "shader_type canvas_item;\nrender_mode unshaded;")
 code = replace_regex(code, "render_mode cull_disabled[^;]*;", "")
 code = replace_regex(code, "varying vec3 [a-z_]+;", "")
 code = replace_regex(code, "(?s)void vertex\\(\\)\\s*\\{.*?\\}", "")
 code = code.replace("dot(NORMAL, VIEW)", "1.0")
 for output: String in ["ALBEDO", "EMISSION", "ROUGHNESS", "SPECULAR", "METALLIC"]:
  code = code.replace(output, "bake_" + output.to_lower())
 code = code.replace("UV2", "bake_uv2").replace("UV;", "bake_uv;").replace("UV.y", "bake_uv.y")
 var locals := "vec3 bake_albedo = vec3(0.0), bake_emission = vec3(0.0); float bake_roughness = 1.0, bake_specular = %f, bake_metallic = 0.0;\n" % specular
 locals += "vec2 bake_uv = UV * vec2(%f, %f); vec2 bake_uv2 = vec2(UV.x, bake_uv.y);\n" % [repeat_size.x, repeat_size.y]
 locals += "vec3 world_position = vec3(bake_uv.x, %f - bake_uv.y, bake_uv.y); vec3 world_normal = vec3(0.0, 0.0, 1.0);\n" % parameters.top_height
 code = code.replace("void fragment() {", "uniform int bake_channel = 0;\nvoid fragment() {\n" + locals)
 code = code.insert(code.rfind("}"), "COLOR = vec4(bake_channel == 0 ? bake_albedo : (bake_channel == 1 ? bake_emission / bake_emission_scale : vec3(bake_roughness, bake_specular, bake_metallic)), 1.0);\n")
 code = code.replace("uniform int bake_channel", "uniform float bake_emission_scale = %f;\nuniform int bake_channel" % config.emission_scale)
 return {"code": code, "parameters": parameters}

func bake(theme: String, surface: String, recipe: Dictionary, size: Vector2i) -> void:
 viewport.size = size
 swatch.size = Vector2(size)
 var shader := Shader.new()
 shader.code = recipe.code
 var material := ShaderMaterial.new()
 material.shader = shader
 for key: String in recipe.parameters: material.set_shader_parameter(key, recipe.parameters[key])
 swatch.material = material
 for channel in 3:
  material.set_shader_parameter("bake_channel", channel)
  for i in 3: await process_frame
  await RenderingServer.frame_post_draw
  var suffix: String = ["", "-emission", "-surface"][channel]
  var path := "res://assets/textures/" + theme + "/" + surface + suffix + ".png"
  if viewport.get_texture().get_image().save_png(path) != OK: failures += 1
 print("BAKED | ", theme, "/", surface)

func run() -> void:
 if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--overwrite"):
  push_error("Use a graphical renderer and -- --overwrite. This replaces painted texture edits.")
  quit(1)
  return
 viewport = SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 swatch = ColorRect.new()
 viewport.add_child(swatch)
 var border := FileAccess.get_file_as_string("res://tools/texture_sources/theme_border.gdshader")
 var index := 0
 for theme: String in Sets.SETS:
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/textures/" + theme))
  for surface: String in ["floor", "top", "wall", "facade", "ramp"]:
   await bake(theme, surface, source(theme, surface), Vector2i(1024, 512) if surface in ["wall", "facade"] else Vector2i(1024, 1024))
  for surface: String in ["floor-border", "top-border"]:
   await bake(theme, surface, {"code": border, "parameters": {"theme": index, "raised": surface == "top-border", "emission_scale": Sets.SETS[theme].emission_scale}}, Vector2i(512, 128))
  index += 1
 viewport.free()
 print("RESULT | Texture bake | ", failures, " failures")
 quit(1 if failures else 0)
