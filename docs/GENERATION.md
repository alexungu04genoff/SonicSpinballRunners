# Vertical Traversal Playground: generation contract

## Current generator v11

Version 11 updates the bottom funnel to a 70px mouth with a central drain sensor and a gravity-fed side serve. It also preserves explicitly tagged checkpoint geometry in shared descriptors while excluding that retracted geometry from entry-open route checks. Active funnel passage, recovery and drain behavior have separate real-physics checks. Existing catalogue resources and normal flipper forces remain shared. Historical v10 fingerprints change because the lower deck's rails changed.

Optional **Zone generator v3** retains v2's Easy selection and composes development Normal/Hard Acts from six purpose-authored rooms per tier. Interaction rooms occupy indices 7, 4 and 1; exit approaches occupy 6 and 3; the final cap occupies 0. Primary recovery decks remain at 8, 5 and 2. Each Act shares a mirror, and a shuffled bag gives five distinct relay IDs. Layout shuffle A/B/C selects deterministic arrangements from the whole library, not a single grid recipe. Official Green Hill remains Easy.

Composition validation supplements the unchanged worst-case estimate and collision validation: each Act must have the correct interaction/approach roles and authored tier, the Zone must have at least three sampled interior silhouettes, and every Hard Act must contain at least two interior rows with a largest contiguous clear ball-center lane of at most 320px. Rows sample local y175–525 at 25px intervals, using 10px horizontal probes and the existing 14px ball plus 6px clearance. These metrics describe actual transformed interior rails/targets, separately from connectors; they remain provisional difficulty heuristics.

Normal uses Curve collars of 160px; Hard uses Bank collars of 240px to meet its narrower cap entrances. Both require the existing maximum grade of 0.75. Every shaped grid room repeats the compiler's complete object/ring/marker/paddle clearance checks before full-course route validation. Difficulty never relaxes collision rules. A bounded 48-candidate search reports failure instead of substituting another tier. Source resources remain unchanged. See README for entry/latch behavior and `GRID_AUTHORING.md` for the room library and kit v4 metadata.

Act completion spans are derived separately from physical gate openings. The generator intersects the incoming checkpoint outline at its safe-entry height and insets the span by the ball and rail radii. Both the progression detector and visible entry strip use these bounds, allowing angled arrivals beyond the previous gate's narrower span.

The default game generates three seven-row sections: a capped top at row 0, a reusable middle at row 7, and the familiar launch deck at row 14. The resulting bounds are currently 800 × 2100 physics pixels. `layout.chunks` is ordered **top to bottom**; `layout.junctions` holds adjacent section indices, world-space closure rails, checked passage rectangles and difficulty estimates. Bounds merge the resource footprints. Runtime construction, overlays, floor, drain detection and camera framing consume that data rather than assuming two sections.

The eight v3 top resources retain their authored static geometry and ratings, with one short recovery paddle added in v10. Normal may reshape private resource copies around their connections as described below. Middle resources in `data/middle_chunks/` have genuine top **and** bottom openings:

| Middle | Width | Gameplay geometry |
| --- | --- | --- |
| Open Relay | 8 cells | Aligned broad openings, clear center route, two separated side bumpers. |
| Bank Relay | 8 cells | Aligned openings with gently banked side walls and different rebound placements. |
| Rebound Relay | 7 cells | Mirroring/shifting, an asymmetric wall bank and short internal return rail, two offset bumpers. |

Each middle defines a pair of `flipper_placements` with local position, side and optional pivot-to-tip length (legacy default 150 px). `world_flippers()` transforms positions and reverses paddle side under mirroring while preserving length; the original deck's named markers remain supported. The launch deck uses 130 px paddles at its unchanged pivots. Open Relay has 115 px side paddles, Bank Relay has staggered 125/115 px side paddles, and Rebound Relay has a 120 px side pair; the extra 10 px reach preserves direct shots into the Hard necks after moving outward. Every top resource and fallback has one 70–85 px paddle. Exact middle placements are documented in README. All left paddles use the existing left action and all right paddles use the right action. No new launch force, spring, checkpoint or character-specific physics is added. The middle's central gap and side lanes allow falling back through the course. Stationary validation checks rail/bumper clearance; moving paddles are verified separately through real physics tests.

