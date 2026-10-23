# Construction grid experiment (kit v1)

The construction grid authors tested chunks. It never quantizes ball positions, velocity, collision response, or input. Existing chunks and the seeded three-section generator remain available.

## Try it

In **Table Generator**, pause or wait at serve, select **Grid base** or **Grid variant** under **Middle section**, then build the seed and difficulty. This replaces only the middle catalogue; top and launch sections still use the existing catalogue. **Existing catalogue** restores the original choices. Repeat preserves seed, difficulty and middle mode. Physics tuning, camera settings, pause and overlays survive a rebuild.

As of generator v9, **Easy** automatically uses a wider recipe in either grid mode. Try **Easy seed 8**: both modes estimate 28 and match the requested tier. Normal and Hard continue using their original recipes; switching difficulty back restores those designs. Existing catalogue geometry and selection remain unchanged.

Enable **Construction grid** to see the 50 px grid, local axis coordinates, piece anchor coordinates and orange footprint guides. The ball telemetry shows its local cell while inside the grid section. Mirrored chunks retain their authored coordinate labels. These guides describe the source recipe; Normal's generated connector collars may reshape the ends of its walls. Enable **Physics geometry** to inspect the final colliders. Footprint boxes are authoring extents, not collision shapes or proofs of free passage.

## One authoritative layout

- `data/grid_chunks/flow_relay.tres`: straight left bank, two right slopes, two bumpers, seven rings and staggered side recovery paddles.
- `data/grid_chunks/flow_relay_variant.tres`: the same recipe with a faceted curved bank and the second bumper moved left by one cell.
- `data/grid_chunks/flow_relay_easy.tres`: a full-width 16-cell recipe with broad openings, gentle banks on both sides, separated bumpers and wider-spaced recovery paddles.
- `data/grid_chunks/flow_relay_easy_variant.tres`: the Easy recipe with faceted curves on both sides and the second bumper moved left by one cell.
- `GridChunkRecipe`: dimensions, connector spans, placements, markers and route probes, all in grid units.
- `GridPieceKit`: reusable local shapes, footprints and rail ports, with no theme or material definitions.
- `GridChunkCompiler.compile(recipe)`: validates and returns fresh `ChunkData`; no compiled resource is saved as a second source of truth.

Edit the `.tres` resource or its exported fields in Godot's Inspector, then restart the game to load file changes. Runtime Build recompiles the loaded recipe; it does not watch files. No custom editor or in-game painting interface is included. For example, the base contains:

```gdscript
{"piece": "bank_right", "cell": Vector2i(1, 3), "chain": "left"}
{"piece": "bumper", "cell": Vector2i(9, 6)}
```

The variant changes those two placements:

```gdscript
{"piece": "curve_right", "cell": Vector2i(1, 3), "chain": "left"}
{"piece": "bumper", "cell": Vector2i(8, 6)}
```

Bank and curve stamps share endpoint ports `(0, 0)` and `(0, 4)`, so the swap requires no neighboring wall edits. Changing an opening requires changing `top_span` or `bottom_span` **and** the matching boundary endpoints. The compiler rejects disconnected ports.

## Coordinates and pieces

Construction cells are **50 physics pixels**. Anchors are integer grid intersections measured from the local top-left; they are not automatically offset to cell centers. Original 14 × 14 recipes compile to 700 × 700 px; Easy's 16 × 14 recipes compile to 800 × 700 px. This is distinct from the existing **100 px chunk-placement grid**. Whole chunks still mirror and shift using the generator's original transforms; full-width Easy recipes have no spare horizontal shift. Neither chunks nor individual pieces rotate.

| Piece | Shape / use |
| --- | --- |
| `open` | An optional empty-cell annotation; unoccupied cells are also empty. |
| `rail_v`, `rail_h` | Straight rail with positive integer `span`, default 1. |
| `slope_left`, `slope_right` | Diagonal rail, with a positive integer `span`. |
| `corner_left`, `corner_right` | Intentional horizontal-to-vertical corner; positive integer `span`. |
| `bank_left`, `bank_right` | Four-row, two-segment bank stamp. |
| `curve_left`, `curve_right` | Four-row faceted curved-bank stamp with matching ports. |
| `bumper` | Radius 36 px; footprint extends beyond its anchor cell. |
| `ring` | Existing stationary collectible and cosmetic pickup animation. |
| `flipper_left`, `flipper_right` | Existing dynamic paddle, length 125 / 115 px; footprint includes its full swing. |

