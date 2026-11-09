# Low-poly Rooftop floor comparison

This uncommitted experiment retains the accepted lighting, original albedo, flat floor mesh, scene geometry and collisions. Runtime shading is normal-map-only. No parallax, displacement, extra surface geometry, specular response or roughness variation is added to the comparison.

## Review

Run `LowPolyReview.cmd`. The five buttons select flat, original edge-only normals, the previous smooth convex normal, beveled blocks and faceted stones. The first three retain their original values (flat, edge strength 0.45, smooth convex strength 1.0). The two new variants have both **Gameplay-safe strength** and **Diagnostic strength** presets.

The initial view restores the actual camera state from the loaded game before the earlier review harness changed it. **Gameplay camera / close-up** switches between that view and the same floor inspection camera used in the previous study. Camera, lighting, source colour texture and material roughness match within every comparison set.

The scene is frozen for an art comparison. “Gameplay-safe” names a conservative visual candidate, not a substitute for judging readability and shimmering during actual play.

## Profiles and controls

**Beveled block:** a flat top surrounded by straight bevel planes and angular corner chamfers. Mortar stays lowest. A narrow outer rise and a wider bevel provide separate mortar and bevel controls; neither rounds the top into a dome.

**Faceted stone:** four triangular, constant-slope top regions meet at a shallow central peak, inside a beveled rim. The planes are continuous in height but change normal at their shared ridges. Variation changes each stone's relief amplitude slightly, not its pixel noise or colour.

| Live control | Gameplay-safe | Diagnostic | Effect |
| --- | ---: | ---: | --- |
| Normal strength | 0.55 | 1.0 | Scales the complete normal response. Zero restores flat shading. |
| Mortar depth | 0.65 | 1.0 | Scales the narrow rise out of the recessed gaps. |
| Bevel / facet intensity | 0.65 | 1.0 | Scales the broad bevel or four planar faces independently. |
| Per-stone variation | 0.15 | 0.25 | Scales a stable, per-stone amplitude offset; zero makes relief amplitude uniform. |

Variation 0.15 permits approximately ±5.25% detail-height variation; it does not add high-frequency noise. Live settings last for the session. Persistent defaults are exported in `settings.gd` and can be overridden in `settings.tres`. The earlier review launchers remain available.

## Generated assets

`bake_lowpoly_maps.py` uses the existing cobble PNG's stone mask and staggered layout. Height fields are piecewise planar. Normals are derived from their unquantized slopes, with OpenGL +Y pointing up the image. The original colour variation and grain are not interpreted as height and remain unchanged.

For each style (`block`, `faceted`) and preset (`gameplay`, `diagnostic`), the experiment includes:

- `{style}_{preset}_height.png`: grayscale height preview.
- `{style}_{preset}_normal_gl.png`: combined OpenGL normal map.

The height preview's white level is 0.033 world units for block and 0.055 for faceted. Both presets of a style share that scale, so lower-strength previews correctly look darker. They are debug height images, not runtime displacement textures.

The live shader combines `lowpoly_mortar_normal.png` with the appropriate `lowpoly_*_basis.png`. The basis texture's alpha channel stores one variation value per stone. This permits independent controls using two pre-baked normal lookups; no height map is sampled at runtime. Both variants have the same shader cost: two normal-related lookups plus the original albedo lookup. A chosen fixed preset could use its combined normal map to reduce this to one normal lookup. The textures use mipmaps and lossless import settings; no Android performance claim is made.

## Visual evaluation

| Variant | Gameplay-distance reading | Style and readability |
| --- | --- | --- |
| Flat | Clearest but least depth | Baseline for ball/interactable separation. |
| Existing edge-only | Very restrained | Clean, but still soft around the edges. |
| Existing smooth convex | Broad light gradients | Looks rounder and softer than the surrounding geometry. |
| Beveled block, safe | Quiet outlines and flat tops | Best overall fit for Rooftop masonry; adds depth without competing strongly with the ball. |
| Faceted stone, safe | Visible but restrained triangular faces | Strong low-poly character; busier than block, but still readable in these static views. |
| New variants, diagnostic | Clearly reveals bevels and four-face structure | Block develops heavy dark edges; facets become conspicuous repeated pyramids. Useful for diagnosis, too strong as a default. |

Recommended direction from these captures: **beveled block at gameplay-safe strength** for the main floor. The faceted option is a useful alternative if stronger planar styling is preferred, with conservative facet intensity. The blue ball, yellow gates and coloured bumpers remain distinct in the captured views; motion, camera movement and gameplay feel still need user review.

## Captures and checks

`captures/lowpoly-study/` contains:

- `gameplay-comparison-safe.png` and `close-comparison-safe.png`: all five variants, new materials at safe strength.
- `gameplay-comparison-diagnostic.png` and `close-comparison-diagnostic.png`: the same references with the two new materials exaggerated.
- `gameplay-strengths.png` and `close-strengths.png`: new block/faceted styles at both strengths.
- `block-maps.png` and `faceted-maps.png`: labelled height/normal assets at diagnostic strength.
- Individual full-resolution captures, controls screenshot and JSON validation results.

Executed checks:

- Map generation checks passed for flat block centres, constant-slope facet interiors, unit normals and zero-height mortar outside the stone mask.
- All 16 capture checks passed for unchanged meshes/instances, physics/collision transforms and fixed camera transforms; Act bytes/fingerprint and ball identity also remained unchanged.
- Camera projection, FOV/orthographic size and lighting match across each comparison set.
- Zero normal strength matches the flat floor within 0.00039 mean RGB levels in an unobstructed floor patch.
- The sampled opaque ball interior is pixel-identical across the five gameplay captures. Antialiased boundary pixels are excluded because they blend with the changed floor.
- The live-control smoke test passed mode switching, both presets, camera switching and all four sliders.

To reproduce: run `bake_lowpoly_maps.py`, import the project, then run `lowpoly_review.gd` with `-- --capture-lowpoly`. Run `compare_lowpoly_captures.py` to validate and compose the screenshots. Use `-- --lowpoly-controls-smoke` to exercise the controls.

No production file, mesh, source texture or procedural generator was changed. Nothing has been committed or pushed.
