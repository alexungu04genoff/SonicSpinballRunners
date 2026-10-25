shader_type spatial;
render_mode unshaded, fog_disabled;
varying vec3 cloud_normal;
void vertex() { cloud_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
 // Analytic sky bounce avoids hard gray lobes and blown-out sun-facing facets.
 float light = smoothstep(-0.8, 0.9, dot(normalize(cloud_normal), normalize(vec3(-0.3, 1.0, 0.2))));
 ALBEDO = mix(vec3(0.52, 0.69, 0.79), vec3(0.86, 0.92, 0.95), light);
}
