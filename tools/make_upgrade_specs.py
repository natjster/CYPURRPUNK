"""Writes the model specs for SEWER UPGRADES (scripts/upgrades.gd):

    tools/model_specs/workbench.json   -> the TINKER WORKBENCH in both sewers (hub.gd)
    tools/model_specs/cyber_bike.json  -> the NEON ZOOM-BIKE   (getaway_car.gd VEHICLES)
    tools/model_specs/fish_van.json    -> the ARMORED MEOW-VAN (getaway_car.gd VEHICLES)

Run it, then build each model:
    python tools/make_upgrade_specs.py
    python tools/cypurr_models.py all tools/model_specs/workbench.json   (same for the other two)

Re-running REPLACES the .bbmodel files (hand edits made in Blockbench are lost), like
tools/make_creature_specs.py. 16 px = 1 m, forward = -Z, Y up.

All three share one 64x64 texture layout of 16x16 swatches:
  row 0:  wood | dark metal | light metal | rust
  row 1:  TRIM (near white: the game tints it the gang colour) | glass | headlight | taillight
  row 2:  tyre | rim | lamp glow | fish sign
  row 3:  body paint | seat cloth | copper | black
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SPECS = os.path.join(HERE, "model_specs")


def sw(col, row, inset=0):
    """The UV rect of one 16x16 swatch."""
    return [col * 16 + inset, row * 16 + inset, col * 16 + 16 - inset, row * 16 + 16 - inset]


WOOD, DARK, LIGHT, RUST = sw(0, 0), sw(1, 0), sw(2, 0), sw(3, 0)
TRIM, GLASS, HEAD, TAIL = sw(0, 1), sw(1, 1), sw(2, 1), sw(3, 1)
TYRE, RIM, LAMP, SIGN = sw(0, 2), sw(1, 2), sw(2, 2), sw(3, 2)
BODY, CLOTH, COPPER, BLACK = sw(0, 3), sw(1, 3), sw(2, 3), sw(3, 3)


def paint(body_top, body_bottom):
    """The shared texture, with this model's body paint."""
    ops = [{"op": "comment", "note": __doc__.split("All three share")[1].strip()}]

    def block(rect, top, bottom, noise=0.2, edge="#111318"):
        ops.append({"op": "gradient", "rect": rect, "top": top, "bottom": bottom})
        if noise:
            ops.append({"op": "noise", "rect": rect, "amount": noise, "spread": 0.12})
        if edge:
            ops.append({"op": "edge", "rect": rect, "color": edge})

    block(WOOD, "#7a5530", "#4e3420", 0.35, "#2a1a10")
    ops.append({"op": "line", "from": [0, 5], "to": [15, 5], "color": "#3d2817"})
    ops.append({"op": "line", "from": [0, 10], "to": [15, 10], "color": "#3d2817"})
    block(DARK, "#4a505a", "#2c3038")
    for x, y in [(18, 2), (29, 2), (18, 13), (29, 13)]:  # rivets
        ops.append({"op": "pixels", "list": [[x, y, "#9aa3b0"]]})
    block(LIGHT, "#a8b0bc", "#6c7480", 0.2, "#3a404a")
    block(RUST, "#8a5530", "#5a3018", 0.4, "#2a1408")
    ops.append({"op": "spots", "rect": RUST, "color": "#a86a38", "count": 6, "size": 1})
    ops.append({"op": "fill", "rect": TRIM, "color": "#f4f4f4"})
    ops.append({"op": "stripes", "rect": [0, 16, 16, 32], "colors": ["#ffffff", "#d8d8d8"], "width": 2, "direction": "horizontal"})
    block(GLASS, "#3a6a78", "#0e1e26", 0.05, "#0a1014")
    ops.append({"op": "line", "from": [18, 18], "to": [22, 22], "color": "#8ad8e8"})
    ops.append({"op": "fill", "rect": HEAD, "color": "#fff6c8"})
    ops.append({"op": "edge", "rect": HEAD, "color": "#c8b878"})
    ops.append({"op": "fill", "rect": TAIL, "color": "#ff3a3a"})
    ops.append({"op": "edge", "rect": TAIL, "color": "#a01818"})
    ops.append({"op": "stripes", "rect": TYRE, "colors": ["#1a1a1e", "#2a2a30"], "width": 2})
    block(RIM, "#3a3f48", "#22252c", 0.1, "#101216")
    ops.append({"op": "edge", "rect": [20, 36, 28, 44], "color": "#8a93a3"})
    ops.append({"op": "fill", "rect": LAMP, "color": "#ffd27a"})
    ops.append({"op": "fill", "rect": [36, 36, 44, 44], "color": "#fff2c0"})
    # The fish sign: a glowing fish on a cyan board.
    ops.append({"op": "fill", "rect": SIGN, "color": "#1ad8ff"})
    ops.append({"op": "fill", "rect": [51, 37, 59, 43], "color": "#fff8e0"})
    ops.append({"op": "pixels", "list": [[59, 38, "#fff8e0"], [60, 37, "#fff8e0"], [60, 39, "#fff8e0"], [60, 40, "#fff8e0"],
                                         [59, 41, "#fff8e0"], [60, 42, "#fff8e0"], [61, 36, "#fff8e0"], [61, 43, "#fff8e0"], [53, 39, "#101014"]]})
    ops.append({"op": "edge", "rect": SIGN, "color": "#0a4a60"})
    block(BODY, body_top, body_bottom, 0.2, "#111318")
    ops.append({"op": "line", "from": [1, 56], "to": [14, 56], "color": "#20232a"})
    block(CLOTH, "#2e2e3a", "#18181f", 0.3, "#0c0c10")
    block(COPPER, "#d08848", "#8a4a20", 0.2, "#4a2410")
    ops.append({"op": "fill", "rect": BLACK, "color": "#101014"})
    return ops


