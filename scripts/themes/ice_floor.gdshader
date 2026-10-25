shader_type spatial;
// Broad wind-packed snow banks over opaque, reflective glacier ice. No noise texture.
uniform bool raised_surface = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_position.xz;
 float drift = sin(p.x * 1.8 + sin(p.y * 1.1) * 1.8) + sin(p.y * 2.2 - p.x * 0.65) * 0.45;
 float snow = smoothstep(raised_surface ? -1.25 : -0.45, raised_surface ? -0.6 : 0.20, drift);
 float ridge = 0.5 + 0.5 * sin(p.y * 5.0 + sin(p.x * 2.0));
 vec3 packed = mix(vec3(0.70, 0.73, 0.77), vec3(0.86, 0.88, 0.90), ridge * 0.18 + 0.55);
 vec3 ice = mix(vec3(0.28, 0.46, 0.58), vec3(0.42, 0.65, 0.73), ridge);
 // Sparse branching seams remain broad enough for the N64 world resolution.
 float crack = abs(sin(p.x * 2.8 + p.y * 1.9 + sin(p.y * 2.5) * 0.38));
 ice += vec3(0.11, 0.17, 0.18) * (1.0 - smoothstep(0.018, 0.055 + fwidth(crack), crack));
 ALBEDO = pow(mix(ice, packed, snow), vec3(2.2));
 ROUGHNESS = mix(0.16 + ridge * 0.06, 0.94, snow);
 SPECULAR = mix(0.85, 0.18, snow);
 METALLIC = 0.04 * (1.0 - snow);
 float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
 EMISSION = vec3(0.04, 0.12, 0.15) * (1.0 - snow) * (0.04 + fresnel * 0.15);
}
