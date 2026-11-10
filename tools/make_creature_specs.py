"""CYPURRPUNK: writes the model RECIPES (spec JSON) for the cat and the three enemy bots.

These four models are made of rounded, faceted shapes (heads, eyes, octagonal shells) that are
tedious to type corner by corner, so this little script works the corners out with a bit of
maths and writes ordinary spec files into tools/model_specs/. Then the normal model kit builds
them:

    python tools/make_creature_specs.py              (writes cat / roomba / lint_trapper /
                                                      squirt_drone .json in tools/model_specs/)
    python tools/cypurr_models.py all tools/model_specs/cat.json      (-> .bbmodel + .glb)

After that the .bbmodel files in models/blockbench/ are the master copies: open one in
Blockbench, move or repaint things, press Ctrl+S, and ask Claude to re-export it. (Running this
script again would overwrite those hand edits with the recipe, so only do that on purpose.)

UNITS: 16 px = 1 m (Blockbench pixels). Y up, the front of every model is -Z (north).
"""
from __future__ import annotations

import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC_DIR = os.path.join(HERE, "model_specs")


# =====================================================================================
# Shape helpers. Every shape becomes a "poly" element (a Blockbench mesh) of explicit corners.
# =====================================================================================

def lathe(name: str, group: str, axis: str, rings: list, sides: int, uv, twist: float | None = None,
          cap_start=None, cap_end=None, face_uv=None) -> dict:
    """A faceted can / ball / lens: rings of `sides` corners stacked along an axis.

    axis "y": each ring = (y, radius_x, radius_z[, centre_x, centre_z])
    axis "z": each ring = (z, radius_x, radius_y[, centre_x, centre_y])
    axis "x": each ring = (x, radius_y, radius_z[, centre_y, centre_z])  (rollers, axles)
    uv        = the texture rect for the sides (each facet shows the whole rect)
    face_uv   = optional function (band, segment) -> rect (or None = uv) for special facets
    cap_start / cap_end = texture rect for the first / last ring's lid (None = left open)
    twist     = angle of the first corner (default: half a facet, so one facet faces -Z)."""
    twist = math.pi / sides if twist is None else twist
    verts, faces = {}, []
    for r, ring in enumerate(rings):
        t, ra, rb = ring[0], ring[1], ring[2]
        ca = ring[3] if len(ring) > 3 else 0.0
        cb = ring[4] if len(ring) > 4 else 0.0
        for i in range(sides):
            a = twist + i * 2 * math.pi / sides
            u, w = ca + ra * math.cos(a), cb + rb * math.sin(a)
            if axis == "y":
                verts["r%d_%d" % (r, i)] = [round(u, 3), round(t, 3), round(w, 3)]
            elif axis == "z":
                verts["r%d_%d" % (r, i)] = [round(u, 3), round(w, 3), round(t, 3)]
            else:
                verts["r%d_%d" % (r, i)] = [round(t, 3), round(u, 3), round(w, 3)]
    for r in range(len(rings) - 1):
        for i in range(sides):
            j = (i + 1) % sides
            rect = (face_uv(r, i) if face_uv else None) or uv
            faces.append({"v": ["r%d_%d" % (r, i), "r%d_%d" % (r, j), "r%d_%d" % (r + 1, j), "r%d_%d" % (r + 1, i)], "uv": rect})
    ax = {"x": 0, "y": 1, "z": 2}[axis]
    for cap, r in ((cap_start, 0), (cap_end, len(rings) - 1)):
        if cap is None:
            continue
        # Which way the lid faces: away from the neighbouring ring.
        other = rings[1][0] if r == 0 else rings[-2][0]
        facing = -1 if rings[r][0] < other else 1
        keys = ["r%d_%d" % (r, i) for i in range(sides)]
        fan = [[keys[0], keys[k], keys[k + 1]] for k in range(1, sides - 1)]  # a fan of triangles
        for tri, rect in zip(fan, cap_rects([verts[k] for k in keys], [[verts[k] for k in t] for t in fan], cap, ax, facing)):
            faces.append({"v": tri, "uv": rect})
    return {"type": "poly", "name": name, "group": group, "vertices": verts, "faces": faces}


def _project(p, axis, facing):
    """How tools/cypurr_models.py lays a texture onto a face pointing along +/- axis (0 x, 1 y, 2 z)."""
    x, y, z = p
    if axis == 0:
        return (z if facing < 0 else -z, -y)
    if axis == 2:
        return (-x if facing < 0 else x, -y)
    return (x, z if facing > 0 else -z)


def cap_rects(all_points, faces, rect, axis, facing):
    """The model kit stretches the WHOLE texture rect over EACH face. For a lid cut into a fan of
    triangles that repeats the picture per triangle. This gives each triangle just its own piece
    of the rect instead, so the picture (whiskers, an eye) is laid once across the whole lid."""
    flat = [_project(p, axis, facing) for p in all_points]
    umin, umax = min(f[0] for f in flat), max(f[0] for f in flat)
    vmin, vmax = min(f[1] for f in flat), max(f[1] for f in flat)
    x1, y1, x2, y2 = rect
    out = []
    for pts in faces:
        fl = [_project(p, axis, facing) for p in pts]
        a0, a1 = min(f[0] for f in fl), max(f[0] for f in fl)
        b0, b1 = min(f[1] for f in fl), max(f[1] for f in fl)
        out.append([round(x1 + (x2 - x1) * (a0 - umin) / (umax - umin), 4), round(y1 + (y2 - y1) * (b0 - vmin) / (vmax - vmin), 4),
                    round(x1 + (x2 - x1) * (a1 - umin) / (umax - umin), 4), round(y1 + (y2 - y1) * (b1 - vmin) / (vmax - vmin), 4)])
    return out


def tube(name: str, group: str, points: list, radii: list, uv, cap_start=None, cap_end=None) -> list:
    """A bent tube (a tail, a hose) as one 4-sided frustum per segment, each square turned to
    face along the tube. points = centre line [x,y,z] list, radii = one per point."""
    def norm(v):
        l = math.sqrt(sum(c * c for c in v)) or 1.0
        return [c / l for c in v]

    def cross(a, b):
        return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]

    frames = []
    for i, p in enumerate(points):
        a = points[max(0, i - 1)]
        b = points[min(len(points) - 1, i + 1)]
        d = norm([b[k] - a[k] for k in range(3)])
        side = [1.0, 0.0, 0.0]
        other = norm(cross(d, side))
        side = norm(cross(other, d))
        ring = []
        for c in range(4):
            ang = math.pi / 4 + c * math.pi / 2
            ring.append([round(p[k] + radii[i] * (math.cos(ang) * side[k] + math.sin(ang) * other[k]), 3) for k in range(3)])
        frames.append(ring)
    elements = []
    for s in range(len(points) - 1):
        verts, faces = {}, []
        for c in range(4):
            verts["a%d" % c] = frames[s][c]
            verts["b%d" % c] = frames[s + 1][c]
        for c in range(4):
            d = (c + 1) % 4
            faces.append({"v": ["a%d" % c, "a%d" % d, "b%d" % d, "b%d" % c], "uv": uv})
        if s == 0 and cap_start:
            faces.append({"v": ["a0", "a1", "a2", "a3"], "uv": cap_start})
        if s == len(points) - 2 and cap_end:
            faces.append({"v": ["b0", "b1", "b2", "b3"], "uv": cap_end})
        elements.append({"type": "poly", "name": "%s%d" % (name, s + 1), "group": group, "vertices": verts, "faces": faces})
    return elements


