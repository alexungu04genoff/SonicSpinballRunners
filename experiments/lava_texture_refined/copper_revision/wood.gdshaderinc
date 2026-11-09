// Shift the approved timber toward muted reddish-brown without changing its
// value, pattern, grain, knots or the shared mineral insets.
vec3 muted_timber(vec3 original) {
 const vec3 weights=vec3(0.2126,0.7152,0.0722);
 float value=dot(original,weights);
 vec3 timber=mix(original,vec3(value),0.42);
 vec3 tint=vec3(0.04,-0.02,0.08)*value;
 tint-=vec3(dot(tint,weights));
 return timber+tint;
}
