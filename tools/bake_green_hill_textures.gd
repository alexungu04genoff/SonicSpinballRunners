extends SceneTree
## Explicit authoring utility. Never runs in gameplay or automatically overwrites art.
const OUTPUT := "res://assets/textures/green_hill/"
var viewport: SubViewport
var swatch: ColorRect

func _initialize() -> void:
 call_deferred("run")

func bake(name: String, source: String, size: Vector2i, parameters: Dictionary = {}) -> void:
 viewport.size = size
 swatch.size = Vector2(size)
 var shader := Shader.new()
 shader.code = source
 var material := ShaderMaterial.new()
 material.shader = shader
 for key: String in parameters: material.set_shader_parameter(key, parameters[key])
 swatch.material = material
 for i in 3: await process_frame
 await RenderingServer.frame_post_draw
 var image := viewport.get_texture().get_image()
 assert(image.save_png(OUTPUT + name + ".png") == OK)
 print("BAKED | ", name, " | ", size)

func canvas_source(path: String) -> String:
 var code := FileAccess.get_file_as_string(path)
 code = code.replace("shader_type spatial;", "shader_type canvas_item;")
 code = code.replace("render_mode cull_disabled, specular_disabled;", "render_mode unshaded;")
 code = code.replace("ROUGHNESS = 1.0;", "").replace("ROUGHNESS = 0.9;", "")
 code = code.replace("ALBEDO =", "COLOR.rgb =")
 return code

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Texture baking requires a graphical renderer.")
  quit(1)
  return
 if not OS.get_cmdline_user_args().has("--overwrite"):
  push_error("Pass --overwrite to explicitly replace the editable PNG artwork.")
  quit(1)
  return
 viewport = SubViewport.new()
 viewport.transparent_bg = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 swatch = ColorRect.new()
 viewport.add_child(swatch)
 var grass := canvas_source("res://tools/texture_sources/green_hill_grass.gdshader")
 grass = grass.replace("varying vec3 terrain_position;", "")
 grass = grass.replace("void vertex() { terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }", "")
 grass = grass.replace("vec2 ground = terrain_position.xz;", "vec2 ground = UV * 4.0;")
 # Wrap only the noise hash; twelve broad cells and 112 blade rows repeat cleanly.
 grass = grass.replace("dot(p, vec2(127.1, 311.7))", "dot(mod(p, 12.0), vec2(127.1, 311.7))")
 await bake("floor", grass, Vector2i(1024, 1024))
 await bake("top", grass, Vector2i(1024, 1024), {"raised_turf": true})
 var cliff := canvas_source("res://tools/texture_sources/green_hill_cliff.gdshader").replace("UV * 6.25", "UV * 2.0")
 await bake("cliff", cliff, Vector2i(256, 256))
 await bake("soil", cliff.replace("mix(0.88, 1.0, seam)", "1.0"), Vector2i(256, 256))
 var wood := canvas_source("res://tools/texture_sources/green_hill_ramp.gdshader")
 wood = wood.replace("vec2 p = UV;", "vec2 p = UV * vec2(0.64, 1.04);")
 # Eight boards per repeat. Periodic grain keeps the saved image seamless.
 wood = wood.replace("plank * 2.4", "plank * 2.35619449")
 wood = wood.replace("p.x * 170.0 + sin(p.y * 13.0)", "UV.x * 106.8141502 + sin(UV.y * 12.5663706)")
 await bake("ramp", wood, Vector2i(512, 512), {"base_color": Color("b97d3f"), "alternate_color": Color("d2a15d")})
 var fringe := """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
 float depth = UV.y * 0.1;
 float blade = abs(fract(UV.x * 8.0) - 0.5) * 0.045;
 vec3 grass = mix(vec3(0.13, 0.39, 0.025), vec3(0.49, 0.79, 0.035), 1.0 - smoothstep(0.0, 0.08, depth));
 COLOR = vec4(grass, 1.0 - smoothstep(0.065 + blade - 0.001, 0.065 + blade + 0.001, depth));
}
"""
 await bake("wall-fringe", fringe, Vector2i(256, 128))
 var border := """
shader_type canvas_item;
render_mode unshaded;
uniform bool raised = false;
void fragment() {
 float blade = abs(fract(UV.x * 12.0) - 0.5);
 float edge = 1.0 - smoothstep(0.28 + blade * 0.45, 0.36 + blade * 0.45, UV.y);
 vec3 inner = raised ? vec3(0.30, 0.65, 0.03) : vec3(0.22, 0.48, 0.055);
 vec3 outer = raised ? vec3(0.12, 0.36, 0.02) : vec3(0.105, 0.28, 0.025);
 COLOR = vec4(mix(inner, outer, edge * 0.8), 1.0);
}
"""
 await bake("floor-border", border, Vector2i(256, 128))
 await bake("top-border", border, Vector2i(256, 128), {"raised": true})
 viewport.free()
 quit()
