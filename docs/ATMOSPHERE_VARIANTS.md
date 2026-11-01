# Production atmosphere variants

The production model is **Act geometry × Theme × Atmosphere Variant**. Geometry and material topology still bake only as Act × Theme, including that Act/theme's scenery sidecar. Atmosphere is applied to those reusable recipes at runtime. Production does not read `user://lighting_lab_presets.cfg`.

## Ownership and storage

`data/atmospheres/<theme_id>.cfg` is version-1, inspectable project data. Each section has a stable ID, display name, enabled flag, weight and a dictionary of atmosphere overrides. Colors remain native ConfigFile `Color` values. There are no copied Theme resources, geometry references or serialized percentages. Both export scripts include these files.

Every Theme has an authored **Default** atmosphere. Its appearance, enabled flag and weight are editable and save like other variants. Its ID/name remain fixed and the entry cannot be deleted. The Theme must still have an enabled positive-weight choice. An empty override dictionary still means the source appearance. Quick looks and old Lab saves are never promoted automatically.

## Zone Defaults — 2026-11-01

Alex requested a fresh set of eight production Defaults, retaining gameplay visibility at night. These replace the previous saved Default lighting/palette values; other named variants and user-local Lab drafts remain intact. Select **Default** in the Lab selector to review them. **Show original atmosphere** still compares against source theme values.

| Zone | Direction |
| --- | --- |
| Green Hill | Clear tropical daylight, warm sun, blue fill and turquoise ocean. |
| Chemical Plant | Indigo industrial night, readable cool fill, cyan/pink accents and broader soft neon halos. |
| Rooftop Run | Spagonia afternoon: warm cream masonry and terracotta under a blue sky. |
| Casino Night | Deep violet night with distinct pink, aqua, mint and amber neon against a readable course. |
| Sky Sanctuary | Classic pale yellow/green ruins above blue-shadowed cloud banks in daylight. |
| Ice Cap | Daytime glacier, pale blue sky, cold lake reflections, no sky stars or aurora curtains. |
| Lava Reef | Warm rock, orange molten glow and restrained distant heat haze. |
| Aquarium Park | Colours-inspired cool blue lagoon and red architecture with warm lanterns. |

Hue, saturation and brightness controls were preserved, including selective ranges, category overrides, stacking/link flags, environment saturation, background/fog brightness and the existing Color adjustment toggle. Chemical's saved ground brightness/saturation and Rooftop's saved background brightness/saturation therefore remain part of their Defaults. Light energy/exposure, palette colors, emission and halo shape are deliberately tuned independently. Shadows retain enabled / 0.85 opacity / 0.00 angular softness / 0.02 bias / 0.55 normal bias. Only Lava's Default enables a subtle directional haze; ordinary fog stays off to avoid camera-distance-dependent washout.

Scenery defaults to **2.50 Showcase** for the six density-driven themes, separately from atmosphere data. Lava Reef and Aquarium Park retain their fixed scenery builders. Existing explicit sidecar choices still take precedence. Density changes require the normal bake refresh; atmosphere changes alone do not.

Saving validates names, IDs, value types/ranges and the weighted pool. It compares the file revision before replacing it through a temporary file, so another Lab window's save cannot be silently overwritten. A malformed or unavailable runtime registry falls back to the authored Default; the registry exposes its diagnostic to authoring callers.

## Lab workflow

### Cosmetic hardware and protected gameplay colors

Ramp deck surfaces have independent hue, saturation and brightness controls, plus Stack with Hue. The deck role is isolated from shared terrain/decor materials; rail trim retains its existing ownership and the entry accent has its own color picker. Values use the existing variant persistence and material binding paths.

Palette exposes the six existing Pinball Hardware slots (Rubber, Bumper face, Metal trim, Markings, Flipper face, Hardware base), plus Mechanisms (body/trim/accent), Spinner (frame/paddle/inset), Dash Panel (chassis/frame/chevrons), and the existing rail accent where its material supports a color input. These are ordinary production variant colors with per-color Stack with Hue controls. Fields appear for materials present in the preview. Existing source colors remain the neutral defaults, including different shades that share one role. Aquarium Park now has a deliberate coral-rubber, teal-face/paddle, brass-trim, ivory-mark and deep-blue-base pinball palette.

