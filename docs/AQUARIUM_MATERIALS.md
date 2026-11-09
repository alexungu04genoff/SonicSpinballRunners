# Aquarium Park current materials

Alex authorized completing material response and making the selected set current on 2026-11-09. The approved mixed stone/square-blue floor and red border with gold studs are the current direction. This handoff does not authorize a commit, push, or release.

## Production ownership

`scripts/themes/aquarium_park_theme.gd` creates the selected materials through `scripts/themes/aquarium_selected_materials.gd`. The unused legacy terrain-material initialization has been removed; border widths remain 4/2 physics pixels. The source presenter and normal production disk baker use that same factory. `scripts/themes/aquarium_selected.gdshader` owns all mapping and response. Normal Prototype play loads baked recipes; Act/editor play builds the same theme from source.

Current PNG assets live in `assets/textures/aquarium_park/selected/`:

| Role | Asset | Response |
| --- | --- | --- |
| Floor | `1-mixed-floor` | Shallow stone bevels and broad facets; blue panels remain smooth, with raised red frames |
| Floor border | `2A-red-gold-studs` | Lacquered red trim and small raised brass studs |
| Wall | `3B` | Timber plank joints, framing, thin brass fittings |
| Wall fascia | `4B` | Slate tile-end discs and restrained carved spirals |
| Playable roof | `5A-red` | Rounded tile profiles and overlapping courses |
| Roof border | `6A-red` | Matching tile profiles, scaled to the thin existing border |
| Ramp deck | `7B` | Beveled stone courses and smooth painted edge strips |
| Ramp guard | `8A` | Smooth red paint and shallow brass straps |
| Exterior facade | `9A` | Matte ivory panels, raised timber lattice and corner fittings |

Each active ID has an unchanged approved albedo PNG, an OpenGL `_normal.png`, and a linear `_response.png` with roughness in R and exposed-metal mask in G. Blue is unused. Metallic response is deliberately capped at 0.25 so small brass fittings retain their readable gold color under the approved lighting; full metal response turned them nearly black. `_height.png` files are generation references only and are not bound at runtime. Paint remains dielectric. There is no parallax, displacement, added emission, or generated AO.

The original `2A.png` remains only for the historical C comparison; no current Aquarium material requests it. Old proposal sheets and Phase 3 captures are historical evidence, not alternate runtime material overrides.

Scenery roofs (10C), water (11C), glass (12C), lanterns, lamps and architecture retain their existing treatment. Coral retains its approved cyan/violet private materials, without recoloring fish tails. Terrain geometry and collision are unchanged.

## Mapping and controls

Albedo, normals and response use identical coordinates for world floors, contour walls/borders, projected facades and route-aligned ramps. The wall cap uses its own aligned maps. A derivative normal frame supports generated meshes without tangents. Normal strength is intentionally restrained; the 4:1 floor-border image keeps round studs at the existing four-pixel border width.

In Visual Lab, select Aquarium and press **F8** for **Material detail** and **Normal strength**. The existing Retro and camera controls remain unchanged. These authoring controls are temporary, do not save player preferences, and do not override Atmosphere Lab's panel.

The same controls can be applied programmatically to real runtime materials:

```gdscript
const AquariumMaterials = preload("res://scripts/themes/aquarium_selected_materials.gd")
AquariumMaterials.set_detail(game, false)       # Matched albedo-only comparison.
AquariumMaterials.set_detail(game, true, 1.0)   # Restore the production defaults.
AquariumMaterials.set_detail(game, true, 0.5)   # Half the default normal strength.
```

The helper traverses bound, private and baked materials, including mesh batches. The multiplier is clamped to 0–2; roughness and metal response toggle with detail. Per-role default strengths are in `NORMAL_STRENGTH`.

## Regeneration and review

`experiments/aquarium_texture_refined/bake_response.gd` produces response maps graphically from structural definitions in `response.gdshaderinc`, reusing the approved source artwork's functions and exact periodic stone-cell search. It never rewrites approved albedos. `response-manifest.json` records source and asset hashes, physical repeat sizes and height ranges.

After material/source changes, refresh Aquarium through the supported graphical bake scene:

```powershell
& 'C:\Program Files\Godot\Godot.exe' --path . res://scenes/act_baker.tscn -- --prototype --theme=aquarium_park --quit-after-bake
```

`experiments/aquarium_texture_refined/final_review.gd` opens real disk-loaded Prototype sessions for First Try Smooth Decor and RampMania. It checks current albedo/response pixel matches, bound detail controls, unchanged camera/game state, fresh bakes and visible on/off response. Review captures use the default atmosphere and production Retro, with HUD hidden. Receipts and matched images live in `experiments/aquarium_texture_refined/final_review/`.

This review checks material appearance and binding, not gameplay feel or performance. Normals change lighting rather than silhouettes. No full regression suite, headless verification, benchmark, export, commit or push is part of this material handoff.

Completed handoff: all five Prototype and seven Endless Aquarium variants were rebuilt in `settled-pools-bake.log`. Both final Prototype reviews passed with fresh source/bake fingerprints, current texture pixels, unchanged camera/game state and visible normal-only response. Detail controls reached 12 bound materials in the gameplay view and 26 in the ramp view. The separate graphical F8 check passed on all seven live Visual Lab material bindings and restored production defaults. The definitive receipts are `final_review/receipts.json` and `final_review/controls-receipt.json`; earlier failed/stale runs are historical logs only.