def cube(name, group, frm, to, uv, **extra):
    e = {"type": "cube", "name": name, "group": group, "from": frm, "to": to, "all": uv}
    e.update(extra)
    return e


def no_bottom(name, group, frm, to, uv, **extra):
    """A box with no underside (nobody looks under a workbench): fewer triangles."""
    e = {"type": "cube", "name": name, "group": group, "from": frm, "to": to, "sides": uv, "top": uv}
    e.update(extra)
    return e


def wheel(name, group, x, z, radius, width, y=-1.0, tyre=TYRE, cap=RIM):
    """A wheel lying on its side: pivot = axle, so getaway_car.gd can spin it."""
    return {"type": "prism", "name": name, "group": group, "sides": 8, "center": [x, y - width / 2, z],
            "height": width, "radius": radius, "origin": [x, y, z], "rotation": [0, 0, 90],
            "side_uv": [0, 32, 16, 36], "top_uv": cap, "bottom_uv": cap}


def mirror(e):
    """The same element on the other side (x flipped)."""
    m = json.loads(json.dumps(e))
    m["name"] = e["name"].replace("L", "R") if e["name"].endswith("L") else e["name"] + "_r"
    if "group" in m and m["group"].endswith("L"):
        m["group"] = m["group"][:-1] + "R"
    a, b = m["from"][0], m["to"][0]
    m["from"][0], m["to"][0] = -b, -a
    return m