def pyramid(name: str, group: str, base: list, apex: list, uv, front_uv=None) -> dict:
    """A 4-sided pyramid (cat ear, spike). base = 4 corners in order round the edge."""
    verts = {"b%d" % i: base[i] for i in range(4)}
    verts["t"] = apex
    faces = []
    for i in range(4):
        j = (i + 1) % 4
        mid_z = (base[i][2] + base[j][2]) / 2
        faces.append({"v": ["b%d" % i, "b%d" % j, "t"], "uv": front_uv if front_uv and mid_z == min(b[2] for b in base) else uv})
    faces.append({"v": ["b0", "b1", "b2", "b3"], "uv": uv})
    return {"type": "poly", "name": name, "group": group, "vertices": verts, "faces": faces}


def tetra(name: str, group: str, corners: list, uv) -> dict:
    """A 4-cornered spike (cheek tuft, fin)."""
    keys = ["a", "b", "c", "d"]
    verts = dict(zip(keys, corners))
    faces = [{"v": f, "uv": uv} for f in (["a", "b", "c"], ["a", "b", "d"], ["b", "c", "d"], ["a", "c", "d"])]
    return {"type": "poly", "name": name, "group": group, "vertices": verts, "faces": faces}


def box(name: str, group: str, frm, to, uv=None, **faces) -> dict:
    """A plain box (cube element). faces = north=/sides=/top=... rects, uv = all faces."""
    el = {"type": "cube", "name": name, "group": group, "from": list(frm), "to": list(to)}
    if uv is not None:
        el["all"] = uv
    el.update(faces)
    return el


def prism_poly(name: str, group: str, outline: list, z0: float, z1: float, uv, front_uv=None) -> dict:
    """A flat shape (outline [x,y] corners, convex) pushed out from z0 (back) to z1 (front)."""
    verts, faces = {}, []
    n = len(outline)
    for i, (x, y) in enumerate(outline):
        verts["f%d" % i] = [x, y, z1]
        verts["k%d" % i] = [x, y, z0]
    for i in range(n):
        j = (i + 1) % n
        faces.append({"v": ["f%d" % i, "f%d" % j, "k%d" % j, "k%d" % i], "uv": uv})
    for k in range(1, n - 1):
        faces.append({"v": ["f0", "f%d" % k, "f%d" % (k + 1)], "uv": front_uv or uv})
        faces.append({"v": ["k0", "k%d" % k, "k%d" % (k + 1)], "uv": uv})
    return {"type": "poly", "name": name, "group": group, "vertices": verts, "faces": faces}


# =====================================================================================
# Pixel-art helpers (they return paint ops for tools/cypurr_models.py paint_texture)
# =====================================================================================

def wavy_stripes(rect, color, every=5, thick=2, wave=1.0, period=4.0, phase=0.0):
    x1, y1, x2, y2 = rect
    px = []
    for y0 in range(y1 + 1, y2, every):
        for x in range(x1, x2):
            yy = y0 + round(wave * math.sin((x + phase) / period))
            for t in range(thick):
                if y1 <= yy + t < y2:
                    px.append([x, yy + t, color])
    return {"op": "pixels", "list": px}


def ellipse(cx, cy, rx, ry, color, rect=None):
    px = []
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                if rect is None or (rect[0] <= x < rect[2] and rect[1] <= y < rect[3]):
                    px.append([x, y, color])
    return {"op": "pixels", "list": px}


# =====================================================================================
# THE CAT: a chunky armless PS1 mascot cat, ~1.07 m tall to the ear tips.
# Groups = the node names the game uses (scenes/cat_model.tscn, CatLook.COLOR_PARTS):
#   fur:      Body, LegL, LegR, Head, EarL, EarR, Tail
#   markings: Belly, Muzzle      eyes: EyeL, EyeR      nose: Nose
# Each group's ORIGIN is its hinge: legs at the hip, tail at its root (cat_player.gd / npc.gd).
# The texture is grey / cream on purpose: the game MULTIPLIES it by the chosen colour.
# =====================================================================================

CAT_UV = {
    "fur_stripes": [0, 0, 32, 16],   # body / head sides / tail: tabby stripes
    "forehead":    [32, 0, 48, 16],  # front-top of the head: the tabby "M"
    "fur":         [48, 0, 64, 16],  # plain fur grain (legs, ear backs, head top)
    "inner_ear":   [0, 16, 16, 32],
    "markings":    [16, 16, 32, 32],  # belly / muzzle sides
    "whiskers":    [32, 16, 48, 32],  # muzzle front: whisker dots + lines
    "eye":         [48, 16, 64, 32],  # iris, slit pupil, shine
    "eye_rim":     [0, 32, 16, 48],
    "nose":        [16, 32, 32, 48],
    "paw":         [32, 32, 48, 48],  # toe beans under the paws
    "tail":        [48, 32, 64, 48],  # ringed tail stripes
}


