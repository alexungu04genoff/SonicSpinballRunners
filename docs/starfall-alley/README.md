# Starfall Alley

An Easy candidate for Sonic Spinball Runners. Charge the right-side shooter, play the three pop bumpers in the crown, then choose a forehand from the lower pair. A stronger left shot takes the outside line to the lit Goal.

Open [Starfall Alley](<../../data/acts/Candidates/Starfall Alley.tres>) in Act Geometry Editor and choose **Play Act**. In Prototype, hold **X** to charge the plunger and release to fire. A little over half charge gives a useful opening. The authored target and the single-Act Prototype target are both 1,000 points.

[Full-table overview](full-table.jpg) · [Normal follow camera](follow-camera.jpg) · [Four shot demonstrations, 19 s](four-shots.mp4) · [Uninterrupted one-ball clear, 18 s](one-ball-clear.mp4) · [Five matching theme views](five-themes.webp)

## Reading the table

The 450 × 750 px playfield has an arched crown, staggered shoulders and two raised guides above the apron. They separate the inner shooting lanes from the outside returns. The shooter occupies its own cut along the right edge. Four flippers, four bumpers, one patrolling Buzz and 30 floor rings give the player destinations at three heights. Each of the four terrain solids uses the editor's Smooth operation. Unsmooth recovers 113 original 25 px stamps. The top and bottom bank corners, shoulder-flipper mounts and lower guide tips were pinned during smoothing.

| From | Aim | Observed result on a fresh table |
| --- | --- | --- |
| Lower right | Follow the inner ring line to the left pocket bumper. | The bumper scored and the ball came back to the lower left. The sequence earned 190 points. |
| Lower left | Shoot up the right diagonal through Buzz's patrol. Once the Goal lights, shoot farther outside the patrol. | A 0.74 contact fraction destroyed Buzz. The shot and return earned 500 points. The filmed clear finished with an outside forehand from this flipper. |
| Lower left, wide miss | Clip the right guide and let the ball run up the outside lane. | A 0.96 contact fraction missed Buzz. The ball rolled back down the right inlane, where the right flipper sent it back up the table. The sequence earned 90 points. |
| Upper right shoulder | Shoot across the table through the crown and back down the short rack. | The returning ball cleared the 500-point rack. The sequence earned 665 points including rings. |

Contact fractions are measured from hinge to tip on the actual moving paddle. The shot reel starts each example with a controlled falling ball above a resting flipper. The uninterrupted clear starts at the dock and uses only Launch and flipper inputs. Both recordings use the normal Prototype follow camera, production Retro and the live 120 Hz ball. The overview uses the game's top-down inspection camera.

## Why this shape

The eight saved production Acts suggested an opening for a long plunger table with bank shots and visible inlanes.

| Production Act | Gameplay shape observed in its source |
| --- | --- |
| Clover Scoop | Two-flipper scoop. A spring feeds the Loop and a high right pocket holds the Goal. |
| DropTarget-SW-SP-DT | Lower switch play opens into a defended climb with a spring shortcut. |
| First Try Smooth Decor | A broad bumper court uses eight flippers for catches around its terrain. |
| GateDash | A gated course spreads switches, dash panels and catches across a tall field. |
| RampMania | Stacked chambers, two rails and an exit bank make progress through a sequence of rooms. |
| Reverse C Spring | An asymmetric climb passes the ball between springs and elevated paddles. |
| Secret Entry | A lower switch court opens a side ascent into the upper reward area. |
| SpringUp | A vertical relay uses several paddle levels around a central island. |

Starfall Alley gives the crown to the player on the plunge. Falling through the waist exposes a second game at the apron, where either forehand can score and one can finish the Act. The launcher is the only object that takes ownership of travel.

## Iteration record

Four compact cutback layouts preceded the long table. They tested a spinner, a ring rail, weaker-shot rollbacks and a shorter crest. Alex's silhouette review redirected the candidate toward a classic pinball table. The final Act developed through three further playable layouts.

