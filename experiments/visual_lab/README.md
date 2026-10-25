# Green Hill Visual Lab

**Current presentation (2026-10-24):** Sonic, Tails, Knuckles and Shadow always remain in their character-colored ball form, including jumps, impacts, specials and character study. State transitions, special effects and authoritative 2D gameplay remain intact. Local character models are not loaded; the existing Blender pipeline and pose hooks are retained for later work with a 3D modeler. Older model previews and verification records below describe the previous presentation.

A playable Green Hill presentation of the shared physics sandbox: generator v10, the 50 px construction kit with rounded Easy recipes, side recovery flippers and a short upper paddle, Normal-flow banks/curves, optional Score Attack and the first three-Act Green Hill Zone. The original physics-playground entry point remains available. Free Play remains the default.

The scene wraps the existing sandbox and its generated layout. Original procedural checkerboard terrain, grass, palms, flowers, distant rocks, sunlight, rings, bumpers, and flippers dress the same playfield. Locally prepared Sonic Runners Sonic and Tails models supply table-aligned gameplay poses and upright character-study previews. Sonic adds a target-facing homing burst and contact impact; Tails uses his original two tail chains for flight. Character-special presentation is integrated on `main` alongside the shared gameplay hooks. The invisible 2D ball remains authoritative; the character and scenery are collisionless. A contact marker tracks the physical ball independently of the visual hop. Body placement, imported-model axis correction, and spin-ball rotation use separate transforms.

## Launch

Double-click **Play Green Hill.cmd** in this worktree's repository root. **Physics Playground.cmd** opens the original debugging presentation. Both launchers use the same physics, generator, profiles and scoring code. The selected character's local prepared model is reused automatically; preparation is not repeated at launch.

**Authored Acts:** use the footer's **Level source → Authored Act** or **Load Act…** to open a saved `.tres` inside this same application. The existing engine, ball, HUD, character, specials and camera stay alive; only the playfield is rebuilt. **Start / replay** reloads the active file. **Generated / Existing** returns to the remembered generated settings. Authored play uses Free Play; authored score gates and multiple Acts remain deferred. See [playfield sources](../../docs/PLAYFIELD_SOURCES.md) for the common contract, controls, direct `--act` startup and verification. The separate authored tester is diagnostic only.

**Green Hill Zone:** choose it in the shared mode dropdown, then **Start / replay**. Seed 18 has an input-only completion witness. Nine sections form one continuous Easy playfield, with score targets 750 / 1,250 / 1,750, locked gates, checkpoint retries, three Chao drafts and a final portal. Drafts pause the same ball in place; the last reward appears in the completion summary. Zone generation takes several seconds. Names, colored gates and portal are gameplay placeholders for later art. Use O for the full-course overview.

**Chao Lab v0:** the shared **Chao: … · Lab** button beside Start / replay opens three simple colored choices and effective-stat comparisons. Choose at serve or pause, then equip into a fresh run on the same seed. It respects the selected mode/target and keeps the equipped name visible with F1 hidden. Replay, drains and table changes retain one slot; the debug Practice toggle replaces that slot. Chao names/colors are placeholders; terrain and character assets are unchanged. See the main README for values and lifecycle rules.

Alternatively, run PowerShell from this worktree's repository root:

```powershell
.\experiments\visual_lab\launch.ps1
```

The launcher resolves a Godot executable, waits for a dedicated headless import and checks its diagnostics, then opens only `experiments/visual_lab/visual_lab.tscn`. It does not stop existing processes or change `project.godot`. If the selected character has not been prepared, the scene still opens with a clearly reported blue Sonic or orange Tails spin-ball fallback.

