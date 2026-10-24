# Construction grid experiment (kit v3)

The construction grid authors tested chunks. It never quantizes ball positions, velocity, collision response, or input. Existing chunks and the seeded three-section generator remain available.

## Try it

In **Table Generator**, pause or wait at serve, select **Grid base** or **Grid variant** under **Middle section**, then build the seed and difficulty. This replaces only the middle catalogue; top and launch sections still use the existing catalogue. **Existing catalogue** restores the original choices. Repeat preserves seed, difficulty and middle mode. Physics tuning, camera settings, pause and overlays survive a rebuild.

**Easy** automatically uses a wider recipe in either grid mode. Try **Easy seed 8**: both modes estimate 28 and match the requested tier. Generator v10 rounds their banks and removes the small grid/legacy seam steps. Normal and Hard retain their original bank shapes. All four recipes use pivots closer to the side walls. Green Hill's Grid base / Grid variant shortcuts preserve the active seed and difficulty; its footer displays both.

Enable **Construction grid** to see the 50 px grid, local axis coordinates, piece anchor coordinates and orange footprint guides. The ball telemetry shows its local cell while inside the grid section. Mirrored chunks retain their authored coordinate labels. These guides describe the source recipe; Normal's generated connector collars may reshape the ends of its walls. Enable **Physics geometry** to inspect the final colliders. Footprint boxes are authoring extents, not collision shapes or proofs of free passage.

## One authoritative layout

- `data/grid_chunks/flow_relay.tres`: straight left bank, two right slopes, two bumpers, seven rings and staggered side recovery paddles.
- `data/grid_chunks/flow_relay_variant.tres`: the same recipe with a faceted curved bank and the second bumper moved left by one cell.
- `data/grid_chunks/flow_relay_easy.tres`: a full-width 16-cell recipe with broad openings, gentle banks on both sides, separated bumpers and wider-spaced recovery paddles.
- `data/grid_chunks/flow_relay_easy_variant.tres`: the same rounded Easy banks, with the second bumper moved left by one cell.
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
| `soft_bank_left`, `soft_bank_right` | Four-row rounded bank, 16 shallow facets and 30 px maximum bulge, with the same ports. Used by both Easy recipes. |
| `wide_bank_left`, `wide_bank_right` | Eight-row rounded bank, 16 facets and a 50 px apex on an integer-cell anchor. Bank Return mounts a circle directly on that curved bank. |
| `bumper` | Radius 36 px; footprint extends beyond its anchor cell. |
| `bumper_small`, `bumper_large` | Free-standing circles with radius 24 / 48 px and the same full-ball spacing rules. |
| `wall_bumper_left`, `wall_bumper_right` | Radius 36 px circles whose centers sit directly on the named boundary. Their rear half is intentionally sealed by the wall. |
| `sling_left`, `sling_right` | Wall-mounted triangular bumpers, 100 px tall and projecting 70 px into the field. Their entire rear edge must touch one straight segment of the named wall. |
| `ring` | Existing stationary collectible and cosmetic pickup animation. |
| `flipper_left`, `flipper_right` | Existing dynamic paddle, length 125 / 115 px; footprint includes its full swing. |
| `side_flipper_left`, `side_flipper_right` | Same paddle with its pivot and footprint offset half a cell outward; placement anchors remain integer grid points. |

Rail placements belong to either the `left` or `right` outer boundary chain. Piece definitions may include fractional-cell shape details even though placement anchors are integers. The compiler joins matching endpoints, rejects ambiguous/duplicate branches and intersections, and merges adjacent collinear segments. It derives the navigable outline from those same two chains. There are no tile perimeter colliders or duplicate TileMap collisions. Curves remain deliberately faceted and passive: ordinary physics supplies all rebound energy.

Original recipes anchor the left paddle at `(3, 10)` and the right at `(11, 12)`. Easy recipes move the right anchor to `(13, 12)`, widening the central passage. With kit v2's side stamps, actual pivots are `(125, 500)` and `(575, 600)` pixels, or `(675, 600)` for Easy's right paddle. The 25 px outward offset leaves each pivot 75 px from its authored straight wall, with full-ball passage behind the swing. Compiler descriptors, footprint guides and mirroring all include that offset. The bottom deck retains the corrected drain geometry and unlimited respawns; the top catalogue supplies its own short recovery paddle.

## Validation and reproduction

The compiler checks dimensions, supported pieces, integer anchors/spans, matching connector ports, boundary intersections, marker/ring clearance, bumper spacing and complete paddle-segment sweeps against walls, bumpers and other paddles. Sweep sampling uses an additional conservative margin. A footprint overlap is not automatically invalid; actual geometry and physical clearance decide.

Kit v3 gives deliberately mounted bumpers a `wall_attachment` descriptor. This is an explicit authoring contract: the compiler rejects a mount displaced from its named wall. Only clearance behind that flush attachment is exempted; clearance against the opposite boundary, other bumpers, rings and flipper sweeps remains required. Ordinary `bumper` placements still need a full ball passage behind them. Triangles compile to the same `kind: triangle`, position and local polygon descriptors already used by the launch-deck slings, so physics and presentation share their exact transformed outline.

## Authored Zone library

Green Hill Zone generator v2 uses eight Easy relay recipes from this kit. Every nine-chunk course selects five distinct relay IDs, plus its final cap and three reusable launch/drain decks. Mirroring and safe whole-chunk horizontal shifts provide variation within each authored purpose. The two narrower recipes share one legal horizontal alignment within a course so adjacent recovery paddles are not squeezed by opposing shifts. Grid base and Grid variant each shuffle the entire library with a stable seed salt; neither mode repeats a single recipe throughout the Zone.

