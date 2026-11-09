"""Compose Phase 1 boards from shader studies and authoritative production PNGs."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "v2"
CURRENT = ROOT / "assets/textures/sky_sanctuary"
FONT = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 20)
SMALL = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 16)
TITLE = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 27)
ROLES = {
    1: ("Bottom floor", "Ivory interlock", "Classic temple courses", "floor"),
    2: ("Bottom floor border", "Dentil coping", "Banded green stone", "floor-border"),
    3: ("Walls", "Monumental interlock", "Jade pilaster courses", "wall"),
    5: ("Second-floor surfaces", "Azure interlock", "Concentric relic inlay", "top"),
    6: ("Second-floor borders", "Green crown strip", "Carved chevron trim", "top-border"),
    7: ("Ramp decks", "Ivory causeway", "Azure route slabs", "ramp"),
    8: ("Ramp railguards", "Turquoise inset rail", "Carved stone rail", None),
    9: ("Exterior facades", "Ivory arcade", "Stepped temple coffers", "facade"),
}
REFERENCES = {
    1: ("Ref 6: stepped fitted stones", "Ref 9: dense cream masonry courses"),
    2: ("Ref 8: repeated teeth and molding", "Ref 9: green-and-cream column bands"),
    3: ("Refs 1, 6: interlock above blind arches", "Ref 9: framed courses and green columns"),
    5: ("Ref 4: blue fitted stone / turquoise joints", "Ref 2: concentric sectors and stone ribs"),
    6: ("Refs 3, 9: green crown / pale boundary", "Ref 7: broad carved zigzag frieze"),
    7: ("Ref 9: tiled ramps and green edge bands", "Refs 3, 4: blue interlocking stone strip"),
    8: ("Refs 1, 3: blue stone inset in pale trim", "Ref 7: carved zigzags between moldings"),
    9: ("Ref 7: small arches above chevron frieze", "Ref 8: stepped square coffer modules"),
}

def board(number):
    role, a, b, source = ROLES[number]
    height = 250 if number in (2, 6, 8) else 330 if number in (3, 9) else 450
    canvas = Image.new("RGB", (1200, height), "#202a35")
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 10), f"{number}. {role}", font=TITLE, fill="#f1eddb")
    for column, label in enumerate((f"A / {a}", f"B / {b}", "C / Current production")):
        x = 20 + column * 394
        draw.text((x, 52), label, font=FONT, fill="#d7e2e6")
        if column < 2:
            path = OUT / f"{number}{'AB'[column]}.png"
            image = Image.open(path).convert("RGB")
        elif source:
            path = CURRENT / f"{source}.png"
            image = Image.open(path).convert("RGB")
        else:
            # A color key for the real untextured StandardMaterial3D, not a new texture.
            image = Image.new("RGB", (512, 128), "#c8c4a2")
        image.thumbnail((374, height - 140), Image.Resampling.LANCZOS)
        canvas.paste(image, (x + (374-image.width)//2, 87))
        note = REFERENCES[number][column] if column < 2 else (f"Source: {source}.png (unchanged)" if source else "Material color #c8c4a2; no texture")
        draw.text((x, height - 40), note, font=SMALL, fill="#c3d0d6")
        if column < 2:
            draw.text((x, height - 20), "Pass 2 / albedo only", font=SMALL, fill="#9eb0b7")
    canvas.save(OUT / f"choices-{number}.png")
    return canvas

boards = {number: board(number) for number in ROLES}
for page, items in enumerate(((1, 2, 3), (5, 6, 7), (8, 9)), 1):
    canvas = Image.new("RGB", (1200, 68 + sum(boards[n].height + 8 for n in items)), "#101923")
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 14), "SKY SANCTUARY / PHASE 1 / SECOND PASS", font=TITLE, fill="#f1eddb")
    y = 68
    for number in items:
        canvas.paste(boards[number], (0, y))
        y += boards[number].height + 8
    canvas.save(OUT / f"board-{page}.png")
print("Three comparison boards saved; existing C textures read only.")
