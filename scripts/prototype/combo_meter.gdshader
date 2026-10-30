shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float tier = 1.0;
uniform float remaining = 0.0;
void fragment() {
 vec2 p = (UV - 0.5) * 2.0;
 float radius = length(p);
 float ring = smoothstep(0.86, 0.89, radius) * (1.0 - smoothstep(0.98, 1.0, radius));
 float angle = mod(atan(p.x, -p.y) + 6.283185, 6.283185) / 6.283185;
 vec3 green = vec3(0.25, 0.91, 0.49);
 vec3 yellow = vec3(1.0, 0.83, 0.20);
 vec3 red = vec3(1.0, 0.26, 0.29);
 bool top = angle <= remaining;
 ALBEDO = tier > 3.5 ? (top ? red : yellow) : (tier > 2.5 ? (top ? yellow : green) : green);
 ALPHA = ring * (tier < 1.5 ? 0.0 : (tier < 2.5 && !top ? 0.0 : 1.0));
}
