float contact_band(float field, float threshold, int levels) {
 if (levels < 2) { return field; }
 float last = float(levels - 1);
 return min(last, floor(field * last) + step(threshold, fract(field * last))) / last;
}
