# Phase 2A: modular chunk generation

## Scope and controls

Generator version 2 chooses one of four upper sections, one mirror state, and a horizontal shift of zero or one 100-pixel cell, guided by an Easy / Normal / Hard preference. The lower launch deck, serve, flippers, and drain remain fixed. There are 16 authored combinations; symmetric geometry means some may feel similar. Seeds range from 0 to 2147483647 in the debug UI. A local `RandomNumberGenerator` shuffles candidates deterministically, independent of gameplay randomness. The seed and preference together define the generation configuration.

Build at serve or while paused. Regeneration is deferred out of physics callbacks and checks safety again before replacing anything. It validates first, then replaces the upper collision section and collisionless presentation, repopulates rings, resets score/meter/ball count and all pending playground timers, and returns the ball to serve. The lower section and flippers remain the same instances. Profile, session overrides, modifier toggle, pause state, and overlays persist. A paused rebuild stays paused; resume before launching.

The panel displays the current seed, preference, actual estimate, reasons, chunk IDs, mirror flag, shift, and fallback status. The output log records generator version and the same layout signature. Build applies the entered seed and selected preference. Next increments the current seed with the selected preference. Repeat restores both current settings, even if controls contain unbuilt edits. No configuration or run persistence is included. Changing character or modifier tuning does not silently alter the generation configuration or its estimate.

## Difficulty estimation and selection

Technical validity and mechanical challenge are separate. The validator still requires aligned, closed collision boundaries, sufficient clearance, and coarse connectivity. The preference never changes those rules. Traversable corners and ledges are intentional possible challenges; this implementation does not replace them with ramps or alter any authored collider.

Each `ChunkData` exposes an authored `estimated_difficulty` rating from 0 to 100. Initial values are Bumper Garden 20, Central Targets 40, Outer Return 45, Risk Route 65, and lower/fallback sections 25. These are provisional authoring judgments, not measured success rates. The weighted chunk component uses 75% upper and 25% lower, since the lower section is fixed.

The connector component uses world-space geometry:

| Factor | Calculation | Maximum points |
| --- | --- | ---: |
| Narrowing | Lost checked width relative to the lower opening's checked width | 30 |
| Opening offset | Absolute difference between opening centers, normalized by one 100-pixel cell | 15 |
| Largest ledge | Largest closure shoulder, normalized by six ball diameters (168 px) | 40 |
| Approach clutter | Fraction of 42 clearance samples blocked by rails or bumpers | 15 |

Each normalized factor clamps to 0–1. Approach samples use seven evenly spaced columns across the checked opening and rows at 50/100/150 pixels above and below the join. They are separate from the stricter critical-passage validity check. The displayed estimate is `0.5 × weighted_chunk_rating + 0.5 × connector_score`, clamped to 0–100. Easy is below 37.5, Normal is 37.5 to below 62.5, and Hard is 62.5 or higher. Labels indicate estimate bands, not guarantees about a player's experience.

Preference targets are 25, 50, and 75. Selection first finds the smallest distance from that target among technically valid candidates. It then selects the first valid candidate in seeded order whose distance is at most eight points above that minimum. This small variety allowance keeps multiple authored layouts available. A tested-invalid candidate cannot win, and raising a preference cannot turn a collider error into acceptable difficulty. Only candidates needed to establish the nearest distance or select a winner are validated; rejected entries record those tested failures.

The existing library spans approximately **29.4–55.3**, so it does not yet contain a Hard-rated result. A Hard request still displays the selected Normal estimate and an explicit preference-mismatch note. Normal and Hard selections overlap. For seeds 1–24, mean selected scores were **33.8 / 50.7 / 52.1** for Easy / Normal / Hard. These figures show that selection responds to the preference, not that difficulty is calibrated.

Current transitions all use horizontal closure shoulders. The estimator accounts for their protrusion but does not classify hypothetical smooth ramps, curved joins, or multi-turn slopes. Actual upward-shot difficulty, incoming velocity, gravity, profile differences, and moving geometry require playtesting or future targeted measurements. This milestone adds no trajectory simulation, progression, or difficulty framework.

## Data and coordinate contract

