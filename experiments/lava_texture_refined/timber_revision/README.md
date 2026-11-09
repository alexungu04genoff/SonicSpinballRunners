# Lava Reef — orange timber and rock insets

Alex explicitly clarified:

- The second-floor direction is **orange wood with rock insets**, not irregular rocks replacing the whole deck.
- “9A is good” referred to the **latest dark iron-and-brass 9B**.
- Warm charcoal 3B and the latest 9B are approved and remain unchanged.

Only 5B is revised here. It contains broad orange timber planks with lengthwise grain, sparse knots, and embedded pale-gold mineral-rock clusters. The supplied gameplay screenshot informs the timber/rock relationship and the gold, orange, dark purple and restrained cool mineral palette. The screenshot was inspected, not cropped into an asset.

`5B.png` is a 512 x 512 albedo. `5B-repeat.png` tiles the exported pixels 2 x 2. `timber.gdshaderinc` uses the existing deterministic shader helpers and periodic whole-rock selection. Rock insets are part of the texture in this phase: no loose obstacle meshes or collision changes are introduced.

`render.gd` reuses the preceding generic material-study renderer and the approved 3B/9B PNGs directly. Its optional top-texture/output arguments preserve the prior default study behavior and old review images. The study is unlit, on generic geometry, and explicitly not an in-game screenshot. `timber-comparison.png` changes only 5B between the two sides. `5B-review.png` shows the source texture and repeated preview.

Graphical export and visual review completed. The fixed rock clusters remain visibly periodic in the repeated preview; there is no obvious hard tile seam. Final material depth, gameplay scale and mapping remain for later approved phases. Godot still logs the certificate-store startup error; image rendering completed.

This remains Phase 2 review. Production, other selected textures, current lava and current crystals are unchanged. No new response maps, test suite, headless run, production bake, commit or push.
# Subsequent floor balance revision

Alex approved the timber concept, then requested a shared middle brightness and matching mineral treatment across 1C and 5B. The current candidate is in `../balanced_revision/`; these images remain as the previous comparison. Approved 3B and 9B remain unchanged.

