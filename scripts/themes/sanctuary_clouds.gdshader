shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p), f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
 vec2 p = world_position.xz * 0.12;
 float n = noise(p) * 0.62 + noise(p * 2.1) * 0.26 + noise(p * 4.3) * 0.12;
 // Cloud troughs stay blue, never a white ground slab or a water surface.
 vec3 color = mix(vec3(0.54, 0.71, 0.82), vec3(0.82, 0.89, 0.93), smoothstep(0.18, 0.65, n));
 ALBEDO = color;
}
