# Pinball vocabulary study

## Directional Slingshot

Gameplay palette: Slingshot. Local up is the launch direction; rotate to aim. Bright rubber and an arrow mark the active face. Width: 24-200 pixels. Strength: fixed outgoing speed, 100-1600 pixels/second (default 650). Only incoming contact on the straight front face powers a launch. Back and rounded ends rebound passively through the authoritative 2D swept-contact system. Collisionless presentation uses the mechanism hardware palette.

Slingshots award no points and use the existing Spring combo extension once per source per chain. Triangle Bumper behavior is unchanged.

Focused check: `Godot.exe --headless --path . --script res://tests/pinball_vocabulary_regression.gd`.

## Drop Target Bank

Choose Gameplay / Drop Target Bank, then drag the first-to-last target span. Release places one bank and one undo action. Rotation and movement affect the whole row. Inspector exposes count (2-12), spacing (16-80 px), target size (10-50 px), color, completion bonus and reset delay (0-60 seconds). Spacing must exceed target size by 2 pixels; very short/long gestures clamp to those bounds.

Each target owns a stable `bank_object_id/target_index` identity, down state, swept capsule collision and independent retraction animation. Down targets are omitted from contact queries immediately. A hit uses existing Switch scoring (25 points); completion uses existing Switch Bank semantics (default fixed 500, including the existing completion Buddy). No labels or custom-layout grouping in V1. Zero reset delay leaves targets down; a positive delay begins after completion and waits for Ball clearance before restoring collision. Soft retries preserve progress; full reset restores the row.

Editor check: `Godot.exe --headless --path . --script res://tests/pinball_vocabulary_editor_regression.gd`.

## Disposable terrain comparison

Open `experiments/pinball_vocabulary/study_16.tres` in Act Geometry Editor and choose Play Act. Both this file and `study_96.tres` contain the same paired Slingshots, five-target Bank, flippers and serve Spring. In the Play Act window, Load Act switches between the two files; O opens Overview. These files are outside the production Act pool. Save experiments to these copies or Save As, not to production Acts.

The upper/middle court compares a circle, oval, semicircular bump and convex quarter corner. The 96-side baseline preserves the current library sampling. The 16-side study stores every sixth curve vertex in ordinary composite outlines: 16 full-circle edges, eight semicircle segments, four quarter-curve segments. Closing straight edges remain. Those same stored points feed visible terrain and authoritative collision; there is no hidden smooth collider. `CURVE_STEPS` remains 24. Hardware and props keep current production density so this comparison isolates terrain.

Run `Godot.exe --headless --path . --script res://experiments/pinball_vocabulary/studies.gd` to check both saved studies. Add `-- --write` only to regenerate the two disposable files, replacing local edits to them. The script never writes production Acts.

### Primitive-density audit (recommendations, not adopted settings)

- `scripts/pinball_models.gd`, `disc`: 48 radial segments. Candidate hero-hardware range: 12-16.
- `scripts/presentation.gd`, shared sphere: 16 radial segments / 8 rings; shared cylinder: 24 radial segments. Candidate ordinary defaults: 8x4 sphere and 8-sided cylinder. Important pieces: 10x5 spheres and 10-12-sided cylinders.
- `scripts/decor/aquarium_park_decor.gd`: explicit 12x6 spheres, 24-ring torus forms and 12-sided cylinders. The cylinders already suit important props; sphere/torus silhouettes deserve a camera-distance comparison before changing.
- `scripts/decor/sky_sanctuary_decor.gd`: 12x6 spheres and 8-sided cylinders. Cylinder density already fits; spheres are a modest outlier.
- `scripts/authored_act/mechanics_presentation.gd`: magnetic field torus has 48 rings, with a six-segment tube. Treat thin effect outlines separately from solid hero hardware.

Suggested shared language: broad facets, ordinary cylinders 8, important cylinders 10-12, hero hardware 12-16, ordinary spheres 8x4, important spheres 10x5. Terrain 16 is a hypothesis; test 20/24 later only if rebound feel calls for it. Existing bake-time caps may already reduce some source primitives, so inspect both Play Act and baked output before any later migration.

### Manual pass

1. Open `study_16.tres`; inspect paired Slingshots above the flippers and the Bank near the top. Gameplay palette contains both Slingshot and Drop Target Bank.
2. Drag a new Bank row, move/rotate it, then save/reload. Hit individual targets; clear the row and wait five seconds for the fixture reset.
3. Switch to `study_96.tres` through Load Act. Compare curve rebounds and camera readability with the same theme/atmosphere.
4. Five useful tuning controls: Slingshot rotation and strength; Bank target count, spacing and reset delay. Width/target size remain secondary knobs.

Automated coverage is intentionally focused: placement/save/reload, front/back/end and rotated physical contacts, independent drop collision, completion/reset/retry, editor undo/redo, both terrain collision outlines, actual game startup/presentation, and baked animation rebinding. Visual polish, trajectory usefulness and flipper timing still need Alex's playtest.

## Third complex comparison copy

`data/acts/Third complex 16.tres` is a separate faceted copy of Alex's `Third complex.tres`. Its five custom smoothed composites use approximately 22.5-degree accumulated curve turns, retaining sharp corners, curvature reversals and axis extrema. This is a 16-side-equivalent curve treatment, not a forced 16-vertex limit on complex terrain. Outline counts change from 444/366/407/88/44 to 13/15/29/16/9. Only the title and terrain outlines differ; gameplay objects, transforms, rings, scenery identity and all other authored data remain intact. The original file is untouched.

Verified loading/validation, exact save/reload, shared-engine headless startup, and matching visual-source/collision polygons. Open the copy through Act Editor or Play Act / Load Act; rebound feel remains a manual comparison.

## Secret Entry comparison copy

`data/acts/Secret Entry 16.tres` applies the same 22.5-degree, corner/extrema-preserving curve treatment to `data/acts/Authored/Secret Entry.tres`. The copy stays outside the production `Authored` pool. Its four composite outlines change from 828/345/121/86 points to 35/22/6/16; only title and terrain outlines differ. Original source, gameplay and other authored data are preserved. Loading/validation, exact save/reload, headless shared-engine startup and matched visible-source/collision outlines passed. Rebound feel remains for manual playtesting.
