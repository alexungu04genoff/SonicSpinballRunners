# Sonic Spinball Runners — Living Game Design

## Status and use

This document records the project's intended direction, not a claim that its systems already exist. Consult it before major gameplay or architectural changes. Update it as decisions are agreed and playtesting provides evidence.

- **Confirmed direction:** agreed design goals and constraints. These may belong to a later phase rather than the current prototype.
- **Tentative:** proposed mechanics, examples, and balancing values that need validation.
- **Future:** explicitly outside the current phase; not a commitment to implement now.

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

Completion update: the missing script was supplied by the prototype implementation. The earlier missing-script finding below is historical and resolved. See `../README.md` for the runtime architecture, controls, current tuning interpretation, and modifier rules, and `VERIFICATION.md` for the completed physics checks and manual-test limits. The current runtime mapping is `(x, y) -> ((x - 400) * 0.01, visual_height, (y - 700) * 0.01)`. These are provisional implementation choices, not final art or balance decisions.

## Vision

**Confirmed direction:** A Sonic-themed, physics-driven pinball roguelite combining Sonic Spinball's pinball gameplay, colorful presentation inspired by Sonic Runners and Sonic Mania, and Balatro's build-crafting philosophy.

The game should be accessible and immediately fun while supporting deep combinations of character physics, passive abilities, collectible Chao, scoring modifiers, and character-specific specials. Windows is the initial platform; Android is a potential later target. Development uses Godot 4 and GDScript.

## Current scope: Phase 2A — Modular Chunk Generation

**Completed foundation:** The Physics Playground supplies:

- An invisible 2D physics ball, two flippers, bumpers, walls, and basic collectibles.
- A tilted 3D presentation independent of physical collisions.
- Configurable physics with Balanced and Floaty test profiles.
- A debug tuning panel for rapid experimentation.

**Confirmed Phase 2A scope:** Preserve that foundation and the fixed lower deck, flippers, drain, and serve. Choose among four spacious, hand-authored upper sections using a reproducible seed, optional horizontal mirroring, and compatible grid shifts. Transform connectors into world coordinates, validate their shared opening and static route clearance, and visibly close unused spans. Provide safe regeneration and layout diagnostics in the debug UI. No rotations, arbitrary table height, or endless scrolling.

**Implemented choices:** Upper footprints are 7 × 7 cells, the lower deck is 8 × 7, and each cell is 100 physics pixels. The generator tries 16 upper/mirror/shift combinations, then validates the original table as fallback. Regeneration requires pause or serve and clears playground counters, rings, timers, and ball state while retaining tuning and pause state. See [Generation contract](GENERATION.md) for connector rules, sample seeds, validation limits, and expansion concerns.

**Provisional tuning:** User playtesting selected Quick / Tight for both Balanced and Floaty: strength 0.10, normal acceleration 2200, counter deceleration 4000, contribution limit 120, and release deceleration 3000. Original, Air control, and Stronger brake remain selectable. Phase 2A does not change steering/release semantics.

Complete characters, specials, Chao drafting, themed artwork, Android controls, and three-act progression remain outside this milestone. The full vision below guides future compatibility without requiring those systems now. Avoid unrelated refactors.

## Presentation and camera

**Confirmed direction:** The playfield is vertically oriented and viewed through a slightly angled orthographic camera, similar to Sonic Mania's pinball bonus stage. Stylized, colorful, relatively simple 3D should evoke Sonic Runners, with Sonic Mania-like pinball environments.

An invisible 2D physics ball owns collisions and gameplay movement. A collisionless 3D character model follows its position and animates independently. The physical ball continues moving during every visible animation. Character models, themed scenery, and animation timing never determine physical collision geometry.

**Tentative presentation plan:** Three principal character states:

1. Rolling or spinning during ordinary ball movement.
2. A jump animation following flipper launches.
3. Brief signature poses following exciting bumper impacts or other physics events.

Exact camera angle, mapping from physics coordinates to the 3D presentation, animation timing, and transition rules remain open. Complete character animation is not required for Phase 1.

## Characters and physics

**Confirmed direction:** Playable characters have different starting physics profiles. Each may also have a passive ability and a rarer player-activated special. The first prototype needs only Balanced and Floaty test profiles, not finished characters.

**Tentative character examples:** Sonic is relatively fast and balanced; Cream is floatier with slower descent; Knuckles is heavier and more forceful. These are intended feels, not fixed numerical specifications.

Configurable physics should cover steering acceleration, steering deceleration, steering responsiveness, maximum steering contribution, gravity, downward speed limits, rolling behavior, flipper launch power, wall and bumper recoil, ring magnetism, and related properties as needed.

**Confirmed architecture:** A centralized stats system resolves character defaults, Chao upgrades, temporary effects, and game-mode rules. Use shared profiles and modifiers rather than scattered hard-coded character checks. Introduce only the pieces needed by implemented features. Modifier stacking, ordering, limits, and reset behavior must be predictable; their exact formulas remain undecided.

## Controls and steering

**Confirmed Windows mappings:**

| Action | Controller | Keyboard fallback |
| --- | --- | --- |
| Left / right flipper | LB / RB | Q / E |
| Limited lateral steering | Left analog stick | Left / right arrows |
| Character special, when implemented | A | Space |

Steering should resemble slight air control in traditional Sonic games. It should not provide full character movement. Responsiveness, acceleration, deceleration, and maximum contribution must be independently configurable.