def cat_paint() -> list:
    U = CAT_UV
    fur, fur_dark, fur_light = "#ebe6dd", "#a39d92", "#f7f4ee"
    ops = [
        {"op": "comment", "note": "64x64 cat texture. GREY/CREAM ON PURPOSE: the game multiplies it by the "
                                  "chosen FUR / MARKINGS / EYES / NOSE colour, so only the shading shows. Layout: "
                                  + ", ".join("%s %s" % (k, v) for k, v in U.items())},
        {"op": "fill", "rect": [0, 0, 64, 64], "color": fur},
    ]
    # Fur areas: soft grain everywhere.
    for key in ("fur_stripes", "forehead", "fur", "tail"):
        ops.append({"op": "noise", "rect": U[key], "amount": 0.35, "spread": 0.07})
    ops.append(wavy_stripes(U["fur_stripes"], fur_dark, every=5, thick=2, wave=1.0, period=2.5))
    # Forehead: the tabby M plus two short stripes either side.
    x0, y0 = U["forehead"][0], U["forehead"][1]
    m = [(3, 9), (3, 8), (3, 7), (3, 6), (4, 5), (5, 6), (6, 7), (7, 8), (8, 8), (9, 7), (10, 6), (11, 5),
         (12, 6), (12, 7), (12, 8), (12, 9), (7, 9), (8, 9), (7, 10), (8, 10), (7, 11), (8, 11)]
    ops.append({"op": "pixels", "list": [[x0 + x, y0 + y, fur_dark] for x, y in m] +
                [[x0 + x + 1, y0 + y, fur_dark] for x, y in m if x in (3, 12)]})
    ops.append({"op": "pixels", "list": [[x0 + x, y0 + 1, fur_dark] for x in (1, 2, 3, 12, 13, 14)] +
                [[x0 + x, y0 + 2, fur_dark] for x in (0, 1, 14, 15)]})
    ops.append({"op": "noise", "rect": U["fur"], "amount": 0.25, "spread": 0.06, "color": fur_light})
    # Ringed tail.
    tx1, ty1, tx2, ty2 = U["tail"]
    ops.append({"op": "stripes", "rect": U["tail"], "colors": ["#00000000", "#00000000", fur_dark + "d0"], "width": 2, "direction": "horizontal"})
    # Inner ear: darker, with a lighter tuft of fur along the middle.
    ops.append({"op": "gradient", "rect": U["inner_ear"], "top": "#7a746c", "bottom": "#b5aea4"})
    ix, iy = U["inner_ear"][0], U["inner_ear"][1]
    ops.append({"op": "pixels", "list": [[ix + 7 + (y % 3) - 1, iy + y, fur_light] for y in range(5, 15)]})
    ops.append({"op": "edge", "rect": U["inner_ear"], "color": "#ddd7cd"})
    # Markings (belly / muzzle): near white, faint grain.
    ops.append({"op": "fill", "rect": U["markings"], "color": "#fbfaf7"})
    ops.append({"op": "noise", "rect": U["markings"], "amount": 0.25, "spread": 0.05})
    # Muzzle front: whisker dots in rows and two whisker lines each side.
    wx, wy = U["whiskers"][0], U["whiskers"][1]
    ops.append({"op": "fill", "rect": U["whiskers"], "color": "#fbfaf7"})
    ops.append({"op": "pixels", "list": [[wx + x, wy + y, "#9a958e"] for x, y in
                ((4, 6), (6, 5), (8, 6), (5, 8), (7, 8), (9, 8), (11, 6), (10, 5), (12, 8))]})
    ops.append({"op": "line", "from": [wx + 0, wy + 9], "to": [wx + 6, wy + 10], "color": "#6f6a64"})
    ops.append({"op": "line", "from": [wx + 0, wy + 12], "to": [wx + 6, wy + 11], "color": "#6f6a64"})
    ops.append({"op": "line", "from": [wx + 9, wy + 10], "to": [wx + 15, wy + 9], "color": "#6f6a64"})
    ops.append({"op": "line", "from": [wx + 9, wy + 11], "to": [wx + 15, wy + 12], "color": "#6f6a64"})
    ops.append({"op": "line", "from": [wx + 7, wy + 12], "to": [wx + 8, wy + 12], "color": "#9a958e"})
    # Eye: light iris (tinted the EYES colour), darker ring, big slit pupil, two shines.
    ex, ey = U["eye"][0], U["eye"][1]
    ops.append({"op": "fill", "rect": U["eye"], "color": "#5c5c5c"})
    ops.append(ellipse(ex + 8, ey + 8, 7.6, 7.6, "#9a9a9a", U["eye"]))
    ops.append(ellipse(ex + 8, ey + 8, 6.4, 6.4, "#e2e2e2", U["eye"]))
    ops.append(ellipse(ex + 8, ey + 9, 4.6, 4.6, "#f6f6f6", U["eye"]))
    ops.append(ellipse(ex + 8, ey + 8, 1.8, 6.2, "#080808", U["eye"]))
    ops.append({"op": "pixels", "list": [[ex + x, ey + y, "#ffffff"] for x, y in ((4, 3), (5, 3), (4, 4), (5, 4), (11, 11))]})
    ops.append({"op": "fill", "rect": U["eye_rim"], "color": "#262626"})
    ops.append({"op": "noise", "rect": U["eye_rim"], "amount": 0.3, "spread": 0.2})
    # Nose: light with a shine on top, darker underneath.
    nx, ny = U["nose"][0], U["nose"][1]
    ops.append({"op": "fill", "rect": U["nose"], "color": "#e4e4e4"})
    ops.append({"op": "gradient", "rect": [nx, ny + 9, nx + 16, ny + 16], "top": "#e4e4e400", "bottom": "#9c9c9c"})
    ops.append({"op": "fill", "rect": [nx + 4, ny + 2, nx + 8, ny + 4], "color": "#ffffff"})
    # Paw pads (under the feet): four toe beans and a big pad.
    px_, py_ = U["paw"][0], U["paw"][1]
    ops.append({"op": "fill", "rect": U["paw"], "color": "#d8d3ca"})
    for cx, cy in ((3.5, 4), (6.5, 2.8), (9.5, 2.8), (12.5, 4)):
        ops.append(ellipse(px_ + cx, py_ + cy, 1.5, 1.5, "#8d8780"))
    ops.append(ellipse(px_ + 8, py_ + 10, 4.5, 3.5, "#8d8780"))
    return ops


def cat_spec() -> dict:
    U = CAT_UV
    els = []
    # --- Legs: stubby 6-sided columns, paw a bit wider at the front. Hinge = hip (top). ---
    for side, x in (("L", -1.8), ("R", 1.8)):
        els.append(lathe("Leg" + side, "Leg" + side, "y", [
            (0.0, 1.55, 1.75, x, -0.35),
            (1.1, 1.6, 1.8, x, -0.35),
            (3.8, 1.3, 1.3, x, 0.2),
        ], 6, U["fur"], cap_start=U["paw"], cap_end=U["fur"]))
    # --- Body: tapered 8-sided torso above the hips. ---
    els.append(lathe("Body", "Body", "y", [
        (2.6, 4.2, 3.6), (5.8, 4.05, 3.45), (9.4, 3.0, 2.6)],
        8, U["fur_stripes"], cap_start=U["fur"], cap_end=U["fur"]))
    # --- Belly: a rounded tummy patch bulging out of the front. ---
    els.append(lathe("Belly", "Belly", "z", [
        (-2.6, 2.4, 3.0, 0, 5.6), (-3.75, 2.15, 2.6, 0, 5.6), (-4.05, 1.5, 1.9, 0, 5.6)],
        6, U["markings"], cap_end=U["markings"]))
    # --- Head: wide faceted head. The front-top facet carries the tabby M. ---
    def head_uv(band, seg):
        front = seg == 5  # (with 8 facets and the default twist, facet 5 faces -Z)
        if band == 2 and front:
            return U["forehead"]
        if band == 0:
            return U["fur"]
        return None
    els.append(lathe("Head", "Head", "y", [
        (9.0, 3.4, 3.0), (11.2, 5.0, 3.9), (13.4, 4.75, 3.7), (15.2, 3.3, 2.7)],
        8, U["fur_stripes"], cap_start=U["fur"], cap_end=U["fur"], face_uv=head_uv))
    # Cheek tufts: two angled spikes of fur sticking out of each side of the face.
    for s in (-1, 1):
        els.append(tetra("Tuft%s1" % ("L" if s < 0 else "R"), "Head",
                         [[s * 4.1, 12.4, -1.3], [s * 4.1, 10.4, -1.5], [s * 4.1, 11.2, 1.3], [s * 6.5, 10.6, -0.5]], U["fur"]))
        els.append(tetra("Tuft%s2" % ("L" if s < 0 else "R"), "Head",
                         [[s * 3.7, 10.8, -1.4], [s * 3.6, 9.3, -1.0], [s * 3.7, 9.9, 1.0], [s * 5.7, 9.2, 0.2]], U["fur"]))
    # --- Ears: big triangles leaning outward, dark inner side to the front. Hinge = base. ---
    for side, s in (("L", -1), ("R", 1)):
        base = [[s * 1.3, 14.6, -1.0], [s * 4.4, 14.6, -1.0], [s * 4.4, 14.6, 0.9], [s * 1.3, 14.6, 0.9]]
        els.append(pyramid("Ear" + side, "Ear" + side, base, [s * 3.9, 17.3, -0.1], U["fur"], front_uv=U["inner_ear"]))
    # --- Muzzle: plump double-cheek snout pads. ---
    # (Seen from the front the cat's LEFT pad is on the right: it gets the right half of the
    # whisker picture, so the two pads show one face.)
    wx1, wy1, wx2, wy2 = U["whiskers"]
    half = (wx1 + wx2) // 2
    for side, x, rect in (("L", -1.05, [half, wy1, wx2, wy2]), ("R", 1.05, [wx1, wy1, half, wy2])):
        els.append(lathe("Muzzle" + side, "Muzzle", "z", [
            (-2.8, 1.5, 1.3, x, 10.5), (-4.1, 1.35, 1.15, x, 10.5), (-4.6, 0.9, 0.8, x, 10.5)],
            6, U["markings"], cap_end=rect))
    # --- Nose: a little triangle button on top of the snout. ---
    els.append(prism_poly("Nose", "Nose", [[-1.0, 12.15], [1.0, 12.15], [0.0, 11.0]], -4.1, -5.05, U["nose"]))
    # --- Eyes: big domed lenses popping out of the face. ---
    for side, x in (("L", -1.95), ("R", 1.95)):
        els.append(lathe("Eye" + side, "Eye" + side, "z", [
            (-2.6, 1.5, 1.8, x, 13.3), (-3.7, 1.4, 1.7, x, 13.3), (-4.05, 1.05, 1.3, x, 13.3)],
            6, U["eye_rim"], cap_end=U["eye"]))
    # --- Tail: segmented, curling up behind. Hinge = its root in the body. ---
    els += tube("Tail", "Tail", [[0, 4.4, 2.6], [0, 6.6, 5.4], [0, 10.0, 6.8], [0, 13.0, 6.2]],
                [1.0, 0.85, 0.65, 0.2], U["tail"], cap_start=U["fur"])
    groups = [
        {"name": "Body", "origin": [0, 2.6, 0]},
        {"name": "Belly", "origin": [0, 5.6, -3.4]},
        {"name": "LegL", "origin": [-1.8, 3.8, 0.0]},
        {"name": "LegR", "origin": [1.8, 3.8, 0.0]},
        {"name": "Head", "origin": [0, 9.2, 0]},
        {"name": "EarL", "origin": [-2.8, 14.6, 0]},
        {"name": "EarR", "origin": [2.8, 14.6, 0]},
        {"name": "Muzzle", "origin": [0, 10.5, -3.6]},
        {"name": "Nose", "origin": [0, 11.4, -4.4]},
        {"name": "EyeL", "origin": [-1.95, 13.3, -3.6]},
        {"name": "EyeR", "origin": [1.95, 13.3, -3.6]},
        {"name": "Tail", "origin": [0, 4.4, 2.6]},
    ]
    return {
        "name": "cat", "kind": "character",
        "about": "The chunky ARMLESS PS1 mascot cat (player + every sewer NPC). ~1.07 m to the ear tips, "
                 "faces -Z. Group names = the node names CatLook paints (fur: Body LegL LegR Head EarL EarR Tail; "
                 "markings: Belly Muzzle; eyes: EyeL EyeR; nose: Nose). Each group's origin is its hinge: "
                 "legs swing from the hip, the tail sways from its root. The texture is grey/cream on purpose: "
                 "the game multiplies it by the chosen colours. Made by tools/make_creature_specs.py.",
        "texture_size": 64, "seed": 7, "background": "#ebe6dd",
        "paint": cat_paint(), "groups": groups, "elements": els,
    }


