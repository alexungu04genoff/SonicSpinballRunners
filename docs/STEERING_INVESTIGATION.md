# Steering investigation

Phase 2A update: user playtesting selected **Quick / Tight** as the provisional startup tuning for both test profiles. Original remains a comparison preset. No steering integration, collision, contribution-cap, or release behavior changed in Phase 2A.

Persistent steering update (2026-10-25): neutral input now preserves the contribution and applies zero steering impulse. Opposite input counter-steers through zero at the existing rates. Caps, collision response and explicit reset behavior are unchanged. Historical release rates below describe the original investigation; `steering_deceleration` is retained for compatibility and is inactive.

## Finding

The original steering code did apply horizontal impulses against existing velocity. It did not disable steering while descending. Its weak counter-steering came from a slow response rate combined with a small, temporary contribution budget.

At the original defaults, acceleration is `1000 × 0.065 = 65 px/s²`. Full input targets a contribution of ±120 px/s. Reaching that target from zero takes about 1.85 seconds. A ball moving left at 1400 px/s can therefore slow only to 1280 px/s in a collision-free interval. Holding right after reaching the cap applies no further impulse. Increasing strength to 0.3 reaches the same cap in 0.4 seconds; it does not increase the amount of counter-steering available.

The effect is easy to see on a near-vertical shot because its initial horizontal speed is small. The same impulse is a much smaller proportion of a fast lateral shot. There was no separate braking rate based on total horizontal velocity.

Reversing a fully accumulated contribution from −120 to +120 took about 3.69 seconds at the original rate. Positive impulses started immediately, but rebuilding that entire contribution was slow. Releasing a ±120 contribution took about 1.32 seconds at `1400 × 0.065 = 91 px/s²`.

## Input-to-motion trace

1. Named left/right input actions combine through `Input.get_axis()`. Keyboard produces −1, 0, or +1. The left analog stick uses the same actions with a 0.18 deadzone. Full stick and keyboard follow the same physics path.
2. Analog input scales the **target contribution**, not the initial acceleration. A half-deflected stick produces about 0.39 after deadzone adjustment and targets about 47 px/s at the original limit. Even modest input can start at the full configured rate but reaches its smaller target sooner. This existing behavior was preserved.
3. The ball advances a separate steering contribution toward that target. It applies `mass × (new_contribution - previous_contribution)` as a horizontal impulse. That impulse changes the real body's total horizontal velocity. The ledger limits steering; it is not a second body or a cap on total velocity.
4. No branch checks vertical velocity, ascent, descent, or a character movement state. The same steering code runs in both directions of vertical travel.

Raw action telemetry uses Godot's [get_action_raw_strength](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-get-action-raw-strength), which ignores action deadzones. Command telemetry shows the value actually routed to physics after the deadzone and UI blocking. Opposing simultaneous actions are combined into this signed raw value.

## Reset and interference conditions

| Event or condition | Actual behavior |
| --- | --- |
| Native 2D contact | Clears the contribution ledger every contact tick, then applies this tick's steering. It does not remove already acquired velocity. Sustained contact can repeatedly refresh the contribution budget. |
| Swept rebound | Clears the ledger when the conservative collision sweep rebounds. No cancelling steering impulse is applied. |
| Flipper boost | The boost itself does not clear the ledger. A physical flipper contact or sweep can do so through the collision path. |
| Serve, drain recovery, reset | Clears the ledger. Deliberate teleport/serve operations replace velocity as before. |
| Profile, preset, modifier, or field change | Does not clear the ledger. New rates and targets apply on subsequent physics ticks. Reducing the target can gradually trim an existing contribution. Use reset/relaunch for a clean comparison. |
| Release / neutral input | Preserves the ledger and applies no steering impulse. The changed trajectory persists until active input or physical forces redirect it. |
| Paused | Gameplay physics stops. Telemetry reports zero current applied impulse while paused. |
| Editing a numeric field | New steering input is blocked; raw input remains visible. The existing contribution persists. Press Enter to leave the field. |
| Waiting for launch | Ball integration exits before steering. |
| Zero strength or selected rate | No change in the ledger. The panel reports the reason when it prevents a change. |
| Contribution target reached | No sustained steering force until the input/target changes or a contact clears the ledger. This can happen at a partial-stick target below the full configured cap. |

There is no air drag. Contact rolling drag acts along supporting surfaces, so it can compete with or assist horizontal steering there. At its default 0.10/s it can be appreciable at high tangential speeds. Downhill rolling assistance and collision impulses also affect the contact trajectory. Gravity and the downward limiter act vertically; ring collection never changes ball momentum. These mechanisms were not changed by the steering investigation. The later magnet update replaces moving rings with immediate swept-radius collection.

## Scoped implementation change

The steering investigation added `counter_steering_deceleration` to the shared profile schema, resolver limits, and live editor. It is expressed in px/s² at strength 1.0, like normal acceleration and release deceleration. Its bounds are 0–8000. Original uses 1000, matching the old counter-steering rate; Phase 2A profile resources use 4000 as part of Quick / Tight.

When input and the requested steering impulse oppose the body's total horizontal motion, the new rate controls how quickly the contribution changes. It uses `velocity.x`, not just the sign of the contribution. When a braking step reaches zero horizontal velocity, only the remaining portion of that tick uses normal steering acceleration. This prevents the stronger braking rate from powering through zero into a stronger reversal.

