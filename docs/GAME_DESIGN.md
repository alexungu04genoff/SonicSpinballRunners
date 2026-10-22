# Sonic Spinball Runners — Living Game Design

## Status and use

This document records the project's intended direction, not a claim that its systems already exist. Consult it before major gameplay or architectural changes. Update it as decisions are agreed and playtesting provides evidence.

- **Confirmed direction:** agreed design goals and constraints. These may belong to a later phase rather than the current prototype.
- **Tentative:** proposed mechanics, examples, and balancing values that need validation.
- **Future:** explicitly outside the current phase; not a commitment to implement now.
- **Implemented:** behavior observed in repository source or documented verification. This is distinct from proposed experiments and does not imply new testing during a documentation update.

### Current design and implementation snapshot — 2026-10-22

The current product is an endlessly replayable physics sandbox with deliberately simple, blocky N64-style visuals. Current exploration covers physics/flippers/steering, profiles and modifiers, seeded chunks, connector compatibility and estimated difficulty, and primitive 3D geometry, perspective, shadows, and depth perception. It does not include acts, zones, branching progression, win conditions, finished Sonic characters, or elaborate environment artwork.

The repository contains the **Vertical Traversal Playground**: a seeded three-section course with reusable dual-connector middle chunks, two pairs of flippers, reproducible difficulty preferences, a following perspective camera and fixed overview. Shared physics profiles/modifiers, scoring, swept ring collection with cosmetic flight, automatic bottom respawn and live tuning remain intact. Generator validation and regression results are documented in `VERIFICATION.md`; subjective difficulty remains a playtesting question.

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

## Current scope: Vertical Traversal Playground

**Confirmed playground scope:** Generate three connected sections: the familiar bottom launch deck, a reusable middle with top/bottom openings and recovery flippers, and a capped upper section. Follow the ball upward, horizontally and back down. Falling between chunks is normal gameplay; a drain always returns to the bottom, with no checkpoint. This remains an endlessly replayable physics sandbox, not an infinitely tall world. No acts, zones, branching progression, win conditions, limited lives, bosses or complete roguelite progression. Primitive N64-style visuals are sufficient; progression ideas below remain long-term direction only.

**Completed foundation:** The Physics Playground supplies:

- An invisible 2D physics ball, two flippers, bumpers, walls, and basic collectibles.
- A tilted 3D presentation independent of physical collisions.
- Configurable physics with Balanced and Floaty test profiles.
- A debug tuning panel for rapid experimentation.

**Implemented traversal scope:** Preserve the launch deck's geometry, flippers, drain and serve relative to its footprint. Choose among eight capped top sections and three dual-connector middle sections. Open Relay and Bank Relay offer broad routes; Rebound Relay adds asymmetric positioning. Resource-defined middle flippers use the existing left/right actions simultaneously with the bottom pair. No rotations, runtime streaming or arbitrary-height UI is introduced.

**Implemented drain/recovery refinement (generator v6):** Playtesting and real physics drops confirmed that the original 150 px bottom paddles blocked the 28 px ball with a 19.23 px resting gap. They now use 130 px lengths at the same pivots, opening a 57.20 px resting gap and at least 44 px through the swing. Middle placements vary: side recovery in Open Relay, staggered recovery in Bank Relay and a shorter traditional pair in Rebound Relay. This deliberately supersedes preservation of the original flipper geometry above; rails, bumpers, rings, connectors, serve and drain remain unchanged. Per-placement length drives collision, presentation and leverage consistently. Shared input, physics profiles, steering, angular speeds and strike formulas remain intact. Unlimited automatic retries continue; no lives limit or game-over state is introduced.

**Playtesting limit:** A raised bottom flipper can cradle the ball at its pivot against the incoming wall; releasing it frees the ball. Genuine missed shots must drain, and resting tip gaps must not form an unintended stable cradle. Lengths and arrangements remain provisional. Existing static difficulty estimates do not yet account for recovery timing or paddle coverage.

**Implemented construction experiment (generator v7, kit v1):** Author reusable construction pieces on a 50 px grid, then compile them into the existing geometry/object descriptors. A Resource-authored middle chunk and a two-placement variant are opt-in in Table Generator; legacy chunks remain the default. Multi-cell banks, slopes, corners, straight rails, grid-anchored bumpers/rings and staggered flippers share physical clearance validation. Ball motion remains continuous, the 100 px whole-chunk placement grid is unchanged, and no unrestricted random tile generation is added. Chunk mirroring/shifting remains supported; rotations remain disallowed. A source-grid overlay exposes coordinates and footprints, while the physics overlay shows final geometry after connector shaping. Built-in TileMap editing was investigated; a Resource-first compiler avoids a second layout authority and can accept an editor adapter later. See [Grid authoring](GRID_AUTHORING.md) for limits and workflow.

