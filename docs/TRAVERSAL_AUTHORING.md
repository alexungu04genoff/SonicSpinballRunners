# Authored traversal freedom

Implemented 2026-11-05. Act format 19 adds optional rail terrain clearance,
continuous flipper length, and a paired Teleporter. Older Acts load in memory
without rewriting their source. Their flipper centerline stays exactly
`0.65 × cell_size`, with radius `0.05 × cell_size`; clearance defaults off.

## Terrain clearance

Select an Elevated Ramp / Rail and enable **Terrain clearance (lower crossing)**.
Draw terrain normally. The compiler checks overlap using the whole rail footprint
and ball radius, including open walls. It still rejects obstructed mouths, exits,
too-narrow rails, and insufficient clearance above other hardware.

The representation is a rail-owned overpass, not terrain polygon subtraction.
Ground terrain colliders and baked convex/segment shapes stay unchanged. Existing
authoritative rail travel captures the ball at the mouth, saves its collision
masks, disables ground collisions, integrates gravity/drag along the route, and
writes `ball.ramp_height`. Weak shots can roll back. At either endpoint the
existing occupancy query must pass before restoring collision; an occupied
endpoint reverses the ball on the rail.

With clearance enabled, terrain lowers to at most the sampled deck height minus
the 3 px deck thickness and 2 px air gap. An 8 px minimum terrain base means a
crossing still needs 13 px elevation. Normal terrain is 32.5 px high. A 20 px
plateau lowers the crossing to 15 px; full-height terrain requires 37.5 px.

Lowered terrain remains an obstacle to an ordinary ground ball. This option does
not create a walkable terrain top or cut a ground tunnel through a solid polygon.
The elevated ball crosses through its established rail owner. This preserves
unrelated ground collision while making a shallow authored crossing valid.

Presentation uses a conservative sampled height field with a 16 px shoulder.
Affected terrain triangles are tessellated on an 8 px grid; a 12 px guard around
the deck footprint covers the grid diagonal. Top, side extrusion, and existing
border meshes share the deformation. UVs, materials and vertex colors survive;
normals are recomputed per face. Rail deck, underside, fascia and supports keep
their existing geometry and shadow policy. Exterior walls join the existing
facade after lowering. Decor mounts follow the lowered cap and report a reminder
to check tall props under the rail. Overlapping clearance regions use the lower
cap. No source polygon changes.

Source presentation and the shared offline template presenter use this helper.
Prototype and Endless load the resulting recipe. Pipeline hashes include it;
old bakes become stale instead of silently reusing full-height terrain.

## Flipper length

Set **Length multiplier** from 1.0 through 2.0; 1.5 is supported. Pivot, radius,
rest angle, swing direction, angular speed, contact-fraction assistance and upward
safety cap keep their existing rules. Longer paddles naturally have faster tips
at the same angular speed.

One calculation drives the editor capsule, swing guide, isolated launch probe,
compiler and collision capsule. Visual and streamed/baked actors consume actual
runtime length. At 50 px cells, centerlines are 32.5 / 48.75 / 65 px; capsule end
caps add 5 px to total length. Defaults remain unchanged pending human playtests.

## Teleporter

One stable object owns IN and OUT, avoiding dangling pairing IDs. Select IN and
drag OUT; Alt frees snapping, Escape/right-click cancels. The inspector exposes
local **Exit X**, **Exit Y**, **Exit angle**, and entrance **Radius**. Moving or
rotating the object moves both endpoints. Connection line and arrow show the
relationship; Undo restores both offsets as one edit. Duplicate creates a new ID.

Contact has no minimum speed or alignment. Exit motion preserves incoming speed
magnitude up to 2,400 px/s and follows the OUT arrow. There is no launch floor:
a resting ball transfers and then obeys gravity. Compilation rejects exits outside
the Act, inside terrain, or in solid hardware/flipper sweeps. Runtime occupancy
checks reject a blocked exit without moving the ball.

Transfer clears steering contribution, angular velocity, pending flipper contact,
contact cooldowns and swept mechanic history. A ball-owned lock spans resident
Acts: wait at least 0.35 active seconds and leave the arrival vicinity (60 px
maximum portal radius plus ball radius plus 2 px) before another transfer.
An overlapping entrance cannot ping-pong after the timer alone expires.

