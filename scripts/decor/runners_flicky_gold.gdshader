shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D body_texture : source_color, filter_linear_mipmap;
uniform sampler2D gold_texture : source_color, filter_linear, repeat_disable;
varying vec2 reflection_uv;
varying vec3 gold_reflection;

void vertex() {
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	reflection_uv = vec2(0.5 + view_normal.x * 0.5, 0.5 - view_normal.y * 0.5);
}

void fragment() {
	vec4 body = texture(body_texture, UV);
	ALBEDO = 2.0 * body.rgb;
	gold_reflection = 2.0 * body.a * texture(gold_texture, reflection_uv).rgb;
}

void light() {
	float response = clamp(0.5 + 0.5 * dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += response * ATTENUATION * LIGHT_COLOR / PI;
	SPECULAR_LIGHT += response * ATTENUATION * gold_reflection;
}
