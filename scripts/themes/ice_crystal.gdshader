shader_type spatial;
render_mode cull_back;
// Opaque, rim-lit ice avoids transparent cap/backface ordering in compound props.
uniform vec3 atmosphere_tint = vec3(1.0);
void fragment() {
 // Interpolated vectors/roundoff can put the dot outside [-1, 1]. A negative
 // base to fractional pow produces NaNs, magnified into black dots by Retro.
 float rim = pow(clamp(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.5);
 ALBEDO = mix(vec3(0.16, 0.52, 0.69), vec3(0.65, 0.95, 0.97), rim);
 ROUGHNESS = 0.13;
 SPECULAR = 0.9;
 EMISSION = vec3(0.10, 0.36, 0.40) * (0.18 + rim * 0.4);
 ALBEDO *= atmosphere_tint;
 EMISSION *= atmosphere_tint;
}