**Tentative tuning:** Approximately 5–8% steering influence is a starting idea for calibration and playtesting. Current code uses `steering_strength = 0.065` to scale acceleration/deceleration toward a separately capped steering contribution. This is not a measured percentage of total ball motion. Whether that interpretation achieves the desired feel remains open; do not treat the percentage as an acceptance threshold.

**Steering investigation:** Playtesting found weak response against existing lateral momentum. The implementation was applying counteracting impulses, but the original 65 px/s² rate and 120 px/s contribution cap limited their effect. Steering was not disabled on descent. An independent counter-steering deceleration setting and comparison presets were added; subsequent playtesting selected Quick / Tight as the Phase 2A provisional default. Counter-steering remains bounded assistance, and release unwinds that assistance rather than permanently dissipating external momentum. Collision bookkeeping resets remain unchanged. See [the steering investigation](STEERING_INVESTIGATION.md) for the exact trace, telemetry, and comparisons.

**Future Android plan:** A virtual analog stick on the left, with two flipper buttons and a special button on the right.

**Future possibility:** A separate Arcade Mode could allow nearly complete movement control for a relaxed, chaotic experience. It is outside the first prototype.

## Chao and build crafting

**Confirmed long-term direction:** Chao are collectible upgrades offered between acts. Players choose one from a randomly presented selection. Chao should affect both scoring and gameplay physics, changing how players play rather than merely increasing score numbers.

Chao can reinforce a character's strengths, compensate for weaknesses, or enable unexpected builds. A floaty Cream build could gain stronger steering or more powerful flipper launches. Stacking rules, modifier ordering, and limits must remain predictable.

**Tentative choices and examples:** Offer approximately 3–5 options per draft. Ice Chao could affect steering and drifting; Spring Chao could boost flipper launches; Magnet Chao could attract rings. Other Chao could alter combo rules or special abilities. Exact effects, rarity, stacking caps, and draft timing details remain open.

Chao drafting is outside Phase 1. Future Chao may modify character specials through the same established systems.

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

Target eligibility, effect ranges, interaction with combos, and special-specific movement rules need design and playtesting. Specials are outside Phase 1.

## Run progression

**Confirmed long-term direction:** A run consists of randomly selected Sonic-inspired zones, each with three acts. Acts have increasing score requirements. The core table layout should generally remain recognizable across a zone's three acts so players can learn shots and refine strategy while acquiring Chao.

After Act 3, players advance to another zone while retaining their run build.

**Tentative:** Acts may add objectives or hazards. Score requirements may grow multiplicatively, but tuning must account for achievable character and Chao combinations. Exact thresholds, run length, failure conditions, and between-act reset rules remain open.

## Modular levels and procedural generation

**Confirmed long-term direction:** Assemble tables from hand-tested, reusable gameplay chunks. Prefer spacious, interesting vertical pinball sections over small arbitrary shapes. Chunks contain walls, rails, bumpers, launchers, collectible routes, and other pinball elements.

Each chunk describes invisible collision geometry and gameplay data independently of its visual theme. Gameplay objects and scenery derive their placements from the same layout data.

Connection and transformation constraints:

- Use grid-based connection regions. Compatible openings may connect at different valid offsets; do not require rigid exact-match connector IDs.
- Chunks may be shifted horizontally or mirrored horizontally. **Rotations are not allowed.**
- Preserve continuous collision boundaries and avoid trapped balls, unreachable routes, and disconnected sections.

**Confirmed layout goal:** Chunks offer around 2–3 broad gameplay lanes. Phase 2A uses 100-pixel placement cells, overlapping connector spans, and coarse static clearance plus selected physics simulations. Exact widths and validation thresholds remain provisional tuning choices.

**Confirmed theme separation:** Themes skin the same gameplay geometry. Green Hill could use checkerboard cliffs, grass, palms, sunflowers, and distant scenery; Chemical Plant could use industrial geometry, pipes, and machinery. These are visual examples, not Phase 1 asset requirements.

**Future possibilities:** True vertical loops and multi-height tracks may need guided movement modules. They are unnecessary for the first prototype.

Phase 2A implements seeded selection of one upper section above the fixed lower deck. Multi-junction layouts, arbitrary heights, guided loops, and themed attachments remain future work.

## Lightweight verification and playtesting

The user performs subjective gameplay testing. Automated checks should protect deterministic rules and regression-prone systems without becoming a separate infrastructure project.

As relevant systems are implemented, add a handful of simple regression checks covering:

- Profile resolution: expected defaults and resolved values without mutating shared profile data.
- Modifier stacking: agreed ordering and limits, including repeatable results for the same inputs.
- Reset behavior: remove the intended temporary or run modifiers and restore the appropriate baseline without stale effects.
- Scoring: expected awards and modifier application through the shared scoring path, once scoring exists.

Use Godot's available headless checks for script parsing, project startup, and scene loading/validation. Run the game when possible and inspect its output through Godot MCP or local tools. Report commands/checks actually executed and their results; headless success does not establish gameplay quality.

Avoid substantial test dependencies and custom testing frameworks for Phase 1.

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

Near-term decisions are physics values for Balanced/Floaty, the meaning and calibration of steering influence, camera/presentation mapping, and modifier resolution/reset rules as needed by the playground.

Later decisions include Chao drafting and stacking limits, scoring and combo formulas, special charging and target eligibility, progression thresholds and failure rules, validation for larger procedural layouts, Android support, and Arcade Mode.

Keep tentative values labeled until validated. Record implementation differences here when they arise, with their impact and a proposed next step. Do not interrupt the current phase or refactor unrelated code merely to satisfy a future design concept.
