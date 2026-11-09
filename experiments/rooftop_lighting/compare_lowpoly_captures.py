"""Validate fixed-camera captures and create unretouched labelled comparisons."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

folder = Path(__file__).parent / "captures/lowpoly-study"
report = json.loads((folder / "validation.json").read_text())
assert report["failures"] == 0
names = ["flat", "edge-only", "smooth-convex", "beveled-block", "faceted-stone"]
labels = ["1  Flat floor", "2  Existing edge-only normal (0.45)", "3  Existing smooth convex normal (1.0)", "4  Beveled block", "5  Faceted stone"]
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 30)
small = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 28)

def panel(sheet, index, filename, label):
    x, y = index % 2 * 1280, index // 2 * 750
    sheet.paste(Image.open(folder / filename), (x, y + 60))
    ImageDraw.Draw(sheet).text((x + 24, y + 10), label, font=font, fill="#f4ead2")

for view in ["gameplay", "close"]:
    for strength in ["safe", "diagnostic"]:
        records = []
        sheet = Image.new("RGB", (2560, 2250), "#142127")
        for index, (name, title) in enumerate(zip(names, labels)):
            suffix = strength if index >= 3 else "safe"
            key = f"{view}-{name}-{suffix}"
            records.append(report[key])
            panel(sheet, index, key + ".png", title + (f" | {strength}" if index >= 3 else ""))
        assert all(r["geometry_camera_unchanged"] for r in records)
        for field in ["camera", "fov", "projection", "orthogonal_size", "lighting"]:
            assert all(r[field] == records[0][field] for r in records), field
        draw = ImageDraw.Draw(sheet)
        text = "SAME CAMERA / LIGHTING / ALBEDO\n\nFlat mesh; normal mapping only.\nNo parallax, roughness changes or extra geometry.\n\nNew variants: " + strength + " preset.\nEarlier variants retain their original settings.\n\nGameplay = original scene camera.\nClose-up = shared material inspection camera."
        draw.multiline_text((1320, 1570), text, font=small, fill="#f4ead2", spacing=16)
        sheet.save(folder / f"{view}-comparison-{strength}.png")
    strengths = Image.new("RGB", (2560, 1500), "#142127")
    for index, (style, strength) in enumerate([(a, b) for b in ["safe", "diagnostic"] for a in ["beveled-block", "faceted-stone"]]):
        panel(strengths, index, f"{view}-{style}-{strength}.png", style.replace("-", " ").title() + " | " + strength)
    strengths.save(folder / f"{view}-strengths.png")

def pixels(name):
    return np.asarray(Image.open(folder / f"{name}.png").convert("RGB"), dtype=float)
roi = (slice(340, 525), slice(600, 860))
flat = pixels("close-flat-safe")
zero_errors = {style: float(abs(flat[roi] - pixels("zero-" + style)[roi]).mean()) for style in names[-2:]}
assert max(zero_errors.values()) < 0.05
# Verify the ball's blue interior remains unchanged across the gameplay captures.
ball_roi = (slice(420, 444), slice(720, 750))
baseline_ball = pixels("gameplay-flat-safe")[ball_roi]
ball_mask = (baseline_ball[:, :, 2] > 80) & (baseline_ball[:, :, 2] > baseline_ball[:, :, 0] * 1.5) & (baseline_ball[:, :, 2] > baseline_ball[:, :, 1] * 1.2)
# Antialiased outline pixels legitimately blend with the changed floor behind
# the ball. Erode that boundary to compare only actual opaque ball pixels.
for _ in range(2):
    ball_mask = np.logical_and.reduce([ball_mask, np.roll(ball_mask, 1, 0), np.roll(ball_mask, -1, 0), np.roll(ball_mask, 1, 1), np.roll(ball_mask, -1, 1)])
assert ball_mask.sum() > 20
ball_error = max(float(abs(pixels(f"gameplay-{name}-safe")[ball_roi][ball_mask] - baseline_ball[ball_mask]).max()) for name in names)
assert ball_error <= 1.0
summary = {"checks": "PASS", "geometry_camera_captures": 16, "comparison_lighting_projection_match": True, "zero_strength_floor_rgb_mae": zero_errors, "ball_interior_max_rgb_difference": ball_error, "ball_mask_pixels": int(ball_mask.sum())}
(folder / "comparison-validation.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
maps = Image.new("RGB", (1024, 1084), "#142127")
for index, style in enumerate(["block", "faceted"]):
    maps.paste(Image.open(folder / f"{style}-maps.png").resize((1024, 542), Image.Resampling.LANCZOS), (0, index * 542))
maps.save(folder / "maps-overview.png")
