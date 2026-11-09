"""Make single-texture and honest tiled previews for the eight selected albedos."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
TITLE = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 25)
SMALL = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 17)
ITEMS = {
    "1A": ("Bottom floor / keyed slabs and blue insets", "Blue strips form parallel runs when repeated; path placement waits for Phase 3."),
    "2B": ("Bottom border / banded green stone", "Lengthwise repeat; stone segments meet at the tile boundary."),
    "3B": ("Walls / jade columns and masonry", "Three whole column modules per tile; horizontal repeat only."),
    "5A": ("Upper surfaces / garden paving", "Approved grass islands repeat visibly; roughly 70% stone / 30% turf."),
    "6A": ("Upper borders / green crown strip", "Shares the selected coping design with 2B; mapping controls physical size."),
    "7B": ("Ramp decks / azure fitted stone", "Fitted block groups repeat; route direction and scale wait for Phase 3."),
    "8A": ("Ramp guards / azure inset rail", "Continuous inset band; horizontal repeat only."),
    "9B": ("Facades / stepped temple coffers", "Four complete coffer modules per tile; horizontal repeat only."),
}
manifest = {"phase": 2, "status": "awaiting_visual_approval", "maps": "albedo_only", "integration": False, "items": {}}
boards = {}
for key, (title, note) in ITEMS.items():
    path = OUT / f"{key}.png"
    image = Image.open(path).convert("RGB")
    square = image.width == image.height
    repeats = (2, 2) if square else (3, 1)
    tiled = Image.new("RGB", (image.width*repeats[0], image.height*repeats[1]))
    for y in range(repeats[1]):
        for x in range(repeats[0]):
            tiled.paste(image, (x*image.width, y*image.height))
    tiled.save(OUT / f"{key}-repeat.png")
    height = 480 if square else 325 if image.height == 256 else 250
    board = Image.new("RGB", (1100, height), "#202a35")
    draw = ImageDraw.Draw(board)
    draw.text((18, 10), f"{key} / {title}", font=TITLE, fill="#f1eddb")
    draw.text((18, 50), f"Refined albedo / {image.width} x {image.height}", font=SMALL, fill="#bdcbd0")
    draw.text((560, 50), f"Repeat / {repeats[0]} x {repeats[1]}", font=SMALL, fill="#bdcbd0")
    for x, picture in ((18, image.copy()), (560, tiled.copy())):
        picture.thumbnail((520, height-120), Image.Resampling.LANCZOS)
        board.paste(picture, (x+(520-picture.width)//2, 82))
    draw.text((18, height-28), note, font=SMALL, fill="#bdcbd0")
    board.save(OUT / f"{key}-review.png")
    boards[key] = board
    manifest["items"][key] = {"file": path.name, "size": image.size, "repeat_axes": "xy" if square else "x", "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "review_note": note}

for number, keys in enumerate((("1A", "2B", "3B"), ("5A", "6A", "7B"), ("8A", "9B")), 1):
    board = Image.new("RGB", (1100, sum(boards[k].height+8 for k in keys)+57), "#101923")
    draw = ImageDraw.Draw(board)
    draw.text((18, 12), "SKY SANCTUARY / PHASE 2 / ALBEDO REVIEW", font=TITLE, fill="#f1eddb")
    y = 57
    for key in keys:
        board.paste(boards[key], (0, y))
        y += boards[key].height+8
    board.save(OUT / f"review-{number}.png")
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
print("Eight single/repeat reviews and three grouped boards saved.")
