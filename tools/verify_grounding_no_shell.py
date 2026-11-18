"""Build-machine verification of the frozen direct-EXE package (stdlib only)."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile


def verify(original: Path, package: Path, extracted: Path) -> dict:
    manifest = json.loads((extracted / "payload-manifest.json").read_text(encoding="utf-8-sig"))
    expected = {row["path"]: row for row in manifest["files"]}
    original_hash = hashlib.sha256(original.read_bytes()).hexdigest().upper()
    assert original_hash == manifest["original_zip_sha256"]
    with zipfile.ZipFile(original) as before, zipfile.ZipFile(package) as after:
        prefix = "Sonic Spinball Grounding 2026-11-19/"
        originals = {name[len(prefix):]: name for name in before.namelist() if not name.endswith("/")}
        assert set(originals) == set(expected) | set(manifest["omitted_shell_and_build_tools"])
        assert not [name for name in after.namelist() if name.lower().endswith((".cmd", ".bat", ".ps1"))]
        for path, entry in expected.items():
            frozen = before.read(originals[path])
            assert frozen == after.read("Frozen Payload/" + path), path
            assert frozen == (extracted / "Frozen Payload" / path).read_bytes(), path
            assert hashlib.sha256(frozen).hexdigest().upper() == entry["sha256"], path
            assert len(frozen) == entry["bytes"], path
        matrix_source = before.read(prefix + "tools/run_grounding_matrix.ps1").decode("utf-8-sig")
    jobs = re.findall(r"@\{name='([^']+)';runtime='([^']+)';quality='([^']+)';renderer='([^']+)';detailed=\$(true|false)\}", matrix_source)
    plans = sorted((extracted / "Results").glob("Work-Laptop-*/command-plan.json"))
    assert plans, "Run the extracted matrix launcher with --verify-only first."
    plan_path = plans[-1]
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    assert len(jobs) == len(plan) == 8
    for source, actual in zip(jobs, plan):
        name, runtime, quality, renderer, detailed = source
        assert actual["name"] == name
        assert actual["timeout_seconds"] == (420 if renderer == "gl_compatibility" else 240)
        assert actual["detailed"] == (detailed == "true")
        arguments = list(actual["arguments"])
        if "--position" in arguments:
            position = arguments.index("--position")
            del arguments[position:position + 2]
        frozen_arguments = [
            "--path", str(extracted / "Results/Runtime"), "--rendering-method", renderer,
            "--rendering-driver", "opengl3_angle" if renderer == "gl_compatibility" else "vulkan",
            "--script", "res://tests/grounding_lab.gd", "--", "--seed=18", "--retro=production",
            "--profile-stages", "--grounding-lab", "--grounding-task=matrix", "--grounding-runtime=" + runtime,
            "--theme=rooftop_run", "--grounding-quality=" + quality, "--grounding-seconds=2.5",
            "--output=" + str(plan_path.parent / name),
        ]
        if quality == "balanced-no-retro":
            frozen_arguments.append("--grounding-retro=off")
        if quality == "reduced-retro":
            frozen_arguments.append("--grounding-retro=n64")
        if detailed == "true":
            frozen_arguments.append("--grounding-detailed")
        assert arguments == frozen_arguments, (name, arguments, frozen_arguments)
    return {"original_zip_sha256": original_hash, "payload_files": len(expected),
            "payload_mismatches": 0, "exact_frozen_matrix_cases": len(jobs), "shell_files": 0,
            "note": "Archive/extraction/command-plan verification; execution receipts are separate."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original", type=Path, required=True)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--extracted", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.original.resolve(), args.package.resolve(), args.extracted.resolve()), indent=2))
