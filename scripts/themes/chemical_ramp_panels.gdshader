shader_type spatial;
render_mode cull_disabled, specular_disabled;
// UV.y is route distance; UV2.x spans the complete deck, regardless of width.
float rectangle(vec2 p, vec2 low, vec2 high) {
 return step(low.x, p.x) * step(p.x, high.x) * step(low.y, p.y) * step(p.y, high.y);
}
void fragment() {
 float panel = floor(UV.y / 0.34);
 vec2 p = vec2(UV2.x, fract(UV.y / 0.34));
 vec3 yellow = vec3(0.50, 0.39, 0.045);
 vec3 gray = vec3(0.19, 0.22, 0.25);
 vec3 pale = vec3(0.70, 0.72, 0.67);
 vec3 color = yellow;
 // Broad ochre framing, pale inset rims, alternating gray hatches/yellow lids.
 float rim = rectangle(p, vec2(0.14, 0.13), vec2(0.86, 0.87));
 float inset = rectangle(p, vec2(0.18, 0.18), vec2(0.82, 0.82));
 color = mix(color, pale, rim);
 float hatch = mod(panel, 2.0);
 vec3 plate = mix(yellow * 0.93, gray, hatch);
 float seam = step(0.92, fract(p.x * 18.0)) + step(0.94, fract(p.y * 10.0));
 plate *= 1.0 - min(seam, 1.0) * hatch * 0.17;
 // Three dark service slots on the yellow panels; understated corner fasteners.
 float slots = rectangle(p, vec2(0.29, 0.35), vec2(0.62, 0.65)) * step(0.60, fract(p.y * 17.0));
 plate = mix(plate, gray * 0.65, slots * (1.0 - hatch));
 color = mix(color, plate, inset);
 vec2 bolt_cell = vec2(min(abs(p.x - 0.10), abs(p.x - 0.90)), min(abs(p.y - 0.10), abs(p.y - 0.90)));
 color = mix(color, gray, 1.0 - smoothstep(0.009, 0.018, length(bolt_cell)));
 float joint = 1.0 - smoothstep(0.0, 0.018, min(p.y, 1.0 - p.y));
 color = mix(color, gray * 0.7, joint);
 // Thin pale longitudinal lines tie the repeated modules into the side frame.
 float stripe = step(0.035, p.x) * step(p.x, 0.055) + step(0.945, p.x) * step(p.x, 0.965);
 ALBEDO = mix(color, pale, stripe);
 ROUGHNESS = 0.84;
}
