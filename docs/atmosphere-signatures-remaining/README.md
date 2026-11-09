# Remaining production Default atmosphere signatures — 2026-11-09

This continues the [first four-theme pass](../atmosphere-signatures/README.md) after Alex completed the remaining selected textures. Scope: Sky Sanctuary, Ice Cap, Lava Reef and Aquarium Park. Production Retro stays enabled and is the final appearance gate; OFF captures are lighting diagnostics. Starting pushed main is `4e2406d3f0c74c73f10d3a2212c89630275e42de`, with a clean working tree. The previous four Defaults, selected artwork, material detail, named variants, gameplay and device quality are preserved.

## Audit before atmosphere edits

The canonical fixture is the real disk-loaded Prototype single-Act session: First Try Smooth Decor, seed 18, served Sonic, zero score, locked Goal, frozen time, 1440×1000 output, 4× MSAA and 100% device render scale. The normal Retro stack retains its own authored internal resolution. Camera targets are spawn `(400,500)`, mid `(300,250)` and upper `(350,125)`, matching the previous pass. Source pixels, recipe fingerprints, atmosphere, graphics and gameplay state are recorded by the existing capture/freshness guard.

The initial audits found stale recipes after the material revisions. Both supported pools were refreshed through the existing baker before capture: 40 Prototype and 56 Endless Act/theme recipes. The new selected-material policy deliberately retains structural normals in these four themes. The older audit incorrectly demanded flat shaders for every theme; it now checks the approved policy, retained normal maps and matching per-theme tags while preserving the flat-material assertions elsewhere. A focused sharing test covers all four exceptions. No production baking or material code changed in this pass.

| Theme | Current atmosphere identity | Strong | Weak / generic | Readability risk | Proposed action |
| --- | --- | --- | --- | --- | --- |
| Sky Sanctuary | Warm ivory/jade ruins over a pale cyan cloud world | Blue insets, folded greenery, carved pale masonry and open gaps already separate the world from a city | Yellow-green sunlight dominates the paving and makes the light feel closer to Rooftop's afternoon than high-altitude air | Gold Rings have limited color separation on yellow paving, especially with Retro | Neutralize the warm key, introduce cooler blue fill and cleaner cloud contrast, and test a steeper sun. Keep clear air and the approved stone/grass textures. |
| Ice Cap | Brilliant cyan/white snow stage with blue faceted walls and frozen structures | Strong cold identity, coherent snow patches, readable crystal silhouettes | Production Retro expands the very bright snow and small crystal highlights into broad white areas; native OFF retains more visible surface variation | Gold Rings and pale hardware approach the snow's brightness; narrow snow edges lose detail | Reduce light energy and glow conservatively, preserve bright snow with blue shadows, and deepen the blue distance. Avoid gray snow, murk or a nighttime conversion. |
| Lava Reef | Ochre/brown rock under warm light, purple basalt surrounds and orange magma | New large rock cells and purple structures read clearly; cyan/green gameplay faces stand out | Ambient fill is uniformly warm; the course and hot surroundings have too little lighting contrast | Gold Rings and warm hardware sit against ochre floor highlights; the dark locked Goal needs its edge visible | Lower and cool the ambient fill, preserve a warm key, deepen cavern/magma darks and contain existing glow/fog. Preserve the approved ochre artwork and normal strengths. |
| Aquarium Park | Bright blue/cyan lagoon with red architectural blocks and warm lanterns | New red/blue separation, giant fish, clear water and warm lamps already establish the theme | Broad cool fill reduces depth; bright lantern/reflection spots can compete with scoring objects | Blue character over blue insets relies on its contact marker; Rings on pale stone and near yellow lanterns need motion review | Try a restrained reduction in ambient fill and decorative bloom with deeper lagoon tones. Keep the blue deck, warm architecture and clear near field; retain the baseline if the trial harms readability. |

The audit precedes production Default edits. It judges current selected artwork through Prototype rather than source-Lab screenshots. Static images do not approve moving-object readability.

## Accepted Default changes

