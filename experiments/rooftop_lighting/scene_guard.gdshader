shader_type spatial;
render_mode cull_disabled;
#include "res://experiments/rooftop_lighting/scene_normal.gdshaderinc"
uniform vec4 base_color : source_color = vec4(1.0);
uniform float base_roughness = 1.0;
uniform float base_specular = 0.5;
varying vec2 route_uv;
void vertex() {
 // Existing strips emit six unindexed vertices per quad in this order.
 // This supplies the missing cross-strip coordinate without editing the mesh.
 int corner = VERTEX_ID % 6;
 float across = (corner == 2 || corner == 3 || corner == 5) ? 1.0 : 0.0;
 route_uv = vec2(UV.y / 0.48, across);
}
void fragment() {
 ALBEDO = base_color.rgb;
 ROUGHNESS = base_roughness;
 SPECULAR = base_specular;
 NORMAL = relief(VERTEX, NORMAL, route_uv, vec2(fract(route_uv.x), clamp(route_uv.y, 0.0, 1.0)));
}
