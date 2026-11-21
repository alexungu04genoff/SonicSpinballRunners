"""Build the Tuesday direct-EXE package from a locally imported, baked checkout."""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path("C:/Program Files/Godot/Godot.exe")
COMPILER = Path("C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe")
THEMES = ("green_hill", "casino_night")
CODE = {".gd", ".uid", ".gdshader", ".gdshaderinc", ".tscn", ".tres", ".cfg"}


def payload():
    paths = {Path("project.godot"), Path("tests/laptop_depth_matrix.gd")}
    roots = ("assets", "data", "scripts", "scenes", "third_party", "tests", "experiments")
    tracked = subprocess.check_output(["git", "ls-files", "-z", "--", *roots], cwd=ROOT).decode("utf-8")
    for name in filter(None, tracked.split("\0")):
        path = Path(name)
        if path.parts[0] in ("experiments", "tests") and path.suffix not in CODE:
            continue
        if "green_hill_floor" in path.parts or path.suffix in (".ps1", ".cmd", ".bat", ".pyc"):
            continue
        paths.add(path)
        descriptor = Path(str(path) + ".import")
        if (ROOT / descriptor).is_file():
            paths.add(descriptor)
    for descriptor in [p for p in paths if p.suffix == ".import"]:
        for imported in re.findall(r'res://(\.godot/imported/[^"\s]+)', (ROOT / descriptor).read_text("utf-8")):
            paths.add(Path(imported))
    for name in (".gdignore", "global_script_class_cache.cfg", "uid_cache.bin"):
        paths.add(Path(".godot") / name)
    bank = ROOT / "data/endless/assets.bake"
    paths.update(p.relative_to(ROOT) for p in bank.iterdir() if p.is_file())
    for theme in THEMES:
        paths.add(Path("data/endless/themes.bake") / (theme + ".res"))
        paths.add(Path("data/acts/Authored/First Try Smooth Decor.bake") / (theme + ".res"))
        for act in (ROOT / "data/endless").glob("*.tres"):
            paths.add(act.with_suffix(".bake").relative_to(ROOT) / (theme + ".res"))
    return sorted(paths)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--engine", type=Path, default=ENGINE)
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        launcher = temp / "Run Tuesday Depth Matrix.exe"
        licenses = temp / "GODOT LICENSES.txt"
        sources = ROOT / "tools/no_shell_grounding"
        refs = ("System", "System.Core", "System.Drawing", "System.Windows.Forms", "System.Web.Extensions", "System.Management")
        subprocess.run([str(COMPILER), "/nologo", "/target:winexe", "/platform:x64", "/optimize+",
                        "/define:TUESDAY", "/out:" + str(launcher), "/win32manifest:" + str(sources / "app.manifest"),
                        *["/reference:" + ref + ".dll" for ref in refs], str(sources / "Launcher.cs")], check=True)
        subprocess.run([str(args.engine), "--headless", "--path", str(ROOT), "--script",
                        "res://tools/write_engine_licenses.gd", "--", str(licenses)], check=True)
        files = [(p.as_posix(), ROOT / p) for p in payload()]
        files.extend([("Sonic Spinball Runners.exe", args.engine), (licenses.name, licenses)])
        manifest = []
        # A partial archive stays separate if an import, bake or disk write fails.
        partial = output.with_suffix(".partial.zip")
        if output.exists():
            raise FileExistsError(output)
        with zipfile.ZipFile(partial, "x", zipfile.ZIP_DEFLATED, compresslevel=2) as archive:
            for name, source in files:
                content = source.read_bytes()
                archive.writestr("Frozen Payload/" + name, content)
                manifest.append({"path": name, "sha256": hashlib.sha256(content).hexdigest().upper()})
            archive.writestr("payload-manifest.json", json.dumps({"source_head": head, "files": manifest}))
            archive.write(launcher, launcher.name)
            archive.write(ROOT / "docs/TUESDAY_LAPTOP_DEPTH.md", "Read me.md")
        partial.rename(output)
        print(f"{output} ({output.stat().st_size:,} bytes, {len(files)} verified payload entries)")


if __name__ == "__main__":
    main()
