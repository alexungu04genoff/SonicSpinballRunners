# Green Hill Visual Lab

A separately runnable presentation experiment for the committed sandbox snapshot `a099f340bf7d54ce779fc37375123adb73faf832`. The experiment lives on `experiment/green-hill-visual-lab`; it does not change the normal project entry point. It is not a new zone, progression system, or physics redesign.

The scene wraps the existing sandbox and its generated layout. Original procedural checkerboard terrain, grass, palms, flowers, distant rocks, sunlight, rings, bumpers, and flippers dress the same playfield. A locally prepared Sonic Runners model supplies upright poses. The invisible 2D ball remains authoritative; the character and scenery are collisionless. A contact marker tracks the physical ball independently of the visual hop. Upright poses and spin-ball rotation use separate transforms.

## Launch

Run PowerShell from this worktree's repository root:

```powershell
.\experiments\visual_lab\launch.ps1
```

The launcher resolves a Godot executable, registers script classes in a dedicated headless import process, then opens only `experiments/visual_lab/visual_lab.tscn`. It does not stop existing processes or change `project.godot`. If Sonic has not been prepared, the scene still opens with a clearly reported spin-ball fallback.

To choose the exact executable used for this experiment:

```powershell
.\experiments\visual_lab\launch.ps1 -GodotPath 'C:\Users\Alex\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
```

Discovered tools: **Godot 4.7.2 stable**, **Blender 5.2.3 LTS**. The launcher also checks Godot on `PATH` and `C:\Program Files\Godot\Godot.exe`; pass `-GodotPath` for reproducible version selection. Import-only mode is available as `-ImportOnly`. Godot can return a successful process exit code despite script errors, so inspect its output as well.

| Control | Action |
| --- | --- |
| Enter | Launch the served ball |
| Q / E | Left / right flippers |
| Left / right arrows | Existing limited steering |
| 1 / Rolling button | Show the spin-ball and re-enable automatic jump/trick events during gameplay |
| 2 / Idle button | Hold the idle preview |
| 3 / Jump button | Hold the jump preview |
| 4 / Trick button | Hold the trick preview |
| C / camera button | Enter or leave the dedicated character-study pedestal; study mode pauses physics |
| Escape | Pause gameplay, or leave the close-up |
| R | Reset the existing sandbox |

Automatic presentation uses a brief jump after a flipper strike and a brief trick after a bumper hit. A manual preview overrides those events until `1` is pressed. Idle, jump, and trick preview clips loop while physics is paused. The spin-ball also rotates in the paused study view. The dedicated close-up moves only the character visual onto a study pedestal with its own foot shadow; the physical ball and its contact marker remain at their actual playfield position. Returning from the close-up restores the prior pause state and automatic event presentation.

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

Each capture run opens its own lab process, freezes physics, saves the full window including the lab UI, then exits. The gameplay image uses the playfield camera and idle Sonic at the served ball. The pose and roll captures use the dedicated study pedestal. Single images are `captures/gameplay.png`, `idle.png`, `jump.png`, `trick.png`, and `roll.png`. Single character images seek the pose to 0.55 seconds.

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

## Verification performed — 2026-10-22

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
- Leave the lab and run the ordinary project entry point; mechanics work should continue in its own checkout.

Feel, flipper timing, camera readability, and final art direction still need user playtesting. The verification above records the checks actually run; it does not establish production readiness or asset redistribution permission.
