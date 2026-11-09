# Rooftop Run lighting experiment

This is an archived historical review experiment on `codex/rooftop-lighting-experiment`, based on `a77560a`. It does not replace the production theme or change the procedural generation architecture.

The follow-up [convex height-map study](HEIGHT_STUDY.md) retains the accepted lighting and compares flat, old edge-only normals, broad convex normals and parallax. Run `HeightReview.cmd` for that four-way material review.

The latest [low-poly normal study](LOWPOLY_STUDY.md) compares beveled blocks and four-facet stones against all three earlier floor styles. Run `LowPolyReview.cmd` for the normal-only review, including safe/diagnostic presets and independent mortar/detail controls.

## Review

Run `Review.cmd` on this Windows machine. Switch between the five buttons without rebuilding the level:

1. **Current:** the original environment, light and materials.
2. **Lighting only:** revised lighting with every original material retained.
3. **Normal only:** lighting pass plus a subtle floor normal map; original roughness 1.0 and specular 0.
4. **Normal + roughness:** the same normals, with floor roughness variation and restrained specular response.
5. **Material detail:** mode 4 plus small roughness/specular differences in Rooftop scenery, walls, roof tiles and ramp decking. Character, rings, flippers and gameplay-marker materials remain unchanged.

Use **Show / hide tuning controls** for live light direction/energy, ambient energy, exposure, normal strength, roughness variation, floor specular and SSAO. These changes last for the current session. Edit `settings.gd` defaults or override exported properties in `settings.tres` for persistent experiment settings, including shadow bias/range, AO radius, tonemapper, sky contribution and optional fog.

The frozen scene is a byte-for-byte copy of the existing user-authored `Third complex.tres`, chosen because it contains an elevated ramp, curved walls and scenery. No layout was authored or modified for these screenshots. The production Act file remains untouched. Retro filters are off in every variant.

## Findings

- **Main contributor: key-light direction and shadow placement.** Elevation changes from -49 to -42 degrees, azimuth from -37 to -62 degrees, energy from 0.95 to 1.05. Ramp supports, roof overhangs, arches and walls read more distinctly.
- **Ambient fill:** 0.28 with the original cool fill colour, rather than 0.32. A small sky contribution retains warm lit faces without black shadows. Full sky ambient was too blue in the trial.
- **Contact shading:** SSAO radius 0.24, intensity 0.85, direct-light contribution 0.15. Its effect is deliberately modest; compare `lighting-only.png` with `lighting-no-ao.png` to isolate it.
- **Shadows:** retain the original single orthographic directional shadow, limit distance to 24 world units, and use bias 0.22 / normal bias 2.0. Lower biases produced visible streaking and were rejected. Thin-feature shadow edges still have normal real-time shadow-map limitations.
- **Tonemapping:** the filmic trial desaturated and washed out this palette. The selected pass retains linear tonemapping and exposure 1.0; exposure remains adjustable.
- **Materials:** the normal map follows the existing cobble bevels with no new albedo noise or displacement. Strength 0.45 gives a small change, most visible in the close-up. Roughness is approximately 0.73–0.98 after blending; specular is 0.25. The material pass is less visually significant than the lighting pass at the overview camera.
- Fog remains off. The existing low-poly silhouettes, meshes, textures and palette carry the scene; this experiment does not pursue photorealism.

## Captures and verification

`captures/current.png`, `lighting-only.png` and `material-detail.png` use identical camera transforms, FOV, viewport size and geometry. `normal-only.png` and `normal-roughness.png` isolate the intermediate floor steps at that camera. The three `floor-close-*.png` images share a second, closer camera.

The runner checks mesh vertex/index arrays, mesh identities, instance transforms, MultiMesh buffers, physics-body/collision transforms, collision-shape identities, authored document fingerprint, ball identity and original Act bytes. It checks camera equality within each comparison set. `captures/validation.json` records each capture's result. Time-dependent shader effects can continue while gameplay is frozen, so the restored baseline is not guaranteed to be pixel-identical in animated effects.

Final validation: all 10 capture checks passed, the control smoke test passed, and both Godot runs completed without logged errors or warnings. The copied Act's SHA-256 matches the original. No tracked production file has changed. `captures/comparison.png` and `captures/floor-comparison.png` arrange the unretouched captures with labels; `compose_captures.py` regenerates those sheets.

Regenerate screenshots with Godot 4.7.2:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://experiments/rooftop_lighting/review.gd -- --capture-review
```

Use `--control-smoke` instead of `--capture-review` to exercise mode buttons, sliders and the AO checkbox, then save a UI screenshot. `bake_maps.py` reproducibly creates the two experiment-only maps from the original cobble recipe using NumPy and Pillow. Both textures use mipmaps.

## Performance limits

Verified on Godot 4.7.2 Compatibility through ANGLE, RTX 4060. GPU timer queries returned zero/unavailable in this configuration; `validation.json` records null, not an invented zero-cost measurement. No Android hardware was profiled.

- The changed direction, ambient level and exposure are inexpensive tuning changes. The shadow light already existed; the experiment adds no lights or shadow cascades.
- SSAO is an extra screen-space pass and the first optional effect to disable on slower Android devices. In current Godot, Compatibility supports SSAO, but the renderer named Mobile does not. See [renderer support](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).
- The floor maps add two texture samples and texture memory. Smaller maps or a packed channel could be evaluated if adopting this pass; no additional geometry is required.
- Shadow resolution, filtering and extra cascades can cost substantially more than the material tweaks. This pass does not add PCSS, reflection probes, SSR, GI or volumetric fog. See [Godot lighting and shadows](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html).

Review visual preference and in-motion shadow quality before promoting anything into the production theme. Nothing has been committed or pushed.
