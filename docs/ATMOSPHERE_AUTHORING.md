# Atmosphere authoring

**Act geometry × Theme × Atmosphere Variant** is the accepted model. An atmosphere comprises **lighting + sky + the theme's environmental palette**. This milestone builds the manual instrument; it does not promote saved Lab values into production variants.

Launch **Lighting Lab.cmd** in the main project folder. This is the existing Lighting Lab extended with atmosphere authoring, using the same scene and saved presets. **Atmosphere Lab.cmd** forwards to that launcher with the same renderer/theme/Act arguments. Forward+/Vulkan is the Lab default; production renderer defaults are unchanged. Existing Light, Sky, Glow & Fog, Shadows, VSync, uncapped FPS, pause, theme switching, Act loading, wheel zoom and middle-drag pan remain available. F6 hides/reopens the inspector while keeping one FPS overlay.

## Palette

The new Palette tab displays only supported semantic controls for the loaded theme. It intentionally omits gameplay readability colors, tiny details, and a generic shader/material editor.

| Theme | Environmental controls |
| --- | --- |
| Green Hill | Ocean deep/wave, fake sky reflection, broad sun highlight, cloud shadow/highlight, distant vegetation and sand/stone tints |
| Chemical Plant | Reservoir deep/ripple, industrial cyan and signal pink |
| Rooftop Run | Canal deep/reflection, distant haze, shared architecture and vegetation tints |
| Casino Night | Four neon colors, skyline tint, purple accent, window gold, marquee and the two existing spill-light colors |
| Sky Sanctuary | Cloud-sea and cloud-bank shadow/highlight pairs, ruin haze |
| Ice Cap | Custom sky horizon/upper/glow, star tint/intensity, lake base/aurora reflection, three aurora colors and strength, crystal tint |
| Lava Reef | Four magma colors, cavern tint/deep/bounce, three crystal colors, embers and existing MagmaBounce light colors |
| Aquarium Park | Lagoon deep/wave, caustic glow, water and lantern reflection, glass base/glow tint, lantern paper/emission, coral, aquatic tint and both existing lantern spill-light colors |

Controls named **tint** multiply the authored shades, with white as neutral. Other colors address the named environmental role directly. Original comparison and Reset restore each bound material's exact authored shade, including slightly different source shades sharing a role. Existing emission multipliers are independent of palette colors. Aurora strength multiplies both curtains while retaining their authored relative strengths. Glass opacity and batching remain unchanged.

Sky Sanctuary and Green Hill keep cheap unshaded clouds. Changing sun elevation/azimuth updates their analytic light direction once on apply. Original atmosphere restores the original analytic direction as well as the colors.

## Compare, save and inspect

**Show original atmosphere** restores lighting, sky and palette together. The tuned draft remains intact. Editing a control returns to the tuned preview. Save always saves the tuned draft, even while comparing with originals.

The existing `user://lighting_lab_presets.cfg` location and `<renderer>/<theme>` sections are retained. Format v2 adds `palette/*` values:

- Version-1 lighting and sky values load unchanged. Missing palette values inherit the authored theme.
- The first v2 Save of a v1 file creates `lighting_lab_presets.cfg.v1-backup`, without replacing an existing backup. A failed backup stops that save.
- Save rereads the file, preserves other renderer/theme sections and unknown keys, and merges only the current draft. It refuses to downgrade a newer format.
- Unsaved drafts survive theme switching. Reload discards the current draft and reads disk. Reset previews the originals; it changes the saved preset only if followed by Save.

The Sky tab separates **Show far environment** from **Show local framing**. These inspection switches persist across theme switches within the session, but are not saved as atmosphere values. Hide far scenery to inspect the sky without losing useful Act-edge landmarks; hide both to see sky alone. They toggle existing scenery children, with no second hierarchy or changed bake/streaming ownership.

All thirteen existing quick-start looks remain. Sunset-related and Night-related looks now supply palette starting values where the relationship is clear. Neon night adds a few artificial-environment accents. Authored atmosphere restores the complete baseline. These recipes are deliberately editable starting points, not final Day/Sunset/Night variants, and are never saved automatically.

## Implementation and cost

`scripts/themes/theme_atmosphere.gd` defines the small vocabulary and explicit shader bindings. Themes/decor libraries tag selected shared material properties and existing light/sign properties. The Lab collects bindings once when the presentation changes. Palette and emission editing share one private copy per editable source material, regardless of how many nodes use it. No new material is allocated when a color changes, and no palette work or scene traversal runs each frame.

Generated presentation shaders can retain the same semantic role through an explicit `Atmosphere.tag(material, uniform, role, mode, {"shader": true})` binding. The uniform must already have an authored value. Local art integrations use this for Rooftop foliage and stone, so their palette controls remain effective after adding surface detail. Static scenery combiners must preserve `atmosphere_scenery` ownership and must not combine far and local geometry into one batch.

Existing shader color literals become uniforms while retaining their original rendering algorithms and linear defaults. The Lab converts sRGB picker colors to linear vectors once on apply. Standard-material colors retain Godot's normal color handling. This explicit conversion avoids accidentally darkening a former linear shader literal when introducing a color uniform; see Godot's [shader uniform/color-space guidance](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html#uniforms).

Ice's existing static custom sky remains `PROCESS_MODE_QUALITY` at radiance size 128. The Lab changes a sky uniform only when its value changes. A palette change can trigger one radiance update; there is no TIME dependency or continuous sky rebuild.

Green Hill's ocean is one opaque, unshaded plane with two broad moving sine waves, a fake reflection ribbon and a subtle broad sun ribbon. It adds no geometry, textures, lights, screen reads, transparency, reflection system or render pass. Its cyan authored palette stays recognizable. The measured old-flat/new-ocean comparison is separate from palette parameterization in [the performance report](ATMOSPHERE_PERFORMANCE.md).

Lava's reported Forward+ rectangular breakup was reproduced on an isolated plane without Retro, scenery or batching. Its large-multiplier sine hash produced discontinuous noise-cell boundaries. Replacing only the lattice hash with deterministic integer arithmetic removed those seams; the interpolation, domain warp, noise layers, flow, distance damping, material and composition remain. The precise driver/compiler floating-point optimization responsible was not traced. This is a bounded shader fix, not a new lava design.

## Framing and production boundary

The accepted [real-Act framing architecture](ENVIRONMENT_FRAMING.md) remains: shared far Zone backgrounds, local records baked against authored course outlines, Act-owned local retirement, existing batching and contour-following Ice aurora. No physics, scoring, authored Act geometry, streaming buffers or shadow topology changed.

New source shaders and material metadata invalidate existing source-hashed bakes deliberately. Bake Prototype and Bake Endless before using the updated production defaults; bake format remains version 7. Atmosphere presets themselves remain Lab-only and do not modify a bake or source theme. Transferring approved variants into streamed production is a later task.

## Review checklist

1. Choose an Act and theme, compare original, Sunset and Night with Retro both on and off.
2. Tune a few palette roles, compare originals, switch themes, return, Save and Reload.
3. Inspect sky, far environment and local framing separately; then restore both scenery switches.
4. Judge the ocean in motion and cloud/water contrast from gameplay views. Test the same settings on the work laptop before approving production variants.

Automated rendered coverage lives in `tests/atmosphere_lab_regression.gd`; the existing lighting smoke remains supported. `tests/atmosphere_profile.gd` records matched ABBA timings, preparation windows, pipeline counters and captures. See [measured results and limits](ATMOSPHERE_PERFORMANCE.md).
