"""Encode Motion Lab frames and build compact review media. No external assets."""
from __future__ import annotations

import argparse
import csv
import html
import json
from pathlib import Path
import subprocess

THEMES = ("green_hill", "chemical_plant", "rooftop_run", "casino_night", "sky_sanctuary", "ice_cap", "aquarium_park")


def run(args: list[str]) -> None:
    subprocess.run(args, check=True, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))


def ffmpeg(*args: str) -> None:
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args])


def encode(directory: Path, keep_frames: bool) -> Path:
    receipt_path = directory / "capture.json"
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    destination = directory.with_suffix(".mp4")
    extension = receipt.get("frame_format", "png")
    if extension not in ("png", "jpg"):
        raise RuntimeError(f"Unsupported frame format: {extension}")
    frames = [directory / f"{index:05d}.{extension}" for index in range(receipt["frames"])]
    if all(path.is_file() for path in frames):
        ffmpeg("-framerate", str(receipt["fps"]), "-i", str(directory / ("%05d." + extension)),
               "-c:v", "libx264", "-preset", "fast", "-crf", "23", "-pix_fmt", "yuv420p",
               "-movflags", "+faststart", str(destination))
        if not destination.is_file() or destination.stat().st_size < 1000:
            raise RuntimeError(f"Empty movie: {destination}")
        if not keep_frames:
            # Only the exact frames enumerated by this capture receipt are removed.
            # Keep its receipt, preview PNG and movie; never remove whole folders.
            for path in frames:
                path.unlink()
    elif not destination.is_file():
        raise RuntimeError(f"Missing capture frames and encoded movie: {directory}")
    return destination


def contact_sheet(output: Path, rows: list[dict], recommendations: dict[str, str]) -> None:
    inputs: list[str] = []
    filters: list[str] = []
    occupied: list[str] = []
    labels: list[str] = []
    available = {(row["theme"], row["candidate"]): row for row in rows}
    font = "C\\:/Windows/Fonts/segoeui.ttf"
    for theme in THEMES:
        selection = recommendations.get(theme, "C")
        if (theme, "C") not in available or (theme, selection) not in available:
            continue
        row_index = len(occupied) // 2
        pair = [available[theme, candidate] for candidate in ("C", selection)]
        diagnostic_images = []
        for row in pair:
            matched = next((item for item in row.get("diagnostics", [])
                            if item.get("focus", "spawn") == row.get("focus", "spawn")
                            and item.get("camera") == "normal"
                            and item.get("retro") == "production"
                            and abs(float(item.get("time", -1)) - 7.25) < 0.0001), None)
            diagnostic_images.append(output / matched["image"] if matched else None)
        # Both columns use the same diagnostic time or both use their time-zero
        # previews. Never silently compare a scrubbed candidate with a reset C.
        use_diagnostics = all(path is not None and path.is_file() for path in diagnostic_images)
        for column, candidate in enumerate(("C", selection)):
            index = len(occupied)
            path = diagnostic_images[column] if use_diagnostics else output / (available[theme, candidate]["directory"] + ".png")
            inputs += ["-i", str(path)]
            label = theme.replace("_", " ").title() + (" / Current C" if column == 0 else f" / Recommended {candidate}")
            label += " / 7.25 s" if use_diagnostics else " / 0 s"
            filters.append(f"[{index}:v]scale=480:333,pad=480:363:0:30:color=0x101824,drawtext=fontfile='{font}':text='{label}':fontcolor=white:fontsize=16:x=10:y=5[s{index}]")
            labels.append(f"[s{index}]")
            occupied.append(f"{column * 480}_{row_index * 363}")
    if not occupied:
        return
    filters.append("".join(labels) + f"xstack=inputs={len(occupied)}:layout=" + "|".join(occupied) + "[sheet]")
    ffmpeg(*inputs, "-filter_complex_threads", "1", "-filter_complex", ";".join(filters),
           "-map", "[sheet]", "-frames:v", "1", "-update", "1", str(output / "contact-sheet.png"))


