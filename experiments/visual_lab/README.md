# Green Hill Visual Lab

A playable Green Hill presentation of the shared physics sandbox, integrated on `main`: generator v10, the 50 px construction kit with rounded Easy recipes, side recovery flippers and a short upper paddle, Normal-flow banks/curves, optional Score Attack and the first three-Act Green Hill Zone. The original physics-playground entry point remains available. Free Play remains the default.

The scene wraps the existing sandbox and its generated layout. Original procedural checkerboard terrain, grass, palms, flowers, distant rocks, sunlight, rings, bumpers, and flippers dress the same playfield. A locally prepared Sonic Runners model supplies brief, table-aligned gameplay poses and upright character-study previews. The invisible 2D ball remains authoritative; the character and scenery are collisionless. A contact marker tracks the physical ball independently of the visual hop. Body placement, imported-model axis correction, and spin-ball rotation use separate transforms.

## Launch

Double-click **Play Green Hill.cmd** in this worktree's repository root. **Physics Playground.cmd** opens the original debugging presentation. Both launchers use the same physics, generator, profiles and scoring code. The local prepared Sonic model is reused automatically; preparation is not repeated at launch.

**Green Hill Zone:** choose it in the shared mode dropdown, then **Start / replay**. Seed 18 has an input-only completion witness. Nine sections form one continuous Easy playfield, with score targets 750 / 1,250 / 1,750, locked gates, checkpoint retries, three Chao drafts and a final portal. Drafts pause the same ball in place; the last reward appears in the completion summary. Zone generation takes several seconds. Names, colored gates and portal are gameplay placeholders for later art. Use O for the full-course overview.

**Chao Lab v0:** the shared **Chao: … · Lab** button beside Start / replay opens three simple colored choices and effective-stat comparisons. Choose at serve or pause, then equip into a fresh run on the same seed. It respects the selected mode/target and keeps the equipped name visible with F1 hidden. Replay, drains and table changes retain one slot; the debug Practice toggle replaces that slot. Chao names/colors are placeholders; terrain and character assets are unchanged. See the main README for values and lifecycle rules.

Alternatively, run PowerShell from this worktree's repository root:

```powershell
.\experiments\visual_lab\launch.ps1
```

The launcher resolves a Godot executable, waits for a dedicated headless import and checks its diagnostics, then opens only `experiments/visual_lab/visual_lab.tscn`. It does not stop existing processes or change `project.godot`. If Sonic has not been prepared, the scene still opens with a clearly reported spin-ball fallback.

Import uses a private editor profile under `.godot/launcher-profile` with indentation conversion disabled. Godot restores editor state even with `--import`; using a normal tab-based editor profile could rewrite a four-space nested line into a tab and break `game.gd`. The launcher restores the caller's `APPDATA` before starting gameplay and never edits the user's editor settings. If a previous launch already introduced that parse error, restore the affected line to its original spaces before retrying; the launcher does not rewrite source files to repair errors.

To choose the exact executable used for this experiment:

```powershell
.\experiments\visual_lab\launch.ps1 -GodotPath 'C:\Users\Alex\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
```

Discovered tools: **Godot 4.7.2 stable**, **Blender 5.2.3 LTS**. The launcher also checks Godot on `PATH` and `C:\Program Files\Godot\Godot.exe`; pass `-GodotPath` for reproducible version selection. Import-only mode is available as `-ImportOnly`. Godot can return a successful process exit code despite script errors, so inspect its output as well.

| Control | Action |
| --- | --- |
| Enter / gamepad X | Launch from the bottom serve |
| Q / E or LB / RB | All left / right flippers, including the short upper paddle |
| Left / right arrows or left stick | Existing limited steering |
| Escape / Menu | Pause or resume; leave character study |
| R / Back | Reset and relaunch |
| F1 / Tuning button | Open the complete existing physics, camera, seed and construction-grid controls |
| O / Overview button | Toggle full-course overview and ball-follow camera |
| Normal 18 / Normal 23 | Build the requested catalogue layout while paused or at serve |
| Grid base / Grid variant | Switch middle type, preserving current seed and difficulty, while paused or at serve |
| C / Character close-up | Enter or leave the optional paused study pedestal |
| 1–4 in character study | Preview rolling, idle, jump and trick |

