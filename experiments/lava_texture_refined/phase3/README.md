# Lava Reef — Phase 3 in-game albedo review

Alex approved the revised set and requested one final adjustment: darken only the timber slightly before proceeding. The final 5B uses a 0.96 timber multiplier. Rocks retain their approved shared mineral palette, 3B restores the earlier purple basalt wall, and 9B retains the dark iron-and-brass facade.

## Production ownership

The normal `scenes/prototype_run.tscn` session consumes the selected artwork through `scripts/themes/lava_reef_theme.gd`, `lava_selected_materials.gd`, and `lava_selected.gdshader`. The source presenter and supported disk baker share these bindings. `assets/textures/lava_reef/selected/README.md` records the eight roles and source paths. `selected-source-receipt.json` records exact source/copy hashes.

The shader is albedo-only: no generated normals, height, AO, roughness, metallic or emission maps. The former terrain emission textures are not bound to the new albedos. Existing lava, crystal, cavern and minor-prop materials remain unchanged. The floor and facade mappings retain their physical periods; top/ramp surfaces use the approved 1.6-unit repeat. Pipe trim and girder guards use the established contour/route distance chart. Existing geometry, collisions and border widths remain intact.

## Review evidence

- `gameplay.png` and `gameplay-receipt.json`: First Try Smooth Decor through the canonical Prototype fixture, with six selected terrain albedos verified against the loaded disk resources.
- `ramps.png` and `ramps-receipt.json`: RampMania through the same fixture, with all eight albedos verified, including ramp deck and guards.
- `freshness.json`: Current pipeline and freshness of the five Lava Reef Prototype variants.
- `bake-current.log`, `review-current.log`, `ramps-current.log`: Accepted graphical bake and review runs. These supersede the initial runs.

Reviews use the existing Default atmosphere, production Retro settings and normal gameplay camera. Only the HUD is hidden in isolated review sessions. There are no runtime fallback builds. Both saved images were visually inspected. The wood reads warmer under the existing volcanic lighting than in the unlit authoring study; lighting has not been changed to compensate. The inset clusters remain periodic, and motion/readability still need Alex's review.

All five Prototype variants were baked through the supported graphical `scenes/act_baker.tscn -- --prototype --theme=lava_reef --quit-after-bake` path. A concurrent Ice Cap texture change invalidated the shared pipeline fingerprint after the first bake; the accepted bake and captures were refreshed afterward. No freshness check was bypassed. The existing certificate-store startup error remains nonblocking; no material/script errors were accepted.

The phase does not refresh the separate Endless pool or add material response. No headless validation, full regression suite, benchmark, production build, commit or push was run. Await approval of the in-game albedo/mapping before Phase 4.
