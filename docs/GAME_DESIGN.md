# Sonic Spinball Runners — Living Game Design

## Status and use

This document records the project's intended direction, not a claim that its systems already exist. Consult it before major gameplay or architectural changes. Update it as decisions are agreed and playtesting provides evidence.

- **Confirmed direction:** agreed design goals and constraints. These may belong to a later phase rather than the current prototype.
- **Tentative:** proposed mechanics, examples, and balancing values that need validation.
- **Future:** explicitly outside the current phase; not a commitment to implement now.
- **Implemented:** behavior observed in repository source or documented verification. This is distinct from proposed experiments and does not imply new testing during a documentation update.

### Current design and implementation snapshot — 2026-10-24

The current product defaults to an endlessly replayable Free Play physics sandbox. Standalone Score Attack adds a single-table objective; optional Green Hill Zone adds the first three-Act loop with score gates, checkpoint retries and Chao drafts. All modes share authoritative invisible 2D physics, seeded geometry, profiles, modifiers and the existing score events. The primitive playground and integrated Green Hill presentation remain separate launch options. Zone 2, permanent progression, limited lives, bosses, shops and rarity are outside the current prototype.

Free Play and standalone Score Attack use the **Vertical Traversal Playground**: a seeded three-section course with reusable dual-connector middle chunks, bottom and middle flipper pairs plus a short upper flipper, reproducible difficulty preferences, a following perspective camera and fixed overview. Green Hill Zone extends the same construction to nine connected chunks with one bottom launch deck and one final cap. Shared physics profiles/modifiers, scoring, swept ring collection with cosmetic flight and live tuning remain intact. Generator validation and regression results are documented in `VERIFICATION.md`; subjective difficulty remains a playtesting question.

The depth experiment retains Real Pinball perspective as the default, a lower Dramatic preset and a top-down orthographic reference. Follow mode adds bounded, damped translation with a vertical dead zone, upward lead and gentle horizontal response, without rotating during play. Overview fits the complete generated course. Raised meshes, contrasting materials and shadows remain collisionless; floor, overlays and cameras derive their extent from generated bounds. README records provisional camera values; this document owns the long-term design. Historical sections below retain earlier implementation and verification context.

### Phase 1 implementation history — 2026-10-22

The workspace was empty at initial inspection, but prototype files appeared during this documentation pass. This baseline describes the files subsequently inspected; development appears to be ongoing. The directory was not a Git repository at inspection.

Observed implementation:

- `project.godot` configures a 1280 × 900 window, 120 Hz physics, and 2D gravity of 700. Godot MCP reports installed Godot 4.7.2.
- Shared `PhysicsProfile`, `PhysicsModifier`, and `PhysicsTuning` scripts provide centralized settings, Balanced/Floaty resources, tuning overrides, and a practice modifier. Floaty currently uses gravity scale 0.58 and a downward speed limit of 1000, versus Balanced's 1.0 and 1500. These are prototype values, not confirmed balance.
- The resolver applies an override or profile default, adds all additions, multiplies all multipliers, then clamps to each field's limits. Profile switching clears overrides but preserves the enabled practice modifier. Full run/temporary-effect reset policy remains open.
- Ball and flipper scripts implement 2D physics; the input adapter contains the agreed Windows controls and extra launch/reset/pause/debug bindings.
- The practice Chao resource multiplies steering acceleration by 1.25 and flipper launch strength by 1.15. It is a tuning demonstration, not Chao drafting or a finished collectible system.
- `scenes/playground.tscn` now runs through `scripts/game.gd`. The completed Phase 1 build includes two manually connected sections, 2D rails and bumpers, physical flippers, rings, scoring/meter, automatic drain recovery, a collisionless 3D presentation, and live tuning. Headless startup and the graphical MCP session now succeed.

No existing gameplay source was changed for this documentation task. A small standalone regression script was added at `tests/profile_regression.gd`; it requires no testing dependency or framework. The missing scene script is recorded for the ongoing prototype work rather than replaced with an unrelated implementation.

Completion update: the missing script was supplied by the prototype implementation. The earlier missing-script finding below is historical and resolved. See `../README.md` for current runtime architecture, controls, tuning and modifier rules, and `VERIFICATION.md` for checks and manual-test limits. The original centered mapping was replaced during vertical traversal with `(x, y) -> (x * 0.01, visual_height, y * 0.01)`; all collisionless visuals use that same mapping.

## Vision

**Confirmed direction:** A Sonic-themed, physics-driven pinball roguelite combining Sonic Spinball's pinball gameplay, colorful presentation inspired by Sonic Runners and Sonic Mania, and Balatro's build-crafting philosophy.

The game should be accessible and immediately fun while supporting deep combinations of character physics, passive abilities, collectible Chao, scoring modifiers, and character-specific specials. Windows is the initial platform; Android is a potential later target. Development uses Godot 4 and GDScript.

## Current scope: Playground, Score Attack and Green Hill Zone

**Confirmed playground scope:** Free Play and standalone Score Attack generate three connected sections: the familiar bottom launch deck, a reusable middle with top/bottom openings and recovery flippers, and a capped upper section. Follow the ball upward, horizontally and back down. Falling between chunks is normal gameplay; drains in these two modes return to the bottom without checkpoints. Free Play remains an endlessly replayable sandbox. Green Hill Zone is a separate optional progression experiment described below; it does not replace the sandbox, difficulty preferences or construction-grid tools.

**Confirmed and implemented Score Attack experiment (2026-10-23):** Opt into a fresh single-table challenge through the existing HUD. Accumulate points through the existing ring, bumper and rack-clear callbacks; reaching the configured target unlocks a collisionless goal near the upper end of the generated table. Completion requires subsequent physical proximity/swept contact with that goal. An earlier locked visit is not banked. Existing transformed target/navigation/ring anchors and clearance checks determine placement; no fixed world coordinate, generation change, new obstruction or 3D collision is introduced. Victory pauses play and presents same-seed replay, next table, and return to Free Play. Replay/regeneration resets the objective, score, rack and timers. Drains and ordinary ball resets retain progress and unlimited retries. Physics profiles, modifiers, steering, flipper mechanics and camera behavior remain shared with Free Play.

