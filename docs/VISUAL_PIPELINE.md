# Canonical visual source

## Ownership

`ThemeRegistry.create(theme_id)` resolves one of eight current theme definitions and prepares the shared Atmosphere roles. The themed presenter, Play Act, Prototype builder, Endless builder, editor defaults and theme capture/review tools consume these definitions. Unknown IDs fail explicitly rather than quietly producing Green Hill. Low-level decor tests may instantiate decor directly; they are not alternate terrain-material factories.

The selected Green Hill, Chemical Plant and Casino artwork and approved Rooftop artwork are production dependencies, not optional local experiments. `theme_textures.gd` loads imported textures consistently in editor, captures, baking and exports. Import changed source PNGs before testing. There is no raw-image editor-only fallback and no fallback to a retired texture set.

The stale Green Hill captures that triggered this cleanup came from a clean Git worktree: preferred artwork and factories had not been committed in the original workspace. Prototype was not a separate newer material authority. The common theme definitions were already the right seam, but clean checkout and dirty workspace contained different generations.

## Baking

Bake v9 preserves source shaders, normal/height settings and material parameters. The previous `flat_surfaces.gd` conversion intentionally removed selected relief in baked play while authoring retained it; that policy and its conversion test are retired. `theme_resolution_regression.gd` checks all eight themes, material sharing and disk round trips instead. Baking copies materials before externalizing resources, so it cannot rewrite the editor's material objects.

Pipeline hashes include reachable source, shader includes and texture directories. Version 9 invalidates old sidecars. Stale local generated recipes must be removed or archived before rebuilding if their dependencies have been deleted. Bakes remain derived, ignored files. Prototype and Endless share the baker, recipes, loader and freshness checks; regenerate each desired Act pool. No Atmosphere variant migration is involved.

## Retired and retained assets

42 unreachable older PNGs and their import sidecars were removed after replacing their callers. Four obsolete procedural Chemical/Casino shaders moved to `tools/texture_sources` as reference-generation sources. Initial-art generators now write only under `experiments/texture_reference`, so running them cannot overwrite production artwork. Unused construction of old materials before replacing them was removed from Chemical and Casino.

Intentional current selections remain explicit:

- Green Hill retains its ramp PNG; selected artwork has no replacement ramp.
- Rooftop retains wall and top-border albedos with approved 3C/6C structural maps; there are no approved replacement color PNGs for those two roles.
- Chemical retains floor/wall/facade base maps with selected structural detail and neon treatment.
- Casino retains its current floor maps; its selected material generation covers the other terrain roles.
- Sky Sanctuary, Ice Cap, Lava Reef and Aquarium retain their current texture sets and custom geometry. Their procedural reference sources are not substituted at runtime.
- Thin field outlines, halos, water and animated effects remain deliberate exceptions to solid geometry rules.

## Verification and review

Use `tests/theme_resolution_regression.gd` for source/bake material identity, `tests/pinball_mesh_batch_regression.gd` for mesh fidelity/facet normals/VFX preservation, and `tests/geometry_style_capture.gd` for all-theme authored captures and mesh checks. Run the capture headlessly for mesh readback; rendered runs avoid GPU readback stress. `-- --baked --label=baked` reloads the Lockbox disk recipes and compares authoritative collision shapes. Bake that fixture first with `scenes/act_baker.tscn -- --act=res://data/acts/Experiments/Lockbox.tres`.

The existing hardware palette regression reports 18 Ice Cap tint assertions on both the untouched baseline and this work. Do not interpret those pre-existing assertions as passing. The independent Prototype Goal and Drop Target animation checks passed during the geometry work. Final visual feel, highlight stability during rotation and theme polish remain human review items.

Earlier geometry-only screenshots used the committed old art. They are not valid isolated geometry comparisons against the newly adopted art. Current contact sheets are labelled as the combined canonical-art and geometry result.

## Review artifacts and source counts

[Eight-theme overview](geometry-review/all-themes.png), [gameplay views](geometry-review/gameplay-views.png), [old committed/current comparison](geometry-review/comparison.png).

Counts below cover one instance of every decor variant per theme, not a rendered frame or GPU performance. Facet normals can increase stored vertices even as triangles fall. Material adoption is included.

| Theme | Before triangles | Current triangles | Before vertices | Current vertices |
| --- | ---: | ---: | ---: | ---: |
| aquarium_park | 17168 | 14544 | 19383 | 17702 |
| casino_night | 6588 | 6588 | 12403 | 12403 |
| chemical_plant | 8844 | 8844 | 9903 | 9903 |
| green_hill | 31700 | 12530 | 24414 | 14970 |
| ice_cap | 5434 | 5434 | 4976 | 4976 |
| lava_reef | 9256 | 9256 | 23311 | 23311 |
| rooftop_run | 4572 | 4572 | 6256 | 6256 |
| sky_sanctuary | 19744 | 12840 | 16466 | 22105 |

## Executed verification

- Current material resolution: 1,393 checks, zero failures, all eight themes.
- Mesh/catalogue checks: 4,319 checks, zero failures.
- Mesh batching, outward facet normals and magnetic VFX exception: 16 checks, zero failures. Degenerate primitive pole triangles are omitted when creating flat-normal organic meshes.
- Production rebake: five Acts × eight themes, 40 sidecars; disk audit: 199 checks, zero failures.
- Lockbox rebake: eight themes; rendered disk-recipe reload/collision comparison: 192 checks, zero failures.
- Real Prototype Play Act: 12 checks, zero failures, including rendered Goal state and restart. Normal disk-backed Prototype startup also reached ready with zero generated geometry. This exercises the same loader used by Endless; the separate full Endless stress pool was not rebaked.
- Paired Slingshot/Drop Target smoke and baked animation rebinding passed.
- One initial rendered mesh-readback pass hit a GPU-driver crash. Geometry readback now runs headlessly; subsequent authored and baked rendered captures completed without errors.
- The 18 Ice Cap palette-test failures reproduced on untouched commit `ce8d658`; they remain outside this material-source cleanup.

Selected height maps remain as source material-authoring inputs even where the renderer samples derived normals instead. Explicit `--reference` enables the old procedural comparisons in the Green Hill/Rooftop review tools; default captures use the current definitions. Reference generators never write production assets.

The default Green Hill material-review preview also rendered successfully with the current imported source PNGs. This work is isolated on `codex/geometry-language`, based on `d77655b`; concurrent telemetry work and the original dirty workspace are preserved. Generated bakes and full-resolution captures are local to that worktree.
