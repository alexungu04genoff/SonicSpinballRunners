# Lava Reef — muted timber proposal and restored purple wall

Alex liked the matched brightness and shared rocks, but found the orange timber hue conflicting and preferred the earlier purple wall. This Phase 2 proposal changes only the 5B timber hue/saturation and restores the earlier refined purple 3B in the generic study.

- **5B:** Muted reddish-brown timber with a slight plum undertone. Grain, knots, plank layout, mineral inset positions and rock shading remain from the balanced revision.
- **3B:** Reuses `../3B.png` directly, restoring the earlier violet basalt columns. It is not regenerated.
- **1C:** Reuses `../balanced_revision/1C.png` unchanged.
- **9B:** Retains the approved dark iron-and-brass facade from `../warm_revision/9B.png`.

`wood.gdshaderinc` reduces timber chroma toward its weighted sRGB value and adds a small red/plum tint whose weighted signal is zero. The shared mineral function is unchanged. Mean weighted sRGB signal is approximately 0.4048 both before and after; this is an albedo comparison metric, not a photometric lighting measurement. Values and source paths are recorded in `render-receipt.json`.

`render.gd` exports the 512 x 512 albedo through the existing graphical Godot shader workflow with a 1024 x 1024 authoring render. `5B-repeat.png` copies the saved pixels into a 2 x 2 repeat. `compose.ps1` creates `copper-comparison.png` and `5B-review.png`. The generic unlit study uses the same geometry, camera and mapping as the previous comparison; it is not a gameplay screenshot.

Both review images were inspected. There is no obvious hard seam in the repeated preview; the two rock clusters remain visibly periodic. All 12 production-source hashes match the Phase 1 baseline. The existing certificate-store startup error did not prevent rendering. No production assets, gameplay, material-depth maps or live bindings were changed. No headless checks, full test suite, build, commit or push was run.

The new wood hue remains a proposal awaiting approval before integration. The earlier purple wall follows Alex's latest preference.
