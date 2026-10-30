# Combo and scoring economy V1

Current behavior for authored Acts and the shared streamed game, implemented from normalization baseline `4d05c78f516e09c6e9233867629dea7f10650a02`. This section supersedes earlier scoring, combo and enemy descriptions. Physics, authored geometry, Challenge targets, Balls, Goal Ring progression, Special Meter charging and Buddy architecture are unchanged.

## Score economy

Amounts below exclude Buddies and use modern defaults. Explicit authored feature rewards remain authoritative.

| Interaction | Base / fixed points | Combo behavior |
| --- | ---: | --- |
| Physical Ring | 15 | Multiplied; an available three-Ring Link can build |
| Fresh Bumper | 100 | Builder, multiplied |
| Already-used Bumper | 100 | Flat; no advance or refresh |
| Enemy destruction | 200 | Multiplied; builder once per source per chain |
| Floor / Wall Switch | 25 | Multiplied; extender |
| Spinner half-turn | 5 | Multiplied; never builds or refreshes |
| Individual lane | 50 | Multiplied; extender |
| Switch Bank completion | 500 | Fixed; builder |
| Spinner Goal completion | 300 | Fixed; builder |
| Lane Set completion | 500 | Fixed; builder |
| Bonus Rack completion | 500 | Fixed; refreshes an active combo, never builds |
| Spring / Dash Panel / Rail | 0 | Traversal support only |
| Gates / Diverters / magnets / terrain / flippers | 0 | Routing only |

Normal builders advance **before** scoring their hit, preserving the existing bumper convention. Thus a fresh enemy that raises ×1 to ×2 awards 400. The Ring that completes a Link also scores at the newly visible tier. At ×4, four 25-point switches followed by a bank pay `4 × 25 × 4 + 500 = 900`. Fixed completion amounts never receive the combo multiplier.

Buddy percentages apply independently to the completed normal award, including a Homing bonus; contributions are rounded separately and added, never compounded. Existing per-Buddy ledgers and physical/virtual Ring distinctions remain intact.

## Combo builders, extenders and decay

Challenge retains a ×4 cap and a three-second window. Each timeout drops ×4 to ×3, then ×3 to ×2, then ends the chain; each retained tier gets a new window. Standalone's existing configurable cap/decay profile remains available.

Fresh bumpers, enemy destruction, Switch Bank completion, Spinner Goal completion and Lane Set completion build once per stable source in the current chain. A builder starts an inactive combo at ×1, otherwise advances one visible tier. At the cap an unused builder refreshes the window without storing another tier. Repeat sources still pay their normal award but do not build, refresh, or arm a Link. Source eligibility survives tier decay and clears only when the chain fully ends (including drain, reset, Act activation and successful Homing).

Switches, individual lanes, Springs, Dash Panels and successfully completed Rails refresh an active window once per source per chain. They cannot start or advance it. Lanes use `<object_id>:lane:<index>` for scoring/support while retaining the authored object ID and `lane` category. Zero-score switches and lanes still support. Virtual-ring lane rewards retain counter-only semantics; the lane crossing itself can support.

A genuine Rail entry protects an already-active combo for at most five seconds per ride. Repeated entry notifications cannot refill that ride's budget. Completing the ride refreshes once per Rail per chain. Rollback, cancellation and fabricated completion without entry do not refresh. Reset and Act changes release protection.

A completed Bonus Rack can refresh any active chain, including on subsequent rack cycles. It cannot start a chain, add a tier or arm a Link. Pattern timing and physical pickup provide its existing lifecycle limit.

## Ring Link state machine

- Inactive chain: multiplier ×1, chain 0, no Link, progress 0.
- Eligible builder: start ×1 or advance one tier; refresh three seconds.
- Below cap, if no Link is available, arm one at 0/3. If already armed, preserve its partial progress.
- First and second qualifying physical Rings update progress to 1/3 and 2/3.
- Third Ring advances exactly one visible tier, refreshes, consumes the Link and resets progress to zero.
- Link completion does not arm another Link. Another eligible builder is required.
- Reaching ×4 clears all Link availability/progress. Decay does not restore a stored Link.
- While active, internal `chain` equals the visible multiplier. Ending clears eligibility, progress and support history.

