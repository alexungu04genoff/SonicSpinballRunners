shader_type spatial;
render_mode cull_disabled, specular_disabled;

// The shared ramp mesh supplies normalized width in UV2.x and route distance
// in UV.y. Cards follow bends and elevation without changing the rail geometry.
float box_distance(vec2 p, vec2 half_size) {
 vec2 d = abs(p) - half_size;
 return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}
float heart_distance(vec2 p) {
 float lobes = min(length(p - vec2(-0.063, -0.045)), length(p - vec2(0.063, -0.045))) - 0.078;
 float tip = max(abs(p.x) * 0.85 + p.y * 0.70 - 0.10, -p.y - 0.045);
 return min(lobes, tip);
}
float suit_distance(vec2 p, float suit) {
 if (suit < 0.5) { return heart_distance(p); }
 if (suit < 1.5) { return abs(p.x) * 1.15 + abs(p.y) - 0.15; }
 float stem = box_distance(p - vec2(0.0, 0.105), vec2(0.027, 0.065));
 if (suit < 2.5) { return min(heart_distance(-p), stem); }
 float lobes = min(length(p - vec2(0.0, -0.075)), min(length(p - vec2(-0.073, 0.025)), length(p - vec2(0.073, 0.025)))) - 0.077;
 return min(lobes, stem);
}
void fragment() {
 vec2 p = vec2(UV2.x - 0.5, fract(UV.y / 0.55) - 0.5);
 float aa = max(length(fwidth(p)), 0.003);
 float suit = mod(floor(UV.y / 0.55), 4.0);
 float card = 1.0 - smoothstep(0.0, aa, box_distance(p, vec2(0.40, 0.43)) - 0.025);
 float border = 1.0 - smoothstep(0.007, 0.007 + aa, abs(box_distance(p, vec2(0.36, 0.39)) - 0.015));
 vec3 ink = suit < 1.5 ? vec3(0.57, 0.012, 0.045) : vec3(0.018, 0.025, 0.05);
 vec3 paper = mix(vec3(0.88, 0.83, 0.69), vec3(0.61, 0.45, 0.22), border * 0.65);
 float center = 1.0 - smoothstep(0.0, aa, suit_distance(p * vec2(0.85, 0.85), suit));
 // Matching corner pips make the white panels read as cards at close range.
 vec2 corner = p.y < 0.0 ? p - vec2(-0.28, -0.29) : -p - vec2(-0.28, -0.29);
 float pip = 1.0 - smoothstep(0.0, aa * 2.7, suit_distance(corner * 2.7, suit));
 paper = mix(paper, ink, max(center, pip));
 ALBEDO = mix(vec3(0.27, 0.025, 0.07), paper, card);
 ROUGHNESS = 0.82;
}
