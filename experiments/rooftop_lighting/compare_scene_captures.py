"""Validate the controlled comparison and assemble unretouched screenshot sheets."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "captures/scene-study"
report = json.loads((OUT / "validation.json").read_text())
assert report["failures"] == 0
names = ["none", "beveled", "faceted", "hybrid"]
labels = ["Current improved lighting | No generated normals", "A | Beveled", "B | Faceted", "C | Hybrid"]
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 28)
for view in ["gameplay", "close", "overview"]:
    records = [report[f"{view}-{name}"] for name in names]
    assert all(r["geometry_camera_unchanged"] for r in records)
    for field in ["camera", "fov", "projection", "lighting"]:
        assert all(r[field] == records[0][field] for r in records), field
    sheet = Image.new("RGB", (2560, 1500), "#142127")
    for i, (name, label) in enumerate(zip(names, labels)):
        x, y = i % 2 * 1280, i // 2 * 750
        ImageDraw.Draw(sheet).text((x + 20, y + 12), label, font=font, fill="#f4ead2")
        sheet.paste(Image.open(OUT / f"{view}-{name}.png"), (x, y + 60))
    sheet.save(OUT / f"{view}-comparison.png")

def pixels(name):
    return np.asarray(Image.open(OUT / f"{name}.png").convert("RGB"), dtype=float)

flat, zero = pixels("close-none"), pixels("zero-strength")
zero_mae = float(abs(flat - zero).mean())
assert zero_mae < .1, f"Zero strength changes baseline rendering: {zero_mae}"
guard_difference = np.max(abs(pixels("guards-only") - zero), axis=2)
assert (guard_difference > 2).sum() > 50, "Inner railguards/fascia have no visible response."
roi = (slice(420, 444), slice(720, 750))
ball = pixels("gameplay-none")[roi]
mask = (ball[:, :, 2] > 80) & (ball[:, :, 2] > ball[:, :, 0] * 1.5) & (ball[:, :, 2] > ball[:, :, 1] * 1.2)
for _ in range(2):
    mask = np.logical_and.reduce([mask, np.roll(mask, 1, 0), np.roll(mask, -1, 0), np.roll(mask, 1, 1), np.roll(mask, -1, 1)])
assert mask.sum() > 20
ball_error = max(float(abs(pixels(f"gameplay-{name}")[roi][mask] - ball[mask]).max()) for name in names)
assert ball_error <= 1
bakes = json.loads((ROOT / "scene_maps/bake-report.json").read_text())
source = ROOT.parents[1] / "assets/textures/rooftop_run"
assert all(hashlib.sha256((source / name).read_bytes()).hexdigest() == digest for name, digest in bakes["source_hashes"].items())
summary = {"checks": "PASS", "geometry_camera_captures": 14, "lighting_camera_projection_match": True,
           "zero_strength_whole_image_rgb_mae": zero_mae, "guard_response_pixels_over_2_rgb": int((guard_difference > 2).sum()),
           "ball_interior_max_rgb_difference": ball_error, "source_albedos_unchanged": True}
(OUT / "comparison-validation.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))

# Side-by-side map swatches retain source colors and show the structural masks.
sheet = Image.new("RGB", (1280, 7 * 216 + 44), "#142127")
small = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 22)
draw = ImageDraw.Draw(sheet)
for j, text in enumerate(["Source / structural role", "Beveled normal", "Faceted normal", "Treatment"]):
    draw.text((j * 320 + 8, 8), text, font=small, fill="#f4ead2")
for i, (name, art, treatment) in enumerate([
    ("floor", "floor", "Worn cobbles\nHybrid: faceted"), ("ramp", "ramp", "Cut ramp tiles\nHybrid: beveled"),
    ("top", "top", "Terracotta slabs\nHybrid: beveled"), ("wall", "wall", "Masonry joints\nHybrid: beveled"),
    ("facade", "facade", "Masonry only\nWindows/trim masked"), ("border", "top-border", "Cut coping\nLow strength: 0.25"),
    ("guard", None, "Solid stone guard\nBoundary-based profile")]):
    y = 44 + i * 216
    if art:
        img = Image.open(source / f"{art}.png").convert("RGB")
        img.thumbnail((312, 208))
        sheet.paste(img, (4, y))
    else:
        draw.rectangle((4, y, 312, y + 208), fill="#e8cba0")
    for j, style in enumerate(["beveled", "faceted"]):
        img = Image.open(ROOT / f"scene_maps/{name}_{style}_normal.png")
        img.thumbnail((312, 208))
        sheet.paste(img, (324 + j * 320, y))
    draw.multiline_text((968, y + 20), treatment, font=small, fill="#f4ead2", spacing=10)
sheet.save(OUT / "material-map-sheet.png")