Cosmetic materials are shared by presentation and theme. Stateful dash chevrons remain instance-owned, and their pulse updates the live Zone-owned palette material after attachment. Springs, switch buttons, lane lit/unlit/completed lights, diverter pending/normal indicators and magnetic attract/repel identity are protected from palette/range changes. Protected state materials are not replaced by atmosphere copies, so runtime feedback retains its live references. Switch housings and lane posts/rims remain cosmetic. Rings, Goal Rings, player/enemy identity and combo feedback have no new palette bindings.

Spring `color` and `launch_strength` are currently separate Act-authored properties (default red and 300); this pass does not infer strength from color or establish new strength classes. Switch color remains an Act property suitable for Bank correlation. Magnetic field rings, centers and arc markers retain their attract/repel colors at 20% opacity and cast no shadows; their forces and radii are unchanged.

No gameplay geometry, collision, texture rebake, new palette render pass, per-frame scene traversal or bake dimension is introduced. The material-tag changes require the usual recipe refresh. Magnetic alpha uses the existing native transparent material path. All eight themes passed the focused hardware/state check and Lab smoke; performance and extended playtesting are left to Alex.

The final ramp-inclusive headless check passed 447 assertions across all eight themes, including variant save/reload and range opt-out. The earlier rendered hardware check passed 408 assertions and the Lab smoke passed 1,698. A later rendered retry encountered a Vulkan device-loss crash during initial flipper construction; that retry did not validate final ramp appearance. Final visual review remains manual.

### Foliage semantics

Foliage means visible plant tissue: fronds, leaves, needles, vines, moss, shrubs, decorative grass and aquatic plant material. It is a material role, not a whole-prop selection. Trunks, bridge wood, petals, rocks, ruins, coral, fish, crystals, machinery and playable turf retain their existing Decor, Terrain or Palette roles.

| Theme | Foliage targets |
| --- | --- |
| Green Hill | Palm fronds, shrubs, decorative grass tufts, sunflower stems/leaves and distant vegetation mounds. Island turf and playable grass remain separate. |
| Rooftop Run | Hedge/planter greenery and cypress foliage, including textured local materials. Vegetation tint remains a Palette input. |
| Sky Sanctuary | Vines, moss, blossom stems and palm leaves; scenery haze remains a separate Palette input. |
| Ice Cap | Pine/fir needles and frost-grass blades. Frost grass has a private shared copy of the snow material, with identical neutral appearance, so snowcaps do not follow it. |
| Aquarium Park | The existing `plant` material, currently used for teal stalks in the branching aquatic arrangements. Pink coral branches retain Coral; fish retain Aquatic accent. |
| Chemical Plant / Lava Reef | No plant materials; Foliage controls are hidden. |
| Casino Night | The palm is a stylized mint-neon fixture, sharing its light material with casino accents. It deliberately remains under Neon/Neon mint, including its fronds. Foliage controls are hidden; signs are never classified as plants. |

Controls, including Stack with Hue, appear only when the current preview contains Foliage bindings. A plant-free Act may therefore hide them even in a supporting theme. Saved values remain valid. Shared material tags survive Decor conversion, local/distant scenery copies, baking and runtime binding. Vegetation Palette inputs are applied before the single final Foliage adjustment; textured foliage shifts its sampled colors rather than a neutral tint. Selective Hue ranges follow that adjustment and can be disabled for Foliage with Stack with Hue. Neutral settings preserve source colors; no geometry, collision, random sampling, render pass or per-frame traversal is added. Frost grass's separate semantic material can split it from snow in a material batch; ordinary static batching remains enabled.

Use the existing Lighting/Atmosphere Lab. The new selector distinguishes **Lab draft (user-local)** from production variants. The Variants tab contains New, Duplicate, Delete, a name field for renaming, Enabled, Weight, Save Variant and Revert.

1. Select a Theme and Default to edit its usual appearance, or Duplicate for another look. New starts from the source baseline.
2. Enter a name for a new variant. Apply a quick look such as Sunset, then tune Light, Sky, Palette, Glow & Fog and Shadows.
3. Save Variant explicitly. Slider changes are drafts; an asterisk marks unsaved changes. Editing the name and saving renames the display label without changing the stable ID.
4. Revert reloads that variant from disk. Delete removes a non-default variant only if the remaining weighted pool is valid.

Default supports the same presets, Palette/Hue controls and scene picker as other variants. Show original atmosphere always compares with the authored theme, even after Default is edited. Reset restores the authored appearance as an unsaved edit; Revert reloads the saved variant. Switching variants does not rebuild geometry, regenerate scenery, change the Act, move the camera or reset the ball. Switching Acts retains the selected Theme/variant and its working draft. Scenery remains independently owned by the Act/theme sidecar.

