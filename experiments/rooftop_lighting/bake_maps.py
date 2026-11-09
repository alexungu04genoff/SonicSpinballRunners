"""Bake clean bevel response aligned to the existing Rooftop cobble recipe.

No albedo changes, stochastic grit, displacement or external assets.
Requires Pillow and NumPy; rerun only when changing this experiment's maps.
"""
from pathlib import Path
import numpy as np
from PIL import Image

out = Path(__file__).parent
size = 1024
y, x = np.mgrid[0:size, 0:size].astype(float)
x = (x + 0.5) / size * 16
y = (y + 0.5) / size * 16
x += np.mod(np.floor(y), 2) * 0.5
cx, cy = np.floor(x), np.floor(y)
qx, qy = abs(np.mod(x, 1) - 0.5), abs(np.mod(y, 1) - 0.5)
d = np.hypot(np.maximum(qx - 0.35, 0), np.maximum(qy - 0.31, 0)) - 0.12
t = np.clip((d + 0.07) / 0.082, 0, 1)
height = (1 - t * t * (3 - 2 * t)) * 0.008
dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) / (8 / size)
dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) / (8 / size)
normal = np.stack([-dx, -dy, np.ones_like(dx)], axis=-1)
normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
Image.fromarray(np.uint8(np.clip(normal * 0.5 + 0.5, 0, 1) * 255)).save(out / "floor_normal.png")
variation = np.mod(np.sin(cx * 127.1 + cy * 311.7) * 43758.5453, 1)
roughness = np.clip(0.64 + variation * 0.15 + t * 0.18, 0, 1)
Image.fromarray(np.uint8(roughness * 255)).save(out / "floor_roughness.png")