There are 28 top transforms and eight middle transforms, forming 224 unshaped combinations. The historical v4 catalogue audit found 220 technically valid combinations: 16 Easy, 144 Normal and 60 Hard. Four fail the unchanged 300-pixel minimum raw connector overlap. These counts describe raw layouts, not v8's shaped Normal candidates. Difficult geometry receives no validation exemptions. Candidates are shuffled by a local seeded RNG. Easy/Hard retain their existing first-valid-in-band selection. Normal constructs both joins before estimating difficulty and requires flowing geometry as described below. If a tier is unavailable, explicitly report the closest valid alternative. Exhausting the catalogue uses a separately validated **three-section** fallback, never a silent two-section layout.

The v3 component formula below applies to each adjacent pair. The whole-course estimate is their maximum, preserving the distinction between authored challenge, connector geometry and sampled approach clearance. Route flood validation runs across all ordered outlines and closures, from the bottom serve to rings, probes and entry/exit/test markers. Each junction retains the same 90-pixel clear seam band and safety margin. For slopes, intersect the horizontal spans of both navigable outlines across that entire band before applying the 36-pixel inset. Linear-edge extrema occur at band limits and polygon vertices. This avoids claiming a rectangular passage that crosses a sloping wall; physical obstacle checks still apply. Raw overlap and the full-band corridor must both meet the 300-pixel minimum. Chunk rotation remains unsupported.

Regeneration replaces generated sections and middle/upper paddles, retaining the bottom paddles. It also replaces the bottom collision section when a transition changes its upper wall collar; unchanged deck geometry keeps its existing node. Serve, drain and bottom paddle positions do not move. It frees the old presentation before repopulating rings, then rebuilds meshes and signal listeners. Scores, timers and ball state reset; physics overrides, modifier, camera settings/preset/follow mode, overlays and pause persist. The ball and camera return to the bottom. Falling between sections does not reset progress or trigger a checkpoint.

| Seed | Preference | Top / middle | Purpose |
| --- | --- | --- | --- |
| 1 | Easy | Open Meadow / Open Relay | Start with the broadest recovery space. |
| 2 | Easy | Gentle Banks / Bank Relay | Compare gentle side-bank rebounds. |
| 18 | Normal | Outer Return / Rebound Relay | Two straight banked joins; estimate 46. |
| 23 | Normal | Risk Route / Bank Relay | Faceted upper curve and aligned lower join; estimate 55. |
| 1 | Normal | Risk Route / Open Relay | Straight upper bank, aligned lower join and side recovery; estimate 55. |
| 5 | Normal | Risk Route / Rebound Relay | Two faceted curves; estimate 55. |
| 1 | Hard | Offset Neck / Rebound Relay | Sideways upper approach and sharper shoulders. |
| 3 | Hard | Tapered Throat / Bank Relay | Precision through a centered upper neck. |

Reproduction requires generator version, engine, resource catalogue, seed and difficulty. Version 5 intentionally changes Normal mappings to prefer passive transitions; Easy and Hard retain v4 selection and geometry. `generate_pair()` retains version 3 for the existing collision fixtures and earlier diagnostic; it is not a player-facing generation mode. There is still no runtime streaming, arbitrary section count UI, branching route or progression.

Version 6 records the drain/recovery placement change. Static rails, bumpers, rings and connectors are preserved; flipper lengths and middle pivots intentionally differ. Existing static difficulty ratings are unchanged and do not yet model the timing demands of individual recovery arrangements. Compare Normal 1 (side), Normal 23 (staggered) and Normal 8 (traditional); all have distinct tested recovery and upward routes. The shot diagnostic samples contact positions as fractions of each actual paddle length. It records attempts at three input timings, including real drains, while retaining the requirement for a full traversal witness through every middle design. No diagnostic controller runs in gameplay.

Version 7 adds an explicit middle-catalogue mode without changing existing catalogue selection or geometry. **Grid base** and **Grid variant** compile a 50 px Resource-authored construction grid into fresh `ChunkData`, then pass that one middle resource through the same mirror/shift, selection, transition, difficulty and collision validation paths. The mode and kit version are recorded in game layout metadata and grid signatures; repeat uses the current mode. Closest-tier reporting still applies. Failed grid compilation preserves the active table. The two recipes and shared construction kit are documented in [Grid authoring](GRID_AUTHORING.md).

Version 8 intentionally changes Normal's seed mappings, transition eligibility and estimates, including grid modes. It removes generated stepped ceilings from Normal, rates actual bank inclination and supports shared seam points between construction-grid and legacy insets. Easy/Hard selection and geometry remain unchanged. The existing catalogue provides enough variety without additional resource variants: sampled default Normal seeds cover at least four top designs, all three middle designs and six pairings. Record v8 when sharing new seeds.

