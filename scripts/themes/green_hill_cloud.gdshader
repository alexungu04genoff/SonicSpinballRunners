shader_type spatial;
render_mode unshaded;
// Equal authored colors preserve the former flat cloud material. Variants can
// separate troughs and highlights without making the puffs physically lit.
uniform vec3 shadow_color = vec3(0.913099, 1.0, 1.0);
uniform vec3 highlight_color = vec3(0.913099, 1.0, 1.0);
uniform vec3 fake_light_direction = vec3(-0.3, 1.0, 0.2);
varying vec3 cloud_normal;
void vertex() { cloud_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
 float light = smoothstep(-0.8, 0.9, dot(normalize(cloud_normal), normalize(fake_light_direction)));
 vec3 cloud = mix(shadow_color, highlight_color, light);
 if (OUTPUT_IS_SRGB) {
  cloud = mix(cloud * 12.92, 1.055 * pow(cloud, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), cloud));
 }
 ALBEDO = cloud;
}
