shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform bool raised_turf = false;
varying vec3 terrain_position;
void vertex() { terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
 vec2 ground = terrain_position.xz;
 vec2 p = ground * 3.0;
 vec2 cell = floor(p);
 vec2 blend = fract(p);
 blend = blend * blend * (3.0 - 2.0 * blend);
 float noise = mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
 // Staggered little grass tufts, with broad patches underneath. World-space
 // coordinates keep the same texture density on curved stamps and rail caps.
 vec2 blades = ground * 28.0;
 blades.x += mod(floor(blades.y), 2.0) * 0.5;
 vec2 blade = fract(blades) - 0.5;
 float tuft = (1.0 - smoothstep(0.055, 0.14, abs(abs(blade.x) - (blade.y + 0.35) * 0.32))) * step(-0.3, blade.y) * step(blade.y, 0.28);
 vec3 dark = raised_turf ? vec3(0.14, 0.49, 0.025) : vec3(0.16, 0.40, 0.045);
 vec3 light = raised_turf ? vec3(0.40, 0.78, 0.035) : vec3(0.28, 0.55, 0.065);
 ALBEDO = mix(dark, light, 0.35 + noise * 0.40 + tuft * 0.22);
 ROUGHNESS = 1.0;
}
