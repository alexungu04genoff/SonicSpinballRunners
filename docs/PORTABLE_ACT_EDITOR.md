# Portable Windows Act Editor

The portable build opens the Act Geometry Editor and embeds project resources in `Act Editor.exe`. Godot does not need to be installed on the destination Windows x64 computer. Keep any DLLs produced by the exporter beside the executable.

Put the build in a writable folder. The editor creates an `Acts` folder beside the executable for Load and Save As. If that folder cannot be created, the dialogs default to Documents. Save levels as `.tres` files and copy them back to the main project when finished.

Save the current Act, then click **Play** to open the normal authored player in a separate window. After saving further changes, use **Reload Act** in the player. The Play button requires a saved Act with no pending edits. Existing example buttons still open editable copies. **Bake** remains an optional separate process for Endless preparation.

## Build

Run from the repository with Godot 4.7.2 and its Windows x64 release export template:

```powershell
& '.\tools\export_act_editor.ps1' -WindowsTemplate 'C:\Tools\windows_release_x86_64.exe'
```

The script snapshots current local sources, including untracked Acts and art, into an ignored build directory. It imports and exports that snapshot without changing the working project's main scene or editor settings. The build uses Compatibility/ANGLE, preserves text Act resources, and includes editable copies of current `data/acts/*.tres` files. Output is under `test-results/portable-build/Portable Act Editor`, with a ZIP alongside that directory.

Run the exported save/load smoke check with `"Act Editor.exe" --headless -- --portable-smoke`. It creates a uniquely named temporary Act, reloads it, starts the actual player with it, checks the fingerprint, and removes that temporary file. Omitting `--headless` also captures editor and player images in the application's user data directory. Release builds route Play and Bake through application arguments because editor-only scene-selection flags are unavailable. Also test a visible launch before transferring the build to another computer.

Verified on 2026-10-26: 92 editor interaction checks passed; source and exported external save/reload/player checks passed; exported Compatibility/ANGLE captures of both the editor and player were inspected. Exported checks ran with a working directory outside the project. The standalone player route also loaded an external copy of Second Simple successfully. The destination laptop and exported Bake workflow have not been tested.
