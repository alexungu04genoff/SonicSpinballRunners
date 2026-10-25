shader_type spatial;
render_mode unshaded, world_vertex_coords, shadows_disabled;
void vertex() {
 VERTEX.x += sin(TIME * 0.18 + MODEL_MATRIX[3].z) * 0.3;
 // Wrap each whole instance, avoiding stretched triangles at the cycle boundary.
 float base_y = MODEL_MATRIX[3].y;
 VERTEX.y += mod(base_y + 6.0 - TIME * 0.16, 10.0) - 6.0 - base_y;
}
void fragment() { ALBEDO = vec3(0.52, 0.67, 0.75); }
