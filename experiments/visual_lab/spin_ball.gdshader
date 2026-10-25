shader_type spatial;
render_mode diffuse_burley;

// Directional surface blur keeps the rolled silhouette solid at every frame.
uniform vec4 fur_color : source_color = vec4(0.025, 0.20, 0.80, 1.0);
uniform int character_style = 0; // Sonic, Tails, Knuckles, Shadow.
uniform float blur_amount : hint_range(0.0, 1.0) = 0.9;
varying vec3 sphere_position;

void vertex() {
 sphere_position = VERTEX;
}

// Elliptical painted forms describe a tucked crouch on the spherical shell.
float form(vec3 direction, vec3 center, vec3 scale) {
 return 1.0 - smoothstep(0.65, 1.0, length((direction - normalize(center)) / scale));
}

vec3 curled_colors(vec3 d) {
 float angle = atan(d.z, d.y);
 float fur = sin(angle * 5.0 + d.x * 8.0) * 0.12;
 vec3 color = fur_color.rgb * (0.88 + fur);
 // Folded head sits above the knees; the dark crease separates face and body.
 float fold = form(d, vec3(0.0, 0.03, 1.0), vec3(0.63, 0.14, 0.35));
 color *= 1.0 - fold * 0.45;
 float muzzle = form(d, vec3(0.0, 0.28, 1.0), vec3(0.32, 0.15, 0.30));
 vec3 cream = character_style == 1 ? vec3(0.80, 0.69, 0.43) : vec3(0.60, 0.34, 0.16);
 color = mix(color, cream, muzzle);
 for (int side = -1; side <= 1; side += 2) {
  float x = float(side);
  // Forearms tuck inward, with small fists above the large shoe toes.
  float arm = form(d, vec3(x * 0.59, 0.04, 0.9), vec3(0.14, 0.26, 0.32));
  color = mix(color, character_style == 0 ? cream : fur_color.rgb, arm);
  float glove = form(d, vec3(x * 0.33, -0.15, 1.0), vec3(0.19, 0.15, 0.24));
  color = mix(color, vec3(0.72, 0.69, 0.59), glove);
  float shoe = form(d, vec3(x * 0.47, -0.64, 0.85), vec3(0.40, 0.40, 0.48));
  vec3 shoe_color = character_style == 2 ? vec3(0.73, 0.43, 0.045) : vec3(0.92, 0.018, 0.025);
  color = mix(color, shoe_color, shoe);
  // Narrow straps leave most of each shoe red; avoid a single white blob.
  float strap = shoe * (1.0 - smoothstep(0.02, 0.055, abs(d.y + 0.38)));
  vec3 strap_color = character_style == 2 ? vec3(0.045, 0.42, 0.065) : vec3(0.84, 0.78, 0.62);
  color = mix(color, strap_color, strap);
  if (character_style == 1) {
   float tail_tip = form(d, vec3(x * 0.48, -0.15, -1.0), vec3(0.24, 0.40, 0.35));
   color = mix(color, vec3(0.86, 0.74, 0.48), tail_tip);
  }
  if (character_style == 3) {
   float stripe = form(d, vec3(x * 0.52, 0.55, -0.55), vec3(0.14, 0.62, 0.65));
   color = mix(color, vec3(0.72, 0.012, 0.025), stripe);
   float cuff = glove * smoothstep(0.30, 0.45, abs(d.x));
   color = mix(color, vec3(0.80, 0.47, 0.035), cuff);
  }
 }
 return color;
}

void fragment() {
 vec3 direction = normalize(sphere_position);
 vec3 color = vec3(0.0);
 float weight_sum = 0.0;
 // Sample around the local roll axis: a soft exposure smear, not transparency.
 for (int i = -5; i <= 5; i++) {
  float offset = float(i) * 0.15 * blur_amount;
  float weight = 1.0 - abs(float(i)) / 7.0;
  vec3 sample_direction = vec3(direction.x,
   direction.y * cos(offset) - direction.z * sin(offset),
   direction.y * sin(offset) + direction.z * cos(offset));
  color += curled_colors(sample_direction) * weight;
  weight_sum += weight;
 }
 // Retain some pose definition beneath the directional exposure smear.
 ALBEDO = mix(curled_colors(direction), color / weight_sum, 0.82);
 ROUGHNESS = 0.58;
 SPECULAR = 0.32;
}
