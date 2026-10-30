# Act scoring and repeatable objectives

Implemented for authored Acts in the existing game and Endless streaming path. Scorecraft remains the score authority. Bumpers and rings provide the permanent scoring foundation; optional features offer alternatives. Authors choose targets deliberately, without requiring every gimmick family.

## Authoring an Act target

In **Act Markers**, select **Enable Score Target** and enter a positive integer. New Acts start disabled. The initial enabled value is 3,000; it is only an editor starting value, not an estimate of the Act's scoring capacity. Supported targets range from 1 to 100,000,000. Stored `score_target = 0` means disabled / Free Play.

A positive target uses points earned after this Act becomes active. The Exit opens once that target is reached and stays open for the rest of that Act, including checkpoint retries. The ball must still physically cross the authored Exit; reaching the target never teleports it. The system exit barrier is separate from authored One-Way Gates and follows the actual connector position and width. Add an Exit connector to make the score requirement a physical objective.

The run total persists through activation of another Act. Each new activation starts a fresh Act score and combo. A normal drain or reset clears the combo but preserves earned Act points and the run total. Resident neighboring Acts do not earn points for the active Act. Their rewards become eligible only when their Activation Trigger transfers ownership.

Old Acts have no target and remain ungated. Pass `--free-play` after Godot's `--` separator to ignore authored targets for a traversal session. Endless keeps its existing streaming/checkpoint behavior; targets affect only explicitly configured Acts. Rebuild offline Endless bakes after changing scoring authoring or updating to this format.

## Rings and Bonus Racks

Select a ring line or ellipse in the **Rings** tab. Its scoring controls also set the next pattern's brush settings:

| Setting | Ordinary pattern | Bonus Rack | Supported range |
| --- | --- | --- | --- |
| Completion bonus | None | 500 points | Integer 0–100,000 |
| Timeout | 25 seconds | 12 seconds | 0.1–300 seconds |
| Respawn delay | 18 seconds | 11 seconds | 0.1–60 seconds |

Bonus Rack defaults off. Toggling it updates the brush's default timers but preserves bespoke timing. These remain one shared pattern/rack implementation, separate from Switch Banks.

The first physical pickup starts that pattern's timeout. Later pickups do not extend it. Clearing the whole pattern before timeout awards its configured bonus once if **Bonus Rack** is enabled, then respawns after the delay. An incomplete timeout restores that pattern without a bonus. Ordinary patterns also respawn, but have no completion reward. An ordinary single ring therefore never implicitly earns a 500-point bonus; enabling a one-ring Bonus Rack is an explicit author choice.

Patterns remain independent even when their rings overlap. New patterns receive stable IDs, duplication gives a fresh ID, and Save As retains identity. Runtime ring IDs combine the owning Act instance, pattern ID and ring index. Legacy patterns receive deterministic identities from their original index on load, preserved during subsequent edits and written only on explicit save. Editing geometry never merges unrelated racks.

Rack progress and clocks survive checkpoint retries, pausing while collection is disabled, serving, teleporting, or the owner is inactive. Eligible rail travel counts toward rack timeout, even while lower-table collection is unavailable. Retiring an Act retires its rack state. A rack respawn does not reset Scorecraft. Direct, magnet and character area collection claim the same physical rings.

Expired patterns wait outside their bounds expanded by 128 px plus Ball and Ring radii, checking the Ball's last sweep too. They fade in over 0.35 seconds before becoming collectible. Returning during the fade restarts the safety wait. Inactive owners cannot advance timers, fade or activation.

Lane Barrier and Buddy ring rewards use the same explicit `award_virtual_rings` counter-only path. They neither claim physical rings nor complete racks, grant Special charge, or recursively trigger physical-Ring Buddy effects.

## Repeatable optional features

| Feature | New-authoring defaults | Cycle |
| --- | --- | --- |
| Floor / Wall Switch | 0 individual points | Both orientations use the same bank logic. |
| Switch Bank | 500 points; 0.75-second reset | Complete all members, apply links, then rearm targets. |
| Spinner | 5 per actual half-turn; goal enabled; 10 ticks; 300 bonus | Each goal resets progress and can repeat. |
| Lane Set | Existing configurable lane rewards and completion bonus | Existing unique-gap lights, completion and cooldown remain. |

Switch Bank **Reset seconds = 0** preserves the existing one-completion-per-reset behavior. Explicit rewards and reset delays in old Acts are retained. Feature rearming never recloses gates opened by the bank. Diverter Set A / Set B applies its chosen state; Toggle may change state on every completion. Ordinary mechanic/run resets retain their existing gate and switch reset semantics.