Version 9 adds dedicated **Easy** recipes for Grid base and Grid variant. The game chooses the matching broad middle recipe before calling the unchanged generator. Their 800 px footprints, 700 px openings, gentle banks and wider paddle spacing replace the narrower grid layout that previously forced an out-of-tier fallback. Existing catalogue and grid Normal/Hard retain their v8 selection and geometry. The 5 px grid/legacy inset difference still uses the ordinary rounded closure capsules; no difficulty threshold, collision rule or physics value changes. See [grid authoring](GRID_AUTHORING.md) for exact dimensions and sample seeds. Record v9 for layouts from that pass.

Run `tests/vertical_traversal_regression.gd`, `tests/vertical_shot_survey.gd` (headless with `--fixed-fps 120`) and graphical `tests/vertical_camera_smoke.gd` for current verification. The shot survey uses actual flipper impulses, including uninterrupted bottom-to-top traversal and falling recovery. Its controlled inputs are evidence of sample routes, not guaranteed reachability for every transform or a difficulty success probability. See [executed results and limitations](VERIFICATION.md).

**Version 10 is the current reproduction version.** It moves catalogue/grid middle pivots toward the walls, adds one short upper paddle to every top resource, and rounds Easy grid banks with kit v2. Easy grid candidates reshape their 5 px inset mismatches using Curve collars extending 100 px on either side of each seam; this avoids touching the upper section's existing banks. Both joins must be flowing before estimation and normal whole-course validation. Catalogue Easy and all Hard static geometry retain their earlier fingerprints. Normal uses its existing 160 px collars and policy. Source resources remain unmodified by shaping. Tests record the deliberately revised full geometry fingerprints and retain the separate pre-change static fingerprints.

### Normal transition styles

`ConnectorTransitions` reshapes compatible outer-wall collars on private chunk copies. For Normal, the seed selects a preference using `seed % 8`: 0–3 prefer **Bank**, and 4–7 prefer **Curve**. Catalogue selection still uses its independent seeded shuffle. Each candidate tries the preferred style, then the other style. Both joins must be **Aligned**, **Bank** or **Curve**; partial shaping that leaves a stepped closure is excluded. Aligned edges stay aligned. Catalogue Easy and Hard do not request reshaping; Easy grid uses the shorter Curve collars described above. Intentional authored interior corners remain unchanged.

A bank spans 160 pixels above and below the shared seam. Its endpoints lie on the existing outer rails; both adjoining rail polylines and navigable outlines are replaced together. A bank has two straight segments meeting at the shared seam point; a curve uses four facets with smoothstep horizontal interpolation. Only the generated seam X coordinate rounds to the 5-pixel connector grid, moving it at most 2.5 pixels. This permits 50-pixel construction-grid boundaries to connect to legacy 55-pixel insets without snapping authored objects. Both opening rectangles and rail endpoints use that same coordinate. The old horizontal closure and old collar segments are removed, rather than hidden behind an extra diagonal collider. Bumpers, rings, markers, flippers, transforms and source resources remain unchanged.

Unsupported or ambiguous collars, out-of-footprint seam points and insufficient paddle-swing clearance cause Normal to try another style or candidate. Generated bank/paddle centerlines must remain at least 69 pixels apart throughout the sampled swing: both collider radii, one complete ball, 6 pixels of clearance per surface and a 4-pixel sampling margin. Every generated facet must satisfy `abs(dx / dy) <= 0.75` (at least 53.13 degrees above horizontal). This flow policy favors an upward component after a vertical passive impact; it is separate from technical validity and does not promise every oblique approach succeeds. All existing collision, full-seam corridor and route checks still apply.

Selection rates the finished geometry and returns the first valid Normal candidate. If none exists, it reports the closest valid flowing alternative outside the tier. If no candidate is usable, the separately validated emergency course is aligned Open Meadow / Open Relay / launch deck, explicitly reported as a fallback. No Normal fallback accepts a stepped ceiling. Requested and actual styles appear in the panel and signature; its tooltip includes bank grades and their score contributions.

