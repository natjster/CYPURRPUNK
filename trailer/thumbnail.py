"""YouTube thumbnails (1280x720): a game still + the CYPURRPUNK logo + a tag line.

The stills are filmed with DevCapture (see SETUP_GUIDE section 15, "Thumbnail"). Then:
    python trailer/thumbnail.py
Output: shots/thumb/thumbnail_*.jpg
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

import cards

THUMBS = Path(__file__).resolve().parent.parent / "shots" / "thumb"
SIZE = (1280, 720)

# One entry per thumbnail:
#   still = the picture in shots/thumb/      crop = (left, top, right) as fractions of the still
#             (the height follows, to keep 16:9)
#   logo  = "left" (top-left, big) or "top" (centred across the top)
#   tag   = the words in the yellow band, and where: "bottom-left" or "bottom-right"
THUMBNAILS = {
    # The hero cat with the MEGA VAC-COP right behind it (menace).
    "thumbnail_red": {"still": "raw_b.png", "crop": (0.02, 0.12, 0.77), "logo": "left",
                      "tag": ("REVEAL TRAILER", "bottom-left")},
    "thumbnail_blue": {"still": "raw_a.png", "crop": (0.02, 0.12, 0.77), "logo": "left",
                       "tag": ("REVEAL TRAILER", "bottom-left")},
    # Side-on gunfight: laser beam, exploding VAC-COP (action).
    "thumbnail_gunfight": {"still": "gun_40.png", "crop": (0.09, 0.03, 0.95), "logo": "top",
                           "tag": ("REVEAL TRAILER", "bottom-right")},
}


def trimmed(png: Path) -> Image.Image:
    """Opens a cards.py PNG and cuts it down to just the drawn letters."""
    image = Image.open(png)
    return image.crop(image.getbbox())


def shade_mask(where: str) -> Image.Image:
    """Where to darken the picture behind the logo: the left side, or the top."""
    mask = Image.new("L", SIZE, 0)
    draw = ImageDraw.Draw(mask)
    if where == "left":
        for x in range(SIZE[0]):
            draw.line([(x, 0), (x, SIZE[1])], fill=int(170 * max(0.0, 1 - x / (SIZE[0] * 0.55))))
    else:
        for y in range(SIZE[1]):
            draw.line([(0, y), (SIZE[0], y)], fill=int(190 * max(0.0, 1 - y / (SIZE[1] * 0.42))))
    return mask.filter(ImageFilter.GaussianBlur(30))


def make(name: str, plan: dict) -> None:
    picture = Image.open(THUMBS / plan["still"]).convert("RGB")
    w, h = picture.size
    left, top, right = plan["crop"]
    box_w = int(w * (right - left))
    picture = picture.crop((int(w * left), int(h * top), int(w * right), int(h * top) + box_w * 9 // 16))
    picture = picture.resize(SIZE, Image.LANCZOS)
    # Brighter and punchier for a small phone screen.
    picture = ImageEnhance.Brightness(picture).enhance(1.35)
    picture = ImageEnhance.Color(picture).enhance(1.35)
    picture = ImageEnhance.Contrast(picture).enhance(1.12)
    picture = Image.composite(Image.new("RGB", SIZE, (6, 2, 14)), picture, shade_mask(plan["logo"])).convert("RGBA")

    work = THUMBS / "work"
    logo = trimmed(cards.text_png(work / "logo.png", ["CYPURRPUNK"], (2560, 720), pixel=9, font_px=20,
                                  color=cards.PINK))
    share = 0.62 if plan["logo"] == "left" else 0.74  # how much of the width the logo takes
    logo = logo.resize((int(SIZE[0] * share), int(logo.height * SIZE[0] * share / logo.width)), Image.NEAREST)
    logo_x = 36 if plan["logo"] == "left" else (SIZE[0] - logo.width) // 2
    picture.alpha_composite(logo, (logo_x, 40))

    words, corner = plan["tag"]
    tag = trimmed(cards.text_png(work / "tag.png", [words], (1280, 720), pixel=6, font_px=12, color=cards.YELLOW))
    band = Image.new("RGBA", (tag.width + 40, tag.height + 26), (8, 2, 16, 220))
    band_x = 36 if corner == "bottom-left" else SIZE[0] - band.width - 36
    band_y = SIZE[1] - band.height - 40
    picture.alpha_composite(band, (band_x, band_y))
    picture.alpha_composite(tag, (band_x + 20, band_y + 13))

    out = THUMBS / f"{name}.jpg"
    picture.convert("RGB").save(out, quality=92)
    print(out)


if __name__ == "__main__":
    for thumb_name, thumb_plan in THUMBNAILS.items():
        if (THUMBS / thumb_plan["still"]).exists():
            make(thumb_name, thumb_plan)
