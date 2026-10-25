shader_type spatial;
render_mode diffuse_burley;

// Directional surface blur keeps the rolled silhouette solid at every frame.
uniform vec4 fur_color : source_color = vec4(0.025, 0.20, 0.80, 1.0);
varying vec3 sphere_position;

void vertex() {
 sphere_position = VERTEX;
}

float patch(vec3 direction, vec3 center, float size) {
 return 1.0 - smoothstep(size * 0.55, size, distance(direction, normalize(center)));
}

vec3 curled_colors(vec3 direction) {
 float angle = atan(direction.z, direction.y);
 // Broad swept fur bands, not thin neon rings or individual protruding quills.
 float fur = sin(angle * 5.0 + direction.x * 8.0) * 0.07;
 vec3 color = fur_color.rgb * (0.85 + fur);
 float muzzle = patch(direction, vec3(0.0, 0.42, 1.0), 0.48);
 color = mix(color, vec3(0.70, 0.49, 0.29), muzzle * 0.85);
 float gloves = max(patch(direction, vec3(-0.32, 0.05, 1.0), 0.25),
                    patch(direction, vec3(0.32, 0.05, 1.0), 0.25));
 float shoes = max(patch(direction, vec3(-0.35, -0.60, 0.85), 0.31),
                   patch(direction, vec3(0.35, -0.60, 0.85), 0.31));
 color = mix(color, vec3(0.72, 0.025, 0.035), shoes);
 float straps = shoes * (1.0 - smoothstep(0.035, 0.10, abs(direction.y + 0.49)));
 return mix(color, vec3(0.86, 0.86, 0.78), max(gloves, straps));
}

void fragment() {
 vec3 direction = normalize(sphere_position);
 vec3 color = vec3(0.0);
 float weight_sum = 0.0;
 // Sample around the local roll axis: a soft exposure smear, not transparency.
 for (int i = -5; i <= 5; i++) {
  float offset = float(i) * 0.12;
  float weight = 1.0 - abs(float(i)) / 7.0;
  vec3 sample_direction = vec3(direction.x,
   direction.y * cos(offset) - direction.z * sin(offset),
   direction.y * sin(offset) + direction.z * cos(offset));
  color += curled_colors(sample_direction) * weight;
  weight_sum += weight;
 }
 ALBEDO = color / weight_sum;
 ROUGHNESS = 0.58;
 SPECULAR = 0.32;
}
