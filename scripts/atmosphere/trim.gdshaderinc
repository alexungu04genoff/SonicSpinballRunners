// UV2.x identifies outer floor rims inside the existing border mesh/pass.
uniform vec3 atmosphere_edge_adjustment = vec3(0.0, 1.0, 1.0);
uniform bool atmosphere_edge_ranges_enabled = false;

vec3 atmosphere_border_shift(vec3 color, float outer_rim) {
 if (outer_rim > 0.5) {
  return atmosphere_transform(color, atmosphere_edge_adjustment.x,
   atmosphere_edge_adjustment.y, atmosphere_edge_adjustment.z, atmosphere_edge_ranges_enabled);
 }
 return atmosphere_shift(color);
}
