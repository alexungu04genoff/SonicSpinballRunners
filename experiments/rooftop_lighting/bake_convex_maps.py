"""Build broad, stylized stone relief from the existing floor PNG's silhouettes.

The known 16-row stagger locates each stone; the actual albedo pixels define its
outline. Albedo brightness/grain is deliberately not converted into height.
The normal is derived from the saved grayscale map, not independently painted.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SOURCE = ROOT / "assets/textures/rooftop_run/floor.png"
REPEAT_WORLD = 4.0
BAKE_RELIEF_WORLD = 0.05  # Deliberately exaggerated diagnostic amplitude.

def blur_periodic(values, sigma):
    radius = int(np.ceil(sigma * 3))
    weights = np.exp(-np.arange(-radius, radius + 1, dtype=float) ** 2 / (2 * sigma ** 2))
    weights /= weights.sum()
    for axis in (0, 1):
        values = sum(weight * np.roll(values, offset, axis) for offset, weight in zip(range(-radius, radius + 1), weights))
    return values

albedo = np.asarray(Image.open(SOURCE).convert("RGB"))
size = albedo.shape[0]
assert albedo.shape == (1024, 1024, 3), "Review the authored stone layout if the source changes."
y, x = np.mgrid[0:size, 0:size].astype(float)
x = (x + 0.5) / size * 16
y = (y + 0.5) / size * 16
x += np.mod(np.floor(y), 2) * 0.5
u, v = np.mod(x, 1) - 0.5, np.mod(y, 1) - 0.5

# The source grout is RGB (71, 69, 59). This threshold rejects grout and its
# antialiased transition, while retaining even the darkest actual stone faces.
stone_mask = albedo[:, :, 0] > 80
grout_mask = albedo[:, :, 0] == 71
face = np.maximum(0, 1 - (u / 0.48) ** 2) * np.maximum(0, 1 - (v / 0.45) ** 2)
height = blur_periodic(stone_mask * (0.18 + 0.82 * face), 1.6)
height *= 1.0 - grout_mask * 0.98
height /= height.max()
Image.fromarray(np.uint8(np.rint(height * 255))).save(OUT / "floor_height.png")

# Read the grayscale artifact back before deriving slopes. A small low-pass
# suppresses 8-bit quantization steps, not the broad authored curvature.
height = np.asarray(Image.open(OUT / "floor_height.png"), dtype=float) / 255
smooth_height = blur_periodic(height, 1.25) * BAKE_RELIEF_WORLD
pixel_world = REPEAT_WORLD / size
dx = (np.roll(smooth_height, -1, 1) - np.roll(smooth_height, 1, 1)) / (2 * pixel_world)
dy_down = (np.roll(smooth_height, -1, 0) - np.roll(smooth_height, 1, 0)) / (2 * pixel_world)
# OpenGL: +Y points toward the top of the image, whereas raster rows grow down.
normal = np.stack([-dx, dy_down, np.ones_like(dx)], axis=-1)
normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
encoded = np.uint8(np.rint(np.clip(normal * 0.5 + 0.5, 0, 1) * 255))
Image.fromarray(encoded).save(OUT / "floor_convex_normal_gl.png")

# Small deterministic checks for depth order, direction, continuity and noise.
centres = (abs(u) < 0.025) & (abs(v) < 0.025)
shoulder = (abs(u) > 0.30) & (abs(u) < 0.36) & (abs(v) < 0.05)
assert height[grout_mask].max() < 0.025
assert height[centres].min() > 0.97
assert 0.45 < height[shoulder].mean() < 0.75
assert np.allclose(np.linalg.norm(normal, axis=-1), 1)
assert encoded[20, 32, 1] > 128 and encoded[44, 32, 1] < 128, "OpenGL green direction reversed."
assert encoded[32, 20, 0] < 128 and encoded[32, 44, 0] > 128, "Red direction reversed."
assert np.max(abs(height[:, 0] - height[:, -1])) < 0.08
assert np.max(abs(height[0, :] - height[-1, :])) < 0.025
report = {"source": str(SOURCE.relative_to(ROOT)), "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(), "size": size, "repeat_world": REPEAT_WORLD, "normal_bake_relief_world": BAKE_RELIEF_WORLD, "normal_convention": "OpenGL +X +Y +Z; green points up the image", "grout_max": float(height[grout_mask].max()), "centre_min": float(height[centres].min()), "shoulder_mean": float(height[shoulder].mean()), "checks": "PASS"}
(OUT / "captures/height-map-validation.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))

sheet = Image.new("RGB", (2048, 1084), "#142127")
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 28)
for i, (filename, label) in enumerate([("floor_height.png", "HEIGHT | dark mortar, bright convex centres"), ("floor_convex_normal_gl.png", "NORMAL | OpenGL, derived from the height map")]):
    sheet.paste(Image.open(OUT / filename).convert("RGB"), (i * 1024, 60))
    draw.text((i * 1024 + 20, 10), label, fill="#f4ead2", font=font)
sheet.save(OUT / "captures/height-normal-maps.png")
