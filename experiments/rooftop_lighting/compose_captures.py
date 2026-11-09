"""Arrange unretouched Godot captures into labelled review sheets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

folder = Path(__file__).parent / "captures"
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 30)

def sheet(filename, entries):
    result = Image.new("RGB", (1280 * len(entries), 750), "#142127")
    draw = ImageDraw.Draw(result)
    for i, (name, label) in enumerate(entries):
        result.paste(Image.open(folder / f"{name}.png"), (i * 1280, 60))
        draw.text((i * 1280 + 24, 10), label, font=font, fill="#f4ead2")
    result.save(folder / filename)

sheet("comparison.png", [("current", "1  Current"), ("lighting-only", "2  Lighting only"), ("material-detail", "3  Lighting + subtle material detail")])
sheet("floor-comparison.png", [("floor-close-lighting-only", "Flat floor / same experimental lighting"), ("floor-close-normal-only", "+ Subtle normal map"), ("floor-close-normal-roughness", "+ Normal map and roughness response")])