The existing combo meter shows Link progress and brief advance/support feedback. It does not enqueue per-frame notifications.

Physical pickups retain +5 base Special charge and their existing lifecycle. Bumpers retain their existing +2 base charge, including repeated and Homing contacts. Mechanic awards and enemy deaths do not charge Special. Lane/Buddy virtual Rings never score as physical pickups, progress Links/racks, charge Special or recursively trigger Ring Buddies. Existing Knuckles/Shadow remote ring and bumper awards retain their area-ability semantics; their enemy hits use generic enemy scoring.

## Enemy lifecycle and Homing

The generic enemy runtime owns the Buzz Bomber definition's 200-point base. Placement `respawn_delay` defaults to 15 seconds and is exposed in the normal object inspector (0.1–300 seconds). No placement-level score field is introduced.

Destruction marks the enemy dead before signals, awards once, and starts an Act-owned countdown. Soft retry preserves the clock. Inactive owners, serve, loading and protected transfer states pause it. At expiry the enemy resets to its authored anchor, starting direction and normal 0.65-second patrol pause, then waits for safety. The entire patrol region is expanded by 128 px plus Ball/enemy radii; current and previous Ball positions and the intervening sweep must clear. A 0.35-second appearance remains noninteractive. Returning Ball cancels the appearance until clear. Only then does the enemy become targetable and emit one respawn event. No RNG or presentation collision controls the lifecycle.

A respawned enemy still scores at the current multiplier but cannot build again in the same chain. A later chain restores eligibility.

Sonic Homing uses the **pre-hit** tier, including on an already-used target:

- Bumper: `100 × multiplier + 400` (500 / 600 / 700 / 800).
- Enemy: `200 × multiplier + 400` (600 / 800 / 1000 / 1200).

The successful hit produces one normal award, applies Buddy bonuses, then ends the combo. Enemy Homing passes through generic destruction exactly once. Acquisition prefers fresh/eligible enemies or bumpers, then used enemies, then used bumpers. Within a class it selects the nearest clear target using the existing full-Ball sweep. No target retains meter. Capacity/cost and all other ability behavior remain unchanged.

## Clean editor defaults and warnings

| New object / recipe | Explicit defaults |
| --- | --- |
| Ordinary Ring pattern | Bonus Rack false; completion 0; timeout 25 s; respawn 18 s |
| Bonus Rack | Completion 500; timeout 12 s; respawn 11 s |
| Floor / Wall Switch | Score 25 |
| Switch Bank | Completion 500; reset 0 (one-shot) |
| Lane Set | Lane 50; completion 500; existing 1.5 s reset |
| Spinner | Tick 5; goal enabled; target 10; completion 300 |
| Elevated Rail | Rings enabled; spacing 35 px |
| Buzz Bomber | Respawn 15 s |

Ordinary/rack toggles replace each setting only when it still equals the old recipe's default, preserving deliberate bonus/timer changes. Untouched rack recipes toggle back to explicit ordinary 0/25/18. Existing authored amounts, geometry and lifecycle settings are retained; new defaults do not rewrite saved files.

Verify Act adds nonblocking semantic warnings for an unbanked zero-score switch, a zero-bonus bank without routing actions, and banks with identical member sets and equivalent gate/diverter actions. Member/action order and legacy gate-open versus explicit open representations do not hide duplicates. Shared subsets are legal. A zero-bonus bank can still build a combo: its warning accurately describes the absence of a completion score or routing action. Rail density remains an author choice.

## Rings, objectives and Act progression

The first physical pickup starts its pattern timeout; later pickups do not extend it. Completing an enabled rack pays once, then waits its respawn delay. Ordinary patterns have no completion reward. Incomplete timeout restores the pattern without a bonus. Pattern IDs remain independent, including overlapping patterns and streamed copies; duplication creates a fresh identity.

