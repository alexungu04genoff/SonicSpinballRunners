# Lava Reef canonical materials

## Final approved response — 2026-11-09

Alex chose the exaggerated normal-only comparison. Floor 1C and timber/insets 5B now use normal strength **6.0**; the other roles retain **0.85**. Geometry and parallax are off. The earlier recessed mesh trial described below is historical and is no longer constructed by the theme or baker. Its source resources remain for provenance. F8 now exposes only Material detail and Normal strength; 1.0 restores each material's approved strength. Albedo pixels, lighting and authoritative flat collision remain unchanged. Alex also explicitly authorized committing and pushing all current project changes.

Alex approved completing the remaining material phases and making this set current. The approved albedos remain byte-identical, including the final 4% timber darkening and restored purple 3B. Structural OpenGL normals and roughness now accompany all eight material roles.

| ID | Role | Authoring source |
| --- | --- | --- |
| 1C | Brighter ochre lower floor | `experiments/lava_texture_refined/balanced_revision/1C.png` |
| 2A | Single purple lower pipe trim | `experiments/lava_texture_refined/2A.png` |
| 3B | Purple basalt walls | `experiments/lava_texture_refined/3B.png` |
| 5B | Muted timber with matching rock insets, slightly darker | `experiments/lava_texture_refined/final_revision/5B.png` |
| 6B | Paired purple upper conduits with gold saddles | `experiments/lava_texture_refined/6B.png` |
| 7A | Fitted basalt ramp paving | `experiments/lava_texture_refined/7A.png` |
| 8B | Gold girder ramp guards | `experiments/lava_texture_refined/8B.png` |
| 9B | Dark iron-and-brass facade | `experiments/lava_texture_refined/warm_revision/9B.png` |

`scripts/themes/lava_reef_theme.gd` binds these through `lava_selected_materials.gd` and `lava_selected.gdshader` for both source presentation and disk baking. The older root PNGs are retained historical sources and are not bound by the Lava Reef terrain theme. Existing lava, crystals and cavern scenery remain current.

Each albedo has `_normal.png` and `_roughness.png` companions. Depth follows the original procedural rock cells, timber planks, basalt columns, pipe profiles, paving joints and frame members. The material response is not inferred from color brightness. The two rock floors also have restrained cavity maps and `_relief.res` meshes traced from the structural height references. No metallic, emission or parallax maps were added.

The default normal strength is 0.85. The existing derivative frame keeps response aligned with albedo on curved and tangentless meshes. Rock meshes use their actual planar normals rather than doubling the normal-map effect. Their highest face remains at the original surface, while the beds and bevels are recessed. The geometry contains no collisions and is clipped to existing terrain contours. The disk baker preserves selected Lava response. In Visual Lab, F8 exposes Material detail, Normal strength and Rock recess depth. Both numeric controls default to 1.0. Controls reach original, private and baked bindings through `lava_selected_materials.gd.set_detail`.

Floor repeats remain 8/2.1 world units; top and ramp repeats are 1.6 world units. Wall/facade projection retains 3.2 x 1.6 world units. Border and guard artwork follows the existing distance chart at approximately one world unit per repeat. Border widths, authored contours, collision and physics remain unchanged. Alex explicitly approved collisionless relief and then requested recessing it rather than raising it above gameplay surfaces.

The final 5B is generated with `experiments/lava_texture_refined/copper_revision/render.gd -- --output=res://experiments/lava_texture_refined/final_revision --timber-scale=0.96`. The authoring stages and earlier comparisons are retained under `experiments/lava_texture_refined/`.
