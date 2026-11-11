# Ring rack bookkeeping — 2026-11-11

`RingField.advance_racks()` now caches rack membership and owner views. Each
120 Hz update visits the active Act's racks directly. Expiration and respawn
update that rack's cached members. The previous implementation scanned every
resident Ring to discover racks, allocated a visited dictionary each tick, and
rescanned the full list for every expired or respawning rack.

The cache holds the original Ring dictionaries, so clocks, home positions and
other state stay live. Pickup indices, contact scans, swept collection, scoring,
rail eligibility, safety distance, timeout, respawn delay and fade are unchanged.
Inactive owners keep their exact clock state. Legacy collection bounds can still
select a partial rack; expiration/restoration retains its whole-ID behavior.

## Membership changes

- Assigning `field.rings`, `add_ring()` and `add_pattern()` invalidate the cache.
- A size check catches direct append/removal before the next rack update.
- Same-size in-place replacements, reordering, or edits to rack IDs/owners must
  call `invalidate_rack_cache()`. The real resident synchronizer does this before
  clearing and repopulating the list, including when its final count is unchanged.
- Invalidation immediately releases cached record references. The next enabled,
  positive-delta rack update rebuilds them. Changing the active owner selects its
  cached view without rebuilding membership.

These are runtime caches. No extra bake is required for this change; the existing
version-9 Green Hill recipes pass normal Prototype freshness/authority validation.

## Verification and CPU measurement

The focused cache regression passes 23 checks, including same-count replacements,
owner changes, partial bounds, live home-position edits, legacy duplicate IDs,
signal counts and release of replaced data. Its 72-Ring fixture performs three
eligibility checks per tick for the active three racks, versus 72 in the previous
scan. Existing pickup, rack, rail, GPU spin, Scorecraft, character, streamed rail,
disk authority, enemy streaming, protected retry and streaming smoke checks also
pass: **359 checks** in total. Editor import reports no script errors.

The optional profiler compares the previous source with current code. A seeded
4,000-step run preserves Ring state, previous Ball position and reward/reset
signal order across claims, ownership/bounds changes, suspension, resets, rail
travel, home edits, list replacements, additions and reordering.

The [sample receipt](ring-rack-cache-profile.json) uses matching Godot 4.7.2 on
Linux, three real published Acts (160 Rings, 15 racks, six active racks), and
12 alternating blocks of 3,000 calls per implementation. Median microseconds:

| Method | Rack clocks | Before | Cached |
| --- | --- | ---: | ---: |
| `advance_racks()` | Idle | 191.13 | 11.04 |
| `advance_racks()` | Pending | 187.44 | 11.54 |
| `RingField._physics_process()` | Idle | 440.66 | 228.70 |
| `RingField._physics_process()` | Pending | 357.19 | 197.21 |

This measures warmed CPU method calls with a stationary fixture Ball. Pending
clocks use a long fixture timeout so they remain pending throughout sampling.
Membership construction is outside the steady timing blocks. The full RingField
method includes its contact scan; this does not time the engine's collision
solver, rendering, a complete game frame, or Windows FPS. Host timing variation
remains visible in the raw samples. Full Windows profiling remains useful.

For a repeat on Windows PowerShell, save the reviewed baseline outside the
project so the editor does not import a duplicate global class. `$godot` names
the matching Godot 4.7.2 console executable:

```powershell
git show 9f50556:scripts/ring_field.gd | Set-Content -Encoding utf8 "$env:TEMP/ring-field-before.gd"
& $godot --headless --path . --script tools/profile_ring_racks.gd -- --baseline="$env:TEMP/ring-field-before.gd" --profile
```

Omit `--profile` to run only the state/signal comparison. Results default to
ignored `test-results/ring-rack-profile.json`; `--output=<path>` overrides it.
The ordinary deterministic check needs no baseline file:

```sh
godot --headless --path . --script tests/ring_rack_cache_regression.gd
```
