# Stronger theme signatures — 2026-11-08

The second-stage pass strengthens three large silhouettes while preserving the fictional late-Saturn / early-Dreamcast language. See [the audit, decisions and remaining questions](../../THEME_IDENTITY.md#stronger-signature-pass--2026-11). Green Hill remains the control. Rooftop, Casino, Sky and Aquarium are deliberately unchanged.

## Start here

- [Eight-theme spawn overview](eight-themes-spawn-overview.png) and [native sheet](eight-themes-spawn-native.png).
- [Eight-theme peripheral overview](eight-themes-edge-overview.png) and [native sheet](eight-themes-edge-native.png).
- Label-free small thumbnails: [spawn color](label-free-spawn-color.png), [spawn grayscale](label-free-spawn-grayscale.png), [peripheral color](label-free-edge-color.png), [peripheral grayscale](label-free-edge-grayscale.png).

Each label-free tile is 288 × 200. A consistent black rectangle masks the HUD/name corner and a small amount of adjacent scenery; the rest retains the whole gameplay frame. No missing scenery is reconstructed. Grayscale is a diagnostic copy only. The [thumbnail key](thumbnail-key.json) records order, dimensions and masking. These sheets inform human judgment; they are not automated recognition tests.

## Changed themes

Each native pair contains two unscaled 1440 × 1000 frames and a label strip. Open a `-before.png` or `-after.png` original if your viewer shrinks a pair. Detail crops retain native pixels.

| Theme | Matched gameplay views | Detail | Small comparison |
| --- | --- | --- | --- |
| Chemical Plant | [Spawn](chemical_plant-spawn-pair.png), [peripheral](chemical_plant-edge-pair.png), [hero](chemical_plant-hero-pair.png) | [Vessel waist and shoulder](details/vessel-pair.png) | [Three views](chemical_plant-thumbnails.png) |
| Ice Cap | [Spawn](ice_cap-spawn-pair.png), [peripheral](ice_cap-edge-pair.png), [hero](ice_cap-hero-pair.png) | [Broad crystal crown](details/crown-pair.png) | [Three views](ice_cap-thumbnails.png) |
| Lava Reef | [Spawn](lava_reef-spawn-pair.png), [peripheral](lava_reef-edge-pair.png), [hero](lava_reef-hero-pair.png) | [Caldera and orange cleft](details/caldera-pair.png) | [Three views](lava_reef-thumbnails.png) |

The full eight-theme sets include matched unchanged controls as well: Green Hill, Rooftop Run, Casino Night, Sky Sanctuary and Aquarium Park. Small framebuffer differences across runs are not claimed as source edits.

## Authority and reproduction

All originals come from the real Prototype session and validated disk recipes, with zero production fallback builds. The reference Act is First Try Smooth Decor, served Sonic, zero score, locked Goal, seed 18, published Default atmosphere, Forward+/Vulkan, 4× MSAA and 100% render scale. No camera behavior or graphics defaults change. Camera targets are spawn `(400, 500)`, peripheral `(570, 500)` and a supplemental hero view `(500, 500)` for the three changed themes.

All six capture sets include manifests and provenance. [The image index](index.json) records original hashes; [detail coordinates](details/coordinates.json) record exact crop rectangles. [Source scope](source-scope.json) identifies the three presentation constructors and the independently owned local artwork. [Recipe accounting](metrics.json) distinguishes complete baked workload from visible-frame draw cost. [Verification](verification.json) records actual completed checks.

Capture roots are under `test-results/theme-signature/`: `before-validated`, `before-edge`, `before-hero`, `after`, `after-edge`, `after-hero`. Initial before frames were captured before editing. The extra before hero view uses `before-source`, an isolated working-art snapshot with only the three theme constructors restored. Its source provenance records that reconstruction explicitly. The final snapshots preserve selected local artwork that is not owned by this commit. A separate renderer pass corrected the MSAA precompilation hint during this work; actual captured 4× quality is unchanged. The supplemental before source shares that current rendering policy.

Use `tools/capture_prototype_appearance.ps1` in each source state, passing `-CameraTarget` for matching alternate views and `-Themes chemical_plant,ice_cap,lava_reef` for the hero subset. Every source state must be imported and baked first. Then run:

```powershell
tools/export_theme_signature_comparisons.ps1 -CaptureRoot test-results/theme-signature -OutputRoot <new-output-directory>
```

The exporter rejects incomplete theme sets, fallback builds, mismatched gameplay state, camera, graphics, atmosphere, source Acts, scenery or renderer. It preserves the originals and applies downsampling/grayscale only to explicitly diagnostic outputs.

## Limits

Some spawn landmarks remain clipped, and authored quarter-turns expose edge-on shapes. The alternate frames show why those views alone should not trigger another size increase. Chemical's distant block buildings remain generic supporting architecture. Ice needs its crown/mountains/aurora in view to go beyond general winter scenery. Check Lava's deliberately simple dark mass in motion. Chemical floor/Ring competition, Lava hardware separation and Sky cloud facets remain human-review questions. No animation or new light was added, and mesh counts do not establish an FPS improvement.
