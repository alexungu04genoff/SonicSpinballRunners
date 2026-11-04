# Lighting Lab — Atmosphere authoring

**Production variants (2026-11-01):** Named Theme atmospheres, weights, editable Default appearances, independent terrain-category/background/foliage/neon hue controls and deterministic Zone selection are now available in the same Lab. Default keeps its fixed name and entry; Show original atmosphere retains the authored comparison. See [Atmosphere Variants](ATMOSPHERE_VARIANTS.md). Older lab-only ownership statements below describe the initial authoring pass.

**Renderer update — 2026-11-01:** Production gameplay and editors now also default to Forward+/Vulkan. Earlier statements below about unchanged production defaults describe the original lab rollout. Saved atmosphere presets remain lab-only.

The current manual palette workflow, migration rules and implementation are documented in [Atmosphere authoring](ATMOSPHERE_AUTHORING.md).

Double-click **`Atmosphere Lab.cmd`** or **`Lighting Lab.cmd`** at the repository root. Both open the same current tool; there is no separate newer editor to locate. It opens the atmosphere inspector with **Forward+/Vulkan** and the current local artwork. Saved Lab presets do not modify production bakes; source shader changes require the normal rebake.

**Play Prototype (2026-11-04)** opens the currently loaded Act in the real single-Act Prototype session. The bottom Play button and the atmosphere action row both use this path. It carries the selected theme and all current lighting/palette values, including an unsaved Lab draft or variant edit. With **Show original atmosphere** enabled, it carries the visible original comparison instead. No Save Variant or production bake is required. The prototype uses its usual Goal, 1,000-point target, Practice retries and results.

The appearance is captured when Play is clicked. To test newer lighting edits, return to the Lab and click Play Prototype again. Restart inside Prototype reloads the Act while retaining that captured appearance. Changing theme in the test menu clears the Lab preview. Scenery composition continues to use the Act's saved scenery settings; use the Scenery tab's Save action for those edits. Viewport inspection toggles and camera framing are not production atmosphere settings.

Preview data is stored separately under `user://atmosphere_playtests`, validated with the existing atmosphere field rules and recorded in run telemetry. Production variant files, normal run preferences and best records remain unchanged. Thirteen focused Lab-to-Prototype checks pass headlessly and rendered; normal run planning retains 41 passing checks. Existing exported tools must be rebuilt to receive the new button.

## Inspect and play

- **Mouse wheel:** zoom around the cursor. **Middle-drag:** pan. Either enters inspection mode from Follow.
- Wheel events over the lighting panel stay in the panel, including at either scroll limit and when it overlaps fullscreen Play View.
- **O / Overview / Follow:** switch between inspecting the Act and following the ball. **Frame Act** restores the full overview.
- **F6 / Hide:** collapse or reopen lighting controls. The world expands into the freed space.
- **Pause preview / Resume preview:** hold the inspection ball while tuning; lighting and camera controls remain live. Time-driven scenery shaders may continue animating.
- Use the bottom **Theme**, **Load Act** and **Reload Act** controls to choose the inspection context. **Play Prototype** opens that context for gameplay testing; the Lab stays open for editing.
- **Retro** toggles the default world filter stack. F4 and the existing Retro panel remain available.
- The lab starts **uncapped with VSync off**. Its **VSync** switch optionally synchronizes rendering to the display. A top-left counter shows FPS and average frame time, refreshed twice per second, including with the inspector hidden and in fullscreen Play View. Physics remains 120 Hz. These are process-local lab settings, not production defaults.

The inspector includes these lighting tabs (alongside Variants, Hue and Scenery):

| Tab | Controls |
|---|---|
| Light | Exposure; Linear/Reinhard/Filmic/ACES/AgX tonemapping; ambient energy/color and sky contribution; directional energy/color, elevation/azimuth and specular strength; color-adjustment toggle, contrast and saturation |
| Sky | Background brightness; procedural sky top/horizon and ground bottom/horizon colors, with separate sky/ground blends; solid background color where applicable; background scenery visibility |
| Palette | Theme-specific water, cloud, scenery, accent and existing spill-light colors; supported intensity controls |
| Glow & Fog | Glow enable/intensity, spread, tight/wide/diffuse halo weights, brightness normalization, bloom and threshold; material emission multiplier and supported surface-halo width; ordinary fog enable, mode, density, depth start/end distance, curve, color, brightness and sky influence |
| Directional Fog | Independent enable, angle, start offset, fade length, maximum density, curve, color and brightness |
| Shadows | Enable, opacity, directional softness, depth/normal bias, distance, and one/two/four shadow maps |

