# Rooftop Run: whole-scene normal comparison

This is an uncommitted presentation experiment on `codex/rooftop-lighting-experiment`. It uses the same copied authored Act, frozen game state, approved lighting, camera transforms, source albedos, roughness, and specular settings for every variant. No production code, meshes, collision shapes, or procedural-generation contracts are edited.

## Live review

For the added normal-versus-retro stills and moving-camera comparison, run `RetroSceneReview.cmd` and see `RETRO_SCENE_STUDY.md`. It adds the existing saved filter stack and a repeatable camera move to the same material controls.

Run `SceneReview.cmd`. Use buttons or keys 1–4 for None, Beveled, Faceted, and Hybrid. Camera buttons select the native gameplay camera, material close-up, or intermediate overview. Expand the tuning panel for independent normal strengths; Reset restores the values below. The scene stays loaded and frozen while switching. Controls are session-local; edit `DEFAULT_STRENGTHS` in `scene_review.gd` to persist defaults.

Images in `captures/scene-study/`:

- `gameplay-comparison.png`: four variants from the native gameplay camera.
- `close-comparison.png`: matching ramp, railguard, path, and wall close-ups.
- `overview-comparison.png`: matching intermediate overview.
- `material-map-sheet.png`: existing source artwork beside both generated normals.
- Individual lossless captures use `<camera>-<variant>.png` names.
- `inventory.json`: every original material slot, visibility, assignment, or skip reason.

## Treatment and strengths

Beveled and Faceted cover the same eligible slots. Hybrid uses faceted worn path cobbles and beveled cut architectural materials. The path is the only source classified as rough/worn stone here; terracotta slabs, ramp tiles, and border coping remain cut masonry. This is an explicit art interpretation, not a color classifier.

| Material / role | Normal multiplier | Hybrid | Visible slots / total |
| --- | ---: | --- | ---: |
| Cobblestone floor/path | 1.00 | Faceted | 1 / 2 |
| Ramp deck tiles | 0.65 | Beveled | 1 / 1 |
| Wall masonry | 0.65 | Beveled | 5 / 6 |
| Exterior facade masonry | 0.55 | Beveled, windows masked | 1 / 1 |
| Terracotta wall/ledge tops | 0.85 | Beveled | 5 / 5 |
| Floor/ledge borders and ramp caps | 0.25 | Beveled | 8 / 8 |
| Ramp inner guards and outer fascia | 0.22 | Beveled | 4 / 4 |
| Stone ramp supports | 0.25 | Beveled | 8 / 8 |
| Solid architectural stone | 0.65 | Beveled | 68 / 70 |
| Solid coping, eaves, frames, trim | 0.30 | Beveled | 73 / 75 |

These are multipliers for different base profiles, not comparable physical heights. In particular, floor maps already include the previously accepted safe normal strength 0.55, mortar/detail weights 0.65, and variation 0.15. Its multiplier of 1.00 preserves that result. Hidden study objects account for several extra slots. One MultiMesh slot can cover many background instances.

## Generation and mapping

`bake_scene_maps.py` reconstructs the structural cells from the original source shader recipes: staggered cobbles, ramp tiles, terracotta slabs, and masonry courses. It does not convert brightness to height. Flat-top bevels and four-plane tops provide the two profiles. Original albedo PNGs remain byte-identical. All runtime relief comes from OpenGL normal textures responding to the existing DirectionalLight. Heights are offline debug assets only; no parallax or displacement runs.

Facade normal slopes are masked out at the authored windows/recess graphics, trim, sill, and cornice. Masking slopes instead of heights avoids inventing a raised outline around a painted motif. Flat source shadow lines do not become geometry.

The ramp retains its original route UVs. A derivative tangent frame handles its curved and sloped surface without adding mesh tangents. Ramp guard side UVs have only one useful coordinate, so a shader varying recovers the existing six-vertex strip ordering to provide the cross-strip coordinate. This changes no vertex positions or mesh arrays. Plain guard sides receive a restrained authored coping profile, repeated along the route.

Untextured stone boxes receive one profile per existing BoxMesh face, using its 3-by-2 UV atlas. These are geometry-boundary-based profiles, not recovered brick patterns. StandardMaterial3D materials are duplicated with only normal mapping enabled. Textured materials preserve their original albedo lookup, projection, filtering, roughness, and specular behavior.