| Theme | New character | Changed controls | Deliberate limits |
| --- | --- | --- | --- |
| Sky Sanctuary | Cleaner high-altitude daylight over pale stone and jade, separated from Rooftop's warm city | Less-yellow key, cooler ambient fill, steeper sun, stronger blue cloud shadows and cleaner cloud highlights | Clear air, unchanged exposure and glow; approved textures and cloud facets retained |
| Ice Cap | Brilliant blue-white snow with less expanded white glare under Retro | Lower sun/ambient energy, cooler key/fill, reduced decorative emission/glow, deeper upper-sky blue | No fog or gray-winter conversion; aurora/star values and plain snow guards retained |
| Lava Reef | Hot ochre rock and magma against cooler purple shadows and deeper cavern masses | Lower/cooler ambient fill, lower key energy, darker cavern/magma colors, restrained glow and existing directional fog | Approved warm rock artwork and extreme floor/timber normal strengths retained; warm hardware is not recolored |
| Aquarium Park | Bright red/blue aquatic architecture over deeper lagoon tones | Slightly lower ambient fill/emission/glow, neutral-cool key, deeper water and restrained reflections | Smaller adjustment because the revised artwork already supplies strong identity; no near-field fog |

There are 42 changed saved Default fields: Sky 11, Ice 8, Lava 13 and Aquarium 10. [Exact values](changed-fields.json) and the [four original Default files](baseline-atmospheres/) make the comparison reproducible. A line-by-line scope check confirms every other Default and named variant is unchanged. No global hue layer, exposure, tonemapper, geometry, gameplay material, camera or device setting changed. Production changes are confined to four atmosphere data files; the code changes extend existing evidence helpers and update obsolete test expectations for the approved material policy.

## Matched evidence

All 24 before/after comparisons preserve 1440×1000 gameplay pixels at 1:1 scale. Each image has BEFORE at left and AFTER at right. Every pair matches renderer/device, camera/gameplay state, graphics/Retro settings, source textures and exact Act/background bake hashes. [Pair verification](pair-verification.json) and [capture receipts](receipts/) retain those checks. All 12 capture batches pass 83 fresh-process checks each, with zero source fallback.

| Theme | Production Retro ON | Diagnostic Retro OFF |
| --- | --- | --- |
| Sky Sanctuary | [Spawn](pairs/production/sky_sanctuary-spawn.png), [mid](pairs/production/sky_sanctuary-mid.png), [upper](pairs/production/sky_sanctuary-upper.png) | [Spawn](pairs/off/sky_sanctuary-spawn.png), [mid](pairs/off/sky_sanctuary-mid.png), [upper](pairs/off/sky_sanctuary-upper.png) |
| Ice Cap | [Spawn](pairs/production/ice_cap-spawn.png), [mid](pairs/production/ice_cap-mid.png), [upper](pairs/production/ice_cap-upper.png) | [Spawn](pairs/off/ice_cap-spawn.png), [mid](pairs/off/ice_cap-mid.png), [upper](pairs/off/ice_cap-upper.png) |
| Lava Reef | [Spawn](pairs/production/lava_reef-spawn.png), [mid](pairs/production/lava_reef-mid.png), [upper](pairs/production/lava_reef-upper.png) | [Spawn](pairs/off/lava_reef-spawn.png), [mid](pairs/off/lava_reef-mid.png), [upper](pairs/off/lava_reef-upper.png) |
| Aquarium Park | [Spawn](pairs/production/aquarium_park-spawn.png), [mid](pairs/production/aquarium_park-mid.png), [upper](pairs/production/aquarium_park-upper.png) | [Spawn](pairs/off/aquarium_park-spawn.png), [mid](pairs/off/aquarium_park-mid.png), [upper](pairs/off/aquarium_park-upper.png) |

Final native-output sheets: [Retro ON](four-themes-production.png), [OFF diagnostic](four-themes-off.png). Label-free thumbnails mask the HUD and show spawn/mid/upper columns: [Retro ON](label-free-production.png), [OFF diagnostic](label-free-off.png). These thumbnails are downscaled identity checks; primary pairs retain native pixels. The first four themes' earlier evidence remains in the linked first pass, rather than being presented as newly captured artwork here.

