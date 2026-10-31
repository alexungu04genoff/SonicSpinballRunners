shader_type spatial;
// Linear palette uniforms preserve the original shader constants.
uniform vec3 dark_color = vec3(0.12,0.25,0.55);
uniform vec3 highlight_color = vec3(0.63,0.89,0.95);
uniform vec3 vein_color = vec3(0.25,0.55,0.72);
render_mode cull_disabled;
// Opaque mineral glass avoids sorting seams and preserves broad facets in N64.
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
 float facet = clamp(dot(normalize(NORMAL), normalize(vec3(-0.5,0.7,0.6))) * 0.5 + 0.5, 0.0, 1.0);
 float vein = smoothstep(0.89, 0.97, sin(local_position.y * 15.0 + local_position.x * 7.0));
 ALBEDO = mix(dark_color, highlight_color, step(0.62,facet)*0.7+facet*0.3);
 EMISSION = ALBEDO * 0.18 + vein_color * vein * 0.12;
 ROUGHNESS = 0.28;
 SPECULAR = 0.65;
 METALLIC = 0.2;
}
