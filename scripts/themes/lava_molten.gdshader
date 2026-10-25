shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Broad advected crust islands keep their silhouette at the retro resolution.
uniform vec2 pattern_scale = vec2(1.0);
uniform vec2 flow = vec2(0.035, -0.018);
uniform float radiance = 1.15;
uniform float phase = 0.0;
uniform float review_time = -1.0;
uniform bool lake_edges = false;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
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
 float hot = 1.0 - smoothstep(0.012, 0.105 + fwidth(field), ridge);
 float core = 1.0 - smoothstep(0.008, 0.028 + fwidth(field), ridge);
 float crust = smoothstep(0.55, 0.64, field);
 vec3 melt = mix(vec3(0.42, 0.034, 0.016), vec3(1.0, 0.43, 0.025), hot);
 melt = mix(melt, vec3(1.0, 0.85, 0.26), core * 0.8);
 melt = mix(melt, vec3(0.10, 0.032, 0.035), crust * 0.94);
 melt *= 0.88 + 0.12 * noise(p * 9.0 + time * flow);
 // Long-Zone overviews reduce subpixel glow contrast instead of showing a
 // dense orange wire pattern. Close lava retains the complete flowing surface.
 float distant = smoothstep(0.035,0.11,length(fwidth(p)));
 melt = mix(melt,vec3(0.16,0.035,0.025),distant * 0.82);
 float rim = lake_edges ? 1.0-smoothstep(0.34,0.49,max(abs(UV.x-0.5),abs(UV.y-0.5))) : 1.0;
 melt *= rim;
 ALBEDO = melt * 0.3;
 EMISSION = melt * radiance * (0.95 + 0.05 * sin(time * 0.7 + field * 13.0));
 ROUGHNESS = 0.88;
}
