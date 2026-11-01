# Seeded scenery authoring

Open `Lighting Lab.cmd`, load an authored Act, choose a Theme, then open **Scenery**.

1. Enter a Scenery seed, or click **Randomize**.
2. Choose **Scenery Density**: 0.50 Sparse, 0.75 Light, 1.00 Normal, 1.25 Dense, 1.50 Very Dense, 2.00 Packed or 2.50 Showcase.
3. Use **Inspect left** and **Inspect right**, then pan along the Act. These use the accepted 50° elevation, 52° FOV and 1.3 gameplay zoom. They do not move the ball.
4. Click **Save scenery**. Run **Bake Prototype** or **Bake Endless** before playing the relevant production mode.

Randomize and density changes replace local scenery only. Terrain, gameplay nodes, ball state, camera, shared far scenery and the current atmosphere draft remain intact. Unsaved scenery drafts survive Act/theme switches during this Lab session. Reload restores the saved composition; Reset previews seed 0 and density 2.50 Showcase. Reset does not save automatically. The common Save/Reload/Reset buttons act on scenery while the Scenery tab is selected; on other tabs they retain their atmosphere behavior.

## Ownership and compatibility

Each Act can have one compact adjacent `<Act name>.scenery.cfg` file. Version 1 stores `seed` and `density` in sections named by theme ID. Saving merges only the selected section and preserves other themes and unknown fields. Staged writes preserve a recovery copy if replacement fails. The gameplay `.tres` is never modified by scenery authoring. Missing fields independently fall back to seed 0 and density 2.50 Showcase; explicit saved values still take precedence. Invalid values prevent bake validation and are reported by the Lab/baker.

The November 2026 Zone Default pass makes Showcase the shared default for settings, standalone presentation and builder fallbacks. The local Chemical sidecar in the reviewed checkout already uses 2.50; its seed and file are preserved outside this change. The candidate budget, footprint rejection, shadowless local scenery, batching and gameplay RNG isolation are unchanged. Lava Reef and Aquarium Park use fixed scenery layouts rather than this density system.

The sidecar is authored project data: commit it with the Act. Prototype and portable-editor export filters include these files under `data/`. When manually renaming, copying or using Save As on an Act, copy/rename the sidecar too if that new Act should inherit its compositions. The geometry editor's Save As remains a geometry operation. No theme-specific gameplay Act duplicates are needed. Atmosphere presets remain separate lab data under `user://`; saving scenery does not publish an atmosphere variant.

Green Hill, Chemical Plant, Rooftop Run, Casino Night, Sky Sanctuary and Ice Cap support composition changes. Aquarium Park and Lava Reef retain their accepted fixed compositions. Seed 0 uses authored default choices. Other seeds derive independent per-role RNG streams from the seed and theme. Selecting a saved seed is independent of wall-clock time and never consumes the gameplay RNG. Randomize uses a separate RNG only to choose the next seed.

## Bounded composition

Density adjusts up to five landmark candidates and small optional accents. Packed (2.00) and Showcase (2.50) add candidates in separate longitudinal bands and search the nearest available gap. Extra ruins, ridges, facades and casino clusters use half-size secondary groups; the full transformed footprint is measured after scaling. Settings through 1.50 retain their previous placement policy. It does not multiply every prop. Rotated/scaled group footprints clear the real course contour, remain inside the Act's longitudinal bounds and keep a 30-pixel minimum gap from another group on the same side. Short Acts can reject extra candidates, so higher density need not increase every view's draw count.

- Green Hill varies headland sides/widths, one loop choice, up to two palms, flowers/rocks and up to two small islets.
- Chemical Plant varies nearby tank type, radius, height and short pipe groups.
- Rooftop Run varies facade/garden combinations and modest group rotation.
- Casino Night uses existing lantern/reel/pylon landmarks with optional neon palms.
- Sky Sanctuary varies broken ruin choice, rotation, scale and up to five fragments while retaining cloud gaps.
- Ice Cap varies ridges, shelves, pines/crystals and one optional arch. Its two aurora ribbons continue to follow the actual contour and do not randomize.

The preview reports local group, mesh-instance and mesh-surface counts, shadow casters and lights. Surface counts are estimates, not GPU draw calls. Local scenery stays shadowless and adds no lights. Existing theme batching and offline spatial batching remain in use.

## Baking and runtime

The baker resolves Act geometry + Theme + saved scenery inputs into the existing static visual recipe. Local scenery retains the Act's background tag and retirement ownership. Shared far scenery stays a Zone/theme resource and does not use the Act seed. Runtime loads ordinary recipes; it adds no seed polling, procedural placement or randomization.

