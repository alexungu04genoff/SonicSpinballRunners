extends RefCounted
## Reuse actual checker texels for the palm/bridge wood palette. Sampling is
## bounded and cached per theme, including when a local texture selection changes.
static func wood(theme: RefCounted) -> Array[Color]:
 if theme.has_meta("checker_wood_palette"): return theme.get_meta("checker_wood_palette")
 var texture: Texture2D = theme.side_material.get_shader_parameter("soil_texture")
 var image: Image = texture.get_image() if texture != null else null
 var colors: Array[Color] = []
 if image != null:
  if image.is_compressed(): image.decompress()
  for y in 32:
   for x in 32:
    var color := image.get_pixel(mini(image.get_width() - 1, (x * image.get_width()) / 32), mini(image.get_height() - 1, (y * image.get_height()) / 32))
    if color.a > 0.9 and color.s > 0.18 and color.v > 0.12: colors.append(color)
 colors.sort_custom(func(a: Color, b: Color): return a.v < b.v)
 var result: Array[Color] = []
 result.assign([Color("713b20"), Color("b86a2b")] if colors.is_empty() else [colors[colors.size() / 4], colors[(colors.size() * 3) / 4]])
 theme.set_meta("checker_wood_palette", result)
 return result
