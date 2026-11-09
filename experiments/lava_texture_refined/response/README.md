# Lava Reef structural response

Alex approved the shared rock/wood depth proposal and then authorized completing the remaining phases. `bake.gd` combines the existing selected, timber and balanced procedural source functions with `response.gdshaderinc`. No source image is sampled for height, and no albedo is rewritten.

- Lower-floor rocks and wood insets use the same broad asymmetric crown and bevel profile, scaled to each material's physical cell size. Both receive actual collisionless planar facets after Alex rejected the normal-only result and approved visual geometry. The relief is recessed below the original gameplay surface, as requested in the follow-up.
- Timber uses its existing staggered planks, bevel widths and grain paths. Grain depth is much smaller than the plank joints or rock facets.
- Purple walls use the existing basalt-column sites and cross-joints. Ramp paving uses its fitted octagonal block outline.
- Pipe trim follows the selected single/twin profiles and collars. Guards and facade frames receive restrained structural bevels.
- Roughness keeps rocks matte, timber slightly smoother and painted/alloy trim moderately smooth. Metalness and emission are unchanged.

OpenGL normal maps are calculated from finite differences of the structural height field at the physical repeat size, before the 1024 authoring render is downsampled to the original texture resolution. V points down in the texture and normal Y points up. Runtime maps are in `assets/textures/lava_reef/selected/`; grayscale height references remain here. Reference decoding is `red * range - 0.003` world units, where range is 0.12 for 1C and 0.065 for the other roles.

`rock_mesh.gd` traces whole rocks across a 3x3 repeat, simplifies their footprints and constructs a bevel ring plus a faceted crown. There are 64 rocks/1887 triangles per lower-floor repeat and 7 rocks/213 triangles per upper-floor repeat. The source height is scaled by 0.75; the runtime subtracts the maximum height so no rock rises above the original gameplay surface. Timber and joints form the recessed bed. The production helper clips these meshes to terrain contours, and the normal disk baker stores the result. Collision data is never touched. This is visible relief, not a physics floor change.

The manifest records all eight original albedo hashes and companion paths. The runtime default normal strength is 0.85. Geometry uses its actual face normals without a second normal-map perturbation. Cavity maps are limited to the two floors. Parallax remains off; atmosphere and authored collision remain unchanged. Canonical captures and loaded-material receipts are in `../canonical/`.
