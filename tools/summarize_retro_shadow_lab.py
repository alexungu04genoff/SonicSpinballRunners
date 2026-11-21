"""Make compact review plates and clips from Retro Shadow Lab.cmd evidence."""

import argparse
import csv
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def label(image, xy, text, size=20):
    draw = ImageDraw.Draw(image)
    try:
        font = ImageFont.truetype("segoeui.ttf", size)
    except OSError:
        font = ImageFont.load_default(size=size)
    draw.text(xy, text, fill="#f4f1e9", font=font)


def frame(path):
    with Image.open(path) as image:
        return image.convert("RGB")


def plate(output, name, heading, cells, columns, size):
    width, height = size
    rows = (len(cells) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * width, 50 + rows * (height + 32)), "#171924")
    label(sheet, (12, 8), heading, 24)
    for i, (caption, image) in enumerate(cells):
        x, y = (i % columns) * width, 50 + (i // columns) * (height + 32)
        label(sheet, (x + 10, y + 2), caption, 18)
        sheet.paste(image.resize(size, Image.Resampling.LANCZOS), (x, y + 32))
    sheet.save(output / name, quality=94, subsampling=0)


def movie(output, name, frames, fps):
    frames = iter(frames)
    first = next(frames)
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo",
               "-pixel_format", "rgb24", "-video_size", f"{first.width}x{first.height}",
               "-framerate", str(fps), "-i", "-", "-an", "-c:v", "libx264", "-crf", "15",
               "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(output / name)]
    with subprocess.Popen(command, stdin=subprocess.PIPE) as process:
        process.stdin.write(first.tobytes())
        for image in frames:
            process.stdin.write(image.tobytes())
        process.stdin.close()
        if process.wait():
            raise RuntimeError(f"ffmpeg failed for {name}")


def summarize(source, output):
    report = json.loads((source / "report.json").read_text(encoding="utf-8"))
    if not report["complete"]:
        raise ValueError("Capture run did not pass. Inspect its report and engine log.")
    output.mkdir(parents=True, exist_ok=True)
    candidates = [(0, "normal", "A   Normal"), (5, "clean8", "B   Clean · 8 levels"),
                  (2, "clean4", "B   Clean · 4 levels"), (4, "clean3", "C   Clean · 3 levels"),
                  (3, "ordered4", "D   Ordered dither · 4 levels"), (1, "clean2", "E   Hard · 2 levels")]
    names = {mode: caption for mode, _, caption in candidates}
    themes = [row["theme"] for row in report["rows"] if row["mode"] == "normal"]
    if len(themes) != 8:
        raise ValueError("The full eight-theme evidence run is required.")

    def compare(name, title, paths, crop=None, size=(422, 296)):
        cells = []
        for (mode, slug, caption) in candidates:
            img = frame(source / paths(mode, slug))
            cells.append((caption, img.crop(crop) if crop else img))
        plate(output, name, title, cells, 3, size)

    compare("penumbra.jpg", "One soft shadow   /   Profile B   /   full Retro",
            lambda mode, _: f"penumbra-retro-{mode}.png")
    compare("tube.jpg", "Rooftop Run   /   Launch Tube Workshop   /   full Retro",
            lambda mode, _: f"tube-shadow-{mode}.png", (420, 160, 980, 650), (399, 350))
    for theme in ["green_hill"]:
        compare(theme + ".jpg", theme.replace("_", " ").title() + "   /   matched pose   /   full Retro",
                lambda _, slug: f"{theme}-{slug}.png", (80, 140, 920, 700), (420, 280))
    plate(output, "eight-themes.jpg", "Profile B   /   full Retro   /   clean four-level shadows",
          [(t.replace("_", " ").title(), frame(source / f"{t}-clean4.png")) for t in themes], 4, (320, 225))
    tones = [("normal", "Normal"), ("clean4", "Native range · 4"), ("original-tones-2", "Starting tones · 4"),
             ("deeper-2", "Deeper tones · 4"), ("original-tones-3", "Starting tones · dither"),
             ("deeper-3", "Deeper tones · dither")]
    plate(output, "tone-study.jpg", "Green Hill   /   art-directed palette study   /   full Retro",
          [(caption, frame(source / f"green_hill-{slug}.png").crop((80, 140, 920, 700)))
           for slug, caption in tones], 3, (420, 280))
    cells = []
    for theme in ["rooftop_run", "casino_night", "aquarium_park"]:
        for mode in [0, 2]:
            cells.append((theme.replace("_", " ").title() + "   /   " + names[mode],
                          frame(source / f"{theme}-raised-{mode}.png")))
    plate(output, "raised-and-emissive.jpg", "Raised architecture, emission and water   /   full Retro",
          cells, 2, (420, 295))
    fixtures = [("RampMania · ball in play", "act-1-moving"), ("Side to Side · ball in play", "act-2-moving"),
                ("Score chute", "score-chute"), ("Launch Tube release", "act-3-moving")]
    plate(output, "moving-fixtures.jpg", "Rooftop Run   /   real gameplay fixtures   /   full Retro",
          [(caption, frame(source / (name + ".png"))) for caption, name in fixtures], 2, (480, 338))
    cells = []
    for theme in ["green_hill", "ice_cap"]:
        for blur, angle in [(0.5, 0), (2, 0), (1, 3)]:
            img = frame(source / f"{theme}-light-{blur:.1f}-{angle:.1f}-2.png")
            cells.append((f"{theme.replace('_', ' ').title()}   /   blur {blur:g}, sun {angle}°",
                          img.crop((60, 115, 900, 675))))
    plate(output, "blur.jpg", "Four levels   /   atmosphere Shadow Blur and physical Sun Angle",
          cells, 3, (375, 250))

    ring_values = []
    for profile in (1, 2):
        for mode in (0, 5, 2, 3):
            darkness = []
            for i in range(16):
                stem = f"ring-{profile}-{mode}-{i:02d}"
                on = np.asarray(frame(source / f"{stem}-1.png").convert("L"), dtype=float)
                off = np.asarray(frame(source / f"{stem}-0.png").convert("L"), dtype=float)
                darkness.append(float(np.maximum(off - on, 0).sum()))
            ring_values.append({"profile": "ABC"[profile], "mode": names[mode],
                                "mean_darkness": float(np.mean(darkness)),
                                "max_adjacent_over_mean": float(np.max(np.abs(np.diff(darkness))) / np.mean(darkness))})

    def ring_frame(i):
        sheet = Image.new("RGB", (1600, 360), "#171924")
        for profile in (1, 2):
            for col, (mode, enabled) in enumerate([(0, 1), (5, 1), (2, 1), (3, 1), (3, 0)]):
                x, y = col * 320, (profile - 1) * 180
                caption = names[mode] if enabled else "Ring shadows off"
                label(sheet, (x + 6, y + 3), "Profile " + "ABC"[profile] + "   /   " + caption, 16)
                img = frame(source / f"ring-{profile}-{mode}-{i:02d}-{enabled}.png")
                sheet.paste(img.resize((320, 144), Image.Resampling.LANCZOS), (x, y + 30))
        return sheet

    def pan_frame(i, prefix, anchors=False):
        order = [(0, "Ordered · screen"), (1, "Ordered · object"), (2, "Ordered · world")] if anchors else [
            (3, names[0]), (5, names[5]), (4, names[2]), (6, names[4]), (2, names[3]), (7, names[1])]
        sheet = Image.new("RGB", (1200, 46 + 300 * (len(order) // 3)), "#171924")
        scene = "Penumbra study" if prefix == "edge-pan" else "Green Hill"
        label(sheet, (10, 4), scene + "   /   Profile B   /   full Retro", 22)
        for j, (index, caption) in enumerate(order):
            x, y = (j % 3) * 400, 46 + (j // 3) * 300
            label(sheet, (x + 8, y), caption, 18)
            img = frame(source / f"{prefix}-{index}-{i:02d}.png")
            sheet.paste(img.resize((400, 258), Image.Resampling.LANCZOS), (x, y + 32))
        return sheet

    sweep = list(range(24)) + list(range(22, 0, -1))
    movie(output, "rings.mp4", (ring_frame(i % 16) for i in range(48)), 12)
    for name, anchors in [("pan.mp4", False), ("anchors.mp4", True)]:
        movie(output, name, (pan_frame(i, prefix, anchors)
              for prefix in ["edge-pan", "pan"] for i in sweep), 15)
    with (output / "rtx4060.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["theme", "mode", "startup_ms", "attach_ms", "warm24_ms", "median_ms", "p95_ms", "pan_median_ms",
                         "pan_p95_ms", "draws", "triangles_or_primitives", "shadow_draws", "shadow_candidate_primitives", "resources", "video_bytes",
                         "receivers", "added_materials", "added_shaders", "pipeline_compilations"])
        for row in report["rows"]:
            if "theme" not in row:
                continue
            pan = row.get("pan", {}).get("frame", {})
            counts = row["receiver_inventory"]
            new_pipelines = sum(row["pipelines_after"].values()) - sum(row["pipelines_before"].values())
            writer.writerow([row["theme"], row["mode"], row["startup_ms"], row["attach_ms"], row["warm24_ms"],
                             row["frame"]["median_ms"], row["frame"]["p95_ms"], pan.get("median_ms"), pan.get("p95_ms"),
                             row["visible"]["draws"], row["visible"]["primitives"], row["shadow"]["draws"],
                             row["shadow"]["primitives"], row["resources"], row["video_bytes"], counts["receivers"], counts["materials"],
                             counts["programs"], int(new_pipelines)])
    summary = {"renderer": {k: report["metadata"][k] for k in ("engine", "renderer", "driver", "api", "device")}, "checks_passed": len(report["checks"]), "orphan_nodes": report["orphan_nodes"],
               "ring_motion": ring_values, "endless": [row for row in report["rows"] if row.get("runtime") == "Endless"],
               "lighting_and_ownership": [c["check"] for c in report["checks"] if any(
                   s in c["check"] for s in ["Aquarium:", "calibration:", "local/emission", "Released runtime"])]}
    (output / "measurements.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    summarize(args.capture, args.output)
