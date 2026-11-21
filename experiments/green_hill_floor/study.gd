extends RefCounted
## Private material for one held Act. The baked receiver and its shader stay on disk.
const DIR := "res://experiments/green_hill_floor/"
const FLOOR_SAMPLE := "ALBEDO=texture(surface_texture,world_position.xz/repeat_size).rgb;"
var originals := {}
var materials := {}
var programs := {}
var textures := {}

func artwork(mounted: bool) -> ImageTexture:
 if textures.has(mounted): return textures[mounted]
 var route := Image.new()
 if route.load_svg_from_string(FileAccess.get_file_as_string(DIR + "route.svg")) != OK: return null
 if mounted:
  var mounts := Image.new()
  if mounts.load_svg_from_string(FileAccess.get_file_as_string(DIR + "mounts.svg")) != OK: return null
  route.blend_rect(mounts, Rect2i(Vector2i.ZERO, mounts.get_size()), Vector2i.ZERO)
 route.fix_alpha_edges()
 route.generate_mipmaps()
 textures[mounted] = ImageTexture.create_from_image(route)
 return textures[mounted]

func apply(root: Node3D, mounted: bool) -> bool:
 var texture := artwork(mounted)
 if texture == null: return false
 if originals.is_empty():
  for node: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
   var source := node.material_override as ShaderMaterial
   if not source or source.get_meta("atmosphere_hue", "") != "terrain_ground": continue
   if not source.shader or not FLOOR_SAMPLE in source.shader.code: continue
   if not materials.has(source):
    if not programs.has(source.shader):
     var variant := Shader.new()
     var code := source.shader.code.replace("void fragment()", "uniform sampler2D floor_art : source_color, filter_linear_mipmap_anisotropic, repeat_disable;\nvoid fragment()")
     variant.code = code.replace(FLOOR_SAMPLE, FLOOR_SAMPLE + """
 vec2 art_uv = world_position.xz / 6.4;
 vec4 art = texture(floor_art, art_uv);
 float inside = float(all(greaterThanEqual(art_uv, vec2(0.0))) && all(lessThan(art_uv, vec2(1.0))));
 ALBEDO = mix(ALBEDO, art.rgb * (0.81 + 1.25 * ALBEDO.g), art.a * inside);
""")
     programs[source.shader] = variant
    var material: ShaderMaterial = source.duplicate()
    material.shader = programs[source.shader]
    materials[source] = material
   originals[node] = source
   node.material_override = materials[source]
 for material: ShaderMaterial in materials.values(): material.set_shader_parameter("floor_art", texture)
 return not originals.is_empty()

func restore() -> void:
 for node: GeometryInstance3D in originals: node.material_override = originals[node]
 originals.clear()
 materials.clear()
 programs.clear()
 textures.clear()
