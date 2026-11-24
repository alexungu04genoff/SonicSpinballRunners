"""Build the offline Windows playtest ZIP from a baked, imported working tree."""

import argparse
import os
import re
import zipfile
from pathlib import Path
from tempfile import NamedTemporaryFile


ROOT = Path(__file__).resolve().parents[1]
ART = Path("experiments/visual_lab/local")
GUEST = Path("test-results/team-eggman-source-review")
SCENES = {
    "Play": "prototype_run",
    "Play Endless": "endless_runner",
    "Act Geometry Editor": "act_geometry_editor",
}
SOURCE = {".gd", ".gdshader", ".gdshaderinc", ".tscn", ".tres"}
RESOURCES = SOURCE | {".cfg", ".res", ".uid", ".png", ".svg", ".json", ".import", ".txt", ".md"}
EXTERNAL_RESOURCE = re.compile(r"""res://((?:experiments|tests)/[^"'\r\n]+?\.(?:gd|gdshaderinc|gdshader|tscn|tres|png|svg))["']""")
RELATIVE_RESOURCE = re.compile(r"""(?:\b(?:preload|load)\(\s*|#include\s+|^extends\s+)["']([^:"'\r\n]+)["']""", re.MULTILINE)
IMPORT_TARGET = re.compile(r'res://(\.godot/imported/[^"]+)')


def game_files():
    files = {Path("project.godot"), Path(".godot/global_script_class_cache.cfg"),
             Path(".godot/uid_cache.bin"), Path(".godot/.gdignore"), ART / ".gdignore"}
    for folder in ("assets", "data", "scenes", "scripts", "third_party"):
        files.update(path for path in Path(folder).rglob("*") if path.suffix in RESOURCES
                     and path.is_file() and (path.suffix != ".import" or path.with_suffix("").is_file()))

    # The live presentation and some built-in tools reference resources outside the main folders.
    pending = [path for path in files if path.suffix in SOURCE]
    while pending:
        source = pending.pop()
        content = source.read_text(encoding="utf-8-sig")
        dependencies = [Path(match) for match in EXTERNAL_RESOURCE.findall(content)]
        dependencies.extend(Path(os.path.normpath(source.parent / match)) for match in RELATIVE_RESOURCE.findall(content))
        for dependency in dependencies:
            if dependency in files or not dependency.is_file():
                continue
            files.add(dependency)
            if dependency.suffix in SOURCE:
                pending.append(dependency)
            for suffix in (".uid", ".import"):
                sidecar = Path(str(dependency) + suffix)
                if sidecar.is_file():
                    files.add(sidecar)

    for descriptor in [path for path in files if path.suffix == ".import"]:
        for target in IMPORT_TARGET.findall(descriptor.read_text(encoding="utf-8-sig")):
            cache = Path(target)
            files.add(cache)
            # GPU-specific textures can have an extra suffix ahead of .ctex.
            for digest in (cache.with_suffix(".md5"), cache.with_suffix("").with_suffix(".md5")):
                if digest.is_file():
                    files.add(digest)

    runtime = ART / "runtime"
    rigs = ART / "runners-decomp"
    for character in sorted(path.stem for path in Path("data/characters").glob("*.tres")):
        if character == "sage":
            files.add(ART / "sage-flight-study/game/sage.glb")
            files.update((ART / "sage-flight-study/game").glob("*.png"))
            continue
        for suffix in (".glb", ".low.glb", ".png"):
            files.add(runtime / (character + "_runners_poses" + suffix))
        for suffix in (".glb", ".low.glb"):
            files.add(rigs / character / (character.capitalize() + " Runners - original animations" + suffix))
    files.update((runtime / "sonic_sa1_combo.glb", runtime / "shadow_boost_fit.json",
                  runtime / "sonic.glb", runtime / "tails.glb"))
    for badnik in ("beeton", "eggpawn", "ganigani"):
        files.add(rigs / badnik / (badnik.capitalize() + " Runners - original animations.glb"))
    for species in ("flicky", "picky", "pecky", "pocky", "ricky", "rocky", "cookie"):
        files.add(rigs / species / "Runners animal.glb")
    # Guest preview models live outside the playable roster.
    for model in ("bomb", "eggmobile", "metal", "metal_runners_poses"):
        for suffix in (".glb", ".low.glb"):
            files.add(GUEST / (model + suffix))
    files.add(GUEST / "metal_runners_poses.png")
    return files