The contribution cap, release semantics, collision response, flipper impulses, gravity, and rolling behavior are preserved. The new setting makes braking reach its bounded effect sooner; it does not bypass the budget or introduce continuous friction. The existing practice Chao boosts normal steering acceleration only; the independent counter-steering field is not implicitly multiplied by that modifier.

## Presets for comparison

Use the **Steering** dropdown in the Live Physics Lab. Presets edit only the five steering settings as session overrides. They work with either character profile. The selected label changes to Custom when values no longer match. Switching character profiles or restoring profile defaults now returns to Quick / Tight. Runtime edits never mutate the base resources.

| Preset | Strength | Normal acceleration | Counter deceleration | Release deceleration | Contribution limit |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original (6.5%) | 0.065 | 1000 | 1000 | 1400 | 120 px/s |
| Quick / tight | 0.10 | 2200 | 4000 | 3000 | 120 px/s |
| Air control | 0.10 | 1800 | 3600 | 2200 | 180 px/s |
| Stronger brake | 0.10 | 2000 | 6000 | 2600 | 220 px/s |

The three acceleration columns are pre-strength px/s². Their effective full-input values are:

| Preset | Normal | Counter | Release | Time to full counter contribution from zero |
| --- | ---: | ---: | ---: | ---: |
| Original | 65 | 65 | 91 | 1.85 s |
| Quick / tight | 220 | 400 | 300 | 0.30 s |
| Air control | 180 | 360 | 220 | 0.50 s |
| Stronger brake | 200 | 600 | 260 | 0.37 s |

Start with the user-preferred **Quick / Tight**: a faster response with the original 120 px/s budget. **Air control** increases the maximum isolated change to 180 px/s. **Stronger brake** is an upper comparison. Against a −1400 px/s shot, Quick / Tight, Air control, and Stronger brake eventually reach −1280, −1220, and −1180 respectively, assuming zero initial contribution and no intervening contact. Reversing an existing contribution can span twice its magnitude.

To tune independently: adjust normal acceleration for initial response, counter deceleration for opposing-motion response, and contribution limit for maximum authority. Release deceleration is inactive under persistent steering. Increasing a rate cannot overcome a reached contribution limit.

## Diagnostics

The always-visible steering readout shows raw input, routed command, `velocity.x`, actual signed steering acceleration, the impulse applied in the latest physics tick, the contribution and current target, whether that target is reached, and any blocking condition. It also records the most recent ledger reset and its simulation-time age.

Modes are Normal, Counter, Coast, Idle, or Trim. Coast means neutral input preserves a nonzero contribution; its displayed target is the stored contribution. Trim means the active-input target moved inward, for example after reducing stick deflection or the limit. Active/no impulse reports the actual latest steering impulse, not merely whether a key is held. Acceleration is `steering_delta_velocity / physics_delta`; it excludes gravity, rolling forces, and collision impulses. The label is sampled at 10 Hz, so a brief event may appear only through the persistent reset reason. A single contribution value cannot reconstruct pre-collision momentum after the ledger is reset.

## Verification and playtesting

Persistent steering verification (2026-10-25): the new release assertions failed against the old implementation, then all 21 real-body steering checks passed with the fix. Coverage includes short right input, 120 neutral ticks with unchanged contribution/velocity and zero steering impulse, left reversal through zero, both contribution caps, native/swept contacts, and teleport/serve resets. The updated general physics suite passed all 38 checks, including flippers, bumpers, high-speed walls, respawn and 20 seconds of simulated play; profile regression and four steering UI checks also passed. Broader suites and graphical startup used an isolated committed snapshot plus this change because concurrent working-tree edits had a `game.gd` indentation error. Graphical startup reached `PLAYGROUND_READY` with existing script warnings; sandbox headless runs reported certificate-store/editor-settings access diagnostics. Subjective steering feel remains a manual check.

Focused real-physics checks cover ascent/descent, aligned input in both directions, counter-steering in both directions, saturation, release, input reversal, actual native/swept wall rebounds, profile changes, external impulses, mapped keyboard/gamepad events, UI suppression, and 60/120-step rate consistency. A separate UI smoke check exercises preset selection, independent editing, profile reset, preservation of unrelated stats, and rendered layout.

The automated preset comparison requested 30 physics ticks of right input against a −1400 px/s shot. Approximate measured velocity changes were +16 Original, +97 Quick/tight, +87 Air control, and +145 Stronger brake. Input reaches integration on the following tick, so these short samples are slightly below an idealized quarter-second calculation. They demonstrate bounded response, not subjective feel.

Manual checklist:

1. Reset/relaunch, then compare the Quick / Tight default with Original while ascending and descending.
2. Hold against a fast lateral shot. Watch Counter, signed acceleration, and contribution target; note when braking stops at the cap.
3. Steer briefly, release and check that the trajectory persists. Reverse input to cross zero, then compare after a rebound. Watch Coast and the last reset reason.
4. Compare Quick/tight and Stronger brake. Judge useful correction versus excessive control, using both keyboard and a physical gamepad.

No continuous-braking redesign is included. If sustained braking beyond the contribution cap is desired after these comparisons, that is a separate gameplay choice with different momentum/release semantics.
