"""CYPURRPUNK model kit: Blockbench .bbmodel files <-> game-ready .glb files, no Blockbench needed.

Used by tools/model_mcp.py (the MCP server Claude talks to) and from the command line:

    python tools/cypurr_models.py build tools/model_specs/trash_bin.json   (spec -> .bbmodel)
    python tools/cypurr_models.py export models/blockbench/trash_bin.bbmodel (-> models/trash_bin.glb)
    python tools/cypurr_models.py inspect models/trash_bin.glb

THE THREE FILE KINDS
  * A SPEC (JSON) = a short recipe: "a 64x64 texture painted like this, an 8-sided can here, a
    tilted lid there". Claude writes these. They live in tools/model_specs/.
  * A .bbmodel = a Blockbench project (models/blockbench/). Double-click it to open it in
    Blockbench, repaint or move things, press Ctrl+S. It is the "master copy" of a model.
  * A .glb = what Godot loads (models/<name>.glb). Made from the .bbmodel by `export`, so after
    you edit a model in Blockbench, ask Claude to re-export it (or run the export line above).

UNITS: Blockbench works in "pixels"; 16 pixels = 1 metre in the game. Y is up, -Z is north.

Only needs Python + Pillow (pip install pillow). No Blockbench, no Blender.
"""
from __future__ import annotations

import base64
import io
import json
import math
import os
import random
import struct
import sys
import uuid as uuidlib

from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLOCKBENCH_DIR = os.path.join(PROJECT_ROOT, "models", "blockbench")
GLB_DIR = os.path.join(PROJECT_ROOT, "models")
PIXELS_PER_METRE = 16.0

# ROADMAP.md style rules.
TRIANGLE_LIMITS = {"prop": 150, "character": 600, "vehicle": 500, "set_piece": 500}  # set_piece = a big room centrepiece (the Mainframe)
TEXTURE_SIZES = (64, 128)


# =====================================================================================
# A tiny 3x5 pixel font for stencils on textures ("OVERCLEAN", "DEPT OF SANITATION"...)
# =====================================================================================

FONT_3X5 = {
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
    "G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"], "J": ["001", "001", "001", "101", "010"],
    "K": ["101", "101", "110", "101", "101"], "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"], "N": ["110", "101", "101", "101", "101"],
    "O": ["010", "101", "101", "101", "010"], "P": ["110", "101", "110", "100", "100"],
    "Q": ["010", "101", "101", "110", "011"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"], "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"], "3": ["110", "001", "010", "001", "110"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "110", "001", "110"],
    "6": ["011", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "110"],
    " ": ["000", "000", "000", "000", "000"], "-": ["000", "000", "111", "000", "000"],
    ".": ["000", "000", "000", "000", "010"], "%": ["101", "001", "010", "100", "101"],
    "!": ["010", "010", "010", "000", "010"], "/": ["001", "001", "010", "100", "100"], "&": ["010", "101", "010", "101", "011"],
}


def _color(value) -> tuple:
    """'#rrggbb' / '#rrggbbaa' / [r, g, b(, a)] -> (r, g, b, a) 0..255."""
    if isinstance(value, str):
        h = value.lstrip("#")
        if len(h) == 6:
            h += "ff"
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4, 6))
    v = list(value)
    if len(v) == 3:
        v.append(255)
    return tuple(int(c) for c in v)


def _shade(c: tuple, amount: float) -> tuple:
    """Lighter (amount > 0) or darker (< 0) version of a colour."""
    out = []
    for ch in c[:3]:
        out.append(int(max(0, min(255, ch + (255 - ch) * amount if amount > 0 else ch * (1 + amount)))))
    return tuple(out) + (c[3],)


# =====================================================================================
# Texture painting: a list of simple operations on a small pixel-art image
# =====================================================================================