Spinner **Enable completion bonus**, **Target ticks** and **Completion bonus** are in its Gameplay inspector beside Tick score. Target ticks must be an integer from 1–1,000; bonus is 0–100,000. Progress counts awarded physical spin ticks, including zero-point ticks, and never stationary animation. Spinner-local progress/flash, switch lights and lane lights keep feature progress near the equipment.

Feature bonuses are fixed awards. They do not receive combo multiplication, advance or refresh the combo, or charge Special Meter. `mechanic_score(kind, object_id, points)` carries the award; `feature_completed(kind, object_id, bonus)` carries completion feedback, so emitting both does not double-pay. Ring racks join the same fixed-award path. Canonical categories include `bumper`, `ring`, `ring_rack`, `switch`, `switch_bank`, `spinner_tick`, `spinner_goal`, `lane` and `lane_set`.

## Traversal supports Scorecraft

Springs and Dash Panels give no score or Special Meter charge. Each may refresh an existing combo window once per object per chain. Neither starts a combo or raises its multiplier. After the chain ends, those objects are eligible again.

Actual elevated-rail entry protects an existing combo for at most the configured rail budget, initially 5 seconds. The timer resumes after that budget or on exit. Repeated entry notifications cannot refill one ride's budget. Drain, reset and activation clear traversal protection. Typed `traversal_event(kind, object_id, phase)` events distinguish use, entry and exit; physics never polls a visual model for scoring state.

The existing ring value (25), fresh bumper chain, repeated-bumper flat 100, ring links, bounded multiplier and character-special awards remain in Scorecraft. Routing-only gates, diverters, magnetic fields, terrain and flippers add no direct points.

## Production authored-Act normalization — 2026-10-30

The five source Acts in `data/acts/Authored` now explicitly describe the existing mechanics before any future scoring/combo redesign. This pass started from implementation commit `338c28e410a352aee85f8d9d9237aa61e8a345ff` and, with the author's approval, retained the newer local Act revisions, including their Buzz Bombers and Goal Rings. Terrain, connectors, spawn/goal positions, object transforms, ring geometry, physics properties and decoration were preserved from those local revisions.

| Source Act | Bonus Racks / patterns | Authored rings | Rail rings | Total physical rings | Rail spacing |
| --- | ---: | ---: | ---: | ---: | --- |
| First Try Smooth Decor | 0 / 3 | 20 | 0 | 20 | No rails |
| RampMania | 3 / 4 | 55 | 27 | 82 | Short: 35 px (7 rings); long: 45 px (20 rings) |
| Reverse C Spring | 1 / 4 | 25 | 0 | 25 | No rails |
| Secret Entry | 2 / 3 | 34 | 10 | 44 | 30 px |
| SpringUp | 0 / 5 | 34 | 0 | 34 | No rails |
| **Total** | **6 / 19** | **168** | **37** | **205** | |

Ring totals count each physical collectible in a fresh Act, before any respawns. All 19 patterns previously opted into Bonus Rack behavior. Ordinary route trails now explicitly store no completion reward, a 25-second partial timeout and an 18-second full-clear respawn. The six retained racks explicitly store 500 points, a 12-second timeout and an 11-second respawn. They are RampMania patterns 0/2/3, Reverse C Spring pattern 4, and Secret Entry patterns 0/1.

RampMania retains its five-member gate bank with an explicit 500-point reward and zero reset delay. Secret Entry retains its original seven-member gate bank with the same settings; its second bank had identical members and the same gate and was removed. Reverse C Spring's three existing targets now award 25 points individually and form one 500-point, zero-reset-delay scoring bank. SpringUp's four targets retain their individual 25-point rewards and form the same kind of scoring bank. Neither scoring bank has a gate. All four banks are one-shot objectives for the Act and preserve completion through soft retries.

All seven Spinners explicitly enable the 10-tick, 300-point goal while preserving their authored tick score and physical properties. All three Rails explicitly enable ordinary physical rings. Their new spacing reduces generated rail rings from 58 to 37; paths, heights and traversal remain unchanged. Rendered overview and top-down rail inspection supported the proposed 35/45/30 px spacing without further adjustment.

Scorecraft, Ring Link, combo participation, enemy lifecycle, Sonic Homing, Special Meter and global defaults are unchanged. Challenge still assigns sequence targets of 1000/1500/2000/2500/3000/3500. No per-Act score targets or additional mechanic families were added.

The existing prototype baker rebuilt all ten derived Act/theme variants (five Acts across Green Hill and Chemical Plant); the source/pipeline fingerprint and collision/visual-recipe audit passed 33 checks. Sidecars remain ignored, rebuildable outputs. The historical fixed Endless snapshots were not republished.

