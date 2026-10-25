extends SceneTree
## Explicit initial-art bake. Runtime loads PNGs and never regenerates artwork.
const OUTPUT := "res://assets/textures/rooftop_run/"
var viewport: SubViewport
var swatch: ColorRect

func _initialize() -> void:
 call_deferred("run")

func bake(name: String, code: String, size: Vector2i, parameters: Dictionary = {}) -> void:
 viewport.size = size
 swatch.size = Vector2(size)
 var shader := Shader.new()
 shader.code = code
 var material := ShaderMaterial.new()
 material.shader = shader
 for key: String in parameters: material.set_shader_parameter(key, parameters[key])
 swatch.material = material
 for i in 3: await process_frame
 await RenderingServer.frame_post_draw
 assert(viewport.get_texture().get_image().save_png(OUTPUT + name + ".png") == OK)
 print("BAKED | ", name)

func canvas_source(name: String) -> String:
 var code := FileAccess.get_file_as_string("res://tools/texture_sources/rooftop_" + name + ".gdshader")
 code = code.replace("shader_type spatial;", "shader_type canvas_item;")
 code = code.replace("render_mode cull_disabled, specular_disabled;", "render_mode unshaded;")
 var declarations := RegEx.new()
 declarations.compile("(?s)varying vec3 world_position;.*?void vertex\\(\\) \\{.*?\\}")
 code = declarations.sub(code, "")
 return code

func run() -> void:
 if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--overwrite"):
  push_error("Use a graphical renderer and -- --overwrite to replace the rooftop PNGs.")
  quit(1)
  return
 viewport = SubViewport.new()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 swatch = ColorRect.new()
 viewport.add_child(swatch)
 var cobble := FileAccess.get_file_as_string("res://tools/texture_sources/rooftop_cobble.gdshader")
 await bake("floor", cobble, Vector2i(1024, 1024))
 await bake("floor-border", cobble, Vector2i(512, 128), {"border": true})
 await bake("top-border", cobble, Vector2i(512, 128), {"border": true, "raised": true})
 var top := canvas_source("paving").replace("world_position.xz", "UV * vec2(5.0, 3.125)").replace("ALBEDO =", "COLOR.rgb =").replace("ROUGHNESS = 0.94;", "")
 await bake("top", top, Vector2i(1024, 1024), {"raised_surface": true})
 var wall := canvas_source("masonry")
 wall = wall.left(wall.find("void fragment()")) + "void fragment() { COLOR = vec4(masonry(vec2(UV.x * 3.4, top_height - UV.y * 1.45), UV.y * 1.45), 1.0); }"
 # Twelve bricks across four facade bays give a seamless repeat for both motifs.
 wall = wall.replace("vec2(3.0, 6.0)", "vec2(3.529411765, 6.0)")
 await bake("wall", wall, Vector2i(1024, 512))
 await bake("facade", wall, Vector2i(1024, 512), {"facade": true, "top_height": 0.0})
 var ramp := canvas_source("ramp").replace("vec2 p = UV;", "vec2 p = UV * vec2(0.48, 0.44);").replace("ALBEDO =", "COLOR.rgb =").replace("ROUGHNESS = 0.9;", "")
 await bake("ramp", ramp, Vector2i(256, 256), {"surface_kind": 2, "base_color": Color("bf7954"), "alternate_color": Color("dba27a")})
 viewport.free()
 quit()
