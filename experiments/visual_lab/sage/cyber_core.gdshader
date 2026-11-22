shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://experiments/visual_lab/sage/cyber_surface.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.052, 0.025, 0.058, 1.0);
uniform vec4 ink : source_color = vec4(0.72, 0.055, 0.16, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.90;

void fragment() {
    float rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    vec4 marks = circuit_sample(normalize(local_normal));
    ALBEDO = mix(tint.rgb, ink.rgb, marks.y * 0.83);
    EMISSION = ink.rgb * (0.035 + 0.20 * marks.y);
    METALLIC = 0.11;
    ROUGHNESS = 0.35 + 0.12 * marks.x;
    SPECULAR = 0.30;
    float density = 1.0 + rim * 0.18 - marks.w * (1.0 - rim) * 0.53;
    ALPHA = clamp(opacity * density, 0.0, 0.95) * smoothstep(0.0, 0.82, assembly);
}
