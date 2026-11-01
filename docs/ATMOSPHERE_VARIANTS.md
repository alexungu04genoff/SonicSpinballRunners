# Production atmosphere variants

The production model is **Act geometry × Theme × Atmosphere Variant**. Geometry and material topology still bake only as Act × Theme, including that Act/theme's scenery sidecar. Atmosphere is applied to those reusable recipes at runtime. Production does not read `user://lighting_lab_presets.cfg`.

## Ownership and storage

`data/atmospheres/<theme_id>.cfg` is version-1, inspectable project data. Each section has a stable ID, display name, enabled flag, weight and a dictionary of atmosphere overrides. Colors remain native ConfigFile `Color` values. There are no copied Theme resources, geometry references or serialized percentages. Both export scripts include these files.

Every Theme starts with **Default**: an empty override dictionary representing the current source appearance. Its ID, name and appearance are protected. Its enabled flag and weight may change, provided the Theme still has an enabled positive-weight choice. The initial production roster contains only these eight baselines; quick looks and old Lab saves have not been promoted.

Saving validates names, IDs, value types/ranges and the weighted pool. It compares the file revision before replacing it through a temporary file, so another Lab window's save cannot be silently overwritten. A malformed or unavailable runtime registry falls back to the authored Default; the registry exposes its diagnostic to authoring callers.

## Lab workflow

Use the existing Lighting/Atmosphere Lab. The new selector distinguishes **Lab draft (user-local)** from production variants. The Variants tab contains New, Duplicate, Delete, a name field for renaming, Enabled, Weight, Save Variant and Revert.

1. Select a Theme and Default, then Duplicate. New instead starts from the source baseline.
2. Enter a name. Apply a quick look such as Sunset, then tune Light, Sky, Palette, Glow & Fog and Shadows.
3. Save Variant explicitly. Slider changes are drafts; an asterisk marks unsaved changes. Editing the name and saving renames the display label without changing the stable ID.
4. Revert reloads that variant from disk. Delete removes a non-default variant only if the remaining weighted pool is valid.

Default's appearance controls are read-only. Switching variants does not rebuild geometry, regenerate scenery, change the Act, move the camera or reset the ball. Switching Acts retains the selected Theme/variant and its working draft. Scenery remains independently owned by the Act/theme sidecar.

Unsaved variants and edits are retained in memory while switching contexts, not automatically promoted or committed. Save Variant saves the selected variant only. The user-local draft's Save action still uses the renderer/theme section in `user://lighting_lab_presets.cfg`. Quick looks remain recipes that populate a draft, never a production roster or automatic run choice.

## Weights, selection and overrides

Chance is `enabled positive weight / sum of enabled positive weights`. The editor shows the approximate percentage using the current draft pool. It never serializes that derived number. Proportional weights such as 5/3/2 and 50/30/20 are equivalent. Disabled or zero-weight variants remain available for explicit testing. An all-zero/disabled pool, negative or nonfinite weight, duplicate name/ID, or deleted Default cannot be saved.

Prototype and Endless choose once per Zone, after choosing its Theme. A private RNG is seeded from the run seed, Zone index and Theme ID with a versioned `atmosphere/v1` salt. Stable ID order makes selection reproducible for the same registry. The choice, including its override values, is copied into every Act entry in that Zone. Editing a registry during a run does not rewrite already-planned Zones. Prototype course telemetry includes the selected atmosphere snapshot. Neither theme/Act planning RNG nor gameplay RNG is consumed by atmosphere selection.

For development, the Lab itself previews any stored or unsaved variant directly. **Playtest args** copies an argument for the normal launcher:

```powershell
& ".\Play Prototype.cmd" -Atmosphere ice_cap:variant_123456
```

Use the actual stable ID shown in the Variants tab. Save first. The underlying Godot argument is `-- --atmosphere=ice_cap:variant_123456`. It selects that Theme for a one-Zone Prototype and bypasses weights, including for disabled variants. `RunConfiguration.atmosphere_overrides` also supports explicit per-Theme choices in development code. These overrides are not saved as normal run preferences.

## Hue and saturation scope

Hue is a signed turn (−0.5 to +0.5), saturation a multiplier (0 to 2). Neutral values are 0 and 1. Controls are semantic, not a screen-wide filter.

| Group | Explicit coverage |
| --- | --- |
| Terrain | Theme floor, raised wall tops, wall/facade and contour-border material roles |
| Ground floor override | `floor_material` |
| Raised tops / upper floor override | `top_material` |
| Walls / cliffs override | `side_material` and `cliff_material`, retaining a common facade appearance |
| Ledges / borders / edges override | `floor_border_material` and `top_border_material` |
| Background | Opted-in water/cloud palettes, architecture/skyline/shore tints, ruin haze and cavern colors |
| Foliage | Explicit vegetation-tint bindings, including tagged Rooftop decor and Green Hill distant vegetation |
| Neon | Tagged Casino decorative neon, windows, marquee and spill lights; Chemical decorative cyan/pink signals |

