shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D height_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 repeat_size = vec2(4.0);
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool parallax_enabled = false;
uniform float height_strength : hint_range(0.0, 0.08, 0.001) = 0.04;
uniform int parallax_steps : hint_range(4, 24) = 12;
varying vec3 world_position;

void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 parallax_uv(vec2 uv, vec3 to_camera, vec2 gradient_x, vec2 gradient_y) {
 // Virtual relief recedes from the existing plane. Never move actual vertices,
 // fragment depth, collision geometry, silhouettes or real shadow geometry.
 float grazing_fade = smoothstep(0.08, 0.3, to_camera.y);
 vec2 full_offset = to_camera.xz / max(to_camera.y, 0.2) * height_strength * grazing_fade / repeat_size;
 float step_depth = 1.0 / float(parallax_steps);
 vec2 step_uv = full_offset * step_depth;
 vec2 at = uv;
 float ray_depth = 0.0;
 float surface_depth = 1.0 - textureGrad(height_texture, at, gradient_x, gradient_y).r;
 vec2 previous = at;
 float previous_difference = surface_depth;
 for (int i = 0; i < 24; i++) {
  if (i >= parallax_steps || ray_depth >= surface_depth) { break; }
  previous = at;
  previous_difference = surface_depth - ray_depth;
  at -= step_uv;
  ray_depth += step_depth;
  surface_depth = 1.0 - textureGrad(height_texture, at, gradient_x, gradient_y).r;
 }
 float difference = ray_depth - surface_depth;
 float blend = previous_difference / max(previous_difference + difference, 0.00001);
 return mix(previous, at, clamp(blend, 0.0, 1.0));
}

void fragment() {
 vec2 uv = world_position.xz / repeat_size;
 vec2 gradient_x = dFdx(uv);
 vec2 gradient_y = dFdy(uv);
 if (parallax_enabled && height_strength > 0.0) {
  uv = parallax_uv(uv, normalize(CAMERA_POSITION_WORLD - world_position), gradient_x, gradient_y);
 }
 ALBEDO = textureGrad(surface_texture, uv, gradient_x, gradient_y).rgb;
 vec2 xy = textureGrad(normal_texture, uv, gradient_x, gradient_y).rg * 2.0 - 1.0;
 float z = sqrt(max(1.0 - dot(xy, xy), 0.0001));
 // +U is world X. OpenGL +Y (up the image) is world -Z for this floor.
 vec3 world_normal = normalize(vec3(xy.x * normal_strength, z, -xy.y * normal_strength));
 NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
 ROUGHNESS = 1.0;
}