**Tentative tuning and evidence:** Start at 1,500 points with a 55 px goal radius, plus the existing 14 px ball contact radius. The target is configurable before starting a fresh challenge. Input-only Balanced trials unlocked in approximately 13–32 simulated seconds; successful upper-goal finishes ranged from approximately 20–86 seconds. Some bot policies failed to finish despite sufficient score. This supports a short scoring phase followed by a meaningful climb, but does not establish human enjoyment, tier balance or completion time. Score is intentionally retained after drains so repeated attempts remain useful. See [verification](VERIFICATION.md) for sampled layouts and limitations.

**Completed foundation:** The Physics Playground supplies:

- An invisible 2D physics ball, two flippers, bumpers, walls, and basic collectibles.
- A tilted 3D presentation independent of physical collisions.
- Configurable physics with Balanced and Floaty test profiles.
- A debug tuning panel for rapid experimentation.

**Implemented three-section traversal scope:** Preserve the launch deck's geometry, flippers, drain and serve relative to its footprint. Choose among eight capped top sections and three dual-connector middle sections. Open Relay and Bank Relay offer broad routes; Rebound Relay adds asymmetric positioning. Resource-defined middle flippers use the existing left/right actions simultaneously with the bottom pair. The Zone extension also reuses these controls. Rotations and runtime streaming remain unimplemented.

**Implemented drain/recovery refinement (generator v6):** Playtesting and real physics drops confirmed that the original 150 px bottom paddles blocked the 28 px ball with a 19.23 px resting gap. They now use 130 px lengths at the same pivots, opening a 57.20 px resting gap and at least 44 px through the swing. Middle placements vary: side recovery in Open Relay, staggered recovery in Bank Relay and a shorter traditional pair in Rebound Relay. This deliberately supersedes preservation of the original flipper geometry above; rails, bumpers, rings, connectors, serve and drain remain unchanged. Per-placement length drives collision, presentation and leverage consistently. Shared input, physics profiles, steering, angular speeds and strike formulas remain intact. Unlimited automatic retries continue; no lives limit or game-over state is introduced.

**Playtesting limit:** A raised bottom flipper can cradle the ball at its pivot against the incoming wall; releasing it frees the ball. Genuine missed shots must drain, and resting tip gaps must not form an unintended stable cradle. Lengths and arrangements remain provisional. Existing static difficulty estimates do not yet account for recovery timing or paddle coverage.

**Confirmed and implemented side recovery refinement (generator v10, kit v2):** User feedback identified middle paddles sitting too far from the side walls. Catalogue and grid pivots now move outward while retaining full-ball clearance behind the complete swing. Every capped upper chunk, including fallback, has one short 70–85 px paddle using the existing side action and transformed placement. Easy grid banks use shallow rounded profiles and both grid/legacy seams use short curved collars, removing their tiny horizontal steps. Normal/Hard authored corners remain intentional. Green Hill's grid shortcuts now preserve the active seed and difficulty instead of silently selecting Normal, and its footer displays that difficulty. These are layout and interface changes; flipper impulse rules, steering, scoring and unlimited drain recovery remain shared. Paddle lengths, timing and subjective flow still need human playtesting.

**Implemented construction experiment (generator v7, kit v1):** Author reusable construction pieces on a 50 px grid, then compile them into the existing geometry/object descriptors. A Resource-authored middle chunk and a two-placement variant are opt-in in Table Generator; legacy chunks remain the default. Multi-cell banks, slopes, corners, straight rails, grid-anchored bumpers/rings and staggered flippers share physical clearance validation. Ball motion remains continuous, the 100 px whole-chunk placement grid is unchanged, and no unrestricted random tile generation is added. Chunk mirroring/shifting remains supported; rotations remain disallowed. A source-grid overlay exposes coordinates and footprints, while the physics overlay shows final geometry after connector shaping. Built-in TileMap editing was investigated; a Resource-first compiler avoids a second layout authority and can accept an editor adapter later. See [Grid authoring](GRID_AUTHORING.md) for limits and workflow.

**Implemented three-section baseline choices:** Top/middle footprints are 7 × 7 or 8 × 7 cells, the bottom is 8 × 7, and cells are 100 physics pixels. Ordered sections occupy rows 0, 7 and 14; two adjacent junctions connect the 800 × 2100 sandbox course. Full-width sections stay aligned; narrower sections retain both shifts and mirroring. Regeneration requires pause or serve, resets counters/rings/timers/ball/camera state, and preserves tuning, camera mode/settings, overlays and pause. Its fallback also has three sections. Zone regeneration instead starts a fresh nine-chunk run and clears acquired rewards. See [Generation contract](GENERATION.md) for version-specific rules and validation limits. Generator v4 changes seed mappings; v3 remains a regression fixture.

**Difficulty-aware experimentation:** Generator v4 retains the v3 maximum-of-components formula across all sections and junctions. Intrinsic chunk challenge, connector widths/offsets/ledges and sampled approach clearance/turns/obstacles remain distinct from validity. A challenging join cannot be diluted by averaging. Select a valid course within the requested tier in seeded order; report a shortage explicitly before using the closest valid alternative. Difficulty never relaxes collision validation or changes character physics.

**Provisional tuning:** User playtesting selected Quick / Tight for both Balanced and Floaty: strength 0.10, normal acceleration 2200, counter deceleration 4000, contribution limit 120, and release deceleration 3000. Original, Air control, and Stronger brake remain selectable. Phase 2A does not change steering/release semantics.

The subsequent Character Lab v1 adds Sonic and Tails specials to all three modes. Complete character artwork, Android controls, additional Zones and persistent campaign systems remain outside this milestone. ArtBro owns themed presentation and animation polish. Avoid unrelated refactors.

### Green Hill Zone prototype — three connected Acts

**Confirmed perimeter mounting and Target Garden route experiment, 2026-10-24:** The user approved compact wall-mounted flippers after rejecting large wall wedges. Move pivots toward existing boundaries, preserve open central space, and remove secondary paddles that become ineffective. Zone generator v5 / kit v5 applies this arrangement only to Normal Target Garden: pivots move 50px outward to x125/675, 25px from the existing rail centerlines. Compact 18px bearings join a 48px wall span; walls and paddle lengths are unchanged. The kit's `mounted_` variants use passive 2D geometry shared with presentation and route validation, without bumper scoring or special targeting. Other rooms retain their previous arrangements while Garden's route choices are playtested.

