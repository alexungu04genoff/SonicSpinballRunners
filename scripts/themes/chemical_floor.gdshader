shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform bool raised_surface = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 // Broad, quiet plates keep the ball legible at the table camera's scale.
 vec2 p = world_position.xz * 2.0;
 vec2 cell = floor(p);
 vec2 q = fract(p);
 vec2 edge = min(q, 1.0 - q);
 float aa = max(length(fwidth(p)), 0.005);
 float seam = 1.0 - smoothstep(0.012, 0.012 + aa, min(edge.x, edge.y));
 float alternate = mod(cell.x + cell.y, 2.0);
 vec3 plate = mix(vec3(0.115, 0.20, 0.29), vec3(0.14, 0.23, 0.32), alternate);
 if (raised_surface) { plate = mix(vec3(0.40, 0.49, 0.58), vec3(0.48, 0.57, 0.64), alternate); }
 ALBEDO = mix(plate, vec3(0.035, 0.065, 0.12), seam * 0.75);
 // Inset cyan service indicators, sparse and short, never ring-shaped.
 float strip = (1.0 - smoothstep(0.022, 0.022 + aa, abs(q.y - 0.10))) * step(0.12, q.x) * step(q.x, 0.36);
 strip *= raised_surface ? 0.85 : 0.16;
 ALBEDO = mix(ALBEDO, vec3(0.04, 0.65, 0.82), strip);
 EMISSION = vec3(0.05, 0.65, 0.9) * strip * 0.55;
 // The raised cap has occasional yellow/black service hatching.
 float hazard = step(0.87, q.y) * step(q.y, 0.95) * step(0.12, q.x) * step(q.x, 0.88);
 hazard *= raised_surface ? step(0.5, mod(cell.x + cell.y, 3.0)) : 0.0;
 float diagonal = step(0.5, fract((p.x + p.y) * 5.0));
 ALBEDO = mix(ALBEDO, mix(vec3(0.035, 0.05, 0.08), vec3(0.94, 0.68, 0.08), diagonal), hazard);
 ROUGHNESS = 0.78;
}
