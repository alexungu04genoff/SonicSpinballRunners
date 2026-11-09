"""Validate paired normal/retro captures, inspect temporal noise, and encode review videos."""
from pathlib import Path
import json
import subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "captures/retro-scene-study"
report = json.loads((OUT / "validation.json").read_text())
assert report["failures"] == 0
assert report["fixed_camera_fixed_filter_time_pixel_identical"]
MODES = ["none", "beveled", "faceted", "hybrid"]
LABELS = ["No generated normals", "A | Beveled", "B | Faceted", "C | Hybrid"]
FONT = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 28)
SMALL = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 24)
FFMPEG = "C:/ProgramData/chocolatey/bin/ffmpeg.exe"
keys = [f"{style}-{mode}" for style in ["normal", "retro"] for mode in MODES]
reference = report["stills"][keys[0]]
for key in keys:
    state = report["stills"][key]
    for field in ["camera", "fov", "projection", "size", "lighting", "strengths", "filter_settings", "output_resolution"]:
        assert state[field] == reference[field], (key, field)
    assert state["geometry_unchanged"]
    assert state["effects"] == ([2, 4, 3] if key.startswith("retro") else [])
    sequence = report["sequences"][key]
    assert sequence["geometry_gameplay_unchanged"]
    assert sequence["trajectory"] == report["sequences"][keys[0]]["trajectory"]
    assert sequence["shader_times"] == report["sequences"][keys[0]]["shader_times"]
    assert len(list((OUT / key).glob("*.png"))) == 180

def rgb(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)

def panel(sheet, x, y, source, title):
    ImageDraw.Draw(sheet).text((x + 20, y + 12), title, font=FONT, fill="#f4ead2")
    sheet.paste(Image.open(source).convert("RGB"), (x, y + 60))