Pattern progress/clocks survive retry and pause with collection/owner gating. Ring respawn retains the existing 128 px safety expansion and 0.35-second noninteractive fade. This milestone does not change Ring placements, timeout or respawn values.

Banks with reset 0 remain complete through soft retry. Deliberately repeatable banks can rearm and pay again, but never farm the same chain's builder/support eligibility. Spinner goals and lane sets keep their authored repeat/cooldown lifecycle. Gates remain open after bank rearming; authored diverter actions keep their existing behavior. Both zero-bonus and scored feature completion emit builder events, with no duplicate award from visual completion feedback.

The editor's optional standalone `score_target` still defaults to 0 (ungated). Enabling starts at 3000, adjustable from 1 to 100,000,000. Reaching it opens the physical Exit without teleporting. Earned points and open exits persist through retry; activation of another Act starts a new local ledger and combo. Explicit `--free-play` bypass remains a standalone traversal aid.

Finite Challenge continues using physical Goal Rings and sequence targets **1000 / 1500 / 2000 / 2500 / 3000 / 3500**. Balls, Practice retry behavior, Buddy drafts, target snapshots and protected transfers are unchanged.

## Production Act changes

Only twelve score properties and eight enemy respawn properties changed from normalization baseline:

- RampMania's five and Secret Entry's seven existing switches now explicitly award 25.
- Every production Buzz placement explicitly stores `respawn_delay = 15.0`.
- Reverse C Spring and SpringUp switches remain 25; First Try has no switch change.
- Four banks retain 500/reset 0; seven Spinner Goals retain 10/300.
- All racks, Ring geometry, object transforms, patrols, terrain, gates and Goals remain unchanged.
- Rail spacing remains RampMania 35/45 px and Secret Entry 30 px.

The unrelated local deletion of `Second Simple.tres` is outside this milestone.

## Historical normalization baseline — 2026-10-30

Before economy V1, the five source Acts in `data/acts/Authored` now explicitly describe the existing mechanics before any future scoring/combo redesign. This pass started from implementation commit `338c28e410a352aee85f8d9d9237aa61e8a345ff` and, with the author's approval, retained the newer local Act revisions, including their Buzz Bombers and Goal Rings. Terrain, connectors, spawn/goal positions, object transforms, ring geometry, physics properties and decoration were preserved from those local revisions.

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

At that normalization milestone only, Scorecraft, Ring Link, combo participation, enemy lifecycle, Sonic Homing, Special Meter and global defaults were unchanged. Economy V1 above supersedes that scoring baseline. Challenge still assigns sequence targets of 1000/1500/2000/2500/3000/3500. No per-Act score targets or additional mechanic families were added.

The existing prototype baker rebuilt all ten derived Act/theme variants (five Acts across Green Hill and Chemical Plant); the source/pipeline fingerprint and collision/visual-recipe audit passed 33 checks. Sidecars remain ignored, rebuildable outputs. The historical fixed Endless snapshots were not republished.

Focused verification on Godot 4.7.2: 151 source-preservation, validation, physical-ring and objective checks passed both in the working checkout and against an isolated HEAD implementation with the five normalized Acts. Existing ring-rack checks passed 25 assertions, rail-ring checks passed 13, and the real soft-retry regression passed 26. Seven rendered captures covered all five Acts and both rail layouts. Disk-loaded rail streaming passed seven assertions and exited cleanly headlessly. The rendered streaming run passed those assertions but encountered a native Windows shutdown crash (exit -1073740771); this is recorded as an unresolved shutdown limitation, not a successful process exit. Manual flipper feel, route difficulty and scoring balance remain unassessed.

## Passive telemetry v2

Copy Run Data exports `telemetry_format_version = 2` and retains every v1 field: run seed, mode/character/build, raw target/Goal/end timing, target score/Buddy snapshots, score after target, Balls lost, Buddy state/contributions and derived rates. Results remain concise; detailed diagnostics stay in JSON.

Each Act additionally exports:

