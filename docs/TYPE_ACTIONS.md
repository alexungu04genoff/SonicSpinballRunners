# Shared character type actions V1

Each character combines a physics profile with one shared Type Action. Sonic, Shadow and Amy use **Speed · Target Boost**. Tails, Rouge and Cream use **Fly · Flight**. Knuckles, Blaze and Big use **Power · Table Smash**.

`CharacterDefinition` retains identity, colors, profile and charge rules. Its `type_action` references one resource in `data/types/`. Characters of the same type reference the same action. `TypeAction` owns the type, action label, description and tuning. `CharacterSpecials` dispatches by type, never by character name. Future Fly characters can reference `fly.tres` without another ability implementation.

## Speed: Target Boost

Speed characters uncurl into their own Sonic Runners boost animations during the guided approach. Their feet face the table and their heading turns around its normal to follow the live target. Target Boost uses the same stride rate as dash panels. F8 inherits the active cadence. At the default 1.2× setting, each stride takes about 0.37 seconds for every character, regardless of travel speed. Physical contact or cancellation restores the roll. With the painted character art, a tapered wake points away from the target. The F8 preview inherits the active clip and target heading.

Acquisition preserves the existing full-ball clear-path checks and fresh combo-builder priority, choosing the nearest eligible target within each priority class. Valid targets are active-Act round/triangle bumpers and living enemies. Very close targets no longer have the old 55-pixel exclusion. A failed acquisition keeps the meter.

The authoritative ball integrates a bounded approach each physics tick. It follows a moving target, slows near the target surface and cancels on a newly blocked route, unrelated collision, lost target, range escape or timeout. It never teleports or scores on arrival distance alone. Existing native/swept collision and enemy sensor contact callbacks award the hit. Rails, reset, character changes, drains and Act transfers clear action state.

Provisional shared tuning: 400 px acquisition range, 520 px/s maximum approach speed, 2,600 px/s² guidance acceleration, 180 px/s contact speed and 240 px/s exit cap. Distance increases the allotted approach time, capped at 1.6 seconds. Excessive incoming speed is braked to the cap at entry; subsequent guidance is acceleration-limited. On a hit, a small outward recoil replaces inward enemy pass-through while preserving bounded tangent/rebound motion. Misses return to ordinary physics with bounded velocity. These are initial feel values, not a guarantee against falling off an edge.

Scoring is the former Homing cash-out for all Speed characters: pre-hit base × visible combo + 400, then end the chain. Base is 100 for a bumper and 200 for an enemy. Ordinary physical bumper recharge remains. Existing `homing_*` presentation hooks and the `homing` score/telemetry key remain as internal compatibility names; they now describe shared Speed, not a Sonic signature.

## Fly: Flight

The existing temporary modifier and bounded rescue lift are shared unchanged: 1.6 seconds, gravity ×0.25, steering acceleration ×1.6, counter steering ×1.5 and maximum steering contribution ×1.4. A falling ball receives one lift of at most 700 px/s; Flight does not continuously propel it upward. The final 0.35 seconds smoothly restore gravity/control. Pause freezes duration, and resets remove only the `type_flight` modifier, preserving other modifiers.

## Power: Table Smash

Press Special at full charge to hold the physical Ball at its current table coordinates. The curled model rises for one second. At the apex, the selected character uncurls and plays their Runners Power attack for a one-second accelerating descent (`kn_jump_bunk_loop`, `bl_jump_bunk_loop` or `bg_jump_bunk_loop`). The original attack travels forward, so the presenter points the attack along the table’s downward normal. At two seconds the Ball resumes from rest and one expanding shockwave awards nearby targets. Pause holds the action clock. Reposition, retry, character change or transfer cancels a pending impact. The painted Ball follows the same jump and landing when local model assets are unavailable.

The radius is provisionally 300 px, with a hard 600 px tuning ceiling. Like the former radial blast, it crosses walls within that radius but only affects eligible objects in the active Act:

| Object | Result |
|---|---|
| Ordinary physical Rings | Claim once through RingField; base 15 each |
| Living enemies | Destroy once through their atomic lifecycle; authored base points (Buzz: 200) |
| Round and triangle bumpers | Award base 100 and flash, without inventing a ball contact |
| Elevated rail Rings | Excluded; require authoritative travel on their own rail |
| Switches, Wall Switches, Drop Targets | Excluded; no existing safe area activation contract |
| Gates, diverters, slingshots, springs, rails, Dash Panels, spinners, lanes | Excluded; physical/directional state remains authoritative |

Direct area awards do not build/refresh combos, multiply by the combo tier or recharge Special. Enemy area awards now use the same fixed-base area rule as bumpers/Rings rather than accidentally taking the ordinary contact builder path. Existing Buddy callbacks and legitimate Bonus Rack completion remain: a completed rack still pays its normal fixed reward and may refresh an existing combo. Duplicate descriptors, overlapping Ring claims and immediate remote/contact bumper callbacks cannot duplicate awards.

## Telemetry and focused checks

The original version-2 action fields remain: run-level `character_type` and `type_action`, plus each Act's `type_actions`: `uses`, `successful_target_hits`, `affected_targets`, and `affected_rings`. Speed successes in this legacy group are accepted scoring events; Power counts successful atomic target/pickup callbacks. Existing Homing counters include Sonic and Shadow. Telemetry v4 adds `character_action` with committed uses and type-specific success definitions: physical Speed hits and failed approaches by range bucket, Flight gameplay time and actual lift activations, and Power affected-object breakdowns. See [precise metric meanings](PROTOTYPE_TELEMETRY.md); no old field changes meaning.

Focused regressions: `character_lab_regression`, `four_character_regression`, `authored_main_game_regression`, `enemy_regression`, `enemy_stream_regression`, `run_telemetry_regression`, `economy_v1_regression`, `ring_rack_regression`, `physics_regression`, `buddy_scoring_regression` and `scorecraft_regression`. The enemy streaming fixture uses distinct test-only source copies; `-- --no-bakes` exercises their runtime construction without changing production bakes.

All eleven passed locally on Godot 4.7.2; authored gameplay also passed 72 checks rendered with Forward+/Vulkan on the RTX 4060, with its HUD capture inspected. The broader legacy `endless_scoring_regression` could not complete: normal startup found a stale Sky Sanctuary bake, and its `--no-bakes` retry hit an outdated assumption that the selected published Acts contain Ring patterns. Production bakes and the ongoing authored/art work were preserved. The isolated enemy streaming regression covers real active/resident ownership and shared Speed scoring without those dependencies.

Manual checks for Alex:

1. Replay the same Act as Sonic, then Shadow. Both should show Speed · Target Boost and use identical action tuning; their normal profile feel remains different.
2. Dash at a barely separated bumper/enemy, a medium target and a near-400 px target. Try moving toward and away, a closing/blocked route and a target beside a drain. Look for bounded approach, one cash-out and readable recoil.
3. Use Flight during a fall, steer both ways, pause/resume and drain/retry. Check rescue usefulness and smooth return to normal gravity/control.
4. Smash while stationary near Rings, enemies and bumpers. Check that targets react once on landing, two seconds after pressing Special, and that remote hits grant no meter. Switches, Drop Targets and directional mechanisms must remain unchanged.
5. For the separate first-Buzz-kill issue, run **Buzz Death Diagnostic.cmd** on the work laptop. Compare legacy, opaque and off; see [measurements and report paths](BUZZ_FIRST_KILL.md).
