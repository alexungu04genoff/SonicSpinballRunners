shader_type spatial;
render_mode diffuse_burley;
uniform vec4 paint : source_color = vec4(0.1, 0.3, 0.8, 1.0);
uniform float metal = 0.0;
void fragment() {
 // Fine moulded stipple remains neutral so every surface can be recoloured.
 vec2 cell = fract(UV * 64.0) - 0.5;
 float grain = smoothstep(0.12, 0.32, length(cell));
 float detail = 1.0 - smoothstep(0.15, 0.65, max(fwidth(UV.x), fwidth(UV.y)) * 64.0);
 grain = mix(0.75, grain, detail);
 ALBEDO = paint.rgb * mix(0.94, 1.0, grain);
 ROUGHNESS = mix(0.32, 0.4, grain);
 METALLIC = metal;
}
