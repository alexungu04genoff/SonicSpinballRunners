"""Validate the controlled captures and arrange them without retouching."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

folder = Path(__file__).parent / "captures/height-study"
report = json.loads((folder / "validation.json").read_text())
assert report["failures"] == 0 and report["floor_slots"] > 0
names = ["lighting-only", "normal-only", "convex-normal", "convex-parallax"]
labels = ["1  Flat floor", "2  Existing edge-only normal", "3  Convex normal | diagnostic strength", "4  Convex + parallax | diagnostic depth"]
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 30)
for view in ("overview", "close"):
    records = [report[f"{view}-{name}"] for name in names]
    assert all(r["geometry_camera_unchanged"] for r in records)
    assert all(r["camera"] == records[0]["camera"] and r["fov"] == records[0]["fov"] and r["lighting"] == records[0]["lighting"] for r in records)
    sheet = Image.new("RGB", (2560, 1500), "#142127")
    draw = ImageDraw.Draw(sheet)
    for index, (name, label) in enumerate(zip(names, labels)):
        x, y = (index % 2) * 1280, (index // 2) * 750
        sheet.paste(Image.open(folder / f"{view}-{name}.png"), (x, y + 60))
        draw.text((x + 24, y + 10), label, font=font, fill="#f4ead2")
    sheet.save(folder / f"{view}-comparison.png")

# Fixed, unobstructed floor patch; excludes animated scenery and gameplay props.
roi = (slice(340, 525), slice(600, 860))
def pixels(name):
    return np.asarray(Image.open(folder / f"{name}.png").convert("RGB"), dtype=float)[roi]
flat, convex = pixels("close-lighting-only"), pixels("close-convex-normal")
flat_zero_error = float(abs(flat - pixels("normal-zero")).mean())
parallax_zero_error = float(abs(convex - pixels("parallax-zero")).mean())
assert flat_zero_error < 0.05, "Zero normal strength must reproduce the flat floor."
assert parallax_zero_error < 0.05, "Zero parallax depth must reproduce normal-only shading."
summary = {"same_lighting_and_camera_within_both_sets": True, "capture_checks": 10, "flat_vs_zero_normal_rgb_mae": flat_zero_error, "normal_vs_zero_parallax_rgb_mae": parallax_zero_error, "checks": "PASS"}
(folder / "comparison-validation.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
