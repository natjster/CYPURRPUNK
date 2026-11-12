"""Writes the model specs for the SEWER REBELLION recruits' OWN THINGS (scripts/recruit_home.gd).
Every recruit moves in WITH something that is theirs, so recruiting fills out the sewer. The
CATLEONE family so far:

    tools/model_specs/mittens_box.json      -> LIL' MITTENS: her cardboard box home (blanket, fairy lights, food bowl)
    tools/model_specs/paulie_scrapheap.json -> PAULIE "NO-BROOMS": his collections drum of smashed VAC-COPs + a NO BROOMS sign
    tools/model_specs/sal_heavy_bag.json    -> SAL "THE SLAPPER": a heavy punching bag (with a Roomba face taped on), tyre, dumbbell
    tools/model_specs/nonna_kitchen.json    -> NONNA CATLEONE: her stove, the pot of Sunday Gravy, a checked-cloth table
    tools/model_specs/frankie_garage.json   -> FRANKIE "ESPRESSO": the garage bay where the gang's chosen ride is parked

Run it, then build each model:
    python tools/make_recruit_home_specs.py
    python tools/cypurr_models.py all tools/model_specs/mittens_box.json   (same for the other four)

Re-running REPLACES the .bbmodel files (hand edits made in Blockbench are lost), like
tools/make_upgrade_specs.py. 16 px = 1 m, forward (the side that faces the room) = -Z, Y up.
Group names the game looks for (scripts/recruit_home.gd): Glow / Lamp / Burner (lit up), Trim
(glows in the gang colour), Sign (a soft glow), Swing (sways gently, e.g. the punching bag).

All five share one 64x64 texture of 16x16 swatches:
  row 0:  cardboard | cardboard inside | plaid blanket | corrugated tin
  row 1:  dark metal | rust | wood | black (a dead red Roomba eye in the middle)
  row 2:  warm glow | TRIM (white: tinted the gang colour) | gravy | checked tablecloth
  row 3:  punching-bag leather (taped X + Roomba eye) | hazard stripes | chrome with a window | NO BROOMS sign
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SPECS = os.path.join(HERE, "model_specs")


def sw(col, row, inset=0):
    """The UV rect of one 16x16 swatch."""
    return [col * 16 + inset, row * 16 + inset, col * 16 + 16 - inset, row * 16 + 16 - inset]


CARD, CARD_IN, BLANKET, TIN = sw(0, 0), sw(1, 0), sw(2, 0), sw(3, 0)
DARK, RUST, WOOD, BLACK = sw(0, 1), sw(1, 1), sw(2, 1), sw(3, 1)
GLOW, TRIM, GRAVY, CHECK = sw(0, 2), sw(1, 2), sw(2, 2), sw(3, 2)
LEATHER, HAZARD, CHROME, NOBROOM = sw(0, 3), sw(1, 3), sw(2, 3), sw(3, 3)


def paint():
    ops = [{"op": "comment", "note": __doc__.split("All five share")[1].strip()}]

    def block(rect, top, bottom, noise=0.2, edge="#111318"):
        ops.append({"op": "gradient", "rect": rect, "top": top, "bottom": bottom})
        if noise:
            ops.append({"op": "noise", "rect": rect, "amount": noise, "spread": 0.12})
        if edge:
            ops.append({"op": "edge", "rect": rect, "color": edge})

    # Row 0
    block(CARD, "#b88a55", "#94683c", 0.3, "#5a3e20")
    ops.append({"op": "fill", "rect": [6, 0, 10, 16], "color": "#d8c08a"})  # packing tape
    ops.append({"op": "text", "pos": [1, 9], "text": "MEOW", "color": "#3a2412c0", "worn": 0.15})
    block(CARD_IN, "#6e4c2a", "#4a3018", 0.3, "#2e1c0c")
    ops.append({"op": "fill", "rect": BLANKET, "color": "#b02a30"})
    ops.append({"op": "stripes", "rect": BLANKET, "colors": ["#00000000", "#f0dcb000", "#f0dcb0a0", "#00000000"], "width": 1, "direction": "horizontal"})
    ops.append({"op": "stripes", "rect": BLANKET, "colors": ["#00000000", "#30101060", "#00000000", "#f0dcb080"], "width": 1})
    ops.append({"op": "noise", "rect": BLANKET, "amount": 0.15, "spread": 0.08})
    ops.append({"op": "stripes", "rect": TIN, "colors": ["#9aa2ac", "#6a727c"], "width": 2, "direction": "horizontal"})
    ops.append({"op": "spots", "rect": TIN, "color": "#7a4a28a0", "count": 4, "size": 1})
    ops.append({"op": "edge", "rect": TIN, "color": "#3a404a"})
    # Row 1
    block(DARK, "#4a505a", "#2c3038")
    for x, y in [(2, 18), (13, 18), (2, 29), (13, 29)]:
        ops.append({"op": "pixels", "list": [[x, y, "#9aa3b0"]]})
    block(RUST, "#8a5530", "#5a3018", 0.4, "#2a1408")
    ops.append({"op": "spots", "rect": RUST, "color": "#a86a38", "count": 6, "size": 1})
    block(WOOD, "#7a5530", "#4e3420", 0.35, "#2a1a10")
    ops.append({"op": "line", "from": [32, 21], "to": [47, 21], "color": "#3d2817"})
    ops.append({"op": "line", "from": [32, 26], "to": [47, 26], "color": "#3d2817"})
    ops.append({"op": "fill", "rect": BLACK, "color": "#141418"})
    ops.append({"op": "noise", "rect": BLACK, "amount": 0.1, "spread": 0.05})
    ops.append({"op": "fill", "rect": [55, 23, 57, 25], "color": "#a01818"})  # a dead Roomba eye
    # Row 2
    ops.append({"op": "fill", "rect": GLOW, "color": "#ffcc66"})
    ops.append({"op": "fill", "rect": [4, 36, 12, 44], "color": "#fff0b8"})
    ops.append({"op": "pixels", "list": [[2, 34, "#ff5a5a"], [7, 33, "#5aff8a"], [13, 34, "#5ac8ff"], [3, 45, "#ff5aff"], [12, 46, "#ffffff"]]})
    ops.append({"op": "fill", "rect": TRIM, "color": "#f4f4f4"})
    ops.append({"op": "stripes", "rect": TRIM, "colors": ["#ffffff", "#d8d8d8"], "width": 2, "direction": "horizontal"})
    block(GRAVY, "#c02818", "#801408", 0.25, None)
    ops.append({"op": "spots", "rect": GRAVY, "color": "#e86040", "count": 7, "size": 1.5})
    ops.append({"op": "pixels", "list": [[38, 38, "#5a2a10"], [42, 43, "#5a2a10"], [36, 44, "#5a2a10"]]})  # meatballs
    for cy in range(4):
        for cx in range(4):
            if (cx + cy) % 2 == 0:
                ops.append({"op": "fill", "rect": [48 + cx * 4, 32 + cy * 4, 52 + cx * 4, 36 + cy * 4], "color": "#c8202a"})
            else:
                ops.append({"op": "fill", "rect": [48 + cx * 4, 32 + cy * 4, 52 + cx * 4, 36 + cy * 4], "color": "#f2ecdc"})
    ops.append({"op": "noise", "rect": CHECK, "amount": 0.1, "spread": 0.05})
    # Row 3
    block(LEATHER, "#a0282a", "#6a1416", 0.25, "#3a0a0a")
    ops.append({"op": "line", "from": [3, 51], "to": [12, 60], "color": "#b8b8b0"})  # duct tape X
    ops.append({"op": "line", "from": [4, 51], "to": [13, 60], "color": "#b8b8b0"})
    ops.append({"op": "line", "from": [12, 51], "to": [3, 60], "color": "#b8b8b0"})
    ops.append({"op": "line", "from": [13, 51], "to": [4, 60], "color": "#b8b8b0"})
    ops.append({"op": "fill", "rect": [7, 54, 9, 56], "color": "#ff2a2a"})  # the taped-on Roomba eye
    ops.append({"op": "fill", "rect": HAZARD, "color": "#f0c020"})
    # Black diagonal bands, pixel by pixel so they stay inside the swatch.
    ops.append({"op": "pixels", "list": [[x, y, "#18181c"] for x in range(16, 32) for y in range(48, 64) if (x + y) % 6 < 3]})
    ops.append({"op": "edge", "rect": HAZARD, "color": "#18181c"})
    block(CHROME, "#d8dee6", "#8a929c", 0.1, "#4a525c")
    ops.append({"op": "fill", "rect": [35, 52, 45, 60], "color": "#1a1210"})
    ops.append({"op": "fill", "rect": [37, 55, 43, 59], "color": "#c86a20"})  # warm light in the window
    ops.append({"op": "line", "from": [35, 50], "to": [45, 50], "color": "#4a525c"})  # handle
    ops.append({"op": "fill", "rect": NOBROOM, "color": "#f2ecdc"})
    ops.append({"op": "edge", "rect": NOBROOM, "color": "#c81818"})
    ops.append({"op": "edge", "rect": [49, 49, 63, 63], "color": "#c81818"})
    ops.append({"op": "line", "from": [53, 61], "to": [58, 51], "color": "#7a5530"})  # a broom...
    ops.append({"op": "fill", "rect": [51, 59, 55, 62], "color": "#d8b860"})
    ops.append({"op": "line", "from": [50, 50], "to": [61, 61], "color": "#c81818"})  # ...crossed out
    ops.append({"op": "line", "from": [51, 50], "to": [62, 61], "color": "#c81818"})
    return ops


def cube(name, group, frm, to, uv=None, **extra):
    e = {"type": "cube", "name": name, "group": group, "from": frm, "to": to}
    if uv is not None:
        e["all"] = uv
    e.update(extra)
    return e


def can(name, group, center, radius, height, side, top=None, bottom=None, sides=8, **extra):
    e = {"type": "prism", "name": name, "group": group, "sides": sides, "center": center,
         "height": height, "radius": radius, "side_uv": side}
    if top:
        e["top_uv"] = top
    if bottom:
        e["bottom_uv"] = bottom
    e.update(extra)
    return e


def spec(name, about, groups, elements, kind="set_piece", seed=31):
    return {"name": name, "kind": kind, "texture_size": 64, "seed": seed, "background": "#2a2d33",
            "about": about, "paint": paint(), "groups": [{"name": "Body"}] + groups, "elements": elements}


# ---------------------------------------------------------------------------------------
# LIL' MITTENS: her cardboard box, on its side, opening facing the room. 1.25 m wide.
# ---------------------------------------------------------------------------------------
mittens_box = spec("mittens_box",
    "SEWER REBELLION: LIL' MITTENS' cardboard box home (scripts/recruit_home.gd). Front (the open side) = -Z. "
    "Groups: Body, Glow (fairy lights).",
    [{"name": "Glow"}],
    [
        cube("floor", "Body", [-10, 0, -8], [10, 1, 8], faces={"up": CARD_IN, "north": CARD}),
        cube("roof", "Body", [-10, 13, -8], [10, 14, 8], faces={"up": CARD, "down": CARD_IN, "north": CARD, "east": CARD, "west": CARD}),
        cube("wallL", "Body", [-10, 1, -8], [-9, 13, 8], faces={"west": CARD, "east": CARD_IN, "north": CARD}),
        cube("wallR", "Body", [9, 1, -8], [10, 13, 8], faces={"east": CARD, "west": CARD_IN, "north": CARD}),
        cube("back", "Body", [-9, 1, 7], [9, 13, 8], faces={"north": CARD_IN, "south": CARD}),
        # The flaps hang open either side of the doorway, and one sticks up off the roof.
        cube("flapL", "Body", [-10, 1, -14], [-9.5, 13, -8], faces={"west": CARD, "east": CARD_IN, "north": CARD},
             origin=[-10, 1, -8], rotation=[0, 35, 0]),
        cube("flapR", "Body", [9.5, 1, -14], [10, 13, -8], faces={"east": CARD, "west": CARD_IN, "north": CARD},
             origin=[10, 1, -8], rotation=[0, -35, 0]),
        cube("flapTop", "Body", [-10, 14, -8.5], [10, 20, -8], faces={"north": CARD, "south": CARD_IN, "up": CARD},
             origin=[0, 14, -8], rotation=[-25, 0, 0]),
        cube("blanket", "Body", [-8, 1, -6], [8, 2.5, 6], faces={"up": BLANKET, "north": BLANKET, "east": BLANKET, "west": BLANKET}),
        cube("pillow", "Body", [-7, 2.5, 2], [-1, 5, 6], faces={"up": BLANKET, "north": BLANKET, "east": BLANKET, "west": BLANKET}),
        can("bowl", "Body", [5, 0, -12], 2, 1.2, TIN, top=GRAVY, sides=6),
        cube("lights", "Glow", [-9, 12, -7.6], [9, 12.6, -7.1], GLOW),
    ], kind="prop", seed=41)

# ---------------------------------------------------------------------------------------
# PAULIE "NO-BROOMS": the collections drum, full of the VAC-COPs he's "collected", a pile of
# flattened Roomba shells, a snapped broom and his NO BROOMS sign on a post.
# ---------------------------------------------------------------------------------------
paulie_scrapheap = spec("paulie_scrapheap",
    "SEWER REBELLION: PAULIE NO-BROOMS' scrap drum, squashed Roombas, snapped broom + NO BROOMS sign "
    "(scripts/recruit_home.gd). Front = -Z. Groups: Body, Sign (soft glow), Glow (the busted eye).",
    [{"name": "Sign"}, {"name": "Glow"}],
    [
        can("drum", "Body", [-8, 0, 0], 4, 14, RUST, top=BLACK),
        cube("junk1", "Body", [-10, 12, -1], [-7, 17, 1], DARK, rotation=[0, 0, 20]),
        cube("junk2", "Body", [-8, 12, 0], [-6, 16, 3], TIN, rotation=[15, 0, -12]),
        can("hose", "Body", [-9, 11, -2], 0.8, 7, DARK, sides=5, origin=[-9, 11, -2], rotation=[35, 0, 10]),
        can("roomba1", "Body", [4, 0, 1], 4.5, 1.5, DARK, top=BLACK),
        can("roomba2", "Body", [5, 1.5, 0], 4.5, 1.5, DARK, top=BLACK, origin=[5, 1.5, 0], rotation=[0, 0, 12]),
        can("roomba3", "Body", [3, 3.4, 2], 4.5, 1.5, DARK, top=BLACK, origin=[3, 3.4, 2], rotation=[-10, 30, -6]),
        cube("eye", "Glow", [2.5, 5.0, 1.5], [3.5, 5.3, 2.5], GLOW),  # one Roomba still blinking, just about
        cube("broom_handle", "Body", [8, 0, -5], [9, 1, 6], WOOD),
        cube("broom_head", "Body", [6, 0, 6], [11, 2.5, 9], faces={"up": CARD, "north": CARD, "south": CARD, "east": CARD, "west": CARD}),
        cube("broom_snapped", "Body", [11, 0, -9], [12, 1, -3], WOOD, origin=[11.5, 0.5, -6], rotation=[0, -35, 0]),
        cube("post", "Body", [14, 0, 4], [15, 22, 5], WOOD),
        cube("plaque", "Sign", [10, 15, 3.4], [19, 24, 4], faces={"north": NOBROOM, "south": WOOD, "up": WOOD, "east": WOOD, "west": WOOD}),
    ], seed=42)

# ---------------------------------------------------------------------------------------
# SAL "THE SLAPPER": a heavy bag hanging off a frame (a Roomba face taped on it), a tyre and a
# dumbbell on the floor. The bag sways (group Swing, pivot at the top of the chain).
# ---------------------------------------------------------------------------------------
sal_heavy_bag = spec("sal_heavy_bag",
    "SEWER REBELLION: SAL THE SLAPPER's punching bag on a frame, tyre + dumbbell (scripts/recruit_home.gd). "
    "Front = -Z. Groups: Body, Swing (the bag + chain: the game sways it from the top).",
    [{"name": "Swing", "origin": [0, 30, 0]}],
    [
        cube("postL", "Body", [-12, 0, -1], [-10, 30, 1], DARK),
        cube("postR", "Body", [10, 0, -1], [12, 30, 1], DARK),
        cube("beam", "Body", [-12, 30, -1], [12, 32, 1], DARK),
        cube("footL", "Body", [-13, 0, -4], [-9, 1, 4], DARK),
        cube("footR", "Body", [9, 0, -4], [13, 1, 4], DARK),
        cube("chain", "Swing", [-0.3, 24, -0.3], [0.3, 30, 0.3], TIN),
        can("bag", "Swing", [0, 8, 0], 3.5, 16, LEATHER, top=DARK, bottom=DARK),
        can("tyre", "Body", [-6, 0, -9], 4, 2.5, BLACK, top=BLACK),
        cube("bar", "Body", [4, 1, -9], [10, 1.6, -8.4], TIN),
        cube("weightL", "Body", [3, 0, -10], [4.5, 2.6, -7.4], BLACK),
        cube("weightR", "Body", [9.5, 0, -10], [11, 2.6, -7.4], BLACK),
    ], seed=43)

# ---------------------------------------------------------------------------------------
# NONNA CATLEONE: an old stove with the pot of Sunday Gravy on, a table with a checked cloth,
# a stool and a candle in a bottle. 2.1 m long (X); the back (+Z) goes against the wall.
# ---------------------------------------------------------------------------------------
nonna_kitchen = spec("nonna_kitchen",
    "SEWER REBELLION: NONNA CATLEONE's kitchen: stove, pot of Sunday Gravy, checked-cloth table "
    "(scripts/recruit_home.gd). Front = -Z, back against the wall. Groups: Body, Burner (lit: rings + candle).",
    [{"name": "Burner"}],
    [
        cube("stove", "Body", [-16, 0, -5], [-1, 15, 6], faces={"north": CHROME, "east": TIN, "west": TIN, "up": BLACK}),
        cube("backsplash", "Body", [-16, 15, 5], [-1, 22, 6], faces={"north": TIN, "up": TIN}),
        cube("knobs", "Body", [-15, 13, -5.5], [-2, 14, -5], BLACK),
        cube("ring1", "Burner", [-14, 15, -3], [-10, 15.4, 1], faces={"up": GLOW}),
        cube("ring2", "Burner", [-7, 15, -3], [-3, 15.4, 1], faces={"up": GLOW}),
        can("pot", "Body", [-12, 15.4, -1], 3.2, 5, RUST, top=GRAVY),
        cube("spoon", "Body", [-11, 18, -1], [-10.4, 26, -0.4], WOOD, origin=[-11, 18, -1], rotation=[0, 0, -20]),
        can("pan", "Body", [-5, 15.4, -1], 2.2, 1.5, BLACK, top=GRAVY, sides=6),
        cube("cloth", "Body", [2, 8, -7], [20, 12, 5], CHECK),
        cube("legA", "Body", [3, 0, -6], [4, 8, -5], WOOD),
        cube("legB", "Body", [18, 0, -6], [19, 8, -5], WOOD),
        cube("legC", "Body", [3, 0, 3], [4, 8, 4], WOOD),
        cube("legD", "Body", [18, 0, 3], [19, 8, 4], WOOD),
        can("plate", "Body", [9, 12, -2], 2.4, 0.4, TIN, top=GRAVY),
        can("bottle", "Body", [15, 12, 1], 0.9, 4, BLACK, sides=6, top=BLACK),
        cube("candle", "Burner", [14.6, 16, 0.6], [15.4, 17.4, 1.4], GLOW),
        cube("stool", "Body", [8, 0, -14], [13, 6, -9], faces={"up": WOOD, "north": WOOD, "east": WOOD, "west": WOOD, "south": WOOD}),
    ], seed=44)

# ---------------------------------------------------------------------------------------
# FRANKIE "ESPRESSO": a garage bay 5.25 m wide (X) and 3 m deep, open to the room (-Z). The
# gang's chosen ride is parked inside by the game (recruit_home.gd show_ride), nose to -X.
# Outside the bay: his tool chest with the espresso machine on it, and a stack of tyres.
# ---------------------------------------------------------------------------------------
frankie_garage = spec("frankie_garage",
    "SEWER REBELLION: FRANKIE ESPRESSO's garage bay; the game parks the gang's chosen ride inside "
    "(scripts/recruit_home.gd). Front (open) = -Z. Groups: Body, Trim (gang colour neon), Lamp (ceiling light), "
    "Glow (espresso machine light).",
    [{"name": "Trim"}, {"name": "Lamp"}, {"name": "Glow"}],
    [
        cube("pad", "Body", [-42, 0, -21], [42, 1.0, 22], faces={"up": DARK}),  # 6 cm thick: thinner z-fought (flickered) with the hub floor
        cube("stripe", "Body", [-42, 0, -24], [42, 1.2, -21], faces={"up": HAZARD, "north": HAZARD}),
        cube("door", "Body", [-39, 0, 22], [39, 40, 24], faces={"north": TIN}),
        cube("wallL", "Body", [-42, 0, -24], [-39, 40, 24], faces={"east": DARK, "west": DARK, "north": HAZARD}),
        cube("wallR", "Body", [39, 0, -24], [42, 40, 24], faces={"east": DARK, "west": DARK, "north": HAZARD}),
        cube("roof", "Body", [-42, 40, -24], [42, 42, 24], faces={"up": DARK, "down": DARK, "north": DARK}),
        cube("trim", "Trim", [-42, 42, -24.5], [42, 43.5, -23.5], faces={"north": TRIM, "up": TRIM}),
        cube("light", "Lamp", [-8, 39.4, -4], [8, 40, 4], faces={"down": GLOW}),
        cube("chest", "Body", [-54, 0, 8], [-44, 14, 20], faces={"north": RUST, "east": RUST, "west": RUST, "up": DARK}),
        cube("drawers", "Body", [-53, 4, 7.6], [-45, 4.6, 8], BLACK),
        cube("espresso", "Body", [-52, 14, 10], [-46, 21, 16], faces={"north": CHROME, "east": CHROME, "west": CHROME, "up": DARK}),
        cube("spout", "Body", [-50, 16, 9], [-48, 18, 10], BLACK),
        cube("cup", "Glow", [-49.8, 14, 8], [-48.2, 15.4, 9.6], GLOW),
        can("tyre1", "Body", [49, 0, 14], 5, 3, BLACK, top=BLACK),
        can("tyre2", "Body", [49, 3, 14], 5, 3, BLACK, top=BLACK, twist=10),
        can("tyre3", "Body", [48, 6, 13], 5, 3, BLACK, top=BLACK, origin=[48, 6, 13], rotation=[8, 0, 6]),
    ], seed=45)


if __name__ == "__main__":
    for s in (mittens_box, paulie_scrapheap, sal_heavy_bag, nonna_kitchen, frankie_garage):
        path = os.path.join(SPECS, s["name"] + ".json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(s, f, indent=1)
        print("wrote", path)
