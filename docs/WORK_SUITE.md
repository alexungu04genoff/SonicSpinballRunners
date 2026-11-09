# Sonic Spinball Work Suite

Extract the entire ZIP to a new writable folder. Keep all files together.
No Godot installation or repository checkout is required: the Windows EXE,
current resources, imported assets and both baked pools are included.

## Start here

- **Play Prototype.cmd**: the normal configurable roguelite run.
- **Play Endless.cmd**: the separate streaming and presentation stress test.
- **Act Geometry Editor.cmd**: edit Acts, then Save and Play from the editor.
- **Atmosphere Lab.cmd**: lighting, sky, palettes, glow, fog and scenery editing.
- **Visual Lab.cmd**: character and presentation tuning.
- **Bake Prototype.cmd** and **Bake Endless.cmd**: refresh the corresponding pool
  after geometry, scenery or material changes. Wait for the bake window to close.
- **Bake Saved Act.cmd**: select an individual saved Act to bake.

Normal Retro is ON. The revised textures and all eight current Default
atmospheres are included. Device graphics remain adjustable for the work laptop.
First use can compile graphics pipelines; let preparation finish before judging
performance.

## Keep your work

This is a writable workspace, so baking and editing use the same files as play.
Authored Acts are in `data/acts/Authored`; the existing Endless roster uses
`data/endless`. These are separate pools. Atmospheres are in `data/atmospheres`.
Save new Acts in the authored folder to include them in the Prototype menu.
Use the editor's Play button for a single saved Act. Back up the whole extracted
folder, or at least your edited Acts, their scenery sidecars and atmospheres.

Do not run from inside the ZIP or copy only the EXE. Close running games before
rebaking their pool. No cloud connection is needed to play after downloading.

The bundled EXE is the existing Godot engine running this project. It also makes
the authoring and baking workflows available without a separate installation.