**Implemented baseline choices:** Top/middle footprints are 7 × 7 or 8 × 7 cells, the bottom is 8 × 7, and cells are 100 physics pixels. Ordered sections occupy rows 0, 7 and 14; two adjacent junctions connect the current 800 × 2100 course. Full-width sections stay aligned; narrower sections retain both shifts and mirroring. Regeneration requires pause or serve, resets counters/rings/timers/ball/camera state, and preserves tuning, camera mode/settings, overlays and pause. Its fallback also has three sections. See [Generation contract](GENERATION.md) for version-specific rules and validation limits. Generator v4 changes seed mappings; v3 remains a regression fixture.

**Difficulty-aware experimentation:** Generator v4 retains the v3 maximum-of-components formula across all sections and junctions. Intrinsic chunk challenge, connector widths/offsets/ledges and sampled approach clearance/turns/obstacles remain distinct from validity. A challenging join cannot be diluted by averaging. Select a valid course within the requested tier in seeded order; report a shortage explicitly before using the closest valid alternative. Difficulty never relaxes collision validation or changes character physics.

**Provisional tuning:** User playtesting selected Quick / Tight for both Balanced and Floaty: strength 0.10, normal acceleration 2200, counter deceleration 4000, contribution limit 120, and release deceleration 3000. Original, Air control, and Stronger brake remain selectable. Phase 2A does not change steering/release semantics.

Complete characters, specials, Chao drafting, themed artwork, Android controls, and three-act progression remain outside this milestone. The full vision below guides future compatibility without requiring those systems now. Avoid unrelated refactors.

## Presentation and camera

**Confirmed direction:** View the vertical playfield as if standing in front of a real pinball machine, through a moderately tilted **perspective camera**. The bottom appears larger and closer; the top recedes and appears slightly narrower. Think of a much less extreme Temple Run-style perspective combined with Sonic Mania's pinball gameplay. This supersedes the earlier orthographic design preference. The eventual colorful, relatively simple Sonic Runners-inspired presentation remains compatible with today's blocky sandbox visuals.

**Implemented camera experiment:** Follow the ball vertically through the current sandbox, gently adjust horizontally, and provide upward look-ahead. A tunable dead zone, separate response rates and speed cap soften rebounds. Upper/lower bounds prevent following beyond the course. Rotation stays fixed during movement. A debug toggle selects the fixed overview; pause freezes tracking and reset reframes the bottom.

**Tentative tuning:** Follow defaults are a 100-pixel vertical dead zone, 100-pixel upward lead, 5/s vertical response, 2/s horizontal response and 1800 px/s speed cap. Horizontal target movement is 18% of the ball's offset from course center, capped at 55 pixels. Follow framing covers a local 1100-pixel window; view distance is derived from projection/aspect and the object-height envelope. These are playtesting values, not final camera behavior.

**Implemented depth experiment:** Top-down reference uses orthographic projection. Real Pinball uses a 60° elevation above the board and 40° vertical FOV; Dramatic uses 50° and 52°. Each preset supports following and full-course overview. Geometry footprints remain derived from 2D descriptors, including mirrored triangles and closure rails. The ball remains a sphere. Heights and camera settings are provisional; human playtesting must judge visibility, distant-lane readability and rebound tracking.

An invisible 2D physics ball owns collisions and gameplay movement. A collisionless 3D character model follows its position and animates independently. The physical ball continues moving during every visible animation. Character models, themed scenery, and animation timing never determine physical collision geometry.

**Tentative presentation plan:** Three principal character states:

1. Rolling or spinning during ordinary ball movement.
2. A jump animation following flipper launches.
3. Brief signature poses following exciting bumper impacts or other physics events.

Exact camera tuning, presentation mapping, animation timing, and transition rules remain open. Complete character animation is outside the current sandbox scope.

## Characters and physics

**Confirmed direction:** Playable characters have different starting physics profiles. Each may also have a passive ability and a rarer player-activated special. The first prototype needs only Balanced and Floaty test profiles, not finished characters.