Unsaved variants and edits are retained in memory while switching contexts, not automatically promoted or committed. Save Variant saves the selected variant only. The user-local draft's Save action still uses the renderer/theme section in `user://lighting_lab_presets.cfg`. Quick looks remain recipes that populate a draft, never a production roster or automatic run choice.

In F11 Play View, the inspector uses the available vertical height with 10-pixel top and bottom margins. Returning to the development window restores space for the existing footer. The Palette tab starts with the Decor controls.

Text fields own keyboard input while focused, including in Play View: letters and digits do not trigger overview, pose or material shortcuts. Numeric edits apply on Enter or focus loss; idle fields display two decimal places while retaining finer stored precision. Typed values are not snapped to slider increments, so 0.01 works even on fields whose arrows move by 0.5; valid field bounds still apply. Arrow/slider increments remain independent, and scenery seeds remain integers. Variant names retain spaces while typing and trim only when saved.

## Weights, selection and overrides

Chance is `enabled positive weight / sum of enabled positive weights`. The editor shows the approximate percentage using the current draft pool. It never serializes that derived number. Proportional weights such as 5/3/2 and 50/30/20 are equivalent. Disabled or zero-weight variants remain available for explicit testing. An all-zero/disabled pool, negative or nonfinite weight, duplicate name/ID, or deleted Default cannot be saved.

Prototype and Endless choose once per Zone, after choosing its Theme. A private RNG is seeded from the run seed, Zone index and Theme ID with a versioned `atmosphere/v1` salt. Stable ID order makes selection reproducible for the same registry. The choice, including its override values, is copied into every Act entry in that Zone. Editing a registry during a run does not rewrite already-planned Zones. Prototype course telemetry includes the selected atmosphere snapshot. Neither theme/Act planning RNG nor gameplay RNG is consumed by atmosphere selection.

For development, the Lab itself previews any stored or unsaved variant directly. **Playtest args** copies an argument for the normal launcher:

```powershell
& ".\Play Prototype.cmd" -Atmosphere ice_cap:variant_123456
```

Use the actual stable ID shown in the Variants tab. Save first. The underlying Godot argument is `-- --atmosphere=ice_cap:variant_123456`. It selects that Theme for a one-Zone Prototype and bypasses weights, including for disabled variants. `RunConfiguration.atmosphere_overrides` also supports explicit per-Theme choices in development code. These overrides are not saved as normal run preferences.

## Hue, saturation and brightness scope

Hue is a signed turn (−0.7 to +0.7); saturation is a multiplier from 0 to 2, and brightness from 0 to 3. Neutral values are 0, 1 and 1. Hue wraps around the color wheel, so shifts beyond half a turn revisit colors available in the opposite direction. Every group below has all three controls. Brightness scales the bound surface color, not exposure or real-light energy, and preserves alpha. Older drafts/variants without brightness values remain neutral. Controls are semantic, not a screen-wide filter. Sliders, scene dragging and saved-variant validation share these bounds. Numeric fields across the Lab display two decimal places without reducing stored precision or changing their adjustment steps.

| Group | Explicit coverage |
| --- | --- |
| Decor | Collisionless props created by authored Decor slots, including their decorative emission; shared copies per source material |
| Terrain | Theme floor, raised wall tops, wall/facade and contour-border material roles |
| Ground floor override | `floor_material` |
| Raised tops / upper floor override | `top_material` |
| Walls / cliffs override | `side_material` and `cliff_material`, retaining a common facade appearance |
| Borders override | Floor trim around the bases of raised terrain |
| Edges override | Outer floor rims, including local scenery landforms |
| Ledges override | Raised top trim (`top_border_material`) |
| Background | Opted-in water/cloud palettes, architecture/skyline/shore tints, ruin haze and cavern colors |
| Foliage | Explicit vegetation-tint bindings, including tagged Rooftop decor and Green Hill distant vegetation |
| Neon | Tagged Casino decorative neon, windows, marquee and spill lights; Chemical decorative cyan/pink signals |

Each terrain category has an **Override** toggle. Off inherits Terrain; on replaces Terrain hue/saturation/brightness for that material role. It does not add another shader operation. These are material categories, not geometry-height detection: a scenery landform using the floor material remains in Ground, and a raised wall top uses Upper. Existing art roles and shared terrain mapping remain intact.

