# Endless authored-Act experiment

Open **Play Endless.cmd**. This is another level source for the shared game loop, ball, input, profiles, mechanics and camera. Free Play remains the default application mode.

The trial uses checked-in snapshots of **Second Simple**, **Third Complex**, and **First Try Smooth Decor** in `data/endless/`. Each Zone contains three shuffled Acts under one theme. Themes use a shuffled bag without adjacent repeats. Act entry and exit connectors align physically; crossing the next Act's activation line transfers the checkpoint. No score gate, limited lives or new character physics is introduced.

## Continuous travel

Normal play never changes scenes or teleports between Acts. Upcoming collision and visual roots attach above the existing course. The same camera follows the same ball across the seam. Draining retries the active Act's Spawn.

The background transition starts 200 pixels before a Zone entrance and finishes 250 pixels beyond it. These distances are provisional. Two independently rendered scenery/sky layers follow the gameplay camera during the overlap. Scenery fades by camera travel distance; foreground light direction, color, intensity, ambient color and exposure blend with it. Old scenery stops rendering after the fade and retires later. Foreground lighting uses ambient color without live sky reflections so changing the directional light does not repeatedly rebuild sky radiance. Reflective-material polish remains a visual-review item.

**T** starts a spectator camera tour with physics parked. It never pushes the ball into geometry. **N** jumps the camera to the next ready Act only in this diagnostic tour. Ordinary traversal does not use that jump. Leaving the tour serves safely at the current checkpoint. The HUD provides tour speed, pause and reset; **F3** shows streaming timings.

## Preparation and bounds

Startup waits for the first **two** Act/theme variants and the opening background. It does not enumerate every Act/theme combination. Once play begins, preparation fills the rest of the current Zone and the next Zone. Only one cold variant builds at a time.

The library keeps at most eight visual recipes and three theme definitions, with active entries pinned. Resident scenes retain the previous Act and a bounded lookahead. Each live physics shape and visual node is installed separately under a frame budget. Old trees are freed incrementally. Private resource calculations run on workers; scene nodes are created on the main thread with cooperative frame breaks. A private rendering viewport warms new materials before readiness. If the player outruns preparation, physics pauses safely before an unavailable entrance with the course still visible, then resumes automatically.

First-use graphics setup includes uploading textures and meshes to the graphics card and compiling shaders. Godot Compatibility/ANGLE can still stall during these operations. Some procedural scenery creation also exceeds the frame budget. Baking removes geometry calculation, not every preparation cost. Frame timing remains an explicit prototype check; this implementation does not guarantee hitch-free cold loading on every machine.

## Bake after verifying an Act

1. Finish playtesting and save the Act in Act Builder.
2. Click **Bake** in the editor header. A separate progress window prepares all available theme geometry for that saved Act.
3. Keep the resulting `<Act name>.bake/` folder beside its `.tres` source. Each theme has a compressed `.res` sidecar.

The sidecar stores pre-decomposed collision shapes, floor outlines, terrain/cliff meshes and contour bands. It does not embed textures, materials, scenery scene trees or gameplay state. Theme materials bind to the loaded meshes. Runtime requests only the selected sidecar asynchronously, then constructs scene nodes incrementally.

Every sidecar records the source fingerprint, engine version and geometry-pipeline fingerprint. Stale or absent bakes fall back to staged preparation; source Acts are never rewritten. Re-bake after changing geometry or its builder code. Sidecars are derived artifacts ignored by Git; packaging a release must include freshly generated sidecars.

**Bake Endless.cmd** prepares the three trial snapshots in one offline run. This is the authoring bake, not a session loading screen. The original editable Acts in `data/acts/` remain separate from those snapshots. Replacing a trial snapshot requires re-baking it.

For a repeatable run, use `Play Endless.cmd -Seed 18 -Tour -FrameTiming`. The pool currently contains the three agreed Acts; adding a larger authored library requires updating the pool manifest and verifying connector compatibility.

## Checks

- `tests/endless_regression.gd`: seeded ordering, connector alignment, all nine ordered seams and source immutability.
- `tests/geometry_bake_regression.gd`: round-trip collision equality, stale-bake rejection and material-free mesh serialization.
- `tests/endless_scene_smoke.gd`: startup scope, readiness guard, bounded caches, nine Zone transitions, stationary tour ball, shared engine identities, background blending, physical checkpoint activation without teleporting and normal launch/reset. `--captures` writes screenshots; `--transitions=3` runs a short rendered check; `--full-buffer` also waits for six resident Acts.

Verified with Godot 4.7.2 on Windows: ordering/seams passed 788 checks and bake serialization passed 1,001. A rendered nine-Zone run passed 206 checks before the final background warm-up and physical-activation assertions. The final short rendered check passed all 47 assertions, including a six-Act buffer, invisible background rendering during warm-up and restored native particle processing. That run used the clean intended changes without bake sidecars and measured a 70.15 ms maximum frame and 26.505 seconds to prepare the opening buffer. An earlier cold run reached 332.51 ms, so first-use stalls remain unresolved. These are local diagnostic observations, not performance guarantees. The clean intended changes passed 813 theme checks; editor smoke passed 92, and the editor and baker passed final script checks. The existing mechanics regression still fails its composed spinner/magnet/rail fixture, also reproduced on unchanged commit `b5fe20b`.

Manual review: pinball traversal and flipper timing, connector readability, scenery/lighting at the blend midpoint, and cold-frame performance. Unlimited-duration coordinate rebasing and production packaging remain future work.