# ---------------------------------------------------------------------------------------
# THE TINKER WORKBENCH (prop): heavy table, vice, wrench, soldering iron, vacuum parts, lamp.
# 2 m long (X), 1 m deep (Z); the side that faces you is -Z, the pegboard (+Z) goes on the wall.
# ---------------------------------------------------------------------------------------
workbench = {
    "name": "workbench", "kind": "prop", "texture_size": 64, "seed": 77, "background": "#2a2d33",
    "about": "SEWER UPGRADES: the TINKER WORKBENCH (scripts/upgrades.gd page 'workbench', built by hub.gd "
             "_build_workbench). Front = -Z. Groups: Body, Lamp (the bulb: glows), Glow (soldering tip).",
    "paint": paint("#4a5a3a", "#2a3420"),
    "groups": [{"name": "Body"}, {"name": "Lamp", "origin": [-6, 22, -5.5]}, {"name": "Glow"}],
    "elements": [
        no_bottom("top", "Body", [-16, 13, -8], [16, 15, 8], WOOD),
        {"type": "cube", "name": "legL", "group": "Body", "from": [-15, 0, -7], "to": [-13, 13, 7], "sides": DARK},
        {"type": "cube", "name": "legR", "group": "Body", "from": [13, 0, -7], "to": [15, 13, 7], "sides": DARK},
        no_bottom("shelf", "Body", [-13, 3, -6], [13, 4, 6], DARK),
        no_bottom("parts_crate", "Body", [-11, 4, -4], [-3, 9, 4], RUST),
        no_bottom("vice", "Body", [8, 15, -6], [13, 18.5, -1], LIGHT),
        no_bottom("wrench", "Body", [-7, 15, -4], [1, 15.6, -3], LIGHT),  # (a long spanner; under 150 triangles in all)
        no_bottom("iron", "Body", [-12, 15, 1], [-4, 16, 2], COPPER),
        no_bottom("iron_tip", "Glow", [-13.5, 15.2, 1.2], [-12, 15.8, 1.8], LAMP),
        {"type": "prism", "name": "vac_brush", "group": "Body", "sides": 6, "center": [3, 15, 3], "height": 2,
         "radius_bottom": 3, "radius_top": 2.4, "side_uv": [0, 48, 16, 52], "top_uv": RIM},
        {"type": "cube", "name": "pegboard", "group": "Body", "from": [-16, 15, 7], "to": [16, 28, 8],
         "faces": {"north": CLOTH, "up": DARK}},
        {"type": "cube", "name": "lamp_pole", "group": "Body", "from": [-14, 15, 4], "to": [-13, 26, 5], "sides": DARK},
        {"type": "cube", "name": "lamp_arm", "group": "Body", "from": [-14, 25, -6], "to": [-13, 26, 4], "sides": DARK, "top": DARK},
        {"type": "prism", "name": "lamp_shade", "group": "Body", "sides": 6, "center": [-13.5, 22, -6.5], "height": 3,
         "radius_bottom": 2.6, "radius_top": 0.8, "side_uv": [16, 0, 32, 4]},
        no_bottom("bulb", "Lamp", [-14.5, 21.2, -7.5], [-12.5, 22.2, -5.5], LAMP),
    ],
}
# (the bulb sits under the shade: give it its underside back so it shines down at you)
workbench["elements"][-1]["bottom"] = LAMP


# ---------------------------------------------------------------------------------------
# THE NEON ZOOM-BIKE (vehicle): an 80s/90s cyber-motorcycle. Two wheels with glowing rims.
# ---------------------------------------------------------------------------------------
nose = {"type": "poly", "name": "fairing", "group": "Body", "uv": BODY, "vertices": {
    "fbl": [-3.5, 1, -19], "fbr": [3.5, 1, -19], "ftl": [-2.5, 6, -15], "ftr": [2.5, 6, -15],
    "btl": [-3, 8, -9], "btr": [3, 8, -9], "bbl": [-3.5, 1, -9], "bbr": [3.5, 1, -9]},
    "faces": [{"v": ["fbl", "fbr", "bbr", "bbl"]}, {"v": ["bbl", "bbr", "btr", "btl"]}, {"v": ["ftl", "ftr", "btr", "btl"]},
              {"v": ["fbl", "fbr", "ftr", "ftl"]}, {"v": ["fbl", "ftl", "btl", "bbl"]}, {"v": ["fbr", "ftr", "btr", "bbr"]}]}
tail = {"type": "poly", "name": "tail", "group": "Body", "uv": BODY, "vertices": {
    "fbl": [-3, 3, 8], "fbr": [3, 3, 8], "ftl": [-3, 7, 8], "ftr": [3, 7, 8],
    "btl": [-1.8, 7.5, 18], "btr": [1.8, 7.5, 18], "bbl": [-1.8, 5, 18], "bbr": [1.8, 5, 18]},
    "faces": [{"v": ["fbl", "fbr", "bbr", "bbl"]}, {"v": ["bbl", "bbr", "btr", "btl"]}, {"v": ["ftl", "ftr", "btr", "btl"]},
              {"v": ["fbl", "fbr", "ftr", "ftl"]}, {"v": ["fbl", "ftl", "btl", "bbl"]}, {"v": ["fbr", "ftr", "btr", "bbr"]}]}
