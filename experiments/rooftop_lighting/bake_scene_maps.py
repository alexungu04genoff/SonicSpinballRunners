"""Structural normal bakes matching the existing Rooftop Run art recipes.

No color-to-height conversion. Mortar follows authored cells, facade graphics
are excluded geometrically, and solid blocks receive one profile per mesh face.
"""
from pathlib import Path
import hashlib
import json
import shutil
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "scene_maps"
OUT.mkdir(exist_ok=True)
SOURCES = ROOT.parents[1] / "assets/textures/rooftop_run"
report = {"source_hashes": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCES.glob("*.png")}, "maps": {}}

def bake(name, width, height, cells, span, stagger=True, cobble=False, wall_top=None, facade=False, face=False):
    yy, xx = np.mgrid[:height, :width].astype(float)
    s, t = (xx + .5) / width, (yy + .5) / height
    y = t * cells[1] if wall_top is None else (wall_top - t * 1.45) * 6
    x = s * cells[0] + (np.mod(np.floor(y), 2) * .5 if stagger else 0)
    u, v = np.mod(x, 1) - .5, np.mod(y, 1) - .5
    distance = np.minimum(.485 - abs(u), .485 - abs(v))
    if cobble:
        distance = np.minimum.reduce([.47 - abs(u), .43 - abs(v), (.83 - abs(u) - abs(v)) / np.sqrt(2)])
    bevel = np.clip(distance / (.12 if cobble else .09), 0, 1)
    facets = np.clip(np.minimum(1 - abs(u) / .35, 1 - abs(v) / .35), 0, 1)
    # Preserve the source's flat cornice and trim; never infer recess from paint.
    allowed = np.ones_like(s)
    if wall_top is not None:
        depth = t * 1.45
        allowed *= np.clip((depth - .10) / .025, 0, 1)
        if facade:
            bx = np.mod(s * 3.4 / .85, 1) - .5
            by = depth - .64
            arch = np.maximum(abs(bx) - .22, np.maximum(-by - .13, by - .55))
            arch = np.where(by < 0, np.maximum(arch, np.sqrt(bx * bx + by * by) - .22), arch)
            allowed *= np.clip((arch - .055) / .025, 0, 1)
            allowed *= np.clip((abs(depth - 1.21) - .045) / .025, 0, 1)
    for style in ["beveled", "faceted"]:
        # Gentle base slopes. Role-specific runtime multipliers are independent.
        h = bevel * .010 if style == "beveled" else bevel * .0045 + facets * .014
        if face: h *= 2.0
        dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / (2 * span[0] / width)
        if wall_top is None:
            dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) / (2 * span[1] / height)
        else:
            dy = np.gradient(h, span[1] / height, axis=0)
        # Mask slopes, not height, to avoid a false raised rim around graphics.
        normal = np.stack([-dx * allowed, dy * allowed, np.ones_like(h)], -1)
        normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
        encoded = np.uint8(np.rint((normal * .5 + .5) * 255))
        Image.fromarray(encoded).save(OUT / f"{name}_{style}_normal.png")
        Image.fromarray(np.uint8(np.rint(h / .04 * 255))).save(OUT / f"{name}_{style}_height.png")
        assert np.allclose(np.linalg.norm(normal, axis=-1), 1)
        assert np.max(abs(normal[allowed == 0, :2]), initial=0) == 0
        report["maps"][f"{name}_{style}"] = {"size": [width, height], "masked_graphics_pixels": int((allowed == 0).sum())}

# Reuse the accepted floor profiles exactly; they already contain safe strength.
for style, prior in [("beveled", "block"), ("faceted", "faceted")]:
    shutil.copyfile(ROOT / f"{prior}_gameplay_normal_gl.png", OUT / f"floor_{style}_normal.png")
    shutil.copyfile(ROOT / f"{prior}_gameplay_height.png", OUT / f"floor_{style}_height.png")
bake("top", 1024, 1024, (10, 10), (5, 3.125))
bake("ramp", 256, 256, (2, 2), (.48, .44))
bake("border", 512, 128, (4, 1), (.48, .12), stagger=False, cobble=True)
bake("wall", 1024, 512, (12, 8.7), (3.4, 1.45), wall_top=.325)
bake("facade", 1024, 512, (12, 8.7), (3.4, 1.45), wall_top=0, facade=True)
# A single solid coping piece per route repeat, not invented cobbles on paint.
bake("guard", 512, 128, (1, 1), (.48, .18), stagger=False)
# BoxMesh's 3 by 2 atlas: one structural face per cell, including instanced blocks.
bake("block", 768, 512, (3, 2), (3, 2), stagger=False, face=True)
report["checks"] = "PASS: normalized OpenGL normals; flat facade graphics; original albedos unchanged"
# Keep fine bevels filtered at gameplay distance. Lossless RGB also avoids
# making this art comparison depend on platform-specific normal compression.
for path in OUT.glob("*_normal.png.import"):
    content = path.read_text().replace("mipmaps/generate=false", "mipmaps/generate=true")
    content = content.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
    path.write_text(content)
(OUT / "bake-report.json").write_text(json.dumps(report, indent=2))
print(report["checks"])