- `score_by_category`: normal score only for ring, bumper, enemy, switch, switch_bank, spinner_tick, spinner_goal, lane, lane_set, ring_rack and other.
- `combo_score_by_multiplier`: sensitive base score at keys "1" through "4". Excludes fixed completions, repeated flat bumpers, remote area payouts and Homing's fixed +400; includes Homing's multiplied base.
- `combo_advances_by_source`: bumper, enemy, ring_link, switch_bank, spinner_goal, lane_set. Initial ×1 starts count; cap refreshes do not count as advances.
- `combo_support_by_source`: switch, lane, spring, dash_panel, elevated_rail, ring_rack, builder_refresh. An advancement is not also counted as support.
- `x4_activations`, `highest_multiplier`, `longest_combo_seconds`, `longest_combo_max_multiplier`. The longest chain includes its decayed tiers and uses the existing gameplay clock; Goal completion snapshots an unfinished chain.
- `homing`: finishers_used, successful_hits, normal_score and hits_by_target_type.
- `enemies`: destructions, respawns, normal_score and per-type lifecycle counts.

The telemetry object only listens to existing score/lifecycle/combo events and reads the run clock. It does not mutate gameplay, score, physics or RNG. Category totals reconcile to normal score; Buddy contributions reconcile separately to the full score. Homing/enemy totals overlap categories intentionally and must not be added to them.

## Persistence and verification

Act format 17 remains unchanged. New enemy properties use the existing extensible object dictionary and fingerprint. Older resources migrate in memory and write only on explicit save. Explicit saved rewards and recipe timings remain authoritative. Rebuild derived sidecars with **Bake Prototype.cmd** for the finite run or **Bake Endless.cmd** for the separately published Endless roster. Baking does not publish editable Acts.

Focused coverage uses existing Godot regression scripts plus `tests/economy_v1_regression.gd`: real game/feature wiring, physical Ring claims, visible Link progression, repeated-source eligibility, fixed payouts, zero/virtual-score support, safety-gated respawn, Homing, editor save/reload and semantic warnings. `tests/enemy_stream_regression.gd` exercises real streamed ownership, retry/respawn, a physical ×4 Homing hit, Buddy reconciliation and JSON v2 through the run adapter.

Existing scoring example Acts remain editable and retain their deliberately authored rewards/targets; they are not silently normalized. Human playtesting must still judge scoring pace, flipper timing, Homing target preference, enemy reappearance and HUD readability. No Challenge target or level balancing is claimed.

### Verified milestone checks — Godot 4.7.2, 2026-10-30

The exact staged implementation was imported into an isolated checkout without the unrelated local art edits. Twelve headless suites passed **514 checks**: economy V1 (44), authoring (57), Scorecraft (29), Buddies (70), enemies (45), enemy streaming/telemetry (27), scoring flow (31), physical Rings (11), racks (25), four characters (43), routing mechanics (103), and protected soft retry (29). There were no script errors. The new integration fixture also creates its output directory in a clean checkout.

Additional existing checks passed in the working checkout: authored main-game integration (70), rail Rings (13), pinball editor (30), and raw telemetry timing (12). All ten local production Act/theme bakes were rebuilt; the source/pipeline, collision and visual-recipe audit passed 33 checks. A text-preservation audit confirmed the five production files differ from the starting commit only by twelve switch rewards and eight enemy respawn values.

Rendered ANGLE checks passed with successful process exits: the full six-Act prototype (136 checks), score feedback (25), and editor save/reload (57). Captures were inspected for visible ×2/×3/×4, Ring Link feedback, Goal readiness, wide-window layout, editor controls and concise Results. The actual Copy Run Data button placed valid telemetry v2 on the OS clipboard; all six normal-category totals and Buddy contributions reconciled.

The full rendered run reported **31 leaked ObjectDB instances at shutdown**, despite exit code 0; frame hitches were also observed during presentation preparation. These remain limitations, not a claim of leak-free or smooth performance. The automated run injects scoring and traversal to verify integration; its short completion time is not balance or human-play evidence. Manual scoring pace, flipper feel and enemy/Homing readability still need playtesting.
