# Ice Cap selected materials

Current production materials, approved through the remaining phases on 2026-11-09: 1A, 2B, 3A, 5A, 6A, 7B, 9A, 11A, 12B. 10C retains `scripts/themes/ice_crystal.gdshader`. Alex subsequently replaced role 8 with the existing matte snow material on ramp guard caps, inner faces and outer fascia. 8A files remain historical and are no longer bound.

Source: `experiments/ice_texture_refined/response.gdshader` and `response_bake.gd`, following Alex's requests to soften and narrow the diamond trim, enrich the ice, add lightweight ice reflections, and brighten the ramp. 11A remains the approved Phase 2 PNG.

The lower floor uses a denser 7 × 7 placement cycle. Alex's final small density correction tightens its production repeat from 8 × 8 to 7.2 × 7.2 world units, preserving the existing artwork and snow/ice coverage while making the pattern 10% smaller. Albedo and response use the same mapping. Upper snow keeps its established 8 × 8 world-unit repeat.

`ID.png` is approved color artwork. `ID-response.png` is linear material data: R roughness, G specular, B exposed-ice coverage. The response is generated from material boundaries, not image brightness. Snow stays matte; ice uses the existing sky reflections. These are opaque dielectric surfaces. Foliage 11A uses constant matte response.

`ID-normal.png` contains OpenGL tangent-space normals. `ID-height.png` is the structural source reference only; it is never bound at runtime. `experiments/ice_texture_refined/detail_bake.gd` exports both from `structure.gdshaderinc`, reusing the approved generator's snow, crystal, cut-block and bough shapes. Color brightness does not drive relief. Snow lips, crystal facets and cut-ice bevels stay broad and restrained. No parallax, displacement, AO, metallic or new emission maps are added.

All maps share the same world, contour, route-strip or foliage coordinates. The existing derivative-based normal helper handles curved, scaled and tangentless meshes. Per-role normal strengths live in `ice_selected_materials.gd`; Visual Lab's Ice Cap F8 panel exposes only material detail and a normal-strength multiplier. These controls reach private, batched and baked materials. Production uses the authored defaults.

Bindings live in `scripts/themes/ice_cap_theme.gd`, `ice_selected_materials.gd`, `ice_selected.gdshader`, `ice_lake.gdshader` and `scripts/decor/ice_cap_decor.gd`. Geometry, approved lighting and camera remain unchanged.

The normal launcher, source previews and disk-baked Prototype/Endless variants all use this set. Original Phase 2 artwork and receipts remain historical in the experiment directory. Reflection uses the existing environment; it does not add scene capture probes or screen-space reflections.