Only a housing's own sealed bearing may overlap its paddle root. The complete paddle capsule must clear its attached wall, with full ball passage required beyond the first 60px; other walls, bumpers and paddles retain their original margins. Every sampled swing keeps the housing behind the exposed blade. Mirroring and shaping must preserve the compact attachment rather than extend terrain inward.

**Confirmed route purpose; provisional placement and timing:** A successful secondary-flipper shot can mean upward traversal, not just a target hit. Garden's source-right paddle has a diagonal ring trail toward the actual upper opening. Its large bumper moves from (550,200) to (600,200), outside the clean climbing trajectory. Earlier contact can still attack that bumper for points, with rebound and fallback risk. The left paddle feeds the small target cluster through a separate short trail. Optional `shot_kind` metadata distinguishes `score` from `upper_passage` in authoring and checks; it never influences runtime aiming or scoring. Existing contact-dependent physics supplies both shots. Controlled gravity drops verify five neighboring clean-climb timings and distinct scoring/miss outcomes in both mirrors; human timing comfort remains unproven. Primary Act funnels and gameplay systems remain unchanged. Review Garden's gameplay-camera captures and input demonstrations before applying this route-design principle elsewhere.

**Middle-flipper feel revision, 2026-10-24:** Zone generator v4 makes three focused geometry changes without adding rooms. Normal Target Garden moves its shallow side shoulders above its recovery pair and keeps pivots 75px off the wall, allowing descending wall returns to reach a real catch. Hard Bank Vault removes its redundant short right paddle; its left bank-fed recovery remains. Offset Climb lowers its short paddle by 50px to intercept the opposing-bank return. Other reviewed Normal/Hard placements remain after upstream gravity-feed, missed-shot and mirrored traversal checks. A missed middle catch falls to the existing lower recovery area; primary Act drains and checkpoints are unchanged.

All modes now share a provisional arcade aiming rule derived from contact fraction and current paddle orientation. Heel contacts aim farther inward, while tip and later contacts aim straighter upward; angle bounds retain a strong upward component. The shared resolver still supplies launch strength, including Spring Chao, with unchanged leverage scaling and additive physical impulses. No target lookup, automatic aiming, teleport or velocity replacement participates. Release cancels the powered catch, stationary follow-through lasts at most two physics ticks, and underside contacts receive only ordinary collision response. Existing controls, angular speeds, character profiles and temporary effects remain intact. `shot_fired(contact_position, impulse, contact_fraction)` supplements the existing strike signal for presentation and debugging. These values and timing fairness remain subject to human playtesting.

**Normal/Hard composition revision, 2026-10-24:** Zone generator v3 preserves the official Easy library and adds six distinct Normal rooms plus six Hard rooms. Each development Act contains its recovery area, an interaction chamber and an exit approach; the final Act uses a capped objective room as its approach. Three interaction identities appear once each per run, with two distinct open approaches. All Acts use the selected tier; Act number does not increase geometric difficulty. A shared Act mirror preserves the authored direction of side lanes while compatible connectors assemble the route.

Normal emphasizes broad asymmetric chambers, flowing banks and recoverable target shots. Hard places precision in target gaps, offset shot lanes and selective recovery coverage. Both use validated sloping joins instead of adding arbitrary Step ceilings. Normal retains 160px Curve collars; Hard's 240px Bank collars accommodate the existing narrow capped chambers without relaxing the maximum bank grade or any physical-clearance rule. Private shaping never changes Free Play resources. Full authored object and flipper clearance is rechecked after shaping.

The worst junction remains part of difficulty reporting. Separate Zone composition checks require five distinct relay IDs, at least three sampled interior silhouettes and an interaction/approach pair rated for the intended tier in each Act. Every Hard Act must also have at least two sampled interior rows whose widest clear ball-center lane is at most 320px. This provisional geometric proxy is independent of seam severity and prevents numeric ratings or one difficult join from qualifying an otherwise empty corridor as Hard. It does not establish human success rates; actual shot witnesses and human playtesting remain necessary.

Paddle arrangements now follow declared side-recovery or precision roles and authored scoring targets. Some rooms have no paddles and rely on neighboring recovery areas; others have one paddle or an unequal pair. The kit adds 80px precision paddles and shallow 50-by-100px slope stamps. Shared flipper timing, force, steering and character physics are unchanged. `zone_role`, `shot_description`, and transformed paddle `role`/`shot_target` metadata expose intent without controlling physics or awarding points remotely. Zone UI calls its arrangement choices Layout shuffle A/B/C; sandbox catalogue/base/variant semantics remain unchanged.

**Playfield design revision, 2026-10-24:** Each Act now has a reusable sloped recovery funnel, a central 2D drain and a marked side serve. The user rejected the first cup/plunger experiment during review. The confirmed prototype instead holds the character visibly at the serve until Enter / X, then releases it into ordinary gravity with no preset velocity or kick. The ball rolls toward the flippers for its first shot. Respawns reuse that mechanism. A temporary serve reset is the only position assignment; releasing the serve does not teleport.

Future Act funnels and their flippers retract during upward entry. The score gate still controls the boundary. Act completion waits until the entire ball reaches a generated safe-entry line above the future funnel's collision envelope; only after the mandatory draft does that funnel activate and the previous gate latch. Weak entry attempts may return before completion. A bounded central drain, with swept detection for fast motion, replaces the old whole-width checkpoint reset line. Score, Chao and unlimited retries retain their existing rules.

The safe-entry line uses the incoming chamber's width, inset by the ball and rail radii. This allows a valid angled shot to spread sideways after passing a narrower score gate without missing the completion trigger. The physical gate retains its original opening.

Zone generator v2 chooses five distinct relay archetypes from eight authored Easy rooms, plus two checkpoint decks, the bottom funnel and final cap. The 50px kit supplies mounted circles on straight/curved walls, varied circle sizes, triangular slings, broad return lanes and purposeful ring arrangements. Mirroring and safe horizontal shifts vary these authored layouts. Grid modes use the same full library with different deterministic shuffles. Static difficulty remains separate from collision validity; numerical ratings do not establish human ease or fun.

**Development-only override:** Official Green Hill remains Easy. F1 may explicitly request a complete Normal or Hard Zone, with the selected tier labelled in the HUD and retained across replay. All candidates use the same collision/route validation. Failure reports the unavailable tier and preserves the active table; there is no fallback to Easy. This is a testing option, not a new campaign difficulty mode.