**Link edges and ledges to borders** defaults on. Borders then drives hue, saturation, brightness, the override toggle and Stack with Hue for all three trim groups. Turn the link off to edit Edges and Ledges independently; their controls become available, and each has its own override and stacking toggle. Linking does not erase independent values. Old variants without the link field retain their combined appearance through the existing `terrain_borders` keys.

The floor's outer rim and inner foot borders share one mesh/material. Their existing triangles now carry a constant role in the spare UV2 channel; the surface shader selects the corresponding adjustment before its existing color operation. Raised trim has its own material role. This preserves vertices, UV1 mapping, collision, draw passes and static batching; it does not duplicate border meshes. The live and fast bake builders both carry the role, including scenery landforms. Existing Rooftop grass shells inherit the same trim controls. This source change needs the usual bake refresh; subsequent link/color edits do not.

Decor materials opt in at the shared Decor slot factory, without changing their terrain or gameplay source materials. Existing Neon/Foliage/per-color bindings apply first, then Decor adjusts the finished prop color. Distant and local background scenery retain their existing semantic bindings; they are not classified as authored Decor slots. Rings, player/ball, enemies, UI, Goal Rings, physics/debug visuals and untagged readability markers do not join these hue groups. **Neon also controls terrain texture emission**, including Chemical's blue/yellow floor panels and edge strips. It leaves the terrain's non-emissive color alone. Per-color palette controls remain available alongside the transforms.

Production terrain shader families (`terrain_texture`, `terrain_facade`, `texture_surface`, `texture_wall`, `terrain_border`, `green_hill_wall`) use the same small uniform-driven HSV operation in their existing pass. Neutral hue/saturation bypass HSV; brightness remains a multiplication. StandardMaterial and semantic palette colors change once on apply.

The ground/raised-top failure reported after the first variant pass came from custom replacement surface shaders: their materials carried terrain role metadata, but their programs lacked the shared color uniforms. `surface_controls.gd` now prepares missing support once when a theme's explicit terrain roles or an authored Decor material are created. It caches the resulting shader programs and retains the original program identity for palette bindings and offline relief conversion. Vertex, texture, relief and lighting code remain intact. Slider edits and variant switches only change uniforms; they do not generate programs, rebuild props or add render passes. This also covers the working checkout's custom Green Hill turf and selected Chemical/Casino/Rooftop shaders without committing those unrelated art experiments.

## Selective color ranges

The separate **Hue** tab adds Red, Orange, Yellow, Green, Aqua, Blue, Purple and Magenta ranges. Each has a hue offset, saturation multiplier and brightness multiplier, using the same bounds as the Palette transforms. Enable color ranges turns the layer on; Reset color ranges resets only this layer. Adjacent ranges interpolate smoothly, red wraps around the hue circle, and neutral whites/grays are protected. An enabled but neutral layer is also an exact no-op.

**Pick in scene** provides a targeted adjustment tool: choose Hue, Saturation or Brightness, click a colored surface, then drag horizontally. Shift gives finer adjustment and Esc exits picking. The swatch and label identify the nearest range. Sampling briefly pauses and freezes the visible preview while reading the existing scene viewport before the Hue/Retro layers; this keeps an already shifted green surface selectable as Green. It restores the original pause/Retro state and uses no additional viewport or persistent pass. Lighting and Palette edits remain in the sampled image; the picker is not an object or gameplay-material selector. Neutral areas request a more colorful sample.

Ranges operate after the category controls. For example, Green hue `0.23`, saturation `0.4` and brightness `1.6` is an icy Green Hill starting point: grass and foliage shift toward pale blue while brown checker colors remain. It is not a production variant or a new default. Warm yellow-green colors overlap Yellow and Green; each range is a smooth selection, not a hard RGB replacement.

Every Palette category and every individual color picker has **Stack with Hue**. On combines its Palette adjustment with the Hue tab. Off retains its Palette adjustment while excluding the range layer. Terrain's master switch gates its subcategories; a category can also opt out independently. For a shader mixing multiple palette inputs, an individual opt-out keeps that input unchanged and applies ranges to the remaining enabled inputs before the shader mixes them. This avoids shifting an opted-out input again in the final surface operation. Old variants without stack flags default to stacking.

