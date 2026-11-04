# Device shadow quality

Atmosphere owns shadow enablement, opacity, angular softness, depth/normal bias and maximum distance. Device graphics owns directional atlas resolution, cascade count and the existing smooth-shadow convenience toggle. Selecting a mood never changes those device choices.

## Controls and defaults

Open **Atmosphere Lab > Shadows**, then scroll from **Shadow Appearance** to **Device Shadow Quality**. Resolution (2048 / 4096 / 8192) and cascades (1 / 2 / 4) are independent controls. Changes save immediately in `user://graphics_settings.cfg`, section `rendering`:

| Key | Values | No saved preference |
| --- | --- | --- |
| `directional_shadow_resolution` | 2048, 4096, 8192 | Current project directional atlas size (8192) |
| `directional_shadow_cascades` | 1, 2, 4 | 4 |
| `smooth_shadows` | Boolean | false: existing project filter and screen-space AA defaults |

Smooth shadows enables Ultra directional filtering plus FXAA on registered viewports. Turning it off restores the project defaults (currently Medium filtering and disabled FXAA), without changing MSAA. Invalid saved types or choices fall back independently. Saves merge with the latest graphics file; write failures retain the active settings and report an error in the Lab.

These preferences are local to the application's `user://` directory. Source Lab and Prototype share the game profile; the portable tools and their launched Prototype share the separate **Sonic Spinball Authoring Tools** profile. Copying Acts/Atmospheres or a ZIP does not transfer device preferences. Separate running processes load preferences on startup; they do not poll one another's files.

## Runtime ownership

`scripts/rendering_options.gd` is the single quality policy. The first viewport or light registration loads preferences before rendering gameplay. Resolution calls `RenderingServer.directional_shadow_atlas_set_size()` with the existing project depth precision; it never writes `project.godot`. Changes affect the whole renderer process, including all its viewports, without restarting. The Lab reports the size submitted to that API. Godot has no public atlas-size readback, so this is not a claim to independently measure the allocated GPU texture.

Directional light registrations use weak references and apply 1/2/4 cascades immediately. Live changes update existing lights; new lights inherit the policy. Covered paths:

- Shared table foreground, including Lab, normal Prototype, single-Act Prototype, and Endless.
- Source theme configuration and the temporary authoring/bake presenter, after theme setup.
- Atmosphere runtime configuration used by streamed Zone backdrops. These lights still have shadows explicitly disabled.
- Temporary foreground/background lights used to warm disk-baked visual recipes. Warm-up viewports also inherit FXAA.

Atmosphere lighting snapshots/blends contain no cascade mode. Cached light metadata does not own it. Registering a light never changes `shadow_enabled` or artistic properties. There are no per-frame scene scans and no geometry or baked-lighting architecture changes. Existing source-fingerprint rules can require an ordinary rebake after this code update; changing device preferences does not invalidate bakes.

Atlas size and cascade modes are supported by Forward+, Mobile and Compatibility, so the numeric preferences are shared across renderers. Ultra shadow filtering and FXAA require Forward+/Mobile. Compatibility disables that toggle, states that both features are unavailable, and preserves the saved preference for a later supported launch. Angular softness retains its existing Forward+-only control. Headless runs explicitly state that they cannot compare rendered shadows.

Engine references: [global runtime atlas API and directional filtering](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-directional-shadow-atlas-set-size), [Compatibility light storage](https://github.com/godotengine/godot/blob/master/drivers/gles3/storage/light_storage.cpp), [renderer feature support](https://docs.godotengine.org/en/latest/tutorials/rendering/renderers.html#antialiasing).

## Legacy atmosphere compatibility

`sun/directional_shadow_mode` is retired, not repurposed. Older format-1 production variants, renderer-specific Lab drafts and playtest snapshots still load. The exact legacy key is ignored/removed in memory and never overrides device policy; other unknown fields still fail production validation. Loading does not rewrite files or change their revision hashes.

Explicit variant saves omit the retired field from all records in that theme file. Explicit Lab draft saves omit it only from the selected theme/renderer section, preserving other sections. New snapshots omit it. Save, Reload, Reset, Show Original, quick looks, theme changes and variant changes neither save nor reset device graphics. No existing production atmosphere resource is migrated on disk by this change.

## Laptop comparison

Extract the portable authoring ZIP into a writable folder, open **Atmosphere Lab.exe**, choose **Shadows**, and scroll to **Device Shadow Quality**. Disable VSync for uncapped FPS. Keep the same Act, camera, atmosphere and Retro state while trying:

1. 8192 / 4 (current baseline)
2. 4096 / 4
3. 4096 / 2
4. 2048 / 2
5. 4096 / 1

Compare edges, distant shadows, cascade transitions and FPS after shader/atlas warm-up. Toggle smooth shadows independently. Use **Play Prototype** to carry the visible appearance into a single-Act game with the same saved device quality. No new production default or quality preset is selected by these tests.

## Regression coverage

- `tests/device_shadow_regression.gd`: independent controls, defaults/invalid input, all eight themes, Save/Reload/Reset/Show Original, legacy read/save behavior and unchanged source hashes. Run a second process with `-- --reload-only` to verify disk persistence. Graphical runs also log texture-memory changes while resizing the real atlas.
- `tests/atmosphere_playtest_regression.gd`: Lab snapshot into the real Prototype session, foreground/background policy and runtime blend protection.
- `tests/prototype_variable_run_regression.gd`: ordinary disk-backed 1- and 7-Zone runs load preferences without a Lab, including resident/background/warm-up lights.
- `tests/portable_atmosphere_smoke.gd`: release executable live controls and fresh Lab instances; `--graphics-reload` additionally checks preferences from the previous process.

Human review still owns laptop performance, shadow quality, transitions and camera readability.

### Verification on 2026-11-04

Godot 4.7.2 / Windows / RTX 4060: 440 variant checks; 135 device-boundary checks in headless, Vulkan and Compatibility runs; 2 fresh-process persistence checks; 20 Lab-to-Prototype checks; 252 ordinary 1-/7-Zone Vulkan run checks; 31 graphical portable checks and 32 portable relaunch checks. All assertions passed. Vulkan atlas changes increased reported texture memory by 24 MiB from 2048 to 4096 and by 96 MiB from 4096 to 8192, consistent with live 16-bit atlas reallocations. This is allocation evidence, not a laptop FPS recommendation.

The broader headless production test emitted dummy-renderer mesh RID errors; the equivalent Vulkan run had no runtime errors but reported ObjectDB leaks at shutdown. Compatibility reported texture leaks at exit. The graphical portable multi-theme smoke completed its assertions but stalled in shutdown and was stopped; a separate normal portable launch/exit and headless relaunch both exited successfully. These cleanup limitations remain outside the shadow-ownership change. No production atmosphere bytes or project settings changed during verification. The portable ZIP passed CRC checks and its three entries matched the exported files byte-for-byte.