All normal imports are lossless with mipmaps and anisotropic sampling where supported. They add no direct lighting to the source textures.

## Deliberate exclusions

- Signs, markings, entry arrows, gameplay objects, logos, clock faces/hands, windows, shutters, and emissive graphics: no physically justified relief in their source artwork.
- Awnings, pennants, balloons, and their painted stripes: cloth/paint is not stone.
- Smooth plaster/ochre walls and solid-color pitched roofs: no source joints or tile pattern to infer; do not fabricate a cobble grid.
- Wood benches, trunks, and baskets: no source grain or structural texture; existing modeled boards remain unchanged.
- Smooth metal rails/poles and dark background plaza: no panel seams in the source; do not apply stone shapes based on shared dark color.
- Vegetation, distant hills, water, and effects: retain their existing material response.
- Hidden ramp underside: smooth soffit without source detail.

Cream box geometry is treated as solid architectural trim only; awning and pennant ancestry is explicitly excluded. Non-box cream clock faces remain untouched. Background batching preserves mesh/material groups, allowing stone boxes to be distinguished from smooth painted surfaces without changing MultiMeshes.

## Findings and limitations

- Beveled produces a clear tile edge response on the ramp and masonry, while keeping broad tops quiet.
- Faceted gives stronger orientation cues, but repeated triangles become more apparent on walls and large solid building blocks.
- Hybrid retains planar path variation and quieter architecture. It is a comparison option, not a selected production default.
- Plain guards and untextured architectural blocks required authored structural assumptions. Their normal profiles are inferred from physical role and mesh boundaries, not recovered from existing texture artwork. Review these especially before adopting the treatment.
- Nonuniformly scaled stone boxes stretch their face profiles. This is intentionally broad stylization, not a constant-width physical bevel.
- Facade trim/windows are deliberately flat. Their existing painted shading remains in the original albedo; no new lighting is baked.
- Thin coping stays subtle at gameplay distance. Stronger values can exaggerate seams and compete with gameplay markers.

## Validation executed

Godot 4.7.2, Compatibility renderer, ANGLE on RTX 4060:

- Headless editor import completed without script/shader errors.
- Four variants captured at three fixed cameras, plus zero-strength and guard-only ablations: 14 captures.
- Geometry and collision fingerprints, authored document, ball identity, camera, projection, and lighting comparisons passed.
- Whole-image zero-strength error versus None: 0.0137 RGB levels on a 0–255 scale; minor shader/edge rasterization differences remain.
- Guard-only ablation changed 4,566 close-up pixels by more than two RGB levels, confirming side/fascia treatment is active.
- Ball interior pixels were identical across gameplay captures.
- Source albedo hashes remained unchanged.
- Live mode, camera, slider, reset, and tuning-panel controls passed a runtime smoke test.
- Capture and smoke-test logs contain no script/shader errors or warnings. Screenshots were inspected visually.

This frozen review does not test moving-camera shimmer or gameplay feel. Those still need a normal playtest before adopting a style.

## Runtime cost

All three variants use normal mapping only. Most eligible surfaces add one filtered normal lookup and tangent-frame math. Existing blended wall projections add two normal lookups. Box materials use Godot's standard normal path. There are no new draw calls, vertices, lights, shadow passes, height samples, or raymarch loops introduced by this material experiment. Mipmaps improve distance stability and add texture storage.

The reviewer caches both styles to switch instantly, so its memory use exceeds shipping a single choice. Desktop GPU timer queries returned unavailable; no Android timing or memory budget is claimed. Profile a chosen style on device before shipping, particularly full-screen walls and the existing SSAO/shadow settings.

## Reproduction

1. Run `bake_scene_maps.py` with Python, NumPy, and Pillow.
2. Import the project in Godot. The supplied experiment import settings enable mipmaps; if starting from missing imports, run the bake again after initial import, then reimport.
3. Run `scene_review.gd` with `-- --capture-scene` for captures.
4. Run `compare_scene_captures.py` for validation and labelled sheets.
5. Run `scene_review.gd` with `-- --scene-controls-smoke` for control validation.

No commit or push has been made.
