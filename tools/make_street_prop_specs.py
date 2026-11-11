"""Writes the model specs for the INTERACTIVE STREET PROPS PACK (scripts/mess_prop.gd, ROADMAP.md §5 #3):

    tools/model_specs/vending_machine.json -> FISH VENDING MACHINE (Kind VENDING: kick it, a fish drops out)
    tools/model_specs/fire_hydrant.json    -> CYBER HYDRANT        (Kind HYDRANT: wrench it, a geyser erupts)
    tools/model_specs/shopping_cart.json   -> MEOW-MART CART       (Kind CART: shove it, it rolls and bowls)
    tools/model_specs/neon_sign_prop.json  -> NEON A-FRAME SIGN    (Kind NEON_SIGN: kick it over, it sparks)
    tools/model_specs/dumpster.json        -> ALLEY DUMPSTER       (Kind DUMPSTER: rummage it, the lid flies open)

Run it, then build each model (spec -> .bbmodel -> .glb):
    python tools/make_street_prop_specs.py
    python tools/cypurr_models.py all tools/model_specs/vending_machine.json   (same for the other four)

Re-running REPLACES the .bbmodel files (hand edits made in Blockbench are lost), like
tools/make_creature_specs.py. 16 px = 1 m, the FRONT of every prop faces -Z (north), Y up,
feet on y = 0.

GROUP NAMES MATTER: scripts/mess_prop.gd looks these up by name, so keep them if you rename things:
    Screen   (vending)  glows cyan; goes dark when the machine is busted
    Flap     (vending)  pivot = its top edge: swings open when busted
    Cap      (hydrant)  pivot = its middle: pops off and tilts when burst
    Handle   (cart)     glows hot pink (Meow-Mart's colour)
    Wheels   (cart)     the four casters
    SignFace (neon)     glows; goes dark when knocked flat
    Lid      (dumpster) pivot = the BACK hinge: swings open when rummaged
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SPECS = os.path.join(HERE, "model_specs")

# A 5x3 pixel fish (tail on the right) and a 3x3 sardine can, for icons painted onto textures.
FISH = ["01101", "11110", "01101"]
CAN = ["111", "101", "111"]


def icon(pattern, x, y, color, eye=None):
    """pixels-op list for a little pattern at (x, y); eye = colour of the fish's eye pixel."""
    out = []
    for gy, row in enumerate(pattern):
        for gx, bit in enumerate(row):
            if bit == "1":
                out.append([x + gx, y + gy, color])
    if eye:
        out.append([x + 1, y + 1, eye])
    return {"op": "pixels", "list": out}


