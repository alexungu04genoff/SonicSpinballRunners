# Device shadow quality

Atmosphere owns shadow enablement, opacity, filter radius, physical sun angle, depth/normal bias and maximum distance. Device graphics owns atlas size, cascades, directional filter quality, FXAA, MSAA and native 3D scale.

## Controls and defaults

Open **Atmosphere Lab → Shadows**. The six **Device Quality** controls save immediately in the `rendering` section of `user://graphics_settings.cfg`.

| Key | Values | No saved preference |
| --- | --- | --- |
| `directional_shadow_resolution` | 2048, 4096, 8192 | Current project directional atlas size (8192) |
| `directional_shadow_cascades` | 1, 2, 4 | 4 |
| `ultra_filter` | Off / on | Project filter, currently Medium |
| `fxaa` | Off / on | Project screen-space AA, currently off |
| `msaa` | 0, 2, 4 samples | 4 |
| `scale_percent` | 75, 85, 100 | 100 |

Legacy `smooth_shadows=true` enables Ultra and FXAA. Explicit new keys take precedence independently. The first successful device save writes both keys and removes the legacy key. Reads preserve the file. Saves merge with the latest file and preserve unrelated keys.

**Shadow blur** scales the normal light filter radius from 0.50 to 2.00. Start at 1.00 and try 1.25 or 1.50. **Sun angle ° (PCSS, costly)** controls physical source size in Forward+. Old variants inherit a blur of 1.00 and retain any authored sun angle. The default angle is 0°. Both properties blend between Zones. The installed 4.7.2 binary confirmed their independent defaults. [Godot Light3D reference](https://docs.godotengine.org/en/4.7/classes/class_light3d.html#class-light3d-property-shadow-blur)

These preferences are local to the application's `user://` directory. Source Lab and Prototype share the game profile; the portable tools and their launched Prototype share the separate **Sonic Spinball Authoring Tools** profile. Copying Acts/Atmospheres or a ZIP does not transfer device preferences. Separate running processes load preferences on startup; they do not poll one another's files.

## Runtime ownership

`scripts/rendering_options.gd` is the single quality policy. The first viewport or light registration loads preferences before rendering gameplay. Resolution calls `RenderingServer.directional_shadow_atlas_set_size()` with the existing project depth precision; it never writes `project.godot`. Changes affect the whole renderer process, including all its viewports, without restarting. The Lab reports the size submitted to that API. Godot has no public atlas-size readback, so this is not a claim to independently measure the allocated GPU texture.

Directional light registrations use weak references and apply 1/2/4 cascades immediately. Live changes update existing lights; new lights inherit the policy. Covered paths:

- Shared table foreground, including Lab, normal Prototype, single-Act Prototype, and Endless.
- Source theme configuration and the temporary authoring/bake presenter, after theme setup.
- Atmosphere runtime configuration used by streamed Zone backdrops. These lights still have shadows explicitly disabled.
- Temporary foreground/background lights used to warm disk-baked visual recipes. Warm-up viewports also inherit FXAA.

Atmosphere lighting snapshots/blends contain no cascade mode. Cached light metadata does not own it. Registering a light never changes `shadow_enabled` or artistic properties. There are no per-frame scene scans and no geometry or baked-lighting architecture changes. Existing source-fingerprint rules can require an ordinary rebake after this code update; changing device preferences does not invalidate bakes.

Atlas size and cascade modes are supported by Forward+, Mobile and Compatibility, so the numeric preferences are shared across renderers. Ultra shadow filtering and FXAA require Forward+/Mobile. The Lab disables both toggles in Compatibility and retains the preferences for later supported launches. Angular softness retains its existing Forward+-only control. Headless runs explicitly state that they cannot compare rendered shadows.

Engine references: [global runtime atlas API and directional filtering](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-directional-shadow-atlas-set-size), [Compatibility light storage](https://github.com/godotengine/godot/blob/master/drivers/gles3/storage/light_storage.cpp), [renderer feature support](https://docs.godotengine.org/en/latest/tutorials/rendering/renderers.html#antialiasing).

## Legacy atmosphere compatibility

`sun/directional_shadow_mode` is retired, not repurposed. Older format-1 production variants, renderer-specific Lab drafts and playtest snapshots still load. The exact legacy key is ignored/removed in memory and never overrides device policy; other unknown fields still fail production validation. Loading does not rewrite files or change their revision hashes.

Explicit variant saves omit the retired field from all records in that theme file. Explicit Lab draft saves omit it only from the selected theme/renderer section, preserving other sections. New snapshots omit it. Save, Reload, Reset, Show Original, quick looks, theme changes and variant changes neither save nor reset device graphics. No existing production atmosphere resource is migrated on disk by this change.

## Laptop comparison

Extract the Shadow Review ZIP to a writable folder. Double-click **Shadow Review.cmd**. Option 1 opens the live Lab on the Shadows tab at B. Keep Act, camera, atmosphere and Retro fixed while switching A/B/C, FXAA, Ultra and Ring shadows. Review device changes last for that session. Ordinary Lab device changes persist. Option 2 runs the paired first/repeat benchmark. [Configurations, evidence and review instructions](SHADOW_REVIEW.md)

## Regression coverage

- `tests/device_shadow_regression.gd`: independent controls, defaults/invalid input, all eight themes, Save/Reload/Reset/Show Original, legacy read/save behavior and unchanged source hashes. Run a second process with `-- --reload-only` to verify disk persistence. Graphical runs also log texture-memory changes while resizing the real atlas.
- `tests/atmosphere_playtest_regression.gd`: Lab snapshot into the real Prototype session, foreground/background policy and runtime blend protection.
- `tests/prototype_variable_run_regression.gd`: ordinary disk-backed 1- and 7-Zone runs load preferences without a Lab, including resident/background/warm-up lights.
- `tests/portable_atmosphere_smoke.gd`: release executable live controls and fresh Lab instances; `--graphics-reload` additionally checks preferences from the previous process.

Human review still owns laptop performance, shadow quality, transitions and camera readability.

### Verification on 2026-11-04

Godot 4.7.2 / Windows / RTX 4060: 440 variant checks; 135 device-boundary checks in headless, Vulkan and Compatibility runs; 2 fresh-process persistence checks; 20 Lab-to-Prototype checks; 252 ordinary 1-/7-Zone Vulkan run checks; 31 graphical portable checks and 32 portable relaunch checks. All assertions passed. Vulkan atlas changes increased reported texture memory by 24 MiB from 2048 to 4096 and by 96 MiB from 4096 to 8192, consistent with live 16-bit atlas reallocations. This is allocation evidence, not a laptop FPS recommendation.

The broader headless production test emitted dummy-renderer mesh RID errors; the equivalent Vulkan run had no runtime errors but reported ObjectDB leaks at shutdown. Compatibility reported texture leaks at exit. The graphical portable multi-theme smoke completed its assertions but stalled in shutdown and was stopped; a separate normal portable launch/exit and headless relaunch both exited successfully. These cleanup limitations remain outside the shadow-ownership change. No production atmosphere bytes or project settings changed during verification. The portable ZIP passed CRC checks and its three entries matched the exported files byte-for-byte.
