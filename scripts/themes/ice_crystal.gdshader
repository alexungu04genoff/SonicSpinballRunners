shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Only decorative thin crystals use transparency. Terrain stays opaque.
uniform vec3 atmosphere_tint = vec3(1.0);
void fragment() {
 float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
 ALBEDO = mix(vec3(0.16, 0.52, 0.69), vec3(0.65, 0.95, 0.97), rim);
 ROUGHNESS = 0.13;
 SPECULAR = 0.9;
 EMISSION = vec3(0.10, 0.36, 0.40) * (0.18 + rim * 0.4);
 ALBEDO *= atmosphere_tint;
 EMISSION *= atmosphere_tint;
 ALPHA = 0.78 + rim * 0.20;
}
