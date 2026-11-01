// Only explicitly bound terrain, decor and scenery materials use this layer.
uniform float atmosphere_hue = 0.0;
uniform float atmosphere_saturation = 1.0;
uniform float atmosphere_brightness = 1.0;
uniform float atmosphere_emission_hue = 0.0;
uniform float atmosphere_emission_saturation = 1.0;
uniform float atmosphere_emission_brightness = 1.0;
uniform bool atmosphere_emission_ranges_enabled = false;
uniform bool atmosphere_ranges_enabled = false;
// Hue offset, saturation multiplier, brightness multiplier.
uniform vec3 atmosphere_range_red = vec3(0.0, 1.0, 1.0);
uniform vec3 atmosphere_range_orange = vec3(0.0, 1.0, 1.0);
uniform vec3 atmosphere_range_yellow = vec3(0.0, 1.0, 1.0);
uniform vec3 atmosphere_range_green = vec3(0.0, 1.0, 1.0);
uniform vec3 atmosphere_range_aqua = vec3(0.0, 1.0, 1.0);
uniform vec3 atmosphere_range_blue = vec3(0.0, 1.0, 1.0);
uniform vec3 atmosphere_range_purple = vec3(0.0, 1.0, 1.0);
uniform vec3 atmosphere_range_magenta = vec3(0.0, 1.0, 1.0);

vec3 atmosphere_range_settings(float h) {
 if (h < 1.0 / 12.0) return mix(atmosphere_range_red, atmosphere_range_orange, smoothstep(0.0, 1.0 / 12.0, h));
 if (h < 1.0 / 6.0) return mix(atmosphere_range_orange, atmosphere_range_yellow, smoothstep(1.0 / 12.0, 1.0 / 6.0, h));
 if (h < 1.0 / 3.0) return mix(atmosphere_range_yellow, atmosphere_range_green, smoothstep(1.0 / 6.0, 1.0 / 3.0, h));
 if (h < 0.5) return mix(atmosphere_range_green, atmosphere_range_aqua, smoothstep(1.0 / 3.0, 0.5, h));
 if (h < 2.0 / 3.0) return mix(atmosphere_range_aqua, atmosphere_range_blue, smoothstep(0.5, 2.0 / 3.0, h));
 if (h < 0.75) return mix(atmosphere_range_blue, atmosphere_range_purple, smoothstep(2.0 / 3.0, 0.75, h));
 if (h < 5.0 / 6.0) return mix(atmosphere_range_purple, atmosphere_range_magenta, smoothstep(0.75, 5.0 / 6.0, h));
 return mix(atmosphere_range_magenta, atmosphere_range_red, smoothstep(5.0 / 6.0, 1.0, h));
}

vec3 atmosphere_transform(vec3 c, float hue, float saturation, float brightness, bool ranges) {
 if (hue == 0.0 && saturation == 1.0 && !ranges) return c * brightness;
 vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
 vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
 vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
 float d = q.x - min(q.w, q.y);
 vec3 hsv = vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 0.0000001)), d / (q.x + 0.0000001), q.x);
 hsv.x = fract(hsv.x + hue);
 hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
 hsv.z *= brightness;
 if (ranges) {
  vec3 settings = mix(vec3(0.0, 1.0, 1.0), atmosphere_range_settings(hsv.x), smoothstep(0.03, 0.12, hsv.y));
  hsv.x = fract(hsv.x + settings.x);
  hsv.y = clamp(hsv.y * settings.y, 0.0, 1.0);
  hsv.z *= settings.z;
 }
 vec3 rgb = clamp(abs(fract(hsv.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
 return hsv.z * mix(vec3(1.0), rgb, hsv.y);
}
vec3 atmosphere_shift(vec3 c) {
 return atmosphere_transform(c, atmosphere_hue, atmosphere_saturation, atmosphere_brightness, atmosphere_ranges_enabled);
}
vec3 atmosphere_emission_shift(vec3 c) {
 return atmosphere_transform(c, atmosphere_emission_hue, atmosphere_emission_saturation, atmosphere_emission_brightness, atmosphere_emission_ranges_enabled);
}
