shader_type spatial;
// Linear palette uniforms preserve the original shader constants.
uniform vec3 dark_color = vec3(0.62, 0.055, 0.016);
uniform vec3 hot_color = vec3(1.0, 0.43, 0.025);
uniform vec3 core_color = vec3(1.0, 0.85, 0.26);
uniform vec3 crust_color = vec3(0.16, 0.032, 0.035);
render_mode cull_disabled, specular_disabled;
// Broad advected crust islands keep their silhouette at the retro resolution.
uniform vec2 pattern_scale = vec2(1.0);
uniform vec2 flow = vec2(0.035, -0.018);
uniform float radiance = 1.15;
uniform float phase = 0.0;
uniform float review_time = -1.0;
uniform bool lake_edges = false;
// The sine hash amplified floating-point differences between adjacent lattice
// evaluations into rectangular seams on Forward+/Vulkan. Integer lattice hashes
// give the same corner value from either cell; interpolation/flow stay unchanged.
float hash(vec2 p) {
 uvec2 q = uvec2(ivec2(p));
 uint n = q.x * 1597334677u ^ q.y * 3812015801u;
 n = (n ^ (n >> 16u)) * 2246822519u;
 return float(n & 0x00ffffffu) / 16777215.0;
}
float noise(vec2 p) {
 vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1)), f.x), f.y);
}
void fragment() {
 float time = review_time < 0.0 ? TIME : review_time;
 vec2 p = UV * pattern_scale + time * flow + vec2(phase);
 vec2 warp = vec2(noise(p * 0.67 + time * 0.012), noise(p * 0.67 + 8.7));
 float field = noise(p + warp * 1.8) * 0.70 + noise(p * 2.1 - time * flow * 0.3) * 0.23 + noise(p * 5.0 + warp) * 0.07;
 float ridge = abs(field - 0.49);
 float hot = 1.0 - smoothstep(0.025, 0.18 + fwidth(field), ridge);
 float core = 1.0 - smoothstep(0.008, 0.028 + fwidth(field), ridge);
 float crust = smoothstep(0.55, 0.64, field);
 vec3 melt = mix(dark_color, hot_color, hot);
 melt = mix(melt, core_color, core * 0.8);
 melt = mix(melt, crust_color, crust * 0.68);
 melt *= 0.88 + 0.12 * noise(p * 9.0 + time * flow);
 // Long-Zone overviews reduce subpixel glow contrast instead of showing a
 // dense orange wire pattern. Close lava retains the complete flowing surface.
 float distant = smoothstep(0.035,0.11,length(fwidth(p)));
 melt = mix(melt,dark_color * vec3(0.258064516, 0.636363636, 1.5625),distant * 0.82);
 float rim = lake_edges ? 1.0-smoothstep(0.34,0.49,max(abs(UV.x-0.5),abs(UV.y-0.5))) : 1.0;
 melt *= rim;
 ALBEDO = melt * 0.3;
 EMISSION = melt * radiance * (0.95 + 0.05 * sin(time * 0.7 + field * 13.0));
 ROUGHNESS = 0.88;
}