def launcher(scene):
    return rf"""@echo off
setlocal DisableDelayedExpansion
set "engine="
if /i "%~x1"==".exe" (
    if exist "%~f1" set "engine=%~f1"
    goto validate
)
if exist "%~dp0Godot.exe" set "engine=%~dp0Godot.exe"
if not defined engine for %%G in ("%~dp0Godot_v4.7.2-stable_win*.exe") do if exist "%%~fG" set "engine=%%~fG"
if not defined engine if defined GODOT4_EXE if exist "%GODOT4_EXE%" set "engine=%GODOT4_EXE%"
if not defined engine if exist "%ProgramFiles%\Godot\Godot.exe" set "engine=%ProgramFiles%\Godot\Godot.exe"
if not defined engine for %%G in (godot.exe godot4.exe) do if not "%%~$PATH:G"=="" set "engine=%%~$PATH:G"
:validate
if not defined engine goto missing
"%engine%" --version | "%SystemRoot%\System32\findstr.exe" /b /l /c:"4.7.2." >nul
if errorlevel 1 (
    echo These level bakes require Godot 4.7.2. Drag that Godot executable onto this launcher.
    pause
    exit /b 1
)
if /i "%~x1"==".exe" goto dragged
"%engine%" --path "%~dp0Game" --fullscreen res://scenes/{scene}.tscn %*
goto finished
:dragged
"%engine%" --path "%~dp0Game" --fullscreen res://scenes/{scene}.tscn
:finished
set "result=%errorlevel%"
if not "%result%"=="0" pause
exit /b %result%
:missing
echo Extract the whole ZIP first. Drag your Windows Godot 4.7.2 executable onto this launcher.
pause
exit /b 1
"""


README = """Sonic Spinball Runners | Windows laptop playtest

Extract the entire ZIP into a writable folder. Drag your Windows Godot 4.7.2
executable onto Play.bat. If Godot.exe is in this folder, on PATH, or in the
standard Program Files/Godot folder, just double-click Play.bat.
You can also point GODOT4_EXE at an existing Godot 4.7.2 executable.

Play.bat opens the Prototype menu. Pick a character, then start a run.
Play Endless.bat starts the streaming mode. Act Geometry Editor.bat opens
the editor, where Play launches the current saved Act. All three use your
existing Godot and start fullscreen. F11 toggles fullscreen during gameplay.

Q / E         Left / right flipper       Arrow keys    Steer
X             Launch                     Space         Character special
R             Retry checkpoint           Enter / Esc   Pause

The game includes the authored Acts, theme bakes, character rigs and wildlife.
The menu has ten playable characters. Eggman and Metal Sonic are included as
preview model files. Forward+ uses Vulkan, and the game has a laptop quality
preset. The first run may take longer while the graphics driver warms up.
Settings and run history are saved in your normal Godot user-data folder.
"""


def windows_text(text):
    return text.replace("\n", "\r\n").encode("utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Destination ZIP path")
    output = parser.parse_args().output.resolve()
    os.chdir(ROOT)
    files = game_files()
    missing = sorted(path for path in files if not path.is_file())
    if missing:
        raise SystemExit("Missing required game files:\n" + "\n".join(map(str, missing)))
    if not Path("data/endless/themes.bake/green_hill.res").is_file():
        raise SystemExit("Run the Prototype and Endless bakers before packaging.")
    output.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=output.parent, suffix=".zip", delete=False) as temp:
        temporary = Path(temp.name)
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=5) as archive:
            for name, scene in SCENES.items():
                archive.writestr(name + ".bat", windows_text(launcher(scene)))
            archive.writestr("Read me.txt", windows_text(README))
            # The bake fingerprint includes texture directories even when they contain no files.
            for directory in sorted(path for path in Path("assets").rglob("*") if path.is_dir()):
                archive.write(directory, "Game/" + directory.as_posix() + "/")
            for path in sorted(files):
                archive.write(path, "Game/" + path.as_posix())
        with zipfile.ZipFile(temporary) as archive:
            bad = archive.testzip()
            if bad:
                raise SystemExit("ZIP integrity check failed for " + bad)
        temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"{output} ({output.stat().st_size:,} bytes, {len(files)} game files)")


if __name__ == "__main__":
    main()