Ring and Goal consumers reset swept history. The virtual line between endpoints
cannot collect Rings, hit enemies, activate switches or complete Goals. Landing
on a Goal remains ordinary physical contact. A successful transfer emits
`traversal_event("teleporter", object_id, "used")`. Telemetry V5 adds transfer
counts without points, combo support, or changes to V4 mechanic counter meanings.
Collisionless 16-sided IN/OUT rings and an arrow are functional placeholders.

## Diagnostic and measurements

Open `data/acts/Experiments/Traversal Diagnostic.tres`, then Play. Top rail is the
old 40 px full-height crossing; bottom rail is the 20 px clearance crossing.
Both horizontal routes are 440 px long with the unchanged smooth 22%-length
entrance/exit profile. Bottom flippers show 1×, 1.5× and 2×. IN near spawn transfers
to upper-right OUT. This is an inspection fixture, not a finished level.

Real-ball trials at 120 Hz, base Balanced/Sonic tuning, default 0.06 rail drag,
no steering and no Dash Panel tested three mouth offsets (-3, 0, +3 px):

| Measure | Full-height | Lowered crossing |
| --- | ---: | ---: |
| Peak elevation | 40 px | 20 px |
| Horizontal route length | 440 px | 440 px |
| Entrance run | 96.8 px | 96.8 px |
| Average rise/run | 0.413 | 0.207 |
| Maximum smooth-profile slope | about 0.620 | about 0.310 |
| First tested speed completing 3/3 | 140 px/s | 110 px/s |
| Previous tested speed completing 0/3 | 130 px/s | 100 px/s |
| Comfortable tested speed | 150 px/s | 150 px/s |

These are diagnostic thresholds, not guarantees for uphill/curved Acts. The entry
gate remains 100 px/s; an exact-threshold shot can miss after ordinary pre-contact
integration. No entry grace, magnetism, boost, drag change or global ramp tuning
was needed. Dash Panels remain useful for intentionally high/fast uphill routes.

Human review still decides mouth feel, shallow-route readability, long-flipper
control and Teleporter exit motion. Inspect tight curves, tall decorative props,
and overlapping clearances in the intended Act.

## Verification paths

- `traversal_authoring_regression.gd`: source/baked compiler, old dimensions,
  invalid crossings/exits, lowered mesh, repeated rail trials, ground collision,
  transfer motion, dynamic obstruction and loop prevention.
- `traversal_prototype_regression.gd`: source and disk recipes through Prototype,
  including telemetry and no swept Ring/Goal collection.
- `flipper_contact_response_regression.gd`: existing contacts plus repeated
  1.5×/2× contacts on both hands, preserving the launch safety cap.
- `portable_editor_smoke.tscn`: inspector edits/Undo, external Save/Load and
  actual Prototype play with a successful transfer.
- Standard single-Act baker covers all eight themes and the shared Endless path.
  Canonical disk-baked Prototype captures passed for all eight themes with no
  fallback builds; Green Hill and Chemical Plant received individual inspection.

Verified results: traversal authoring 34/34, actual source/baked Prototype 20/20,
flipper contacts 208/208, telemetry evidence 30/30, Act geometry 3,461/3,461,
geometry bake 2,842/2,842, Scorecraft 29/29, run telemetry 14/14, and single-Act
Prototype playtest 12/12. Both exported portable executables passed the editor
Save/Load/Undo and actual Prototype transfer smoke test.

Four older suites retain failures reproduced against preserved pre-task code:
authored gimmicks expects a full reset instead of the current soft retry;
pinball mechanics has two existing shot/departure assertions; ramp theme height
expects an older Chemical Plant texture; soft retry cannot start because its
fixture repeats a source Act forbidden by current pool validation. These were
not weakened or folded into this traversal change. Headless graphical Prototype
checks also emit dummy-renderer RID errors; the Forward+/Vulkan run passes cleanly.

Shadow defaults, cascades, MSAA, renderer, atmospheres, steering strength, scoring,
Buddies and character actions remain outside this pass.