Each terrain category has an **Override** toggle. Off inherits Terrain; on replaces Terrain hue/saturation for that material role. It does not add another shader operation. These are material categories, not geometry-height detection: a scenery landform using the floor material remains in Ground, and a raised wall top uses Upper. Existing art roles and shared terrain mapping remain intact.

Decor follows its explicit material bindings. Untagged props do not change. Rings, player/ball, enemies, UI, Goal Rings, physics/debug visuals and untagged readability markers do not join these hue groups. Texture emission maps retain their authored colors under Terrain hue; Neon controls the explicitly tagged decorative bindings. Per-color palette controls remain available alongside the transforms.

Production terrain shader families (`terrain_texture`, `terrain_facade`, `texture_surface`, `texture_wall`, `terrain_border`, `green_hill_wall`) use the same small uniform-driven HSV operation in their existing pass. Neutral uniforms bypass it. StandardMaterial and semantic palette colors shift once on apply. Independent, uncommitted material experiments that replace these shaders need their own opt-in before those surfaces participate; they are not rewritten automatically.

## Runtime and bake boundaries

Each resident Zone owns private environment/sky state and one edited material copy per source material, shared across its Acts and scenery. Cached recipe materials are immutable. Incremental attachment tracks already-bound nodes so background completion cannot duplicate an Act's material copies or apply a transform twice. Binding and palette work happens on attachment/change, not through a per-frame scene traversal.

Adjacent Zones can use the same Theme with different variants. Their background viewports keep separate skies and materials; foreground light/environment parameters follow the existing distance-driven transition. Numeric lighting/fog/glow values blend. Discrete tonemapper/adjustment modes switch at the midpoint. No new light, viewport, render pass, screen-reading effect, refraction or texture rebake is introduced. Static MultiMeshes and recipe topology remain unchanged.

The shader/binding implementation requires one ordinary source-hash bake refresh. Subsequent named-variant creation, renaming, weighting or color edits do not change the bake matrix or recipe fingerprint. Production remains five Acts × eight Themes (40 variants); Endless remains seven × eight (56). Runtime ignores the Lab save file and packaged games include the production registry.

## Verification

`tests/atmosphere_variants_regression.gd` covers storage, protected baselines, validation, concurrent-save rejection, weights, RNG isolation, per-Zone plan identity, production-location data edits without a changed bake fingerprint, material sharing/exclusions, Lab Save/Revert/Delete and context preservation. The production-location case uses `--production-fixture` in a disposable checkout and restores its files exactly; the ordinary test does not write production files.

`tests/atmosphere_runtime_regression.gd` exercises two adjacent Ice Zones with different appearances from shared disk recipes, material isolation, switching and a distance-driven transition. It writes matched default/strong ABBA profiles and transition observations. `tests/atmosphere_profile.gd -- --atmosphere-hue` compares strong category/background/foliage/neon transforms in the Lab. Alex owns further performance and visual tuning review; additional performance testing was stopped at his request.

Final functional checks: variant/storage/Lab regression passed 458 checks in the clean export, including a real Act change; the existing atmosphere suite passed 476 there (492 with local art). Scenery passed 8,574 checks in the clean export and 6,606 in the working checkout. Prototype planning passed 41 checks; static batching passed 111. Runtime ownership/switching/transition checks passed 52. All 40 Prototype and 56 Endless recipes were refreshed and audited (387/451 checks). Streaming passed 256 checks over 27 transitions with zero fallback, and the minimal PCK loaded all eight production registries. Launcher/export PowerShell syntax checks pass.

Exploratory profiles completed before the manual-performance handoff are retained under ignored test results: the clean export's `test-results/atmosphere-hue/report.json` and `test-results/atmosphere-variants/runtime/report.json` in the working checkout. Strong hue transforms kept draw/object/material/resource counts unchanged in the matched samples; the all-eight mean GPU deltas were approximately −0.0005 to +0.002 ms. CPU/frame results are not isolated benchmarks: an interactive Lab was open, and the Lab profile also overlapped offline baking. These measurements do not establish whole-run FPS or second-hardware behavior.

The existing ObjectDB exit-warning class remains: 48 instances after the full tour; a six-transition verbose repeat reported four zero-reference RefCounted instances and no leaked scene nodes. Streaming still has preparation/frame-time outliers. Neither is claimed fixed by atmosphere authoring. Uncommitted art experiments remain separate, and no final look roster was authored automatically.
