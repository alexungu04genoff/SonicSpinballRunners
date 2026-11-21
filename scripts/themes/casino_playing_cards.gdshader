shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/atmosphere/hue.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 enamel : source_color = vec4(0.095, 0.145, 0.265, 1.0);

// Each atlas cell is 128 by 180 pixels. A card is inset within its cell.
// UV.x is the lane's length in lane widths. UV2 gives width fraction and
// distance in lane widths, so the printed proportions survive track scaling.
const float CARD_PITCH = 180.0 / 128.0;

void fragment() {
 // A short, wide custom ramp gets one centered ace at the same aspect ratio.
 float pitch = clamp(UV.x, 0.0001, CARD_PITCH);
 float card_count = floor(UV.x / pitch);
 float margin = (UV.x - card_count * pitch) * 0.5;
 float deal = (UV2.y - margin) / pitch;
 float across = (UV2.x - 0.5) * CARD_PITCH / pitch + 0.5;
 float slot = floor(deal);
 vec2 atlas_uv = vec2((mod(slot, 4.0) + clamp(across, 0.0, 1.0)) * 0.25, 1.0 - fract(deal));
 // Keep derivatives continuous over both the suit boundary and each card end.
 vec2 chart = vec2(across * 0.25, -UV2.y / pitch);
 vec4 print_ink = textureGrad(albedo_texture, atlas_uv, dFdx(chart), dFdy(chart));
 float on_card = print_ink.a * step(0.0, slot) * (1.0 - step(card_count, slot));
 ALBEDO = mix(atmosphere_shift(enamel.rgb), print_ink.rgb, on_card);
 ROUGHNESS = mix(0.55, 0.82, on_card);
 SPECULAR = 0.24;
}