Difficulty is recomputed from the resulting rails, openings, approach turns and checked corridor. Normal adds `80 × maximum abs(dx / dy)` across each join's actual generated facets as another maximum component, up to 60 points under the current flow limit. A bank that demands a more angled approach cannot disappear from the estimate just because its shared opening has no closure ledge. This is a tunable shape heuristic, not an energy or success-rate simulation. Banks use ordinary wall collision response and restitution; they add no spring impulse, speed multiplier or velocity override. Gravity, surface losses and shot angle still matter.

`tests/connector_transition_regression.gd` preserves Easy/Hard geometry fingerprints, checks seeded variation and regeneration, reproduces the original v3 seed 18/23 shelves, and compares their real passive collision responses with both shaped styles. It also exercises high-speed contacts and uninterrupted play on the current Normal 18/23 courses.

`tests/normal_flow_regression.gd` checks 22 reproducible Normal configurations, actual-geometry estimates, retained variety, explicit aligned fallback, partial/shallow transition rejection, and native collision/recovery samples. Straight and curved banks preserve upward momentum for the vertical probes, while oblique misses can still reflect downward and recover through timed flipper input. See [verification](VERIFICATION.md) for measured velocities and limits.

## Retained v3 pair contract and shared difficulty formula

The sections below document the original two-section catalogue and `generate_pair()` fixture. Component scoring, resource transforms and clearance principles are also reused by the current generator; the three-section lifecycle and Normal transition handling are described above.

## Scope and controls

Generator version 3 chooses among eight upper sections, one mirror state, and a compatible horizontal cell shift, guided by an Easy / Normal / Hard preference. The lower launch deck, serve, flippers, and drain remain fixed. There are 28 fitting combinations: four Easy, 16 Normal, and eight Hard. Full-width upper sections have only shift zero; seven-cell sections retain shifts zero and one. Seeds range from 0 to 2147483647 in the debug UI. A local `RandomNumberGenerator` shuffles candidates deterministically, independent of gameplay randomness. The seed and preference together define the generation configuration.

Build at serve or while paused. Regeneration is deferred out of physics callbacks and checks safety again before replacing anything. It validates first, then replaces the upper collision section and collisionless presentation, repopulates rings, resets score/meter/ball count and all pending playground timers, and returns the ball to serve. The lower section and flippers remain the same instances. Profile, session overrides, modifier toggle, pause state, camera preset, and overlays persist. A paused rebuild stays paused; resume before launching.

The panel displays the current seed, preference, actual estimate, reasons, chunk IDs, mirror flag, shift, and fallback status. The output log records generator version and the same layout signature. Build applies the entered seed and selected preference. Next increments the current seed with the selected preference. Repeat restores both current settings, even if controls contain unbuilt edits. No configuration or run persistence is included. Changing character or modifier tuning does not silently alter the generation configuration or its estimate.

## Difficulty estimation and selection

Technical validity and mechanical challenge are separate. The validator still requires aligned, closed collision boundaries, sufficient clearance, and coarse connectivity. The preference never changes those rules. Existing corners and ledges remain; new geometry supplies distinct challenges instead of relabeling the old catalogue.

### Geometry behind the tiers

| Tier | Upper sections | Mechanical differences |
| --- | --- | --- |
| Easy | Open Meadow, Gentle Banks | Eight-cell width, aligned 690 px opening, no closure ledges. Broad recovery routes, gentle banks, two separated bumpers. |
| Normal | Bumper Garden, Central Targets, Outer Return, Risk Route | Seven-cell width with shifts/mirroring, 100–150 px shoulders, moderate offsets, denser target approaches or a curved return route. |
| Hard | Tapered Throat, Offset Neck | Raw entrances of 340 / 300 px, large closure shoulders, then a 180 / 140 px rail-center throat. Offset Neck shifts its approach sideways by 115 px; mirroring reverses the required bend. Two bumpers each, not increased obstacle counts. |

Hard necks begin above y620, preserving the existing clear seam band. They have sloped recovery walls and no new horizontal interior shelves. The narrow neck makes a missed approach rebound into the lower deck; the upper chamber opens out again. Static connectivity and controlled real-flipper samples establish useful evidence of traversability, not a promise about every shot.

### Transparent, provisional estimator

`ChunkData.estimated_difficulty` remains an authored judgment. Values are Open Meadow 20, Gentle Banks 28, Bumper Garden 20, Central Targets 40, Outer Return 45, Risk Route 55, Tapered Throat 68, Offset Neck 72, and lower/fallback 25. Risk Route's old 65 was recalibrated against the genuinely restrictive new geometry. The chunk component is the maximum of the two authored ratings.

