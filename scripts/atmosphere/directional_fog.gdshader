shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float fog_angle = 0.0;
uniform float fog_start = 0.0;
uniform float fog_length = 600.0;
uniform float fog_density = 0.65;
uniform float fog_curve = 1.5;
uniform vec4 fog_color : source_color = vec4(0.7, 0.8, 0.9, 1.0);
uniform float fog_brightness = 1.0;

void vertex() {
 POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
 float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
 // Leave empty sky and transparent foreground gaps untouched. Each streamed
 // background viewport applies its own fog to its own scenery depth.
 if (depth < 0.000001) { discard; }
 vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 ndc.z = depth * 2.0 - 1.0;
 #endif
 vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
 vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
 // Center ray intersects the table at y=0. This is independent of camera
 // distance, supports orthographic views, and follows the visible play area.
 vec3 eye = INV_VIEW_MATRIX[3].xyz;
 vec3 forward = -INV_VIEW_MATRIX[2].xyz;
 vec3 origin = eye + forward * (-eye.y / min(forward.y, -0.0001));
 float angle = radians(fog_angle);
 vec2 direction = vec2(sin(angle), -cos(angle));
 float distance_px = dot(world.xz - origin.xz, direction) * 100.0;
 float progress = clamp((distance_px - fog_start) / max(fog_length, 1.0), 0.0, 1.0);
 ALBEDO = fog_color.rgb * fog_brightness;
 ALPHA = clamp(fog_density * pow(progress, max(fog_curve, 0.01)), 0.0, 1.0);
}
