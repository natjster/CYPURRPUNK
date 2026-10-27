"""YouTube thumbnail (1280x720): a game still + the CYPURRPUNK logo + a tag line.

The still is filmed with DevCapture (see SETUP_GUIDE section 15, "Thumbnail"), e.g. the hero cat
with the MEGA VAC-COP behind it. Then:   python trailer/thumbnail.py
Output: shots/thumb/thumbnail_*.jpg
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

import cards

THUMBS = Path(__file__).resolve().parent.parent / "shots" / "thumb"
SIZE = (1280, 720)
TAG = "REVEAL TRAILER"
# still file -> output name
STILLS = {"raw_b.png": "thumbnail_red", "raw_a.png": "thumbnail_blue"}


def trimmed(png: Path) -> Image.Image:
    """Opens a cards.py PNG and cuts it down to just the drawn letters."""
    image = Image.open(png)
    return image.crop(image.getbbox())


def make(still: Path, out: Path) -> None:
    picture = Image.open(still).convert("RGB")
    # Zoom in on the left three quarters (past the CRT's curved black edges), so the cat - standing
    # in the middle of the still - ends up on the right, leaving room on the left for the words.
    w, h = picture.size
    picture = picture.crop((int(w * 0.02), int(h * 0.12), int(w * 0.77), int(h * 0.12) + int(w * 0.75 * 9 / 16)))
    picture = picture.resize(SIZE, Image.LANCZOS)
    picture = ImageEnhance.Brightness(picture).enhance(1.35)
    picture = ImageEnhance.Color(picture).enhance(1.35)
    picture = ImageEnhance.Contrast(picture).enhance(1.12)
    # Darken the left and the bottom so the words stand out.
    shade = Image.new("L", SIZE, 0)
    draw = ImageDraw.Draw(shade)
    for x in range(SIZE[0]):
        draw.line([(x, 0), (x, SIZE[1])], fill=int(170 * max(0.0, 1 - x / (SIZE[0] * 0.55))))
    shade = shade.filter(ImageFilter.GaussianBlur(30))
    picture = Image.composite(Image.new("RGB", SIZE, (6, 2, 14)), picture, shade).convert("RGBA")

    work = THUMBS / "work"
    logo = trimmed(cards.text_png(work / "logo.png", ["CYPURRPUNK"], (2560, 720), pixel=9, font_px=20,
                                  color=cards.PINK))
    logo = logo.resize((int(SIZE[0] * 0.62), int(logo.height * SIZE[0] * 0.62 / logo.width)), Image.NEAREST)
    picture.alpha_composite(logo, (36, 40))
    tag = trimmed(cards.text_png(work / "tag.png", [TAG], (1280, 720), pixel=6, font_px=12, color=cards.YELLOW))
    band = Image.new("RGBA", (tag.width + 40, tag.height + 26), (8, 2, 16, 220))
    band_y = SIZE[1] - band.height - 40  # bottom left
    picture.alpha_composite(band, (36, band_y))
    picture.alpha_composite(tag, (56, band_y + 13))
    out.parent.mkdir(parents=True, exist_ok=True)
    picture.convert("RGB").save(out.with_suffix(".jpg"), quality=92)
    print(out.with_suffix(".jpg"))


if __name__ == "__main__":
    for still, name in STILLS.items():
        make(THUMBS / still, THUMBS / name)
