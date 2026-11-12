"""CYPURRPUNK - makes the cat COAT pattern textures (textures/cat_coat_*.png).

Run from the project folder:  python tools/make_cat_coats.py
(Needs Pillow: pip install pillow.) Re-running gives the same pictures (fixed random seeds).

How a coat texture works (shaders/psx_lit.gdshader):
  - the GREY level darkens the fur colour (240 = the fur colour itself, low = dark stripes/spots),
  - ALPHA 0 pixels are painted in the cat's MARKINGS colour instead (white patches on calico,
    tuxedo socks). Fully opaque textures have no patches.
Body textures are 32x32 (wrap round the body/head, same as the tabby), limb textures 16x16
(legs and tail). Every picture tiles left-to-right, because it wraps all the way round the cat.
The original tabby (cat_tabby.png / cat_tabby_rings.png) is NOT made here: it stays as it is.
"""
import math
import random
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "textures"
BASE = 240  # same light grey as the tabby: the fur colour shows almost exactly


def new(size):
    return [[[BASE, 255] for _ in range(size)] for _ in range(size)]


def save(px, name):
    size = len(px)
    im = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            g, a = px[y][x]
            im.putpixel((x, y), (g, g, g, a))
    im.save(OUT / name)
    print("wrote", name)


def blob(px, cx, cy, rx, ry, grey=None, patch=False):
    """A soft-edged oval (wraps left/right). grey = darken to this; patch = markings colour."""
    size = len(px)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        if not 0 <= y < size:
            continue
        for dx in range(int(-rx) - 1, int(rx) + 2):
            x = int(cx + dx) % size
            if (dx / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                if patch:
                    px[y][x] = [BASE, 0]
                elif grey is not None and px[y][x][1] == 255:
                    px[y][x][0] = min(px[y][x][0], grey)


def tiger():
    # Bold, dark, thick stripes all over (darker and wider than the tabby's).
    body = new(32)
    for band in range(4):
        y0 = 2 + band * 8
        for x in range(32):
            wave = 1.6 * math.sin((x / 32) * 2 * math.pi * 2 + band)
            for y in range(32):
                if abs(y - (y0 + wave)) < 1.6:
                    body[y][x][0] = 90
    limbs = new(16)
    for y in range(16):
        if y % 8 < 4:
            for x in range(16):
                limbs[y][x][0] = 90
    save(body, "cat_coat_tiger.png")
    save(limbs, "cat_coat_tiger_rings.png")


def spotted():
    # Leopard / bengal: dark spots with a lighter middle (little rosettes).
    rng = random.Random(7)
    body = new(32)
    for row in range(5):
        for col in range(5):
            cx = col * 6.4 + (3.2 if row % 2 else 0) + rng.uniform(-1, 1)
            cy = 3 + row * 6.2 + rng.uniform(-0.8, 0.8)
            blob(body, cx, cy, 2.2, 1.7, grey=110)
            blob(body, cx, cy, 0.9, 0.7, grey=200)  # lighter centre
    limbs = new(16)
    for row in range(3):
        for col in range(3):
            blob(limbs, col * 5.3 + (2.6 if row % 2 else 0), 2.5 + row * 5.3, 1.5, 1.2, grey=110)
    save(body, "cat_coat_spotted.png")
    save(limbs, "cat_coat_spotted_rings.png")


def ticked():
    # Abyssinian "ticked" coat: fine salt-and-pepper speckle, no real stripes.
    rng = random.Random(3)
    for size, name in ((32, "cat_coat_ticked.png"), (16, "cat_coat_ticked_rings.png")):
        px = new(size)
        for y in range(size):
            for x in range(size):
                r = rng.random()
                px[y][x][0] = 150 if r < 0.12 else (200 if r < 0.4 else BASE)
        save(px, name)


def mottled(seed, dark_count, patch_count, size, name, dark=70):
    rng = random.Random(seed)
    px = new(size)
    s = size / 32
    for _ in range(patch_count):  # markings-colour patches (calico white)
        blob(px, rng.uniform(0, size), rng.uniform(0, size), rng.uniform(3, 6) * s + 1, rng.uniform(2.5, 5) * s + 1, patch=True)
    for _ in range(dark_count):  # dark patches (black on calico / tortie)
        blob(px, rng.uniform(0, size), rng.uniform(0, size), rng.uniform(2, 5) * s + 0.8, rng.uniform(1.5, 4) * s + 0.8, grey=dark)
    save(px, name)


def tuxedo():
    # Solid body (none needed); the limbs get white socks: the far end of each leg/tail.
    # Used with uv_scale (1, 1) so the sock shows once per leg.
    # Godot cylinders use only the TOP HALF of the picture for their sides (top of the leg at
    # row 0, foot at row 8); the bottom half holds the end caps (top cap left, bottom cap right).
    limbs = new(16)
    for y in range(4, 8):  # lower half of the leg
        for x in range(16):
            limbs[y][x] = [BASE, 0]
    for y in range(8, 16):  # the sole (bottom cap)
        for x in range(8, 16):
            limbs[y][x] = [BASE, 0]
    save(limbs, "cat_coat_socks.png")


def pointed():
    # Siamese "points": legs and tail are a dark shade of the fur colour.
    limbs = new(16)
    for y in range(16):
        for x in range(16):
            limbs[y][x][0] = 80
    save(limbs, "cat_coat_points.png")


if __name__ == "__main__":
    tiger()
    spotted()
    ticked()
    mottled(11, 9, 7, 32, "cat_coat_calico.png")
    mottled(12, 3, 3, 16, "cat_coat_calico_rings.png")
    mottled(21, 9, 0, 32, "cat_coat_tortie.png", dark=70)
    mottled(22, 3, 0, 16, "cat_coat_tortie_rings.png", dark=70)
    tuxedo()
    pointed()
