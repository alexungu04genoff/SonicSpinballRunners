# Production Default atmosphere signatures — 2026-11-09

Alex narrowed this pass to **Green Hill, Chemical Plant, Rooftop Run and Casino Night**, and confirmed that **Retro stays on in production**. Retro ON is the final appearance gate. OFF images are lighting diagnostics only. Sky Sanctuary, Ice Cap, Lava Reef and Aquarium Park are deferred until their texture rework; their atmosphere files remain untouched.

Starting pushed main: `6c06cc0c128a8a8148e4c4630b0adee1915095e8`. Existing local selected artwork, material work, Acts and named atmosphere variants are preserved. Evidence includes that explicitly recorded artwork, as in the preceding identity-coverage pass.

## Audit before production edits

The audit uses validated disk-only Prototype recipes for First Try Smooth Decor, seed 18, served Sonic, zero score, locked Goal, fixed time and a 1440×1000 window. Camera targets match the coverage pass: spawn `(400,500)`, mid `(300,250)`, upper `(350,125)`. Both Retro modes retain 4× MSAA, 100% 3D scale and unchanged device shadow settings. Production Retro uses the existing N64/VHS/CRT stack, including its authored internal resolution treatment; no Retro parameter is edited.

| Theme | Current atmosphere identity | Strong | Weak / generic | Readability risk | Proposed action |
| --- | --- | --- | --- | --- | --- |
| Green Hill | Clear tropical daylight, cyan sea and warm green terrain | Retro delivers vivid cheerful grass, blue water and crisp silhouettes at all three tiers | Course-filled views show little sky, but the light/material relationship is already distinctive | Palm shadows cross Rings; existing silhouettes remain readable | Keep the Default as the daylight control. No extra fog, glow or golden-hour tint. |
| Chemical Plant | Cool industrial blue with cyan/yellow floor lamps and pink vessels | Machinery remains visible; blue/cyan/magenta separation communicates the Zone | Wide repeated floor halos dominate both native and Retro views; surroundings are too evenly bright | Yellow floor spill overlaps Ring rows and the locked Goal; Retro expands the competition | Tighten existing surface halos, reduce environmental emission, deepen cool ambient/key lighting and reservoir tones. Preserve Rings and all gameplay materials. |
| Rooftop Run | Warm cream/terracotta afternoon with angled shadows | Retro already gives bright postcard blocks; cream walls, orange roofs and blue-green shadows separate well | Lower view has little blue sky, but upper architecture and long shadows establish the atmosphere | Sunlit paving is relatively close to Ring luminance; dark Ring outlines/shadows remain visible | Keep the Default. More warmth or exposure risks washing out cream masonry and Rings. |
| Casino Night | Saturated blue playing deck, red/gold surrounds, pink/cyan decorative neon | Rings, flippers and bumper emblems remain clear; night backdrop is already dark | Broad cool lighting makes the deck and housings feel unusually evenly lit for a night casino | Existing tall cyan fixture competes with nearby Rings; raising bloom globally would worsen it | Lower cool ambient/key energy, use a steeper independent sun direction, deepen night sky, and tune existing emission/glow for contrast. |

The audit was completed before editing the production Default values. All accepted baseline batches passed fresh-process authority/freshness checks with zero source fallback. The initially attempted sandbox capture is excluded because it could not write Godot cache/log files. A superseded partial eight-theme upper batch is also excluded.

Static frames do not prove motion readability. The three targets expose Rings, Goal, Ball, enemies, flippers and bumpers. Supplemental mechanism views are recorded below.

## Production result

| Theme | Before → after | Changed fields and intent |
| --- | --- | --- |
| Chemical Plant | Even blue industrial light with broad yellow floor spill → darker cool machinery with tighter cyan/yellow lamps and clearer magenta liquid | Ambient energy 0.68→0.52 and cooler color; sun energy 0.85→0.65; environmental emission 0.55→0.42; surface halo spread 1.35→0.55; glow threshold 0.85→1.10 and intensity 0.62→0.48. Deeper violet sky/horizon and reservoir deep/ripple colors. Retro already contributes substantial halo, so stronger identity comes from controlled spill and contrast. |
| Casino Night | Broad blue fill and uniform illumination → darker violet night surroundings, steeper shadows and more localized neon | Ambient energy 0.60→0.42 and cooler color; sun energy 0.72→0.56, pitch −58°→−72°, yaw −32°→24°; darker sky/ground horizon. Environmental emission 0.80→0.90, with glow threshold 0.95→1.15 and intensity 0.70→0.64 to contain the existing Retro halo. The blue deck remains readable; the improvement is subtler than Chemical's. |
| Green Hill | Cheerful tropical daylight retained | No Default edit. The daylight control already works with production Retro. |
| Rooftop Run | Warm architectural afternoon retained | No Default edit. Preserve cream/terracotta blocks and angled shadows without pushing Ring brightness competition. |

