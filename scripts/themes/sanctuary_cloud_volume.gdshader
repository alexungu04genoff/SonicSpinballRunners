shader_type spatial;
// Linear palette uniforms preserve the original shader constants.
uniform vec3 shadow_color = vec3(0.52, 0.69, 0.79);
uniform vec3 highlight_color = vec3(0.86, 0.92, 0.95);
render_mode unshaded, fog_disabled;
uniform vec3 fake_light_direction = vec3(-0.3, 1.0, 0.2);
varying vec3 cloud_normal;
void vertex() { cloud_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
 // Analytic sky bounce avoids hard gray lobes and blown-out sun-facing facets.
 float light = smoothstep(-0.8, 0.9, dot(normalize(cloud_normal), normalize(fake_light_direction)));
 ALBEDO = mix(shadow_color, highlight_color, light);
}
