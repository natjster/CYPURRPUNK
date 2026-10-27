"""Text for the trailers: chunky pixel lettering with a CRT colour fringe, as see-through PNGs.

trailer/edit.py calls text_png() for every caption; nothing to run by hand.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = r"C:\Windows\Fonts\consolab.ttf"  # Consolas Bold: like the game's HUD
PINK = (255, 79, 216)
CYAN = (79, 240, 255)
YELLOW = (242, 209, 75)
GREEN = (108, 255, 138)
WHITE = (240, 236, 255)


def text_png(path: Path, lines: list[str], canvas: tuple[int, int], *, pixel: int = 6, font_px: int = 14,
             color=WHITE, centre_y: float = 0.5, line_gap: float = 1.25, glow: bool = True,
             box: bool = False) -> Path:
    """Draws centred lines of text on a see-through canvas and saves it.

    pixel   = how many screen pixels one 'game pixel' of the letters becomes (chunkiness).
    font_px = letter height in game pixels.  centre_y = where the block sits (0 top .. 1 bottom).
    box     = a dark band behind the text (for captions over busy footage).
    """
    width, height = canvas
    font = ImageFont.truetype(FONT, font_px)
    # Too wide for the screen (long captions on a phone)? Smaller chunks until it fits.
    widest = max(font.getlength(line) for line in lines) + 4
    while pixel > 2 and widest * pixel > width * 0.92:
        pixel -= 1
    small = Image.new("RGBA", (width // pixel, height // pixel), (0, 0, 0, 0))
    draw = ImageDraw.Draw(small)
    line_h = int(font_px * line_gap)
    block_h = line_h * len(lines)
    top = int(small.height * centre_y - block_h / 2)
    if box:
        draw.rectangle([0, top - font_px // 2, small.width, top + block_h + font_px // 3], fill=(8, 2, 16, 170))
    for n, line in enumerate(lines):
        line_w = draw.textlength(line, font=font)
        x = (small.width - line_w) / 2
        y = top + n * line_h
        # The CRT fringe: a cyan copy one pixel left, a pink one right, the real colour on top.
        draw.text((x - 1, y), line, font=font, fill=CYAN + (200,))
        draw.text((x + 1, y), line, font=font, fill=PINK + (200,))
        draw.text((x, y), line, font=font, fill=tuple(color) + (255,))
    # Hard alpha (no soft anti-aliased edges) = crisp pixel letters when blown up.
    alpha = small.getchannel("A").point(lambda a: 255 if a > 110 else (170 if box and a > 100 else 0))
    small.putalpha(alpha)
    big = small.resize((small.width * pixel, small.height * pixel), Image.NEAREST)
    if glow:
        halo = big.filter(ImageFilter.GaussianBlur(pixel * 2.5))
        halo.putalpha(halo.getchannel("A").point(lambda a: a // 2))
        big = Image.alpha_composite(halo, big)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    out.paste(big, (0, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)
    return path


def logo_png(path: Path, canvas: tuple[int, int], *, pixel: int = 10, tagline: str = "",
             centre_y: float = 0.45) -> Path:
    """The CYPURRPUNK title: big pink letters, cyan fringe, a tagline under it."""
    width, height = canvas
    title = text_png(path.with_name(path.stem + "_t.png"), ["CYPURRPUNK"], canvas, pixel=pixel, font_px=20,
                     color=PINK, centre_y=centre_y)
    image = Image.open(title)
    if tagline:
        tag = Image.open(text_png(path.with_name(path.stem + "_g.png"), [tagline], canvas, pixel=max(6, pixel // 2),
                                  font_px=12, color=CYAN, centre_y=centre_y + 0.13))
        image = Image.alpha_composite(image, tag)
    image.save(path)
    return path