def paint_texture(img: Image.Image, ops: list, seed: int = 1) -> Image.Image:
    """Paint operations, in order, onto img (RGBA). Every op is a dict with an "op" key:

      fill     rect [x1,y1,x2,y2] (x2/y2 exclusive), color
      noise    rect, color, amount 0..1 (share of pixels changed), spread 0..1 (how much
               lighter/darker they get) -> speckled grime / wear
      stripes  rect, colors [a, b, ...], width (px per stripe), direction "vertical"/"horizontal"
               -> corrugated metal, reflective bands
      gradient rect, top color, bottom color (alpha blended over what's there)
      spots    rect, color, count, size (radius px) -> rust / dirt blotches
      text     pos [x,y], text, color, scale (1 = 3x5 letters), spacing -> stencils
      line     from [x,y], to [x,y], color
      pixels   list of [x, y, color]
      edge     rect, color -> 1 px border (outlines panels)
      dither   rect, color, top/bottom (or density) 0..1 -> 4x4 Bayer ordered dither (PS1 fades)
      comment  note -> does nothing (labels which part of the texture is which)
    """
    rng = random.Random(seed)
    px = img.load()
    w, h = img.size

    def put(x, y, c, blend=False):
        if 0 <= x < w and 0 <= y < h:
            if blend and c[3] < 255:
                o = px[x, y]
                a = c[3] / 255.0
                c = tuple(int(o[i] * (1 - a) + c[i] * a) for i in range(3)) + (255,)
            px[x, y] = c

    def rect_of(op):
        r = op.get("rect", [0, 0, w, h])
        return max(0, r[0]), max(0, r[1]), min(w, r[2]), min(h, r[3])

    for op in ops:
        kind = op["op"]
        if kind == "comment":  # a note for humans: which part of the texture is which
            continue
        if kind == "fill":
            x1, y1, x2, y2 = rect_of(op)
            c = _color(op["color"])
            for y in range(y1, y2):
                for x in range(x1, x2):
                    put(x, y, c, blend=True)
        elif kind == "noise":
            x1, y1, x2, y2 = rect_of(op)
            base = _color(op["color"]) if "color" in op else None
            amount, spread = op.get("amount", 0.3), op.get("spread", 0.25)
            for y in range(y1, y2):
                for x in range(x1, x2):
                    if rng.random() < amount:
                        c = base if base is not None else px[x, y]
                        put(x, y, _shade(c, rng.uniform(-spread, spread)))
        elif kind == "stripes":
            x1, y1, x2, y2 = rect_of(op)
            colors = [_color(c) for c in op["colors"]]
            width = max(1, int(op.get("width", 1)))
            vertical = op.get("direction", "vertical") == "vertical"
            for y in range(y1, y2):
                for x in range(x1, x2):
                    i = ((x - x1) if vertical else (y - y1)) // width
                    put(x, y, colors[i % len(colors)], blend=True)
        elif kind == "gradient":
            x1, y1, x2, y2 = rect_of(op)
            top, bottom = _color(op["top"]), _color(op["bottom"])
            for y in range(y1, y2):
                t = (y - y1) / max(1, y2 - y1 - 1)
                c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4))
                for x in range(x1, x2):
                    put(x, y, c, blend=True)
        elif kind == "spots":
            x1, y1, x2, y2 = rect_of(op)
            c = _color(op["color"])
            size = op.get("size", 1.5)
            for _ in range(int(op.get("count", 6))):
                cx, cy = rng.uniform(x1, x2), rng.uniform(y1, y2)
                r = rng.uniform(size * 0.5, size)
                for y in range(int(cy - r) - 1, int(cy + r) + 2):
                    for x in range(int(cx - r) - 1, int(cx + r) + 2):
                        if x1 <= x < x2 and y1 <= y < y2 and (x - cx) ** 2 + (y - cy) ** 2 <= r * r * rng.uniform(0.6, 1.0):
                            put(x, y, _shade(c, rng.uniform(-0.15, 0.1)), blend=True)
        elif kind == "text":
            x0, y0 = op["pos"]
            c = _color(op["color"])
            scale = int(op.get("scale", 1))
            spacing = int(op.get("spacing", 1))
            worn = op.get("worn", 0.0)  # share of stencil pixels that have rubbed off
            cx = x0
            for ch in str(op["text"]).upper():
                glyph = FONT_3X5.get(ch, FONT_3X5[" "])
                for gy, row in enumerate(glyph):
                    for gx, bit in enumerate(row):
                        if bit == "1":
                            for sy in range(scale):
                                for sx in range(scale):
                                    if rng.random() >= worn:
                                        put(cx + gx * scale + sx, y0 + gy * scale + sy, c, blend=True)
                cx += (3 + spacing) * scale
        elif kind == "line":
            (ax, ay), (bx, by) = op["from"], op["to"]
            c = _color(op["color"])
            steps = int(max(abs(bx - ax), abs(by - ay))) + 1
            for i in range(steps):
                t = i / max(1, steps - 1)
                put(round(ax + (bx - ax) * t), round(ay + (by - ay) * t), c, blend=True)
        elif kind == "pixels":
            for x, y, c in op["list"]:
                put(int(x), int(y), _color(c), blend=True)
        elif kind == "dither":
            # PS1-style ordered dithering: "color" is laid over the rect in a 4x4 Bayer pattern.
            # "top" / "bottom" = how much of the rect it covers (0..1) at its top and bottom rows,
            # so 0 -> 1 is a dithered fade (grime creeping up a wall, a glow fading out).
            x1, y1, x2, y2 = rect_of(op)
            c = _color(op["color"])
            top = op.get("top", op.get("density", 0.5))
            bottom = op.get("bottom", top)
            bayer = (0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5)
            for y in range(y1, y2):
                t = (y - y1) / max(1, y2 - y1 - 1)
                density = top + (bottom - top) * t
                for x in range(x1, x2):
                    if (bayer[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0 < density:
                        put(x, y, c, blend=True)
        elif kind == "edge":
            x1, y1, x2, y2 = rect_of(op)
            c = _color(op["color"])
            for x in range(x1, x2):
                put(x, y1, c, True)
                put(x, y2 - 1, c, True)
            for y in range(y1, y2):
                put(x1, y, c, True)
                put(x2 - 1, y, c, True)
        else:
            raise ValueError("unknown paint op '%s'" % kind)
    return img


def image_to_data_uri(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def data_uri_to_image(uri: str) -> Image.Image:
    data = base64.b64decode(uri.split(",", 1)[1])
    return Image.open(io.BytesIO(data)).convert("RGBA")


# =====================================================================================
# Building .bbmodel files from a spec
# =====================================================================================

def _uuid() -> str:
    return str(uuidlib.uuid4())


def _new_project(name: str, tex_size: int) -> dict:
    return {
        "meta": {"format_version": "4.10", "model_format": "free", "box_uv": False},
        "name": name,
        "model_identifier": "",
        "visible_box": [1, 1, 0],
        "variable_placeholders": "",
        "variable_placeholder_buttons": [],
        "timeline_setups": [],
        "unhandled_root_fields": {},
        "resolution": {"width": tex_size, "height": tex_size},
        "elements": [],
        "outliner": [],
        "textures": [],
    }


def _texture_entry(name: str, img: Image.Image) -> dict:
    return {
        "path": "", "name": name + ".png", "folder": "", "namespace": "", "id": "0",
        "width": img.width, "height": img.height, "uv_width": img.width, "uv_height": img.height,
        "particle": False, "use_as_default": False, "layers_enabled": False, "sync_to_project": "",
        "render_mode": "default", "render_sides": "auto", "frame_time": 1, "frame_order_type": "loop",
        "frame_order": "", "frame_interpolate": False, "visible": True, "internal": True, "saved": False,
        "uuid": _uuid(), "relative_path": "", "source": image_to_data_uri(img),
    }


FACE_NAMES = ("north", "south", "east", "west", "up", "down")


def _cube_element(spec: dict) -> dict:
    """A box. spec: name, from [x,y,z], to [x,y,z], optional origin/rotation, and UVs:
    "faces": {"north": [x1,y1,x2,y2], ...} for each face, or the shortcuts "all": rect,
    "sides": rect (north/south/east/west), "top": rect, "bottom": rect. A face left out has no
    texture (it isn't drawn)."""
    faces = {}
    for f in FACE_NAMES:
        rect = None
        if "faces" in spec and f in spec["faces"]:
            rect = spec["faces"][f]
        elif f in ("north", "south", "east", "west") and "sides" in spec:
            rect = spec["sides"]
        elif f == "up" and "top" in spec:
            rect = spec["top"]
        elif f == "down" and "bottom" in spec:
            rect = spec["bottom"]
        elif "all" in spec:
            rect = spec["all"]
        faces[f] = {"uv": list(rect) if rect else [0, 0, 0, 0], "texture": 0 if rect else None}
    frm, to = spec["from"], spec["to"]
    origin = spec.get("origin", [(frm[i] + to[i]) / 2 for i in range(3)])
    el = {
        "name": spec.get("name", "cube"), "box_uv": False, "rescale": False, "locked": False,
        "render_order": "default", "allow_mirror_modeling": True,
        "from": list(frm), "to": list(to), "autouv": 0, "color": spec.get("color", 0),
        "origin": list(origin), "faces": faces, "type": "cube", "uuid": _uuid(),
    }
    if spec.get("rotation"):
        el["rotation"] = list(spec["rotation"])
    if spec.get("inflate"):
        el["inflate"] = spec["inflate"]
    return el


def _prism_element(spec: dict) -> dict:
    """An n-sided can / cone / pillar (a Blockbench MESH). spec:
      name, sides (e.g. 8), center [x,y,z] = middle of the BOTTOM, height,
      radius (or radius_bottom + radius_top; 0 top = pointy), twist (degrees to turn it),
      optional origin/rotation (pivot + tilt, e.g. a crooked lid),
      side_uv rect (wrapped all the way round: each side gets an equal slice),
      top_uv / bottom_uv rects (a cap is left off when its uv is missing)."""
    n = int(spec.get("sides", 8))
    cx, cy, cz = spec["center"]
    hgt = spec["height"]
    rb = spec.get("radius_bottom", spec.get("radius", 4))
    rt = spec.get("radius_top", spec.get("radius", 4))
    twist = math.radians(spec.get("twist", 180.0 / n))
    origin = spec.get("origin", [cx, cy, cz])
    verts, faces = {}, {}

    def key(i):
        return "v%d" % i

    angle = lambda i: twist + i * 2 * math.pi / n
    for i in range(n):  # bottom ring 0..n-1, top ring n..2n-1 (relative to origin)
        a = angle(i)
        verts[key(i)] = [cx + rb * math.cos(a) - origin[0], cy - origin[1], cz + rb * math.sin(a) - origin[2]]
        verts[key(n + i)] = [cx + rt * math.cos(a) - origin[0], cy + hgt - origin[1], cz + rt * math.sin(a) - origin[2]]

    if "side_uv" in spec:
        x1, y1, x2, y2 = spec["side_uv"]
        slice_w = (x2 - x1) / n
        for i in range(n):
            j = (i + 1) % n
            # Seen from outside, a LARGER angle is to the LEFT. Slices are handed out so text
            # painted across the strip reads left-to-right as you walk round the can.
            s = n - 1 - i
            u_left, u_right = x1 + s * slice_w, x1 + (s + 1) * slice_w
            tl, tr, br, bl = key(n + j), key(n + i), key(i), key(j)
            faces["side%d" % i] = {
                "uv": {tl: [u_left, y1], tr: [u_right, y1], br: [u_right, y2], bl: [u_left, y2]},
                "vertices": [tl, bl, br, tr], "texture": 0,
            }
    for cap, ring, up in (("top", n, True), ("bottom", 0, False)):
        rect = spec.get(cap + "_uv")
        if not rect or (cap == "top" and rt <= 0) or (cap == "bottom" and rb <= 0):
            continue
        x1, y1, x2, y2 = rect
        mx, my, hw, hh = (x1 + x2) / 2, (y1 + y2) / 2, (x2 - x1) / 2, (y2 - y1) / 2
        uv = {}
        for i in range(n):
            a = angle(i)
            # Seen from above, -Z is the top of the picture (Blockbench's "up" face).
            # From below the picture is mirrored front-to-back (Blockbench's "down" face).
            uv[key(ring + i)] = [mx + math.cos(a) * hw, my + (math.sin(a) if up else -math.sin(a)) * hh]
        for t in range(1, n - 1):  # fan of triangles (Blockbench meshes take 3- or 4-sided faces)
            tri = [key(ring), key(ring + t), key(ring + t + 1)]
            if up:
                tri = [tri[0], tri[2], tri[1]]  # anticlockwise seen from above = faces up
            faces["%s%d" % (cap, t)] = {"uv": {k: uv[k] for k in tri}, "vertices": tri, "texture": 0}
    el = {
        "name": spec.get("name", "prism"), "color": spec.get("color", 0), "origin": list(origin),
        "rotation": list(spec.get("rotation", [0, 0, 0])), "export": True, "visibility": True,
        "locked": False, "render_order": "default", "allow_mirror_modeling": True,
        "vertices": verts, "faces": faces, "type": "mesh", "uuid": _uuid(),
    }
    return el


def _poly_element(spec: dict) -> dict:
    """A free-form shape (a Blockbench MESH) from named corner points: wedges, slopes, fins.
    spec:
      name, vertices {"nl": [x,y,z], ...}  (pixels, like everything else),
      faces [{"v": ["nl", "nr", "wr", "wl"], "uv": [x1,y1,x2,y2]}, ...]  (3 or 4 corners each),
                    or {"v": [...], "uvs": [[u,v], ...]} = the exact texture point of each corner,
      uv            default rect for faces that don't give their own,
      outward_from  [x,y,z]: faces are turned to point AWAY from this point. Leave it out and the
                    middle of the shape is used, which is right for any closed, bulging shape
                    (a wedge, a pyramid). Give it for a single flat piece (which way is "out"?).
      origin / rotation like the other shapes.
    You don't have to care about corner order: each face is turned to face outward by itself.
    The texture is laid flat onto each face from the side it faces most (like a projector):
    side faces show the rect with up = up, top faces with north (-Z) at the top of the rect."""
    raw = {k: [float(c) for c in v] for k, v in spec["vertices"].items()}
    origin = spec.get("origin", [0, 0, 0])
    if "outward_from" in spec:
        middle = spec["outward_from"]
    else:
        middle = [sum(v[i] for v in raw.values()) / len(raw) for i in range(3)]
    default_uv = spec.get("uv", [0, 0, 16, 16])
    faces = {}
    for index, fspec in enumerate(spec["faces"]):
        keys = list(fspec["v"])
        pts = [raw[k] for k in keys]
        # Newell's method: the face's normal for this corner order (anticlockwise = outward).
        n = [0.0, 0.0, 0.0]
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            n[0] += (a[1] - b[1]) * (a[2] + b[2])
            n[1] += (a[2] - b[2]) * (a[0] + b[0])
            n[2] += (a[0] - b[0]) * (a[1] + b[1])
        centre = [sum(p[i] for p in pts) / len(pts) for i in range(3)]
        # "uvs" = the exact texture point [u, v] of each corner, in the same order as "v" (used by
        # tools/make_weapon_specs.py to wrap stripes and labels round a barrel). Without it the
        # rect is projected onto the face (below).
        corner_uvs = [list(p) for p in fspec["uvs"]] if "uvs" in fspec else None
        if sum(n[i] * (centre[i] - middle[i]) for i in range(3)) < 0:
            keys.reverse()
            n = [-c for c in n]
            if corner_uvs:
                corner_uvs.reverse()
        if corner_uvs:
            faces["f%d" % index] = {"uv": dict(zip(keys, corner_uvs)), "vertices": keys, "texture": 0}
            continue
        # Lay the rect onto the face from the axis it faces most.
        axis = max(range(3), key=lambda i: abs(n[i]))
        def project(p):
            x, y, z = p
            if axis == 0:   # east / west side: front of the car (-Z) on the left seen from the west
                return (z if n[0] < 0 else -z, -y)
            if axis == 2:   # north / south
                return (-x if n[2] < 0 else x, -y)
            return (x, z if n[1] > 0 else -z)  # top (north at the top) / bottom
        flat = [project(raw[k]) for k in keys]
        umin, umax = min(f[0] for f in flat), max(f[0] for f in flat)
        vmin, vmax = min(f[1] for f in flat), max(f[1] for f in flat)
        x1, y1, x2, y2 = fspec.get("uv", default_uv)
        uv = {}
        for k, (u, v) in zip(keys, flat):
            tu = (u - umin) / (umax - umin) if umax > umin else 0.0
            tv = (v - vmin) / (vmax - vmin) if vmax > vmin else 0.0
            uv[k] = [x1 + (x2 - x1) * tu, y1 + (y2 - y1) * tv]
        faces["f%d" % index] = {"uv": uv, "vertices": keys, "texture": 0}
    return {
        "name": spec.get("name", "poly"), "color": spec.get("color", 0), "origin": list(origin),
        "rotation": list(spec.get("rotation", [0, 0, 0])), "export": True, "visibility": True,
        "locked": False, "render_order": "default", "allow_mirror_modeling": True,
        "vertices": {k: [v[i] - origin[i] for i in range(3)] for k, v in raw.items()},
        "faces": faces, "type": "mesh", "uuid": _uuid(),
    }


def _locator_element(spec: dict) -> dict:
    """An invisible marker (e.g. where a hat goes). spec: name, position [x,y,z]."""
    return {
        "name": spec["name"], "position": list(spec.get("position", [0, 0, 0])),
        "rotation": list(spec.get("rotation", [0, 0, 0])), "ignore_inherited_scale": False,
        "visibility": True, "locked": False, "type": "locator", "uuid": _uuid(),
    }


ELEMENT_BUILDERS = {"cube": _cube_element, "prism": _prism_element, "poly": _poly_element, "locator": _locator_element}


def _new_group(spec: dict) -> dict:
    return {
        "name": spec["name"], "origin": list(spec.get("origin", [0, 0, 0])),
        "rotation": list(spec.get("rotation", [0, 0, 0])), "color": 0, "uuid": _uuid(),
        "export": True, "mirror_uv": False, "isOpen": True, "locked": False, "visibility": True,
        "autouv": 0, "children": [],
    }


def _walk_groups(nodes, fn, parent=None):
    for node in nodes:
        if isinstance(node, dict):
            fn(node, parent)
            _walk_groups(node.get("children", []), fn, node)


def _find_group(project: dict, name: str):
    found = []
    _walk_groups(project["outliner"], lambda g, p: found.append(g) if g.get("name") == name else None)
    return found[0] if found else None


def _remove_from_outliner(nodes: list, uid: str) -> None:
    for node in list(nodes):
        if node == uid:
            nodes.remove(node)
        elif isinstance(node, dict):
            _remove_from_outliner(node.get("children", []), uid)


def build_bbmodel(spec: dict, out_path: str | None = None, replace: bool = True) -> str:
    """Create (replace=True) or edit (replace=False: merge into the existing file) a .bbmodel.

    spec keys (all optional when editing):
      name            model name; the file is models/blockbench/<name>.bbmodel
      texture_size    64 or 128 (square)
      texture_png     path to a PNG to use as the texture (instead of / under "paint")
      background      colour the new texture starts as
      paint           list of paint ops (see paint_texture), painted on top
      seed            random seed for noise/spots (same seed = same pixels)
      groups          [{name, origin, rotation, parent}]  (bones; parent = another group's name)
      elements        [{type: cube|prism|locator, group, ...}]  (same name = replaced when editing)
      remove          [element or group names] (editing)
    Returns the path written."""
    name = spec.get("name") or os.path.splitext(os.path.basename(out_path or "model"))[0]
    out_path = out_path or os.path.join(BLOCKBENCH_DIR, name + ".bbmodel")
    if not replace and os.path.exists(out_path):
        with open(out_path, "r", encoding="utf-8") as f:
            project = json.load(f)
        _upgrade_v5(project)
    else:
        project = _new_project(name, int(spec.get("texture_size", 64)))

    # --- Texture ---
    size = int(spec.get("texture_size", project["resolution"]["width"]))
    if "texture_png" in spec:
        img = Image.open(spec["texture_png"]).convert("RGBA")
    elif project["textures"] and not spec.get("new_texture"):
        img = data_uri_to_image(project["textures"][0]["source"])
    else:
        img = Image.new("RGBA", (size, size), _color(spec.get("background", "#808080")))
    if "paint" in spec:
        paint_texture(img, spec["paint"], spec.get("seed", 1))
    if project["textures"]:
        project["textures"][0]["source"] = image_to_data_uri(img)
        project["textures"][0].update({"width": img.width, "height": img.height, "uv_width": img.width, "uv_height": img.height})
    else:
        project["textures"].append(_texture_entry(name, img))
    project["resolution"] = {"width": img.width, "height": img.height}

    # --- Removals ---
    for gone in spec.get("remove", []):
        for el in [e for e in project["elements"] if e.get("name") == gone]:
            project["elements"].remove(el)
            _remove_from_outliner(project["outliner"], el["uuid"])
        group = _find_group(project, gone)
        if group:
            def drop(nodes):
                for node in list(nodes):
                    if isinstance(node, dict):
                        if node is group:
                            nodes.remove(node)
                        else:
                            drop(node.get("children", []))
            drop(project["outliner"])

    # --- Groups (bones) ---
    for gspec in spec.get("groups", []):
        group = _find_group(project, gspec["name"])
        if group is None:
            group = _new_group(gspec)
            parent = _find_group(project, gspec["parent"]) if gspec.get("parent") else None
            (parent["children"] if parent else project["outliner"]).append(group)
        else:
            group["origin"] = list(gspec.get("origin", group["origin"]))
            group["rotation"] = list(gspec.get("rotation", group.get("rotation", [0, 0, 0])))

    # --- Elements ---
    for espec in spec.get("elements", []):
        kind = espec.get("type", "cube")
        el = ELEMENT_BUILDERS[kind](espec)
        for old in [e for e in project["elements"] if e.get("name") == el["name"]]:
            project["elements"].remove(old)
            _remove_from_outliner(project["outliner"], old["uuid"])
        project["elements"].append(el)
        group = _find_group(project, espec["group"]) if espec.get("group") else None
        if espec.get("group") and group is None:
            group = _new_group({"name": espec["group"]})
            project["outliner"].append(group)
        (group["children"] if group else project["outliner"]).append(el["uuid"])

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(project, f, indent="\t")
    return out_path


def _upgrade_v5(project: dict) -> None:
    """Blockbench 5 saves groups in a separate "groups" list; fold them back into the outliner
    tree (the older layout every Blockbench version still opens)."""
    groups = {g["uuid"]: g for g in project.get("groups", [])}
    if not groups:
        return

    def expand(nodes):
        out = []
        for node in nodes:
            if isinstance(node, dict):
                g = dict(groups.get(node.get("uuid"), {}))
                g.update({k: v for k, v in node.items() if k != "children"})
                g["children"] = expand(node.get("children", []))
                out.append(g)
            else:
                out.append(node)
        return out

    project["outliner"] = expand(project["outliner"])
    project.pop("groups", None)
    project["meta"]["format_version"] = "4.10"


# =====================================================================================
# .bbmodel -> triangles
# =====================================================================================

def _euler_matrix(deg) -> list:
    """Blockbench rotation [x, y, z] in degrees (applied Z, then Y, then X... Blockbench's 'ZYX'
    order means the matrix is Rz * Ry * Rx)."""
    rx, ry, rz = (math.radians(v) for v in deg)
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    rxm = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    rym = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rzm = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return _mat_mul(rzm, _mat_mul(rym, rxm))


def _mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def _apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def _rotate_about(points, origin, rotation):
    if not rotation or not any(rotation):
        return points
    m = _euler_matrix(rotation)
    return [[a + o for a, o in zip(_apply(m, [p[i] - origin[i] for i in range(3)]), origin)] for p in points]


def _cube_faces(el: dict):
    """-> list of (texture_index, [(pos, uv) x3]) triangles in Blockbench pixels."""
    inflate = el.get("inflate", 0)
    (x0, y0, z0), (x1, y1, z1) = el["from"], el["to"]
    x0, y0, z0 = x0 - inflate, y0 - inflate, z0 - inflate
    x1, y1, z1 = x1 + inflate, y1 + inflate, z1 + inflate
    # Corners of each face as seen from OUTSIDE: top-left, top-right, bottom-right, bottom-left.
    corners = {
        "north": [(x1, y1, z0), (x0, y1, z0), (x0, y0, z0), (x1, y0, z0)],
        "south": [(x0, y1, z1), (x1, y1, z1), (x1, y0, z1), (x0, y0, z1)],
        "east": [(x1, y1, z1), (x1, y1, z0), (x1, y0, z0), (x1, y0, z1)],
        "west": [(x0, y1, z0), (x0, y1, z1), (x0, y0, z1), (x0, y0, z0)],
        "up": [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
        "down": [(x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0)],
    }
    origin = el.get("origin", [0, 0, 0])
    rotation = el.get("rotation", [0, 0, 0])
    tris = []
    for fname, face in el.get("faces", {}).items():
        if face.get("texture") is None or fname not in corners:
            continue
        u1, v1, u2, v2 = face["uv"]
        uvs = [(u1, v1), (u2, v1), (u2, v2), (u1, v2)]
        turns = int(face.get("rotation", 0)) // 90 % 4  # the face's texture turned in 90° steps
        uvs = uvs[-turns:] + uvs[:-turns] if turns else uvs
        pts = _rotate_about([list(p) for p in corners[fname]], origin, rotation)
        tl, tr, br, bl = zip(pts, uvs)
        tex = face["texture"]
        tris.append((tex, [tl, bl, br]))
        tris.append((tex, [tl, br, tr]))
    return tris


def _mesh_faces(el: dict):
    origin = el.get("origin", [0, 0, 0])
    rotation = el.get("rotation", [0, 0, 0])
    verts = el["vertices"]
    world = {}
    for k, v in verts.items():
        world[k] = _rotate_about([[v[0] + origin[0], v[1] + origin[1], v[2] + origin[2]]], origin, rotation)[0]
    tris = []
    for face in el.get("faces", {}).values():
        if face.get("texture") is None:
            continue
        keys = face["vertices"]
        uv = face.get("uv", {})
        pts = [(world[k], uv.get(k, [0, 0])) for k in keys]
        if len(pts) == 3:
            tris.append((face["texture"], pts))
        elif len(pts) == 4:
            tris.append((face["texture"], [pts[0], pts[1], pts[2]]))
            tris.append((face["texture"], [pts[0], pts[2], pts[3]]))
    return tris


def _textures_of(project: dict, bbmodel_path: str) -> list:
    images = []
    for t in project.get("textures", []):
        if t.get("source", "").startswith("data:"):
            images.append(data_uri_to_image(t["source"]))
        else:
            path = t.get("path") or os.path.join(os.path.dirname(bbmodel_path), t.get("relative_path", ""))
            images.append(Image.open(path).convert("RGBA"))
    return images


def _tree(project: dict) -> list:
    """The outliner as nested {group, children: [...], elements: [...]} with element dicts."""
    _upgrade_v5(project)
    by_uuid = {e["uuid"]: e for e in project["elements"]}

    def walk(nodes):
        out_groups, out_elements = [], []
        for node in nodes:
            if isinstance(node, dict):
                if node.get("export", True) is False:
                    continue
                kids, els = walk(node.get("children", []))
                out_groups.append({"group": node, "children": kids, "elements": els})
            elif node in by_uuid:
                out_elements.append(by_uuid[node])
        return out_groups, out_elements

    groups, loose = walk(project["outliner"])
    listed = set()

    def mark(g):
        for e in g["elements"]:
            listed.add(e["uuid"])
        for c in g["children"]:
            mark(c)
    for g in groups:
        mark(g)
    loose += [e for e in project["elements"] if e["uuid"] not in listed and e not in loose]
    return groups, loose


# =====================================================================================
# .glb writing
# =====================================================================================

def _normal(a, b, c):
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    n = [uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx]
    length = math.sqrt(sum(x * x for x in n)) or 1.0
    return [x / length for x in n]


def _quat_from_euler(deg):
    m = _euler_matrix(deg)
    tr = m[0][0] + m[1][1] + m[2][2]
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        return [(m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s, 0.25 * s]
    if m[0][0] > m[1][1] and m[0][0] > m[2][2]:
        s = math.sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2
        return [0.25 * s, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s, (m[2][1] - m[1][2]) / s]
    if m[1][1] > m[2][2]:
        s = math.sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2
        return [(m[0][1] + m[1][0]) / s, 0.25 * s, (m[1][2] + m[2][1]) / s, (m[0][2] - m[2][0]) / s]
    s = math.sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2
    return [(m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, 0.25 * s, (m[1][0] - m[0][1]) / s]


class _GlbWriter:
    def __init__(self):
        self.bin = bytearray()
        self.gltf = {"asset": {"version": "2.0", "generator": "CYPURRPUNK cypurr_models.py"},
                     "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [],
                     "accessors": [], "bufferViews": [], "buffers": [], "materials": [],
                     "textures": [], "images": [], "samplers": []}

    def _view(self, data: bytes, target=None) -> int:
        while len(self.bin) % 4:
            self.bin.append(0)
        view = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        if target:
            view["target"] = target
        self.bin += data
        self.gltf["bufferViews"].append(view)
        return len(self.gltf["bufferViews"]) - 1

    def accessor(self, values: list, kind: str, ctype: int, target=None) -> int:
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[kind]
        fmt = {5126: "f", 5123: "H", 5125: "I"}[ctype]
        flat = [x for v in values for x in (v if width > 1 else [v])]
        view = self._view(struct.pack("<%d%s" % (len(flat), fmt), *flat), target)
        acc = {"bufferView": view, "componentType": ctype, "count": len(values), "type": kind}
        if kind == "VEC3":
            acc["min"] = [min(v[i] for v in values) for i in range(3)]
            acc["max"] = [max(v[i] for v in values) for i in range(3)]
        self.gltf["accessors"].append(acc)
        return len(self.gltf["accessors"]) - 1

    def material(self, name: str, img: Image.Image) -> int:
        buf = io.BytesIO()
        img.save(buf, "PNG")
        view = self._view(buf.getvalue())
        self.gltf["images"].append({"bufferView": view, "mimeType": "image/png", "name": name})
        if not self.gltf["samplers"]:
            # NEAREST everywhere: crisp pixels, no blur (PS1 look).
            self.gltf["samplers"].append({"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071})
        self.gltf["textures"].append({"sampler": 0, "source": len(self.gltf["images"]) - 1})
        mat = {"name": name, "pbrMetallicRoughness": {
            "baseColorTexture": {"index": len(self.gltf["textures"]) - 1},
            "metallicFactor": 0.0, "roughnessFactor": 1.0}}
        if img.getchannel("A").getextrema()[0] < 255:
            mat["alphaMode"] = "MASK"
        self.gltf["materials"].append(mat)
        return len(self.gltf["materials"]) - 1

    def mesh(self, name: str, tris: list, offset, tex_sizes, materials) -> int | None:
        """tris = [(texture_index, [(pos_px, uv_px) x3])]; offset = the group's pivot (px)."""
        by_tex = {}
        for tex, pts in tris:
            by_tex.setdefault(tex, []).append(pts)
        prims = []
        for tex, faces in sorted(by_tex.items(), key=lambda kv: str(kv[0])):
            if not isinstance(tex, int) or tex >= len(materials):
                tex = 0
            tw, th = tex_sizes[tex]
            pos, nor, uvs = [], [], []
            for pts in faces:
                p = [[(pt[0][i] - offset[i]) / PIXELS_PER_METRE for i in range(3)] for pt in pts]
                n = _normal(*p)
                if not any(n):
                    continue
                for (xyz, uv), pp in zip(pts, p):
                    pos.append(pp)
                    nor.append(n)
                    uvs.append([uv[0] / tw, uv[1] / th])
            if not pos:
                continue
            idx = list(range(len(pos)))
            prims.append({"attributes": {
                "POSITION": self.accessor(pos, "VEC3", 5126, 34962),
                "NORMAL": self.accessor(nor, "VEC3", 5126, 34962),
                "TEXCOORD_0": self.accessor(uvs, "VEC2", 5126, 34962)},
                "indices": self.accessor(idx, "SCALAR", 5123 if len(idx) < 65536 else 5125, 34963),
                "material": materials[tex]})
        if not prims:
            return None
        self.gltf["meshes"].append({"name": name, "primitives": prims})
        return len(self.gltf["meshes"]) - 1

    def node(self, data: dict) -> int:
        self.gltf["nodes"].append(data)
        return len(self.gltf["nodes"]) - 1

    def save(self, path: str) -> None:
        while len(self.bin) % 4:
            self.bin.append(0)
        self.gltf["buffers"] = [{"byteLength": len(self.bin)}]
        for key in ("textures", "images", "samplers", "materials"):
            if not self.gltf[key]:
                del self.gltf[key]
        js = json.dumps(self.gltf, separators=(",", ":")).encode("utf-8")
        while len(js) % 4:
            js += b" "
        out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(self.bin))
        out += struct.pack("<II", len(js), 0x4E4F534A) + js
        out += struct.pack("<II", len(self.bin), 0x004E4942) + bytes(self.bin)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(out)


def export_glb(bbmodel_path: str, glb_path: str | None = None) -> str:
    """Turn a .bbmodel into models/<name>.glb. Every Blockbench GROUP becomes a node with that
    name (its cubes/meshes merged into its mesh, pivoting at the group's origin); every LOCATOR
    becomes an empty node with its name (attachment points: hats, shades...). One material per
    texture, with NEAREST filtering. Cube face UV rotation and inflate are honoured."""
    with open(bbmodel_path, "r", encoding="utf-8") as f:
        project = json.load(f)
    name = os.path.splitext(os.path.basename(bbmodel_path))[0]
    glb_path = glb_path or os.path.join(GLB_DIR, name + ".glb")
    images = _textures_of(project, bbmodel_path)
    if not images:
        images = [Image.new("RGBA", (16, 16), (200, 200, 200, 255))]
    tex_sizes = []
    for t, img in zip(project.get("textures", []) or [{}], images):
        tex_sizes.append((t.get("uv_width", img.width), t.get("uv_height", img.height)))
    groups, loose = _tree(project)
    w = _GlbWriter()
    materials = [w.material(os.path.splitext(project["textures"][i]["name"])[0] if project.get("textures") else name, img)
                 for i, img in enumerate(images)]

    def element_tris(elements):
        tris = []
        for el in elements:
            if el.get("export", True) is False:
                continue
            kind = el.get("type", "cube")
            if kind == "cube":
                tris += _cube_faces(el)
            elif kind == "mesh":
                tris += _mesh_faces(el)
        return tris

    def locator_nodes(elements, offset):
        nodes = []
        for el in elements:
            if el.get("type") in ("locator", "null_object"):
                p = el.get("position", [0, 0, 0])
                nodes.append(w.node({"name": el["name"], "translation": [(p[i] - offset[i]) / PIXELS_PER_METRE for i in range(3)]}))
        return nodes

    def build(g, parent_origin):
        grp = g["group"]
        origin = grp.get("origin", [0, 0, 0])
        node = {"name": grp["name"], "translation": [(origin[i] - parent_origin[i]) / PIXELS_PER_METRE for i in range(3)]}
        rot = grp.get("rotation", [0, 0, 0])
        if any(rot):
            node["rotation"] = _quat_from_euler(rot)
        mesh = w.mesh(grp["name"], element_tris(g["elements"]), origin, tex_sizes, materials)
        if mesh is not None:
            node["mesh"] = mesh
        kids = [build(c, origin) for c in g["children"]] + locator_nodes(g["elements"], origin)
        if kids:
            node["children"] = kids
        return w.node(node)

    roots = [build(g, [0, 0, 0]) for g in groups]
    loose_mesh = w.mesh(name, element_tris(loose), [0, 0, 0], tex_sizes, materials)
    if loose_mesh is not None:
        roots.append(w.node({"name": "Ungrouped", "mesh": loose_mesh}))
    roots += locator_nodes(loose, [0, 0, 0])
    w.gltf["scenes"][0]["nodes"] = roots
    w.save(glb_path)
    _write_import_settings(glb_path)
    return glb_path


# Godot import settings for a new model: keep the texture INSIDE the model, uncompressed (exact
# pixels, no extra PNG files next to it), and no level-of-detail copies (pointless at <150
# triangles). Godot fills in everything else on the next import. An existing .import file
# (maybe changed by hand in Godot's Import tab) is left alone.
GODOT_IMPORT_TEMPLATE = """[remap]

importer="scene"
type="PackedScene"

[params]

meshes/generate_lods=false
gltf/embedded_image_handling=3
"""


def _write_import_settings(glb_path: str) -> None:
    path = glb_path + ".import"
    if not os.path.exists(path):
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(GODOT_IMPORT_TEMPLATE)


# =====================================================================================
# Inspecting (style rules from ROADMAP.md)
# =====================================================================================

def _read_glb(path: str) -> tuple:
    with open(path, "rb") as f:
        data = f.read()
    magic, _, _ = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError("not a .glb file")
    js_len, _ = struct.unpack_from("<II", data, 12)
    gltf = json.loads(data[20:20 + js_len])
    bin_start = 20 + js_len + 8
    return gltf, data[bin_start:]


def inspect_model(path: str, kind: str = "prop") -> dict:
    """Triangles, texture sizes and the group/bone tree of a .bbmodel or .glb, checked against
    ROADMAP.md: props < 150 triangles, characters < 600, textures 64x64 or 128x128."""
    report = {"file": os.path.relpath(path, PROJECT_ROOT), "kind": kind, "problems": []}
    if path.endswith(".bbmodel"):
        with open(path, "r", encoding="utf-8") as f:
            project = json.load(f)
        tris = 0
        for el in project["elements"]:
            if el.get("type", "cube") == "cube":
                tris += len(_cube_faces(el))
            elif el.get("type") == "mesh":
                tris += len(_mesh_faces(el))
        textures = [(t.get("width"), t.get("height"), t.get("name")) for t in project.get("textures", [])]
        groups, loose = _tree(project)

        def describe(g, depth=0):
            lines = ["  " * depth + g["group"]["name"] + "  (%d parts)" % sum(1 for e in g["elements"] if e.get("type", "cube") != "locator")]
            lines += ["  " * (depth + 1) + "@" + e["name"] + " (marker)" for e in g["elements"] if e.get("type") == "locator"]
            for c in g["children"]:
                lines += describe(c, depth + 1)
            return lines
        tree = []
        for g in groups:
            tree += describe(g)
        if loose:
            tree.append("(not in a group: %s)" % ", ".join(e["name"] for e in loose))
    else:
        gltf, binary = _read_glb(path)
        tris = 0
        for mesh in gltf.get("meshes", []):
            for prim in mesh["primitives"]:
                acc = gltf["accessors"][prim["indices"]] if "indices" in prim else gltf["accessors"][prim["attributes"]["POSITION"]]
                tris += acc["count"] // 3
        textures = []
        for img in gltf.get("images", []):
            view = gltf["bufferViews"][img["bufferView"]]
            im = Image.open(io.BytesIO(binary[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]))
            textures.append((im.width, im.height, img.get("name", "")))
        nodes = gltf.get("nodes", [])

        def describe(i, depth=0):
            n = nodes[i]
            label = n.get("name", "node%d" % i) + ("" if "mesh" in n else "  (marker)")
            lines = ["  " * depth + label]
            for c in n.get("children", []):
                lines += describe(c, depth + 1)
            return lines
        tree = []
        for root in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
            tree += describe(root)
    limit = TRIANGLE_LIMITS.get(kind, 150)
    report["triangles"] = tris
    report["triangle_limit"] = limit
    if tris >= limit:
        report["problems"].append("%d triangles: a %s must stay under %d" % (tris, kind, limit))
    report["textures"] = ["%dx%d %s" % t for t in textures]
    for wdt, hgt, tname in textures:
        if (wdt, hgt) not in [(s, s) for s in TEXTURE_SIZES]:
            report["problems"].append("texture %s is %dx%d: use 64x64 (or 128x128 for characters)" % (tname, wdt, hgt))
    report["tree"] = tree
    report["ok"] = not report["problems"]
    return report


def format_report(r: dict) -> str:
    lines = ["%s  [%s]" % (r["file"], "OK" if r["ok"] else "NEEDS WORK"),
             "  triangles: %d (limit for a %s: under %d)" % (r["triangles"], r["kind"], r["triangle_limit"]),
             "  textures:  " + (", ".join(r["textures"]) or "none")]
    lines.append("  groups / bones:")
    lines += ["    " + t for t in r["tree"]]
    lines += ["  PROBLEM: " + p for p in r["problems"]]
    return "\n".join(lines)


# =====================================================================================
# Command line
# =====================================================================================

def main(argv: list) -> int:
    if len(argv) < 2 or argv[0] not in ("build", "export", "inspect", "all"):
        print(__doc__)
        return 1
    cmd, path = argv[0], argv[1]
    kind = argv[2] if len(argv) > 2 else "prop"
    if cmd in ("build", "all"):
        with open(path, "r", encoding="utf-8") as f:
            spec = json.load(f)
        kind = spec.get("kind", kind)
        bb = build_bbmodel(spec)
        print("wrote", os.path.relpath(bb, PROJECT_ROOT))
        if cmd == "all":
            glb = export_glb(bb)
            print("wrote", os.path.relpath(glb, PROJECT_ROOT))
            print(format_report(inspect_model(glb, kind)))
    elif cmd == "export":
        glb = export_glb(path)
        print("wrote", os.path.relpath(glb, PROJECT_ROOT))
        print(format_report(inspect_model(glb, kind)))
    else:
        print(format_report(inspect_model(path, kind)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
