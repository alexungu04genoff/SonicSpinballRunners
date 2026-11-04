shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// 0: upper floor; 1: contour trim; 2: full-width ramp; 3: ramp guard.
uniform int mapping = 0;
uniform vec2 repeat_size = vec2(1.5);
varying vec3 world_position;
varying vec2 guard_uv;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 int corner = VERTEX_ID % 6;
 float across = (corner == 2 || corner == 3 || corner == 5) ? 1.0 : 0.0;
 guard_uv = vec2(UV.y / repeat_size.x, 1.0 - across);
}
void fragment() {
 vec2 uv = world_position.xz / repeat_size;
 if (mapping == 1) uv = vec2(UV.x / repeat_size.x, UV.y);
 if (mapping == 2) uv = vec2(UV2.x, UV.y / repeat_size.y);
 if (mapping == 3) uv = guard_uv;
 vec2 dx = dFdx(uv), dy = dFdy(uv);
 vec2 wrapped = fract(uv);
 if (mapping == 1 || mapping == 3) wrapped.y = clamp(uv.y, 0.0, 1.0);
 if (mapping == 2) wrapped.x = clamp(uv.x, 0.0, 1.0);
 ALBEDO = textureGrad(albedo_texture, wrapped, dx, dy).rgb;
 ROUGHNESS = 0.78;
 SPECULAR = 0.25;
 METALLIC = 0.0;
}
