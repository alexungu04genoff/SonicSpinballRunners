shader_type spatial;
uniform float time_override = -1.0;
float theme_time() { return time_override >= 0.0 ? time_override : TIME; }
render_mode unshaded, world_vertex_coords, shadows_disabled;
void vertex() {
 VERTEX.x += sin(theme_time() * 0.18 + MODEL_MATRIX[3].z) * 0.3;
 // Wrap each whole instance, avoiding stretched triangles at the cycle boundary.
 float base_y = MODEL_MATRIX[3].y;
 VERTEX.y += mod(base_y + 6.0 - theme_time() * 0.16, 10.0) - 6.0 - base_y;
}
void fragment() { ALBEDO = vec3(0.52, 0.67, 0.75); }