**Confirmed and implemented:** Select Green Hill Zone through the shared mode selector in either presentation. Pre-generate nine physically connected chunks, three per Act, with eight validated joins. Every Act has a recovery deck; only the bottommost one closes the outside course and only the final chunk has a roof. Intermediate boundaries combine score gates with retractable checkpoint funnels. All three official Acts use the same broad Easy geometry philosophy; score targets escalate, geometry difficulty does not. The 50 px construction kit, mirrored chunks and existing collision validation remain in use. Follow and overview cameras derive their bounds from the entire course.

**Separate scoring challenges:** Total Run Score accumulates through the existing bumper, ring and rack-clear callbacks. Current Act Score counts only points earned since entering that Act; entering the next Act resets that subtotal and preserves the total. Only the active Act's scoring objects count. Active ring racks refresh after a clear and at checkpoint resets, so retries retain scoring opportunities. `ZoneConfig` stores the official Easy difficulty and three score targets. The explicit development override is separate from that official configuration.

**Tentative tuning:** Act targets are **750 / 1,250 / 1,750** points. These are provisional values for the existing 25-point rings, 100-point bumper hits and 500-point rack bonus. They are not established human completion-time or enjoyment targets. Physics-driven traversal evidence, remaining limitations and actual checks belong in [Verification](VERIFICATION.md).

**Mandatory physical exits and rewards:** Act 1 and Act 2 exits remain physically closed until their own score target is met. A locked gate returns the ball into the current Act. Unlocking removes the obstruction; an upward shot must then clear the marked safe-entry line above the next Act's retracted funnel. That crossing pauses gameplay for a mandatory Chao choice. The same body, position and velocity resume into the next Act after selection. No scene reload or transition teleport occurs. The recovery funnel activates and a gate closes behind the ball, preventing a return to completed Acts. The final Act instead has a collisionless upper portal; its own score target and physical contact are both required. Entering it opens the third draft, then the Green Hill Zone completion summary. There is no fourth score gate or actual Zone 2.

**Checkpoint and replay policy:** Entering an Act sets a safe checkpoint in that Act. Falling between its three chunks is allowed. Missing the Act-bottom flippers and entering the central drain triggers a checkpoint retry before the ball can fall into a completed Act. Unlimited retries retain Total Run Score, Current Act Score, completed Acts and acquired Chao. A fresh Zone or same-seed replay resets all Zone progress and starts with no Chao. The previous single-slot sandbox Chao is restored when leaving Zone mode; Zone rewards cannot leak into Free Play or standalone Score Attack.

**Presentation hooks:** `ZoneRun` exposes `changed`, `exit_opened`, `draft_started`, `act_started` and `completed` signals, plus current state, Act records in `acts`, and acquired reward IDs in `acquired`. These are gameplay hooks for ArtBro's gate effects, portal effects, Chao visuals and Act announcements. Current gates, portal, draft cards and completion screen use readable placeholders. Decorative meshes remain collisionless; the invisible 2D ball and gate bodies own physical interaction.

## Presentation and camera

**Implemented Green Hill experiment — 2026-10-23:** Green Hill is integrated on main and skins the sandbox, including recovery flippers, 50 px grid recipes with broad Easy variants, Normal-flow connections and shared Score Attack. It also presents the optional nine-chunk Zone with the same gameplay state, draft UI and collisionless goal markers as the physics playground. Terrain rebuilds from transformed collision outlines on regeneration. F1 exposes the original tuning/generation tools; overview and character study remain presentation options. Separate Windows launchers preserve the primitive physics playground.

The optional local Sonic model supplies table-aligned jump and trick poses while a procedural spin-ball handles the default gameplay state and asset absence. During gameplay, the head points up-table (-Z), feet down-table (+Z), and front toward the board normal (+Y). A separate imported-model alignment transform keeps this correction independent of smoothed, bounded in-plane lean. Descending motion retains the head-up orientation. Character study alone uses the conventional upright orientation. Contact-marker position and ring attraction share the observed 2D ball anchor. Brief flipper jumps, bumper tricks, a short trail and pickup pulses are collisionless feedback only; the RigidBody2D remains the sole gameplay authority. Third-party files and captures are ignored. This visual integration originally added no progression; the later Zone controller supplies progression independently of presentation. Visual scale, animation duration and camera comfort remain provisional playtesting choices.

**Confirmed direction:** View the vertical playfield as if standing in front of a real pinball machine, through a moderately tilted **perspective camera**. The bottom appears larger and closer; the top recedes and appears slightly narrower. Think of a much less extreme Temple Run-style perspective combined with Sonic Mania's pinball gameplay. This supersedes the earlier orthographic design preference. The eventual colorful, relatively simple Sonic Runners-inspired presentation remains compatible with today's blocky sandbox visuals.

**Implemented camera experiment:** Follow the ball vertically through the sandbox or Zone, gently adjust horizontally, and provide upward look-ahead. A tunable dead zone, separate response rates and speed cap soften rebounds. Upper/lower bounds prevent following beyond the course. Rotation stays fixed during movement. A debug toggle selects the fixed overview; pause freezes tracking and reset reframes the active serve/checkpoint. Crossing an Act boundary retains continuous camera tracking.

**Tentative tuning:** Follow defaults are a 100-pixel vertical dead zone, 100-pixel upward lead, 5/s vertical response, 2/s horizontal response and 1800 px/s speed cap. Horizontal target movement is 18% of the ball's offset from course center, capped at 55 pixels. Follow framing covers a local 1100-pixel window; view distance is derived from projection/aspect and the object-height envelope. These are playtesting values, not final camera behavior.

**Implemented depth experiment:** Top-down reference uses orthographic projection. Real Pinball uses a 60° elevation above the board and 40° vertical FOV; Dramatic uses 50° and 52°. Each preset supports following and full-course overview. Geometry footprints remain derived from 2D descriptors, including mirrored triangles and closure rails. The ball remains a sphere. Heights and camera settings are provisional; human playtesting must judge visibility, distant-lane readability and rebound tracking.

An invisible 2D physics ball owns collisions and gameplay movement. A collisionless 3D character model follows its position and animates independently. The physical ball continues moving during every visible animation. Character models, themed scenery, and animation timing never determine physical collision geometry.