Bake version 8 adds a scenery fingerprint separate from the gameplay source fingerprint. Changing one Act/theme's settings stales that visual bake only; other Acts/themes and shared far resources retain their input signatures. Collision validation can still reuse the unchanged geometry receipt. Generator/source changes retain the existing broader pipeline invalidation rules. The version upgrade requires one initial refresh of both bake pools.

Regression and rendering checks live in `tests/scenery_regression.gd` and `tests/scenery_profile.gd`. The latter captures local scenery through the production recipe and batch optimizer, then measures Normal/Very Dense/Showcase in matched left/right views. Preparation and screenshot readback occur outside measured frames. Results and images are written under ignored `test-results/scenery-density/`.

## Measurements — 2026-10-31

RTX 4060, Godot 4.7.2, Forward+/Vulkan, Reverse C Spring, seed 183742, 1280×900 window and 673×473 world viewport. The two approved edge views use 50° / 52° FOV / 1.3 zoom. Each density was measured in ascending order (120 settled frames) and descending order (360 settled frames), with preparation and screenshot readback excluded. Local scenery was captured and instantiated through the production recipe/batch pipeline; terrain and shared far scenery remained matched generated presentation. The measured working checkout includes existing local material experiments, which are preserved outside this commit. These are local density deltas, not whole-run performance claims.

Values below are draw counts and the mean of the two per-pass GPU medians, in milliseconds. GPU time sums active viewport measurements.

| Theme / edge | Sparse draws / GPU ms | Normal draws / GPU ms | Very Dense draws / GPU ms | Dense − Sparse draws / GPU ms |
| --- | ---: | ---: | ---: | ---: |
| green_hill / left | 1176 / 0.618 | 1187 / 0.644 | 1188 / 0.644 | +12 / +0.026 |
| green_hill / right | 1100 / 0.568 | 1103 / 0.570 | 1116 / 0.589 | +16 / +0.021 |
| chemical_plant / left | 647 / 0.616 | 647 / 0.673 | 657 / 0.677 | +10 / +0.060 |
| chemical_plant / right | 580 / 0.532 | 589 / 0.587 | 589 / 0.587 | +9 / +0.055 |
| sky_sanctuary / left | 894 / 0.657 | 894 / 0.659 | 894 / 0.676 | +0 / +0.019 |
| sky_sanctuary / right | 715 / 0.564 | 723 / 0.577 | 723 / 0.572 | +8 / +0.008 |
| ice_cap / left | 865 / 0.718 | 870 / 0.678 | 870 / 0.693 | +5 / -0.025 |
| ice_cap / right | 703 / 0.658 | 710 / 0.646 | 710 / 0.647 | +7 / -0.011 |
| casino_night / left | 988 / 0.823 | 1003 / 0.830 | 1002 / 0.831 | +14 / +0.009 |
| casino_night / right | 829 / 0.753 | 831 / 0.757 | 838 / 0.767 | +9 / +0.014 |
| rooftop_run / left | 735 / 0.884 | 745 / 0.868 | 745 / 0.833 | +10 / -0.051 |
| rooftop_run / right | 768 / 0.835 | 770 / 0.827 | 772 / 0.798 | +4 / -0.036 |

The largest measured draw increase is 16. GPU deltas range from -0.051 to +0.060 ms; negative values are measurement/clock variation, not a claimed speedup from adding scenery. The largest same-case GPU difference between orders is 0.115 ms. Longer whole-run and work-laptop measurements remain useful. Sky/Ice retain small pre-existing MultiMesh sets; the optimizer does not expand them. Dense Ice rejects the third large group on this Act, preserving spacing.

Seeds 0, 183742 and 9127 were rendered in both views for all six supported themes, with native and existing-retro captures. Visual review checks contour clearance, readable course edges and bounded landmarks. Human review of moving scenery rhythm and preferred composition remains with Alex. Raw reports, preparation timings and screenshots are under `test-results/scenery-authoring/profile/` and `profile-reverse/`.

## Verification