Exact Default deltas are in [changed-fields.json](changed-fields.json). Named variants, hue/palette overrides, exposure, tonemapper, device quality, gameplay materials, geometry and camera behavior are unchanged. Ordinary and directional fog remain disabled in these four Defaults. Existing glow remains enabled; no optional rendering path is newly enabled. The other four themes are deferred, not artistically approved by this pass.

## Matched evidence

Primary comparisons preserve each complete 1440×1000 output frame at 1:1 pixels. “Native” here means output pixels: production Retro intentionally retains its authored lower internal resolution. The extra 40-pixel header is outside gameplay. Before is left; after is right. Captures are frozen, disk-loaded Prototype single-Act sessions, with no source fallback.

| Theme | Retro ON: production review | Retro OFF: lighting diagnostic |
| --- | --- | --- |
| Chemical Plant | [Spawn](pairs/production/chemical_plant-spawn.png) · [Mid](pairs/production/chemical_plant-mid.png) · [Upper](pairs/production/chemical_plant-upper.png) | [Spawn](pairs/off/chemical_plant-spawn.png) · [Mid](pairs/off/chemical_plant-mid.png) · [Upper](pairs/off/chemical_plant-upper.png) |
| Casino Night | [Spawn](pairs/production/casino_night-spawn.png) · [Mid](pairs/production/casino_night-mid.png) · [Upper](pairs/production/casino_night-upper.png) | [Spawn](pairs/off/casino_night-spawn.png) · [Mid](pairs/off/casino_night-mid.png) · [Upper](pairs/off/casino_night-upper.png) |

Final native-output sheets: [Retro ON](four-themes-production.png) and [Retro OFF](four-themes-off.png). Label-free diagnostic thumbnails: [ON](label-free-production.png) and [OFF](label-free-off.png), ordered Green Hill / Chemical / Rooftop / Casino in rows and spawn / mid / upper in columns. These thumbnails are downscaled and mask the HUD; they are not primary pixel comparisons. No grayscale sheet was necessary.

[Pair verification](pair-verification.json) records all 24 theme/mode/tier comparisons. Green Hill and Rooftop deliberately reuse their unchanged baseline frames as controls, rather than pretending identical images came from separate after runs. [Receipts](receipts/) preserve the complete capture manifests, source hashes, local-art provenance and successful fresh-process checks. The two eight-theme OFF baseline batches predate the scope reduction; only the selected four are reviewed here.

The later supported Orbit Garden bake regenerated the four shared background resource files. Earlier before/after resource hashes are capture-time receipts, not a promise of byte-identical serialization after rebaking. Source/pipeline fingerprints remain unchanged and the subsequent [current-disk captures and receipts](final-current-disk/manifest.json) pass all 83 freshness checks. [Final verification sheet](final-current-disk/sheet.png). The primary pairs used identical recipe hashes within each comparison.

### Gameplay hardware

All four themes were also captured with production Retro in existing authored mechanism views: [RampMania mid](hardware/rampmania-mid/sheet.png), [RampMania upper](hardware/rampmania-upper/sheet.png), and [Orbit Garden Drop Targets](hardware/drop-targets/sheet.png). These sheets are downscaled supplemental review, with independent manifests and freshness checks beside them. RampMania belongs to the production pool; Orbit Garden is an existing experiment loaded through Prototype's normal single-Act disk path because the production pool has no Drop Target bank. No Act was edited or added to the pool.

Rails, switches, three yellow Drop Targets, enemy silhouettes, bumper emblems and flipper tips remain distinguishable. The primary views additionally show the served character and locked Goal. The new Chemical halo treatment reduces broad floor spill, but Rings directly overlapping yellow lamp rectangles still compete. Casino's blue character on its blue deck benefits from its white contact marker; do not deepen the deck further without play review. Rooftop Rings on cream paving and Green Hill palm shadows remain existing motion-review questions.

### Real streamed transitions

The new rendered fixture opens normal two-Zone Prototype runs with six resident Acts, validated disk recipes and default atmospheres. It moves the existing tour camera across the actual distance-driven seam at 0, 0.25, 0.49, 0.50, 0.51, 0.75, 1, then back to 0.50 and 0, with gameplay frozen. Production Retro stays enabled. This is a camera traversal, not a claim that the Ball played through both Zones.

Native-output endpoint/midpoint triptychs: [Green Hill → Casino](transitions/green_hill-to-casino_night.png), [Rooftop → Chemical](transitions/rooftop_run-to-chemical_plant.png), [Chemical → Casino](transitions/chemical_plant-to-casino_night.png). [Manifest](transitions/manifest.json) records all 27 samples; the full sequences remain under `test-results/atmosphere-signatures/transitions-final/` locally.

The test passes 237 checks for real blend weights, exposure/ambient/glow interpolation, clear fog, private environments/skies/materials, unchanged source values, gameplay identity and zero fallback. Static review found no abrupt midpoint flash or fog wall. Different Zone backgrounds retain their own lighting while the foreground interpolates, as designed. The existing transition system is unchanged. Known ObjectDB exit warnings remain; they are not treated as evidence that the engine's lifecycle issue is fixed.