fork = cube("forkL", "Body", [-3.2, -1, -14.5], [-2.6, 6, -13.5], LIGHT)
bike = {
    "name": "cyber_bike", "kind": "vehicle", "texture_size": 64, "seed": 88, "background": "#202228",
    "about": "SEWER UPGRADES: the NEON ZOOM-BIKE (getaway_car.gd VEHICLES 'cyber_bike'). Forward = -Z, wheel "
             "bottoms at y = -7 px like the car. Groups: Body, Trim (gang colour), TrimRimF/B (inside the wheels: "
             "glowing rims), HeadlightL, TaillightL, Thrusters, WheelFL, WheelBL.",
    "paint": paint("#6a58a0", "#382a60"),
    "groups": [{"name": "Body"}, {"name": "Trim"}, {"name": "HeadlightL", "origin": [0, 3, -19]},
               {"name": "TaillightL", "origin": [0, 6, 18]}, {"name": "Thrusters", "origin": [3, 2, 16]},
               {"name": "WheelFL", "origin": [0, -1, -14]}, {"name": "WheelBL", "origin": [0, -1, 13]},
               {"name": "TrimRimF", "origin": [0, -1, -14], "parent": "WheelFL"},
               {"name": "TrimRimB", "origin": [0, -1, 13], "parent": "WheelBL"}],
    "elements": [
        cube("frame", "Body", [-1.4, -0.5, -12], [1.4, 3, 9], DARK),
        nose,
        cube("tank", "Body", [-3, 3, -9], [3, 7, -1], BODY),
        cube("seat", "Body", [-2.5, 5, -1], [2.5, 7, 8], CLOTH),
        tail,
        {"type": "cube", "name": "windscreen", "group": "Body", "from": [-2.2, 8, -10.5], "to": [2.2, 11, -9.5], "all": GLASS, "rotation": [-20, 0, 0], "origin": [0, 8, -10]},
        cube("bars", "Body", [-6, 8.5, -11.5], [6, 9.3, -10.7], DARK),
        fork, mirror(fork),
        cube("stripeL", "Trim", [-3.5, 4, -8.5], [-3, 5, 7.5], TRIM),
        cube("stripeR", "Trim", [3, 4, -8.5], [3.5, 5, 7.5], TRIM),
        cube("nose_lip", "Trim", [-3.6, 0.6, -19.6], [3.6, 1.2, -18.8], TRIM),
        cube("headlight", "HeadlightL", [-1.6, 2, -19.8], [1.6, 4, -18.9], HEAD),
        cube("taillight", "TaillightL", [-1.6, 5.4, 17.9], [1.6, 7, 18.5], TAIL),
        cube("exhaust", "Thrusters", [3, 1, 11], [4.4, 2.6, 17], COPPER),
        wheel("tyre_f", "WheelFL", 0, -14, 6, 3),
        wheel("tyre_b", "WheelBL", 0, 13, 6, 3.4),
        wheel("rim_f", "TrimRimF", 0, -14, 3.6, 4.4, cap=TRIM),
        wheel("rim_b", "TrimRimB", 0, 13, 3.6, 4.8, cap=TRIM),
    ],
}


