"""Boards for reopened Phase 1 concepts; production and locked artwork are read-only."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE / "v3"
CURRENT = HERE.parents[1] / "assets/textures/sky_sanctuary"
TITLE = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 27)
FONT = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 21)
SMALL = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 16)

def compose(name, title, entries, height=470):
    board = Image.new("RGB", (1200, height), "#202a35")
    draw = ImageDraw.Draw(board)
    draw.text((20, 12), title, font=TITLE, fill="#f1eddb")
    width = 1160 // len(entries)
    for i, (label, path, note) in enumerate(entries):
        x = 20 + width*i
        draw.text((x, 55), label, font=FONT, fill="#e2e8df")
        image = Image.open(path).convert("RGB")
        image.thumbnail((width-20, height-145), Image.Resampling.LANCZOS)
        board.paste(image, (x+(width-20-image.width)//2, 93))
        draw.text((x, height-38), note, font=SMALL, fill="#bdcbd0")
    board.save(OUT/name)

compose("choices-1.png", "1. Bottom floor / reopened A", [
    ("A / Keyed sanctuary slabs", OUT/"1A.png", "Ref 6 + Generations pale stone framing"),
    ("B / Previous alternative", HERE/"v2/1B.png", "Unchanged; sprite-sheet masonry rhythm"),
    ("C / Current production", CURRENT/"floor.png", "Existing floor.png; unchanged"),
])
compose("choices-4.png", "4. Wall transition cap / one proposal", [
    ("A / Paneled limestone cornice", OUT/"4A.png", "Ref 8 + Generations platform cornices; material study only"),
], 400)
compose("choices-5.png", "5. Second-floor surfaces / new alternatives", [
    ("A / Sanctuary turf", OUT/"5A.png", "Generations spiral path + sprite-sheet crowns"),
    ("B / Turquoise inset courts", OUT/"5B.png", "Generations inset paths + refs 2 and 4"),
    ("C / Current production", CURRENT/"top.png", "Existing top.png; unchanged"),
])
print("Three reopened-concept boards saved.")