def bar(name: str, group: str, p0, p1, width: float, y0: float, y1: float, uv) -> dict:
    """A flat-lying box from point p0 to p1 ([x, z] each) between heights y0 and y1 (drone arms)."""
    dx, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dz) or 1.0
    sx, sz = -dz / length * width / 2, dx / length * width / 2
    verts = {}
    for tag, (px, pz) in (("a", p0), ("b", p1)):
        for side, sgn in (("l", 1), ("r", -1)):
            for lvl, y in (("d", y0), ("u", y1)):
                verts[tag + side + lvl] = [round(px + sgn * sx, 3), y, round(pz + sgn * sz, 3)]
    faces = [{"v": f, "uv": uv} for f in (
        ["alu", "aru", "bru", "blu"], ["ald", "ard", "brd", "bld"],
        ["alu", "blu", "bld", "ald"], ["aru", "bru", "brd", "ard"],
        ["alu", "aru", "ard", "ald"], ["blu", "bru", "brd", "bld"])]
    return {"type": "poly", "name": name, "group": group, "vertices": verts, "faces": faces}


def blade(name: str, group: str, centre, angle_deg: float, length: float, width: float, uv) -> dict:
    """A flat propeller blade / bristle through `centre`, seen from above AND below (two faces)."""
    a = math.radians(angle_deg)
    ux, uz = math.cos(a) * length / 2, math.sin(a) * length / 2
    wx, wz = -math.sin(a) * width / 2, math.cos(a) * width / 2
    cx, cy, cz = centre
    verts = {"p0": [round(cx - ux - wx, 3), cy, round(cz - uz - wz, 3)], "p1": [round(cx + ux - wx, 3), cy, round(cz + uz - wz, 3)],
             "p2": [round(cx + ux + wx, 3), cy, round(cz + uz + wz, 3)], "p3": [round(cx - ux + wx, 3), cy, round(cz - uz + wz, 3)]}
    # (A flat piece has no inside, so the kit keeps each face the way it is listed: one each way.)
    return {"type": "poly", "name": name, "group": group, "vertices": verts,
            "faces": [{"v": ["p0", "p1", "p2", "p3"], "uv": uv}, {"v": ["p3", "p2", "p1", "p0"], "uv": uv}]}


def police_light_paint(rect, base="#f4f4f4"):
    """A siren lens: bright with fresnel ridges (the game tints it red / blue and makes it glow)."""
    x1, y1, x2, y2 = rect
    return [{"op": "fill", "rect": rect, "color": base},
            {"op": "stripes", "rect": rect, "colors": ["#00000000", "#bdbdbd"], "width": 2, "direction": "vertical"},
            {"op": "fill", "rect": [x1, y1, x2, y1 + 2], "color": "#ffffff"},
            {"op": "edge", "rect": rect, "color": "#8a8a8a"}]


