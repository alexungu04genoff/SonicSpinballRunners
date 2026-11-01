# Continuous exterior terrain mapping

## Diagnosis (2026-10-31)

The reported Green Hill screenshot is **First Try Smooth Decor**. Its front edge is
at world Z = 6, X = 1–5.5. The left raised wall ends at X = 2.5; the right one
starts at X = 3.5. Both meet the floor cliff at Y = 0.

The discontinuity exists in the authored, unbaked presentation. Capturing that
presentation into a recipe and applying static batching preserve it. Loading the
old disk bake also reproduces it. Recipe transforms and batching are not the
source of this example.

There were three contributing problems:

1. **Surface ownership did not express exterior continuity.** `_prism()` used
   `side_material` above Y = 0, while `_make_land()` used `cliff_material` below it.
   These are independently authored wall/facade images and height origins. The
   converted shaders already use world positions, but that cannot make different
   images, trims and depth clamping continuous. Sky Sanctuary's repeated cornice
   and vines and Ice Cap's restarted upper lip expose the same material boundary.
   This is not simply a missing world-position calculation in those shaders.
2. **Legacy UV charts disagreed.** Committed Green Hill used contour UVs for the
   cliff and world projection for walls. The local art variant used independently
   fitted contour UVs for both. In that variant, the measured front-edge U scale
   was 0.98577 on the cliff, 1.02140 on the left wall and 1.00448 on the right wall.
   Their starting phases also differed. The apparently good right join was an
   accidental alignment, not a stable mapping rule.
3. **Baking simplified two copies of the boundary independently.** Raised walls
   used simplified contours, but floor inference used the original outlines and
   was then simplified separately. On curves this produced slightly different
   segments and projection normals at the wall/cliff join. The measured example
   included approximately 0.0022 world units of separation and a 4.18-degree
   normal difference. Raw floor inference also contains tiny epsilon segments;
   these are not evidence of an Act transform error.

The two converted themes do not reproduce Green Hill's independently fitted
checker UVs. They reproduce the shared material-boundary problem. These causes
must not be conflated.

## Shared rule

An exterior wall face that coincides with the floor boundary belongs to the
**facade**, regardless of the obstacle mesh that initially generated it. Interior
walls retain their wall material. `terrain_facade.gd` transfers the existing
exterior triangles into the existing cliff surface before capture. It introduces
no extra mesh surface, draw pass, overlay or runtime work.

The facade uses final world position and outward world normal, with the existing
orientation-weighted X/Z projection and the theme's existing texture pitch. Its
depth reference is shared across the entire exterior, including the upper wall.
Legacy contour materials are adapted to this rule while retaining their selected
images and repeat sizes. Green Hill's upper grass fringe remains at its existing
height. No Act offsets, seed adjustments or manually shifted textures are stored.

The offline presenter infers the floor from the **same simplified wall contours**
that it renders. It does not independently simplify that inferred boundary again.
This changes the derived floor triangulation, not authored polygons or collision
shapes. `_make_land()` scenery uses the same facade material/world-coordinate
rule. Scenery positions, framing, atmosphere, physics and static batching remain
under their existing owners.

Normal recipe placement and MultiMesh instance transforms feed `MODEL_MATRIX` and
`MODEL_NORMAL_MATRIX`. Camera movement does not enter the mapping calculation.
Changing theme intentionally changes artwork; actual geometric corners still
change projection according to their orientation.

## Verification

- Straight and bent fixtures in all eight themes: 164 checks with the local art
  variants and 168 against an isolated export of the staged, committed source.
  The transfer preserves the complete triangle/normal multiset, adds no surfaces,
  and survives capture, batching and translated Act placement.
- Geometry/collision regression: 2,842 checks. Static batching regression: 111.
- Forward+ / Vulkan screenshots of First Try Smooth Decor and Reverse C Spring
  in Green Hill, Sky Sanctuary and Ice Cap: raw, captured, batched and disk-baked
  views, including curved outlines and generated scenery landforms.
- Rebuilt 40 Prototype and 56 Endless variants. Bakes are derived local artifacts;
  changed source dependencies invalidate earlier pipeline receipts automatically.
- Both bake audits passed: 387 Prototype checks and 451 Endless checks. Actual
  Prototype instances loaded neighboring Acts in Green Hill, Sky Sanctuary and
  Ice Cap with zero runtime rebuilds and reused validated collision data.
- The 27-transition Forward+ streaming smoke passed all 256 checks twice.
  Atmosphere regression passed all 492 checks. Clean-source Forward+ captures also
  confirmed the original committed Green Hill art and the two converted themes.

Local evidence is under `test-results/terrain-seams/`: `baseline`, `final-first`,
`final-reverse`, `matched`, and the Prototype join captures. These generated
artifacts are intentionally not source assets.

The existing Godot shutdown warning remains. The first streaming run reported 66
ObjectDB entries; the verbose repeat reported seven zero-reference `RefCounted`
entries, with no leaked Nodes or texture/material resources listed. The previous
scenery verification also recorded seven zero-reference `RefCounted` entries.
This fix does not claim to resolve that engine/streaming shutdown warning.

### Measured cost

Matched old/new template builds used the same current authored Act, theme,
1280×900 camera and environment. Both went through production asset sharing and
static batching. Two 240-frame samples per variant ran in before/after/after/before
order on an RTX 4060 with Godot 4.7.2, Forward+ Vulkan. GPU values below are the
mean of the two median viewport timings, not a whole-run benchmark.

| Act / theme | Draw calls before → after | Batches before → after | GPU ms before → after |
| --- | ---: | ---: | ---: |
| First Try / Green Hill | 527 → 527 | 30 → 30 | 0.444 → 0.471 |
| First Try / Sky Sanctuary | 306 → 306 | 46 → 46 | 0.521 → 0.542 |
| First Try / Ice Cap | 199 → 199 | 19 → 19 | 0.504 → 0.525 |
| Reverse C / Green Hill | 952 → 952 | 38 → 38 | 0.523 → 0.558 |
| Reverse C / Sky Sanctuary | 398 → 395 | 64 → 64 | 0.553 → 0.579 |
| Reverse C / Ice Cap | 262 → 261 | 41 → 41 | 0.524 → 0.546 |

Keeping the common boundary adds approximately 4,569–4,605 submitted source
vertices on First Try and 5,622–5,640 on Reverse C before mesh optimization,
including the associated floor border. The measured GPU increase was about
0.02–0.035 ms in these views. It is small, but this is a geometry/material fix,
not a claim of literally zero cost. Draw calls did not increase and batch counts
were unchanged. No new pass or light was added.

Do not compare an old Endless Act copy with a current editable Prototype Act to
measure this change: their gameplay/decor contents can differ. The matched report
rebuilds both versions from the same document instead.
