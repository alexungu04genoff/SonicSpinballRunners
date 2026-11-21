shader_type spatial;
#include "res://scripts/atmosphere/hue.gdshaderinc"
render_mode cull_disabled, specular_disabled;

uniform vec4 limestone : source_color;

void fragment() {
 // Side UVs fan out from the tread. A joint at constant station cuts a wedge.
 float course = UV.x / 0.265;
 float wedge = floor(course);
 float edge = min(fract(course), 1.0 - fract(course));
 float pixel = max(fwidth(course) * 0.5, 0.001);
 float stone = smoothstep(0.022 - pixel, 0.022 + pixel, edge);
 float pencil_edge = 1.0 - smoothstep(0.052 - pixel, 0.052 + pixel, edge);
 float shade = 0.96 + 0.045 * cos(wedge * 2.1) + 0.02 * cos(wedge * 3.4);
 vec3 face = limestone.rgb * shade * (1.0 + 0.08 * pencil_edge);
 ALBEDO = atmosphere_shift(mix(limestone.rgb * 0.52, face, stone));
 ROUGHNESS = 0.92;
}
