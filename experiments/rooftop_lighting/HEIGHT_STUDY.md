# Convex cobblestone diagnostic

The accepted Rooftop lighting direction is unchanged. This follow-up changes only the floor's shading, in the same isolated, uncommitted experiment. The scene, floor mesh, collisions, source albedo, and production theme remain unchanged.

## Review

Run `HeightReview.cmd`. Four buttons compare:

1. Existing flat floor.
2. The previous edge-only normal map, at its original strength of 0.45.
3. The new convex-stone normal, at deliberately exaggerated diagnostic strength 1.0.
4. The same convex normal plus parallax, at diagnostic virtual depth 0.04 world units.

Every variant uses the accepted key light, fill, SSAO and exposure. Roughness remains 1.0 and specular remains zero for the material comparison. No additional scenery-material response is mixed into this test. The window starts at the floor close-up; use **Overview / floor close-up** to switch cameras, and **Show / hide tuning controls** to adjust settings.

The important tunables are:

| Control | Default | Purpose |
| --- | ---: | --- |
| `old_edge_strength` | 0.45 | Previous normal map only; preserves its original comparison value. |
| `convex_normal_strength` | 1.0 | Broad light variation across the new stones; zero gives flat shading. |
| `height_strength` | 0.04 | Parallax's apparent depth, in world units; affects only mode 4. Zero matches mode 3. |
| `parallax_steps` | 12 | Parallax ray-search quality, adjustable from 4 to 24. |

Live adjustments are session-only. Set persistent values in `settings.tres` or the defaults in `settings.gd`. Normal strength and parallax depth are intentionally independent diagnostic controls. The height-to-normal bake uses a 0.05-world-unit peak relief across a 4-world-unit repeating texture; change `BAKE_RELIEF_WORLD` in `bake_convex_maps.py` only if rebaking is desired. Neither value displaces the mesh.

## How the maps were generated

`bake_convex_maps.py` reads the existing `assets/textures/rooftop_run/floor.png`. It extracts the stone silhouettes from the pixels, using the known 16-row stagger to locate their centres. It does **not** interpret brighter stone colours or the original colour grain as height.

Each silhouette receives a smooth broad dome. The mortar stays nearly black, the shoulders rise gradually, and the centres approach white. The diagnostic height image is saved as `floor_height.png`, then read back to derive `floor_convex_normal_gl.png`. A small filter suppresses grayscale quantization steps. No high-frequency surface noise is added.

The normal is OpenGL +X/+Y/+Z: green points up the image. Because this floor's UVs use world X/Z, the shader explicitly maps image-up to world -Z. It reconstructs the normal's blue component from RG and requires no tangent changes to the mesh. The old edge-only map and its existing decoding are preserved for an honest comparison. [Godot normal-map convention](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html#normal-map)

## Results and limits

The new normal produces clearly visible broad lighting gradients across the stone faces. It adds substantially more readable shape than rounding only the perimeter. This deliberately strong setting is for diagnosis, not a proposed final production strength.

Parallax works in the current Godot 4.7.2 Compatibility/ANGLE renderer. It shifts both albedo and normal UVs using the height map, adding apparent depth and view-dependent occlusion. At the exaggerated depth, some mortar edges distort or show search-step artifacts; the broad normal response supplies most of the useful effect. Increasing steps can reduce search artifacts but adds cost. The shader fades the effect at grazing angles to limit extreme UV stretching.

Parallax does not move vertices or fragment depth, and does not create physical stone silhouettes, collisions or matching raised-stone cast shadows. Existing props and real shadows still meet the actual flat plane. These limitations are particularly visible with exaggerated depth. [Godot height-mapping overview](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html#height)

## Relative GPU cost

| Version | Per-fragment texture work in this implementation |
| --- | --- |
| Flat | One albedo lookup. |
| Convex normal only | One albedo lookup + one normal lookup, with small normal-decoding arithmetic. No height sampling or ray search. |
| Convex + parallax | The same two lookups, plus 1–13 dependent height lookups at the default 12 steps. The 24-step maximum permits up to 25 height lookups. |

These are shader sampling instructions, not hardware tap counts or a measured frame-time multiplier. Filtering, anisotropy, cache behaviour, screen coverage and GPU architecture affect actual cost. Both maps are 1024×1024 with mipmaps. The old edge shader also samples its roughness map, even though roughness variation is disabled for this comparison; this is retained baseline behaviour, not required by the new normal-only version.

For Android, the convex **normal-only** version is the sensible starting point: the height map is baked offline and need not be sampled at runtime. Parallax should remain optional until tested on target phones; broad floor coverage makes its dependent texture searches costly. No Android device was profiled. The current ANGLE configuration returned unavailable GPU timing, so no measured milliseconds or FPS gains are claimed.

## Verification and captures

- Map checks passed: darkest mortar, brightest centres, intermediate shoulders, unit normals, OpenGL channel direction and wrapped seam continuity.
- Ten scene captures passed unchanged mesh/instance geometry, collision/physics transforms, camera, Act fingerprint/bytes and ball-identity checks.
- Both four-way comparison sets use identical light settings and camera/FOV within each set.
- In a fixed unobstructed floor patch, zero normal strength matches flat shading within 0.00039 mean RGB levels; zero parallax depth matches normal-only shading exactly.
- The control smoke test exercises all mode buttons, camera switching, sliders and the AO checkbox.

`captures/height-normal-maps.png` shows the two generated maps. `captures/height-study/close-comparison.png` and `overview-comparison.png` arrange the four unretouched scene captures. JSON validation files accompany the captures.

To reproduce, run `bake_convex_maps.py`, import the project with Godot, then launch `review.gd` with `-- --capture-height-study`. Run `compare_height_captures.py` to validate and compose the screenshots. Use `-- --height-controls-smoke` to verify the live controls.

Nothing has been committed or pushed. The accepted lighting and the earlier review launcher remain available.
