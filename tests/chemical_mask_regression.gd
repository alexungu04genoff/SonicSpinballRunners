extends SceneTree
## Verify original scalar values at every mip level and through the real bake bank.
const Maps = preload("res://scripts/themes/chemical_material_maps.gd")
const Assets = preload("res://scripts/endless/bake_assets.gd")
const CHANNELS := ["roughness", "ao", "metallic"]
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func run() -> void:
 var maps := Maps.new()
 var assets := Assets.new()
 var original_bytes := 0
 var packed_bytes := 0
 for id: String in Maps.STRENGTH:
  var packed: Texture2D = maps.texture(id, "response")
  var image := packed.get_image()
  check(image != null and image.has_mipmaps() and image.get_format() == Image.FORMAT_RGB8, id + " is linear RGB with mipmaps")
  if image == null: continue
  var references: Array[PackedByteArray] = []
  for channel: String in CHANNELS:
   var source := Image.load_from_file(ProjectSettings.globalize_path(Maps.ROOT + id + "_" + channel + ".png"))
   source.convert(Image.FORMAT_RGBA8)
   source.generate_mipmaps()
   check(source.get_size() == image.get_size() and source.get_mipmap_count() == image.get_mipmap_count(), id + " " + channel + " retains dimensions and mip count")
   references.append(source.get_data())
   original_bytes += source.get_data_size()
  var pixels := image.get_data()
  packed_bytes += pixels.size()
  var imported: Texture2D = load(Maps.ROOT + id + "_response.png")
  var imported_image := imported.get_image()
  imported_image.convert(Image.FORMAT_RGB8)
  check(imported_image.has_mipmaps() and imported_image.get_size() == image.get_size() and imported_image.get_data() == pixels, id + " imported/export texture matches the editor and bake pixels")
  var exact := references[0].size() / 4 * 3 == pixels.size()
  if exact:
   for pixel in pixels.size() / 3:
    for channel in 3:
     if pixels[pixel * 3 + channel] != references[channel][pixel * 4]:
      exact = false
      break
    if not exact: break
  check(exact, id + " preserves every roughness/AO/metallic value at every mip level")
  var canonical: Texture2D = assets.share(packed)
  check(assets.error.is_empty() and canonical.get_image().get_data() == pixels and canonical.get_image().get_format() == Image.FORMAT_RGB8, id + " survives canonical bake serialization")
  var settings := ConfigFile.new()
  check(settings.load(Maps.ROOT + id + "_response.png.import") == OK and settings.get_value("params", "mipmaps/generate", false) and settings.get_value("params", "compress/mode", -1) == 0, id + " export import retains lossless values and mipmaps")
 var theme = preload("res://scripts/themes/chemical_plant_theme.gd").new()
 var ramps: Dictionary = theme.ramp_materials()
 var surfaces: Array = [theme.floor_material, theme.side_material, theme.cliff_material, theme.top_material, theme.floor_border_material, theme.top_border_material, ramps.deck, ramps.edge]
 for material: ShaderMaterial in surfaces:
  var texture: Texture2D = material.get_shader_parameter("detail_response")
  check(texture != null and texture.get_image().has_mipmaps(), "Production surface binds the packed response")
  var baked: ShaderMaterial = assets.share(material)
  var retained: Texture2D = baked.get_shader_parameter("detail_response")
  check(assets.error.is_empty() and retained != null and retained.get_image().get_data() == texture.get_image().get_data(), "Production response survives the bake material policy")
 print("CHEMICAL_MASK_BYTES | original=", original_bytes, " packed=", packed_bytes, " | CPU image bytes including mipmaps; not measured GPU allocation")
 print("CHEMICAL_MASK_REGRESSION | ", checks, " checks | ", failures, " failures")
 quit(1 if failures else 0)