**Tentative character examples:** Sonic is relatively fast and balanced; Cream is floatier with slower descent; Knuckles is heavier and more forceful. These are intended feels, not fixed numerical specifications.

Configurable physics should cover steering acceleration, steering deceleration, steering responsiveness, maximum steering contribution, gravity, downward speed limits, rolling behavior, flipper launch power, wall and bumper recoil, ring magnetism, and related properties as needed.

**Confirmed architecture:** A centralized stats system resolves character defaults, Chao upgrades, temporary effects, and game-mode rules. Use shared profiles and modifiers rather than scattered hard-coded character checks. Introduce only the pieces needed by implemented features. Modifier stacking, ordering, limits, and reset behavior must be predictable. The sandbox's additive-then-multiplicative resolver is implemented; future Chao limits and campaign reset rules remain undecided.

## Controls and steering

**Confirmed Windows mappings:**

| Action | Controller | Keyboard fallback |
| --- | --- | --- |
| Left / right flipper | LB / RB | Q / E |
| Limited lateral steering | Left analog stick | Left / right arrows |
| Character special, when implemented | A | Space |

Steering should resemble slight air control in traditional Sonic games. It should not provide full character movement. Responsiveness, acceleration, deceleration, and maximum contribution must be independently configurable.

**Tentative tuning:** Approximately 5–8% steering influence was the initial calibration idea; Original retains `steering_strength = 0.065`. Both test profiles now use Quick / Tight at 0.10. Strength scales acceleration/deceleration toward a separately capped steering contribution, not a measured percentage of total ball motion. Do not treat the original percentage as an acceptance threshold.

**Steering investigation:** Playtesting found weak response against existing lateral momentum. The implementation was applying counteracting impulses, but the original 65 px/s² rate and 120 px/s contribution cap limited their effect. Steering was not disabled on descent. An independent counter-steering deceleration setting and comparison presets were added; subsequent playtesting selected Quick / Tight as the Phase 2A provisional default. Counter-steering remains bounded assistance, and release unwinds that assistance rather than permanently dissipating external momentum. Collision bookkeeping resets remain unchanged. See [the steering investigation](STEERING_INVESTIGATION.md) for the exact trace, telemetry, and comparisons.

**Future Android plan:** A virtual analog stick on the left, with two flipper buttons and a special button on the right.

**Future possibility:** A separate Arcade Mode could allow nearly complete movement control for a relaxed, chaotic experience. It is outside the first prototype.

## Chao and build crafting

**Current ring magnet:** Claim stationary rings immediately when their centers enter the swept magnetic radius around the ball. The provisional default is 50 physics pixels. Direct-contact collection still works with magnetism disabled, including high-speed sweeps. Score, ring total, and meter update once per ring per rack at claim time. `TablePresentation` then animates each collisionless ring toward the ball's current visible position with a provisional 0.20-second quadratic ease-in and a small final shrink. Claimed rings keep following outside the original radius. Pause freezes flight; drain/reset clears unfinished visuals without undoing rewards, rack reset restores them, and table regeneration discards the old presentation. Radius remains tunable through shared profiles/modifiers; the old attraction-speed stat is removed, and visual timing stays separate from character physics. Collection and animation never change ball movement. This does not introduce an electric-shield ability or Chao inventory.

**Confirmed long-term direction:** Chao are collectible upgrades offered between acts. Players choose one from a randomly presented selection. Chao should affect both scoring and gameplay physics, changing how players play rather than merely increasing score numbers.

Chao can reinforce a character's strengths, compensate for weaknesses, or enable unexpected builds. A floaty Cream build could gain stronger steering or more powerful flipper launches. Stacking rules, modifier ordering, and limits must remain predictable.

**Tentative choices and examples:** Offer approximately 3–5 options per draft. Ice Chao could affect steering and drifting; Spring Chao could boost flipper launches; Magnet Chao could attract rings. Other Chao could alter combo rules or special abilities. Exact effects, rarity, stacking caps, and draft timing details remain open.

Chao drafting is outside the current sandbox scope. Future Chao may modify character specials through the same established systems.

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

Target eligibility, effect ranges, interaction with combos, and special-specific movement rules need design and playtesting. Specials are outside the current sandbox scope.

## Run progression