The mode strip below the Green Hill title reuses the shared Free Play / Score Attack selector, score target and Start / replay action. Score Attack unlocks the upper goal at the chosen score and requires reaching it physically; the shared victory panel offers replay, next seed and Free Play. The Green Hill score card shows target progress and goal status. F1 preserves access to the same controls.

The quick-build buttons disable during live play. Use Escape first, build, then resume and launch. F1 provides any other seed, preference, profile, tuning or grid combination. Regeneration preserves tuning, camera settings, overlays and pause, resets the run, and rebuilds terrain from the final mirrored/shifted/shaped chunk outlines. Surviving bottom paddles and newly generated middle paddles bind to the new character adapter exactly once.

Ordinary gameplay defaults to the procedural spin-ball, including at serve. Real flipper strikes trigger a 0.62-second jump; bumper contacts trigger a 0.56-second trick. Both return to spin through a 0.12-second scale overlap. A 0.18-second event cooldown and suppression of repeated active reactions prevent contact callbacks from continually restarting the pose. Short cyan motion beads and expanding impact/pickup circles improve tracking. The physical-radius contact marker stays at the authoritative ball anchor. Ring collection retains the sandbox's 0.20-second attraction flight to that anchor. Cosmetic hops and animations never change physical position, momentum, collider size or scoring.

Pose previews are confined to character study so a forgotten preview cannot suppress gameplay feedback. Returning restores the previous pause state and automatic animation. Regeneration is unavailable during study.

Optional launch arguments:

```powershell
.\experiments\visual_lab\launch.ps1 -Seed 23 -Grid Variant
.\experiments\visual_lab\launch.ps1 -NoModel
.\experiments\visual_lab\launch.ps1 -Playground
```

`-Grid` accepts `Catalogue`, `Base` or `Variant`; seed/grid options apply to Green Hill. `-NoModel` verifies the procedural fallback without moving or deleting local assets. F5 in Godot still opens the original playground; F6 on `visual_lab.tscn` opens Green Hill.

## Table-relative character orientation

The presenter has four small explicit states: `SPIN`, `JUMP`, `TRICK`, and `SHOWCASE`. Gameplay uncurled poses point the head up-table (3D `-Z`), feet down-table (`+Z`), and front toward the board normal (`+Y`). Descending motion never flips that axis. Character study retains the conventional upright model.

`UncurledVisualAnchor` owns placement, cosmetic height and directional lean. Its child `ImportedModelAxisAlignment` rotates the imported model by -90 degrees about X for gameplay. The normalized one-metre model is centered by a local Y offset of -0.5 before that correction. The separate procedural spin-ball never rotates the uncurled rig.

Horizontal velocity supplies a smoothed in-plane lean, capped at ±23 degrees. The provisional dead zone is 45 px/s; full lean is reached at 650 px/s, with an exponential response rate of 10/s. Lean rotates around the board normal only. The body uses scale 0.85 and anchor height 0.40, with a visual-only sine hop of up to 0.12 for jumps or 0.06 for tricks. Sampled prepared poses retain at least 0.088 units of board clearance at full scale. These values are presentation tuning, not collision or grounded/airborne rules.

## Prepare the local character

Third-party archives, textures, models, prepared binaries, and captures are deliberately absent from Git. Read [ASSETS.md](ASSETS.md) and [asset_manifest.json](asset_manifest.json) before acquiring them. No paid services, add-ons, or asset-supplied scripts are required.