| Recipe | Intended shot / recovery pattern |
| --- | --- |
| `zone_wall_garden.tres` | Side-wall rebound targets, different circle sizes, and ring arcs between targets. |
| `zone_sling_alley.tres` | Offset wall slings and two broad ring lanes around one large center target. |
| `zone_orbit_cluster.tres` | Three small targets on one side, with a wide outside route and curved ring sequence. |
| `zone_bank_return.tres` | Rounded bank with an apex-mounted circular target, an opposing wall target and a broad ring return arc. |
| `zone_staggered_steps.tres` | Recovery paddles at different heights, with diagonal ring follow-ups. |
| `zone_winding_lane.tres` | Alternating shallow curved banks and an S-shaped ring route. |
| `zone_twin_banks.tres` | Paired rounded banks, wide central travel and two optional side ring paths. |
| `zone_crosscourt.tres` | Asymmetric sling, wall target and staggered recovery encouraging cross-table shots. |

Official Green Hill remains Easy. The development override uses existing narrower Normal bank/rebound recipes, or the denser `zone_target_gauntlet.tres` and `zone_crossfire.tres` Hard recipes with their matching capped sections. The requested tier changes physical geometry and must match the final whole-course difficulty estimate. A deterministic search of at most 48 authored combinations reports failure explicitly if no valid match exists; it never substitutes an Easy course. Difficulty never relaxes collider validation. These development layouts are test content, not tuned official Zone difficulties.

Future checkpoint funnel rails carry `checkpoint_only` in the shared descriptors. Course entry validation uses the open state because those rails and recovery paddles arm only after the ball crosses the clear marker above them. Active funnel drains and recoveries require separate real-physics checks.

Run `tests/playfield_catalogue_regression.gd` for compilation, illegal attachment rejection, transformed triangles, real mounted-bumper/sling contacts and genuine difficulty selection. `tests/zone_generation_regression.gd` checks deterministic complete Zone layouts and real open-boundary traversal. Static checks do not establish whether a shot is fun or a recovery is comfortable.

## Three-section generation and historical fixtures

The three-section generator validates compatible joins, the full seam band and continuous routes through the complete table. Normal v8 also requires flowing junctions and complete ball clearance between generated banks and the paddle swing. Only generated seam coordinates round to the common 5-pixel connector grid; authored pieces remain at their exact positions. Estimates use the resulting geometry, including bank inclination. A requested tier can be unavailable with this small optional catalogue; the three-section panel reports the closest valid alternative rather than pretending it matches. The Zone development override instead rejects an unavailable requested tier. Invalid grid compilation preserves the active table instead of silently substituting a legacy middle.

Record **the reported generator and Zone versions, kit v3, recipe files, middle mode, seed, difficulty and Godot version**. Version 7 introduced construction mode; v8 changed Normal connector selection; v9 added Easy-specific recipes. Version 10 changed paddle placements and Easy grid banks/seams. Kit v3 adds mounted targets, circle sizes and the authored Zone library. Recipe edits intentionally change the layouts that use them. The generator still selects tested chunks; it does not place random individual pieces.

For the original recipe comparison, use **Normal seed 8** in both grid modes: the same top section and transform show the authored bank swap and 50 px bumper move clearly. Both generated junctions are curved, with an estimated difficulty of 38.6. For the broader designs, use **Easy seed 8** in both modes (28 points). Sampled Easy seeds 1–12 use both existing broad upper designs and mirrored grid middles without falling back to Normal.

The original Easy grid source openings span 50–750 px, a **5 px** mismatch against legacy 55–745 px rails. Generator v10 replaces this mismatch with shallow Curve collars extending 100 px on either side of each seam; there are no horizontal closure steps. Its checked corridor remains at least 618 px. Both joins pass real bidirectional ball probes. Those original Easy banks protrude at most 30 px, with no horizontal ledges and maximum horizontal/vertical grade below 0.5. Each local turn is at most 20 degrees. The Zone library also uses 700 px wide chunks, up to 50 px rounded bank bulges and 180 px seam collars, with a separately validated Easy estimate. These curves remain passive capsule segments shared by collision and presentation; no physics value or difficulty threshold changes.

The former midpoint-alignment restriction could reject grid/legacy banks and exhaust the catalogue before retaining Step joins. Version 8 supports their shared seam coordinates and excludes stepped Normal candidates. Grid base Normal 18 built in about 0.335 seconds in one measured run, compared with 18.756 seconds in v7. This is a local sample, not a performance guarantee. Generation still runs synchronously while paused or at serve; exhaustive fallback searches can delay the UI.

Run `tests/grid_easy_regression.gd` for the Easy recipes and `tests/grid_chunk_regression.gd` for the original kit, with Godot headless and `--fixed-fps 120`. See [executed checks](VERIFICATION.md). Static connectivity and sampled shots cannot prove every possible trajectory safe. Human testing remains important for low-speed pockets, recovery timing, profile extremes and subjective flow.

## Why Resources first

Godot's built-in [TileMap editing and reusable patterns](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html) are a viable future authoring interface. [TileSet custom data](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html) belongs to tile definitions, while our multi-cell stamps and dynamic paddle clearances need additional validation. The small Resource experiment exercises the shared compiler without adding a tile atlas or editor plugin.

A future TileMapLayer adapter should read cells into this same authoritative recipe/compile path, account for [`map_to_local()` returning cell centers](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html), and disable TileMap collision/navigation when generating the existing colliders. It must not keep a separately editable compiled layout. Scene tiles are unnecessary here.

Current limits: fixed 14-row dual-opening middle recipes, two monotonic outer wall chains, a small fixed kit, whole-chunk mirroring only, no arbitrary interior rail islands or custom per-placement object sizes. Intentional corners are supported; usable drains and successful recovery still require whole-table physical checks.