Rail placements belong to either the `left` or `right` outer boundary chain. Piece definitions may include fractional-cell shape details even though placement anchors are integers. The compiler joins matching endpoints, rejects ambiguous/duplicate branches and intersections, and merges adjacent collinear segments. It derives the navigable outline from those same two chains. There are no tile perimeter colliders or duplicate TileMap collisions. Curves remain deliberately faceted and passive: ordinary physics supplies all rebound energy.

Original recipes place the left paddle at `(3, 10)` and the right at `(11, 12)`. Easy recipes move the right paddle to `(13, 12)`, widening the central passage. Mirroring transforms both paddles consistently. The bottom deck retains the corrected drain geometry and unlimited respawns.

## Validation and reproduction

The compiler checks dimensions, supported pieces, integer anchors/spans, matching connector ports, boundary intersections, marker/ring clearance, bumper spacing and complete paddle-segment sweeps against walls, bumpers and other paddles. Sweep sampling uses an additional conservative margin. A footprint overlap is not automatically invalid; actual geometry and physical clearance decide.

The generator validates compatible joins, the full seam band and continuous routes through the complete table. Normal v8 also requires flowing junctions and complete ball clearance between generated banks and the paddle swing. Only generated seam coordinates round to the common 5-pixel connector grid; authored pieces remain at their exact positions. Estimates use the resulting geometry, including bank inclination. A requested tier can be unavailable with this small optional catalogue; the panel reports the closest valid alternative rather than pretending it matches. Invalid grid compilation preserves the active table instead of silently substituting a legacy middle.

Record **generator v9, kit v1, recipe files, middle mode, seed, difficulty and Godot version**. Version 7 introduced the construction mode; v8 changed Normal connector selection. Version 9 adds Easy-specific grid recipes; Existing catalogue and grid Normal/Hard preserve their v8 geometry. The kit and original recipes remain unchanged. Recipe edits intentionally change the layouts that use them. The generator still selects tested chunks; it does not place random individual pieces.

For the original recipe comparison, use **Normal seed 8** in both grid modes: the same top section and transform show the authored bank swap and 50 px bumper move clearly. Both generated junctions are curved, with an estimated difficulty of 38.6. For the broader designs, use **Easy seed 8** in both modes (28 points). Sampled Easy seeds 1–12 use both existing broad upper designs and mirrored grid middles without falling back to Normal.

Easy openings span 50–750 px, leaving only a **5 px** mismatch against legacy 55–745 px rails, instead of the old 95–105 px closure shoulders. The unchanged generator labels these small closures `Step`; they are below the 12 px rail radius, use rounded capsule geometry and leave a 618 px checked corridor. They are not perfectly identical endpoints. Both joins pass real bidirectional ball probes. Interior Easy banks protrude at most 50 px (37.5 px for curves), with no horizontal ledges; both sides have a maximum horizontal/vertical grade of 0.5. The improvement comes from authored geometry, not a lower difficulty label or modified physics.

The former midpoint-alignment restriction could reject grid/legacy banks and exhaust the catalogue before retaining Step joins. Version 8 supports their shared seam coordinates and excludes stepped Normal candidates. Grid base Normal 18 built in about 0.335 seconds in one measured run, compared with 18.756 seconds in v7. This is a local sample, not a performance guarantee. Generation still runs synchronously while paused or at serve; exhaustive fallback searches can delay the UI.

Run `tests/grid_easy_regression.gd` for the Easy recipes and `tests/grid_chunk_regression.gd` for the original kit, with Godot headless and `--fixed-fps 120`. See [executed checks](VERIFICATION.md). Static connectivity and sampled shots cannot prove every possible trajectory safe. Human testing remains important for low-speed pockets, recovery timing, profile extremes and subjective flow.

## Why Resources first

Godot's built-in [TileMap editing and reusable patterns](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html) are a viable future authoring interface. [TileSet custom data](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html) belongs to tile definitions, while our multi-cell stamps and dynamic paddle clearances need additional validation. The small Resource experiment exercises the shared compiler without adding a tile atlas or editor plugin.

A future TileMapLayer adapter should read cells into this same authoritative recipe/compile path, account for [`map_to_local()` returning cell centers](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html), and disable TileMap collision/navigation when generating the existing colliders. It must not keep a separately editable compiled layout. Scene tiles are unnecessary here.

Current limits: fixed 14-row dual-opening middle recipes, two monotonic outer wall chains, a small fixed kit, whole-chunk mirroring only, no arbitrary interior rail islands or custom per-placement object sizes. Intentional corners are supported; usable drains and successful recovery still require whole-table physical checks.
