shader_type canvas_item;
render_mode unshaded;
uniform bool border = false;
uniform bool raised = false;
float hash(vec2 p) { return fract(sin(dot(mod(p, vec2(16.0)), vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
 vec2 p = UV * (border ? vec2(4.0, 1.0) : vec2(16.0));
 if (!border) p.x += mod(floor(p.y), 2.0) * 0.5;
 vec2 cell = floor(p);
 float tint = hash(cell);
 vec2 q = abs(fract(p) - 0.5);
 // Rounded stone corners and shallow bevels remain readable at play distance.
 vec2 corner = max(q - vec2(0.35, 0.31), vec2(0.0));
 float distance = length(corner) - 0.12;
 float mortar = smoothstep(-0.015, 0.012, distance);
 float bevel = 1.0 - smoothstep(-0.07, -0.005, distance);
 vec3 low = border ? (raised ? vec3(0.65, 0.52, 0.34) : vec3(0.43, 0.40, 0.32)) : vec3(0.39, 0.38, 0.33);
 vec3 high = border ? (raised ? vec3(0.88, 0.77, 0.56) : vec3(0.66, 0.61, 0.49)) : vec3(0.56, 0.53, 0.45);
 vec3 stone = mix(low, high, 0.25 + tint * 0.65) * (0.86 + bevel * 0.14);
 float grain = sin(p.x * 90.0) * sin(p.y * 70.0) * 0.008;
 vec3 grout = border ? vec3(0.29, 0.25, 0.18) : vec3(0.28, 0.27, 0.23);
 COLOR = vec4(mix(stone + grain, grout, mortar), 1.0);
}