Windows launchers default to **ANGLE / Direct3D 11**, retaining Godot's Compatibility renderer. This avoids the native NVIDIA OpenGL path implicated in a reported access-violation crash during a Zone rebuild. For comparison, pass `-GraphicsBackend Native`; use `-GraphicsBackend Angle` to select the default explicitly. The game's current and previous launch logs are `.godot/green-hill-game.log` and `.godot/green-hill-game.previous.log`. A failed launch reports the backend, hexadecimal exit code and log path. No driver installation or project-setting change is required. See [Godot's driver documentation](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-rendering-gl-compatibility-driver-windows).

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
| Space / gamepad A | Use the selected character's special when the shared meter is ready |
| Escape / Menu | Pause or resume; leave character study |
| R / Back | Reset and relaunch |
| F1 / Tuning button | Open the complete existing physics, camera, seed and construction-grid controls |
| F4 | Cycle OFF, PIXEL / DITHER, N64-ish, CRT and VHS; custom stacks return to OFF |
| Retro... / Shift+F4 | Open live effect checkboxes and tuning sliders; F1 also has a multiselect menu. HUD stays crisp |
| O / Overview button | Toggle full-course overview and ball-follow camera |
| Normal 18 / Normal 23 | Build the requested catalogue layout while paused or at serve |
| Grid base / Grid variant | Switch middle type, preserving current seed and difficulty, while paused or at serve |
| C / Character close-up | Enter or leave the optional paused study pedestal |
| 1–4 in character study | Preview rolling, idle, jump and trick |
| 5 in character study | Preview Sonic homing or Tails flight |
| 6 in character study | Preview Sonic impact |

**Character selection:** choose Sonic or Tails in the shared character dropdown, then **Start / replay**. Selection starts a fresh run through the shared gameplay controller. Rings and bumper contacts charge the meter. Sonic's target marker follows the eligible target selected by gameplay; an impact reaction requires a real successful homing contact. Tails' flight pose lasts for the authoritative flight window, then blends back to the orange spin-ball.

The mode strip below the Green Hill title reuses the shared Free Play / Score Attack selector, score target and Start / replay action. Score Attack unlocks the upper goal at the chosen score and requires reaching it physically; the shared victory panel offers replay, next seed and Free Play. The Green Hill score card shows target progress and goal status. F1 preserves access to the same controls.

The quick-build buttons disable during live play. Use Escape first, build, then resume and launch. F1 provides any other seed, preference, profile, tuning or grid combination. Regeneration preserves tuning, camera settings, overlays and pause, resets the run, and rebuilds terrain from the final mirrored/shifted/shaped chunk outlines. Surviving bottom paddles and newly generated middle paddles bind to the new character adapter exactly once.

Ordinary gameplay defaults to the procedural spin-ball, including at serve. Real flipper strikes trigger a 0.62-second jump; bumper contacts trigger a 0.56-second trick. Both return to spin through a 0.12-second scale overlap. A 0.18-second event cooldown and suppression of repeated active reactions prevent contact callbacks from continually restarting the pose. Character-colored motion beads and expanding impact/pickup circles improve tracking. The physical-radius contact marker stays at the authoritative ball anchor. Ring collection retains the sandbox's 0.20-second attraction flight to that anchor. Cosmetic hops and animations never change physical position, momentum, collider size or scoring.

Pose previews are confined to character study so a forgotten preview cannot suppress gameplay feedback. Returning restores the previous pause state and automatic animation. Regeneration is unavailable during study.

Optional launch arguments:

```powershell
.\experiments\visual_lab\launch.ps1 -Seed 23 -Grid Variant
.\experiments\visual_lab\launch.ps1 -Character Tails
.\experiments\visual_lab\launch.ps1 -NoModel
.\experiments\visual_lab\launch.ps1 -Playground
```

`-Character` accepts `Sonic` or `Tails` (default Sonic). `-Grid` accepts `Catalogue`, `Base` or `Variant`; character/seed/grid options apply to Green Hill. Direct Godot launches can pass `-- --character=tails`. `-NoModel` verifies the procedural fallback without moving or deleting local assets. F5 in Godot still opens the original playground; F6 on `visual_lab.tscn` opens Green Hill.

## Table-relative character orientation

The presenter has explicit `SPIN`, `JUMP`, `TRICK`, `SHOWCASE`, `HOMING`, `IMPACT`, and `FLIGHT` states. Ordinary uncurled poses and flight point the head up-table (3D `-Z`), feet down-table (`+Z`), and front toward the board normal (`+Y`). Descending motion never flips that axis. Homing rotates the heading in the board plane toward gameplay's launch direction, while keeping the face outward; impact retains that heading. Character study retains the conventional upright model.

The existing `sonic_presenter.gd` / `SonicVisualAdapter` name is retained for compatibility, but the adapter handles both characters. It reads the target selected by `CharacterSpecials` and observes its character-change, homing-start/end, successful-hit and flight-start/end signals. Shared gameplay owns targeting, impulse, duration, meter, contact validation and scoring. Visual callbacks never move the ball or award a hit. Special poses take priority over ordinary flipper/bumper reactions, and cancellation clears the visual state.

`UncurledVisualAnchor` owns placement, cosmetic height and directional lean. Its child `ImportedModelAxisAlignment` rotates the imported model by -90 degrees about X for gameplay. The normalized one-metre model is centered by a local Y offset of -0.5 before that correction. The separate procedural spin-ball never rotates the uncurled rig.

Outside homing and impact, horizontal velocity supplies a smoothed in-plane lean, capped at ±23 degrees. The provisional dead zone is 45 px/s; full lean is reached at 650 px/s, with an exponential response rate of 10/s. Lean rotates around the board normal only. The body uses scale 0.85 and anchor height 0.40, with a visual-only sine hop of up to 0.12 for jumps or 0.06 for tricks. The previous Sonic jump/trick audit retained at least 0.088 units of board clearance at full scale; new rig depth bounds are recorded below. These values are presentation tuning, not collision or grounded/airborne rules.

## Prepare the local characters

Third-party archives, textures, models, prepared binaries, and captures are deliberately absent from Git. Read [ASSETS.md](ASSETS.md) and [asset_manifest.json](asset_manifest.json) before acquiring them. Obtain user approval before downloading a new external asset. The Tails archive used for this integration was explicitly approved. No paid services, add-ons, or asset-supplied scripts are required.

1. Download the approved ZIP from the corresponding source page in a browser:

| Character | Source | Local archive | SHA-256 |
| --- | --- | --- | --- |
| Sonic | [Sonic Runners — Sonic](https://models.spriters-resource.com/mobile/sonicrunners/asset/293026/) | `local/sonic.zip` | `4DE42CC9627DAEA795F6E4EDCB77A2BB5E44A11AED10C8968B977BB18E9DB2E8` |
| Tails | [Sonic Runners — Miles “Tails” Prower](https://models.spriters-resource.com/mobile/sonicrunners/asset/295033/) | `local/tails.zip` | `D81CA4D80D6B9D9C109933F578DEF4E59E9C2BE9EEED95A9969C22F422055F43` |

Browser downloads worked for this experiment; command-line fetching encountered a Cloudflare challenge. Do not bypass the site's controls or execute scripts from an archive.

2. From the worktree root, verify and extract the chosen archive locally. This example prepares Tails; substitute the Sonic name and hash from the table for Sonic:

```powershell
$characterName = 'tails'
$labPath = Join-Path (Get-Location) 'experiments\visual_lab'
$localPath = Join-Path $labPath 'local'
New-Item -ItemType Directory -Path $localPath -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $localPath '.gdignore') -Force | Out-Null
$archivePath = Join-Path $localPath "$characterName.zip"
$expectedHash = 'D81CA4D80D6B9D9C109933F578DEF4E59E9C2BE9EEED95A9969C22F422055F43'
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'Archive differs from the inspected version. Inspect the new archive before preparing it.'
}
Expand-Archive -LiteralPath $archivePath -DestinationPath (Join-Path $localPath "source\$characterName")
```

Each source directory must contain `chr_<character>.smd` and its adjacent body, eye and mouth diffuse PNGs. Nested archive folders are supported. Extract once; preparation can be rerun without extracting again.

3. Run the shared repository-authored Blender preparation script:

```powershell
$blenderPath = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $blenderPath --background --python-exit-code 1 --python '.\experiments\visual_lab\tools\prepare_character.py' -- --character tails
if ($LASTEXITCODE -ne 0) { throw 'Tails preparation failed; inspect Blender output.' }
& $blenderPath --background --python-exit-code 1 --python '.\experiments\visual_lab\tools\prepare_character.py' -- --character sonic
if ($LASTEXITCODE -ne 0) { throw 'Sonic preparation failed; inspect Blender output.' }
```

`tools/prepare_sonic.py` remains a compatible Sonic-only entry point. Add `--skip-renders` after Blender's `--` separator to export and audit without studio renders. Rebuild the local Sonic GLB once to obtain the new homing and impact clips.

Preparation reads SMD data directly, preserves the hierarchy and skin weights, assigns diffuse textures, normalizes standing height to one metre, and exports `local/runtime/<character>.glb`. It writes `local/<character>_prepared.blend`, `local/<character>_rig_report.json`, and `local/<character>_blender_<pose>.png` previews, including table-view special poses. Sonic also retains `local/rig_report.json` as a compatibility report. Existing prepared GLBs and Blender files are backed up under ignored `local/backups/` before replacement; original sources are not modified.

Sonic exports `idle`, `jump`, `trick`, `homing`, and `impact`; Tails exports `idle`, `jump`, `trick`, and `fly`. These are newly authored in-place clips, not animations recovered from the archives. The narrow reader requires exactly one source skeleton frame (`0`) and rejects an unexpected skin-weight assignment to the omitted implicit root. The inspected FBX version 6100 is unsupported by this Blender importer; the SMD route requires no add-on. `--python-exit-code 1` propagates preparation failures to the process exit code.

The `.gdignore` keeps original files and Blender sources out of Godot's import scan. The adapter loads each GLB at runtime with `GLTFDocument`, so this ignore file does not prevent the selected character from appearing. Run `launch.ps1` after preparation.

## Captures

Use a graphical Godot run for screenshots; headless execution cannot verify lighting or material appearance:

```powershell
.\experiments\visual_lab\launch.ps1 -Capture gameplay
.\experiments\visual_lab\launch.ps1 -Capture idle
.\experiments\visual_lab\launch.ps1 -Capture jump
.\experiments\visual_lab\launch.ps1 -Capture trick
.\experiments\visual_lab\launch.ps1 -Capture roll
.\experiments\visual_lab\launch.ps1 -Character Sonic -Capture homing
.\experiments\visual_lab\launch.ps1 -Character Sonic -Capture impact
.\experiments\visual_lab\launch.ps1 -Character Tails -Capture fly
.\experiments\visual_lab\launch.ps1 -Capture reel -Sequence
```

Each capture run opens its own lab process, freezes physics, saves the full window including the lab UI, then exits. The gameplay image uses the playfield camera and the spin-ball at serve. The pose and roll captures use the dedicated study pedestal. Single images use the capture kind as their filename, such as `captures/gameplay.png`, `homing.png` or `fly.png`. Single character images seek the pose to 0.55 seconds.

The launcher supplies Godot's `--fixed-fps 60` for capture runs. Sequence mode writes 48 images, sampled every four rendered frames, for a 15 fps presentation sequence. `-Capture reel -Sequence` writes `captures/reel_000.png` through `reel_047.png`: 12 idle frames, 12 jump frames, 12 trick frames, and 12 spin-ball frames. Passing `-Sequence` with another capture kind holds that view for the entire sequence. `-CaptureFrames` changes the initial warm-up from its default of 75 rendered frames. The scene creates `captures/.gdignore` so Godot does not import the rendered images. This delivers frame captures; no video encoding tool is required.

Captures are local and ignored because they contain the third-party character. Repeating a capture replaces files with the same names. Keep any captures you want to compare under a different local name first.

An optional local MP4 can be encoded with an already installed FFmpeg; this is not required to prepare or run the lab. With `ffmpeg` on `PATH`, run from the worktree root:

```powershell
ffmpeg -framerate 15 -i '.\experiments\visual_lab\captures\reel_%03d.png' -c:v libx264 -pix_fmt yuv420p -crf 19 -movflags +faststart '.\experiments\visual_lab\captures\visual_lab_reel.mp4'
```

The delivered local `captures/visual_lab_reel.mp4` was verified with FFprobe: H.264, 1280 × 900, 48 frames at 15 fps, 3.2 seconds. It remains ignored along with the source frames.

## Rig and animation status

Both inspected SMDs contain only skeleton frame `0`; **neither archive supplies a usable source animation clip**. The imported hierarchy and authored skin weights are preserved. Neither model uses animation root motion to control the ball.

| Audit | Sonic | Tails |
| --- | --- | --- |
| Retained bones | 54 | 61 |
| Unique vertices | 2,211 | 2,605 |
| Triangles | 3,318 | 3,782 |
| Material assignments | 5 | 5 |
| Unweighted vertices | 0 | 0 |
| Maximum weight-sum error | approximately 0.000001 | approximately 0.000001 |
| Identity-pose skin error | approximately 0.000000181 m | approximately 0.000000179 m |
| Maximum rest-matrix element error | approximately 0.00000780 | approximately 0.000000924 |

The newly authored idle, jump, trick, homing and impact clips use held poses with a small one-second variation. Tails' one-second flight loop rotates his actual two tail chains at two revolutions per second. The left and right chains each contain four bones (`Tail1` through `Tail4`) and influence 131 unique vertices, with no tail vertices blended onto body bones. The preparer derives each chain's direction from its measured first two joints, spreads the tails into opposite blades, and rotates only `Tail1_L` and `Tail1_R`. The internal `Tail2`–`Tail4` rotation deltas remain at rest. Relaxed poses move each complete tail chain beside the legs rather than leaving the source's long rearward tails through the board.

Export validation checks every one-second clip for endpoint continuity and rejects rotation mismatch over 0.1 degrees or translation drift over 0.00001 m. The final Tails flight export loops within 0.000023 degrees, with maximum translation jitter approximately 0.000000079 m.

The flight audit samples 24 rotor phases. Its normalized Godot-Z depth envelope is approximately -0.2034 to +0.3154 m; the relaxed poses reach -0.3054 m. These bounds help select visual clearance above the board, independently of the authoritative ball radius. Runtime and rendered checks remain necessary because sampled bounds do not establish transition quality or camera readability.

Tails' diffuse PNGs and `_a` variants all have opaque alpha. The DAE binds the diffuse images; the grayscale `_a` auxiliary maps are not used as transparency masks. Body, eye, mouth and metal material assignments retain the inspected diffuse mapping.

The pose script expresses rotations in each bone's rest-frame axes, carried by animated parents. Fingers keep their imported open-hand transforms: earlier invented finger curls deformed the mesh sideways and were removed. These are readable prototype poses, not a polished close-up animation set. Numerical deformation checks and rendered joint review complement one another; inspect shoulders, elbows, hips, knees and both tail attachments.

## Character-special checks and live captures

The focused checks are separate from the earlier verification records below:

```powershell
godot --headless --fixed-fps 120 --path . --script res://experiments/visual_lab/special_visual_smoke.gd
godot --headless --fixed-fps 120 --path . --script res://experiments/visual_lab/special_visual_smoke.gd -- --no-model
godot --rendering-method gl_compatibility --rendering-driver opengl3_angle --fixed-fps 120 --path . --script res://experiments/visual_lab/special_play_capture.gd -- --character=sonic --mode=2 --seconds=180 --screenshots
godot --rendering-method gl_compatibility --rendering-driver opengl3_angle --fixed-fps 120 --path . --script res://experiments/visual_lab/special_play_capture.gd -- --character=tails --mode=0 --seconds=180 --screenshots
```

The visual smoke check uses controlled fixtures to inspect state transitions, rig animation, orientation and separation from physics. The live capture survey starts at the normal serve and uses ordinary launch, steering, flipper and special requests. It must earn meter through play; it does not inject score, meter, velocity or position. Its screenshots and sequence frames are written under ignored `captures/specials/`. They are distinct from the paused study and serve-composition captures described above.

Verified on 2026-10-23 against PhysicsBro's committed homing lifecycle API (`e5bc124`), using Godot 4.7.2 and the final local exports:

- Special visual smoke: **13/13 with models**, **13/13 with `--no-model`**. Includes real 2D contact, both tail roots, retained child-joint poses, unchanged gameplay state, pause, expiration, reset/drain and regeneration listener cleanup.
- Existing orientation smoke: **13/13**; visual smoke: **19/19**; shared Character Lab regression: **70/70**. The obsolete hidden-Sonic placeholder assertion now verifies the selected orange Tails presenter.
- Headless editor import passed. The actual `-Character Tails -Capture fly` launcher completed with ANGLE, and its full-window study was reviewed.
- Input-only graphical witnesses earned Sonic's meter in Green Hill Zone and Tails' meter in Free Play, both Easy seed 18. Sonic hit the selected bumper for the shared 5× bonus and returned to blue spin. Tails showed two rotor phases, completed flight, and returned to orange spin. Screenshots and short MP4 sequences were reviewed; both runs stayed inside the table.
- Prepared GLBs pass skin/rest-pose checks and exported-animation loop/translation checks. Source archives, textures, prepared models, reports and captures remain ignored.

Local live-play outputs are `captures/specials/sonic_homing.png`, `sonic_impact.png`, `sonic_return_to_spin.png`, `tails_flight_a.png`, `tails_flight_b.png`, `tails_return_to_spin.png`, and the corresponding `sonic_homing_gameplay.mp4` / `tails_flight_gameplay.mp4`. JSON reports beside them identify each mode and input witness. The fixed input policy did not land a Sonic special hit in its initial 180-second Free Play run; the Zone witness supplies the successful contact capture. These are reproducible examples, not player success-rate or feel measurements. Earlier dated results below cover their stated revisions.

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

The original Sonic-only lab passed headless import, JSON/PowerShell syntax checks, **19/19** visual checks, **38/38** physics checks, profile regression and normal-sandbox startup. Blender joint renders, Godot close-ups and the 48-frame reel were reviewed. One graphical process exited with Windows code `-1073740791` without a script diagnostic; isolated and final retries succeeded, and the cause was not established. Third-party files and captures were confirmed ignored.

These are historical baseline results. Run current commands from this visual worktree, using the Godot executable described under Launch.

## Short visual/playtest checklist

- Confirm textured eyes, mouth, gloves, shoes, and body for both characters; inspect joints and both Tails tail attachments.
- Earn a full meter, use Sonic's homing attack and Tails' flight, and check target heading, impact timing, tail rotation and return to the correctly colored spin-ball.
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
