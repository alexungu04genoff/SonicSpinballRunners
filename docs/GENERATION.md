# Phase 2A: modular chunk generation

## Scope and controls

Generator version 1 chooses one of four upper sections, one mirror state, and a horizontal shift of zero or one 100-pixel cell. The lower launch deck, serve, flippers, and drain remain fixed. There are 16 authored combinations; symmetric geometry means some may feel similar. Seeds range from 0 to 2147483647 in the debug UI. A local `RandomNumberGenerator` shuffles candidates deterministically, independent of gameplay randomness.

Build at serve or while paused. Regeneration is deferred out of physics callbacks and checks safety again before replacing anything. It validates first, then replaces the upper collision section and collisionless presentation, repopulates rings, resets score/meter/ball count and all pending playground timers, and returns the ball to serve. The lower section and flippers remain the same instances. Profile, session overrides, modifier toggle, pause state, and overlays persist. A paused rebuild stays paused; resume before launching.

The current seed, chunk IDs, mirror flag, shift, clear join width, and fallback status appear beside the table. The output log records generator version and the same layout signature. Repeat reproduces the current seed, even if the seed field contains an unbuilt edit. Next increments the seed and may produce the same combination. No seed or run persistence is included.

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

Rejected combinations are recorded and the next shuffled candidate is tried. If all fail, the original upper/lower pair is validated and used. If even that fails, generation reports failure and preserves the existing table; startup reports an error rather than running invalid geometry.

## Sample seeds (version 1, Godot 4.7.2)

| Seed | Upper section | Mirrored | Shift | Clear join |
| --- | --- | --- | --- | --- |
| 1 | Central Targets | Yes | 0 cells | 518 px |
| 2 | Risk Route | Yes | 0 cells | 468 px |
| 10 | Bumper Garden | Yes | 1 cell right | 518 px |
| 12 | Outer Return | No | 1 cell right | 468 px |
| 13 | Outer Return | No | 0 cells | 468 px |

Seed reproduction applies to the current engine, catalogue ordering, resources, and generator version. Editing layouts or changing the RNG implementation may change a seed's result; signatures record transformations to help diagnose that. There is no serialized layout format or cross-version replay guarantee yet.

## Validation limits and next expansion

Static clearance establishes coarse geometric connectivity, not reachable pinball trajectories under gravity. It may miss a tiny pocket, a stable resting point, an awkward rebound angle, or a moving-flipper corner case. The graph can also conservatively reject a narrow but technically traversable route. Brief real-physics tests cover selected paths and seeds, not all possible inputs, velocities, and modifiers.

Manually compare the central cluster's approaches, the outer return's entry/exit, the risk route's scoring path, and the join shoulders at low and high speeds. Check both profiles and a physical gamepad. Before adding many chunks, establish authoring guidance from those playtests and preserve failing seeds/shots as focused regressions.

The generator deliberately assumes two seven-row sections and the current camera bounds. Additional height, multiple junctions, branching routes, or new collider kinds will require extending placement and clearance handling. Keep transformations and descriptors shared; do not add a parallel visual layout. A catalog/version migration policy and actual saved layout records become useful when seeds must survive content updates.