# ---------------------------------------------------------------------------------------
# THE ARMORED MEOW-VAN (vehicle): a chunky armoured fish-delivery van with a bullbar and a
# glowing fish sign on the roof. 2 m wide, 4.4 m long.
# ---------------------------------------------------------------------------------------
lamp = cube("headlightL", "HeadlightL", [-13, 4, -34.6], [-8, 7, -33.9], HEAD)
taillamp = cube("taillightL", "TaillightL", [-14, 10, 33.9], [-11, 16, 34.6], TAIL)
post = cube("bar_postL", "Body", [-11, -1, -36.5], [-9, 7, -34], LIGHT)
van = {
    "name": "fish_van", "kind": "vehicle", "texture_size": 64, "seed": 99, "background": "#202228",
    "about": "SEWER UPGRADES: the ARMORED MEOW-VAN (getaway_car.gd VEHICLES 'fish_van'). Forward = -Z, wheel "
             "bottoms at y = -7 px. Groups: Body, Trim (gang colour stripes), Sign (roof fish: glows), "
             "HeadlightL/R, TaillightL/R, WheelFL/FR/BL/BR.",
    "paint": paint("#7e8a62", "#465036"),
    "groups": [{"name": "Body"}, {"name": "Trim"}, {"name": "Sign", "origin": [0, 28, -3.5]},
               {"name": "HeadlightL", "origin": [-10.5, 5.5, -34]}, {"name": "HeadlightR", "origin": [10.5, 5.5, -34]},
               {"name": "TaillightL", "origin": [-12.5, 13, 34]}, {"name": "TaillightR", "origin": [12.5, 13, 34]},
               {"name": "WheelFL", "origin": [-13, -1, -22]}, {"name": "WheelFR", "origin": [13, -1, -22]},
               {"name": "WheelBL", "origin": [-13, -1, 22]}, {"name": "WheelBR", "origin": [13, -1, 22]}],
    "elements": [
        {"type": "cube", "name": "chassis", "group": "Body", "from": [-14.5, 0, -34], "to": [14.5, 9, 34], "sides": BODY, "top": DARK, "bottom": BLACK},
        {"type": "cube", "name": "cargo", "group": "Body", "from": [-14.5, 9, -18], "to": [14.5, 24, 34], "sides": BODY, "top": DARK},
        {"type": "cube", "name": "cab", "group": "Body", "from": [-14, 9, -30], "to": [14, 18, -18], "sides": BODY, "top": DARK},
        {"type": "cube", "name": "windshield", "group": "Body", "from": [-12, 10.5, -30.6], "to": [12, 17, -30], "faces": {"north": GLASS}},
        {"type": "cube", "name": "side_windowL", "group": "Body", "from": [-14.6, 11, -28], "to": [-14, 17, -20], "faces": {"west": GLASS}},
        {"type": "cube", "name": "side_windowR", "group": "Body", "from": [14, 11, -28], "to": [14.6, 17, -20], "faces": {"east": GLASS}},
        cube("bullbar_low", "Body", [-14, -1, -36.5], [14, 1, -34], LIGHT),
        cube("bullbar_high", "Body", [-14, 5, -36.5], [14, 7, -34], LIGHT),
        post, mirror(post),
        {"type": "cube", "name": "armor_plateL", "group": "Body", "from": [-15.2, 1, -16], "to": [-14.5, 6, 16], "sides": DARK},
        {"type": "cube", "name": "armor_plateR", "group": "Body", "from": [14.5, 1, -16], "to": [15.2, 6, 16], "sides": DARK},
        cube("stripeL", "Trim", [-15.2, 7, -33], [-14.5, 8.5, 33], TRIM),
        cube("stripeR", "Trim", [14.5, 7, -33], [15.2, 8.5, 33], TRIM),
        cube("stripe_highL", "Trim", [-15.2, 19, -17], [-14.5, 20.5, 33], TRIM),
        cube("stripe_highR", "Trim", [14.5, 19, -17], [15.2, 20.5, 33], TRIM),
        cube("sign_post", "Body", [-1, 24, -4], [1, 25, -3], DARK),
        {"type": "cube", "name": "fish_sign", "group": "Sign", "from": [-10, 25, -4], "to": [10, 31, -3],
         "faces": {"north": SIGN, "south": SIGN, "up": DARK, "east": DARK, "west": DARK}},
        lamp, mirror(lamp), taillamp, mirror(taillamp),
        wheel("wheelfl", "WheelFL", -13, -22, 6, 4), wheel("wheelfr", "WheelFR", 13, -22, 6, 4),
        wheel("wheelbl", "WheelBL", -13, 22, 6, 4), wheel("wheelbr", "WheelBR", 13, 22, 6, 4),
    ],
}

if __name__ == "__main__":
    for spec in (workbench, bike, van):
        path = os.path.join(SPECS, spec["name"] + ".json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(spec, f, indent=1)
        print("wrote", path)
