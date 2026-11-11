# Cached floor pickup candidates — 2026-11-11

RingField's floor sweep now iterates cached global indices for the active owner's
floor-claimable Rings. The same membership pass builds rack groups and pickup
indices. Neighboring Acts and nonempty rail IDs are excluded from the ordinary
floor scan; elevated chains keep their existing `collect_rail_progress()` path.
Legacy empty rail IDs remain floor-claimable, matching the existing claim guard.

Indices keep their original source order. Each candidate still reads its live
active flag, position and eligibility, then uses the same closest-point swept
segment and radius calculation. A disabled magnet retains direct-contact range.
Scoring, abilities, rack clocks, fade/reset behavior, rail travel, serve and
teleport protection, and 120 Hz physics remain current.

## Invalidation and signal callbacks

The existing `invalidate_rack_cache()` now clears both membership caches.
Assignments, additions, size changes and the real resident synchronizer already
use this path. Same-size replacements/reordering and changes to rack ownership
or rail tags must invalidate explicitly. Changes to positions, home positions,
active state and collection bounds are read live.

Zero-delta ticks still collect, so floor membership is ensured even when rack
timers skip their update. Pickup callbacks can change the owner or residents
during a sweep. A revision check detects invalidation/rebuilds; the remaining
indices then use the original ordered scan with the sweep's initial count.
This preserves same-tick owner changes, same-count replacements and deferred
collection of appended records. Nested rail callbacks retain their existing
collection context. These unusual paths do not allocate a fresh candidate list
for ordinary ticks.

## Verification

The focused pickup-cache suite passes 21 checks covering cold and zero-delta
sweeps, ordering, owner changes, legacy bounds/records, live positions, rail
travel, reordering/replacement, direct append and signal-time mutations. Existing
Ring, rack/cache, rail, GPU spin, pickup presentation, Scorecraft, character,
streamed rail, disk authority, enemy streaming, retry and streaming smoke suites
bring the total to **380 checks**. Editor import reports no script errors.

The reference comparison also passes 4,000 seeded steps against `a119aa7`, with
equal Ring state, previous Ball position, last pickup source and signal order.
One combined streamed-rail run logged dummy-renderer mesh cleanup errors during
warm-up/disposal despite passing its assertions. The standalone rerun passed all
10 checks without those errors; their cause was not established. Existing engine
shutdown diagnostics remain separate from these gameplay checks.

## CPU evidence and reproduction

The [raw receipt](ring-pickup-cache-profile.json) uses Godot 4.7.2, Linux headless,
and the same three published Acts as the rack benchmark. It has 160 resident
Rings, 123 floor Rings, and 55 floor candidates in the active Act. Ordinary sweeps
now visit those 55 indices instead of inspecting all 160 records.

Twelve alternating blocks of 3,000 calls per version give these median times:

| RingField tick method | Before (`a119aa7`) | Cached candidates |
| --- | ---: | ---: |
| Idle rack clocks | 231.09 µs | 99.91 µs |
| Pending rack clocks | 257.46 µs | 110.98 µs |

This is about **57% less time in the RingField tick method** for this fixture.
Rack bookkeeping stays around 10–12 µs in both versions. Sampling uses warmed
membership and a stationary fixture Ball; pending clocks stay pending throughout
the blocks. It excludes cache construction, rendering, the engine collision
solver and complete game frames. These numbers are not Windows FPS evidence.

Use the existing profiler with the preceding source as its baseline. Windows
PowerShell, with `$godot` set to the matching 4.7.2 console executable:

```powershell
git show a119aa7:scripts/ring_field.gd | Set-Content -Encoding utf8 "$env:TEMP/ring-field-before-pickups.gd"
& $godot --headless --path . --script tools/profile_ring_racks.gd -- --baseline="$env:TEMP/ring-field-before-pickups.gd" --profile --output=res://test-results/ring-pickup-profile.json
```

Keep the baseline outside the project to avoid importing a duplicate global
class. Omit `--profile` for the state/signal comparison alone. Current version-9
bakes remain valid; the normal disk-loaded Prototype freshness check passes, so
this change requires no additional rebake.