def overview(output: Path, rows: list[dict], recommendations: dict[str, str]) -> None:
    available = {(row["theme"], row["candidate"]): row for row in rows}
    arguments: list[str] = []
    clips: list[str] = []
    filters: list[str] = []
    for theme in THEMES:
        key = theme, recommendations.get(theme, "C")
        if key not in available:
            continue
        index = len(clips)
        arguments += ["-i", str(output / (available[key]["directory"] + ".mp4"))]
        filters.append(f"[{index}:v]trim=duration=5,setpts=PTS-STARTPTS[v{index}]")
        clips.append(f"[v{index}]")
    if not clips:
        return
    filters.append("".join(clips) + f"concat=n={len(clips)}:v=1:a=0[overview]")
    ffmpeg(*arguments, "-filter_complex_threads", "1", "-filter_complex", ";".join(filters),
           "-map", "[overview]", "-c:v", "libx264", "-preset", "fast", "-crf", "23",
           "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(output / "seven-theme-overview.mp4"))


def write_index(output: Path, manifest: dict, recommendations: dict[str, str]) -> None:
    rows = manifest["rows"]
    columns = ["theme", "candidate", "tier", "median_ms", "p95_ms", "p99_ms", "max_ms", "render_cpu_median_ms", "render_gpu_median_ms", "draws", "objects", "primitives", "shadow_draws", "cpu_callbacks", "animated_materials", "moving_meshes", "motion_update_median_ms", "preparation_ms", "warmup_ms", "resources", "resource_delta"]
    with (output / "performance.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        for row in rows:
            data = row["benchmark"]
            entry = {key: row[key] for key in ("theme", "candidate", "tier")}
            entry.update({key: data["frame"][key] for key in ("median_ms", "p95_ms", "p99_ms", "max_ms")})
            entry.update({key: data["counters"].get(key) for key in ("draws", "objects", "primitives", "shadow_draws")})
            entry.update({key: data["motion"].get(key) for key in ("cpu_callbacks", "animated_materials", "moving_meshes")})
            entry.update({key: data.get(key) for key in ("preparation_ms", "warmup_ms", "resources", "resource_delta")})
            entry.update(render_cpu_median_ms=data["render_cpu"].get("median_ms"), render_gpu_median_ms=data["render_gpu"].get("median_ms"), motion_update_median_ms=data["motion_update"].get("median_ms"))
            writer.writerow(entry)
    parts = ["<!doctype html><html><meta charset='utf-8'><title>Theme Life review</title>",
             "<style>body{margin:2rem auto;max-width:1500px;background:#101824;color:#ecf3ff;font:16px system-ui}a{color:#9fd5ff}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}video{width:100%;background:#000}h2{margin-top:3rem}small{color:#b8c7da}table{border-collapse:collapse}td,th{padding:8px;border:1px solid #42516a}</style>",
             "<h1>Theme Life / Environmental Motion</h1><p>Real disk-loaded Prototype. Frozen gameplay. Deterministic environmental time. C remains production; A/B are review candidates.</p><p>Focus changes move only the review camera. Sonic, Rings, mechanisms and Goals remain at their authored positions; some may leave the frame. Spawn stills retain the primary gameplay readability check. Normal angle/zoom stays unchanged; Wide is a separate zoom-0.6 review camera.</p>",
             "<p><a href='manifest.json'>Capture and benchmark receipts</a> · <a href='performance.csv'>Performance CSV</a> · <a href='contact-sheet.png'>Current vs recommended contact sheet</a></p>",
             "<p>Desktop timing is not UHD 620 certification. Presented-frame distributions exclude image capture. Render CPU/GPU sums can overlap; transparent draw counts are unavailable.</p>"]
    if (output / "seven-theme-overview.mp4").exists():
        parts += ["<h2>Recommended states: seven-theme moving overview</h2><p>Five seconds each, in the order listed below. No labels over gameplay.</p><video controls preload='metadata' src='seven-theme-overview.mp4'></video>"]
    for theme in THEMES:
        group = [row for row in rows if row["theme"] == theme]
        if not group:
            continue
        parts.append(f"<h2>{theme.replace('_', ' ').title()} — recommended {recommendations.get(theme, 'C')}</h2><div class='grid'>")
        for row in group:
            file = html.escape(row["directory"])
            info = row["benchmark"]
            parts.append(f"<article><h3>{row['candidate']} · {html.escape(row['description'])}</h3><p>{html.escape(row.get('camera', 'normal'))} camera · {html.escape(row.get('focus', 'spawn'))} focus · target {html.escape(row.get('camera_target', 'canonical spawn'))}</p><video controls loop preload='none' poster='{file}.png' src='{file}.mp4'></video><p>{info['frame']['median_ms']:.2f} ms median · {info['frame']['p95_ms']:.2f} p95 · {info['frame']['p99_ms']:.2f} p99</p><small>{html.escape(str(info['motion']))}</small><p><a href='{file}/capture.json'>Capture receipt</a></p>")
            if row.get("diagnostics"):
                parts.append("<details><summary>Camera / Retro diagnostic stills at 7.25 s</summary>" + " · ".join(f"<a href='{html.escape(item['image'])}'>{item.get('focus', 'spawn')} / {item['camera']} / {item['retro']}</a>" for item in row["diagnostics"]) + "</details>")
            parts.append("</article>")
        parts.append("</div>")
    parts.append("<p>All recommendations remain diagnostic. The registry retains C for every production theme.</p></html>")
    (output / "index.html").write_text("\n".join(parts), encoding="utf-8")
    (output / "recommendations.json").write_text(json.dumps(recommendations, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--keep-frames", action="store_true")
    parser.add_argument("--recommendations", type=Path, help="JSON object mapping included themes to C/A/B")
    args = parser.parse_args()
    output = args.output.resolve(strict=True)
    manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
    if not manifest.get("complete"):
        raise SystemExit("Refusing to present an incomplete capture manifest as final review media.")
    recommendations = {theme: "C" for theme in THEMES}
    if args.recommendations:
        supplied = json.loads(args.recommendations.read_text(encoding="utf-8"))
        if any(theme not in THEMES or state not in ("C", "A", "B") for theme, state in supplied.items()):
            raise SystemExit("Invalid recommendation: expected one of seven included themes and C/A/B.")
        recommendations.update(supplied)
    for row in manifest["rows"]:
        directory = (output / row["directory"]).resolve()
        if directory.parent != output or row["theme"] not in THEMES:
            raise SystemExit("Unexpected capture path or excluded theme.")
        encode(directory, args.keep_frames)
    contact_sheet(output, manifest["rows"], recommendations)
    overview(output, manifest["rows"], recommendations)
    write_index(output, manifest, recommendations)
    print(f"THEME_MOTION_MEDIA_COMPLETE | {output / 'index.html'}")


if __name__ == "__main__":
    main()
