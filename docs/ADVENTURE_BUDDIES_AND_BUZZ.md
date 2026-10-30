# Adventure Buddies, ring pacing and Buzz Bomber

Implemented milestone, 2026-10-30. The finite run uses the eleven **Sonic Runners Adventure** Buddy identities. Effects below are adaptations for this pinball game, not claims about the mobile game's mechanics or rarity. Chao Lab remains a separate physics experiment. Authoritative 2D physics, collisionless 3D presentation, Scorecraft, physical Goal Ring progression and existing standalone/Endless rules remain intact.

## Ring pacing and migration

| Pattern | First-pickup timeout | Full-clear delay | Completion bonus |
|---|---:|---:|---:|
| Ordinary (`bonus_rack = false`) | 25 s | 18 s | None |
| Bonus Rack (`bonus_rack = true`) | 12 s | 11 s | 500 by default |

These are provisional defaults, editable per pattern. Later pickups do not extend the first-pickup timer. A timeout discards partial progress without awarding completion; a successful Bonus Rack awards exactly once before its independent respawn delay. These patterns still share RingField's rack state; they are not Switch Banks.

Act format **17** migrates the legacy format-15/16 signature `respawn_delay = 1.0`, `timeout = 12.0` (or missing), `completion_bonus = 500` (or missing) to the new pattern-specific defaults. A nondefault timeout or reward is evidence of bespoke author timing: that explicit recipe is preserved. New format-17 values, including an intentional one-second delay, are preserved. Missing fields inherit current defaults. Loading never rewrites the source file; Save writes format 17 through the existing exact numeric serialization. The six generated scoring/prototype fixtures have their known defaults updated explicitly. Other authored Acts inherit/migrate on load. Geometry and Ring positions are unchanged.

Expired patterns enter a noncollectible **ready** state. Their world-space pattern bounds expand by **128 px plus Ball and Ring radii**. Both the current Ball position and its last sweep must clear that region. Rings then fade over **0.35 s**, still noncollectible. Returning during the fade cancels it. Activation happens only after a complete safe fade. This also applies to failed partial attempts. Inactive streamed owners, paused games and protected transfers cannot advance these states.

All virtual rewards use `game.award_virtual_rings(amount)`: Ring counter only. No physical claim, scoring, rack progression, Special charge, pickup signal or Buddy recursion. Lane rewards use this same path.

## Buddy effects

All values are provisional gameplay tuning. Percentage contributions independently round to the nearest integer point, after the normal Scorecraft base/combo/Special/fixed-feature award. Contributions add; Buddies never multiply one another. A 300-point award with Hero Chaos Lv1, Dark Chaos Lv1 and Knuckles Omochao Lv1 becomes **300 + 6 + 24 + 75 = 405**. Zero-point events remain zero.

| Buddy | Lv1 | Lv2 |
|---|---|---|
| Hero Chaos | +2% all score | +4% all score |
| Dark Chao | +25% enemy score; +1 virtual Ring per destroyed enemy | +50%; +2 virtual Rings |
| Dark Chaos | +8% all score; −1 starting Ball per Act | +16%; still only −1 Ball |
| Knuckles Omochao | +25% Bumper score | +50% Bumper score |
| Sonic Omochao | Rolling acceleration ×1.10, rolling cap ×1.08, downward cap ×1.02 | ×1.20, ×1.16, ×1.04 respectively |
| Tails Omochao | Gravity ×0.92; downward cap ×0.94 | Gravity ×0.84; downward cap ×0.88 |
| Wizard Chao | +25% `ring_rack`, `switch_bank`, `spinner_goal`, `lane_set` completion score | +50% for those completions |
| Yacker | Ring magnet radius ×1.25 | ×1.50 |
| RC UFO | Each 4 physical Ring claims: +1 virtual Ring | +2 virtual Rings per 4 claims |
| RC Tornado | Acquisition grants +1 starting Ball for the upcoming Act only; no persistent slot | No upgrade; offered only once per run |
| Chip | Once per run, replace a final lost Ball with one emergency Ball in the same Act | No upgrade |

Dark Chaos cannot reduce starting stock below one; Practice ignores its penalty. RC Tornado adds its extra Ball after the minimum-stock rule. Chip's consumed/available status appears in the build summary and results. It does not restore enemies, score or collected Rings. Physics Buddies use a single keyed `PhysicsModifier` contribution alongside existing profile/session/ability modifiers; upgrades replace prior values. They never change Ball mass or multiply arbitrary live velocity.

RC UFO counts physical claims **since acquisition**, including a physical Ring claimed remotely by an ability. Its modulo-four progress persists across Acts, Zones, drains and upgrades for that run. Virtual Rings never enter that hook. The Buddy runtime owns run/Zone/Act counters, levels, acquisition effects, score attribution, rescue usage and draft state. Fresh runs create fresh state.

## Draft and art