Numeric fields support typing and sliders. Mouse-wheel input over sliders scrolls the inspector without changing their values; color-picker sliders also ignore wheel adjustments. **Show original atmosphere** switches the live lighting, sky/background and theme palette back to the loaded theme baseline without discarding the draft. Turning it off restores the tuned atmosphere. Editing any value returns to the tuned preview. This is a same-renderer comparison, not an emulation of Compatibility lighting under Vulkan.

In **Palette**, trim has three groups: **Edges** (outer floor rims), **Borders** (trim around raised terrain bases), and **Ledges** (upper trim). Each has hue, saturation, brightness, an override of Terrain, and Stack with Hue. **Link edges and ledges to borders** starts on for compatibility with existing appearances. Turn it off and enable the desired overrides for separate edits. While linked, Borders is the master and independent controls are disabled without losing their saved values.

## Glow shaping

**Emission multiplier** changes how bright the emitters are; it does not change their size. Enable **Glow** to shape the screen-space halo in every theme. **Glow spread** adjusts its blur spread. Lower **Tight halo** and raise **Wide / soft halo** or **Diffuse halo** for a broader, smoother result. **Normalize halo brightness** balances the active halo weights; use **Glow intensity** to set the resulting halo brightness. A useful starting point is Tight `0.10`, Wide `0.80`, Diffuse `0.70`, normalization on, and intensity `0.65`. These are suggestions, not new defaults.

**Surface halo width** appears only when the active materials expose a supported built-in halo. In the current local Chemical artwork it scales both the floor-panel and edge-strip falloff from their authored radii (`1.00` is unchanged). This is separate from screen glow: it widens the light painted onto the surface without changing the solid lamp geometry. Other current themes use the shared screen-glow controls. Source materials and the user's existing appearances remain unchanged until edited; all new controls save with drafts and production variants, and native glow settings blend between streamed Zones.

Retro adds its own phosphor halo after the scene. Compare with Retro off when shaping native glow, then turn it back on for the final look. No new lights, custom screen effects, materials or geometry are added by adjusting these controls; they reuse the existing material uniforms and Godot glow settings. Performance tuning remains a manual check.

## Fog shaping

Ordinary fog retains its Exponential mode and adds **Depth / distance** mode. Start/end distance and curve apply only in Depth mode; distances are measured radially from the camera in 3D units (1 unit = 100 table pixels). The Lab estimates the visible table plane's distance interval and scales the start/end sliders to that interval instead of a 1,000/2,000-unit range. **Fit distances to view** places the start just inside the visible near edge and the end at the far edge. Camera/zoom changes update slider bounds only; saved fog distances remain fixed, including existing presets. Numeric fields can enter distances outside the visible interval. End distance 0 uses the camera far plane. In Depth mode density means maximum opacity, so try 0.5 instead of the small values used for Exponential fog. Higher curve values delay buildup. Exponential mode does not use start/end distance.

The viewport-fit follow-up passed 31 fog checks, including perspective/top-down distance estimates, fixed saved values while zooming, live application, persistence and streamed transitions. The input/picker regression passed 29 checks, including typing 0.01 into a distance field with 0.5 arrow increments and preserving fine fog density when focusing/leaving the field. This changes authoring controls only; native fog rendering and production saved-value semantics are unchanged.

**Directional Fog** is separate and disabled by default. It builds across the table: 0° points north, 90° east, ±180° south. The origin is the view's center ray at table height, so the clear area travels with the camera. Start offset and fade length use table pixels; negative start brings fog toward the viewer. Maximum density caps opacity; curve, color and brightness are independent. Try the defaults, then adjust start and length to protect the flippers and nearby shots. Both fog types may be enabled together.