Geometry components use world-space descriptors and the actual ball radius:

| Component factor | Calculation | Maximum points |
| --- | --- | ---: |
| Join narrowing | `80 × clamp((618 - checked_width) / 390, 0, 1)` | 80 |
| Opening offset | `45 × clamp(center_offset / 200, 0, 1)` | 45 |
| Largest ledge | `ledge_pixels / 2.5`; at least 40 if over two ball diameters (56 px) | 100 |
| Approach pinch | `100 × clamp(1 - sampled_lane_width / 300, 0, 1)` | 100 |
| Approach turn | `60 × clamp(sharpest_rail_turn / 90°, 0, 1)` | 60 |
| Approach clutter | Fraction of 42 blocked clearance samples × 60 | 60 |

The join component is the maximum of narrowing, offset and ledge scores. The approach component is the maximum of pinch, turn and clutter scores. **The displayed estimate is the maximum of chunk, join and approach components.** No averaging can hide a severe join. Easy is below 37.5, Normal is 37.5 to below 62.5, and Hard is 62.5 or higher. Current estimates span Easy 25–28, Normal 40–60 and Hard 84–100. These are tunable heuristics, not player success probabilities.

Approach pinch scans rows y450–650 every 25 px and X every 10 px, within the upper navigable outline. At each row it measures the largest contiguous clear ball-center interval, then takes the smallest row result. Separate lanes are not combined into a fictitious wide opening. The interval excludes collider thickness and the radius-14 ball; it has 10 px resolution. Wall turns in the same approach region supplement the clearance measurement. Clutter uses seven columns and rows at 50/100/150 px above and below the join with the validator's extra safety clearance. This cannot identify the full difficulty of changing lanes between rows; connectivity validation and the shot survey remain separate.

### Selection and unavailable tiers

Select the first technically valid candidate in seeded order **within the requested band**. This preserves variation across all matching authored shapes rather than repeatedly choosing the nearest score. If no matching valid candidate exists, sort by distance to the preference target (25 / 50 / 75), retaining seeded order for ties, and select the closest valid alternative. The layout reports `preference_available = false` and an explicit message such as `No valid Hard candidate; using Normal.` An empty/invalid catalogue reports a validated fallback separately. No collision criterion is relaxed for a harder request.

## Data and coordinate contract

- `data/chunks/`: six 700 × 700 and two 800 × 700 upper resources. `data/lower_chunk.tres`: fixed 800 × 700 lower deck at grid row 7. `data/upper_chunk.tres`: unchanged original collision geometry used for fallback and the legacy regression fixture.
- `ChunkData.map_point()` mirrors around the local footprint width, then adds the horizontal cell shift. `world_point()` adds the grid origin. `world_rect()` transforms both rectangle corners and normalizes them after mirroring. Triangle vertices mirror as offsets around their transformed center.
- `gameplay_descriptors()` supplies world-space geometry to validation and `TableChunk`. The renderer consumes that chunk's instantiated descriptors, including closure rails. Markers, chunk bounds, and connector overlays use the same transforms. No rotation is represented.
- Placement uses 100-pixel cells. Connector rectangles use a 5-pixel authoring grid, retaining the original 55-pixel wall inset. Top/bottom rectangles lie inside their chunk and touch the corresponding horizontal edge.
- Navigable outlines are closed polygons enclosing the playable interior, including the open join. Route probes identify representative lanes and flipper approaches. Neither outline nor probe creates a collider. Rings, the upper entry marker and optional `test_target` also serve as reachability targets. `test_target` is a diagnostic marker, never a win condition.
- Visual attachment metadata remains a future theme hook. All current meshes use primitive materials; there are no themed assets or 3D colliders.

## Connector validation

Opening compatibility uses world-space horizontal spans at a shared Y boundary. The upper bottom rectangle ends at `y = 700`; the lower top rectangle begins there. Their X spans must overlap by at least 300 pixels. IDs are descriptive, not matching keys.

Both opening edges must meet exactly one authored rail endpoint. The generator closes the non-shared spans using the same radius-12 capsule rails as the table. Closures meet the existing rounded rail ends and never cross the shared opening. They are visible gameplay geometry, not invisible barriers. The current upper openings are contained inside the lower opening; closure shoulders can rebound an upward shot back into the lower deck.

