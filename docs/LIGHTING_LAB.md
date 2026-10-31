# Lighting Lab

Double-click **`Lighting Lab.cmd`** at the repository root. It opens the existing authored Act player with **Forward+/Vulkan**, a lighting inspector and the current local artwork. Production launchers, project renderer, physics, authored Acts and baked Prototype/Endless data are unchanged.

## Inspect and play

- **Mouse wheel:** zoom around the cursor. **Middle-drag:** pan. Either enters inspection mode from Follow.
- **O / Overview / Follow:** switch between inspecting the Act and following the ball. **Frame Act** restores the full overview.
- **F6 / Hide:** collapse or reopen lighting controls. The world expands into the freed space.
- **Pause play / Resume play:** hold the ball while tuning; lighting and camera controls remain live. Time-driven scenery shaders may continue animating.
- Use the existing bottom **Theme**, **Load Act**, **Reload Act**, character and play controls. Existing flipper/steering controls and 120 Hz physics remain intact.
- **Retro** toggles the default world filter stack. F4 and the existing Retro panel remain available.

The inspector has three tabs:

| Tab | Controls |
|---|---|
| Light | Exposure; Linear/Reinhard/Filmic/ACES/AgX tonemapping; ambient energy/color and sky contribution; directional energy/color, elevation/azimuth and specular strength; color-adjustment toggle, contrast and saturation |
| Glow & Fog | Glow enable/intensity, bloom and threshold; material emission multiplier; sky/clear-background brightness; fog enable, density, color, brightness and sky influence |
| Shadows | Enable, opacity, directional softness, depth/normal bias, distance, and one/two/four shadow maps |

Numeric fields support typing and sliders. **Show original lighting** switches the live scene back to the loaded theme baseline without discarding the draft. Editing any value returns to the tuned preview. This is a same-renderer comparison, not an emulation of Compatibility lighting under Vulkan.

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