1. Open the [Sonic Runners Sonic source page](https://models.spriters-resource.com/mobile/sonicrunners/asset/293026/) in a browser and download its ZIP. Save it as `experiments/visual_lab/local/sonic.zip`. Browser download worked for this experiment; command-line fetching encountered a Cloudflare challenge. Do not bypass the site's controls or execute scripts from the archive.
2. From the worktree root, verify the archive and extract it locally:

```powershell
$labPath = Join-Path (Get-Location) 'experiments\visual_lab'
$localPath = Join-Path $labPath 'local'
New-Item -ItemType Directory -Path $localPath -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $localPath '.gdignore') -Force | Out-Null
$archivePath = Join-Path $localPath 'sonic.zip'
$expectedHash = '4DE42CC9627DAEA795F6E4EDCB77A2BB5E44A11AED10C8968B977BB18E9DB2E8'
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'Archive differs from the inspected version. Inspect the new archive before preparing it.'
}
Expand-Archive -LiteralPath $archivePath -DestinationPath (Join-Path $localPath 'source\sonic')
```

The source directory must contain `chr_sonic.smd` and its adjacent `chr_sonic_body_dif.png`, `chr_sonic_eye_dif.png`, and `chr_sonic_mouth_dif.png`. Nested archive folders are supported. Extract once; preparation can be rerun without extracting again.

3. Run the repository-authored Blender preparation script:

```powershell
$blenderPath = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $blenderPath --background --python-exit-code 1 --python '.\experiments\visual_lab\tools\prepare_sonic.py'
if ($LASTEXITCODE -ne 0) { throw 'Sonic preparation failed; inspect Blender output.' }
```

Preparation reads SMD data directly, builds the weighted armature, assigns diffuse textures, normalizes the standing model to one metre, writes three experimental in-place pose clips, and exports `local/runtime/sonic.glb`. It also writes `local/sonic_prepared.blend`, `local/rig_report.json`, and the three `local/blender_idle.png`, `local/blender_jump.png`, and `local/blender_trick.png` studio renders. Rendering is part of this command and takes longer than export alone.

The current source archive's FBX is version 6100, which this Blender importer rejects. The SMD route needs no importer add-on. The `--python-exit-code 1` option makes Blender report a preparation-script failure through its process exit code.

The `.gdignore` keeps original files and Blender sources out of Godot's import scan. The adapter loads the GLB at runtime with `GLTFDocument`, so this ignore file does not prevent the character from appearing. Run `launch.ps1` after preparation.

## Captures

Use a graphical Godot run for screenshots; headless execution cannot verify lighting or material appearance:

```powershell
.\experiments\visual_lab\launch.ps1 -Capture gameplay
.\experiments\visual_lab\launch.ps1 -Capture idle
.\experiments\visual_lab\launch.ps1 -Capture jump
.\experiments\visual_lab\launch.ps1 -Capture trick
.\experiments\visual_lab\launch.ps1 -Capture roll
.\experiments\visual_lab\launch.ps1 -Capture reel -Sequence
```

Each capture run opens its own lab process, freezes physics, saves the full window including the lab UI, then exits. The gameplay image uses the playfield camera and the spin-ball at serve. The pose and roll captures use the dedicated study pedestal. Single images are `captures/gameplay.png`, `idle.png`, `jump.png`, `trick.png`, and `roll.png`. Single character images seek the pose to 0.55 seconds.

The launcher supplies Godot's `--fixed-fps 60` for capture runs. Sequence mode writes 48 images, sampled every four rendered frames, for a 15 fps presentation sequence. `-Capture reel -Sequence` writes `captures/reel_000.png` through `reel_047.png`: 12 idle frames, 12 jump frames, 12 trick frames, and 12 spin-ball frames. Passing `-Sequence` with another capture kind holds that view for the entire sequence. `-CaptureFrames` changes the initial warm-up from its default of 75 rendered frames. The scene creates `captures/.gdignore` so Godot does not import the rendered images. This delivers frame captures; no video encoding tool is required.

Captures are local and ignored because they contain the third-party character. Repeating a capture replaces files with the same names. Keep any captures you want to compare under a different local name first.

An optional local MP4 can be encoded with an already installed FFmpeg; this is not required to prepare or run the lab. With `ffmpeg` on `PATH`, run from the worktree root:

```powershell
ffmpeg -framerate 15 -i '.\experiments\visual_lab\captures\reel_%03d.png' -c:v libx264 -pix_fmt yuv420p -crf 19 -movflags +faststart '.\experiments\visual_lab\captures\visual_lab_reel.mp4'
```

The delivered local `captures/visual_lab_reel.mp4` was verified with FFprobe: H.264, 1280 × 900, 48 frames at 15 fps, 3.2 seconds. It remains ignored along with the source frames.

## Rig and animation status

The inspected SMD contains **54 retained bones, 2,211 unique vertices, 3,318 triangles, five material assignments, zero unweighted vertices, and a maximum weight-sum error of approximately 0.000001**. Its skeleton data contains only frame `0`; **no source animation clips were found**. The imported bone hierarchy and authored skin weights are preserved rather than replaced by a new rig.

`idle`, `jump`, and `trick` are new experimental clips, each made from a held pose with a small one-second easing variation. They are not original game animations, a polished locomotion set, or a fully curled model. Ordinary movement uses a separate procedural spin-ball. No animation root motion drives the ball. Numerical deformation checks and rendered joint review are complementary: the report alone does not establish good shoulders, elbows, hips, or knees.

The orientation follow-up compared imported rest matrices with SMD data (maximum element error about 0.0000078) and checked identity-pose skin deformation (maximum displacement about 0.00000018). The imported rest pose and weights were consistent. The pose script's rotation conjugation expresses rotations in rest-frame axes carried by animated parents; it does not keep them in fixed world axes. Temporary finger curls around the source Z axis bent fingers sideways. Those invented curls were removed, preserving the imported open-hand transforms. Jump and trick remain simple prototype poses; some hand/body overlap still needs artistic refinement.

## Orientation verification — 2026-10-23

Godot 4.7.2 passed `orientation_smoke.gd`: **13/13** with the prepared model, **13/13** with `--no-model`, and **13/13** in the graphical capture run. Checks cover table-relative axes, both lean directions, low-speed stability, descending motion, repeat suppression, pause, showcase restoration, unchanged physics/pickup/score state, and actual flipper/bumper contacts.

```powershell
godot --headless --fixed-fps 120 --path . --script res://experiments/visual_lab/orientation_smoke.gd
godot --headless --fixed-fps 120 --path . --script res://experiments/visual_lab/orientation_smoke.gd -- --no-model
godot --fixed-fps 120 --path . --script res://experiments/visual_lab/orientation_smoke.gd -- --screenshots
```

The graphical probes place the ball once before each contact, then let the actual 2D simulation run without further trajectory edits. Captures are labelled controlled probes. They show a near-vertical flipper launch, diagonal flipper launch, and descending bumper approach/rebound. Near-vertical and bumper sequences naturally complete the return to spin; the diagonal shot encounters another real bumper before its first reaction finishes. The separate complete playable integration check still covers ordinary launch-to-drain traversal.

Local files under `captures/orientation/` include `near_vertical_launch.png`, `diagonal_launch.png`, `descending_bumper_trick.png`, `near_vertical_launch_return_to_spin.png`, and `descending_bumper_return_to_spin.png`. The delivered `live_contact_probes.mp4` contains 113 sampled frames at 30 fps, 1280 × 900, lasting 3.77 seconds. All media remains Git-ignored. To encode fresh sequence frames with an existing FFmpeg installation:

```powershell
ffmpeg -framerate 30 -i '.\experiments\visual_lab\captures\orientation\sequence_%03d.png' -frames:v 113 -c:v libx264 -pix_fmt yuv420p -crf 19 -movflags +faststart '.\experiments\visual_lab\captures\orientation\live_contact_probes.mp4'
```

The full playable check was rerun: **25/25**, covering Normal 18/23 and both grid variants. The existing visual check was rerun: **19/19** with the model and **14/14** without. Its independent bumper fixture now resets between scenarios so the preceding flipper reaction's intended cooldown cannot suppress that probe. Final headless editor import passed. Visual review confirmed the head/feet direction, visible face and return to the procedural ball. Human flipper timing, transition feel and controller hardware remain manual checks.

## Playable integration verification — 2026-10-23

Godot 4.7.2 Compatibility on Windows:

- `experiments/visual_lab/playable_smoke.gd`: **25/25**. Real quick-build buttons regenerate Normal seeds 18 and 23, Grid base at 18 and Grid variant at 23. Checks cover regenerated terrain footprints, paddle lengths/positions, no 3D colliders, settings preservation, stale listeners, both pairs' real contact events, ring flight, marker alignment and pause.
- Each continuous Balanced run started at the normal serve, used only ordinary flipper input, visited all three sections, returned down, hit bumpers, collected rings, drained and automatically relaunched. No trajectory edits or profile changes occurred during those runs. The input probe used a 58 px trigger and released the flippers after reaching the top to observe descent. Earlier 48 px timing did not complete every catalogue route; these witnesses are not player success rates.
- `visual_lab_smoke.gd`: **19/19** with local Sonic; **14/14** with `--no-model`, including real flipper/bumper events in fallback mode.
- Shared `physics_regression.gd`: **38/38**; `grid_chunk_regression.gd`: **23/23**; `normal_flow_regression.gd`: **17/17**. The grid test deliberately emits one invalid-recipe error and verifies preservation of the current table. Normal-flow reporting now creates its ignored output folder in fresh worktrees and handles open failure instead of hanging.
- Headless import and PowerShell launcher syntax passed. Both explicit and automatically discovered Godot launches were checked. The launcher waits correctly for console or GUI executables and rejects reported import errors even when Godot returns zero.
- Actual graphical gameplay and overview captures were rendered for all four layouts. The capture pass uses the same real input probe; it stops early after the live frame and is separate from the complete headless traversal check. Visual review caught and fixed clipped footer controls.

Reproduce the complete focused check:

```powershell
godot --headless --fixed-fps 120 --path . --script res://experiments/visual_lab/playable_smoke.gd
```

Render fresh live-play screenshots (not pose mockups):

```powershell
godot --fixed-fps 120 --path . --script res://experiments/visual_lab/playable_smoke.gd -- --screenshots --captures-only
```

Files are ignored under `captures/`: `normal18_play.png`, `normal23_play.png`, `grid_base18_play.png`, `grid_variant23_play.png`, and each corresponding `_overview.png`. Omit `--captures-only` to run the complete traversal checks graphically as well. The older `-Capture gameplay` launcher option remains a **paused serve composition**, while idle/jump/trick/reel are character studies.

`godot` is shorthand for the installed executable described above. Feel, player flipper timing, controller hardware and camera comfort still need human playtesting. Automated trajectories establish that the routes work, not that every shot succeeds.

## Original visual-lab verification — 2026-10-22


- The launcher's dedicated Godot 4.7.2 headless import completed without script errors. JSON manifest and PowerShell launcher syntax checks passed.
- `godot --headless --path . --script experiments/visual_lab/visual_lab_smoke.gd` passed **19 of 19 checks with the local Sonic asset present**. Checks cover GLB and clip loading, actual Skeleton3D arm/hip differences after seeking idle/jump/trick, real 2D flipper and bumper event triggers, pause behavior, physical contact-marker alignment, separate upright/rolling transforms, no 3D gameplay colliders, and the unchanged normal entry point.
- The normal sandbox startup, `godot --headless --path . --quit-after 90`, completed cleanly. `tests/profile_regression.gd` reported zero failures; `tests/physics_regression.gd` passed **38 of 38 checks**.
- Blender idle, jump, and trick renders were visually reviewed at shoulders, elbows, hips, and knees. Limbs remained connected without exploding geometry. These are simple low-poly bends and pose studies, not a polished action-animation set.
- Godot gameplay, final jump/trick close-ups, and reel frames 17 and 44 were visually inspected. The final capture batch and the local MP4 were produced successfully. This review establishes a visible experiment, not final approval of playfield readability or game feel.
- One graphical Godot capture process exited with Windows code `-1073740791` after reporting ready, without a script diagnostic. An isolated retry and the final capture batch succeeded. The cause was not established.
- Git ignore checks confirmed that third-party assets, derived binaries, and captures remain local.

The `godot` name above is shorthand for the verified executable listed under Launch. Run these commands from the visual-lab worktree root; they must not target another checkout.
## Short visual/playtest checklist

- Confirm textured eyes, mouth, gloves, shoes, and body in the close-up; inspect each pose's shoulders, elbows, hips, and knees.
- Launch, use both flippers, and hit a bumper; confirm jump/trick presentation returns to the spin-ball without moving the physical contact marker independently.
- Check ball visibility, flipper tips, target readability, boundary alignment, and shadows in the gameplay camera.
- Open F1, regenerate another seed/grid layout, and verify its geometry and contact overlay; return to full view. Use Physics Playground.cmd for the original debugging presentation.

Feel, flipper timing, camera readability, and final art direction still need user playtesting. The verification above records the checks actually run; it does not establish production readiness or asset redistribution permission.

## Main integration — 2026-10-23

Green Hill and the original playground now share all committed PhysicsBro changes through `5dc758f`, including Easy grid recipes and Score Attack. The visual adapter creates the same collisionless `ScoreAttackGoal` and reuses `ScoreAttackPanel` outside its hidden debug HUD. Score rules, movement, generation, goal contact and replay remain in the existing shared code.

The existing Score Attack regression can exercise either presentation. Its next-seed assertion uses the actual starting seed so the playground's seed 1 and Green Hill's seed 18 both remain covered. Graphical runs save local ignored HUD captures under `test-results/green-hill-score-attack-*.png`.

```powershell
godot --headless --fixed-fps 120 --path . --script res://tests/score_attack_regression.gd
godot --fixed-fps 120 --path . --script res://tests/score_attack_regression.gd -- --green-hill
```
