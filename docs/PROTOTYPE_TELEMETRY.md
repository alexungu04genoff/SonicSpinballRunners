# Prototype telemetry evidence · version 5

V5 (2026-11-05) adds `teleporters.transfers` and `teleporters.by_object`, keyed by stable entrance/exit-pair IDs. Only accepted transfers in the active Act count. Blocked exits, cooldowns and overlapping arrival sensors do not count. Teleporters grant no score or combo support. All V4 counters retain their meanings, so existing DropTarget evidence stays comparable. Missing Teleporter fields in older files are unknown, not zero. The V4 definitions below remain historical introduction notes.

Telemetry records what happened. It does not judge design, compute difficulty, rebalance mechanics or change an authored Act. This is a compact local summary, not an event log or per-frame trace.

## Files, versions and compatibility

Results → **Copy run data** and the automatic archive use the same pretty-printed JSON. Files remain under `user://telemetry/runs` (normally `%APPDATA%\Godot\app_userdata\Sonic Spinball Runners\telemetry\runs` on Windows). Results → **Open telemetry folder** resolves the actual location; separately named exported builds have separate user directories. Existing feedback, termination reasons and file protections are unchanged.

`telemetry_format_version` is now **5**. V4 introduced the detailed mechanic/action counters below; V3 introduced authored difficulty and Act fingerprints. All earlier fields retain their meanings, including the legacy `homing` and `type_actions` groups, original flat timing fields, category scores, combo buckets, enemy lifecycle, Balls and Buddy contribution. Old files are never rewritten. Readers should branch on the version and treat missing new fields as unknown, not as zero. When an old row is passed to the exporter, unknown aggregate action counts remain `null`.

Each new Act row retains source path, title, theme, full document fingerprint and authored difficulty number/label. It also snapshots `character`, `character_type` (`speed`, `fly`, `power`) and optional `design_thesis`. These describe the document and character used in that run, not the current contents of a later edited file. Authored difficulty is never inferred from the measurements.

The original `time_to_target_seconds` and `time_target_to_goal_seconds` remain first-event measurements on the existing gameplay clock. Pause, serve waits and protected transfers do not advance that clock. Unreached targets/Goals and zero-denominator rates remain `null`; Goal touch is latched before streaming waits. No automatic label calls a long Goal delay bad.

## Slingshots

`slingshots` contains `activations` and `by_object` counts keyed by stable authored IDs. An activation is an accepted active-face collision that actually applies the Slingshot's powered outgoing velocity after its cooldown check. Backside/end rebounds and cooldown rejections do not count. There is no rejected-contact counter in V4.

The adapter identifies Slingshots behind their existing Spring traversal signal. Ordinary Springs are excluded, and Slingshots still award no score. The existing Spring combo-support meaning is unchanged. All authored Slingshots appear, including zero-use objects, so ignored hardware is visible. Resident neighboring Acts do not contaminate the active Act's record.

## Drop Targets and Banks

`drop_targets` contains `hits`, `unique_targets_hit`, `bank_completions`, `bank_resets`, and `banks`. Each stable bank ID reports authored `targets`, accepted `hits`, `unique_targets_hit`, `completions` and `resets`, including zeros for unused banks.

A hit is the actual standing-to-down transition. Already-down targets do not count again. A reset followed by another accepted hit increases total hits but not the number of distinct target IDs hit during that Act. Completion counts when the final standing target drops. Reset counts only when the timed completed bank actually restores its targets after Ball-clearance checks. Soft retries and initial/full resets are not gameplay bank resets. Bank state and counters remain intact across a lost Ball; a new Act/run resets the recorder.

Drop hits still score as `switch`, and Drop Bank completions still score as `switch_bank`. This is their current Scorecraft contract, including Buddy/combo behavior. V4 does not split or reclassify that score, invent new score categories, or duplicate point totals in the interaction counters.

## Character actions

New `character_action` contains `type`, `uses`, `successful_uses`, and the applicable `speed`, `fly` or `power` object. A use is a committed, charged activation. Failed input attempts with insufficient meter, no target or an already active action are not uses.

| Type | Success definition | Additional evidence |
| --- | --- | --- |
| Speed | One actual physical hit on the selected target through the existing hit callback | `targets_acquired`, `physical_target_hits`, `failed_approaches`, `failures_by_reason`, `hits_by_target_type`, `pending_approaches`, `distance`, `target_range_px` |
| Fly | Flight successfully starts and applies its temporary modifier | `activations`, `successful_activations`, `active_seconds`, `rescue_lift_activations` |
| Power | The committed Smash affects at least one eligible object or Ring | `uses`, `affected_total`, `affected_by_type` (`ring`, `bumper`, `enemy`) |

**Speed:** Acquisition counts the target selected for a committed dash, not idle targeting highlights. Distance is center-to-center at dash start. Close is at most one third of the ability's acquisition range, medium is above one third through two thirds, and far is above two thirds. Each bucket reports acquired/hit/failed counts; `target_range_px` supplies the actual tuning scale. Failures include timeout, blocked/lost target, unrelated collision and explicit interrupted/reset approaches, grouped by the existing reason. A dash still active when a row is captured is pending, not an invented failure. Success/failure resolves only once per approach. The legacy `homing.successful_hits` continues to count accepted scoring events, while the new success counter describes the physical hit callback.

