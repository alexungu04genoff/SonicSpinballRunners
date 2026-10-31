shader_type sky;
// Linear palette uniforms preserve the original shader constants.
uniform vec3 horizon_color = vec3(0.22, 0.14, 0.31);
uniform vec3 upper_color = vec3(0.022, 0.045, 0.12);
uniform vec3 glow_color = vec3(0.06, 0.14, 0.17);
uniform vec3 star_color = vec3(0.45, 0.60, 0.72);
// Static radiance lets the ice reflect a cold sky without updating a cubemap each frame.
uniform float star_intensity = 1.0;
void sky() {
 float h = max(EYEDIR.y, 0.0);
 COLOR = mix(horizon_color, upper_color, smoothstep(0.0, 0.65, h));
 COLOR += glow_color * exp(-pow((h - 0.12) * 9.0, 2.0));
 vec2 p = SKY_COORDS * vec2(360.0, 180.0);
 vec2 cell = floor(p);
 float seed = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
 float star = (1.0 - smoothstep(0.015, 0.09, length(fract(p) - 0.5))) * step(0.987, seed);
 COLOR += star_color * star_intensity * star * smoothstep(0.04, 0.4, h);
}