The range layer covers explicitly bound terrain and authored Decor, plus **all collisionless local and distant scenery** through its existing ownership roots. Scenery-only copies are separate from an untagged source also used by gameplay, so shared resources cannot leak a shift onto a bumper or player. The baked runtime identifies scenery through its existing background roots rather than mesh names. Texture colors and vertex colors participate after sampling; a cached surface adapter preserves the StandardMaterial features used by those scenery materials, including texture coordinates/triplanar mapping, culling, opacity, roughness, specular and emission. This closes the remaining textured-shrub and vertex-colored-roof/mountain gaps. All changes reuse the original rendering pass.

At Alex's request, Green Hill palm trunks and bridge wood now use two sampled browns from the active checker texture. The bounded sample is cached per Theme instance, works with committed and locally selected textures, and changes no geometry. Leaves retain their own source palette.

## Glow and emission shaping

Glow & Fog exposes native glow spread, tight/wide/diffuse halo weights and optional brightness normalization in every theme. These complement emission brightness and glow intensity: lower tight weight and increase wide/diffuse weight to soften the halo. Optional Surface halo width scales existing material falloff uniforms where supported, currently the local Chemical floor and edge artwork. Unsupported themes hide that field. Neutral width is `1.00`; no source artwork or saved appearance is changed automatically. Retro's separate phosphor halo is unchanged.

The controls participate in draft/variant storage, validation, original comparison and reset. Each Zone applies surface width to its existing private material copies when attaching scenery. Native glow properties, including the nested `glow_levels` properties, blend through the existing foreground environment transition. This follow-up requires no shader or geometry changes and does not add a bake variant dimension.

## Runtime and bake boundaries

Each resident Zone owns private environment/sky state and one edited material copy per source material, shared across its Acts and scenery. Cached recipe materials are immutable. Incremental attachment tracks already-bound nodes so background completion cannot duplicate an Act's material copies or apply a transform twice. Binding and palette work happens on attachment/change, not through a per-frame scene traversal.

Adjacent Zones can use the same Theme with different variants. Their background viewports keep separate skies and materials; foreground light/environment parameters follow the existing distance-driven transition. Numeric lighting/fog/glow values blend. Discrete tonemapper/adjustment modes switch at the midpoint. No new light, viewport, render pass, screen-reading effect, refraction or texture rebake is introduced. Static MultiMeshes and recipe topology remain unchanged.

The shader/binding implementation requires one ordinary source-hash bake refresh. Subsequent named-variant creation, renaming, weighting or color edits do not change the bake matrix or recipe fingerprint. Production remains five Acts × eight Themes (40 variants); Endless remains seven × eight (56). Runtime ignores the Lab save file and packaged games include the production registry.

## Verification

The Foliage audit passed 444 all-prop checks in the working art checkout and 422 in clean staged source, plus 765 selective-range checks and 1,458 Lab checks. All 96 refreshed recipes passed material-role coverage (7,290 checks); both bake audits passed (401/465), batching passed 111 checks, and six streamed transitions passed 2,634 checks including live plant recoloring and non-plant isolation. Source defaults, variant weights and lighting files were not edited. Existing local Casino import warnings and streaming shutdown ObjectDB warnings remain. No performance benchmark was run.

The Zone Default pass validated all eight saved Defaults, their live Lab/runtime properties, Showcase loading, and the separate Ultra + FXAA option: 774 checks passed in both the working art checkout and an export of the exact staged source. Overview and gameplay-distance images were reviewed with Retro on/off under `test-results/zone-defaults/`. A separate before/after comparison confirmed all protected hue/saturation/brightness values and all named variants were preserved exactly. Lab smoke passed 1,467 checks, scenery passed 6,607, variant/storage checks passed 440, and batching passed 111. All 40 Prototype and 56 Endless recipes were refreshed and passed 401/465 audit checks; the six-transition disk-backed streaming smoke passed 87 checks without procedural fallback. Existing local Casino raw-image warnings and five ObjectDB instances reported at streaming shutdown remain outside this pass. No performance benchmark was run.

The independent trim follow-up passed 1,527 all-theme surface/UI checks, 765 selective-range checks, 227 live border checks, 1,528 bake-border checks and 111 static-batching checks. These cover linked legacy appearances, independent hue/saturation/brightness, per-group Hue stacking, save/reload, retained independent settings, unchanged collision outlines, and outer/inner role data in both border builders. All 40 Prototype and 56 Endless recipes were refreshed; their audits passed 401 and 465 checks. The combined 96-recipe material/UV2 audit passed 6,666 checks. No performance benchmark was run.

