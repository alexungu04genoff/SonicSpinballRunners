shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
 float distance_from_center = length(UV * 2.0 - 1.0);
 float falloff = 1.0 - smoothstep(0.62, 1.0, distance_from_center);
 ALBEDO = vec3(0.22, 0.8, 1.0);
 ALPHA = falloff * 0.24;
}
