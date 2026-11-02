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