**Confirmed presentation direction:** Three principal gameplay character states:

1. Rolling or spinning during ordinary ball movement.
2. A jump animation following flipper launches.
3. Brief signature poses following exciting bumper impacts or other physics events.

The visual-lab adapter implements these states plus a paused upright showcase. Real flipper and bumper events drive timed uncurl reactions with repeat suppression, small cosmetic hops, and a smooth return to the separate procedural spin-ball. Provisional tuning uses ±23 degrees of horizontal-velocity lean, a 45 px/s dead zone, 0.62-second jumps, 0.56-second tricks and 0.12-second transitions. No grounded state, root motion, collision or score changes are inferred from these animations. Camera comfort, pose quality and timing remain playtesting choices. Complete character animation is outside the current sandbox scope.

## Characters and physics

**Confirmed direction:** Playable characters have different starting physics profiles. Each may also have a passive ability and a rarer player-activated special. Character Lab v1 uses Balanced for Sonic and a controlled Tails profile; Floaty remains an optional debug profile. No passive ability system is implemented.

**Tentative character examples:** Sonic is relatively fast and balanced; Cream is floatier with slower descent; Knuckles is heavier and more forceful. These are intended feels, not fixed numerical specifications.

Configurable physics should cover steering acceleration, steering deceleration, steering responsiveness, maximum steering contribution, gravity, downward speed limits, rolling behavior, flipper launch power, wall and bumper recoil, ring magnetism, and related properties as needed.

**Confirmed architecture:** A centralized stats system resolves character defaults, Chao upgrades, temporary effects, and game-mode rules. Use shared profiles and modifiers rather than scattered hard-coded character checks. Introduce only the pieces needed by implemented features. Modifier stacking, ordering, limits, and reset behavior must be predictable. The sandbox's additive-then-multiplicative resolver is implemented; future Chao limits and campaign reset rules remain undecided.

## Controls and steering

**Confirmed Windows mappings:**

| Action | Controller | Keyboard fallback |
| --- | --- | --- |
| Left / right flipper | LB / RB | Q / E |
| Limited lateral steering | Left analog stick | Left / right arrows |
| Character special when READY | A | Space |

Steering should resemble slight air control in traditional Sonic games. It should not provide full character movement. Responsiveness, acceleration, deceleration, and maximum contribution must be independently configurable.

**Tentative tuning:** Approximately 5–8% steering influence was the initial calibration idea; Original retains `steering_strength = 0.065`. Both test profiles now use Quick / Tight at 0.10. Strength scales acceleration/deceleration toward a separately capped steering contribution, not a measured percentage of total ball motion. Do not treat the original percentage as an acceptance threshold.

**Steering investigation:** Playtesting found weak response against existing lateral momentum. The implementation was applying counteracting impulses, but the original 65 px/s² rate and 120 px/s contribution cap limited their effect. Steering was not disabled on descent. An independent counter-steering deceleration setting and comparison presets were added; subsequent playtesting selected Quick / Tight as the Phase 2A provisional default. Counter-steering remains bounded assistance, and release unwinds that assistance rather than permanently dissipating external momentum. Collision bookkeeping resets remain unchanged. See [the steering investigation](STEERING_INVESTIGATION.md) for the exact trace, telemetry, and comparisons.

**Future Android plan:** A virtual analog stick on the left, with two flipper buttons and a special button on the right.

**Future possibility:** A separate Arcade Mode could allow nearly complete movement control for a relaxed, chaotic experience. It is outside the first prototype.

## Chao and build crafting

**Confirmed and implemented Chao Lab v0 (2026-10-23):** Before a fresh Free Play or standalone Score Attack attempt, choose Ice (control), Spring (power), Magnet (collection), or None for a baseline. A shared modal UI compares their effective stats and the equipped name remains visible during gameplay. One slot feeds the existing `PhysicsModifier`/`PhysicsTuning` resolver. Equipping restarts the same seed after successful validation; preview/cancel cannot change physics. Replay, drains, ball resets, profile changes and regeneration retain the slot. Legacy Practice Chao replaces the slot and never stacks with it. Zone mode uses its own acquired build and disables pre-run Chao/Practice replacement; leaving the Zone restores the previous sandbox choice.

**Confirmed Zone draft rules:** Each completed Act offers the same three prototype choices: Ice, Spring and Magnet. The pool is fixed, with no random selection or rarity. Pick exactly one; rewards persist and combine through the existing centralized resolver. A second copy of a species occupies a second slot and multiplies its effect once more. A third copy is disabled. Builds support at most five slots, although this Zone awards only three picks. Shared field clamps bound the final effective values after profile overrides and all selected modifiers. Rebuilding, restoring or previewing a build never adds extra modifier instances. The final draft appears in the completion summary for eventual Zone 2 carryover; replay clears it. Inventory, shops, permanent unlocks and saved campaign builds remain unimplemented.

**Tentative Chao tuning:** Ice multiplies steering acceleration by 1.5, counter-steering by 1.75 and its bounded contribution limit by 1.25. Spring multiplies flipper impulse strength by 1.35; its initial 1.25 was too subtle in controlled moving-paddle samples. Magnet doubles ring radius, preserving immediate collection and cosmetic flight. All existing limits apply after overrides and modifiers. Actual probes demonstrate different control, height and pickup reach, but scoring superiority and human enjoyment remain unconfirmed. Power changes paddle/contact trajectories; a larger scalar does not imply a proportional increase in every shot's height.

**Current ring magnet:** Claim stationary rings immediately when their centers enter the swept magnetic radius around the ball. The provisional default is 50 physics pixels. Direct-contact collection still works with magnetism disabled, including high-speed sweeps. Score, ring total, and meter update once per ring per rack at claim time. `TablePresentation` then animates each collisionless ring toward the ball's current visible position with a provisional 0.20-second quadratic ease-in and a small final shrink. Claimed rings keep following outside the original radius. Pause freezes flight; drain/reset clears unfinished visuals without undoing rewards, rack reset restores them, and table regeneration discards the old presentation. Radius remains tunable through shared profiles/modifiers; the old attraction-speed stat is removed, and visual timing stays separate from character physics. Collection and animation never change ball movement. This does not introduce an electric-shield ability or Chao inventory.