def visor_paint(rect):
    """A cyclops scanner visor: bright scanlines and a hot centre cross (the game tints + glows it)."""
    x1, y1, x2, y2 = rect
    h = y2 - y1
    return [{"op": "fill", "rect": rect, "color": "#7a7a7a"},
            {"op": "stripes", "rect": rect, "colors": ["#d8d8d8", "#9a9a9a"], "width": 1, "direction": "horizontal"},
            {"op": "fill", "rect": [x1, y1 + h // 2 - 2, x2, y1 + h // 2 + 2], "color": "#ffffff"},
            {"op": "fill", "rect": [x1 + (x2 - x1) // 2 - 3, y1 + 2, x1 + (x2 - x1) // 2 + 3, y2 - 2], "color": "#ffffff"},
            {"op": "edge", "rect": rect, "color": "#3a3a3a"}]


def rivets(rect, every=6, color="#c9c9c9", inset=1):
    x1, y1, x2, y2 = rect
    px = []
    for x in range(x1 + inset, x2 - inset, every):
        px += [[x, y1 + inset, color], [x, y2 - 1 - inset, color]]
    return {"op": "pixels", "list": px}


def hazard(rect, flip=False):
    x1, y1, x2, y2 = rect
    return {"op": "pixels", "list": [[x, y, "#ffc61a" if (((x + y) if flip else (x - y)) // 3) % 2 == 0 else "#14141a"]
                                     for y in range(y1, y2) for x in range(x1, x2)]}


# =====================================================================================
# VAC-COP (and the MEGA VAC-COP: the same model, scaled 2.6x by scenes/roomba_boss.tscn)
# Groups the game uses (roomba.gd / enemy.gd): Body (flashes when shot), Cap, Bumper, Eye
# (the cyclops visor: glows, and it's the WEAK SPOT), SirenRed, SirenBlue, Brush + Brush2
# (the corner whisker brushes, spun round their own middle).
# =====================================================================================

ROOMBA_UV = {
    "stencil_vac": [0, 0, 32, 16], "stencil_protect": [32, 0, 64, 16], "stencil_suction": [64, 0, 96, 16],
    "vent": [96, 0, 128, 16], "skirt": [0, 16, 32, 24], "bevel": [0, 24, 32, 32], "dark_metal": [32, 16, 64, 32],
    "hazard": [64, 16, 96, 32], "housing": [96, 16, 128, 32], "top": [0, 32, 64, 96],
    "cap_side": [64, 32, 96, 48], "cap_top": [96, 32, 128, 64], "eye": [64, 48, 96, 64],
    "siren": [64, 64, 96, 80], "bristle": [96, 64, 128, 80], "underside": [64, 80, 128, 96],
}


def roomba_paint() -> list:
    U = ROOMBA_UV
    white, black = "#eceef2", "#15161b"
    ops = [{"op": "comment", "note": "128x128 VAC-COP texture: black-and-white police interceptor paint. "
                                     + ", ".join("%s %s" % (k, v) for k, v in U.items())},
           {"op": "fill", "rect": [0, 0, 128, 128], "color": "#2a2c33"}]
    # Side stencils: white upper half, black lower half, white stencil text on the black.
    for key, text, tx in (("stencil_vac", "VAC-COP", 2), ("stencil_protect", "PROTECT", 2), ("stencil_suction", "&SUCTION", 4)):
        x1, y1, x2, y2 = U[key]
        ops += [{"op": "fill", "rect": [x1, y1, x2, y1 + 7], "color": white},
                {"op": "fill", "rect": [x1, y1 + 7, x2, y2], "color": black},
                {"op": "fill", "rect": [x1, y1 + 6, x2, y1 + 7], "color": "#3b78ff"},
                {"op": "noise", "rect": U[key], "amount": 0.2, "spread": 0.08},
                {"op": "text", "pos": [x1 + tx, y1 + 9], "text": text, "color": white, "worn": 0.08,
                 "spacing": 0 if len(text) > 7 else 1},
                rivets([x1, y1, x2, y1 + 6], every=8, color="#9da3ad")]
    ops.append({"op": "pixels", "list": [[U["stencil_vac"][0] + 13 + dx, 2 + dy, "#ffcc33"] for dx, dy in
                                         ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (0, 3), (2, 3))]})  # a little badge star
    x1, y1, x2, y2 = U["vent"]
    ops += [{"op": "fill", "rect": U["vent"], "color": black},
            {"op": "stripes", "rect": [x1 + 4, y1 + 4, x2 - 4, y2 - 4], "colors": ["#05060a", "#3a3d46"], "width": 2},
            rivets(U["vent"], every=5, color="#7b808a"), {"op": "edge", "rect": U["vent"], "color": "#474b55"}]
    ops += [{"op": "fill", "rect": U["skirt"], "color": "#1c1d22"}, {"op": "noise", "rect": U["skirt"], "amount": 0.4, "spread": 0.2},
            {"op": "fill", "rect": U["bevel"], "color": white}, {"op": "fill", "rect": [0, 30, 32, 32], "color": black},
            {"op": "fill", "rect": U["dark_metal"], "color": "#2b2e36"}, {"op": "noise", "rect": U["dark_metal"], "amount": 0.4, "spread": 0.12},
            rivets(U["dark_metal"], every=5, color="#6f7480")]
    ops += [hazard(U["hazard"]), {"op": "noise", "rect": U["hazard"], "amount": 0.25, "spread": 0.15},
            {"op": "edge", "rect": U["hazard"], "color": "#0b0b0e"}]
    ops += [{"op": "fill", "rect": U["housing"], "color": "#0e0f13"}, {"op": "edge", "rect": U["housing"], "color": "#555a66"},
            {"op": "noise", "rect": U["housing"], "amount": 0.3, "spread": 0.1}]
    # The roof: white with a black ring, a big VAC-COP and a gold badge (front = top of the picture).
    x1, y1, x2, y2 = U["top"]
    ops += [{"op": "fill", "rect": U["top"], "color": white},
            {"op": "noise", "rect": U["top"], "amount": 0.25, "spread": 0.06},
            ellipse(x1 + 32, y1 + 32, 31, 31, black), ellipse(x1 + 32, y1 + 32, 28, 28, white),
            {"op": "fill", "rect": [x1 + 4, y1 + 9, x2 - 4, y1 + 22], "color": black},
            {"op": "text", "pos": [x1 + 5, y1 + 11], "text": "VAC-COP", "color": white, "scale": 2, "spacing": 1},
            ellipse(x1 + 32, y1 + 30, 4, 4, "#e0a922"), ellipse(x1 + 32, y1 + 30, 2, 2, "#ffe27a"),
            {"op": "text", "pos": [x1 + 15, y1 + 52], "text": "UNIT 404", "color": "#1d1f26"}]
    ops += [{"op": "fill", "rect": U["cap_side"], "color": "#22252c"},
            {"op": "stripes", "rect": [64, 36, 96, 46], "colors": ["#16181d", "#3c404a"], "width": 2},
            {"op": "fill", "rect": [64, 32, 96, 34], "color": white},
            {"op": "fill", "rect": U["cap_top"], "color": "#1a1c22"},
            ellipse(112, 48, 13, 13, "#2e323b"), {"op": "text", "pos": [106, 46], "text": "OC", "color": "#59c8ff", "spacing": 2}]
    ops += visor_paint(U["eye"]) + police_light_paint(U["siren"])
    ops += [{"op": "fill", "rect": U["bristle"], "color": "#2d2b28"},
            {"op": "stripes", "rect": U["bristle"], "colors": ["#4a463f", "#1d1c19", "#3b3833"], "width": 1, "direction": "horizontal"},
            {"op": "fill", "rect": U["underside"], "color": "#111216"},
            {"op": "noise", "rect": U["underside"], "amount": 0.3, "spread": 0.2}]
    return ops


def roomba_spec() -> dict:
    U = ROOMBA_UV
    els = []

    def body_uv(band, seg):
        if band == 0:
            return U["skirt"]
        if band == 2:
            return U["bevel"]
        return {0: U["stencil_protect"], 1: U["vent"], 2: U["stencil_suction"], 3: U["stencil_vac"],
                4: U["stencil_protect"], 5: U["vent"], 6: U["stencil_suction"], 7: U["stencil_vac"]}[seg]
    els.append(lathe("Shell", "Body", "y", [(0.6, 7.3, 7.3), (1.6, 8.0, 8.0), (3.0, 8.0, 8.0), (3.8, 7.0, 7.0)],
                     8, U["vent"], cap_start=U["underside"], cap_end=U["top"], face_uv=body_uv))
    # The visor housing: a hood and two cheeks round the eye, so the eye sits RECESSED in it.
    els.append(box("VisorHood", "Body", [-3.9, 3.5, -9.0], [3.9, 4.1, -7.0], U["housing"]))
    els.append(box("VisorCheekL", "Body", [-3.9, 1.6, -8.9], [-3.3, 3.5, -7.0], U["housing"]))
    els.append(box("VisorCheekR", "Body", [3.3, 1.6, -8.9], [3.9, 3.5, -7.0], U["housing"]))
    # The eye: a wide cyclops scanner visor (bigger than the old one, so you can aim for it).
    els.append(box("Visor", "Eye", [-3.3, 1.75, -8.5], [3.3, 3.5, -7.0], U["eye"]))
    # Ram bumper: a heavy angled wedge with hazard stripes on its face.
    els.append({"type": "poly", "name": "Ram", "group": "Bumper", "vertices": {
        "bl": [-6.4, 0.3, -6.4], "br": [6.4, 0.3, -6.4], "tl": [-6.4, 1.7, -6.6], "tr": [6.4, 1.7, -6.6],
        "fbl": [-5.6, 0.2, -9.0], "fbr": [5.6, 0.2, -9.0], "ftl": [-5.6, 1.6, -8.7], "ftr": [5.6, 1.6, -8.7]},
        "faces": [{"v": ["fbl", "fbr", "ftr", "ftl"], "uv": U["hazard"]}, {"v": ["tl", "tr", "ftr", "ftl"], "uv": U["dark_metal"]},
                  {"v": ["bl", "br", "fbr", "fbl"], "uv": U["underside"]}, {"v": ["bl", "tl", "ftl", "fbl"], "uv": U["hazard"]},
                  {"v": ["br", "tr", "ftr", "fbr"], "uv": U["hazard"]}, {"v": ["bl", "br", "tr", "tl"], "uv": U["dark_metal"]}]})
    # The dust-bin turret dome at the back, with a light-bar base on top.
    els.append(lathe("Dome", "Cap", "y", [(3.6, 4.6, 4.6, 0, 1.8), (5.2, 4.2, 4.2, 0, 1.8), (6.0, 3.0, 3.0, 0, 1.8)],
                     8, U["cap_side"], cap_end=U["cap_top"]))
    els.append(box("LightBar", "Cap", [-3.4, 5.8, 1.0], [3.4, 6.3, 2.6], U["dark_metal"]))
    for name, x in (("SirenRed", -1.75), ("SirenBlue", 1.75)):
        els.append(lathe(name, name, "y", [(6.2, 1.4, 0.85, x, 1.8), (7.2, 1.4, 0.85, x, 1.8), (7.8, 0.8, 0.5, x, 1.8)],
                         6, U["siren"], cap_end=U["siren"]))
    # Two corner whisker brushes under the front corners (four bristles each, spun by roomba.gd).
    for name, x in (("Brush", -5.6), ("Brush2", 5.6)):
        for k in range(4):
            els.append(blade("%sBristle%d" % (name, k), name, [x, 0.25, -5.9], k * 45.0, 6.4, 0.5, U["bristle"]))
    groups = [{"name": "Body", "origin": [0, 0, 0]}, {"name": "Cap", "origin": [0, 3.6, 1.8]},
              {"name": "Bumper", "origin": [0, 1.0, -7.6]}, {"name": "Eye", "origin": [0, 2.6, -7.75]},
              {"name": "SirenRed", "origin": [-1.75, 6.2, 1.8]}, {"name": "SirenBlue", "origin": [1.75, 6.2, 1.8]},
              {"name": "Brush", "origin": [-5.6, 0.25, -5.9]}, {"name": "Brush2", "origin": [5.6, 0.25, -5.9]}]
    return {"name": "roomba", "kind": "character",
            "about": "VAC-COP: an armoured police-enforcer disc (the MEGA VAC-COP is the same model at 2.6x). Faces -Z, "
                     "radius 0.5 m. Groups the game uses: Body (flashes when shot), Cap, Bumper, Eye (the cyclops visor: "
                     "glows + is the crit WEAK SPOT), SirenRed, SirenBlue, Brush, Brush2 (pivot = middle, spun by roomba.gd). "
                     "Made by tools/make_creature_specs.py.",
            "texture_size": 128, "seed": 404, "background": "#2a2c33",
            "paint": roomba_paint(), "groups": groups, "elements": els}


# =====================================================================================
# LINT-TRAPPER: a heavy purple-and-black street-sweeper tank with a sticky glue roller.
# Groups: Body (flashes), Cab, Tank (glowing glue canister), Eye, SirenRed, SirenBlue,
# Brush (the glue roller; pivot = its axle, lint_trapper.tscn spins it round X).
# =====================================================================================

TRAPPER_UV = {
    "hull_side": [0, 0, 32, 16], "hull_front": [32, 0, 64, 16], "hull_top": [64, 0, 96, 32], "skirt": [96, 0, 128, 16],
    "dark": [0, 16, 32, 32], "cab": [32, 16, 64, 32], "tank": [0, 32, 32, 64], "tank_top": [32, 32, 48, 48],
    "eye": [48, 32, 80, 48], "siren": [80, 32, 96, 48], "roller": [96, 16, 128, 48], "roller_end": [48, 48, 64, 64],
    "housing": [64, 48, 80, 64], "underside": [80, 48, 96, 64],
}


def trapper_paint() -> list:
    U = TRAPPER_UV
    purple, purple_dark, black = "#8a63cf", "#4e3678", "#1c1824"
    ops = [{"op": "comment", "note": "128x128 LINT-TRAPPER texture. " + ", ".join("%s %s" % (k, v) for k, v in U.items())},
           {"op": "fill", "rect": [0, 0, 128, 128], "color": black}]
    x1, y1, x2, y2 = U["hull_side"]
    ops += [{"op": "gradient", "rect": U["hull_side"], "top": "#a07fe0", "bottom": purple_dark},
            {"op": "noise", "rect": U["hull_side"], "amount": 0.3, "spread": 0.1},
            {"op": "fill", "rect": [x1, y1 + 10, x2, y1 + 11], "color": "#ff3cb4"},
            {"op": "text", "pos": [x1 + 2, y1 + 3], "text": "LINTTRAP", "color": "#e9dcff", "worn": 0.1, "spacing": 0},
            rivets([x1, y1 + 11, x2, y2], every=5, color="#9b88c4")]
    x1, y1, x2, y2 = U["hull_front"]
    ops += [{"op": "fill", "rect": U["hull_front"], "color": purple},
            {"op": "stripes", "rect": [x1 + 2, y1 + 2, x2 - 2, y1 + 8], "colors": ["#1b1424", "#6c55a0"], "width": 2},
            {"op": "noise", "rect": U["hull_front"], "amount": 0.3, "spread": 0.1},
            {"op": "edge", "rect": U["hull_front"], "color": purple_dark}]
    x1, y1, x2, y2 = U["hull_top"]
    ops += [{"op": "fill", "rect": U["hull_top"], "color": purple},
            {"op": "noise", "rect": U["hull_top"], "amount": 0.35, "spread": 0.1},
            {"op": "fill", "rect": [x1 + 2, y1 + 22, x2 - 2, y1 + 29], "color": black},
            {"op": "text", "pos": [x1 + 3, y1 + 23], "text": "OVERCLEAN", "color": "#ff3cb4", "spacing": 0},
            {"op": "edge", "rect": U["hull_top"], "color": purple_dark}, rivets(U["hull_top"], every=6, color="#a08ad0")]
    ops += [hazard(U["skirt"], flip=True), {"op": "noise", "rect": U["skirt"], "amount": 0.25, "spread": 0.15},
            {"op": "fill", "rect": U["dark"], "color": "#1e1b25"}, {"op": "noise", "rect": U["dark"], "amount": 0.4, "spread": 0.15},
            rivets(U["dark"], every=5, color="#5a5466"),
            {"op": "fill", "rect": U["cab"], "color": purple_dark},
            {"op": "fill", "rect": [34, 19, 62, 26], "color": "#0b0910"},
            {"op": "stripes", "rect": [34, 19, 62, 26], "colors": ["#00000000", "#2a2240"], "width": 3, "direction": "vertical"},
            {"op": "edge", "rect": U["cab"], "color": "#1a1226"}]
    # The glue canister: bright (it glows pink in the game) with a level window and bubbles.
    x1, y1, x2, y2 = U["tank"]
    ops += [{"op": "fill", "rect": U["tank"], "color": "#d0d0d0"},
            {"op": "gradient", "rect": [x1, y1, x2, y1 + 10], "top": "#7a7a7a", "bottom": "#d0d0d000"},
            {"op": "fill", "rect": [x1, y1 + 2, x2, y1 + 4], "color": "#3a3a3a"},
            {"op": "fill", "rect": [x1, y2 - 4, x2, y2 - 2], "color": "#3a3a3a"},
            {"op": "spots", "rect": [x1 + 2, y1 + 12, x2 - 2, y2 - 6], "color": "#ffffff", "count": 12, "size": 1.6},
            {"op": "text", "pos": [x1 + 8, y1 + 6], "text": "GLUE", "color": "#404040", "spacing": 1},
            {"op": "fill", "rect": U["tank_top"], "color": "#5a5a5a"}, ellipse(40, 40, 3, 3, "#d8d8d8")]
    ops += visor_paint(U["eye"]) + police_light_paint(U["siren"])
    # The sticky roller: glue bands spiralling round it (bright = it glows pink).
    x1, y1, x2, y2 = U["roller"]
    ops.append({"op": "pixels", "list": [[x, y, "#e6e6e6" if ((x + 2 * y) // 4) % 2 == 0 else "#4a4a4a"]
                                         for y in range(y1, y2) for x in range(x1, x2)]})
    ops += [{"op": "spots", "rect": U["roller"], "color": "#ffffff", "count": 14, "size": 1.3},
            {"op": "fill", "rect": U["roller_end"], "color": "#2a2a2a"}, ellipse(56, 56, 3, 3, "#9a9a9a"),
            {"op": "fill", "rect": U["housing"], "color": "#0d0b12"}, {"op": "edge", "rect": U["housing"], "color": "#6b5a8f"},
            {"op": "fill", "rect": U["underside"], "color": "#0e0c12"}]
    return ops


def trapper_spec() -> dict:
    U = TRAPPER_UV
    els = []
    # Hull: a sloped-front armoured box (front faces -Z).
    els.append({"type": "poly", "name": "Hull", "group": "Body", "vertices": {
        "bfl": [-7.0, 1.0, -6.4], "bfr": [7.0, 1.0, -6.4], "bbl": [-7.0, 1.0, 7.0], "bbr": [7.0, 1.0, 7.0],
        "tfl": [-6.0, 6.6, -3.6], "tfr": [6.0, 6.6, -3.6], "tbl": [-6.0, 6.6, 6.4], "tbr": [6.0, 6.6, 6.4]},
        "faces": [{"v": ["bfl", "bfr", "tfr", "tfl"], "uv": U["hull_front"]}, {"v": ["tfl", "tfr", "tbr", "tbl"], "uv": U["hull_top"]},
                  {"v": ["bfl", "bbl", "tbl", "tfl"], "uv": U["hull_side"]}, {"v": ["bfr", "bbr", "tbr", "tfr"], "uv": U["hull_side"]},
                  {"v": ["bbl", "bbr", "tbr", "tbl"], "uv": U["dark"]}, {"v": ["bfl", "bfr", "bbr", "bbl"], "uv": U["underside"]}]})
    # Hazard-striped side skirts.
    els.append(box("SkirtL", "Body", [-8.0, 0.4, -5.6], [-7.0, 3.4, 6.8], U["dark"], west=U["skirt"]))
    els.append(box("SkirtR", "Body", [7.0, 0.4, -5.6], [8.0, 3.4, 6.8], U["dark"], east=U["skirt"]))
    # Roller arms reaching forward to the roller's axle.
    els.append(bar("ArmL", "Body", [-7.6, -2.0], [-7.6, -9.0], 0.9, 2.0, 3.2, U["dark"]))
    els.append(bar("ArmR", "Body", [7.6, -2.0], [7.6, -9.0], 0.9, 2.0, 3.2, U["dark"]))
    # Visor housing lip over the eye.
    # (Up high on the sloped front, above the roller, so you can see it - and shoot it.)
    els.append(box("VisorHood", "Body", [-4.0, 6.5, -5.9], [4.0, 7.1, -2.8], U["housing"]))
    els.append(box("Visor", "Eye", [-3.4, 4.9, -5.4], [3.4, 6.5, -3.2], U["eye"]))
    # Cab on top with the twin sirens.
    els.append(box("Cab", "Cab", [-4.2, 6.6, -2.6], [4.2, 8.8, 2.8], U["dark"], north=U["cab"], top=U["dark"]))
    for name, x in (("SirenRed", -2.2), ("SirenBlue", 2.2)):
        els.append(lathe(name, name, "y", [(8.8, 1.2, 0.8, x, -0.6), (9.9, 1.2, 0.8, x, -0.6), (10.5, 0.7, 0.45, x, -0.6)],
                         6, U["siren"], cap_end=U["siren"]))
    # Pressurised glue canister at the back.
    els.append(lathe("Canister", "Tank", "y", [(6.6, 2.8, 2.8, 0, 4.4), (11.8, 2.8, 2.8, 0, 4.4), (13.2, 1.7, 1.7, 0, 4.4)],
                     8, U["tank"], cap_end=U["tank_top"]))
    # The wide sticky roller (spins round its axle: X).
    els.append(lathe("Roller", "Brush", "x", [(-7.0, 2.6, 2.6, 2.6, -9.0), (7.0, 2.6, 2.6, 2.6, -9.0)],
                     8, U["roller"], cap_start=U["roller_end"], cap_end=U["roller_end"]))
    groups = [{"name": "Body", "origin": [0, 0, 0]}, {"name": "Cab", "origin": [0, 6.6, 0]},
              {"name": "Tank", "origin": [0, 6.6, 4.4]}, {"name": "Eye", "origin": [0, 5.7, -4.3]},
              {"name": "SirenRed", "origin": [-2.2, 8.8, -0.6]}, {"name": "SirenBlue", "origin": [2.2, 8.8, -0.6]},
              {"name": "Brush", "origin": [0, 2.6, -9.0]}]
    return {"name": "lint_trapper", "kind": "character",
            "about": "LINT-TRAPPER: heavy purple-and-black street-sweeper tank. Faces -Z. Groups the game uses: Body "
                     "(flashes), Tank (glowing glue canister), Eye (glowing visor = crit WEAK SPOT), SirenRed, SirenBlue, "
                     "Brush (the glue roller, pivot = axle, spun round X). Made by tools/make_creature_specs.py.",
            "texture_size": 128, "seed": 77, "background": "#141219",
            "paint": trapper_paint(), "groups": groups, "elements": els}


# =====================================================================================
# SQUIRT-DRONE: an angular OVERCLEAN quad-copter. The origin is its middle (it hovers).
# Groups: Body (flashes), Arms, Tank (glowing water tank), Nozzle, Eye, SirenRed, SirenBlue,
# Rotors > Rotor1..Rotor4 (each spun round its own Y by squirt_drone.gd).
# =====================================================================================

DRONE_UV = {
    "hull": [0, 0, 32, 16], "hull_top": [32, 0, 64, 32], "hull_nose": [0, 16, 16, 32], "hull_tail": [16, 16, 32, 32],
    "arm": [64, 0, 96, 8], "motor": [64, 8, 80, 16], "motor_top": [80, 8, 96, 16], "blade": [96, 0, 128, 8],
    "tank": [0, 32, 32, 48], "tank_cap": [32, 32, 48, 48], "nozzle": [48, 32, 64, 40], "eye": [64, 16, 96, 32],
    "siren": [96, 8, 112, 24], "underside": [64, 32, 96, 48],
}


def drone_paint() -> list:
    U = DRONE_UV
    white, black = "#e4e7ee", "#16171c"
    ops = [{"op": "comment", "note": "128x128 SQUIRT-DRONE texture. " + ", ".join("%s %s" % (k, v) for k, v in U.items())},
           {"op": "fill", "rect": [0, 0, 128, 128], "color": black}]
    x1, y1, x2, y2 = U["hull"]
    ops += [{"op": "gradient", "rect": U["hull"], "top": "#ffffff", "bottom": "#a9aeb9"},
            {"op": "noise", "rect": U["hull"], "amount": 0.25, "spread": 0.06},
            {"op": "fill", "rect": [x1, y1 + 9, x2, y1 + 12], "color": black},
            {"op": "fill", "rect": [x1, y1 + 10, x2, y1 + 11], "color": "#3cc8ff"},
            {"op": "text", "pos": [x1 + 4, y1 + 2], "text": "SQUIRT", "color": "#20232b", "spacing": 1},
            {"op": "edge", "rect": U["hull"], "color": "#70757f"}]
    x1, y1, x2, y2 = U["hull_top"]
    ops += [{"op": "fill", "rect": U["hull_top"], "color": white}, {"op": "noise", "rect": U["hull_top"], "amount": 0.25, "spread": 0.06},
            {"op": "fill", "rect": [x1 + 13, y1, x1 + 19, y2], "color": black},
            {"op": "text", "pos": [x1 + 1, y1 + 24], "text": "OC", "color": "#2a2d36", "spacing": 1},
            {"op": "pixels", "list": [[x1 + 16, y1 + 4 + k * 6, "#3cc8ff"] for k in range(5)]},
            {"op": "fill", "rect": U["hull_nose"], "color": black}, {"op": "edge", "rect": U["hull_nose"], "color": "#3cc8ff"},
            {"op": "fill", "rect": U["hull_tail"], "color": "#9da2ad"},
            {"op": "stripes", "rect": [18, 18, 30, 30], "colors": ["#16171c", "#5d626c"], "width": 1},
            {"op": "fill", "rect": U["arm"], "color": "#2a2c33"}, {"op": "fill", "rect": [64, 3, 96, 5], "color": "#ffc61a"},
            {"op": "fill", "rect": U["motor"], "color": "#3a3d46"}, {"op": "stripes", "rect": U["motor"], "colors": ["#3a3d46", "#1c1d22"], "width": 1},
            {"op": "fill", "rect": U["motor_top"], "color": "#55a9d6"}, ellipse(88, 12, 2, 2, "#d9f3ff"),
            {"op": "fill", "rect": U["blade"], "color": "#3b3e47"},
            {"op": "fill", "rect": [96, 0, 100, 8], "color": "#ff3c3c"}, {"op": "fill", "rect": [124, 0, 128, 8], "color": "#ff3c3c"},
            {"op": "fill", "rect": [96, 3, 128, 5], "color": "#5a5e69"}]
    # Water tank: bright (glows cyan in the game), with a level line and bubbles.
    x1, y1, x2, y2 = U["tank"]
    ops += [{"op": "fill", "rect": U["tank"], "color": "#f0f0f0"},
            {"op": "fill", "rect": [x1, y1, x2, y1 + 4], "color": "#8a8a8a"},
            {"op": "spots", "rect": [x1 + 1, y1 + 6, x2 - 1, y2 - 1], "color": "#ffffff", "count": 10, "size": 1.4},
            {"op": "stripes", "rect": [x1, y1 + 4, x2, y2], "colors": ["#00000000", "#00000000", "#00000000", "#b8b8b8"], "width": 2},
            {"op": "fill", "rect": U["tank_cap"], "color": "#9a9a9a"}, ellipse(40, 40, 4, 4, "#e6e6e6"),
            {"op": "fill", "rect": U["nozzle"], "color": "#303238"}, {"op": "fill", "rect": [48, 38, 64, 40], "color": "#3cc8ff"}]
    ops += visor_paint(U["eye"]) + police_light_paint(U["siren"])
    ops += [{"op": "fill", "rect": U["underside"], "color": "#24262d"}, {"op": "noise", "rect": U["underside"], "amount": 0.3, "spread": 0.15},
            rivets(U["underside"], every=6, color="#6d717c")]
    return ops


def drone_spec() -> dict:
    U = DRONE_UV
    els = []

    def hull_uv(band, seg):
        # (6 facets turned by 30 degrees: facet 1 faces up (+Y) and facet 4 faces down.)
        if seg == 1:
            return U["hull_top"]
        if seg == 4:
            return U["underside"]
        return None
    els.append(lathe("Hull", "Body", "z", [(-6.2, 1.8, 1.1, 0, 0.2), (-3.0, 4.0, 2.3, 0, 0.3), (3.2, 3.6, 2.1, 0, 0.4), (6.0, 2.0, 1.2, 0, 0.6)],
                     6, U["hull"], twist=0.0, cap_start=U["hull_nose"], cap_end=U["hull_tail"], face_uv=hull_uv))
    motors = [("Rotor1", -8.0, -8.0), ("Rotor2", 8.0, -8.0), ("Rotor3", -8.0, 8.0), ("Rotor4", 8.0, 8.0)]
    for i, (_, x, z) in enumerate(motors):
        els.append(bar("Arm%d" % (i + 1), "Arms", [x * 0.3, z * 0.3], [x, z], 1.1, 0.6, 1.4, U["arm"]))
        els.append(lathe("Motor%d" % (i + 1), "Arms", "y", [(0.2, 1.1, 1.1, x, z), (2.0, 1.1, 1.1, x, z)], 6, U["motor"], cap_end=U["motor_top"]))
    for name, x, z in motors:
        els.append(blade(name + "A", name, [x, 2.3, z], 20.0, 9.6, 1.1, U["blade"]))
        els.append(blade(name + "B", name, [x, 2.3, z], 110.0, 9.6, 1.1, U["blade"]))
    # Under-slung water tank + the spray nozzle pointing down and forward.
    els.append(lathe("WaterTank", "Tank", "y", [(-6.8, 2.2, 2.2, 0, 0.6), (-2.2, 2.6, 2.6, 0, 0.6), (-1.2, 2.0, 2.0, 0, 0.6)],
                     6, U["tank"], cap_start=U["tank_cap"]))
    els += tube("Spray", "Nozzle", [[0, -6.6, -0.6], [0, -7.8, -2.0], [0, -8.4, -3.4]], [0.9, 0.7, 0.45], U["nozzle"], cap_end=U["nozzle"])
    # The eye: a glowing lens on the nose.
    els.append(box("Lens", "Eye", [-2.3, -0.8, -6.7], [2.3, 1.2, -5.0], U["eye"]))
    for name, x in (("SirenRed", -1.4), ("SirenBlue", 1.4)):
        els.append(box(name + "Pod", name, [x - 0.9, 2.2, -0.6], [x + 0.9, 3.2, 1.2], U["siren"]))
    groups = [{"name": "Body", "origin": [0, 0, 0]}, {"name": "Arms", "origin": [0, 0, 0]},
              {"name": "Tank", "origin": [0, -4.0, 0.6]}, {"name": "Nozzle", "origin": [0, -6.6, -0.6]},
              {"name": "Eye", "origin": [0, 0.2, -5.85]},
              {"name": "SirenRed", "origin": [-1.4, 2.2, 0.3]}, {"name": "SirenBlue", "origin": [1.4, 2.2, 0.3]},
              {"name": "Rotors", "origin": [0, 0, 0]}]
    groups += [{"name": n, "origin": [x, 2.3, z], "parent": "Rotors"} for n, x, z in motors]
    return {"name": "squirt_drone", "kind": "character",
            "about": "SQUIRT-DRONE: angular OVERCLEAN quad-copter; origin = its middle (it hovers). Faces -Z. Groups the game "
                     "uses: Body (flashes), Tank (glowing water tank), Eye (glowing lens = crit WEAK SPOT), SirenRed, SirenBlue, "
                     "Rotors > Rotor1..Rotor4 (pivot = motor, each spun round Y). Made by tools/make_creature_specs.py.",
            "texture_size": 128, "seed": 5, "background": "#16171c",
            "paint": drone_paint(), "groups": groups, "elements": els}


SPECS = {"cat": cat_spec, "roomba": roomba_spec, "lint_trapper": trapper_spec, "squirt_drone": drone_spec}


def main() -> None:
    import sys
    wanted = sys.argv[1:] or list(SPECS)
    for name in wanted:
        spec = SPECS[name]()
        path = os.path.join(SPEC_DIR, name + ".json")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(spec, f, indent=1)
        print("wrote", os.path.relpath(path, os.path.dirname(HERE)))


if __name__ == "__main__":
    main()