## Rendering cost

The optional profile uses the same canonical disk fixture with Retro ON, a 1440×1000 window, uncapped rendering, frozen gameplay, 120 settling frames and 360 measured frames per ABBA block. Only one Godot process ran. Shader caches were not cleared. Values were swapped through the existing atmosphere property/material bindings; screenshots were excluded from timing. Hardware: RTX 4060, Forward+/Vulkan, Godot 4.7.2.

| Theme | Mean of before GPU block medians | Mean of after GPU block medians | Delta | Draws before → after | Foreground active materials |
| --- | ---: | ---: | ---: | ---: | ---: |
| Chemical Plant | 0.8330 ms | 0.8325 ms | −0.0005 ms | 491 → 491 | 65 → 65 |
| Casino Night | 0.8390 ms | 0.8680 ms | +0.0290 ms | 668 → 657 | 67 → 67 |

Resource counts and measured-block pipeline counters remain constant within each theme. Casino's changed sun direction can change shadow culling; this is the likely explanation for its draw/object reduction, not an asset deletion. Its two baseline GPU medians span 0.800–0.878 ms, larger than the reported average delta. These samples show no material GPU regression; they do not establish whole-run FPS, cold-start cost, motion cost or work-laptop behavior. No new lights, shaders, viewports, passes or quality settings were introduced. Full [timing report](performance/report.json) and [run log](profile.log).

## Verification and limits

The 32-suite supported baseline passes **8,593 checks**, plus six fresh-process child reload checks, including all 40 Prototype recipes (425 audit checks). The separate 56-recipe Endless audit also passes (489 checks), covering all 96 recipes. Focused rendered checks pass for variant save/reload/default identity (461), production Default loading (774), glow and material exclusions (299), fog (31), and all-theme surface controls (1,617 on a fresh-process retry). Headless variant, range, local palette and packaged registry checks also pass. [Verification receipts](verification.json) record exact counts and log hashes.

The additional hardware palette suite has **18 inherited failures**, all cosmetic-response assertions in deferred Ice Cap, Lava Reef and Aquarium Park. The same 18 failures reproduce in an isolated export of untouched starting main, and with just these two scoped Default changes. The four reviewed themes have no failures in that suite. No assertion was weakened and no deferred theme was changed. [Untouched-main log](clean-hardware-baseline.log) and [error details](clean-hardware-baseline.err).

The existing same-theme runtime suite executes 87 checks with **two inherited Ice hue assertions failing** (`Next Zone owns shifted terrain`). An independently baked, untouched-main source export reproduces both failures: [baseline log](clean-runtime-baseline.log), [errors](clean-runtime-baseline.err). Its resource ownership, immutable recipe, switching and transition checks pass. This does not replace the scoped Prototype transition fixture's 237 passing checks. Ice's material/hue issue remains deferred; neither regression was edited to hide it.

One all-theme rendered Lab surface run hit Vulkan device loss during fixture construction; a fresh process with a 60 FPS cap completed all 1,617 checks. An earlier headless surface invocation was rejected because the suite requires a real renderer. Neither failed attempt is counted as a passing run. Existing shutdown ObjectDB/resource diagnostics remain outside this atmosphere pass.

The isolated clean source export also passes variant storage, ranges and local palette checks. Appearance evidence intentionally includes the pre-existing selected local artwork; that artwork is not part of this commit. [Preservation hashes](source-preservation.json) prove the 21 unrelated dirty tracked files remained unchanged. Only Default value lines are staged from the two already-dirty atmosphere files, leaving their pre-existing formatting and named variants uncommitted.

Alex's short motion checklist: follow Rings across Chemical's yellow lamps at speed; track the blue character and scoring objects on Casino's deck; check Rooftop's cream paving and Green Hill's palm shadows; traverse the daylight/night seams with normal play. Static screenshots and numerical interpolation cannot approve feel or moving-object readability.

## Reproduction

Use `tools/capture_prototype_appearance.ps1 -Retro production` with the selected four themes, the same Act, a fresh output directory and the three camera targets above. `-Retro off` is diagnostic only. `-SkipBake` is valid only when current disk recipes already exist. The capture tool checks source/texture freshness and fails on fallback.

Run the transition fixture graphically with `--script res://tests/prototype_atmosphere_transition.gd -- --seed=18 --output=res://test-results/atmosphere-signatures/transitions-review`. Run the optional profile with `--script res://tests/prototype_atmosphere_profile.gd -- --retro=production --baseline-atmospheres=<directory-containing-before-cfg-files>`. It uses the local saved baseline by default. The profile is a manual measurement helper, not a permanent performance threshold or art-value test.

`tools/export_atmosphere_signatures.ps1` rebuilds the matched primary sheets from the recorded local batch directories, validates their paired receipts and explicitly marks reused controls. Evidence tools only alter their isolated capture settings; normal gameplay Retro stays on.