**Confirmed long-term direction:** Chao are collectible upgrades offered between acts. Players choose one from a randomly presented selection. Chao should affect both scoring and gameplay physics, changing how players play rather than merely increasing score numbers.

Chao can reinforce a character's strengths, compensate for weaknesses, or enable unexpected builds. A floaty Cream build could gain stronger steering or more powerful flipper launches. Stacking rules, modifier ordering, and limits must remain predictable.

**Tentative future choices:** Expand to approximately 3–5 options drawn from a larger pool. Other Chao could alter combo rules or special abilities. Randomized offers, rarity, additional slot rules and balance beyond the prototype's two-copy/five-slot limits remain open.

Drafting is exclusive to the current Zone experiment; Free Play and standalone Score Attack retain the single-slot lab. Future Chao may modify character specials through the same established systems.

## Character specials

**Confirmed long-term direction:** Specials are relatively rare, player-activated, and charged through gameplay. They must use the established gameplay and scoring systems rather than unrelated bonus calculations.

**Tentative charging sources:** Rings, bonus targets, and combo milestones. Charge costs, carryover, and activation restrictions remain open.

All abilities and values below are concepts, not final balancing requirements:

| Character | Proposed special | Proposed bonus value |
| --- | --- | --- |
| Sonic | Homing Attack toward the nearest eligible bonus target | Approximately ×5 its normal bonus |
| Tails | Brief controllable flight for around 1–2 seconds, collecting bonus targets | Approximately ×3 |
| Knuckles | Horizontal glide toward a side wall or bumper, then a vertical shockwave that collects or activates eligible targets | Approximately ×2 |
| Shadow | Large-radius Chaos Blast that collects or activates many bonuses | Ordinary ×1 value |

Knuckles, Shadow and a separate Tails special scoring bonus remain concepts. Sonic, Tails and Scorecraft now have playable experiments; all numerical values remain provisional.

### Scorecraft v1 — implemented experiment, 2026-10-24

**Confirmed experiment:** One shared combo calculator consumes existing bumper/ring callbacks in every mode. A fresh bumper starts or advances a chain and arms one three-ring link; completing that ring sequence advances it again. Each advancing link refreshes a three-second window. Partial sequences and extra rings cannot refresh it. Another fresh bumper replaces any partial ring progress. The second link gives ×2; ×3 requires at least three links including a completed ring sequence. Fresh bumper-only chains stay at ×2. Each bumper can advance only once in the entire chain; repeated targets pay their original base points without refreshing or rearming anything. This prevents an A–B–A–B loop from sustaining a multiplier. Rack clears remain fixed at 500.

**Special interaction:** Sonic's actual-contact award is 100 times the eligible combo multiplier plus the original 400 special bonus. It finishes the chain, for at most 700 rather than multiplying 500 again. Unchained/repeated-target Homing remains 500. Tails and Chao affect which scoring opportunities the player can physically reach, without new scoring paths or meter multiplication.

**Lifecycle and comparison:** Pauses and Chao drafts freeze the timer. Expiration, drain, reset, character change, Act advancement and fresh runs clear active combos. Zone subtotals and cumulative score use the same awarded points; no combo carries into the next Act. A shared HUD shows links, multiplier, timer, next action and award breakdown. Switching combos off at serve/pause starts a clean same-seed baseline replay. Config values and presentation signals are documented in README. The numerical tuning and human enjoyment remain provisional; input-only surveys are evidence of behavior, not proof of skill balance.

### Character Lab v1 — implemented experiment

Character selection applies on Start / replay in Free Play, Score Attack or Green Hill Zone. Changing character restores its profile and clears meter and temporary ability state; ordinary same-character replay preserves debug tuning. Sandbox Chao remain compatible with either profile. New Zone runs retain the existing rule of an empty acquired build.

Sonic uses Balanced physics. Homing scans only existing bumper bodies in the active Act, within 400 px. A full-ball physics sweep must first encounter the candidate, excluding obstructed targets and all progression objects. Activation applies a gravity-compensated physical impulse aimed at 1,050 px/s, capped at a 2,600 px/s velocity change. The higher impulse cap overcame misses when opposing fast falls in the initial survey; it does not raise the aimed speed. Actual contact with the selected body within 0.65 seconds grants the equivalent of ×5 base points: 100 plus a 400-point bonus. Scorecraft multiplies only that base as described above. No teleport, remote hit, ring collection or additional scoring system is involved. Missed/blocked attempts receive no bonus or refund; no eligible target spends nothing.

Tails starts at 0.82 gravity, 2,400 steering acceleration, 4,400 counter-steering and a 135 px/s steering contribution limit. Tail Flight lasts 1.6 seconds: gravity ×0.25, steering acceleration ×1.6, counter-steering ×1.5 and steering limit ×1.4, all resolved and clamped alongside Chao. A single lift impulse removes up to 700 px/s of downward velocity, aiming no higher than 160 px/s upward. The final 0.35 seconds smoothly restore the normal modifiers. Flight never disables collisions or gates.

Both currently use a 100-point meter and full-meter cost, charged by ordinary rings (+5) and bumpers (+2) with the existing charge multiplier. Special hits still charge only the ordinary +2. Unused meter persists across Act drafts, checkpoint drains and ball resets; fresh runs and character changes start empty. Pause/drafts freeze flight duration. Drains/resets and final completion remove active temporary effects. Homing locks end at Act boundaries. Temporary modifiers use a keyed resolver slot, so repeated activation cannot stack or overwrite the permanent Chao build.

The HUD exposes character, pending choice, description, READY and ability feedback. Green Hill integrates ArtBro's collisionless Sonic homing/impact poses and Tails rotating-tail flight through the shared special lifecycle events. Separate blue/orange spin-balls support gameplay and missing local assets; prepared character models remain local and Git-ignored. The original physics playground retains its minimal target/flight markers and Tails placeholder. Presentation never advances ability time, changes motion or awards score. First charge arrived in roughly 19–25 simulated seconds on the seed-18 Zone survey. Same-seed input comparisons show different trajectories and scoring, not proof of subjective fun or final balance. Human judgment is still needed for homing timing, down-table target risk, flight generosity and controller feedback.

## Run progression