paired = Image.new("RGB", (2560, 3000), "#142127")
for style in ["normal", "retro"]:
    sheet = Image.new("RGB", (2560, 1500), "#142127")
    for index, (mode, label) in enumerate(zip(MODES, LABELS)):
        title = label + (" | Retro OFF" if style == "normal" else " | Saved N64 + VHS + CRT")
        panel(sheet, index % 2 * 1280, index // 2 * 750, OUT / f"{style}-{mode}.png", title)
        panel(paired, 0 if style == "normal" else 1280, index * 750, OUT / f"{style}-{mode}.png", title)
    sheet.save(OUT / f"{style}-comparison.png")
paired.save(OUT / "normal-vs-retro-all.png")

# Central playfield: broad material response, excluding most distant scenery.
roi = (slice(180, 565), slice(420, 900))
noise_roi = (slice(420, 535), slice(680, 890))
broad = {}
for mode in MODES[1:]:
    deltas = []
    for style in ["normal", "retro"]:
        images = [np.asarray(Image.open(OUT / f"{style}-{name}.png").convert("RGB").filter(ImageFilter.GaussianBlur(2)), dtype=float)[roi] for name in ["none", mode]]
        deltas.append(images[1] - images[0])
    broad[mode] = {
        "normal_lowpass_mean_abs_rgb_difference": float(abs(deltas[0]).mean()),
        "retro_lowpass_mean_abs_rgb_difference": float(abs(deltas[1]).mean()),
        "normal_retro_lowpass_response_correlation": float(np.corrcoef(deltas[0].ravel(), deltas[1].ravel())[0, 1]),
    }

temporal = {}
for key in keys:
    values = []
    previous = rgb(OUT / key / "0000.png")[noise_roi]
    for frame in range(1, 30):
        current = rgb(OUT / key / f"{frame:04d}.png")[noise_roi]
        values.append(float(abs(current - previous).mean()))
        previous = current
    temporal[key] = {"stationary_camera_mean_frame_difference_rgb": float(np.mean(values)), "max_frame_difference_rgb": max(values)}

# Inspect the material-only temporal residual along the identical camera path.
# This includes the legitimate motion of material edges; it is not a measured
# shimmer score or motion-compensated optical-flow benchmark.
motion = {}
for style in ["normal", "retro"]:
    previous = {}
    values = {mode: [] for mode in MODES[1:]}
    for frame in range(30, 150, 3):
        base = rgb(OUT / f"{style}-none" / f"{frame:04d}.png")[roi]
        for mode in MODES[1:]:
            delta = rgb(OUT / f"{style}-{mode}" / f"{frame:04d}.png")[roi] - base
            if mode in previous: values[mode].append(float(abs(delta - previous[mode]).mean()))
            previous[mode] = delta
    motion[style] = {mode: float(np.mean(v)) for mode, v in values.items()}

summary = {"checks": "PASS", "same_cameras_lighting_exposure_strengths_settings": True,
           "same_motion_trajectory_and_VHS_phase": True, "sequences": 8, "total_frames": 1440,
           "video_fps": 30, "video_seconds": 6, "camera_motion_seconds": 4,
           "fixed_camera_fixed_filter_time_pixel_identical": True,
           "broad_material_response": broad, "stationary_camera_temporal_noise": temporal,
           "moving_material_difference_change_per_3_frames_not_a_shimmer_score": motion}
(OUT / "comparison-validation.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2), flush=True)

# Native-size crops from moving frames, for inspecting seams and thin railguards.
film = Image.new("RGB", (1600, 8 * 300), "#142127")
crop = (450, 280, 850, 520)
for row, key in enumerate(keys):
    for col, frame in enumerate([30, 60, 90, 120]):
        ImageDraw.Draw(film).text((col * 400 + 8, row * 300 + 12), f"{key} | frame {frame}", font=SMALL, fill="#f4ead2")
        film.paste(Image.open(OUT / key / f"{frame:04d}.png").crop(crop), (col * 400, row * 300 + 60))
film.save(OUT / "moving-frame-detail-sheet.png")

headers = OUT / "video-headers"
headers.mkdir(exist_ok=True)
def encode(arguments, filename):
    command = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", *arguments,
               "-frames:v", "180", "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "16",
               "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUT / filename)]
    subprocess.run(command, check=True)
    print("VIDEO | " + filename, flush=True)

for mode, label in zip(MODES, LABELS):
    header = Image.new("RGB", (2560, 60), "#142127")
    draw = ImageDraw.Draw(header)
    draw.text((20, 12), label + " | Retro OFF", font=FONT, fill="#f4ead2")
    draw.text((1300, 12), label + " | Saved N64 + VHS + CRT", font=FONT, fill="#f4ead2")
    hp = headers / f"{mode}.png"
    header.save(hp)
    encode(["-framerate", "30", "-i", str(OUT / f"normal-{mode}/%04d.png"),
            "-framerate", "30", "-i", str(OUT / f"retro-{mode}/%04d.png"),
            "-loop", "1", "-framerate", "30", "-i", str(hp),
            "-filter_complex", "[0:v][1:v]hstack=inputs=2,pad=2560:750:0:60:color=0x142127[body];[body][2:v]overlay=0:0:shortest=1[out]",
            "-map", "[out]"], f"{mode}-normal-vs-retro.mp4")

for style in ["normal", "retro"]:
    header = Image.new("RGBA", (2560, 1500), (0, 0, 0, 0))
    draw = ImageDraw.Draw(header)
    inputs, filters = [], []
    for index, (mode, label) in enumerate(zip(MODES, LABELS)):
        x, y = index % 2 * 1280, index // 2 * 750
        draw.rectangle((x, y, x + 1280, y + 59), fill="#142127")
        draw.text((x + 20, y + 12), label + " | " + style.upper(), font=FONT, fill="#f4ead2")
        inputs += ["-framerate", "30", "-i", str(OUT / f"{style}-{mode}/%04d.png")]
        filters.append(f"[{index}:v]pad=1280:750:0:60:color=0x142127[p{index}]")
    hp = headers / f"{style}-grid.png"
    header.save(hp)
    inputs += ["-loop", "1", "-framerate", "30", "-i", str(hp)]
    filters.append("[p0][p1][p2][p3]xstack=inputs=4:layout=0_0|1280_0|0_750|1280_750[body]")
    filters.append("[body][4:v]overlay=0:0:shortest=1[out]")
    encode([*inputs, "-filter_complex", ";".join(filters), "-map", "[out]"], f"{style}-four-way-motion.mp4")