def write(spec):
    path = os.path.join(SPECS, spec["name"] + ".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=1)
    print("wrote", os.path.relpath(path, os.path.dirname(HERE)))


# =====================================================================================
# 1. FISH VENDING MACHINE  (~1.1 m wide x 1.85 m tall x 0.75 m deep)
# =====================================================================================
def vending_machine():
    paint = [
        {"op": "comment", "note": "[0,0,32,48] the front: dark plum metal, panel seams, the dispense hole near the bottom"},
        {"op": "fill", "rect": [0, 0, 32, 48], "color": "#3a2a44"},
        {"op": "stripes", "rect": [0, 0, 32, 48], "colors": ["#ffffff0c", "#00000000", "#0000001a"], "width": 1, "direction": "horizontal"},
        {"op": "edge", "rect": [0, 0, 32, 48], "color": "#1c1422"},
        {"op": "edge", "rect": [1, 1, 31, 47], "color": "#5b4568"},
        {"op": "line", "from": [1, 30], "to": [30, 30], "color": "#1c1422"},
        {"op": "fill", "rect": [5, 35, 22, 43], "color": "#0d0a10"},
        {"op": "edge", "rect": [4, 34, 23, 44], "color": "#6e5880"},
        {"op": "text", "pos": [3, 31], "text": "TAKE", "color": "#ff4fb0c0", "worn": 0.1},
        {"op": "text", "pos": [22, 37], "text": "!", "color": "#ffd23a"},
        {"op": "noise", "rect": [0, 0, 32, 48], "amount": 0.25, "spread": 0.15},
        {"op": "dither", "rect": [0, 38, 32, 48], "color": "#140c10", "top": 0.0, "bottom": 0.6},
        {"op": "spots", "rect": [0, 40, 32, 48], "color": "#7a4420b0", "count": 4, "size": 1.4},
        {"op": "comment", "note": "[32,0,64,24] the SCREEN: deep blue glass with rows of pixel fish + price tags (glows)"},
        {"op": "fill", "rect": [32, 0, 64, 24], "color": "#08142e"},
        {"op": "stripes", "rect": [32, 0, 64, 24], "colors": ["#00000000", "#1d3a6a50"], "width": 1, "direction": "horizontal"},
        {"op": "line", "from": [32, 7], "to": [63, 7], "color": "#2b5aa0"},
        {"op": "line", "from": [32, 15], "to": [63, 15], "color": "#2b5aa0"},
        icon(FISH, 34, 2, "#5ff2ff", "#08142e"), icon(FISH, 41, 2, "#ff5fc8", "#08142e"),
        icon(FISH, 48, 2, "#5ff2ff", "#08142e"), icon(FISH, 55, 2, "#ffd84a", "#08142e"),
        icon(CAN, 35, 10, "#c8d0e0"), icon(CAN, 42, 10, "#ff5fc8"), icon(CAN, 49, 10, "#5ff2ff"), icon(CAN, 56, 10, "#c8d0e0"),
        icon(FISH, 35, 18, "#ffd84a", "#08142e"), icon(FISH, 43, 18, "#5ff2ff", "#08142e"), icon(FISH, 51, 18, "#ff5fc8", "#08142e"),
        {"op": "pixels", "list": [[38, 6, "#ffd84a"], [45, 6, "#ffd84a"], [52, 6, "#ffd84a"], [59, 6, "#ffd84a"],
                                   [37, 14, "#ffd84a"], [44, 14, "#ffd84a"], [51, 14, "#ffd84a"], [58, 14, "#ffd84a"]]},
        {"op": "line", "from": [58, 1], "to": [62, 5], "color": "#ffffff60"},
        {"op": "line", "from": [59, 1], "to": [62, 4], "color": "#ffffff40"},
        {"op": "comment", "note": "[32,24,64,48] the sides: plum metal with cooling vents and a sticker"},
        {"op": "fill", "rect": [32, 24, 64, 48], "color": "#34263e"},
        {"op": "noise", "rect": [32, 24, 64, 48], "amount": 0.25, "spread": 0.15},
        {"op": "stripes", "rect": [36, 27, 60, 33], "colors": ["#120c16", "#4a3856"], "width": 1, "direction": "horizontal"},
        {"op": "stripes", "rect": [36, 38, 60, 44], "colors": ["#120c16", "#4a3856"], "width": 1, "direction": "horizontal"},
        {"op": "edge", "rect": [32, 24, 64, 48], "color": "#1c1422"},
        {"op": "fill", "rect": [52, 34, 60, 37], "color": "#e8d27a"},
        {"op": "dither", "rect": [32, 40, 64, 48], "color": "#140c10", "top": 0.0, "bottom": 0.55},
        {"op": "comment", "note": "[0,48,32,56] the lit header sign FISH 2 GO (glows with the screen)"},
        {"op": "fill", "rect": [0, 48, 32, 56], "color": "#2a0b26"},
        {"op": "text", "pos": [2, 49], "text": "FISH 2 GO", "color": "#ff5fc8", "spacing": 0},
        {"op": "line", "from": [0, 55], "to": [31, 55], "color": "#5ff2ff"},
        {"op": "comment", "note": "[32,48,48,64] coin / card slot panel with buttons"},
        {"op": "fill", "rect": [32, 48, 48, 64], "color": "#22242c"},
        {"op": "edge", "rect": [32, 48, 48, 64], "color": "#5a5e6c"},
        {"op": "fill", "rect": [35, 50, 45, 52], "color": "#000000"},
        {"op": "fill", "rect": [36, 50, 44, 51], "color": "#ffd84a"},
        {"op": "pixels", "list": [[35, 55, "#5ff2ff"], [38, 55, "#5ff2ff"], [41, 55, "#ff5fc8"], [44, 55, "#5ff2ff"],
                                   [35, 58, "#5ff2ff"], [38, 58, "#ff5fc8"], [41, 58, "#5ff2ff"], [44, 58, "#ffd84a"]]},
        {"op": "fill", "rect": [37, 61, 43, 62], "color": "#000000"},
        {"op": "comment", "note": "[48,48,64,56] the dispense FLAP   [0,56,32,64] base / top metal"},
        {"op": "fill", "rect": [48, 48, 64, 56], "color": "#1a1a20"},
        {"op": "edge", "rect": [48, 48, 64, 56], "color": "#6a6e7c"},
        {"op": "text", "pos": [50, 50], "text": "PUSH", "color": "#9aa0b0", "spacing": 0},
        {"op": "fill", "rect": [0, 56, 32, 64], "color": "#1e1824"},
        {"op": "stripes", "rect": [0, 58, 32, 62], "colors": ["#ffd23a", "#1e1824"], "width": 2},
        {"op": "noise", "rect": [0, 56, 32, 64], "amount": 0.35, "spread": 0.2},
    ]
    groups = [
        {"name": "Body", "origin": [0, 0, 0]},
        {"name": "Screen", "origin": [0, 20, -6], "parent": "Body"},
        {"name": "Flap", "origin": [-1.5, 7.4, -6.2], "parent": "Body"},
    ]
    elements = [
        {"type": "cube", "name": "plinth", "group": "Body", "from": [-9.2, 0, -6.4], "to": [9.2, 2, 6.4],
         "sides": [0, 56, 32, 64], "top": [0, 56, 32, 64]},
        {"type": "cube", "name": "cabinet", "group": "Body", "from": [-8.8, 2, -6], "to": [8.8, 28, 6],
         "faces": {"north": [0, 0, 32, 48], "south": [32, 24, 64, 48], "east": [32, 24, 64, 48], "west": [32, 24, 64, 48]}},
        {"type": "cube", "name": "slot_panel", "group": "Body", "from": [4.4, 13, -6.6], "to": [7.8, 24, -6],
         "faces": {"north": [32, 48, 48, 64], "east": [32, 48, 34, 64], "west": [32, 48, 34, 64], "up": [32, 48, 48, 50]}},
        {"type": "cube", "name": "screen", "group": "Screen", "from": [-7, 12.5, -6.25], "to": [3.6, 26.5, -6],
         "faces": {"north": [32, 0, 64, 24]}},
        {"type": "cube", "name": "header", "group": "Screen", "from": [-9.2, 28, -6.5], "to": [9.2, 29.6, 6.2],
         "faces": {"north": [0, 48, 32, 56], "south": [0, 48, 32, 56], "east": [0, 56, 16, 58], "west": [0, 56, 16, 58], "up": [0, 56, 32, 64]}},
        {"type": "cube", "name": "flap", "group": "Flap", "from": [-6.6, 3.4, -6.35], "to": [3.6, 7.4, -6.05],
         "faces": {"north": [48, 48, 64, 56], "down": [48, 54, 64, 56]}},
    ]
    write({"name": "vending_machine", "kind": "prop", "texture_size": 64, "seed": 41, "background": "#3a2a44",
           "about": "FISH 2 GO: a chunky cyber vending machine (1.1 x 1.85 x 0.75 m) with a glowing fish SCREEN, coin slot, "
                    "side vents and a dispense FLAP. A MESS prop (Kind VENDING): kick or shoot it and a fish drops out. 16 px = 1 m.",
           "paint": paint, "groups": groups, "elements": elements})


# =====================================================================================
# 2. FIRE HYDRANT  (~0.55 m wide x 0.85 m tall)
# =====================================================================================
def fire_hydrant():
    paint = [
        {"op": "comment", "note": "[0,0,64,16] the barrel: chipped hazard yellow with a cyan sensor band"},
        {"op": "fill", "rect": [0, 0, 64, 16], "color": "#e0b020"},
        {"op": "stripes", "rect": [0, 0, 64, 16], "colors": ["#ffffff14", "#00000000", "#00000018", "#00000000"], "width": 2},
        {"op": "fill", "rect": [0, 5, 64, 7], "color": "#0f2a30"},
        {"op": "stripes", "rect": [0, 5, 64, 7], "colors": ["#4ff0ff", "#0f2a30", "#0f2a30"], "width": 2},
        {"op": "text", "pos": [4, 9], "text": "H2O", "color": "#3a2a10c0", "worn": 0.1},
        {"op": "text", "pos": [36, 9], "text": "H2O", "color": "#3a2a10c0", "worn": 0.1},
        {"op": "noise", "rect": [0, 0, 64, 16], "amount": 0.3, "spread": 0.15},
        {"op": "spots", "rect": [0, 0, 64, 16], "color": "#8a4b22d0", "count": 8, "size": 1.3},
        {"op": "dither", "rect": [0, 10, 64, 16], "color": "#3a2412", "top": 0.0, "bottom": 0.55},
        {"op": "comment", "note": "[0,16,64,24] the base flange: dark red, bolts"},
        {"op": "fill", "rect": [0, 16, 64, 24], "color": "#8a1c18"},
        {"op": "noise", "rect": [0, 16, 64, 24], "amount": 0.35, "spread": 0.2},
        {"op": "pixels", "list": [[x, 19, "#d8d0c0"] for x in range(3, 64, 8)]},
        {"op": "dither", "rect": [0, 16, 64, 24], "color": "#2a1810", "top": 0.2, "bottom": 0.7},
        {"op": "comment", "note": "[0,24,64,32] the cap's sides: glossy red   [0,32,24,56] the cap seen from above"},
        {"op": "fill", "rect": [0, 24, 64, 32], "color": "#d42a20"},
        {"op": "line", "from": [0, 25], "to": [63, 25], "color": "#ff7a60"},
        {"op": "noise", "rect": [0, 24, 64, 32], "amount": 0.25, "spread": 0.15},
        {"op": "fill", "rect": [0, 32, 24, 56], "color": "#c4241c"},
        {"op": "edge", "rect": [2, 34, 22, 54], "color": "#ff6a50"},
        {"op": "edge", "rect": [6, 38, 18, 50], "color": "#8a1410"},
        {"op": "noise", "rect": [0, 32, 24, 56], "amount": 0.25, "spread": 0.15},
        {"op": "comment", "note": "[24,32,40,48] nozzle brass   [40,32,64,48] the big nut (steel)   [24,48,64,64] wet underside"},
        {"op": "fill", "rect": [24, 32, 40, 48], "color": "#b08a3a"},
        {"op": "edge", "rect": [24, 32, 40, 48], "color": "#5a4418"},
        {"op": "fill", "rect": [29, 37, 35, 43], "color": "#1a1408"},
        {"op": "noise", "rect": [24, 32, 40, 48], "amount": 0.3, "spread": 0.2},
        {"op": "fill", "rect": [40, 32, 64, 48], "color": "#8a9098"},
        {"op": "stripes", "rect": [40, 32, 64, 48], "colors": ["#a8b0b8", "#6a7078"], "width": 3},
        {"op": "noise", "rect": [40, 32, 64, 48], "amount": 0.3, "spread": 0.2},
        {"op": "fill", "rect": [24, 48, 64, 64], "color": "#2a1a14"},
    ]
    groups = [
        {"name": "Body", "origin": [0, 0, 0]},
        {"name": "Cap", "origin": [0, 11, 0], "parent": "Body"},
    ]
    elements = [
        {"type": "prism", "name": "flange", "group": "Body", "sides": 6, "center": [0, 0, 0], "height": 1.4, "radius": 4.4,
         "side_uv": [0, 16, 64, 24], "top_uv": [0, 16, 16, 24]},
        {"type": "prism", "name": "barrel", "group": "Body", "sides": 8, "center": [0, 1.4, 0], "height": 9.6, "radius_bottom": 3.3, "radius_top": 3.0,
         "side_uv": [0, 0, 64, 16]},
        {"type": "cube", "name": "nozzle_front", "group": "Body", "from": [-1.6, 5, -5], "to": [1.6, 8.2, -2.6],
         "faces": {"north": [24, 32, 40, 48], "east": [24, 32, 40, 40], "west": [24, 32, 40, 40], "up": [24, 32, 40, 40], "down": [24, 40, 40, 48]}},
        {"type": "cube", "name": "nozzle_east", "group": "Body", "from": [2.6, 6, -1.2], "to": [4.6, 8.4, 1.2],
         "faces": {"east": [24, 32, 40, 48], "north": [24, 32, 40, 40], "south": [24, 32, 40, 40], "up": [24, 32, 40, 40], "down": [24, 40, 40, 48]}},
        {"type": "cube", "name": "nozzle_west", "group": "Body", "from": [-4.6, 6, -1.2], "to": [-2.6, 8.4, 1.2],
         "faces": {"west": [24, 32, 40, 48], "north": [24, 32, 40, 40], "south": [24, 32, 40, 40], "up": [24, 32, 40, 40], "down": [24, 40, 40, 48]}},
        {"type": "prism", "name": "cap", "group": "Cap", "sides": 8, "center": [0, 11, 0], "height": 1.8, "radius_bottom": 3.6, "radius_top": 2.4,
         "side_uv": [0, 24, 64, 32], "top_uv": [0, 32, 24, 56], "bottom_uv": [24, 48, 40, 64]},
        {"type": "cube", "name": "nut", "group": "Cap", "from": [-1.1, 12.8, -1.1], "to": [1.1, 13.8, 1.1],
         "sides": [40, 32, 64, 40], "top": [40, 40, 52, 48]},
    ]
    write({"name": "fire_hydrant", "kind": "prop", "texture_size": 64, "seed": 42, "background": "#e0b020",
           "about": "A chunky yellow/red cyber hydrant (0.55 x 0.85 m) with side nozzles, a cyan sensor band and a red CAP "
                    "that pops off when burst. A MESS prop (Kind HYDRANT): wrench it open and a geyser erupts. 16 px = 1 m.",
           "paint": paint, "groups": groups, "elements": elements})


# =====================================================================================
# 3. MEOW-MART SHOPPING CART  (~0.75 m wide x 0.95 m tall x 1.05 m long)
# =====================================================================================
def shopping_cart():
    wire = "#c8ccd4"
    paint = [
        {"op": "comment", "note": "[0,0,32,24] basket sides: a chrome wire grid over a dark inside"},
        {"op": "fill", "rect": [0, 0, 32, 24], "color": "#14161c"},
        {"op": "stripes", "rect": [0, 0, 32, 24], "colors": [wire, "#00000000", "#00000000"], "width": 1},
        {"op": "stripes", "rect": [0, 0, 32, 24], "colors": [wire, "#00000000", "#00000000"], "width": 1, "direction": "horizontal"},
        {"op": "edge", "rect": [0, 0, 32, 24], "color": "#e8ecf4"},
        {"op": "fill", "rect": [0, 0, 32, 2], "color": "#e8ecf4"},
        {"op": "dither", "rect": [0, 12, 32, 24], "color": "#7a4420", "top": 0.0, "bottom": 0.25},
        {"op": "comment", "note": "[32,0,64,24] basket seen from above: wires over a forgotten sardine can and a fish"},
        {"op": "fill", "rect": [32, 0, 64, 24], "color": "#0e1014"},
        icon(CAN, 40, 13, "#5ff2ff"), icon(FISH, 50, 6, "#e0c070", "#0e1014"),
        {"op": "fill", "rect": [36, 4, 42, 8], "color": "#ff4fb0"},
        {"op": "stripes", "rect": [32, 0, 64, 24], "colors": [wire, "#00000000", "#00000000"], "width": 1},
        {"op": "stripes", "rect": [32, 0, 64, 24], "colors": [wire, "#00000000", "#00000000"], "width": 1, "direction": "horizontal"},
        {"op": "edge", "rect": [32, 0, 64, 24], "color": "#e8ecf4"},
        {"op": "comment", "note": "[0,24,32,32] the HANDLE: hot pink plastic with MEOW-MART (glows)"},
        {"op": "fill", "rect": [0, 24, 32, 32], "color": "#ff2a9a"},
        {"op": "line", "from": [0, 25], "to": [31, 25], "color": "#ffa8dc"},
        {"op": "text", "pos": [2, 26], "text": "MEOW", "color": "#ffffff", "spacing": 1},
        {"op": "pixels", "list": [[19, 28, "#ffffff"], [20, 28, "#ffffff"]]},
        {"op": "comment", "note": "[32,24,48,40] chrome tube   [48,24,64,40] tray under the basket   [0,32,16,48] black caster wheel"},
        {"op": "fill", "rect": [32, 24, 48, 40], "color": "#a8b0bc"},
        {"op": "stripes", "rect": [32, 24, 48, 40], "colors": ["#e8ecf4", "#a8b0bc", "#7a808c"], "width": 1},
        {"op": "fill", "rect": [48, 24, 64, 40], "color": "#1a1c22"},
        {"op": "stripes", "rect": [48, 24, 64, 40], "colors": [wire, "#00000000", "#00000000"], "width": 1, "direction": "horizontal"},
        {"op": "fill", "rect": [0, 32, 16, 48], "color": "#16161a"},
        {"op": "edge", "rect": [3, 35, 13, 45], "color": "#3a3a44"},
        {"op": "fill", "rect": [7, 39, 9, 41], "color": "#ff2a9a"},
        {"op": "noise", "rect": [0, 32, 16, 48], "amount": 0.3, "spread": 0.2},
    ]
    groups = [
        {"name": "Cart", "origin": [0, 0, 0]},
        {"name": "Handle", "origin": [0, 15.6, 8.2], "parent": "Cart"},
        {"name": "Wheels", "origin": [0, 1, 0], "parent": "Cart"},
    ]
    leg = {"faces": {"north": [32, 24, 48, 40], "south": [32, 24, 48, 40], "east": [32, 24, 48, 40], "west": [32, 24, 48, 40]}}
    elements = [
        {"type": "cube", "name": "basket", "group": "Cart", "from": [-6, 6.5, -8.4], "to": [6, 15, 7],
         "sides": [0, 0, 32, 24], "top": [32, 0, 64, 24], "bottom": [48, 24, 64, 40]},
        {"type": "cube", "name": "tray", "group": "Cart", "from": [-5.2, 2.6, -7.6], "to": [5.2, 3.3, 6.4],
         "sides": [48, 24, 64, 26], "top": [48, 24, 64, 40]},
        dict(leg, type="cube", name="leg_fl", group="Cart", **{"from": [-5.6, 1.6, -7.8], "to": [-4.8, 6.5, -7.0]}),
        dict(leg, type="cube", name="leg_fr", group="Cart", **{"from": [4.8, 1.6, -7.8], "to": [5.6, 6.5, -7.0]}),
        dict(leg, type="cube", name="leg_bl", group="Cart", **{"from": [-5.6, 1.6, 6.2], "to": [-4.8, 15.6, 7.0]}),
        dict(leg, type="cube", name="leg_br", group="Cart", **{"from": [4.8, 1.6, 6.2], "to": [5.6, 15.6, 7.0]}),
        {"type": "cube", "name": "handle", "group": "Handle", "from": [-6.6, 15, 7.4], "to": [6.6, 16.4, 9],
         "faces": {"north": [0, 24, 32, 32], "south": [0, 24, 32, 32], "up": [0, 24, 32, 32], "down": [0, 24, 32, 32],
                   "east": [0, 24, 4, 32], "west": [0, 24, 4, 32]}},
    ]
    for name, x, z in (("wheel_fl", -5.2, -7.4), ("wheel_fr", 5.2, -7.4), ("wheel_bl", -5.2, 6.6), ("wheel_br", 5.2, 6.6)):
        elements.append({"type": "cube", "name": name, "group": "Wheels", "from": [x - 0.5, 0, z - 0.9], "to": [x + 0.5, 1.8, z + 0.9],
                         "faces": {"east": [0, 32, 16, 48], "west": [0, 32, 16, 48], "north": [0, 32, 4, 48], "south": [0, 32, 4, 48]}})
    write({"name": "shopping_cart", "kind": "prop", "texture_size": 64, "seed": 43, "background": "#14161c",
           "about": "A Meow-Mart shopping cart (0.75 x 0.95 x 1.05 m): chrome wire basket, tray, four chunky casters (Wheels) and a "
                    "glowing hot-pink HANDLE. Front (the basket's nose) faces -Z. A MESS prop (Kind CART): shove it and it rolls. 16 px = 1 m.",
           "paint": paint, "groups": groups, "elements": elements})


# =====================================================================================
# 4. NEON A-FRAME STREET SIGN  (~0.75 m wide x 1.05 m tall x 0.65 m deep)
# =====================================================================================
def neon_sign_prop():
    paint = [
        {"op": "comment", "note": "[0,0,32,48] the neon face: black glass with a pink fish + a cyan noodle bowl (glows)"},
        {"op": "fill", "rect": [0, 0, 32, 48], "color": "#07060c"},
        {"op": "edge", "rect": [1, 1, 31, 47], "color": "#5ff2ff"},
        {"op": "comment", "note": "a big outline fish"},
        {"op": "line", "from": [6, 12], "to": [12, 6], "color": "#ff4fc0"}, {"op": "line", "from": [12, 6], "to": [20, 6], "color": "#ff4fc0"},
        {"op": "line", "from": [20, 6], "to": [24, 10], "color": "#ff4fc0"}, {"op": "line", "from": [24, 10], "to": [28, 6], "color": "#ff4fc0"},
        {"op": "line", "from": [28, 6], "to": [28, 18], "color": "#ff4fc0"}, {"op": "line", "from": [28, 18], "to": [24, 14], "color": "#ff4fc0"},
        {"op": "line", "from": [24, 14], "to": [20, 18], "color": "#ff4fc0"}, {"op": "line", "from": [20, 18], "to": [12, 18], "color": "#ff4fc0"},
        {"op": "line", "from": [12, 18], "to": [6, 12], "color": "#ff4fc0"},
        {"op": "pixels", "list": [[11, 11, "#ffffff"], [12, 11, "#ffffff"]]},
        {"op": "comment", "note": "a noodle bowl with chopsticks"},
        {"op": "line", "from": [6, 30], "to": [26, 30], "color": "#5ff2ff"}, {"op": "line", "from": [6, 30], "to": [10, 37], "color": "#5ff2ff"},
        {"op": "line", "from": [26, 30], "to": [22, 37], "color": "#5ff2ff"}, {"op": "line", "from": [10, 37], "to": [22, 37], "color": "#5ff2ff"},
        {"op": "line", "from": [9, 28], "to": [11, 25], "color": "#ffd84a"}, {"op": "line", "from": [13, 28], "to": [12, 24], "color": "#ffd84a"},
        {"op": "line", "from": [17, 28], "to": [19, 24], "color": "#ffd84a"},
        {"op": "line", "from": [20, 29], "to": [28, 21], "color": "#ff4fc0"}, {"op": "line", "from": [22, 29], "to": [29, 23], "color": "#ff4fc0"},
        {"op": "text", "pos": [4, 40], "text": "NOODLE", "color": "#5ff2ff", "spacing": 1},
        {"op": "comment", "note": "[32,0,64,48] the board's frame: dark gunmetal with rivets and grime"},
        {"op": "fill", "rect": [32, 0, 64, 48], "color": "#2a2c34"},
        {"op": "edge", "rect": [32, 0, 64, 48], "color": "#14151a"},
        {"op": "edge", "rect": [34, 2, 62, 46], "color": "#4a4e5a"},
        {"op": "pixels", "list": [[35, 3, "#9aa0b0"], [60, 3, "#9aa0b0"], [35, 44, "#9aa0b0"], [60, 44, "#9aa0b0"]]},
        {"op": "noise", "rect": [32, 0, 64, 48], "amount": 0.3, "spread": 0.18},
        {"op": "dither", "rect": [32, 30, 64, 48], "color": "#120e0a", "top": 0.0, "bottom": 0.6},
        {"op": "comment", "note": "[32,48,64,64] the hinge bar: steel with a hazard stripe"},
        {"op": "fill", "rect": [32, 48, 64, 64], "color": "#6a7078"},
        {"op": "stripes", "rect": [32, 52, 64, 58], "colors": ["#ffd23a", "#1a1a1a"], "width": 2},
        {"op": "noise", "rect": [32, 48, 64, 64], "amount": 0.3, "spread": 0.2},
    ]
    groups = [
        {"name": "Frame", "origin": [0, 0, 0]},
        {"name": "SignFace", "origin": [0, 17, 0], "parent": "Frame"},
    ]
    board = {"faces": {"north": [32, 0, 64, 48], "south": [32, 0, 64, 48], "east": [32, 0, 34, 48], "west": [32, 0, 34, 48]}}
    elements = [
        dict(board, type="cube", name="board_front", group="Frame", origin=[0, 17, 0], rotation=[17, 0, 0], **{"from": [-6, -0.6, -0.9], "to": [6, 17, -0.1]}),
        dict(board, type="cube", name="board_back", group="Frame", origin=[0, 17, 0], rotation=[-17, 0, 0], **{"from": [-6, -0.6, 0.1], "to": [6, 17, 0.9]}),
        {"type": "cube", "name": "hinge", "group": "Frame", "from": [-6.4, 16.4, -0.9], "to": [6.4, 17.6, 0.9],
         "sides": [32, 48, 64, 64], "top": [32, 48, 64, 64]},
        {"type": "cube", "name": "face_front", "group": "SignFace", "origin": [0, 17, 0], "rotation": [17, 0, 0],
         "from": [-5.2, 1.0, -1.05], "to": [5.2, 15.6, -0.9], "faces": {"north": [0, 0, 32, 48]}},
        {"type": "cube", "name": "face_back", "group": "SignFace", "origin": [0, 17, 0], "rotation": [-17, 0, 0],
         "from": [-5.2, 1.0, 0.9], "to": [5.2, 15.6, 1.05], "faces": {"south": [0, 0, 32, 48]}},
    ]
    write({"name": "neon_sign_prop", "kind": "prop", "texture_size": 64, "seed": 44, "background": "#2a2c34",
           "about": "A sidewalk A-frame sandwich board (0.75 x 1.05 x 0.65 m): gunmetal frame, a glowing neon fish + noodle bowl "
                    "SIGNFACE on both sides. A MESS prop (Kind NEON_SIGN): kick it over and the neon dies in a shower of sparks. 16 px = 1 m.",
           "paint": paint, "groups": groups, "elements": elements})


# =====================================================================================
# 5. ALLEY DUMPSTER  (~2.1 m wide x 1.3 m tall x 1.25 m deep)
# =====================================================================================
def dumpster():
    paint = [
        {"op": "comment", "note": "[0,0,64,24] front / back: ribbed teal-green steel, OVERCLEAN stencil, rust and grime"},
        {"op": "fill", "rect": [0, 0, 64, 24], "color": "#2f6a5a"},
        {"op": "stripes", "rect": [0, 0, 64, 24], "colors": ["#3c7e6c", "#2f6a5a", "#24564a", "#2f6a5a"], "width": 2},
        {"op": "fill", "rect": [0, 0, 64, 2], "color": "#4a9080"},
        {"op": "fill", "rect": [8, 7, 56, 14], "color": "#1c3e36c0"},
        {"op": "text", "pos": [10, 8], "text": "OVERCLEAN", "color": "#e8e0c0", "spacing": 2, "worn": 0.15},
        {"op": "text", "pos": [22, 16], "text": "NO CATS", "color": "#d8432f", "spacing": 1, "worn": 0.1},
        {"op": "noise", "rect": [0, 0, 64, 24], "amount": 0.3, "spread": 0.16},
        {"op": "spots", "rect": [0, 0, 64, 24], "color": "#8a4b22d0", "count": 12, "size": 1.8},
        {"op": "spots", "rect": [0, 14, 64, 24], "color": "#5a3014d0", "count": 8, "size": 2.2},
        {"op": "dither", "rect": [0, 12, 64, 24], "color": "#1a1410", "top": 0.0, "bottom": 0.7},
        {"op": "comment", "note": "[0,24,32,48] the two ends"},
        {"op": "fill", "rect": [0, 24, 32, 48], "color": "#2b6254"},
        {"op": "stripes", "rect": [0, 24, 32, 48], "colors": ["#36786a", "#2b6254", "#225044"], "width": 2},
        {"op": "noise", "rect": [0, 24, 32, 48], "amount": 0.3, "spread": 0.16},
        {"op": "spots", "rect": [0, 24, 32, 48], "color": "#8a4b22d0", "count": 6, "size": 1.6},
        {"op": "dither", "rect": [0, 36, 32, 48], "color": "#1a1410", "top": 0.0, "bottom": 0.7},
        {"op": "comment", "note": "[32,24,64,40] the lid seen from above: darker, ribbed   [32,40,64,48] lid edge"},
        {"op": "fill", "rect": [32, 24, 64, 40], "color": "#234c42"},
        {"op": "stripes", "rect": [32, 24, 64, 40], "colors": ["#2f6052", "#1c3e36"], "width": 2, "direction": "horizontal"},
        {"op": "noise", "rect": [32, 24, 64, 40], "amount": 0.3, "spread": 0.16},
        {"op": "spots", "rect": [32, 24, 64, 40], "color": "#d8d0b090", "count": 4, "size": 1.0},
        {"op": "fill", "rect": [32, 40, 64, 48], "color": "#1e4038"},
        {"op": "line", "from": [32, 40], "to": [63, 40], "color": "#4a9080"},
        {"op": "noise", "rect": [32, 40, 64, 48], "amount": 0.3, "spread": 0.2},
        {"op": "comment", "note": "[0,48,32,64] inside: black trash bags, a fish skeleton, a can (seen when the lid is open)"},
        {"op": "fill", "rect": [0, 48, 32, 64], "color": "#0c0c0e"},
        {"op": "spots", "rect": [0, 48, 32, 64], "color": "#22242a", "count": 8, "size": 3.0},
        {"op": "spots", "rect": [0, 48, 32, 64], "color": "#3a3f2a", "count": 4, "size": 2.0},
        {"op": "pixels", "list": [[x, 56, "#c9c3b0"] for x in range(8, 16)] + [[9, 55, "#c9c3b0"], [9, 57, "#c9c3b0"], [11, 55, "#c9c3b0"],
                                  [11, 57, "#c9c3b0"], [13, 55, "#c9c3b0"], [13, 57, "#c9c3b0"], [16, 55, "#c9c3b0"], [16, 57, "#c9c3b0"]]},
        icon(CAN, 22, 51, "#5ff2ff"),
        {"op": "comment", "note": "[32,48,48,56] lift lugs (steel)   [48,48,64,56] ribs   [32,56,64,64] dark plinth"},
        {"op": "fill", "rect": [32, 48, 48, 56], "color": "#6a7078"},
        {"op": "edge", "rect": [32, 48, 48, 56], "color": "#3a3e44"},
        {"op": "noise", "rect": [32, 48, 48, 56], "amount": 0.35, "spread": 0.2},
        {"op": "fill", "rect": [48, 48, 64, 56], "color": "#3c7e6c"},
        {"op": "line", "from": [48, 48], "to": [63, 48], "color": "#5aa090"},
        {"op": "spots", "rect": [48, 48, 64, 56], "color": "#8a4b22d0", "count": 3, "size": 1.2},
        {"op": "fill", "rect": [32, 56, 64, 64], "color": "#18181c"},
        {"op": "noise", "rect": [32, 56, 64, 64], "amount": 0.35, "spread": 0.2},
    ]
    groups = [
        {"name": "Body", "origin": [0, 0, 0]},
        {"name": "Lid", "origin": [0, 19, 10.2], "parent": "Body"},
    ]
    elements = [
        {"type": "cube", "name": "plinth", "group": "Body", "from": [-15, 0, -8.5], "to": [15, 1.6, 8.5], "sides": [32, 56, 64, 64]},
        {"type": "cube", "name": "bin", "group": "Body", "from": [-16.8, 1.6, -10], "to": [16.8, 19, 10],
         "faces": {"north": [0, 0, 64, 24], "south": [0, 0, 64, 24], "east": [0, 24, 32, 48], "west": [0, 24, 32, 48], "up": [0, 48, 32, 64]}},
        {"type": "cube", "name": "lug_east", "group": "Body", "from": [16.8, 11, -4], "to": [18.4, 14, 4],
         "faces": {"east": [32, 48, 48, 56], "north": [32, 48, 34, 56], "south": [32, 48, 34, 56], "up": [32, 48, 48, 50], "down": [32, 54, 48, 56]}},
        {"type": "cube", "name": "lug_west", "group": "Body", "from": [-18.4, 11, -4], "to": [-16.8, 14, 4],
         "faces": {"west": [32, 48, 48, 56], "north": [32, 48, 34, 56], "south": [32, 48, 34, 56], "up": [32, 48, 48, 50], "down": [32, 54, 48, 56]}},
        {"type": "cube", "name": "lid", "group": "Lid", "from": [-17.2, 19, -10.6], "to": [17.2, 20.6, 10.2],
         "faces": {"up": [32, 24, 64, 40], "down": [0, 48, 32, 64], "north": [32, 40, 64, 48], "south": [32, 40, 64, 48],
                   "east": [32, 40, 40, 48], "west": [32, 40, 40, 48]}},
    ]
    for i, x in enumerate((-9.0, 0.0, 9.0)):
        elements.append({"type": "cube", "name": "rib_%d" % i, "group": "Body", "from": [x - 1.2, 2.5, -10.7], "to": [x + 1.2, 18.4, -10],
                         "faces": {"north": [48, 48, 64, 56], "east": [48, 48, 50, 56], "west": [48, 48, 50, 56], "up": [48, 48, 64, 50]}})
    write({"name": "dumpster", "kind": "prop", "texture_size": 64, "seed": 45, "background": "#2f6a5a",
           "about": "A heavy ribbed teal alley dumpster (2.1 x 1.3 x 1.25 m) with rust, grime, side lift lugs and a hinged LID "
                    "(pivot on the back hinge). A MESS prop (Kind DUMPSTER): rummage it and the lid flies open. 16 px = 1 m.",
           "paint": paint, "groups": groups, "elements": elements})


if __name__ == "__main__":
    vending_machine()
    fire_hydrant()
    shopping_cart()
    neon_sign_prop()
    dumpster()