At native production output the Ball's contact marker, gold Rings, flippers, bumper faces, enemies and locked Goal retain visible silhouettes across the three tiers. Sky's paving is less yellow; Ice stays bright while retaining more blue shadow detail; Lava's violet surrounds and cool hardware contrast with its warm floor; Aquarium retains its fish, lamps and architecture without a dark-underwater conversion. The locked Goal still has relatively low contrast over Lava's dark seams. Snow and pale paving remain bright by design, and Retro's halo remains visible.

## Hardware and final disk review

Supplemental production-Retro captures cover all four themes in [RampMania mid](hardware/rampmania-mid/sheet.png), [RampMania upper](hardware/rampmania-upper/sheet.png) and [Orbit Garden's Drop Target bank](hardware/drop-targets/sheet.png). These sheets are downscaled; full native frames remain in the corresponding local `test-results/atmosphere-signatures-remaining/hardware/` directories. Each folder contains an independent manifest and 83-check freshness receipt. RampMania belongs to the production pool. Orbit Garden is an existing experiment captured through the supported single-Act Prototype disk route; no Act was edited or added to the production pool.

Ramp edges, supporting shadows, flipper faces, switches and bumper stars remain distinct. Ice's approved plain snow guards stay bright and untextured. Lava's cool ramp faces separate from warm floor cells, and the gold Drop Target bank remains obvious against its darker surroundings. Sky and Aquarium targets remain separated from their pale paving/red architecture. The unchanged warm targets and Rings still warrant motion review, especially over Lava's lit floor cells.

The supplemental Orbit Garden bake regenerated the four shared background resource files after the matched primary comparisons and transition capture. Their earlier hashes are capture-time receipts, not a promise of byte-identical resource serialization after later bakes. Source/pipeline fingerprints remain unchanged. The subsequent [current-disk manifest](final-current-disk/manifest.json), [final sheet](final-current-disk/sheet.png) and both current pool audits verify the refreshed disk state. Primary before/after pairs used identical recipe hashes within each comparison. Capture-time source-file hashes precede normal Git newline normalization; the [final 83-check receipt validation](checks/post-format-freshness.log) confirms unchanged atmosphere values, artwork, gameplay and disk recipes afterward.

## Streamed transitions

The real two-Zone Prototype fixture loads six Acts and two private background layers per pair. Production seed 18 determines the recorded order: [Ice to Casino](transitions/ice_cap-to-casino_night.png), [Lava to Ice](transitions/lava_reef-to-ice_cap.png), [Lava to Aquarium](transitions/lava_reef-to-aquarium_park.png), and [Sky to Chemical](transitions/sky_sanctuary-to-chemical_plant.png). Each triptych preserves endpoint/midpoint/endpoint pixels at native output scale; the [overview](transitions/overview.png) is downscaled. The [manifest](transitions/manifest.json) records all 36 samples, including 49/50/51-percent seam positions and return visits. Full individual frames remain locally under `test-results/atmosphere-signatures-remaining/transitions/`.

All **366 checks pass**, including fresh disk recipes, zero fallback, numeric light/exposure/glow interpolation, continuous directional-fog density and visibility, private environments/skies/materials, unchanged cached recipe values and unchanged gameplay identities. Native midpoint review shows readable hardware and no abrupt fog wall or exposure flash. The backgrounds retain their own Zone lighting while foreground light blends, as designed; the theme boundary remains visibly distinct. The existing transition system is unchanged. This is sampled static seam evidence, not a human traversal-feel assessment.

## Rendering cost diagnostic

No optional rendering path is enabled by this pass. Existing light, sky, glow and Lava directional-fog controls change values only. A production-Retro ABBA run uses the same canonical disk fixture, 120 settling frames and 360 measured frames per block. The directional-fog values are applied to both the existing foreground and background cameras. No capture readback occurs inside measured blocks.

**This timing run is not isolated.** Two pre-existing Aquarium texture-review processes remained open and were preserved. [Their process receipt](performance/concurrent-previews.json) records that limitation. The numbers below are means of the two block medians on an RTX 4060, not causal performance estimates or FPS claims.

| Theme | Before GPU ms | After GPU ms | Difference ms | Draw calls before / after |
| --- | ---: | ---: | ---: | ---: |
| Sky Sanctuary | 0.870 | 0.856 | -0.014 | 670 / 665 |
| Ice Cap | 0.811 | 0.822 | +0.011 | 516 / 516 |
| Lava Reef | 0.926 | 0.913 | -0.013 | 584 / 584 |
| Aquarium Park | 0.900 | 0.929 | +0.029 | 606 / 606 |

Within each theme, active material/resource counts remain constant and pipeline counters do not grow during measured blocks. Sky's changed sun direction can alter shadow culling, which is a plausible explanation for its five fewer draws; no source asset was removed. The small timing differences cannot establish a gain or regression with other previews running. Whole-run motion, cold startup and laptop cost remain unmeasured. [Full report](performance/report.json), [summary](performance/summary.json), [log](performance/profile.log).

## Verification and existing failures

The supported **32-suite baseline passes 8,566 checks**. Both supported bake pools are current: 40 Prototype recipes pass 502 checks and 56 Endless recipes pass 566 checks. The initial traversal test failed because its separate diagnostic Act was stale; rebaking that fixture made the unchanged 20 assertions pass. The two material-policy test updates preserve freshness, collision and UV validation while checking the approved selected normals and plain Ice snow guards. The focused sharing test passes 29 checks.

Rendered checks pass for variant storage/Default identity (461), production Default loading (774), glow (299), fog (31) and all-theme surface controls (1,631). Headless variant (440), color-range (24) and local-palette (413) checks also pass. [Verification receipts](verification.json) record exact counts and log hashes. Existing headless dummy-renderer errors, Casino raw-image export warnings and ObjectDB shutdown warnings remain; passing assertions do not claim those engine/export issues fixed.

The hardware palette suite still has **12 of 459 assertions failing**: Ice snow tint (six) and ice tint (two), Lava metal tint (two), and Aquarium architecture tint (two). The same messages occurred before any Default edits and after them: [comparison](hardware-failure-comparison.json), [before log](checks/before-hardware_palette_regression.log), [after log](checks/hardware_palette_regression-final.log). These are existing cosmetic-control response failures in the revised material source. No failing assertion or gameplay palette was changed to conceal them.

The older adjacent-Ice runtime suite has **four of 87 assertions failing**, all `Next Zone owns shifted terrain`. Its ownership, immutable-source and switching assertions pass. A separate repeat using the exact original Ice Default bytes with the same current artwork and disk recipes reproduces all four errors; final Default bytes were restored exactly afterward. [Comparison/restoration receipt](runtime-failure-comparison.json), [original-Default log](checks/runtime-before.log), [final-Default log](checks/atmosphere_runtime_regression-rendered.log). This is the current material checkout's baseline, not the older first pass's two-failure count. The new four-pair transition fixture passes independently; the hue-control issue remains open.

## Remaining human review

Play with normal Retro enabled. Check moving Rings over Sky's pale paving and Ice's snow, warm Lava hardware against floor highlights, Aquarium's blue character against blue insets, and the locked Goal over Lava's dark seams. Check the existing cloud facets in motion. Static frozen-camera evidence cannot establish timing, tracking at speed, transition feel or laptop performance.

## Reproduce

Use `tools/capture_prototype_appearance.ps1` with `-Themes sky_sanctuary,ice_cap,lava_reef,aquarium_park`, `-Retro production`, a new `-OutputDirectory` and the camera targets above. Use `-SkipBake` only after current supported recipes have been validated. OFF is diagnostic only. Export matched batches through `tools/export_atmosphere_signatures.ps1 -UniformLayout`, passing these four IDs to both `-Themes` and `-ChangedThemes` and this evidence root explicitly.

The existing transition helper accepts `--pairs=casino_night:ice_cap,ice_cap:lava_reef,lava_reef:aquarium_park,chemical_plant:sky_sanctuary` and `--output=<fresh directory>`. Pair order in the final run follows the actual seeded production plan, recorded in its manifest. The optional profile accepts `--retro=production --themes=sky_sanctuary,ice_cap,lava_reef,aquarium_park --baseline-atmospheres=res://docs/atmosphere-signatures-remaining/baseline-atmospheres --output=<fresh directory>`. Run it alone with a graphical renderer. These are manual evidence tools, not permanent screenshot-equality or art-value tests.
