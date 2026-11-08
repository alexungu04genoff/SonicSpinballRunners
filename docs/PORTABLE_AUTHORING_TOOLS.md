# Geometry Editor and Atmosphere Lab

Extract the ZIP into a writable folder on a Windows x64 PC with a Vulkan-capable
graphics driver. Keep **Geometry Editor.exe** and **Atmosphere Lab.exe** together.
Neither executable needs Godot or the repository installed.

On first launch, the tools create shared **Acts** and **Atmospheres** folders
beside the EXEs, copying the included Acts, scenery sidecars and production
atmospheres. Later launches only add missing files; existing edits are preserved.
Back up these folders before replacing or moving your tools.

## Geometry Editor

Use Load and Save As to edit `.tres` files in **Acts**. The latest editor includes
drag-box selection, Ctrl-click/add selection, group move/delete/undo, and separate
**Show decor** and **Show gameplay** toggles. Save the Act before clicking **Play**;
the separate player supports **Reload Act** after further saves.

## Atmosphere Lab

The Lab starts on the editable **Acts/Authored/First Try Smooth Decor.tres** copy.
Use **Load Act** to inspect another saved level, or **Reload Act** after editing
it in Geometry Editor. Theme selection, lighting, sky, palette, selective hue,
glow, fog and scenery controls are included.

For the work-laptop shadow experiment, open **Shadows** and scroll to **Device
Shadow Quality**. Change **Resolution** (2048 / 4096 / 8192), **Cascades**
(1 / 2 / 4), and **Smooth shadows · Ultra + FXAA** independently, without a
restart. Turn **VSync** off to compare uncapped FPS. The active choices appear
below the controls; no-preference defaults remain 8192 / 4 with project filtering.
Try 8192/4, 4096/4, 4096/2, 2048/2 and 4096/1 with the same view and atmosphere.

Device graphics save immediately to `graphics_settings.cfg` in
`%APPDATA%\Godot\app_userdata\Sonic Spinball Authoring Tools`, independently of
portable Atmospheres and Lab drafts. **Save / Reload / Reset / Show Original**
affect atmosphere only. **Play Prototype** uses the same device preferences in
its separate process. No Godot installation is required. Judge quality and
performance on the laptop; these options do not select new production defaults.

- **Save Variant** writes the selected Theme's `.cfg` in **Atmospheres**.
- **Scenery Save** writes a `.scenery.cfg` beside the loaded Act.
- **Lab draft Save** stores local drafts in
  `%APPDATA%\Godot\app_userdata\Sonic Spinball Authoring Tools`.
- **F6** toggles the inspector. Mouse wheel zooms; middle-drag pans.

Return edited `.tres` files and their `.scenery.cfg` sidecars to the project's
`data/acts` folder. Return production atmosphere `.cfg` files to
`data/atmospheres`. Refresh game bakes after geometry/scenery changes; previously
exported games are not updated automatically.

Both EXEs embed current project resources and local artwork. First-use graphics
shader compilation may pause briefly. If the tools cannot create their data
folders, move them to a writable location and reopen them.

The November 5 traversal refresh includes per-rail **Terrain clearance**, flipper
**Length multiplier** (1–2×), and **Teleporter** with a draggable OUT marker.
`Acts/Experiments/Traversal Diagnostic.tres` demonstrates all three. Play uses
the actual Prototype session. Save new work with this format-19 editor; older
builds cannot read the new format. Existing Acts load without a source rewrite
until you explicitly save them.

## Foreground performance comparison

For the separate pixel-cost experiment, use **Compare Prototype pixels.cmd**.
In the running Prototype, **F6** cycles MSAA 4× / Off / 2× and **F7** cycles native
3D scale 100% / 75% / 85%. The overlay shows both current values. These choices
last only for that process and never save to device preferences or Atmospheres.
Ordinary launches remain 4× / 100%. Keep scale at 100% when comparing MSAA, and
MSAA at 4× when comparing scale. Use the same camera/Act and wait after each switch.
Keep shadow resolution, cascades, Retro and atmosphere fixed; disable Smooth
Shadows before primary MSAA comparisons because it also enables FXAA. Existing
device shadow preferences still apply. HUD/text resolution is unchanged.
The developer keys apply to Prototype/Endless only; the Lab retains its F6 inspector
shortcut. Desktop findings and native comparison paths are in `docs/PIXEL_COST_AUDIT.md`
in the repository; laptop performance and moving-edge quality still need validation.

Use **Compare Prototype legacy.cmd** and **Compare Prototype conservative.cmd**
one at a time. Both open the actual Prototype menu with seed 18 and Green Hill
Default. Choose the same Act pool, character, Practice/Challenge mode and graphics
settings in both runs. Wait until preparation settles, then compare the same
served-ball view, joins and overview. Restart repeats the seed. The ordinary
executables use conservative foreground contribution by default.

These portable comparisons construct their resident Acts from the bundled source
(`--no-bakes`), because the authoring ZIP intentionally excludes disk recipes.
The same contribution policy runs on source-built and disk-baked Acts. The
standard repository Prototype still requires its validated disk bakes. Standalone
editor Play loads only one Act, so it is a control workload rather than the main
multi-resident optimization test.

The development argument is `--foreground-contribution=legacy` or
`--foreground-contribution=conservative`, after Godot's `--` separator. It changes
only foreground visibility. Active Acts, camera-visible neighbors, possible
shadow contributors and transfer/warmup safety states stay visible. Residency,
physics, gameplay and background crossfades remain live. Unknown deformation
bounds retain rendering conservatively.

Keep device shadow settings, window size, render scale and atmosphere identical.
World MSAA remains **4×**; this pass does not change it. Laptop results must be
measured on the laptop; the development machine's timings are not predictions.
