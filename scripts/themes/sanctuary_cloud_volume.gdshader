shader_type spatial;
// Process-local Theme Motion candidate; zero preserves current production.
uniform int motion_candidate = 0;
uniform float time_override = -1.0;
float theme_time() { return time_override >= 0.0 ? time_override : TIME; }
// Linear palette uniforms preserve the original shader constants.
uniform vec3 shadow_color = vec3(0.52, 0.69, 0.79);
uniform vec3 highlight_color = vec3(0.86, 0.92, 0.95);
render_mode unshaded, fog_disabled;
uniform vec3 fake_light_direction = vec3(-0.3, 1.0, 0.2);
varying vec3 cloud_normal;
void vertex() {
 cloud_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
 // Finite local displacement; native instance culling includes 1.2 units.
 if (motion_candidate == 1) VERTEX.x += sin(theme_time() * 0.08 + MODEL_MATRIX[3].z * 0.006) * 1.2;
}
void fragment() {
 // Analytic sky bounce avoids hard gray lobes and blown-out sun-facing facets.
 float light = smoothstep(-0.8, 0.9, dot(normalize(cloud_normal), normalize(fake_light_direction)));
 ALBEDO = mix(shadow_color, highlight_color, light);
}
