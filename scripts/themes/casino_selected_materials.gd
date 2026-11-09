extends RefCounted
## Approved Phase 3 albedos. Original assets remain available for comparison.
const DIRECTORY := "res://assets/textures/casino_night/selected/"
const SHADER = preload("res://scripts/themes/casino_selected.gdshader")
static var textures: Dictionary = {}

static func texture(id: String) -> Texture2D:
 if not textures.has(id):
  var image := Image.load_from_file(DIRECTORY + id + ".png")
  image.generate_mipmaps()
  textures[id] = ImageTexture.create_from_image(image)
 return textures[id]

static func surface(id: String, mapping: int, repeat_size: Vector2) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = SHADER
 result.set_shader_parameter("albedo_texture", texture(id))
 result.set_shader_parameter("cap_texture", texture("4B"))
 result.set_shader_parameter("mapping", mapping)
 result.set_shader_parameter("repeat_size", repeat_size)
 return result

static func housing() -> StandardMaterial3D:
 var result := StandardMaterial3D.new()
 result.albedo_texture = texture("10B")
 result.roughness = 0.65
 result.metallic_specular = 0.3
 result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 return result
