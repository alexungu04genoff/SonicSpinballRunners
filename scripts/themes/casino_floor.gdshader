shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform bool raised_surface = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 // Quiet blue baize panels; large, low-contrast inlays survive the retro view.
 vec2 p = world_position.xz * 1.6;
 vec2 q = fract(p) - 0.5;
 vec2 edge = 0.5 - abs(q);
 float aa = max(length(fwidth(p)), 0.004);
 float seam = 1.0 - smoothstep(0.012, 0.012 + aa, min(edge.x, edge.y));
 float inset = 1.0 - smoothstep(0.014, 0.014 + aa, abs(max(abs(q.x), abs(q.y)) - 0.40));
 float cell = mod(floor(p.x) + floor(p.y), 4.0);
 vec3 base = mix(vec3(0.025, 0.055, 0.15), vec3(0.045, 0.10, 0.24), cell / 4.0);
 if (raised_surface) { base = vec3(0.32, 0.025, 0.065); }
 float angle = atan(q.x, q.y);
 float star_radius = 0.13 + 0.055 * cos(angle * 5.0);
 float star = (1.0 - smoothstep(star_radius, star_radius + aa, length(q))) * step(2.5, cell);
 base = mix(base, raised_surface ? vec3(0.46, 0.18, 0.075) : vec3(0.08, 0.14, 0.27), star * (raised_surface ? 0.65 : 0.30));
 base = mix(base, vec3(0.32, 0.20, 0.07), inset * (raised_surface ? 0.8 : 0.10));
 ALBEDO = mix(base, vec3(0.018, 0.025, 0.065), seam * 0.75);
 // Short, sparse blue inserts rather than bright lines beneath every ring.
 float strip = (1.0 - smoothstep(0.017, 0.017 + aa, abs(q.y - 0.43))) * (1.0 - smoothstep(0.12, 0.12 + aa, abs(q.x))) * step(2.5, cell);
 EMISSION = vec3(0.045, 0.12, 0.40) * strip * (raised_surface ? 0.25 : 0.42);
 ROUGHNESS = 0.78;
}
