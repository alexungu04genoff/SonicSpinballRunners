// MIT: Lucas Rodrigues, Witty Cognomen. See LICENSE.txt and ../README.md.
// Godot 4 adaptation: read this world SubViewport, explicit sampler hints.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene_col : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D dither_tex : filter_nearest, repeat_enable;
uniform float col_depth = 32.0;

uniform float dith_range: hint_range(0,1) = 1.0;

void fragment() {
	vec2 dith_size = vec2(textureSize(dither_tex,0)); // for GLES2: substitute for the dimensions of the dithering matrix
	vec2 buf_size = vec2(textureSize(scene_col,0));

	vec4 color = texture(scene_col, SCREEN_UV);

	vec3 dith = texture(dither_tex, SCREEN_UV*(buf_size/dith_size)).rgb;
	dith -= 0.5;

	color.rgb = round(color.rgb*col_depth + (dith_range*dith)) / col_depth;

	COLOR.rgba = color.rgba;

}