**Confirmed long-term direction:** A roguelite run visits randomly selected Sonic-inspired zones, each with three acts. Each act is a self-contained generated pinball level made from approximately **2–3 vertically connected procedural chunks**. It is not a segment of one infinitely tall tower. The approximate chunk count is a design target, not a fixed generator requirement.

Within an act, the ball can move upward and downward between chunks. Falling into lower chunks is normal play. Flippers, springs, launchers, and other recovery mechanisms may appear throughout the level, supporting route exploration and recovery from missed shots.

Completing an act advances the player to the next act. **Completed acts effectively become checkpoints:** after reaching Act 2, a drain respawns the player within Act 2 rather than returning them to Act 1. Avoid Jump King-style punishment that sends players back through previously completed acts. Exact lives, retry budgets, run-failure conditions, and checkpoint persistence across restarts remain undecided; this checkpoint direction does not imply unlimited campaign retries or saved progress.

This supersedes the earlier preference to retain substantially the same table layout across all three acts. Acts can have distinct generated layouts while sharing a zone's visual identity and familiar gameplay elements.

After Act 3, players advance to another zone while retaining their run build.

**Tentative:** Acts may add objectives or hazards. Score requirements may grow multiplicatively, but tuning must account for achievable character and Chao combinations. Exact thresholds, run length, failure conditions, and between-act reset rules remain open.

Increasing score requirements remain the intended campaign direction; exact completion/win rules are future design work, not sandbox functionality.

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

**Tentative difficulty examples:** Wide aligned openings may be easier; gentle slopes may offer moderate challenge; longer or more complex slopes may be harder. Sharp corners and ledges may be challenging, while large corners combined with narrow openings may be very difficult. These are hypotheses, not fixed rankings. Actual challenge depends on approach direction, ball velocity, geometry, character physics, and other factors.

**Implemented experiment:** Difficulty preferences favor distinct geometry: wide aligned Easy sections, flowing Normal banks and target routes, and Hard tapered or offset necks with large closure shoulders. Estimated difficulty stays separate from technical validity; a harder preference never admits broken connections. A controlled real-flipper survey reports upward access and optional diagnostic target hits without affecting selection, scoring or progression. Static estimates and sampled trajectories are evidence for playtesting, not guarantees about every shot or character profile.

Horizontal shifts, mirroring, and flexible grid-based connection regions remain required. Rotations remain disallowed. Additional connector types and difficulty models should follow playtesting rather than an elaborate framework.
- Preserve intentional, reasonably traversable corners, ledges, sharp turns, and tighter passages as possible difficulty features. Distinguish them from collider gaps, unintended traps, and unreachable connections; do not automatically replace every corner with a ramp.

**Confirmed layout goal:** Chunks offer around 2–3 broad gameplay lanes. Phase 2A uses 100-pixel placement cells, overlapping connector spans, and coarse static clearance plus selected physics simulations. Exact widths and validation thresholds remain provisional tuning choices.

**Tentative difficulty interpretation:** Straight/wide, smooth-offset, extended-slope, pronounced-corner, and tight/sharp connections may offer different challenges. Shape alone does not determine their ranking: incoming velocity, upward traversal, gravity, character physics, clearance, and nearby obstacles matter. All three tiers now have matching catalogue geometry; future transition types still need calibration. Controlled Balanced shots reached the upper targets in all eight Hard transformations, less frequently than representative Easy/Normal upper sections. Easy/Normal initial-shot results overlap; human playtesting must judge recovery and overall challenge. No acts or progression are introduced.

**Confirmed theme separation:** Themes skin the same gameplay geometry. Green Hill could use checkerboard cliffs, grass, palms, sunflowers, and distant scenery; Chemical Plant could use industrial geometry, pipes, and machinery. These are visual examples, not Phase 1 asset requirements.

**Future possibilities:** True vertical loops and multi-height tracks may need guided movement modules. They are unnecessary for the first prototype.

Vertical traversal implements one generated middle and one generated top above the launch deck, using two junctions. Arbitrary heights, runtime streaming, guided loops and themed attachments remain future work.

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

Later decisions include Chao drafting and stacking limits, campaign scoring and combos, special charging and target eligibility, act completion thresholds, lives/retries/run failure, checkpoint persistence, optional branching exits and rewards, validation for larger procedural acts, Android support, and Arcade Mode.

Keep tentative values labeled until validated. Record implementation differences here when they arise, with their impact and a proposed next step. Do not interrupt the current phase or refactor unrelated code merely to satisfy a future design concept.
