shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;

// An expanded back-face pass follows each mesh silhouette instead of its bounds.
void vertex() {
 VERTEX += NORMAL * 0.0198;
}

void fragment() {
 ALBEDO = vec3(0.18, 0.65, 0.8);
 float edge = 1.0 - smoothstep(0.0, 0.55, abs(dot(normalize(NORMAL), normalize(VIEW))));
 ALPHA = 0.22 * edge;
}
