# Lava Reef — warm direction review

Alex found the Phase 2 selection too purple and requested a preview of the proposed orange/dark alternative. This is still Phase 2, not integration or approval of the replacement.

- **5B revised:** burnt-orange fitted mineral slabs with charcoal joints and occasional pale-gold planes. Replaces the purple metal-panel concept for this proposal only.
- **3B revised:** the selected basalt column geometry and gold mineral accents, recolored to warm charcoal with restrained plum undertones.
- **9B revised:** the same darker basalt in dark iron frames with retained brass joints.
- **1C, 2A, 6B, 7A, 8B, 10C, 11C:** unchanged from their preceding review/current sources. Purple pipe borders remain accents.

`warm.gdshaderinc` uses deterministic helpers from the preceding `selected.gdshader`. `render.gd` exports only three new albedos and pixel-based repeat previews. No normal, height, roughness, AO, metallic, or emission maps were generated. The preceding review assets remain intact.

`balance-comparison.png` shows identical generic stepped geometry, camera, unlit material response, and retained textures for both directions. It is explicitly a material study, **not a gameplay screenshot, production scene, or final mapping preview**. The final game scene, camera, lighting, terrain, collision and production material bindings are untouched. `revised-textures.png` shows the three changed texture sources and repeated previews.

Graphical export and visual inspection completed. No obvious hard seams were found in the new repeat previews. Physical scale and lighting remain for an approved Phase 3 review. Godot logged its existing certificate-store startup error; PNG rendering completed. No test suite, production bake, commit, or push was run.

Follow-up: Alex approved warm charcoal 3B and the latest dark iron-and-brass 9B (clarifying that “9A” meant this 9B). The top floor continues in `../timber_revision/` as explicitly requested orange wood with rock insets. No integration is authorized yet.