The checked passage extends 45 pixels above and below the seam, inset 36 pixels from each overlapping edge. Geometry clearance is sampled every 10 pixels there, using ball radius 14 plus a 6-pixel safety allowance against rails, circles, and triangle edges/interiors. Current checked passages are 618 px for Easy, 468/518 px for Normal, and 228/268 px for Hard. These conservative checked widths differ from raw opening widths and sampled ball-center approach lanes.

The validator also checks table footprint bounds, allowed vertical placement, positive connector dimensions, authoring-grid alignment, and opening/rail alignment. It builds a 25-pixel static clearance grid within the two navigable outlines, then floods from serve using four neighbors and midpoint clearance checks. All route probes, rings, entry and test targets must have a reachable clear cell within 36 pixels. More than four disconnected clear cells rejects an obvious pocket.

If all candidates fail, the original upper/lower pair is validated and used, with its actual difficulty estimate. If even that fails, generation reports failure and preserves the existing table; startup reports an error rather than running invalid geometry.

## Sample configurations (version 3, Godot 4.7.2)

| Seed | Preference | Upper section | Mirrored | Shift | Estimate |
| --- | --- | --- | --- | --- | --- |
| 1 | Easy | Gentle Banks | Yes | 0 cells | Easy 28 |
| 3 | Easy | Open Meadow | No | 0 cells | Easy 25 |
| 1 | Normal | Outer Return | Yes | 1 cell right | Normal 45 |
| 4 | Normal | Risk Route | Yes | 1 cell right | Normal 60 |
| 1 | Hard | Offset Neck | Yes | 0 cells | Hard 84 |
| 2 | Hard | Offset Neck | No | 0 cells | Hard 100 |
| 3 | Hard | Tapered Throat | No | 0 cells | Hard 88 |

Reproduction requires the same seed, preference, engine, catalogue, ratings, scoring rules, and generator version. Version 3 intentionally changes version 2 seed mappings. Signatures record the version, preference, and transformations to diagnose differences. There is no serialized layout format or cross-version replay guarantee yet.

## Controlled flipper-access survey

Run `tests/flipper_access_survey.gd` with `--headless --fixed-fps 120`. It builds actual generated 2D colliders, the existing ball, both existing flippers, and unchanged Balanced defaults. It uses no steering, modifier, automatic serve, or rescue flip. Each layout gets 18 samples: both paddles × contact distances 55/95/135 px × incoming horizontal velocities −200/0/+200 px/s. Incoming downward speed is 100 px/s. The script positions the ball above the resting paddle, triggers an actual flipper press and checks for one strike, then tracks up to four simulated seconds or the first return/drain.

The JSON report in `test-results/flipper-access-survey.json` records each input and result: crossing y650, reaching y450, and sweeping within 70 px of an optional authored target. The target check follows movement segments to avoid skipping a fast pass. Default samples use seeds 1/2 per tier plus the first different authored shape. Add `-- --all-hard` to inspect every Hard catalogue transform, with a separate `flipper-access-all-hard.json` report and a successful-route check for each current transform.

This is an opening-shot diagnostic, not a player success probability, guaranteed reachability proof, generation gate or scoring input. The fixed lower bumper influences all shots. Several Easy and Normal samples overlap; recovery and later shots still need manual playtesting. The sampled Hard necks reduced y450 arrivals to 1–4 of 18 versus 7–10 in the representative Easy/Normal designs. All eight new Hard transformations reached their upper target at least once. See `VERIFICATION.md` for the executed results and limits.

## Validation limits and next expansion

Static clearance establishes coarse geometric connectivity, not reachable pinball trajectories under gravity. It may miss a tiny pocket, a stable resting point, an awkward rebound angle, or a moving-flipper corner case. The graph can also conservatively reject a narrow but technically traversable route. Brief real-physics tests cover selected paths and seeds, not all possible inputs, velocities, and modifiers.

Manually compare the central cluster's approaches, the outer return's entry/exit, the risk route's scoring path, and the join shoulders at low and high speeds. Check both profiles and a physical gamepad. Before adding many chunks, establish authoring guidance from those playtests and preserve failing seeds/shots as focused regressions.

The generator deliberately assumes two seven-row sections and the current camera bounds. Additional height, multiple junctions, branching routes, or new collider kinds will require extending placement and clearance handling. Keep transformations and descriptors shared; do not add a parallel visual layout. A catalog/version migration policy and actual saved layout records become useful when seeds must survive content updates.
