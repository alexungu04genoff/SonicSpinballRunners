shader_type spatial;
render_mode unshaded, cull_disabled;
// One opaque plane: three broad analytic bands, no textures or extra passes.
// Raw linear colors are converted from the Lab's sRGB picker on apply only.
uniform vec3 deep_color = vec3(0.009, 0.26, 0.32);
uniform vec3 wave_color = vec3(0.026, 0.47, 0.53);
uniform vec3 reflection_color = vec3(0.12, 0.62, 0.68);
uniform vec3 sun_color = vec3(0.50, 0.67, 0.56);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_position.xz;
 float broad = sin(p.y * 0.85 + p.x * 0.21 + TIME * 0.24);
 float ripple = sin(p.y * 2.2 - p.x * 0.34 - TIME * 0.31 + broad * 0.65);
 float wave = 0.5 + broad * 0.30 + ripple * 0.20;
 vec3 water = mix(deep_color, wave_color, wave);
 float reflection = smoothstep(0.35, 0.95, ripple) * 0.40;
 water = mix(water, reflection_color, reflection);
 // A broad broken sun ribbon, deliberately subtle in the authored daytime look.
 float sun = pow(max(0.0, sin(p.x * 0.09 + p.y * 0.04)), 8.0);
 water = mix(water, sun_color, sun * smoothstep(0.45, 0.95, ripple) * 0.07);
 // Compatibility writes sRGB directly; keep the new ocean's cyan comparable
 // to the former StandardMaterial without changing either renderer's defaults.
 if (OUTPUT_IS_SRGB) {
  water = mix(water * 12.92, 1.055 * pow(water, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), water));
 }
 ALBEDO = water;
}
