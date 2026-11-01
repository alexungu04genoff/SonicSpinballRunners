// Explicit terrain opt-in. Emission/readability accents retain their colors.
uniform float atmosphere_hue = 0.0;
uniform float atmosphere_saturation = 1.0;
vec3 atmosphere_shift(vec3 c) {
 if (atmosphere_hue == 0.0 && atmosphere_saturation == 1.0) return c;
 vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
 vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
 vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
 float d = q.x - min(q.w, q.y);
 vec3 hsv = vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 0.0000001)), d / (q.x + 0.0000001), q.x);
 hsv.x = fract(hsv.x + atmosphere_hue);
 hsv.y = clamp(hsv.y * atmosphere_saturation, 0.0, 1.0);
 vec3 rgb = clamp(abs(fract(hsv.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
 return hsv.z * mix(vec3(1.0), rgb, hsv.y);
}