Both sets of controls participate in draft saves, original comparison and production variants. Streamed foreground fog blends between Zones; each background viewport owns its own directional pass. This optional pass is allocated only when enabled and is hidden when disabled. It uses opaque depth, leaves empty sky untouched, and does not change physics or source materials. Transparent surfaces use the opaque depth behind them; inspect glass and water when tuning. Final color, density and readability remain manual art decisions.

## Shadow baseline

The shared Atmosphere baseline enables shadows with opacity **0.85**, softness **0.00**, depth bias **0.02**, and normal bias **0.55**. The Lab and production Zone runtime apply these defaults after theme or cached lighting setup, before explicit saved atmosphere overrides. Existing saved overrides remain authoritative; shadow distance and split mode are unchanged. Background scenery lights remain shadowless.

The rendered Lab smoke passed 1,419 checks across all eight themes, including these defaults, saved shadow overrides, older cached lighting values, and actual wheel input over a slider scrolling the inspector without changing the value or camera zoom.

Softness is the sun's angular size, enabling contact-hardening shadows above zero. Increasing it can reveal the shadow filter's sampling/dither pattern, especially in a large penumbra; Retro may accentuate that pattern. Zero disables this variable softness. See [Godot's shadow filtering explanation](https://docs.godotengine.org/en/4.5/tutorials/3d/lights_and_shadows.html#shadow-filter-mode).

**Shadows → Smooth shadows · Ultra + FXAA** is an optional device setting. It raises native directional shadow filtering from the project's Medium default to Ultra and enables FXAA on the 3D world viewports. The comparison at 1° angular softness showed substantially cleaner bumper/enemy shadows and less speckling around thin ring shadows, with and without Retro. Large penumbras can still expose limited sampling; this is an improvement, not a guarantee of noise-free shadows at every softness. FXAA slightly smooths the image and Ultra costs more GPU work. MSAA remains unchanged, TAA stays off, and parent UI is unaffected.

The toggle defaults off, applies immediately in the Lab, and persists in `user://graphics_settings.cfg` for future gameplay launches, including streamed background viewports. It is independent of per-Zone atmospheres; changing a preset never toggles rendering quality. Disabling restores the project filter/FXAA defaults. No performance benchmark was run; Alex owns that review. The native Medium/High/Ultra/FXAA/TAA comparison images are under ignored `test-results/shadow-softness/`.

## Sky and background types

The Sky tab adapts to the active theme's actual Environment and sky material:

- **Green Hill, Sky Sanctuary, Rooftop Run, Chemical Plant, Casino Night and Aquarium Park:** four procedural-sky colors and two horizon blends. Edits use private Sky/material copies. Ground colors matter in the downward-looking gameplay camera; top/horizon colors matter when the sky above the horizon is visible.
- **Lava Reef:** background color and brightness, without procedural-sky fields.
- **Ice Cap:** background brightness in Sky, with custom gradient, glow and star controls in Palette. The existing static radiance technique remains.

**Show far environment** and **Show local framing** independently toggle the existing scenery children. Both are inspection-only and survive theme switches in the session. Hide far scenery to inspect sky while retaining Act-owned landmarks. Palette now controls theme-owned water, clouds and accents as well.

## Quick atmosphere looks

The **Try an atmosphere…** menu offers **Daytime, Morning, Golden hour, Sunset, Dusk, Blue hour, Night, Moonlit, Indoors, Overcast, Stormfront, Neon night, and Neutral inspection**, plus **Authored atmosphere**. Every look is available for every theme/Act. Energy, exposure, background brightness, glow and emission are scaled relative to the active theme's original values, with mood-specific ambient/sun colors and sun direction. Compatible sky/background colors are included in the same draft. These are starting points for manual art review, not approved production palettes.

Morning/Sunset use low warm light; Dusk/Night use cooler, dimmer lighting; Indoors emphasizes warm ambient light; Overcast reduces direct-light contrast; Neon night raises the contribution of editable emission against darker surroundings. Neutral inspection uses white lighting and disables glow, fog and color adjustment. These looks do not add time-of-day simulation, indoor geometry, new local lights or weather. They leave shadow quality and physics unchanged. Theme palette recipes now provide starting water/cloud/background colors where the mapping is clear; all remain editable.

**Golden hour** keeps more warm sunlight than Sunset. **Blue hour** gives a cool twilight transition. **Moonlit** is a more readable, brighter alternative to Night. **Stormfront** uses a subdued slate palette and weak direct light, without adding weather. Sunset pairs a blue/purple upper sky with peach/orange horizons and a darker mauve bottom. Night/Moonlit use navy and blue horizons; Neon night uses nearly black surroundings. Daytime and Neutral inspection retain the theme's authored sky palette. Ice's custom sky now receives supported palette recipes as well as brightness.

Choosing a look replaces the current unsaved atmosphere draft. It never writes the saved preset automatically: **Save** keeps the result, **Reload** retrieves the saved choice, and **Reset / Authored atmosphere** returns to the theme baseline. Manual slider edits return the menu to its prompt. VSync, the performance counter and scenery visibility are independent of atmosphere looks.

## Save and compare

**Save** stores one preset for the current **theme + renderer** in `user://lighting_lab_presets.cfg`. In a normal Windows launch this is under `%APPDATA%\Godot\app_userdata\Sonic Spinball Runners\`; **Open folder** opens the exact active location. Share that small configuration file to hand off chosen values. Format v2 contains lighting/environment, compatible sky/background and semantic palette values, not player settings or telemetry. Existing v1 presets still load; missing fields use theme originals. First v2 Save preserves a v1 backup. Unsupported fields do not transfer between sky types.

Saved presets reload automatically on launch/theme selection. Unsaved theme drafts survive switching themes within the current process. **Reload** discards the current draft and reads its saved preset, or originals if none exists. **Reset** restores original values in the preview; it does not replace the saved preset until Save is clicked. Saving while showing originals still saves the tuned draft. The comparison checkbox never erases it.

Presets are lab-only. Approving and transferring values into production themes, including streamed background environments and rebaking affected content, is a separate change. Theme originals are reconstructed from a fresh Environment before applying that theme's configuration, preventing exposure/fog carry-over between inspections. Existing local Rooftop lighting is included when that optional material tool is present.

Optional launches from PowerShell at the repository root:

```powershell
& '.\Lighting Lab.cmd' -Theme aquarium_park
& '.\Lighting Lab.cmd' -Renderer Mobile -Theme chemical_plant
& '.\Lighting Lab.cmd' -Renderer Angle -Theme sky_sanctuary
& '.\Lighting Lab.cmd' -Act 'res://data/acts/Authored/RampMania.tres'
# If Godot is not found automatically:
& '.\Lighting Lab.cmd' -GodotPath 'C:\path\to\Godot_console.exe'
```

Renderer changes require relaunching. Each launch explicitly selects its method/driver and writes `.godot/lighting-lab-<Renderer>.log`. The inspector shows the actual active method. Use one rendering process at a time for meaningful performance comparisons. The repo must already be imported, as in the regular development workflow; this launcher does not silently reimport or rewrite editor/project settings.

## Scope and useful tuning order

Start with exposure and tonemapper, then balance ambient and sun. Compare with Retro disabled before tuning glow, emission and fog. Check both a close gameplay camera and full overview before changing shadow bias or distance. Bias can cause floating shadows; shorter distance can remove distant shadows; one map can blur nearby shadows. None of those quality changes are applied by default.

Emission changes private material copies, preserving source resources. It affects enabled standard-material emission and existing shader scales named `emission_scale`, `neon_strength` or `radiance`. Palette exposes selected environmental shader colors, including Aquarium glass/water highlights. Sky/clear brightness affects the environment background, not independently lit scenery meshes. Consequently, these controls do not guarantee complete Compatibility/Vulkan visual parity; glass, water, clouds or emissive shaders may still need focused material work.

Directional shadow softness uses PCSS and is enabled only on Forward+. It has a performance cost. Other renderer-supported properties can also have different visual effects across backends. See Godot's [Environment controls](https://docs.godotengine.org/en/stable/classes/class_environment.html) and [directional softness support](https://docs.godotengine.org/en/stable/classes/class_light3d.html#class-light3d-property-light-angular-distance). The lab adds no new postprocessing system; theme shader changes preserve existing algorithms except the small ocean addition and Lava hash correction described in the authoring guide.

## Verification history

The entries below describe the earlier lighting/sky milestones. The subsequent full atmosphere implementation and current checks are recorded in [Atmosphere performance](ATMOSPHERE_PERFORMANCE.md).

`tests/lighting_lab_smoke.gd` exercises actual controls and live scene properties, original/tuned comparison, save/reload/reset, theme draft isolation, wheel zoom, middle-drag pan, panel reopening, material emission, all eight themes and unchanged physics/score. Run it in an isolated application profile to keep test presets separate from manual choices:

```powershell
$env:APPDATA = Join-Path $PWD 'test-results\lighting-profile'
$env:LOCALAPPDATA = $env:APPDATA
& $godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tests/lighting_lab_smoke.gd
```

Rendered screenshots are written under ignored `test-results/lighting-lab/<method>/`. Human review still owns the selected aesthetic, glare, cloud detail, ball readability and shadow quality. This standalone inspector does not validate a finished streamed-run lighting migration.

Verification on 2026-10-31: all eight themes rendered under Forward+, Mobile and ANGLE, with **44/44** smoke checks passing on each. A clean HEAD source copy plus only this task's additions imported, parsed all nine changed/new diagnostic/lab scripts, and passed the same headless smoke without local art tools. The final headless suite passed **45/45**, adding verification that saving one renderer's preset preserves a preset saved by another window. Existing restricted-profile certificate-store messages and local Casino image-loader/export warnings are unrelated to the lab; no new script or shader error was observed.

The scroll/FPS/quick-look follow-up uses lightweight runtime profiling and visual/UI review, without adding dedicated tests. The old lab's initial VSync mode was enabled, with `Engine.max_fps = 0` and a measured display refresh of 59.95 Hz; the sampled view ran at 59.96 FPS. Disabling VSync lifted that same Green Hill opening view to 210–229 FPS with the original panel visible and 229–243 FPS with its CanvasLayer hidden. Camera, world size (460×363), lighting and simulation stayed fixed; normal F6 hiding resizes the world and is not an equivalent comparison. Two 400-frame pairs put the panel's median difference at roughly 0.36–0.52 ms. Disabling its idle processing after hiding it did not consistently improve timing. The revised lab starts with VSync disabled and remains above 60 FPS in this view. These short, sequential samples do not reproduce or explain an exact 50 FPS dip at an unknown camera/quality setting; they do not establish a large idle-slider bottleneck or promise whole-run FPS.

Additional Forward+ samples recorded approximately 202 FPS in the windowed authored opening, 186 with directional softness at 5°, 195 in fullscreen Follow view (757×473 world buffer), and 185 in that fullscreen view with softness at 5°. These are distinct camera/resolution workloads, not an isolated fullscreen speed comparison. Actual dispatched wheel input at the panel's lower scroll limit left camera transform and zoom unchanged in overlapping fullscreen layout; input over the level still changed zoom. All nine looks plus authored lighting were rendered for Green Hill, Chemical Plant and Aquarium for visual review. Raw follow-up timings and captures are local under ignored `test-results/lighting-lab-followup/`.

The atmosphere follow-up was reviewed on Forward+/Vulkan using temporary runtime scripts and captures under ignored `test-results/lighting-atmosphere/`; no dedicated tests were added. Green Hill and Sky Sanctuary Sunset/Night, Lava Reef solid backgrounds, and Ice Cap Dusk/Night rendered successfully. Additional Green Hill looks covered Golden hour, Blue hour, Moonlit and Stormfront. Direct sky-facing captures checked the gradients without scenery or Retro, and matched sky/ground horizon colors removed a hard seam. All eight themes showed the appropriate fields. Live color/blend changes, scenery visibility across switches, original/tuned comparison, save/reload/reset, older lighting-only presets, renderer isolation and unchanged paused physics were checked. Saving during original comparison retained the tuned sky. FPS remained visible with the inspector hidden and in fullscreen; the reopen button was corrected to stay on-screen. Native float round-trips were compared approximately. Both runtime reviews finished without assertion failures or script/shader errors; the existing certificate-store warning remained. Hashes of all 1,285 pre-existing modified/untracked files were unchanged. Production sky/material sources were not edited.
