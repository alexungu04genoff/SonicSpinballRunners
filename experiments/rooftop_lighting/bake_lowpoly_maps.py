"""Bake piecewise-planar stone heights and OpenGL normal maps; no micro-noise.

Two normal-map bases permit live mortar/detail controls without sampling height
at runtime. Public height/normal maps show the fully combined default presets.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
SOURCE = ROOT / "assets/textures/rooftop_run/floor.png"
CAPTURES = OUT / "captures/lowpoly-study"
CAPTURES.mkdir(parents=True, exist_ok=True)
PRESETS = {
    "diagnostic": dict(normal_strength=1.0, mortar_depth=1.0, detail_intensity=1.0, variation=0.25),
    "gameplay": dict(normal_strength=0.55, mortar_depth=0.65, detail_intensity=0.65, variation=0.15),
}
albedo = np.asarray(Image.open(SOURCE).convert("RGB"))
size = len(albedo)
assert albedo.shape == (1024, 1024, 3)
y, x = np.mgrid[0:size, 0:size].astype(float)
y = (y + 0.5) / size * 16
x = (x + 0.5) / size * 16 + np.mod(np.floor(y), 2) * 0.5
row, col = np.floor(y).astype(int), np.mod(np.floor(x), 16).astype(int)
u, v = np.mod(x, 1) - 0.5, np.mod(y, 1) - 0.5
mask = albedo[:, :, 0] > 80
# An octagonal footprint follows the original rounded rectangle but uses straight
# chamfers. Each term describes a plane; min/clamp create crisp slope changes.
distance = np.minimum.reduce([0.47 - abs(u), 0.43 - abs(v), (0.83 - abs(u) - abs(v)) / np.sqrt(2)])
mortar_height = np.clip(distance / 0.035, 0, 1) * 0.006 * mask
bevel = np.clip(distance / 0.12, 0, 1)
block_height = bevel * 0.024 * mask
# Four triangular planar top regions meet at a low central peak. The bevel
# surrounds the top, and the facet height is continuous at its rectangular rim.
facet_top = np.clip(np.minimum(1 - abs(u) / 0.35, 1 - abs(v) / 0.31), 0, 1)
facet_height = (bevel * 0.012 + facet_top * 0.032) * mask
# Stable, tileable, per-stone values only. No pixel noise or random texture grit.
random = np.mod(col * 73 + row * 151 + col * row * 19 + 41, 257) / 256
pixel_world = 4.0 / size

def slopes(height):
    return np.stack([(np.roll(height, -1, 1) - np.roll(height, 1, 1)) / (2 * pixel_world),
                     (np.roll(height, -1, 0) - np.roll(height, 1, 0)) / (2 * pixel_world)], axis=-1)

def normal_from_slopes(gradient):
    # Raster Y grows down; OpenGL tangent +Y points up the image.
    normal = np.stack([-gradient[:, :, 0], gradient[:, :, 1], np.ones(gradient.shape[:2])], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    return normal

def encode(normal):
    return np.uint8(np.rint(np.clip(normal * 0.5 + 0.5, 0, 1) * 255))

mortar_gradient = slopes(mortar_height)
Image.fromarray(encode(normal_from_slopes(mortar_gradient))).save(OUT / "lowpoly_mortar_normal.png")
results = {}
for style, detail_height in [("block", block_height), ("faceted", facet_height)]:
    detail_gradient = slopes(detail_height)
    detail_normal = normal_from_slopes(detail_gradient)
    # RGB is a normal map; alpha stores a single constant variation factor per
    # stone. Import losslessly so alpha remains available to the review shader.
    packed = np.dstack([encode(detail_normal), np.uint8(np.rint(random * 255))])
    Image.fromarray(packed).save(OUT / f"lowpoly_{style}_basis.png")
    for preset, values in PRESETS.items():
        amplitude = 1 + values["variation"] * 0.35 * (random * 2 - 1)
        height = (mortar_height * values["mortar_depth"] + detail_height * values["detail_intensity"] * amplitude) * values["normal_strength"]
        gradient = (mortar_gradient * values["mortar_depth"] + detail_gradient * (values["detail_intensity"] * amplitude)[:, :, None]) * values["normal_strength"]
        normal = normal_from_slopes(gradient)
        # Use the same display scale for the two strengths within each style.
        scale = 0.033 if style == "block" else 0.055
        Image.fromarray(np.uint8(np.rint(np.clip(height / scale, 0, 1) * 255))).save(OUT / f"{style}_{preset}_height.png")
        Image.fromarray(encode(normal)).save(OUT / f"{style}_{preset}_normal_gl.png")
        assert np.allclose(np.linalg.norm(normal, axis=-1), 1)
        assert float(height[~mask].max()) == 0
        results[f"{style}-{preset}"] = {**values, "peak_height_world": float(height.max()), "height_preview_white_world": scale}
    # Check actual face planarity, away from the two-texel crease antialiasing.
    if style == "block":
        assert np.max(abs(detail_gradient[(abs(u) < 0.30) & (abs(v) < 0.26)])) < 1e-10
    else:
        for patch in [(slice(14, 20), slice(27, 35)), (slice(44, 50), slice(27, 35)),
                      (slice(27, 35), slice(14, 20)), (slice(27, 35), slice(44, 50))]:
            sample = detail_gradient[patch]
            assert np.max(np.ptp(sample, axis=(0, 1))) < 1e-10, "Facet became curved."
    assert normal_from_slopes(detail_gradient)[10, 32, 1] > 0

report = {"source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(), "checks": "PASS", "facet_regions_per_top": 4,
          "source_albedo_changed": False, "presets": results}
(CAPTURES / "map-validation.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 27)
for style in ["block", "faceted"]:
    sheet = Image.new("RGB", (2048, 1084), "#142127")
    draw = ImageDraw.Draw(sheet)
    for i, (suffix, label) in enumerate([("height", "HEIGHT | diagnostic profile"), ("normal_gl", "NORMAL | OpenGL, planar slopes")]):
        sheet.paste(Image.open(OUT / f"{style}_diagnostic_{suffix}.png"), (i * 1024, 60))
        draw.text((i * 1024 + 20, 10), f"{style.upper()} {label}", fill="#f4ead2", font=font)
    sheet.save(CAPTURES / f"{style}-maps.png")