| Long layout | Evidence and resulting decision |
| --- | --- |
| First | The shooter reached the crown. In a 62-tick charge run, the ball eventually settled behind the left lower heel at approximately (145, 740). Lower-left shot samples also passed below Buzz. |
| Second | Moved the lower hinges into the banks, lengthened their blades to retain the tip gap, brought the shoulder catches closer and moved Buzz onto the left forehand. A continuous neutral-steering clear took 44.05 seconds between lighting and collecting the shoulder Goal. |
| Third | Put the Goal outside Buzz at (328, 485). Kept an upper rack shot and added ring leads for the shoulder and outside collect. The same near-full charge and flipper rule collected the Goal 3.72 seconds after lighting it. |

## Score pacing and limits

These are repeatable input examples with Sonic, no Buddies, no Special and no steering. Times are Prototype telemetry measured from free play. The video also includes charging and the trip up the shooter.

| Launch held | Target reached | Lit Goal to collect | Free play | Final score | Balls lost |
| --- | ---: | ---: | ---: | ---: | ---: |
| 62 ticks, 0.52 s | 4.07 s | 10.31 s | 14.38 s | 2,855 | 0 |
| 112 ticks, 0.93 s | 6.59 s | 3.72 s | 10.32 s | 1,240 | 0 |

The near-full run had the same flipper contacts, score and finish tick in Green Hill, Casino Night, Ice Cap, Rooftop Run and Aquarium Park. Each theme opened its own current disk Act and theme recipe with zero fallback builds. The matched images show the lower guides most clearly in Casino Night. In Ice Cap, the pale guides have less contrast against the ice. [Theme comparison](five-themes.webp) · [Review measurements](review.json)

**Design verdict.** The upper-right cross-table shot is the strongest. A single stroke carries through the crown, and the return can still change how much the shot pays. The lower game is enjoyable before the target lights because a near miss changes which flipper can take the next ball. The shooter gives one brief automatic trip per successful serve. Once it releases, every route is free flight, a contact or a roll along terrain.

Both lower flippers have paying shots. The weakest area is the left shoulder. The ball can spend several exchanges in the apron, especially after losing the crown, and the final Goal can be collected without using that flipper. Human timing and the readability of Buzz's outside lane still need a playtest. Watch whether a first-time player finds the upper-left catch on purpose. If they seldom do, extend its sloping receiving bank by one half-grid stamp and replay the same misses. **Keep this Act in Candidates for Alex's playtest.**

## Verification

Godot 4.7.2. The editor opened, saved and reopened an exact editable copy. Its source-built Play Act path started with the ball docked. The disk-backed candidate fixture passed 603 checks, including floor-ring clearance, paddle sweep clearance, weak-launch rollback, charged exit, retry with Launch held, a fresh relaunch, two continuous Goal clears and teardown of the ball, tube and Act root. Shot results establish those particular approaches. Human success rates and general reachability remain unmeasured.

The existing Act geometry, composite terrain, authored runtime, scoring authoring, Scorecraft, Goal and meter, soft retry, traversal authoring, traversal Prototype, Launch Tube and Launch Tube integration suites passed. The Goal editor's snapping checks used an isolated profile with absolute half-cell snapping. The independent Act Review suite passed 32 of 36 checks in a clean profile. Its four legacy migration assertions hard-code format 18. The current format is 19. The existing Launch Tube integration suite passed all 53 assertions and Godot reported four ObjectDB instances at process exit. The candidate's own teardown checks passed without an exit leak warning. During graphical review Vulkan lost the device on initial Ice Cap and Aquarium Park attempts. Both completed on repeat launches. All five final captures were visually inspected.

To repeat the content review, bake this candidate for Green Hill, then run the fixture from the repository root. Substitute any base-theme ID in both commands to check its disk-backed run. Pass the theme ID after the fixture's engine separator, for example `-- --theme=casino_night`. Use the non-primary monitor for graphical captures.

```powershell
& $Godot --headless --path . res://scenes/act_baker.tscn -- '--act=res://data/acts/Candidates/Starfall Alley.tres' --theme=green_hill
& $Godot --headless --single-threaded-scene --fixed-fps 120 --path . --script res://tests/starfall_alley_review.gd
```

The fixture accepts `--case=overview` for a graphical still and `--case=short_charge,pocket,buzz,inlane,crown --film` for the filmed cases after the engine's `--` separator. At fixed 120 fps, every fourth rendered frame supplies a 30 fps recording. Output appears under `test-results/starfall-alley/`. [Diagnostic fixture](../../tests/starfall_alley_review.gd)
