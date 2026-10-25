shader_type spatial;
render_mode cull_disabled, specular_disabled;
void fragment() {
 vec2 tile = floor(UV * 6.25);
 float checker = mod(tile.x + tile.y, 2.0);
 vec2 edge = min(fract(UV * 6.25), 1.0 - fract(UV * 6.25));
 float seam = smoothstep(0.0, 0.035, min(edge.x, edge.y));
 vec3 dark = vec3(0.30, 0.095, 0.025);
 vec3 light = vec3(0.72, 0.32, 0.075);
 ALBEDO = mix(dark, light, checker) * mix(0.88, 1.0, seam);
 ROUGHNESS = 1.0;
}