`tests/atmosphere_glow_regression.gd` passed 299 functional checks in the live art checkout: all eight themes with Retro on/off, native rendered halo spread, supported surface-width visibility, source/gameplay material isolation, exact reset, save/reload, runtime settings and streamed glow interpolation. Captures are under `test-results/atmosphere-glow/`. The existing fog regression passed 31 checks after the control layout change, and Godot headless editor import passed. Existing Casino local-art raw-image import warnings remain; no shader errors or glow failures occurred. No performance benchmark was run.

`tests/atmosphere_variants_regression.gd` covers storage, editable Default appearances with fixed identity, validation, concurrent-save rejection, weights, RNG isolation, per-Zone plan identity, production-location data edits without a changed bake fingerprint, material sharing/exclusions, Lab Save/Revert/Delete and context preservation. The production-location case uses `--production-fixture` in a disposable checkout and restores its files exactly; the ordinary test does not write production files.

`tests/atmosphere_runtime_regression.gd` exercises two adjacent Ice Zones with different appearances from shared disk recipes, material isolation, switching and a distance-driven transition. It writes matched default/strong ABBA profiles and transition observations. `tests/atmosphere_profile.gd -- --atmosphere-hue` compares strong category/background/foliage/neon transforms in the Lab. Alex owns further performance and visual tuning review; additional performance testing was stopped at his request.

The follow-up uses `tests/atmosphere_color_ranges_regression.gd` for range boundaries, alpha/neutrals, source/gameplay isolation, stacking, exact reset and rendered texture/triplanar/vertex-color parity with StandardMaterial. `tests/atmosphere_surface_regression.gd` captures all eight live themes with terrain, Decor, selective-green and Neon edits, checks fullscreen layout, and uses `--baked-only` to inspect every published Prototype/Endless Act/theme recipe. These are functional checks, not performance benchmarks.

`tests/atmosphere_picker_regression.gd` exercises picking an already shifted scene color with Retro enabled, all three drag modes, fine adjustment, release/Esc and preservation of the pause, camera, ball and authored cloud-light state. The initial 17 checks passed in both the working checkout and the clean staged export, including directional fog. The authoring follow-up passed 26 checks, including real keyboard entry of “Gold VIP”, numeric entry in windowed/fullscreen views, the extended hue/brightness bounds and two-decimal display without losing fine fog precision. The variant regression passed 461 rendered checks (440 headless), including Default preset application, save/reload/reset and runtime selection of edited Default values.

Follow-up checks passed in the working checkout: 765 range/texture/stacking checks, 1,275 all-theme surface/UI checks, 560 Lab checks, 456 variant checks, 6,606 scenery checks and 111 batching checks. The clean staged export passed 765 range checks, 1,232 all-theme surface checks and 461 variant/production-fixture checks. All 96 published Act/theme recipes passed 5,994 binding checks; refreshed Prototype/Endless pools passed 401/465 audit checks. A six-transition streaming check passed 87 checks with disk recipes and no fallback. One existing ObjectDB exit warning remained. No follow-up performance benchmarks were run.

Initial production-system checks: variant/storage/Lab regression passed 458 checks in the clean export, including a real Act change; the existing atmosphere suite passed 476 there (492 with local art). Scenery passed 8,574 checks in the clean export and 6,606 in the working checkout. Prototype planning passed 41 checks; static batching passed 111. Runtime ownership/switching/transition checks passed 52. All 40 Prototype and 56 Endless recipes were refreshed and audited (387/451 checks). Streaming passed 256 checks over 27 transitions with zero fallback, and the minimal PCK loaded all eight production registries. Launcher/export PowerShell syntax checks pass.

Exploratory profiles completed before the manual-performance handoff are retained under ignored test results: the clean export's `test-results/atmosphere-hue/report.json` and `test-results/atmosphere-variants/runtime/report.json` in the working checkout. Strong hue transforms kept draw/object/material/resource counts unchanged in the matched samples; the all-eight mean GPU deltas were approximately −0.0005 to +0.002 ms. CPU/frame results are not isolated benchmarks: an interactive Lab was open, and the Lab profile also overlapped offline baking. These measurements do not establish whole-run FPS or second-hardware behavior.

The existing ObjectDB exit-warning class remains: 48 instances after the full tour; a six-transition verbose repeat reported four zero-reference RefCounted instances and no leaked scene nodes. Streaming still has preparation/frame-time outliers. Neither is claimed fixed by atmosphere authoring. Uncommitted art experiments remain separate, and no final look roster was authored automatically.
