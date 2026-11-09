extends SceneTree
## Isolated color-texture preview. No geometry changes or generated relief maps.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const ASSETS := "res://experiments/rooftop_lighting/texture-selected-refined/"
const FILES := {
 "floor": "1A-limestone-floor.png", "floor-border": "2A-spring-grass-border.png",
 "cap": "4B-alternating-wall-cap.png", "top": "5A-red-barrel-rooftop.png",
 "ramp": "7B-terracotta-ramp.png", "guard": "8B-teal-metal-railing.png",
 "facade": "9B-limestone-arched-facade.png",
}
const REPEATS := {"floor": Vector2(1.8, 1.8), "top": Vector2(1.6, 1.3), "ramp": Vector2(1.4, 1.5)}
var game: Node
var textures := {}
var cache := {}

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count: await process_frame

func run() -> void:
 root.size = Vector2i(1920, 1080)
 for role in FILES:
  var source := Image.load_from_file(ASSETS + FILES[role])
  source.generate_mipmaps()
  textures[role] = ImageTexture.create_from_image(source)
 game = Game.new()
 game.theme_id = "rooftop_run"
 game.authored_act_path = "res://data/acts/Third complex.tres"
 root.add_child(game)
 await frames(20)
 paused = true
 game.rooftop_materials.set_mode(0)
 game.retro_filter.set_effects([])
 game.presentation.set_camera_follow(false)
 game.view_container.offset_bottom = 0
 freeze(game)
 swap_tree(game.presentation)
 var camera: Camera3D = game.presentation.camera
 camera.projection = Camera3D.PROJECTION_PERSPECTIVE
 camera.fov = 44
 var target: Vector3 = game.presentation.map_point(Vector2(465, 420), 0.02)
 camera.position = target + Vector3(0.1, 1.0, 1.4)
 camera.look_at(target)
 await frames(12)
 if "--save-preview" in OS.get_cmdline_user_args():
  await RenderingServer.frame_post_draw
  var destination := "res://experiments/rooftop_lighting/screenshots/selected-textures-close.png"
  game.retro_filter.world_view.get_texture().get_image().save_png(destination)
  print("TEXTURE_PREVIEW_SAVED | ", ProjectSettings.globalize_path(destination))

func freeze(node: Node) -> void:
 node.process_mode = Node.PROCESS_MODE_DISABLED
 if node is CanvasLayer: node.hide()
 for child in node.get_children(): freeze(child)

func swap_tree(node: Node) -> void:
 if node is GeometryInstance3D and node.material_override:
  node.material_override = replacement(node.material_override, node)
 elif node is MeshInstance3D and node.mesh:
  for surface in node.mesh.get_surface_count():
   var original: Material = node.get_active_material(surface)
   if original: node.set_surface_override_material(surface, replacement(original, node))
 for child in node.get_children(): swap_tree(child)

func replacement(original: Material, node: GeometryInstance3D) -> Material:
 var rail_role := str(node.get_meta("rail_surface", ""))
 if rail_role in ["Fascia", "InnerEdge"]:
  return guard_material()
 if not original is ShaderMaterial: return original
 var key := original.get_instance_id()
 if cache.has(key): return cache[key]
 for parameter in ["surface_texture", "wall_texture", "border_texture"]:
  var source = original.get_shader_parameter(parameter)
  if not source is Texture2D: continue
  var role: String = source.resource_path.get_file().get_basename()
  if role == "wall":
   # The existing cream cornice is a band in the wall material, not a separate mesh.
   # Preserve the chosen 3C masonry below it and replace only that cap band.
   var result: ShaderMaterial = original.duplicate()
   var shader := Shader.new()
   var code: String = original.shader.code
   code = code.replace("varying vec3 world_position;", "uniform sampler2D cap_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;\nvarying vec3 world_position;")
   code = code.replace("ROUGHNESS = 0.95;", "if (depth >= 0.0 && depth < 0.055) {\n float v = mix(0.025, 0.14, depth / 0.055);\n ALBEDO = texture(cap_texture, vec2(world_position.z / 1.2, v)).rgb * weights.x + texture(cap_texture, vec2(world_position.x / 1.2, v)).rgb * weights.y;\n }\n ROUGHNESS = 0.95;")
   shader.code = code
   result.shader = shader
   result.set_shader_parameter("cap_texture", textures.cap)
   cache[key] = result
   return result
  if not textures.has(role): return original
  var result: ShaderMaterial = original.duplicate()
  result.set_shader_parameter(parameter, textures[role])
  if REPEATS.has(role): result.set_shader_parameter("repeat_size", REPEATS[role])
  if role == "floor-border":
   var shader := Shader.new()
   # Sample a narrow slice of turf across the narrow border, avoiding stretched blades.
   shader.code = original.shader.code.replace("clamp(UV.y, 0.0, 1.0)", "clamp(UV.y, 0.0, 1.0) * 0.25").replace("dFdy(UV)", "dFdy(vec2(UV.x, UV.y * 0.25))").replace("dFdx(UV)", "dFdx(vec2(UV.x, UV.y * 0.25))")
   result.shader = shader
  if role == "facade":
   var shader := Shader.new()
   shader.code = original.shader.code.replace("vec2(3.4, 1.45)", "vec2(1.7, 1.45)")
   result.shader = shader
  cache[key] = result
  return result
 return original

func guard_material() -> ShaderMaterial:
 if cache.has("guard"): return cache.guard
 var result := ShaderMaterial.new()
 var shader := Shader.new()
 shader.code = """shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D color_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 route_uv;
void vertex() {
 int corner = VERTEX_ID % 6;
 float across = (corner == 2 || corner == 3 || corner == 5) ? 1.0 : 0.0;
 route_uv = vec2(UV.y / 0.55, 1.0 - across);
}
void fragment() {
 ALBEDO = texture(color_texture, vec2(route_uv.x, clamp(route_uv.y, 0.0, 1.0))).rgb;
 ROUGHNESS = 0.85;
}
"""
 result.shader = shader
 result.set_shader_parameter("color_texture", textures.guard)
 cache.guard = result
 return result
