shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D skin_texture : source_color, filter_linear_mipmap;
uniform sampler2D glow_texture : source_color, hint_default_black, filter_linear_mipmap;
uniform float dissolved : hint_range(0.0,1.0);
varying vec3 model_point;

void vertex() {
    model_point = VERTEX;
    float row = floor(VERTEX.y * 45.0);
    VERTEX.x += sin(row*2.93 + dissolved*5.0)*0.008*sin(dissolved*3.14159);
}

void fragment() {
    vec2 cell = floor(vec2(UV.x*32.0, UV.y*50.0));
    float pick = fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
    float order = clamp(0.06 + .67*pick + .26*clamp(model_point.y/.74,0.0,1.0),0.0,1.0);
    if (dissolved >= order) {discard;}
    float frontier = (1.0 - smoothstep(.0,.12,order-dissolved)) * smoothstep(0.0,.08,dissolved);
    ALBEDO = mix(texture(skin_texture,UV).rgb,vec3(.62,.01,.04),frontier);
    EMISSION = texture(glow_texture,UV).rgb*.52 + vec3(1.1,.025,.085)*frontier;
    ROUGHNESS = .86;
}