Every nonfinal Goal Ring opens three uniformly sampled valid offers, derived from the run seed and draft number. Re-reading the offer preserves it. No duplicates; maxed Buddies and acquired RC Tornado are excluded. The cap is **five unique persistent Buddies**; upgrades consume no new slot. If fewer than three entries remain, show them all; an exhausted build can continue. Rarity metadata is explicitly `prototype_rarity = unweighted`; no canonical rarity or weighted odds are asserted.

Cards show local aspect-preserved portraits, names, next levels, adapted numbers and acquire/upgrade state. All eleven verified **SRA** PNGs were downloaded; no placeholder was needed. Sources and checksums live in [TEMP_ASSET_SOURCES.md](TEMP_ASSET_SOURCES.md) and `assets/ui/buddies/sra/sources.json`. Artwork is temporary fangame/prototype material. No runtime downloads occur.

## Buzz Bomber

`scripts/enemies/enemy_runtime.gd` is the reusable sensor/destruction runtime. Each enemy has a stable ID, type, alive state, score, contact shape, patrol state and owning Act. `enemy_destroyed(enemy_type, object_id, base_points, source)` is consumed by the game/Scorecraft and generic Buddy hooks. Destruction marks the enemy dead before dispatch, preventing reentrant or repeated rewards.

Buzz Bomber uses a horizontal capsule sensor: **14 px half-segment plus 12 px radius**, scaled by its authored size. Relative swept motion includes both Ball travel and enemy patrol. Contact classification uses the entry normal, previous/current positions and incoming velocity:

- Descending top contact: preserve X; set Y to `-clamp(incoming_y × 0.85, 420, 850)` px/s.
- Rising bottom contact: preserve X; keep **80%** of upward Y speed.
- Side/grazing contact: preserve velocity, without a bumper impulse.

These are named constants in the enemy runtime and are provisional. A redirect stops at the first contact along the sweep, so targets beyond the bounce cannot be destroyed by discarded travel. See the [classic mechanical reference](https://github.com/sonicretro/s1disasm/blob/AS/_incObj/Sonic%20ReactToItem.asm#L247); no Genesis constants or assembly were copied.

Buzz Bomber awards **100 fixed `enemy` points**, with no combo advancement/refresh or Special charge. Buddy percentages apply afterward. No damage, projectile or freed Animal in v1. Defeated enemies remain dead through Ball/checkpoint retries; a fresh Act instance restores them. Inactive neighbors cannot destroy or score, and their patrol state stays frozen. Retirement removes their mechanics and bound visual references with the existing Act cleanup.

Sonic Homing Attack can acquire unobstructed active enemy sensors and destroy them on real contact. Knuckles Shockwave uses its existing region/line-of-sight rule; Shadow Chaos Blast uses its existing radius. Both call the same generic destruction method. Enemy awards remain fixed 100 before Buddies for every ability; no new target system or ability multipliers were introduced. Tails remains movement-focused.

The original primitive-mesh model has a blue mechanical head/thorax, yellow/black abdomen, silver wings and arms, red eyes, hover bob, wing motion and destruction pop. Meshes never own collision or scoring. Streaming recipes bind each model to its own live enemy state; no Sega mesh or texture was downloaded.

## Authoring and fixture

Choose **Gameplay → Enemy · Buzz Bomber**. Click for the default ±60 px patrol, or **Shift-drag** to place and extend a horizontal route from the anchor. Select an enemy to drag either visible endpoint later; Shift-drag near its anchor also resizes a side. Alt enables precise unsnapped coordinates. The inspector exposes scale, speed and starting direction; **Stationary** collapses the route to zero. No numeric-distance guessing or spline authoring is required. Each gesture is one Undo/Redo action. Move/duplicate/Save/Load retain the same authored-data conventions, with a new ID on duplication.

Patrol defaults: **65 px/s**, **0.65 s** initial/end-point hover, then horizontal travel and reversal. Route offsets remain horizontal and independent of visual scale.

`data/acts/buzz_bomber_test.tres` contains four targets: an easy descending target under spawn, a side target, an underside target above a launch spring, and a patrol target. Open it in the Act Editor or launch standalone with `-- --act res://data/acts/buzz_bomber_test.tres`. It is outside the production `Authored/` pool. No enemies were mass-placed in production Acts.

## Focused verification

Regression entry points: `buddy_scoring_regression.gd`, `ring_rack_regression.gd`, `scoring_authoring_regression.gd`, `enemy_regression.gd`, `enemy_stream_regression.gd`, plus existing Goal Ring, Scorecraft, physics, character and prototype run/budget/feedback checks. The enemy checks exercise actual editor pointer gestures, exact persistence, real Ball contacts (including an isolated 12,000 px/s shot), checkpoint death persistence and the run's generic Buddy event adapter.

Run `Bake Prototype.cmd` after source changes; prior derived bakes are invalidated by format/pipeline fingerprints. Bakes remain generated local data, not authored source.

Human playtest checklist: judge top-bounce height and bottom damping; judge patrol readability/wing motion at follow-camera distance; judge ring downtime and Buddy draft/card readability. Automated checks do not establish feel or balance.