- `data/chunks/`: four 700 × 700 upper resources. `data/lower_chunk.tres`: fixed 800 × 700 lower deck at grid row 7. `data/upper_chunk.tres`: unchanged original collision geometry used for fallback and the legacy regression fixture.
- `ChunkData.map_point()` mirrors around the local footprint width, then adds the horizontal cell shift. `world_point()` adds the grid origin. `world_rect()` transforms both rectangle corners and normalizes them after mirroring. Triangle vertices mirror as offsets around their transformed center.
- `gameplay_descriptors()` supplies world-space geometry to validation and `TableChunk`. The renderer consumes that chunk's instantiated descriptors, including closure rails. Markers, chunk bounds, and connector overlays use the same transforms. No rotation is represented.
- Placement uses 100-pixel cells. Connector rectangles use a 5-pixel authoring grid, retaining the original 55-pixel wall inset. Top/bottom rectangles lie inside their chunk and touch the corresponding horizontal edge.
- Navigable outlines are closed polygons enclosing the playable interior, including the open join. Route probes identify representative lanes and flipper approaches. Neither outline nor probe creates a collider. Rings and the upper entry marker also serve as reachability targets.
- Visual attachment metadata remains a future theme hook. All current meshes use primitive materials; there are no themed assets or 3D colliders.

## Connector validation

Opening compatibility uses world-space horizontal spans at a shared Y boundary. The upper bottom rectangle ends at `y = 700`; the lower top rectangle begins there. Their X spans must overlap by at least 300 pixels. IDs are descriptive, not matching keys.

Both opening edges must meet exactly one authored rail endpoint. The generator closes the non-shared spans using the same radius-12 capsule rails as the table. Closures meet the existing rounded rail ends and never cross the shared opening. They are visible gameplay geometry, not invisible barriers. The current upper openings are contained inside the lower opening; closure shoulders can rebound an upward shot back into the lower deck.

The checked passage extends 45 pixels above and below the seam, inset 36 pixels from each overlapping edge. Geometry clearance is sampled every 10 pixels there, using ball radius 14 plus a 6-pixel safety allowance against rails, circles, and triangle edges/interiors. Current authored clear passages are 468 or 518 pixels wide.

The validator also checks table footprint bounds, allowed vertical placement, positive connector dimensions, authoring-grid alignment, and opening/rail alignment. It builds a 25-pixel static clearance grid within the two navigable outlines, then floods from serve using four neighbors and midpoint clearance checks. All route probes, rings, and the upper entry must have a reachable clear cell within 36 pixels. More than four disconnected clear cells rejects an obvious pocket.

If all candidates fail, the original upper/lower pair is validated and used, with its actual difficulty estimate. If even that fails, generation reports failure and preserves the existing table; startup reports an error rather than running invalid geometry.

## Sample configurations (version 2, Godot 4.7.2)

| Seed | Preference | Upper section | Mirrored | Shift | Estimate |
| --- | --- | --- | --- | --- | --- |
| 1 | Easy | Central Targets | Yes | 0 cells | Easy 36.9 |
| 10 | Easy | Bumper Garden | Yes | 1 cell right | Easy 29.4 |
| 6 | Normal | Outer Return | No | 1 cell right | Normal 47.7 |
| 1 | Normal | Risk Route | No | 0 cells | Normal 55.3 |
| 1 | Hard | Risk Route | No | 0 cells | Normal 55.3 |

Reproduction requires the same seed, preference, engine, catalogue, ratings, scoring rules, and generator version. Version 2 intentionally changes the version 1 seed mappings. Signatures record the version, preference, and transformations to diagnose differences. There is no serialized layout format or cross-version replay guarantee yet.

## Validation limits and next expansion

Static clearance establishes coarse geometric connectivity, not reachable pinball trajectories under gravity. It may miss a tiny pocket, a stable resting point, an awkward rebound angle, or a moving-flipper corner case. The graph can also conservatively reject a narrow but technically traversable route. Brief real-physics tests cover selected paths and seeds, not all possible inputs, velocities, and modifiers.

Manually compare the central cluster's approaches, the outer return's entry/exit, the risk route's scoring path, and the join shoulders at low and high speeds. Check both profiles and a physical gamepad. Before adding many chunks, establish authoring guidance from those playtests and preserve failing seeds/shots as focused regressions.

The generator deliberately assumes two seven-row sections and the current camera bounds. Additional height, multiple junctions, branching routes, or new collider kinds will require extending placement and clearance handling. Keep transformations and descriptors shared; do not add a parallel visual layout. A catalog/version migration policy and actual saved layout records become useful when seeds must survive content updates.
