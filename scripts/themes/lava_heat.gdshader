shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength = 0.0007;
uniform float review_time = -1.0;
void fragment() {
 float edge = smoothstep(0.0,0.18,UV.x) * smoothstep(0.0,0.18,1.0-UV.x) * smoothstep(0.0,0.2,UV.y) * smoothstep(0.0,0.2,1.0-UV.y);
 float time = review_time < 0.0 ? TIME : review_time;
 vec2 wave = vec2(sin(UV.y * 25.0 - time * 1.7), cos(UV.x * 19.0 + time * 1.2));
 ALBEDO = texture(screen_texture, SCREEN_UV + wave * strength * edge).rgb;
 ALPHA = edge * 0.33;
}
