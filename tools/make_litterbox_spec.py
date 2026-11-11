"""Writes the model spec for THE LITTERBOX (the stash: scripts/hub.gd _build_stash), the giant
glowing litterbox on the east wall of each sewer where cats bury their gear to keep it safe:

    tools/model_specs/litterbox.json   -> models/litterbox.glb

Run it, then build the model:
    python tools/make_litterbox_spec.py
    python tools/cypurr_models.py all tools/model_specs/litterbox.json

Re-running REPLACES the .bbmodel (hand edits made in Blockbench are lost). 16 px = 1 m,
the FRONT (the side the cats walk up to) is -Z, Y up, the back (z = 0) goes flat against the wall.
Size = the old box-built tray: 4 m long (x -32..32), 2 m deep (z -32..0), rim 0.5 m high,
sand 0.35 m up (so the solid boxes hub.gd adds still match what you see).

The look: a big chunky plastic cat litterbox with a lip round the top and a dip in the front rim
(where you hop in), full of sand: lumpy mounds, clumps, a torn KITTY LITTER sack spilling in the
back corner, and the cats' BURIED LOOT poking out (a fish tail, a pistol grip, coins, a box corner).
The scoop leans on the front rim. The game adds the neon strip, the sign and the light (hub.gd).

COLOURS: the PLASTIC and the SAND are painted in GREYS on purpose: hub.gd tints them with
Hub > Stash > Litterbox Color and Sand Color (Inspector), so you can recolour them without
repainting. Everything else (loot, sack, scoop) keeps its painted colour.

Texture = 64x64, 16x16 swatches:
  row 0:  plastic (grey) | rim (darker grey) | sand (grey) | clumps (grey)
  row 1:  paw logo (grey) | "LITTER" logo (2 swatches wide) | fish scales
  row 2:  dark gun metal | gold coin | cardboard | KITTY LITTER sack label
  row 3:  scoop (cyan plastic) | sack paper | black | white
Groups: Tray (tinted Litterbox Color), Sand (tinted Sand Color), Loot, Scoop (glows a little).
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SPECS = os.path.join(HERE, "model_specs")


def sw(col, row, wide=1):
    """The UV rect of one 16x16 swatch (wide = how many swatches across)."""
    return [col * 16, row * 16, col * 16 + 16 * wide, row * 16 + 16]


PLASTIC, RIM, SAND, CLUMP = sw(0, 0), sw(1, 0), sw(2, 0), sw(3, 0)
PAW, LOGO, FISH = sw(0, 1), sw(1, 1, 2), sw(3, 1)
METAL, GOLD, CARD, LABEL = sw(0, 2), sw(1, 2), sw(2, 2), sw(3, 2)
SCOOP, PAPER, BLACK, WHITE = sw(0, 3), sw(1, 3), sw(2, 3), sw(3, 3)


def paint():
    ops = [{"op": "comment", "note": __doc__.split("Texture = ")[1].split("Groups:")[0].strip()}]

    def block(rect, top, bottom, noise=0.2, edge=None):
        ops.append({"op": "gradient", "rect": rect, "top": top, "bottom": bottom})
        if noise:
            ops.append({"op": "noise", "rect": rect, "amount": noise, "spread": 0.12})
        if edge:
            ops.append({"op": "edge", "rect": rect, "color": edge})

    # row 0 (greys: the game tints these)
    block(PLASTIC, "#f0f0f0", "#b8b8b8", 0.12)
    ops.append({"op": "line", "from": [0, 2], "to": [15, 2], "color": "#ffffff"})  # shiny moulded edge
    ops.append({"op": "line", "from": [0, 14], "to": [15, 14], "color": "#9a9a9a"})
    block(RIM, "#c8c8c8", "#8a8a8a", 0.1, "#707070")
    block(SAND, "#e8e8e8", "#c8c8c8", 0.6)            # gritty: lots of speckles
    ops.append({"op": "spots", "rect": SAND, "color": "#a8a8a8", "count": 5, "size": 1})
    block(CLUMP, "#9a9a9a", "#707070", 0.5, "#5a5a5a")
    # row 1
    block(PAW, "#f0f0f0", "#b8b8b8", 0.1)
    ops.append({"op": "fill", "rect": [4, 24, 12, 30], "color": "#6a6a6a"})  # pad
    for x, y in [(2, 20), (5, 18), (9, 18), (12, 20)]:  # toes
        ops.append({"op": "fill", "rect": [x, y, x + 2, y + 3], "color": "#6a6a6a"})
    block(LOGO, "#f0f0f0", "#b8b8b8", 0.1)
    ops.append({"op": "text", "text": "LITTER", "pos": [20, 21], "color": "#505050"})
    ops.append({"op": "line", "from": [18, 28], "to": [45, 28], "color": "#505050"})
    block(FISH, "#c8e0f0", "#5a7890", 0.15, "#2a3a48")  # silvery-blue fish scales
    for y in (19, 23, 27):
        for x in range(49, 63, 3):
            ops.append({"op": "pixels", "list": [[x, y, "#e8f6ff"]]})
    # row 2
    block(METAL, "#3a3e46", "#1e2026", 0.15, "#0e1014")
    for y in range(35, 46, 2):  # grip ridges
        ops.append({"op": "line", "from": [3, y], "to": [12, y], "color": "#14161a"})
    block(GOLD, "#ffe070", "#c08a20", 0.15, "#7a5410")
    ops.append({"op": "text", "text": "$", "pos": [23, 37], "color": "#8a6010"})
    block(CARD, "#b08858", "#86643c", 0.25, "#4a3420")
    ops.append({"op": "line", "from": [32, 40], "to": [47, 40], "color": "#d8c090"})  # tape
    ops.append({"op": "fill", "rect": LABEL, "color": "#e04a8a"})  # the sack's pink label
    ops.append({"op": "text", "text": "KIT", "pos": [50, 34], "color": "#ffffff"})
    ops.append({"op": "text", "text": "TY", "pos": [52, 40], "color": "#ffffff"})
    ops.append({"op": "fill", "rect": [49, 46, 63, 48], "color": "#ffd23a"})
    # row 3
    block(SCOOP, "#7af0ff", "#1aa8c8", 0.08)
    for x in range(3, 14, 3):  # the sifting slots
        ops.append({"op": "line", "from": [x, 51], "to": [x, 61], "color": "#0a5a70"})
    block(PAPER, "#d8c8a8", "#a89878", 0.3, "#6a5a40")
    ops.append({"op": "fill", "rect": BLACK, "color": "#121216"})
    ops.append({"op": "fill", "rect": WHITE, "color": "#f8f8f8"})
    return ops


def box(name, frm, to, uv, group="Tray", top=None, **extra):
    """A box with no underside (it sits on something): fewer triangles."""
    e = {"type": "cube", "name": name, "group": group, "from": frm, "to": to, "sides": uv, "top": top or uv}
    e.update(extra)
    return e


def front_panel(name, frm, to, uv, group="Tray"):
    """Only a front face (a sticker / logo flat on something)."""
    return {"type": "cube", "name": name, "group": group, "from": frm, "to": to, "faces": {"north": uv}}


def can(name, center, height, rb, rt, uv_side, uv_top, sides=6, group="Sand", **extra):
    """A prism standing on "center" (its bottom middle): radius rb at the bottom, rt at the top."""
    e = {"type": "prism", "name": name, "group": group, "sides": sides, "center": center, "height": height,
         "radius_bottom": rb, "radius_top": rt, "side_uv": uv_side, "top_uv": uv_top}
    e.update(extra)
    return e


SAND_TOP = 5.6  # 0.35 m

elements = [
    # --- THE TRAY: back, two ends, and a front with a dip in the middle where cats hop in ---
    box("back", [-32, 0, -2], [32, 8, 0], PLASTIC, top=RIM),
    box("end_left", [-32, 0, -30], [-30, 8, -2], PLASTIC, top=RIM),
    box("end_right", [30, 0, -30], [32, 8, -2], PLASTIC, top=RIM),
    box("front_left", [-32, 0, -32], [-10, 8, -30], PLASTIC, top=RIM),
    box("front_right", [10, 0, -32], [32, 8, -30], PLASTIC, top=RIM),
    box("front_dip", [-10, 0, -32], [10, 6.5, -30], PLASTIC, top=RIM),
    # The moulded lip round the top of the front (sticks out a bit, darker), and a foot strip.
    box("lip_left", [-32.6, 7, -32.6], [-10, 8.6, -30], RIM),
    box("lip_right", [10, 7, -32.6], [32.6, 8.6, -30], RIM),
    box("lip_dip", [-10, 5.5, -32.6], [10, 7.1, -30], RIM),
    box("lip_end_left", [-32.6, 7, -30], [-30, 8.6, -1], RIM),
    box("lip_end_right", [30, 7, -30], [32.6, 8.6, -1], RIM),
    box("foot", [-32.4, 0, -32.4], [32.4, 1, -31.9], RIM),
    # Logos moulded into the front: a paw on the left, LITTER on the right.
    front_panel("paw_logo", [-26, 1.5, -32.05], [-18, 6.5, -32], PAW),
    front_panel("litter_logo", [15, 1.5, -32.05], [29, 5.5, -32], LOGO),

    # --- THE SAND: a flat top (its sides hide inside the tray), mounds and clumps on it ---
    {"type": "cube", "name": "sand", "group": "Sand", "from": [-30, 0, -30], "to": [30, SAND_TOP, -2],
     "faces": {"up": SAND}},
    can("mound_big", [-16, SAND_TOP, -12], 3.2, 9, 3.5, SAND, SAND),
    can("mound_mid", [-2, SAND_TOP, -9], 1.6, 6, 2.5, SAND, SAND),
    can("mound_small", [19, SAND_TOP, -21], 1.0, 4, 1.8, SAND, SAND, sides=5),
    box("clump_1", [5, SAND_TOP, -23], [7, SAND_TOP + 1.2, -21], CLUMP, group="Sand"),
    box("clump_2", [9, SAND_TOP, -18], [10.5, SAND_TOP + 1, -16.5], CLUMP, group="Sand"),
    box("clump_3", [-25, SAND_TOP, -25], [-23, SAND_TOP + 1, -23], CLUMP, group="Sand"),
    box("clump_4", [23, SAND_TOP, -9], [25, SAND_TOP + 1.2, -7], CLUMP, group="Sand"),

    # --- BURIED LOOT poking out of the sand ---
    # A fish: the back half sticks out, tail fin up.
    box("fish_body", [5, 4.5, -13], [11, 7.5, -11], FISH, group="Loot",
        rotation=[0, 0, 18], origin=[8, 6, -12]),
    {"type": "cube", "name": "fish_tail", "group": "Loot", "from": [10.5, 6.5, -14], "to": [11.3, 10.5, -10],
     "sides": FISH, "top": FISH, "rotation": [0, 0, -15], "origin": [11, 7, -12]},
    # A pistol grip sticking up (the rest is buried).
    box("pistol_grip", [20, 4, -14], [22, 9.5, -12.5], METAL, group="Loot",
        rotation=[12, 0, -8], origin=[21, 5, -13]),
    box("pistol_slide", [19.5, 9, -16], [22.5, 10.5, -12.2], METAL, group="Loot",
        rotation=[12, 0, -8], origin=[21, 5, -13]),
    # Gold coins lying about.
    can("coin_1", [-6, SAND_TOP, -22], 0.5, 1.6, 1.6, GOLD, GOLD, sides=6, group="Loot"),
    can("coin_2", [-3, SAND_TOP, -24], 0.5, 1.6, 1.6, GOLD, GOLD, sides=6, group="Loot"),
    can("coin_3", [-4.5, SAND_TOP + 0.5, -23], 0.5, 1.6, 1.6, GOLD, GOLD, sides=6, group="Loot"),
    # The corner of a buried cardboard box.
    box("box_corner", [-26, 3.5, -27], [-20, 8.5, -21], CARD, group="Loot",
        rotation=[0, 25, 10], origin=[-23, 4, -24]),
    # A torn KITTY LITTER sack slumped in the back corner, on the big mound.
    {"type": "cube", "name": "sack", "group": "Loot", "from": [-29, SAND_TOP, -9], "to": [-21, 17, -3],
     "faces": {"north": LABEL, "east": PAPER, "west": PAPER, "south": PAPER, "up": PAPER},
     "rotation": [0, 0, -14], "origin": [-25, SAND_TOP, -6]},

    # --- THE SCOOP: head on the sand at the front, handle leaning up over the front rim ---
    box("scoop_head", [14, SAND_TOP, -28], [21, SAND_TOP + 0.6, -23], SCOOP, group="Scoop"),
    box("scoop_rim", [14, SAND_TOP, -23.6], [21, SAND_TOP + 1.6, -23], SCOOP, group="Scoop"),
    box("scoop_handle", [16.7, SAND_TOP, -40], [18.3, SAND_TOP + 1.2, -28], SCOOP, group="Scoop",
        rotation=[30, 0, 0], origin=[17.5, SAND_TOP + 0.6, -28]),  # (positive = the far end lifts)
]

litterbox = {
    "name": "litterbox", "kind": "set_piece", "texture_size": 64, "seed": 2468, "background": "#202228",
    "about": "THE LITTERBOX (the stash, built by hub.gd _build_stash): a giant cat litterbox full of sand and buried "
             "loot. Front = -Z, back (z 0) on the wall. Groups: Tray + Sand (painted grey: the game tints them), "
             "Loot, Scoop (glows a little).",
    "paint": paint(),
    "groups": [{"name": "Tray"}, {"name": "Sand"}, {"name": "Loot"}, {"name": "Scoop"}],
    "elements": elements,
}

if __name__ == "__main__":
    path = os.path.join(SPECS, "litterbox.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(litterbox, f, indent=1)
    print("wrote", path)
