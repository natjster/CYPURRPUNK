"""Writes the model spec for THE MAINFRAME (scripts/mainframe.gd), the rebels' home-made computer
on the west wall of each sewer (built by hub.gd _build_mainframe):

    tools/model_specs/mainframe.json   -> models/mainframe.glb

Run it, then build the model:
    python tools/make_mainframe_spec.py
    python tools/cypurr_models.py all tools/model_specs/mainframe.json

Re-running REPLACES the .bbmodel (hand edits made in Blockbench are lost). 16 px = 1 m,
the FRONT (the side the cats look at) is -Z, Y up, the back (z = 0) goes flat against the wall.

The look: the cats SCROUNGED it together. A big old CRT on a pallet, two mismatched little monitors
on wooden crates, car batteries, a desk fan bolted on top, a wok for a satellite dish, duct tape,
cables running up to the ceiling, a spray-painted paw, and a chute at cat height where you shove the
ELECTRONICS in. The game adds the glowing parts itself (hub.gd): the big screen, its text, the
battery CHARGE GAUGE on the right (4 cells that go dark as the charge drains) and the lights.

Texture = 64x64, 16x16 swatches:
  row 0:  wood | dark metal | old beige plastic | rust
  row 1:  duct tape | green screen (glows) | amber lamp (glows) | spray-paw board
  row 2:  cable (red/black) | black | copper | hazard stripes
  row 3:  vent grille | stencilled crate | cyan LED (glows) | dark glass
Groups: Body, Glow (little screens, LEDs, the chute's slot: hub.gd makes them glow),
Fan (pivot = its middle: hub.gd spins it faster the more charge there is), Dish.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SPECS = os.path.join(HERE, "model_specs")


def sw(col, row):
    """The UV rect of one 16x16 swatch."""
    return [col * 16, row * 16, col * 16 + 16, row * 16 + 16]


WOOD, DARK, BEIGE, RUST = sw(0, 0), sw(1, 0), sw(2, 0), sw(3, 0)
TAPE, SCREEN, LAMP, PAW = sw(0, 1), sw(1, 1), sw(2, 1), sw(3, 1)
CABLE, BLACK, COPPER, HAZARD = sw(0, 2), sw(1, 2), sw(2, 2), sw(3, 2)
GRILLE, CRATE, LED, GLASS = sw(0, 3), sw(1, 3), sw(2, 3), sw(3, 3)


def paint():
    ops = [{"op": "comment", "note": __doc__.split("Texture = ")[1].split("Groups:")[0].strip()}]

    def block(rect, top, bottom, noise=0.2, edge="#111318"):
        ops.append({"op": "gradient", "rect": rect, "top": top, "bottom": bottom})
        if noise:
            ops.append({"op": "noise", "rect": rect, "amount": noise, "spread": 0.12})
        if edge:
            ops.append({"op": "edge", "rect": rect, "color": edge})

    # row 0
    block(WOOD, "#7a5530", "#4e3420", 0.35, "#2a1a10")
    ops.append({"op": "line", "from": [0, 5], "to": [15, 5], "color": "#3d2817"})
    ops.append({"op": "line", "from": [0, 10], "to": [15, 10], "color": "#3d2817"})
    block(DARK, "#4a505a", "#2c3038")
    for x, y in [(18, 2), (29, 2), (18, 13), (29, 13)]:  # rivets
        ops.append({"op": "pixels", "list": [[x, y, "#9aa3b0"]]})
    block(BEIGE, "#c8bc98", "#9a8e6c", 0.25, "#5a5240")  # yellowed 90s computer plastic
    ops.append({"op": "spots", "rect": BEIGE, "color": "#7a6e50", "count": 4, "size": 1})
    block(RUST, "#8a5530", "#5a3018", 0.4, "#2a1408")
    ops.append({"op": "spots", "rect": RUST, "color": "#a86a38", "count": 6, "size": 1})
    # row 1
    ops.append({"op": "stripes", "rect": TAPE, "colors": ["#a0a4a8", "#8a8e92"], "width": 2, "direction": "horizontal"})
    ops.append({"op": "noise", "rect": TAPE, "amount": 0.15, "spread": 0.1})
    ops.append({"op": "fill", "rect": SCREEN, "color": "#2aff70"})
    ops.append({"op": "stripes", "rect": SCREEN, "colors": ["#2aff70", "#12a040"], "width": 1, "direction": "horizontal"})
    ops.append({"op": "fill", "rect": LAMP, "color": "#ffc04a"})
    ops.append({"op": "fill", "rect": [36, 20, 44, 28], "color": "#fff0b8"})
    # The spray-painted paw: a magenta paw on a black board (the rebellion's tag).
    ops.append({"op": "fill", "rect": PAW, "color": "#15151b"})
    ops.append({"op": "noise", "rect": PAW, "amount": 0.2, "spread": 0.1})
    ops.append({"op": "fill", "rect": [52, 24, 60, 30], "color": "#ff3ad0"})  # pad
    for x, y in [(50, 20), (53, 18), (57, 18), (60, 20)]:  # toes
        ops.append({"op": "fill", "rect": [x, y, x + 2, y + 3], "color": "#ff3ad0"})
    ops.append({"op": "pixels", "list": [[55, 31, "#c02aa0"], [56, 31, "#c02aa0"], [57, 31, "#c02aa0"]]})  # a drip
    # row 2
    ops.append({"op": "stripes", "rect": CABLE, "colors": ["#b02020", "#1a1a1e"], "width": 3})
    ops.append({"op": "fill", "rect": BLACK, "color": "#121216"})
    block(COPPER, "#d08848", "#8a4a20", 0.2, "#4a2410")
    ops.append({"op": "stripes", "rect": HAZARD, "colors": ["#f0c020", "#141414"], "width": 3})
    # row 3
    ops.append({"op": "stripes", "rect": GRILLE, "colors": ["#2a2e34", "#0e1014"], "width": 2, "direction": "horizontal"})
    block(CRATE, "#6e4c2a", "#46301a", 0.3, "#24160c")
    ops.append({"op": "text", "text": "ELX", "pos": [19, 55], "color": "#1a120a"})
    ops.append({"op": "fill", "rect": LED, "color": "#30e8ff"})
    ops.append({"op": "fill", "rect": [38, 50, 42, 54], "color": "#e0ffff"})
    block(GLASS, "#203038", "#080e12", 0.05, "#05080a")
    return ops


def box(name, frm, to, uv, group="Body", **extra):
    """A box with no underside (it sits on something): fewer triangles."""
    e = {"type": "cube", "name": name, "group": group, "from": frm, "to": to, "sides": uv, "top": uv}
    e.update(extra)
    return e


def faced(name, frm, to, sides, front, group="Body", top=None):
    """A box with a different picture on its FRONT (north = -Z) face."""
    faces = {"north": front, "east": sides, "west": sides, "south": sides, "up": top or sides}
    return {"type": "cube", "name": name, "group": group, "from": frm, "to": to, "faces": faces}


def front_panel(name, frm, to, uv, group="Body"):
    """Only a front face (a sticker / screen / board flat on something)."""
    return {"type": "cube", "name": name, "group": group, "from": frm, "to": to, "faces": {"north": uv}}


def can(name, center, radius, height, uv_side, uv_top, sides=6, group="Body", **extra):
    e = {"type": "prism", "name": name, "group": group, "sides": sides, "center": center, "height": height,
         "radius": radius, "side_uv": uv_side, "top_uv": uv_top}
    e.update(extra)
    return e


elements = [
    # --- The base: a pallet in the middle, wooden crates either side ---
    box("pallet", [-32, 0, -18], [32, 4, 0], WOOD),
    faced("crate_left", [-48, 0, -17], [-32, 14, -1], WOOD, CRATE),
    faced("crate_right", [32, 0, -16], [48, 12, -1], WOOD, CRATE),
    faced("crate_top_left", [-46, 14, -14], [-34, 20, -2], WOOD, CRATE),

    # --- THE BIG CRT (the game puts its glowing screen + text on the front, at z = -16.6) ---
    faced("crt_case", [-30, 4, -16], [30, 56, 0], BEIGE, BEIGE),
    front_panel("crt_bezel", [-28, 10, -16.3], [28, 52, -16], BLACK),
    faced("crt_chin", [-30, 4, -18], [30, 9, -16], BEIGE, GRILLE),   # vent strip under the screen
    # Duct tape holding the cracked case together.
    {"type": "cube", "name": "tape_1", "group": "Body", "from": [-31, 44, -16.6], "to": [-19, 46, -15.8],
     "faces": {"north": TAPE}, "rotation": [0, 0, 35], "origin": [-25, 45, -16]},
    {"type": "cube", "name": "tape_2", "group": "Body", "from": [20, 6, -18.6], "to": [31, 8, -17.8],
     "faces": {"north": TAPE}, "rotation": [0, 0, -25], "origin": [25, 7, -18]},
    # THE CHUTE (cat height, under the screen): shove the ELECTRONICS in here.
    faced("chute", [-8, 4, -24], [8, 11, -18], DARK, HAZARD, top=RUST),
    front_panel("chute_slot", [-6, 6.5, -24.3], [6, 8.5, -24], LAMP, "Glow"),

    # --- Left side: a little beige monitor on the crates, car batteries, the paw tag ---
    faced("mini_crt", [-47, 20, -13], [-33, 32, -2], BEIGE, BEIGE),
    front_panel("mini_screen", [-45, 22, -13.3], [-35, 30, -13], SCREEN, "Glow"),
    box("battery_1", [-47, 32, -10], [-39, 37, -3], BLACK),
    box("battery_2", [-38, 32, -10], [-33, 36, -4], BLACK),
    box("terminal_1", [-46, 37, -8], [-44, 38.5, -6], COPPER),
    box("terminal_2", [-42, 37, -8], [-40, 38.5, -6], COPPER),
    front_panel("paw_board", [-46, 2, -17.3], [-34, 12, -17], PAW),

    # --- Right side: the battery rack (the game fills it with glowing cells = the CHARGE GAUGE) ---
    box("rack_back", [33, 12, -3], [47, 50, -1], DARK),
    box("rack_post_l", [33, 12, -15], [34.5, 50, -3], RUST),
    box("rack_post_r", [45.5, 12, -15], [47, 50, -3], RUST),
    box("rack_top", [33, 50, -15], [47, 52, -1], RUST),
    front_panel("rack_hazard", [33, 12.5, -16.3], [47, 14.5, -16], HAZARD),
    # A screwed-on old radio: blinking LEDs.
    faced("radio", [-24, 56, -12], [-6, 62, -2], DARK, GRILLE),
    front_panel("leds", [-22, 59, -12.3], [-16, 61, -12], LED, "Glow"),

    # --- On top: a desk fan (spins), a wok satellite dish, fish-can capacitors ---
    can("fan_hub", [-15, 62, -7], 1.5, 2.5, DARK, COPPER, sides=6, group="Fan"),
    {"type": "cube", "name": "fan_blade_1", "group": "Fan", "from": [-21, 63, -8], "to": [-9, 63.6, -6], "sides": BEIGE, "top": BEIGE},
    {"type": "cube", "name": "fan_blade_2", "group": "Fan", "from": [-16, 63, -13], "to": [-14, 63.6, -1], "sides": BEIGE, "top": BEIGE},
    box("dish_pole", [17, 56, -6], [19, 66, -4], DARK),
    can("dish", [18, 64, -5], 7, 2.5, RUST, DARK, sides=8, group="Dish",
        radius_bottom=2, radius_top=8, origin=[18, 65, -5], rotation=[-35, 0, 0]),
    can("fish_can_1", [6, 56, -10], 2.6, 4, COPPER, DARK, sides=6),
    can("fish_can_2", [11, 56, -9], 2.6, 4, COPPER, DARK, sides=6),

    # --- Cables: up to the ceiling pipes, and one across the floor ---
    box("cable_up_1", [-28, 56, -3], [-26.5, 112, -1.5], CABLE),
    box("cable_up_2", [26, 52, -2.5], [27.5, 112, -1], CABLE),
    box("cable_up_3", [44, 52, -2.5], [45.5, 112, -1], BLACK),
    box("cable_floor", [-48, 0, -10], [-32, 1, -8.5], CABLE),
]

mainframe = {
    "name": "mainframe", "kind": "set_piece", "texture_size": 64, "seed": 1999, "background": "#202228",
    "about": "THE MAINFRAME (scripts/mainframe.gd, built by hub.gd _build_mainframe). The rebels' scrounged-together "
             "computer: a big CRT on a pallet, crates, batteries, a fan, a wok dish. Front = -Z, back (z 0) on the wall. "
             "Groups: Body, Glow (glows), Fan (spins), Dish.",
    "paint": paint(),
    "groups": [{"name": "Body"}, {"name": "Glow"}, {"name": "Fan", "origin": [-15, 62, -7]},
               {"name": "Dish", "origin": [18, 65, -5]}],
    "elements": elements,
}

if __name__ == "__main__":
    path = os.path.join(SPECS, "mainframe.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(mainframe, f, indent=1)
    print("wrote", path)