**Confirmed direction, updated 2026-10-23:** A Zone contains three Acts on one physically connected vertical playfield. Green Hill implements exactly three procedural chunks per Act, nine total, generated before play. This supersedes the earlier concept of loading each Act as a separate table. The world remains finite; streaming is unnecessary. The longer-term run visits additional Sonic-inspired Zones while preserving its build and cumulative score.

Within an act, the ball can move upward and downward between chunks. Falling into lower chunks is normal play. Flippers, springs, launchers, and other recovery mechanisms may appear throughout the level, supporting route exploration and recovery from missed shots.

Completing an Act requires its own score target followed by reaching its unlocked exit, then choosing a Chao. **Entered Acts are checkpoints:** after reaching Act 2, a drain respawns within Act 2 rather than returning to Act 1. The prototype uses unlimited retries and retains both score totals and rewards after drains. Future campaign failure conditions and persistence across application restarts remain undecided; no lives or game-over rules are implemented.

This supersedes the earlier preference to retain substantially the same table layout across all three acts. Acts can have distinct generated layouts while sharing a zone's visual identity and familiar gameplay elements.

**Future:** After Act 3, advance to another Zone while retaining the run build and total score. The current final portal instead offers the third Chao and a Green Hill completion summary with replay.

**Confirmed difficulty ownership:** Difficulty belongs to a Zone, not to individual Acts. Green Hill's three Acts all remain Easy. The longer-term proposal is Zone 1 Easy, Zone 2 Easy–Medium, Zone 3 Medium, Zone 4 Medium+, Zone 5 Medium–Hard, Zone 6 Hard and Zone 7 final Hard. Only Green Hill exists; later tier boundaries and layouts need playtesting.

**Tentative:** Later Zones may add objectives or hazards and higher score requirements, potentially with multiplicative growth. Tune these against achievable character and Chao combinations. Green Hill's provisional Act targets and reset rules are specified above; broader campaign length, failure rules and balance remain future work. Standalone Score Attack remains independent of this progression.

### Future possibility: branching routes

An open Act 1 could offer two exits leading to alternative Act 2 layouts with different geometry, difficulty, rewards, or gameplay opportunities. These can be separate generated levels connected by progression choices; they need not coexist in one enormous continuous physical world.

Keep future act selection flexible enough to represent alternative destinations without building branching infrastructure now. Branches are optional future design, not mandatory for the first campaign version or the current sandbox.

## Modular levels and procedural generation

**Confirmed long-term direction:** Assemble tables from hand-tested, reusable gameplay chunks. Prefer spacious, interesting vertical pinball sections over small arbitrary shapes. Chunks contain walls, rails, bumpers, launchers, collectible routes, and other pinball elements.

Each chunk describes invisible collision geometry and gameplay data independently of its visual theme. Gameplay objects and scenery derive their placements from the same layout data.

Connection and transformation constraints:

- Use grid-based connection regions. Compatible openings may connect at different valid offsets; do not require rigid exact-match connector IDs.
- Chunks may be shifted horizontally or mirrored horizontally. **Rotations are not allowed.**
- Preserve continuous collision boundaries and avoid trapped balls, unreachable routes, and disconnected sections.

### Connector geometry and difficulty

**Confirmed direction:** Do not automatically turn every connector into a smooth slope. Intentional corners and protruding ledges are valid gameplay features. Distinguish deliberately difficult geometry from technically broken geometry: unintended traps, collider gaps, and impassable connections are not acceptable.

**Confirmed difficulty identities:** Easy is open and forgiving. Normal emphasizes momentum, aligned connections, angled banks and faceted curves. Hard emphasizes precision, difficult approaches, tight connectors and deliberate hazards. Intentional corners within authored Normal chunks remain welcome, but abrupt overhanging closure shoulders are no longer a standard Normal junction feature. If shaping cannot produce a valid flowing join, try another compatible candidate rather than accepting a stepped ceiling. Ordinary banks remain passive rail geometry: no new impulse, velocity override or powered-spring behavior. Change adjoining rail boundaries and their navigable outlines together, preserve exact collider/mesh alignment, and rerun collision validation and geometric estimation. Leave Easy/Hard geometry intact unless a separate technical defect requires correction.

**Implemented Normal flow pass (generator v8):** This supersedes v5's occasional stepped preference and fallback. Seeds prefer straight banks or faceted curves equally; both joins must be aligned or shaped, with every generated facet steeper than 53 degrees above horizontal. Selection tries both styles per candidate, then other candidates, and rates the finished geometry. Generated seam X coordinates round to the shared 5-pixel connector grid without moving authored pieces. Bank-to-paddle clearance accommodates a complete ball throughout the sampled swing. An unavailable Normal tier explicitly reports a flowing alternative; even the emergency fallback is aligned. Difficulty also considers actual bank inclination, using the maximum component rather than averaging. These are tunable geometry heuristics, not guarantees about every incoming trajectory. Existing chunk resources, Easy/Hard selection and physics behavior remain intact.

**Confirmed grid Easy refinement (generator v9):** Playtesting identified large shoulders only in the optional grid modes; Existing catalogue is satisfactory and remains unchanged. Grid base and Grid variant now select dedicated full-width recipes for Easy, with broad openings, gentler banks and wider recovery space. Normal/Hard retain the original grid designs. Easy must match its tier through actual geometry rather than silently presenting the previous Normal fallback or lowering authored ratings. The current Easy recipes retain their 28-point authored rating and pass the unchanged validator and estimator.

**Tentative difficulty examples:** Wide aligned openings may be easier; gentle slopes may offer moderate challenge; longer or more complex slopes may be harder. Sharp corners and ledges may be challenging, while large corners combined with narrow openings may be very difficult. These are hypotheses, not fixed rankings. Actual challenge depends on approach direction, ball velocity, geometry, character physics, and other factors.

**Implemented experiment:** Difficulty preferences favor distinct geometry: wide aligned Easy sections, flowing Normal banks and target routes, and Hard tapered or offset necks with large closure shoulders. Estimated difficulty stays separate from technical validity; a harder preference never admits broken connections. A controlled real-flipper survey reports upward access and optional diagnostic target hits without affecting selection, scoring or progression. Static estimates and sampled trajectories are evidence for playtesting, not guarantees about every shot or character profile.

