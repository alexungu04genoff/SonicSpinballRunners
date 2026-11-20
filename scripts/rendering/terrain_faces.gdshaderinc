global uniform bool authored_terrain_faces;
uniform vec2 terrain_face_bounds = vec2(0.0, 1.0);
varying vec3 terrain_face_normal;
varying float terrain_face_height;

float terrain_face_visibility() {
 if (!authored_terrain_faces) { return 1.0; }
 float up = normalize(terrain_face_normal).y;
 float cavity = (1.0 - abs(up)) * (0.34 + 0.30 * (1.0 - clamp(terrain_face_height, 0.0, 1.0)));
 return 1.0 - 0.62 * clamp(cavity + 0.75 * max(-up, 0.0), 0.0, 1.0);
}