- Scenery regression: 4,334 checks in the working checkout; 5,450 in a clean export of the staged source without local art experiments. Different geometry batching changes the number of per-node assertions. Both pass determinism, global RNG isolation, gameplay/camera/far-node preservation, density limits, shadow/light rules, settings validation, typed-seed Save and Reload.
- Geometry bake regression: 2,842 checks; existing offline batch regression: 111; physics: 24; Prototype plan: 41. All pass.
- Forward+/Vulkan atmosphere regression: 492/492; Lighting Lab smoke: 45/45.
- Refreshed all 40 Prototype and 56 Endless variants. Audits pass 387 and 451 checks respectively. `tests/endless_bake_audit.gd -- --prototype` selects the Prototype pool; omit that option for Endless.
- A disposable Ice Cap fixture baked seed 183742 / density 0.75 and validated its saved composition receipt, collisions and Act-local background records.
- Forward+/Vulkan streaming smoke: 256 checks across 27 transitions, bounded retirement/cache state and no procedural fallback. Prototype startup reached ready in 5.46 seconds on this run; that is a startup observation, not a performance comparison.
- A minimal exported PCK retained seed 183742 / density 1.50 using the new sidecar inclusion filter. Both PowerShell export scripts pass syntax parsing. No full executable release was built for this feature.

Godot's existing certificate-store warning appears in headless logs. The full streaming test also reports 18 ObjectDB instances at process exit; a verbose repeat identifies zero-reference `RefCounted` objects, the same warning class seen in earlier framing/streaming runs. No leaked scenery nodes are reported, and bounded live retirement checks pass. This exit warning remains unresolved. Moving-camera composition preferences and second-hardware performance remain manual review items.

## Higher density polish — 2026-11-01

Packed (2.00) and Showcase (2.50) extend both saved validation and the actual composition budget to five landmark candidates. They search legal gaps and use smaller secondary groups where the theme builds complete ruin/ridge/facade/landmark roots. Green Hill and Chemical retain their contour-aware headland/industrial placement. No prop-by-prop multiplier, new light, gameplay placement or runtime generation was introduced. The existing 30-pixel separation and full footprint/Act bounds checks still apply; insufficient space can reject a candidate. Local scenery stays shadowless.

On Reverse C Spring, seed 183742, group counts at 1.00 / 1.50 / 2.50 were Green Hill 2/3/4, Chemical 2/3/4, Sanctuary 2/3/5, Rooftop 2/3/5, Casino 2/3/5 and Ice 4/4/6 (Ice includes its two unchanged aurora ribbons). The secondary Ice shelf is visible below the main ridge, rather than repeating every crystal. All six supported themes gained accepted groups at Showcase on this representative Act. Short or crowded Acts remain allowed to reject groups.

Profiles measure both approved edge views after recipe capture and batching, with 120-frame ascending and 360-frame descending samples at 1.00/1.50/2.50. Reports and screenshots are under `test-results/scenery-density/profile` and `profile-reverse`. Measurements include the preserved local art experiments; those art edits are not part of this polish commit.

Final descending-pass results (RTX 4060, Godot 4.7.2 Forward+ Vulkan, 1280×900 window, 673×473 world viewport, 360 settled frames; left edge shown):

| Theme | Draws 1.0 / 1.5 / 2.5 | GPU median ms 1.0 / 1.5 / 2.5 |
| --- | --- | --- |
| green_hill | 1187 / 1188 / 1200 | 0.644 / 0.644 / 0.678 |
| chemical_plant | 648 / 658 / 658 | 0.690 / 0.695 / 0.695 |
| sky_sanctuary | 894 / 894 / 894 | 0.668 / 0.682 / 0.679 |
| ice_cap | 867 / 867 / 869 | 0.716 / 0.708 / 0.716 |
| casino_night | 1004 / 1004 / 1009 | 0.830 / 0.836 / 0.833 |
| rooftop_run | 748 / 748 / 756 | 0.919 / 0.928 / 0.929 |

Higher density is bounded, not free. Culling and batching can keep draw counts equal even when additional groups are present; the opposite edge and other camera positions expose different groups. These are local view measurements, not a whole-run frame-time guarantee. Offline baking ran concurrently, so CPU/frame timings should not be treated as isolated benchmarks.

Polish verification: scenery regression passed 6,606 checks in the working checkout and 8,574 in a clean staged-source export, including deterministic layouts, gameplay RNG isolation, placement bounds, light/shadow rules and settings validation. The different counts reflect local art geometry. Static batching passed 111 checks. All 40 Prototype and 56 Endless variants were refreshed; their audits passed 393 and 457 checks. A disposable density-2.50 sidecar fixture baked all eight variants and loaded into Prototype alongside neighboring Acts under Green Hill, Sanctuary and Ice, with collision receipts reused and no runtime fallback. Forward+ streaming passed 256 checks across 27 transitions with valid disk bakes and bounded caches. The known ObjectDB exit-warning class remains (eight instances on this run). No production sidecar was changed. Final isolated crystal and gameplay captures were reviewed with Retro on/off; see [Ice Cap](ICE_CAP.md#crystal-rendering-polish--2026-11-01).
