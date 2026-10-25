shader_type spatial;
render_mode cull_disabled;
// Opaque mineral glass avoids sorting seams and preserves broad facets in N64.
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
 float facet = clamp(dot(normalize(NORMAL), normalize(vec3(-0.5,0.7,0.6))) * 0.5 + 0.5, 0.0, 1.0);
 float vein = smoothstep(0.89, 0.97, sin(local_position.y * 15.0 + local_position.x * 7.0));
 ALBEDO = mix(vec3(0.015,0.19,0.22), vec3(0.13,0.68,0.65), facet);
 EMISSION = ALBEDO * 0.25 + vec3(0.12,0.5,0.48) * vein * 0.18;
 ROUGHNESS = 0.28;
 SPECULAR = 0.65;
 METALLIC = 0.2;
}