Horizontal shifts, mirroring, and flexible grid-based connection regions remain required. Rotations remain disallowed. Additional connector types and difficulty models should follow playtesting rather than an elaborate framework.
- Preserve intentional, reasonably traversable corners, ledges, sharp turns, and tighter passages as possible difficulty features. Distinguish them from collider gaps, unintended traps, and unreachable connections; do not automatically replace every corner with a ramp.

**Confirmed layout goal:** Chunks offer around 2–3 broad gameplay lanes. Phase 2A uses 100-pixel placement cells, overlapping connector spans, and coarse static clearance plus selected physics simulations. Exact widths and validation thresholds remain provisional tuning choices.

**Tentative difficulty interpretation:** Straight/wide, smooth-offset, extended-slope, pronounced-corner, and tight/sharp connections may offer different challenges. Shape alone does not determine their ranking: incoming velocity, upward traversal, gravity, character physics, clearance, and nearby obstacles matter. All three tiers now have matching catalogue geometry; future transition types still need calibration. Controlled Balanced shots reached the upper targets in all eight Hard transformations, less frequently than representative Easy/Normal upper sections. Easy/Normal initial-shot results overlap; human playtesting must judge recovery and overall challenge. These survey results describe standalone geometry, not Zone progression balance.

**Confirmed theme separation:** Themes skin the same gameplay geometry. Green Hill could use checkerboard cliffs, grass, palms, sunflowers, and distant scenery; Chemical Plant could use industrial geometry, pipes, and machinery. These are visual examples, not Phase 1 asset requirements.

**Future possibilities:** True vertical loops and multi-height tracks may need guided movement modules. They are unnecessary for the first prototype.

Free Play and standalone Score Attack use one generated middle and one generated top above the launch deck, connected by two junctions. Green Hill Zone uses seven open intermediate chunks between its deck and final cap, connected by eight junctions. Arbitrary-height streaming and guided loops remain future work; presentation attachments remain collisionless.

## Lightweight verification and playtesting

The user performs subjective gameplay testing. Automated checks should protect deterministic rules and regression-prone systems without becoming a separate infrastructure project.

As relevant systems are implemented, add a handful of simple regression checks covering:

- Profile resolution: expected defaults and resolved values without mutating shared profile data.
- Modifier stacking: agreed ordering and limits, including repeatable results for the same inputs.
- Reset behavior: remove the intended temporary or run modifiers and restore the appropriate baseline without stale effects.
- Scoring: expected awards and modifier application through the shared scoring path, once scoring exists.

Use Godot's available headless checks for script parsing, project startup, and scene loading/validation. Run the game when possible and inspect its output through Godot MCP or local tools. Report commands/checks actually executed and their results; headless success does not establish gameplay quality.

Avoid substantial test dependencies and custom testing frameworks for the sandbox.

### Phase 1 verification history — 2026-10-22

- Document presence, internal design link, and key scope/approval constraints were checked.
- Godot MCP project inspection and installed-version discovery completed.
- `godot --headless --path . --script tests/profile_regression.gd`: eight checks passed, zero failures. Coverage includes defaults, override/stacking order, modifier permutation, clamping, shared-resource preservation, profile-switch reset behavior, modifier persistence, and restoration of Balanced defaults.
- `godot --headless --path . --editor --quit`: ran, but reported missing `scripts/game.gd` and an editor debugger-plugin error.
- `godot --headless --path . --quit-after 2`: ran, but reported the missing scene script and a scene parse error. Godot returned exit code 0 despite these errors; this is not a successful startup check.
- Godot MCP graphical launch and output inspection reproduced the missing-script/scene errors; the launched process was stopped. No playable session or subjective gameplay validation was completed.

Run a headless editor import before the standalone regression script so Godot discovers global script classes. On this machine the executable is `C:\Program Files\Godot\Godot.exe`; the commands above use `godot` as shorthand. Recheck startup and manual playtesting once the ongoing prototype supplies its main scene script. Scoring tests should be added when a scoring implementation exists.

Subsequent prototype verification on the same date supersedes the startup failures above: headless import/startup succeeded, MCP launched the complete table with an empty errors array, and 38 physics regression checks passed. Those checks include scoring events, both flippers, high-speed collisions, steering momentum, profile differences, chunk crossings, pause, and respawn. Native CCD misses at high speeds were repaired with a conservative 2D shape sweep; it can rebound one physics tick early. Final-build visual and controller feel checks remain manual because Computer Use was stopped with Escape. See `VERIFICATION.md` for evidence and limitations.

Phase 2A adds 39 generation checks and 17 graphical generation-UI checks, all passing, and reruns the 38 physics, 12 steering, eight profile, and four headless steering-UI checks. Four sample layouts and transformed overlays were rendered and visually inspected. This supersedes the earlier lack of final rendered inspection; subjective feel and physical controller checks remain manual. Full results and limits are in [Verification](VERIFICATION.md).

### Short manual checklist for the playable prototype

- Do both flippers respond reliably, with readable launch timing?
- Does limited steering feel useful without overpowering pinball motion?
- Are Balanced and Floaty distinct and enjoyable under comparable shots?
- Do walls and bumpers behave sensibly, without trapping or losing the ball unexpectedly?
- Are collectibles readable and collectible along intended routes?
- Does the camera make the table and ball easy to track?
- Does the 3D presentation follow the physical ball without changing collisions?
- Do debug tuning and resets apply the expected values?

Manual feel, camera readability, flipper timing, and visual polish are outside unit-test scope. Keep playtest notes brief and actionable.

## Open decisions and change discipline

Near-term decisions include physics tuning, connector difficulty calibration and follow-camera readability with primitive geometry. Tilt, field of view, look-ahead and rebound stability need playtesting. Existing steering and modifier behavior is documented above; further changes should follow observed gameplay needs.

Near-term Zone playtesting should judge gate returns, final-climb timing, checkpoint fairness, three-Act duration and whether draft choices change how the same seed feels. Prototype targets and duplicate-pick effects remain tunable. Later decisions include larger/randomized Chao pools, campaign scoring and combos, special charging and target eligibility, lives/retries/run failure, checkpoint persistence across restarts, later Zones, optional branching exits, Android support and Arcade Mode.

Keep tentative values labeled until validated. Record implementation differences here when they arise, with their impact and a proposed next step. Do not interrupt the current phase or refactor unrelated code merely to satisfy a future design concept.
