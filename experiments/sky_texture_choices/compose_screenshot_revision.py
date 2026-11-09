"""Present the requested 1A and 5A corrections with unchanged production C."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE / "v4"
CURRENT = HERE.parents[1] / "assets/textures/sky_sanctuary"
TITLE = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 27)
FONT = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 20)
SMALL = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 16)
for number, title, name, source, note in [
    (1, "Bottom floor", "Keyed slabs + blue inset run", "floor", "New screenshot: central blue panels within pale paving"),
    (5, "Second-floor surfaces", "Garden paving", "top", "New screenshot: stepped grass patches between stone slabs"),
]:
    board = Image.new("RGB", (1100, 635), "#202a35")
    draw = ImageDraw.Draw(board)
    draw.text((20, 12), f"{number}. {title} / requested revision", font=TITLE, fill="#f1eddb")
    for x, label, path in [
        (20, f"{number}A / {name}", OUT / f"{number}A.png"),
        (570, f"{number}C / Current production", CURRENT / f"{source}.png"),
    ]:
        draw.text((x, 56), label, font=FONT, fill="#e2e8df")
        image = Image.open(path).convert("RGB")
        image = image.resize((510, 510), Image.Resampling.LANCZOS)
        board.paste(image, (x, 92))
    draw.text((20, 611), note, font=SMALL, fill="#bdcbd0")
    draw.text((570, 611), f"Existing {source}.png; unchanged", font=SMALL, fill="#bdcbd0")
    board.save(OUT / f"choices-{number}.png")
print("Two revised-concept comparison boards saved.")