**Fly:** Rescue lift counts the actual falling-Ball branch that applies its one-time lift impulse; it does not claim that a drain was prevented. Active time is sampled at the normal physics rate against remaining Flight duration on the run's active gameplay clock. It excludes serve/teleport/frozen/loading/respawn states, pause and protected transfers. Rail travel may retain active Flight time even though it is excluded from Ball-speed statistics. No speculative post-Flight drain correlation is recorded.

**Power:** Only successful atomic target and Ring claims count. The existing area path deduplicates each target before emitting its accepted callback; down/dead/ineligible targets and already-claimed Rings cannot inflate the total. Round/triangle bumpers share `bumper`; living enemies share `enemy`. Rail Rings, switches, Drop Targets and directional mechanisms remain excluded by actual gameplay. An empty Smash is a use with zero affected objects and no successful use. Divide affected total by uses for an average; no duplicate derived total is needed.

The old `type_actions` group remains: uses, scored Speed target hits, affected non-Ring targets and affected Rings. `homing` remains the shared Speed compatibility name for Sonic and Shadow. No field silently changes from hit counts to use counts.

## Ball speed

`ball_speed` samples the magnitude of authoritative 2D Ball velocity in **physics pixels per second** every **0.1 seconds of continuous eligible gameplay**. Ordinary free motion during Flight is included. Sampling excludes pause/drafts, pre-start/finished runs, inactive/frozen Ball, serve waiting, teleport/reset, protected transfer, loading/respawn, guided Speed approach and rail-controlled travel. The cadence restarts after an exclusion and never fabricates catch-up observations.

`samples`, `average` and `max` describe the accepted samples; max is the maximum **sampled** speed, not every instantaneous collision peak. `median` and `p95` use nearest-rank histogram bins and report the bin's lower edge. Their downward quantization error is less than 20 px/s below overflow. All four statistics are `null` with no samples; stationary eligible Balls count as speed zero.

The histogram has 512 fixed 20 px/s bins plus one overflow bin (about 4 KiB of counters per active recorder). No velocity history, random reservoir or histogram is exported. JSON includes `sample_interval_seconds`, `percentile_bin_width`, `overflow_samples` and `overflow_speed` (10,240 px/s). If a percentile lands in overflow it reports that lower bound; mean/max still use the observed speeds. Nonfinite/negative samples are discarded. This is reproducible comparative evidence, not a scientific instrument or a classifier for calm/chaotic Acts. Character/session tuning and cell scale still matter when comparing runs.

## Unavailable and deliberately deferred

**Wide Spring Saver has not landed in current main.** `wide_spring` is `null`, meaning unavailable, not zero saves. Ordinary Springs and Chip's existing Buddy rescue are not relabeled as Wide Spring events. No charge/saver gameplay is invented.

**Interaction-gap telemetry is deferred.** Current score, traversal, completion and ability callbacks overlap; choosing and deduplicating a broader meaningful-interaction contract is outside this pass. V4 adds no `interaction_tempo` group and makes no empty-travel judgment.

## Run totals and passive implementation

`completed_act_difficulties` groups only cleared Acts by authored rating number (JSON string keys). `action_totals` sums uses and successful uses across recorded completed/partial Acts. Run character/type, total drains, score and all prior summaries remain. Per-object details are not duplicated at run level.

The recorder consumes no RNG, owns no physics/scoring/targeting state and does no disk I/O in physics callbacks. Per-tick work is a small scalar update; percentiles and JSON are calculated at existing snapshot/export points. Per-object storage is limited to authored Slingshots, Drop Banks and their finite target identities. Two small observational signals expose actual Drop Target transitions and Flight's lift branch; existing gameplay conditions and awards are unchanged.

## Verification

`telemetry_evidence_regression.gd` checks bounded statistics, exclusions, null/overflow behavior, Speed resolution and distance buckets, RNG/score isolation, versioned JSON, Act reset, resident ownership, actual Fly/Power hooks and authored context. The physical pinball vocabulary regression checks front/back/end contacts, already-down targets, timed reset and re-hits. Enemy streaming checks a real successful Speed hit while preserving the old score/category/combo ledger. Existing character and Prototype Act tests exercise unchanged physics/actions and automatic JSON archival. These checks establish event meaning, not game balance; Alex's manual playtests provide the next evidence.

Verified on Godot 4.7.2: 28 evidence checks headlessly and with Forward+/Vulkan, 17 physical vocabulary checks, 91 character-lab checks, 33 shared-type checks, 14 existing telemetry checks, 32 enemy-stream checks and 12 Prototype Act/archive checks all passed. The streaming regression used its existing `--no-bakes` authoring path. All five production Acts were then rebaked for Green Hill and Chemical Plant; other theme/Endless pools still need the normal rebake after the source changes. No authored Act resources or old telemetry archives were modified.
