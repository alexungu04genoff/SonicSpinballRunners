# Lighting Lab

Double-click **`Lighting Lab.cmd`** at the repository root. It opens the existing authored Act player with **Forward+/Vulkan**, a lighting inspector and the current local artwork. Production launchers, project renderer, physics, authored Acts and baked Prototype/Endless data are unchanged.

## Inspect and play

- **Mouse wheel:** zoom around the cursor. **Middle-drag:** pan. Either enters inspection mode from Follow.
- Wheel events over the lighting panel stay in the panel, including at either scroll limit and when it overlaps fullscreen Play View.
- **O / Overview / Follow:** switch between inspecting the Act and following the ball. **Frame Act** restores the full overview.
- **F6 / Hide:** collapse or reopen lighting controls. The world expands into the freed space.
- **Pause play / Resume play:** hold the ball while tuning; lighting and camera controls remain live. Time-driven scenery shaders may continue animating.
- Use the existing bottom **Theme**, **Load Act**, **Reload Act**, character and play controls. Existing flipper/steering controls and 120 Hz physics remain intact.
- **Retro** toggles the default world filter stack. F4 and the existing Retro panel remain available.
- The lab starts **uncapped with VSync off**. Its **VSync** switch optionally synchronizes rendering to the display; the adjacent counter shows FPS and average frame time. Physics remains 120 Hz. These are process-local lab settings, not production defaults.

The inspector has three tabs:

| Tab | Controls |
|---|---|
| Light | Exposure; Linear/Reinhard/Filmic/ACES/AgX tonemapping; ambient energy/color and sky contribution; directional energy/color, elevation/azimuth and specular strength; color-adjustment toggle, contrast and saturation |
| Glow & Fog | Glow enable/intensity, bloom and threshold; material emission multiplier; sky/clear-background brightness; fog enable, density, color, brightness and sky influence |
| Shadows | Enable, opacity, directional softness, depth/normal bias, distance, and one/two/four shadow maps |

Numeric fields support typing and sliders. **Show original lighting** switches the live scene back to the loaded theme baseline without discarding the draft. Editing any value returns to the tuned preview. This is a same-renderer comparison, not an emulation of Compatibility lighting under Vulkan.

## Quick lighting looks

The **Try a lighting look…** menu offers **Daytime, Morning, Sunset, Dusk, Night, Indoors, Overcast, Neon night, and Neutral inspection**, plus **Authored lighting**. Every look is available for every theme/Act. Energy, exposure, sky brightness, glow and emission are scaled relative to the active theme's original values, with mood-specific ambient/sun colors and sun direction. These are starting points for manual art review, not approved production palettes.

Morning/Sunset use low warm light; Dusk/Night use cooler, dimmer lighting; Indoors emphasizes warm ambient light; Overcast reduces direct-light contrast; Neon night raises the contribution of editable emission against darker surroundings. Neutral inspection uses white lighting and disables glow, fog and color adjustment. These looks do not add time-of-day simulation, indoor geometry, new local lights or weather. They leave shadow quality and physics unchanged. Scenery with fixed shader colors/emission may need separate tuning, especially for night looks.

Choosing a look replaces the current unsaved lighting draft. It never writes the saved preset automatically: **Save** keeps the result, **Reload** retrieves the saved choice, and **Reset / Authored lighting** returns to the theme baseline. Manual slider edits return the menu to its prompt. VSync and the performance counter are independent of lighting looks.

## Save and compare

**Save** stores one preset for the current **theme + renderer** in `user://lighting_lab_presets.cfg`. In a normal Windows launch this is under `%APPDATA%\Godot\app_userdata\Sonic Spinball Runners\`; **Open folder** opens the exact active location. Share that small configuration file to hand off chosen values. It contains lighting values only, not player settings or telemetry.

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

Emission changes private material copies, preserving source resources. It affects enabled standard-material emission and existing shader scales named `emission_scale`, `neon_strength` or `radiance`. Fixed shader expressions, such as part of Aquarium glass/water highlights, remain authored. Sky/clear brightness affects the environment background, not independently lit scenery meshes. Consequently, these controls do not guarantee complete Compatibility/Vulkan visual parity; glass, water, clouds or emissive shaders may still need focused material work.

Directional shadow softness uses PCSS and is enabled only on Forward+. It has a performance cost. Other renderer-supported properties can also have different visual effects across backends. See Godot's [Environment controls](https://docs.godotengine.org/en/stable/classes/class_environment.html) and [directional softness support](https://docs.godotengine.org/en/stable/classes/class_light3d.html#class-light3d-property-light-angular-distance). The lab adds no new postprocessing shader or production shader rewrite.

## Verification

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