Focused verification on Godot 4.7.2: 151 source-preservation, validation, physical-ring and objective checks passed both in the working checkout and against an isolated HEAD implementation with the five normalized Acts. Existing ring-rack checks passed 25 assertions, rail-ring checks passed 13, and the real soft-retry regression passed 26. Seven rendered captures covered all five Acts and both rail layouts. Disk-loaded rail streaming passed seven assertions and exited cleanly headlessly. The rendered streaming run passed those assertions but encountered a native Windows shutdown crash (exit -1073740771); this is recorded as an unresolved shutdown limitation, not a successful process exit. Manual flipper feel, route difficulty and scoring balance remain unassessed.

## Three scoring examples

Load these in the main game's **Load Act** or the Act Editor. They reuse the existing routing sandbox's side walls and lower funnels; the original sandboxes remain unchanged.

| Act | Target | Scoring emphasis |
| --- | --- | --- |
| [Classic Pinball](../data/acts/scoring/classic_pinball.tres) | 1,500 | Bumpers, rings and one opt-in rack. Springs and flippers provide traversal. No optional gimmick family is required. |
| [Switch and Spinner](../data/acts/scoring/switch_spinner.tres) | 2,000 | Repeatable two-switch bank, linked gate and spinner goal, alongside core scoring. |
| [Speedway and Lanes](../data/acts/scoring/speedway_lane.tres) | 1,500 | Lane Set rewards with a raised crossover and an exit Dash Panel. Core scoring remains available. |

These targets, spring strengths and shot routes are provisional playtest values. All three pass the production physics compiler, including rail clearance. Compiler acceptance does not establish comfortable flipper timing or human completion difficulty.

## Persistence and verification

Act format 17 includes the optional Act target, pattern scoring fields, Spinner Goals and authored Goal Ring. Older formats migrate in memory and write format 17 only on explicit save. Format-15/16 ring recipes with the historical one-second delay and default 12-second timeout / 500-point reward migrate to the new ordinary/Bonus Rack defaults; a bespoke timeout or reward preserves the explicit recipe. Format 17 preserves intentional one-second values. Missing fields inherit current defaults. Old switch rewards, bank rewards/reset values and spinner tick values remain exact. Stable pattern IDs and every authored scoring setting participate in fingerprints; numeric rack timers use the existing exact-byte persistence path. Rebuild derived bakes with **Bake Endless.cmd**, or **Bake Prototype.cmd** for the finite run. See [the milestone specification](ADVENTURE_BUDDIES_AND_BUZZ.md) for exact migration and Buddy/enemy behavior.

`tests/scoring_authoring_regression.gd` exercises the real editor's target/rack/spinner/bank controls, undo/redo, invalid values, Save/Reload, format-14 compatibility, unchanged source files and production compilation of all three examples. Runtime coverage lives alongside existing Scorecraft, ring, mechanic, main-game and Endless regression checks.

Verified on Godot 4.7.2: scoring authoring (32 checks), scoring flow (31), ring racks (16), physical pickups (11), Scorecraft (29), authored main game (70), four characters (43), authored gimmicks (91), routing mechanics (103), and real Endless scoring/retirement (30) pass. The three scoring examples were rendered in the actual player, with exit state and theme-rebuild checks. Editor controls were also rendered and inspected. Endless verification uses `tests/endless_scoring_regression.gd -- --seed=34`; add `--no-bakes` only to exercise the explicit developer construction path.

The local published pool was rebuilt for all 56 Act/theme variants and passed the 447-check bake audit. The normal disk-loaded Endless scoring test also passed all 30 checks with the rendered ANGLE backend. The exact staged source was imported separately and passed authoring, scoring flow, ring rack, Scorecraft and four-character checks without the unrelated local art edits. One headless disk-loading run produced dummy-renderer RID diagnostics in the existing character motion trail; the rendered run had no corresponding errors. Windows certificate-store diagnostics remain environmental.

One existing `pinball_mechanics_regression.gd` flipper-to-spinner/rail route assertion still fails identically on untouched commit `0802994` and this milestone; the input sequence does not reach the rail under the current tuning. The other 52 checks, including new goal/traversal coverage, pass. The assertion and physics tuning were preserved. This is a pre-existing route/timing fixture issue, not evidence that the scoring examples are balanced.

Manual review stays short: tune targets using actual Act score categories; check the Exit-open feedback at speed; judge spring/rail combo timing and the three examples' recovery shots. Layout and balance remain author choices.
