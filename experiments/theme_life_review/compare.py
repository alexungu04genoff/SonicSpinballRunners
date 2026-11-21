"""Validate matched Prototype captures and encode six seconds per theme."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "test-results/motion-final"
MEDIA = ROOT / "docs/theme-life/production-review"
THEMES = {
    "rooftop_run": ("Rooftop Run", "A", "clock hands"),
    "casino_night": ("Casino Night", "B", "large rotating stars"),
    "sky_sanctuary": ("Sky Sanctuary", "A", "cloud-bank drift"),
}


def receipt(folder):
    data = json.loads((folder / "receipt.json").read_text(encoding="utf-8"))
    fixture = data["fixture"]
    assert not data["errors"] and fixture["authority"] == "Prototype"
    assert (fixture["disk_acts"], fixture["disk_themes"], fixture["fallback_builds"]) == (1, 1, 0)
    assert fixture["seed"] == 18 and len(fixture["retro_effects"]) == 3
    return data


def encode(theme, current, candidate, label):
    title, state, _ = THEMES[theme]
    # Each 1280 x 900 game image retains its native presentation and HUD.
    header = "pad=2560:944:0:44:color=0x18202a"
    font = "drawtext=fontfile=segoeui.ttf:fontsize=23:fontcolor=white:y=7"
    filters = [
        "[0:v][1:v]hstack", header,
        f"{font}:x=20:text='{title}   C / review baseline'",
        f"{font}:x=1300:text='{title}   {state} / {label}'",
        f"{font}:x=1040:text='Serve + follow':enable='lt(t,4)'",
        f"{font}:x=1040:text='Right edge':enable='gte(t,4)'",
    ]
    output = MEDIA / (theme + ".mp4")
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-framerate", "20", "-i", str(current / "%03d.jpg"),
        "-framerate", "20", "-i", str(candidate / "%03d.jpg"),
        "-filter_complex", ",".join(filters), "-frames:v", "120",
        "-c:v", "libx264", "-preset", "fast", "-crf", "18",
        "-pix_fmt", "yuv420p", "-an", "-movflags", "+faststart", str(output),
    ], check=True, cwd=Path(os.environ["WINDIR"]) / "Fonts")
    return hashlib.sha256(output.read_bytes()).hexdigest()


def compare(theme, state, label):
    current, candidate, cost = [RAW / f"{theme}-{s}" for s in ("C", state, "cost")]
    left, right, bench = map(receipt, (current, candidate, cost))
    fingerprints = ("act", "source_sha256", "act_bake_sha256", "theme_bake_sha256",
                    "pipeline_fingerprint", "scenery_fingerprint", "retro_settings_sha256",
                    "atmosphere", "retro_effects")
    for key in fingerprints:
        assert left["fixture"][key] == right["fixture"][key] == bench["fixture"][key], key
    for path_key, hash_key in (("act", "source_sha256"), ("act_bake", "act_bake_sha256"),
                               ("theme_bake", "theme_bake_sha256")):
        local = ROOT / left["fixture"][path_key].removeprefix("res://")
        assert hashlib.sha256(local.read_bytes()).hexdigest() == left["fixture"][hash_key], local
    for key in ("spawn", "edge", "path"):
        assert left[key] == right[key], key
    assert left["device_defaults"] == right["device_defaults"] == bench["device_defaults"]
    for key in ("directional_lights", "exposure", "ambient_energy", "retro", "pixel_profile"):
        assert left["settings"][key] == right["settings"][key] == bench["settings"][key], key
    assert len(left["path"]) == 80 and len({row[2] for row in left["path"]}) > 10
    assert any(row[4] > 0 for row in left["path"])
    for folder in (current, candidate):
        assert all((folder / f"{i:03}.jpg").is_file() for i in range(120))
    return {
        "clip_sha256": encode(theme, current, candidate, label),
        "production": left["production_state"],
        "matched_fixture": {k: left["fixture"][k] for k in fingerprints},
        "disk_acts": 1, "disk_backdrops": 1, "fallback_builds": 0,
        "spawn": left["spawn"], "right_edge": left["edge"],
        "matched_play_frames": len(left["path"]),
        "matched_play_trace_sha256": hashlib.sha256(json.dumps(left["path"]).encode()).hexdigest(),
        "device_defaults": left["device_defaults"], "renderer": bench["fixture"]["renderer"]["device"],
        "measurements": bench["measurements"],
    }


if __name__ == "__main__":
    MEDIA.mkdir(parents=True, exist_ok=True)
    result = {theme: compare(theme, code, label) for theme, (_, code, label) in THEMES.items()}
    (MEDIA / "receipts.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
