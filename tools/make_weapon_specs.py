"""CYPURRPUNK: writes the model RECIPES (spec JSON) for the 8 weapons (ROADMAP.md section 5 #6).

    python tools/make_weapon_specs.py                         (writes tools/model_specs/<gun>.json)
    python tools/cypurr_models.py all tools/model_specs/pistol.json    (-> .bbmodel + .glb, then check)

    or build all eight in one go:   python tools/make_weapon_specs.py --build

Then the .bbmodel files in models/blockbench/ are the master copies: double-click one to open it in
Blockbench, move or repaint things, Ctrl+S, and re-export it (python tools/cypurr_models.py export
models/blockbench/pistol.bbmodel). Running THIS script again overwrites those hand edits with the
recipe, so only do that on purpose (like tools/make_creature_specs.py).

UNITS: the recipes below are written in CENTIMETRES (a gun is ~30 cm long: easier to read than
4.8 "pixels"). They are turned into Blockbench pixels on the way out: 16 px = 1 m, so 1 cm = 0.16 px.
Y is up, the barrel points -Z (forward). Melee weapons (FROZEN TUNA, NEON BAT) stand up along +Y with
the handle at the origin, like the old box models: their scene tilts the Model forward.

ALL EIGHT SHARE ONE 128x128 TEXTURE ATLAS (`atlas_paint()`), a grid of 16x16 swatches:
  row 0: DARK_STEEL  CHROME_METAL RUST_BRASS  POLY_BLACK  WOOD_ORANGE  TAPE_WRAP  COIL_HEAT  LASER_CAUTION
  row 1: NEON_PINK   NEON_CYAN    NEON_GREEN  TUNA_EYE    TUNA_FROST   CUCUMBER   YARN_WOOL  PAW_GRIP
  row 2: TUNA_SKIN (32 wide)     TUNA_BELLY (32 wide)     CAN_LABEL (32 wide)     DANGER_LABEL (32 wide)
  row 3: SLIDE_PORTS BARREL_FINS  VENTS       BORE        CAN_LID      DIAL       CO2_TANK   CAPACITOR
  row 4: NEON_SPIRAL STUD_RING    KNURL       ANODIZED    LENS         PVC        INDUSTRIAL CUKE_END
  row 5: EAR_SIGHT   (rows 5-7 otherwise spare: room for new guns)
On round parts (barrels, cans, the fish) a swatch's X runs ALONG the part and its Y runs ROUND it,
so vertical stripes become rings (cooling fins, coil windings) and diagonal lines become a spiral.

GROUPS the game uses (scenes/items/<gun>.tscn, scripts/items/weapon.gd):
  Body       everything plain
  HeatCoil   (PURR-TOMMY) glows bolt colour -> red-hot as the gun heats (weapon.gd _update_heat_look)
  any other  glows: listed in the scene's `glow_parts` (whole part glows one colour) or `neon_parts`
             (only the BRIGHT painted pixels glow, in their own colour: neon tubes, frost, slits)
  @Muzzle    a marker at the barrel tip: weapon.gd moves Model/Muzzle there, so bolts start at it.
"""
from __future__ import annotations

import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC_DIR = os.path.join(HERE, "model_specs")
sys.path.insert(0, HERE)
from make_creature_specs import ellipse, hazard, wavy_stripes  # noqa: E402  (shared pixel-art helpers)

PX_PER_CM = 16.0 / 100.0
SIZE = 128


def px(v: float) -> float:
    return round(v * PX_PER_CM, 4)


def pv(p) -> list:
    return [px(c) for c in p]


# =====================================================================================
# The shared texture atlas
# =====================================================================================

def sw(col: int, row: int, w: int = 1, h: int = 1) -> list:
    """The UV rect of a swatch (16x16 grid cell; w/h = cells wide/tall)."""
    return [col * 16, row * 16, (col + w) * 16, (row + h) * 16]


UV = {
    "DARK_STEEL": sw(0, 0), "CHROME_METAL": sw(1, 0), "RUST_BRASS": sw(2, 0), "POLY_BLACK": sw(3, 0),
    "WOOD_ORANGE": sw(4, 0), "TAPE_WRAP": sw(5, 0), "COIL_HEAT": sw(6, 0), "LASER_CAUTION": sw(7, 0),
    "NEON_PINK": sw(0, 1), "NEON_CYAN": sw(1, 1), "NEON_GREEN": sw(2, 1), "TUNA_EYE": sw(3, 1),
    "TUNA_FROST": sw(4, 1), "CUCUMBER_SKIN": sw(5, 1), "YARN_WOOL": sw(6, 1), "PAW_GRIP": sw(7, 1),
    "TUNA_SKIN": sw(0, 2, 2), "TUNA_BELLY": sw(2, 2, 2), "CAN_LABEL": sw(4, 2, 2), "DANGER_LABEL": sw(6, 2, 2),
    "SLIDE_PORTS": sw(0, 3), "BARREL_FINS": sw(1, 3), "VENTS": sw(2, 3), "BORE": sw(3, 3),
    "CAN_LID": sw(4, 3), "DIAL": sw(5, 3), "CO2_TANK": sw(6, 3), "CAPACITOR": sw(7, 3),
    "NEON_SPIRAL": sw(0, 4), "STUD_RING": sw(1, 4), "KNURL": sw(2, 4), "ANODIZED": sw(3, 4),
    "LENS": sw(4, 4), "PVC": sw(5, 4), "INDUSTRIAL": sw(6, 4), "CUKE_END": sw(7, 4),
    "EAR_SIGHT": sw(0, 5),
}
globals().update(UV)  # so the recipes can just say DARK_STEEL


def _pattern(rect, test, color) -> dict:
    """Pixels of `rect` where test(local_x, local_y) is true."""
    x1, y1, x2, y2 = rect
    return {"op": "pixels", "list": [[x, y, color] for y in range(y1, y2) for x in range(x1, x2) if test(x - x1, y - y1)]}


def _centre(rect):
    return (rect[0] + rect[2]) / 2.0, (rect[1] + rect[3]) / 2.0


def atlas_paint() -> list:
    ops = [{"op": "comment", "note": __doc__.split("ALL EIGHT SHARE")[1].split("GROUPS")[0].strip()}]
    add = ops.append

    def steel(r):
        x1, y1, x2, y2 = r
        add({"op": "gradient", "rect": r, "top": "#566072", "bottom": "#2c313c"})
        add({"op": "noise", "rect": r, "amount": 0.25, "spread": 0.1})
        add({"op": "line", "from": [x1, y1], "to": [x2 - 1, y1], "color": "#7c8696"})       # lit top edge
        add({"op": "line", "from": [x1, y1], "to": [x1, y2 - 1], "color": "#555c6a"})
        for x, y in [(x1 + 2, y1 + 3), (x2 - 3, y1 + 3), (x1 + 2, y2 - 3), (x2 - 3, y2 - 3)]:  # rivets
            add({"op": "pixels", "list": [[x, y, "#a0a9b8"], [x, y + 1, "#0e1014"]]})

    # --- Row 0: metals, grips, heat, hazard ---
    steel(DARK_STEEL)
    x1, y1, x2, y2 = CHROME_METAL
    add({"op": "gradient", "rect": CHROME_METAL, "top": "#e4e9f0", "bottom": "#8c95a2"})
    add({"op": "noise", "rect": CHROME_METAL, "amount": 0.15, "spread": 0.08})
    add({"op": "line", "from": [x1 + 2, y1 + 11], "to": [x1 + 9, y1 + 4], "color": "#ffffff"})   # scratches
    add({"op": "line", "from": [x1 + 8, y1 + 14], "to": [x1 + 14, y1 + 8], "color": "#c0c8d4"})
    for cx, cy in [(x1 + 3, y1 + 3), (x2 - 4, y2 - 4)]:  # screw heads
        add({"op": "pixels", "list": [[cx - 1, cy, "#4a505a"], [cx + 1, cy, "#4a505a"], [cx, cy - 1, "#4a505a"],
                                      [cx, cy + 1, "#4a505a"], [cx, cy, "#20242a"]]})
    add({"op": "gradient", "rect": RUST_BRASS, "top": "#d8a850", "bottom": "#7a5020"})
    add({"op": "noise", "rect": RUST_BRASS, "amount": 0.3, "spread": 0.15})
    add({"op": "spots", "rect": RUST_BRASS, "color": "#5c9a7a", "count": 4, "size": 1.3})       # patina
    add({"op": "edge", "rect": RUST_BRASS, "color": "#4a3010"})
    add({"op": "fill", "rect": POLY_BLACK, "color": "#2a2a34"})
    add({"op": "stripes", "rect": POLY_BLACK, "colors": ["#3c3c4a", "#24242c"], "width": 2, "direction": "horizontal"})
    add({"op": "noise", "rect": POLY_BLACK, "amount": 0.1, "spread": 0.1})
    add({"op": "fill", "rect": WOOD_ORANGE, "color": "#c86e2c"})
    add(wavy_stripes(WOOD_ORANGE, "#7c3a16", every=4, thick=1, wave=1.0, period=3.0))         # woodgrain grooves
    add({"op": "noise", "rect": WOOD_ORANGE, "amount": 0.2, "spread": 0.1})
    add({"op": "edge", "rect": WOOD_ORANGE, "color": "#5a2a10"})
    add({"op": "fill", "rect": TAPE_WRAP, "color": "#dcd4bc"})
    add(_pattern(TAPE_WRAP, lambda x, y: (x + y) % 5 == 0, "#a49a80"))                         # wrap seams
    add({"op": "noise", "rect": TAPE_WRAP, "amount": 0.25, "spread": 0.12})
    add({"op": "spots", "rect": TAPE_WRAP, "color": "#8a8068", "count": 3, "size": 1.5})       # grime
    add(_pattern(TAPE_WRAP, lambda x, y: (x == 0 or x == 15) and y % 3 == 1, "#f6f2e6"))       # frayed ends
    add({"op": "fill", "rect": COIL_HEAT, "color": "#2a120a"})
    add({"op": "stripes", "rect": COIL_HEAT, "colors": ["#ff9a48", "#c05a1c", "#2a120a"], "width": 1})  # windings
    add({"op": "line", "from": [COIL_HEAT[0], COIL_HEAT[1] + 7], "to": [COIL_HEAT[2] - 1, COIL_HEAT[1] + 7], "color": "#ff5a20"})
    add(hazard(LASER_CAUTION))
    cx, cy = _centre(LASER_CAUTION)
    add(ellipse(cx, cy, 4.5, 4.5, "#14141a"))
    add(ellipse(cx, cy, 3.5, 3.5, "#ff2020"))                                                # the laser diode
    add({"op": "pixels", "list": [[int(cx) - 1, int(cy) - 1, "#fff0f0"], [int(cx), int(cy) - 1, "#fff0f0"]]})

    # --- Row 1: neon + feline / food ---
    for rect, base, mid, rim in ((NEON_PINK, "#ff2080", "#ff70b0", "#b01058"), (NEON_CYAN, "#00f0ff", "#80f8ff", "#0090b0")):
        x1, y1, x2, y2 = rect
        add({"op": "fill", "rect": rect, "color": base})
        add({"op": "fill", "rect": [x1, y1 + 4, x2, y2 - 4], "color": mid})
        add({"op": "fill", "rect": [x1, y1 + 6, x2, y2 - 6], "color": "#ffffff"})           # white-hot core
        add({"op": "edge", "rect": rect, "color": rim})
    add({"op": "fill", "rect": NEON_GREEN, "color": "#40ff20"})
    add({"op": "spots", "rect": NEON_GREEN, "color": "#20a010", "count": 5, "size": 1.5})      # sludge bubbles
    add({"op": "spots", "rect": NEON_GREEN, "color": "#c0ffb0", "count": 3, "size": 1.0})
    add({"op": "edge", "rect": NEON_GREEN, "color": "#189008"})
    cx, cy = _centre(TUNA_EYE)
    add({"op": "fill", "rect": TUNA_EYE, "color": "#9fb0c0"})
    add(ellipse(cx, cy, 7, 7, "#eef3f8"))                                                    # white rim
    add(ellipse(cx, cy, 4.8, 4.8, "#3a4048"))
    add(ellipse(cx, cy, 3.6, 3.6, "#050508"))                                                # dead black pupil
    add({"op": "pixels", "list": [[int(cx) - 2, int(cy) - 2, "#ffffff"], [int(cx) - 1, int(cy) - 2, "#ffffff"], [int(cx) - 2, int(cy) - 1, "#ffffff"]]})
    add({"op": "fill", "rect": TUNA_FROST, "color": "#bfeaff"})
    add({"op": "noise", "rect": TUNA_FROST, "amount": 0.5, "spread": 0.15})
    add({"op": "spots", "rect": TUNA_FROST, "color": "#ffffff", "count": 8, "size": 1.0})
    add({"op": "spots", "rect": TUNA_FROST, "color": "#78bede", "count": 4, "size": 1.0})
    x1, y1, x2, y2 = CUCUMBER_SKIN
    add({"op": "gradient", "rect": CUCUMBER_SKIN, "top": "#2a6a28", "bottom": "#143a16"})
    for y in (y1 + 3, y1 + 8, y1 + 13):                                                      # pale ribs, end to end
        add({"op": "line", "from": [x1, y], "to": [x2 - 1, y], "color": "#b8c860"})
    add({"op": "spots", "rect": CUCUMBER_SKIN, "color": "#6aa030", "count": 7, "size": 1.0})   # warts
    add({"op": "noise", "rect": CUCUMBER_SKIN, "amount": 0.2, "spread": 0.1})
    add({"op": "fill", "rect": YARN_WOOL, "color": "#18b8e0"})
    add(_pattern(YARN_WOOL, lambda x, y: (x + y) % 4 == 0, "#ff3c9c"))                         # cross-hatched wool
    add(_pattern(YARN_WOOL, lambda x, y: (x - y) % 4 == 2, "#a0f0ff"))
    add({"op": "noise", "rect": YARN_WOOL, "amount": 0.2, "spread": 0.1})
    add({"op": "fill", "rect": PAW_GRIP, "color": "#2a2a34"})
    add({"op": "stripes", "rect": PAW_GRIP, "colors": ["#3c3c4a", "#24242c"], "width": 2, "direction": "horizontal"})
    cx, cy = _centre(PAW_GRIP)
    add(ellipse(cx, cy + 2.5, 3.4, 2.7, "#ff4f9a"))                                          # stamped paw print
    for dx, dy in ((-3.6, -2.0), (-1.3, -4.2), (1.3, -4.2), (3.6, -2.0)):
        add(ellipse(cx + dx, cy + dy, 1.3, 1.4, "#ff4f9a"))

    # --- Row 2: the wide swatches ---
    x1, y1, x2, y2 = TUNA_SKIN  # X = tail -> head, Y = back (dorsal) -> belly
    add({"op": "gradient", "rect": [x1, y1, x2, y1 + 12], "top": "#142250", "bottom": "#3f72b0"})
    for row in range(y1 + 2, y1 + 11, 3):                                                    # scale arcs
        add({"op": "pixels", "list": [[x, row, "#6a9ad6"] for x in range(x1 + (row // 3) % 2 * 2, x2, 4)]
                                     + [[x + 1, row - 1, "#5a88c8"] for x in range(x1 + (row // 3) % 2 * 2, x2 - 1, 4)]})
    add({"op": "fill", "rect": [x1, y1 + 12, x2, y2], "color": "#dce9f2"})                   # white belly edge
    add({"op": "line", "from": [x1, y1 + 12], "to": [x2 - 1, y1 + 12], "color": "#8ab0d0"})
    add({"op": "spots", "rect": TUNA_SKIN, "color": "#ffffff", "count": 7, "size": 0.8})        # frost speckles
    add({"op": "noise", "rect": TUNA_SKIN, "amount": 0.15, "spread": 0.08})
    x1, y1, x2, y2 = TUNA_BELLY  # the head: same top, pale iridescent belly, gill line
    add({"op": "gradient", "rect": [x1, y1, x2, y1 + 5], "top": "#1a2a58", "bottom": "#8fb8d0"})
    add({"op": "gradient", "rect": [x1, y1 + 5, x2, y2], "top": "#cfe8f0", "bottom": "#a6cbd8"})
    add({"op": "spots", "rect": TUNA_BELLY, "color": "#9ae6ee", "count": 6, "size": 1.2})
    add({"op": "spots", "rect": TUNA_BELLY, "color": "#e8d8f8", "count": 3, "size": 1.0})
    add({"op": "pixels", "list": [[x1 + 6 + round(1.5 * math.sin((y - y1) / 3.0)), y, "#3a5870"] for y in range(y1 + 3, y2 - 2)]
                                 + [[x1 + 7 + round(1.5 * math.sin((y - y1) / 3.0)), y, "#7a98b0"] for y in range(y1 + 3, y2 - 2)]})
    add({"op": "line", "from": [x2 - 6, y1 + 10], "to": [x2 - 1, y1 + 9], "color": "#304050"})  # grumpy mouth
    x1, y1, x2, y2 = CAN_LABEL  # wraps ROUND the tuna-tin drum
    add({"op": "fill", "rect": CAN_LABEL, "color": "#2048b8"})
    add({"op": "fill", "rect": [x1, y1, x2, y1 + 2], "color": "#f0c020"})
    add({"op": "fill", "rect": [x1, y2 - 2, x2, y2], "color": "#f0c020"})
    add({"op": "text", "pos": [x1 + 2, y1 + 6], "text": "TUNA", "color": "#ffffff"})
    add(ellipse(x1 + 25, y1 + 9.5, 3.2, 3.0, "#ffffff"))                                       # cat head silhouette
    add({"op": "pixels", "list": [[x1 + 22, y1 + 5, "#ffffff"], [x1 + 22, y1 + 6, "#ffffff"], [x1 + 23, y1 + 6, "#ffffff"],
                                  [x1 + 28, y1 + 5, "#ffffff"], [x1 + 28, y1 + 6, "#ffffff"], [x1 + 27, y1 + 6, "#ffffff"],
                                  [x1 + 24, y1 + 9, "#2048b8"], [x1 + 26, y1 + 9, "#2048b8"]]})
    x1, y1, x2, y2 = DANGER_LABEL
    add({"op": "fill", "rect": DANGER_LABEL, "color": "#ffc61a"})
    add({"op": "edge", "rect": DANGER_LABEL, "color": "#14141a"})
    add({"op": "text", "pos": [x1 + 4, y1 + 2], "text": "DANGER", "color": "#14141a"})
    add({"op": "text", "pos": [x1 + 6, y1 + 9], "text": "LASER", "color": "#14141a"})
    add({"op": "pixels", "list": [[x2 - 3, y1 + 11, "#ff2020"], [x2 - 3, y1 + 12, "#ff2020"]]})

    # --- Row 3 ---
    steel(SLIDE_PORTS)
    x1, y1, x2, y2 = SLIDE_PORTS
    for k in range(3):                                                                      # cooling port cutouts
        add({"op": "fill", "rect": [x1 + 2 + k * 4, y1 + 4, x1 + 4 + k * 4, y1 + 9], "color": "#050508"})
        add({"op": "pixels", "list": [[x1 + 2 + k * 4, y1 + 8, "#ff2080"], [x1 + 3 + k * 4, y1 + 8, "#ff2080"]]})
    add(_pattern([x2 - 3, y1 + 3, x2 - 1, y2 - 3], lambda x, y: y % 2 == 0, "#0e1014"))         # rear serrations
    add({"op": "text", "pos": [x1 + 2, y1 + 10], "text": "P9", "color": "#8a93a3"})
    add({"op": "fill", "rect": BARREL_FINS, "color": "#262a34"})
    add({"op": "stripes", "rect": BARREL_FINS, "colors": ["#6a7282", "#3a404c", "#101216"], "width": 1})
    add({"op": "fill", "rect": VENTS, "color": "#2e2e3a"})
    x1, y1, x2, y2 = VENTS
    for k in range(5):                                                                      # pink-lit slits
        add({"op": "fill", "rect": [x1 + 2 + k * 3, y1 + 3, x1 + 3 + k * 3, y2 - 3], "color": "#ff3c8c"})
    add({"op": "edge", "rect": VENTS, "color": "#101016"})
    cx, cy = _centre(BORE)
    add({"op": "fill", "rect": BORE, "color": "#2a2e36"})
    add(ellipse(cx, cy, 7.5, 7.5, "#6a7280"))
    add(ellipse(cx, cy, 6.0, 6.0, "#0a0a0e"))
    cx, cy = _centre(CAN_LID)
    add({"op": "fill", "rect": CAN_LID, "color": "#8a94a0"})
    add(ellipse(cx, cy, 7.5, 7.5, "#c8d0da"))
    add(ellipse(cx, cy, 6.2, 6.2, "#9aa4b0"))
    add(ellipse(cx, cy, 5.2, 5.2, "#b8c2ce"))
    add(ellipse(cx, cy + 0.5, 3.2, 1.7, "#2048b8"))                                            # fish icon
    add({"op": "pixels", "list": [[int(cx) + 3, int(cy) - 1, "#2048b8"], [int(cx) + 3, int(cy) + 1, "#2048b8"], [int(cx) + 4, int(cy) - 2, "#2048b8"],
                                  [int(cx) + 4, int(cy) + 2, "#2048b8"], [int(cx) - 2, int(cy), "#ffffff"]]})
    add(ellipse(cx, CAN_LID[1] + 3.0, 1.5, 1.2, "#5a6470"))                                     # pull tab
    cx, cy = _centre(DIAL)
    add({"op": "fill", "rect": DIAL, "color": "#b08a3c"})
    add(ellipse(cx, cy, 7.5, 7.5, "#6a4a18"))
    add(ellipse(cx, cy, 6.5, 6.5, "#d8b060"))
    add(ellipse(cx, cy, 5.2, 5.2, "#0c1a0c"))
    ticks = []
    for k in range(7):
        a = math.radians(150 + k * 40)
        ticks.append([int(cx + 4.2 * math.cos(a)), int(cy + 4.2 * math.sin(a)), "#ff3020" if k == 6 else "#40ff20"])
    add({"op": "pixels", "list": ticks})
    add({"op": "line", "from": [int(cx), int(cy)], "to": [int(cx) + 3, int(cy) - 3], "color": "#a8ff90"})  # needle in the red
    add({"op": "pixels", "list": [[int(cx), int(cy), "#ffffff"]]})
    x1, y1, x2, y2 = CO2_TANK
    add({"op": "gradient", "rect": CO2_TANK, "top": "#d83030", "bottom": "#8a1818"})
    add({"op": "noise", "rect": CO2_TANK, "amount": 0.15, "spread": 0.08})
    add({"op": "text", "pos": [x1 + 2, y1 + 5], "text": "CO2", "color": "#ffffff"})
    add({"op": "line", "from": [x2 - 3, y1], "to": [x2 - 3, y2 - 1], "color": "#f0f0f0"})
    x1, y1, x2, y2 = CAPACITOR
    add({"op": "fill", "rect": CAPACITOR, "color": "#3a1a0c"})
    add({"op": "stripes", "rect": CAPACITOR, "colors": ["#e0903c", "#a85a1c"], "width": 1})     # copper windings
    for c in (x1 + 3, x2 - 5):                                                               # cyan discharge rings
        add({"op": "fill", "rect": [c, y1, c + 2, y2], "color": "#00f0ff"})
        add({"op": "line", "from": [c, y1], "to": [c, y2 - 1], "color": "#e0ffff"})

    # --- Row 4 ---
    add({"op": "fill", "rect": NEON_SPIRAL, "color": "#2c2a3a"})
    add({"op": "noise", "rect": NEON_SPIRAL, "amount": 0.15, "spread": 0.1})
    add(_pattern(NEON_SPIRAL, lambda x, y: (x + y) % 8 == 0, "#00f0ff"))                       # two spiralling tubes
    add(_pattern(NEON_SPIRAL, lambda x, y: (x + y) % 8 == 1, "#c8ffff"))
    add(_pattern(NEON_SPIRAL, lambda x, y: (x + y) % 8 == 4, "#ff2080"))
    add(_pattern(NEON_SPIRAL, lambda x, y: (x + y) % 8 == 5, "#ffb8dc"))
    x1, y1, x2, y2 = STUD_RING
    add({"op": "gradient", "rect": STUD_RING, "top": "#b4bcc8", "bottom": "#6a7280"})
    studs = []
    for x in range(x1 + 1, x2 - 1, 4):
        for y in (y1 + 4, y1 + 11):
            studs += [[x, y, "#f0f4fa"], [x + 1, y, "#d8dee8"], [x, y + 1, "#d8dee8"], [x + 1, y + 1, "#3a4250"]]
    add({"op": "pixels", "list": studs})
    add({"op": "fill", "rect": KNURL, "color": "#2a2e38"})
    add(_pattern(KNURL, lambda x, y: (x + y) % 3 == 0 or (x - y) % 3 == 0, "#6a7484"))
    add({"op": "fill", "rect": ANODIZED, "color": "#8a1a38"})
    add({"op": "noise", "rect": ANODIZED, "amount": 0.12, "spread": 0.08})
    cx, cy = _centre(LENS)
    add({"op": "fill", "rect": LENS, "color": "#400008"})
    add(ellipse(cx, cy, 7, 7, "#ff2020"))
    add(ellipse(cx, cy, 4, 4, "#ff8080"))
    add(ellipse(cx, cy, 2, 2, "#ffffff"))
    x1, y1, x2, y2 = PVC
    add({"op": "gradient", "rect": PVC, "top": "#e4e6ea", "bottom": "#a6aab0"})
    add({"op": "text", "pos": [x1 + 2, y1 + 5], "text": "PVC", "color": "#4a5060"})
    add({"op": "line", "from": [x1, y1 + 12], "to": [x2 - 1, y1 + 12], "color": "#8a9098"})
    x1, y1, x2, y2 = INDUSTRIAL
    add({"op": "gradient", "rect": INDUSTRIAL, "top": "#5a6438", "bottom": "#343a20"})
    add({"op": "noise", "rect": INDUSTRIAL, "amount": 0.3, "spread": 0.12})
    add(hazard([x1, y2 - 4, x2, y2]))
    add({"op": "pixels", "list": [[x1 + 2, y1 + 2, "#b0b890"], [x2 - 3, y1 + 2, "#b0b890"]]})
    add({"op": "edge", "rect": INDUSTRIAL, "color": "#1a1e10"})
    cx, cy = _centre(CUKE_END)
    add({"op": "fill", "rect": CUKE_END, "color": "#1e5620"})
    add(ellipse(cx, cy, 6.5, 6.5, "#b8d888"))
    add(ellipse(cx, cy, 3.5, 3.5, "#e0f0b8"))
    add({"op": "pixels", "list": [[int(cx + 2.6 * math.cos(a)), int(cy + 2.6 * math.sin(a)), "#fbfbe6"]
                                  for a in [k * math.pi / 3 for k in range(6)]]})

    # --- Row 5 ---
    add({"op": "fill", "rect": EAR_SIGHT, "color": "#1c1f26"})  # cat-ear iron sight (apex at the top middle)
    add(_pattern(EAR_SIGHT, lambda x, y: abs(x - 7.5) <= (y - 5) / 2.2 and 5 < y < 14, "#ff2080"))
    add(_pattern(EAR_SIGHT, lambda x, y: y == 0, "#7c8696"))
    return ops


# =====================================================================================
# Shape helpers (all sizes in CENTIMETRES; turned into Blockbench pixels here)
# =====================================================================================

def block(name, group, frm, to, uv=None, rot=None, origin=None, **faces) -> dict:
    """A box (a Blockbench cube). uv = every face; or sides= / top= / bottom= / faces={north: ...}.
    A face given no rect is not drawn (saves triangles on sides nobody sees). rot = [x, y, z] degrees
    about `origin` (default: the middle)."""
    el = {"type": "cube", "name": name, "group": group, "from": pv(frm), "to": pv(to)}
    if uv is not None:
        el["all"] = uv
    el.update(faces)
    if rot:
        el["rotation"] = list(rot)
        el["origin"] = pv(origin if origin else [(frm[i] + to[i]) / 2 for i in range(3)])
    return el


def can(name, group, axis, rings, sides, uv, around="facet", top=0.0, swap=False, span=False,
        face_uv=None, cap_start=None, cap_end=None, twist=None) -> dict:
    """A faceted round part: a barrel, a tin can, a fish, a ball. rings = (t, ra, rb[, ca, cb]):
    t = position along the axis, ra/rb = the two radii, ca/cb = the centre off the axis.
      axis "z": ra/ca = x, rb/cb = y      axis "y": ra/ca = x, rb/cb = z      axis "x": ra/ca = y, rb/cb = z
    Texture: X of `uv` runs ALONG the axis (per ring step, or over the whole part if span=True) and Y
    runs ROUND it: around="facet" = each facet shows the whole height, "wrap" = the rect is wrapped
    once round the part, "height" = top of the rect at angle `top` (radians), bottom opposite (a
    fish: dark back, white belly). swap=True turns it 90 degrees (a label whose text goes round).
    face_uv(ring_step, facet) may return another rect for one facet. cap_start / cap_end = lid rects."""
    twist = math.pi / sides if twist is None else twist
    step = 2 * math.pi / sides

    def key(r, i):
        return "r%d_%d" % (r, i)

    verts = {}
    for r, ring in enumerate(rings):
        t, ra, rb = ring[0], ring[1], ring[2]
        ca = ring[3] if len(ring) > 3 else 0.0
        cb = ring[4] if len(ring) > 4 else 0.0
        for i in range(sides):
            a = twist + i * step
            u, w = ca + ra * math.cos(a), cb + rb * math.sin(a)
            p = {"z": [u, w, t], "y": [u, t, w], "x": [t, u, w]}[axis]
            verts[key(r, i)] = pv(p)
    faces = []
    t0, tn = rings[0][0], rings[-1][0]
    for r in range(len(rings) - 1):
        a0, a1 = ((rings[r][0] - t0) / (tn - t0), (rings[r + 1][0] - t0) / (tn - t0)) if span else (0.0, 1.0)
        for i in range(sides):
            j = (i + 1) % sides
            x1, y1, x2, y2 = (face_uv(r, i) if face_uv else None) or uv
            ang_i, ang_j = twist + i * step, twist + (i + 1) * step
            if around == "wrap":
                b_i, b_j = i / sides, (i + 1) / sides
            elif around == "height":
                b_i, b_j = (1 - math.cos(ang_i - top)) / 2, (1 - math.cos(ang_j - top)) / 2
            else:
                b_i, b_j = 0.0, 1.0

            def uvp(a, b):
                along, round_ = (b, a) if swap else (a, b)
                return [round(x1 + (x2 - x1) * along, 3), round(y1 + (y2 - y1) * round_, 3)]
            faces.append({"v": [key(r, i), key(r, j), key(r + 1, j), key(r + 1, i)],
                          "uvs": [uvp(a0, b_i), uvp(a0, b_j), uvp(a1, b_j), uvp(a1, b_i)]})
    for rect, r in ((cap_start, 0), (cap_end, len(rings) - 1)):
        if rect is None:
            continue
        mx, my = _centre(rect)
        hw, hh = (rect[2] - rect[0]) / 2, (rect[3] - rect[1]) / 2
        corner = [[round(mx + math.cos(twist + i * step) * hw, 3), round(my + math.sin(twist + i * step) * hh, 3)] for i in range(sides)]
        for k in range(1, sides - 1):  # a fan of triangles; the picture is laid once over the whole lid
            faces.append({"v": [key(r, 0), key(r, k), key(r, k + 1)], "uvs": [corner[0], corner[k], corner[k + 1]]})
    return {"type": "poly", "name": name, "group": group, "vertices": verts, "faces": faces}


def extrude(name, group, outline, axis, a0, a1, uv, front_uv=None) -> dict:
    """A flat convex shape pushed out along an axis (fins, cat ears). outline = corners in the other
    two coordinates: axis "x" -> (y, z), axis "y" -> (x, z), axis "z" -> (x, y). a0..a1 = thickness.
    front_uv = the rect for the a1 face (default uv)."""
    def p3(c, a):
        return pv({"x": [a, c[0], c[1]], "y": [c[0], a, c[1]], "z": [c[0], c[1], a]}[axis])
    verts, faces, n = {}, [], len(outline)
    for i, c in enumerate(outline):
        verts["f%d" % i] = p3(c, a1)
        verts["k%d" % i] = p3(c, a0)
    for i in range(n):
        j = (i + 1) % n
        faces.append({"v": ["f%d" % i, "f%d" % j, "k%d" % j, "k%d" % i], "uv": uv})
    for k in range(1, n - 1):
        faces.append({"v": ["f0", "f%d" % k, "f%d" % (k + 1)], "uv": front_uv or uv})
        faces.append({"v": ["k0", "k%d" % k, "k%d" % (k + 1)], "uv": uv})
    return {"type": "poly", "name": name, "group": group, "vertices": verts, "faces": faces}


def spike(name, group, base, tip, uv) -> dict:
    """An icicle: a 3-cornered base and a point (4 triangles)."""
    keys = ["a", "b", "c", "t"]
    verts = dict(zip(keys, [pv(p) for p in list(base) + [tip]]))
    faces = [{"v": f, "uv": uv} for f in (["a", "b", "c"], ["a", "b", "t"], ["b", "c", "t"], ["c", "a", "t"])]
    return {"type": "poly", "name": name, "group": group, "vertices": verts, "faces": faces}


def disc(name, group, axis, at, radius, sides, uv, facing, centre=(0.0, 0.0)) -> dict:
    """A flat round lid on its own (a lens): faces `facing` (+1 / -1) along the axis."""
    ring = (at, radius, radius, centre[0], centre[1])
    el = can(name, group, axis, [ring, (at - facing * 0.5, radius, radius, centre[0], centre[1])], sides, uv, cap_start=uv)
    el["faces"] = [f for f in el["faces"] if all(v.startswith("r0_") for v in f["v"])]  # keep only the lid
    el["vertices"] = {k: v for k, v in el["vertices"].items() if k.startswith("r0_")}
    behind = {"z": [centre[0], centre[1], at - facing], "y": [centre[0], at - facing, centre[1]], "x": [at - facing, centre[0], centre[1]]}[axis]
    el["outward_from"] = pv(behind)  # (a flat piece: say which side is the front)
    return el


def ring_loop(name, group, centre_yz, outer, inner, sides, half_thick, uv) -> dict:
    """A flat ring standing in the Y-Z plane (a keychain split-ring), seen from both sides."""
    cy, cz = centre_yz
    verts, faces = {}, []
    for side, x in (("p", half_thick), ("n", -half_thick)):
        for i in range(sides):
            a = i * 2 * math.pi / sides
            verts["%so%d" % (side, i)] = pv([x, cy + outer * math.cos(a), cz + outer * math.sin(a)])
            verts["%si%d" % (side, i)] = pv([x, cy + inner * math.cos(a), cz + inner * math.sin(a)])
    for side in ("p", "n"):
        for i in range(sides):
            j = (i + 1) % sides
            faces.append({"v": ["%so%d" % (side, i), "%so%d" % (side, j), "%si%d" % (side, j), "%si%d" % (side, i)], "uv": uv})
    return {"type": "poly", "name": name, "group": group, "vertices": verts, "faces": faces, "outward_from": pv([0, cy, cz])}


def muzzle(at) -> dict:
    return {"type": "locator", "name": "Muzzle", "group": "Body", "position": pv(at)}


def mirror_x(el: dict, name: str) -> dict:
    """The same element on the other side (x flipped). Works for blocks and polys."""
    m = json.loads(json.dumps(el))
    m["name"] = name
    if m["type"] == "cube":
        a, b = m["from"][0], m["to"][0]
        m["from"][0], m["to"][0] = -b, -a
        if "origin" in m:
            m["origin"][0] = -m["origin"][0]
    else:
        for v in m["vertices"].values():
            v[0] = -v[0]
    return m


def spec(name, about, groups, elements, seed) -> dict:
    return {"name": name, "kind": "prop", "texture_size": SIZE, "seed": seed, "background": "#22242a",
            "about": about, "paint": atlas_paint(), "groups": [{"name": g} for g in groups], "elements": elements}


# =====================================================================================
# 1. PAW-PISTOL: compact service pistol, cat-ear iron sights, paw-print grip, pink laser rail.
# =====================================================================================

def pistol() -> dict:
    ear = extrude("ear_sightL", "Body", [(-2.9, 4.5), (-0.5, 4.5), (-1.7, 7.4)], "z", 8.0, 9.6, DARK_STEEL, front_uv=EAR_SIGHT)
    return spec("pistol", "PAW-PISTOL (scenes/items/pistol.tscn). Barrel -Z. Groups: Body, Laser (pink glow). @Muzzle.",
                ["Body", "Laser"], [
        block("slide", "Body", [-3.5, -1.5, -13], [3.5, 4.5, 11],
              faces={"east": SLIDE_PORTS, "west": SLIDE_PORTS, "north": DARK_STEEL, "south": DARK_STEEL, "up": CHROME_METAL}),
        block("frame", "Body", [-3, -4, -12], [3, -1.5, 7], sides=POLY_BLACK, bottom=POLY_BLACK),
        can("barrel", "Body", "z", [(-13, 1.5, 1.5, 0, 1.5), (-16.5, 1.5, 1.5, 0, 1.5)], 6, CHROME_METAL, cap_end=BORE),
        block("grip", "Body", [-2.8, -15, 1], [2.8, -3, 8.5], rot=[-15, 0, 0], origin=[0, -3, 4.75],
              faces={"east": PAW_GRIP, "west": PAW_GRIP, "north": POLY_BLACK, "south": POLY_BLACK, "down": POLY_BLACK}),
        block("trigger_guard", "Body", [-0.6, -7, -5], [0.6, -4, 0.5], sides=POLY_BLACK, bottom=POLY_BLACK),
        ear, mirror_x(ear, "ear_sightR"),
        block("front_sight", "Body", [-0.6, 4.5, -12.5], [0.6, 5.6, -11.5], sides=DARK_STEEL, top=DARK_STEEL),
        block("laser_rail", "Laser", [-1.4, -6, -14], [1.4, -4, -7], sides=NEON_PINK, bottom=NEON_PINK),
        muzzle([0, 1.5, -16.5]),
    ], seed=101)


# =====================================================================================
# 2. PURR-TOMMY: Thompson-style SMG, finned barrel, TUNA-TIN drum, glowing HeatCoil on top.
# =====================================================================================

def tommy_gun() -> dict:
    return spec("tommy_gun", "PURR-TOMMY (scenes/items/tommy_gun.tscn). Barrel -Z. Groups: Body, HeatCoil (weapon.gd "
                "glows it hotter as you fire). @Muzzle.", ["Body", "HeatCoil"], [
        block("receiver", "Body", [-4.5, -4.5, -18], [4.5, 5, 14], sides=DARK_STEEL, top=CHROME_METAL, bottom=POLY_BLACK),
        can("barrel", "Body", "z", [(-18, 2.2, 2.2, 0, 1), (-52, 2.2, 2.2, 0, 1)], 6, DARK_STEEL),
        can("cooling_fins", "Body", "z", [(-21, 4, 4, 0, 1), (-42, 4, 4, 0, 1)], 6, BARREL_FINS, span=True, cap_end=DARK_STEEL),
        block("compensator", "Body", [-2.6, -1.6, -58], [2.6, 3.6, -52],
              faces={"north": BORE, "east": CHROME_METAL, "west": CHROME_METAL, "up": CHROME_METAL, "down": CHROME_METAL}),
        block("fore_grip", "Body", [-1.8, -14, -30], [1.8, -2.5, -25.5], sides=WOOD_ORANGE, bottom=WOOD_ORANGE),
        block("grip", "Body", [-2.6, -17, 5], [2.6, -4.5, 11.5], rot=[-15, 0, 0], origin=[0, -4.5, 8.25],
              sides=WOOD_ORANGE, bottom=WOOD_ORANGE),
        block("stock", "Body", [-2.4, -9, 14], [2.4, 2.5, 42], sides=WOOD_ORANGE, top=WOOD_ORANGE, bottom=WOOD_ORANGE,
              faces={"south": POLY_BLACK}),
        can("tuna_drum", "Body", "x", [(-4, 9, 9, -12, -6), (4, 9, 9, -12, -6)], 8, CAN_LABEL, around="wrap", swap=True,
            cap_start=CAN_LID, cap_end=CAN_LID),
        can("heat_coil", "HeatCoil", "z", [(-15, 1.8, 1.8, 0, 7), (11, 1.8, 1.8, 0, 7)], 6, COIL_HEAT, span=True,
            cap_start=RUST_BRASS, cap_end=RUST_BRASS),
        muzzle([0, 1, -58]),
    ], seed=102)


# =====================================================================================
# 3. FROZEN TUNA (melee): a whole rock-hard bluefin, taped tail = the handle, icicles on the fins.
# Stands up along +Y: tail/handle at the origin, head at the top (scene tilts it forward).
# =====================================================================================

def frozen_tuna() -> dict:
    def skin(r, i):
        return TUNA_BELLY if r == 2 else None  # the last ring step (the head) gets the gill + pale belly
    pec = extrude("pec_finR", "Ice", [(4.0, 60), (4.4, 53), (12, 47)], "z", -0.6, 0.6, TUNA_FROST)
    pec_ice = spike("icicle_pecR", "Ice", [(10.5, 48.5, -0.4), (11.6, 47.4, 0.4), (10.2, 47.8, 0.5)], (12.5, 41, 0), TUNA_FROST)
    return spec("frozen_tuna", "FROZEN TUNA (scenes/items/frozen_tuna.tscn, MeleeWeapon). Handle at the origin, head +Y, "
                "back (dorsal) -Z. Groups: Body, Ice (frost: neon_parts makes the bright frost glow).", ["Body", "Ice"], [
        block("handle_tape", "Body", [-1.8, -6, -1.8], [1.8, 13, 1.8], sides=TAPE_WRAP),
        extrude("tail_lobe_back", "Ice", [(-5, 0), (-17, -10), (-11, 0)], "x", -0.8, 0.8, TUNA_FROST),
        extrude("tail_lobe_belly", "Ice", [(-5, 0), (-11, 0), (-17, 10)], "x", -0.8, 0.8, TUNA_FROST),
        can("body", "Body", "y", [(12, 2.2, 3.5), (34, 5, 14), (62, 5, 12), (80, 2.2, 3.5)], 6, TUNA_SKIN,
            around="height", top=1.5 * math.pi, twist=0.5 * math.pi, face_uv=skin, cap_start=TUNA_FROST, cap_end=TUNA_BELLY),
        block("eyes", "Body", [-3.7, 67, -3.2], [3.7, 70, -0.2], faces={"east": TUNA_EYE, "west": TUNA_EYE}),
        extrude("dorsal_fin", "Ice", [(38, -13.0), (56, -11.0), (44, -24)], "x", -0.6, 0.6, TUNA_FROST),
        extrude("belly_fin", "Ice", [(28, 10.5), (40, 13.0), (29, 20)], "x", -0.6, 0.6, TUNA_FROST),
        pec, mirror_x(pec, "pec_finL"),
        spike("icicle_dorsal", "Ice", [(-0.5, 43, -22.5), (0.5, 45.5, -22), (0, 44, -21)], (0, 41, -30), TUNA_FROST),
        pec_ice, mirror_x(pec_ice, "icicle_pecL"),
    ], seed=103)


# =====================================================================================
# 4. HAIRBALL BLASTER: sawed-off double barrel, flared muzzles, brass hinge, pink-lit side vents.
# =====================================================================================

def hairball_blaster() -> dict:
    barrel = can("barrelL", "Body", "z", [(-6, 3, 3, -3.4, 0), (-26, 3, 3, -3.4, 0)], 6, DARK_STEEL)
    flare = can("flareL", "Body", "z", [(-26, 3.2, 3.2, -3.4, 0), (-30, 3.8, 3.8, -3.4, 0)], 6, CHROME_METAL, cap_end=BORE)
    return spec("hairball_blaster", "HAIRBALL BLASTER (scenes/items/hairball_blaster.tscn). Barrels -Z. Groups: Body, "
                "Vents (pink slits: neon_parts). @Muzzle between the barrels.", ["Body", "Vents"], [
        barrel, mirror_x(barrel, "barrelR"), flare, mirror_x(flare, "flareR"),
        block("breech", "Body", [-7, -4, -6], [7, 4, 6],
              faces={"east": CHROME_METAL, "west": CHROME_METAL, "up": CHROME_METAL, "north": DARK_STEEL, "south": DARK_STEEL, "down": DARK_STEEL}),
        block("vents", "Vents", [-7.2, -2.5, -4.5], [7.2, 1.5, 4.5], faces={"east": VENTS, "west": VENTS}),
        block("breech_latch", "Body", [-1.2, 4, -1], [1.2, 6, 5], sides=RUST_BRASS, top=RUST_BRASS),
        block("hinge_pins", "Body", [-7.8, -4, -6.6], [7.8, -2, -4.6], uv=RUST_BRASS),
        block("grip", "Body", [-2.8, -15, 3], [2.8, -3.5, 9.5], rot=[-25, 0, 0], origin=[0, -3.5, 6.25],
              sides=WOOD_ORANGE, bottom=WOOD_ORANGE),
        block("trigger_guard", "Body", [-0.6, -7, -2], [0.6, -4, 3], sides=POLY_BLACK, bottom=POLY_BLACK),
        muzzle([0, 0, -30]),
    ], seed=104)


# =====================================================================================
# 5. YARN-ZOOKA: PVC rocket tube, flared launch bell, static-charged yarn ball, cyan capacitor.
# =====================================================================================

def yarn_zooka() -> dict:
    return spec("yarn_zooka", "YARN-ZOOKA (scenes/items/yarn_zooka.tscn). Tube -Z. Groups: Body, Yarn (glows), "
                "Capacitor + Ring (cyan glow). @Muzzle at the bell's mouth.", ["Body", "Yarn", "Capacitor", "Ring"], [
        can("tube", "Body", "z", [(24, 6.5, 6.5), (-40, 6.5, 6.5)], 8, PVC, span=True, cap_start=DARK_STEEL),
        can("launch_bell", "Body", "z", [(-40, 6.5, 6.5), (-48, 9.5, 9.5)], 8, DARK_STEEL),
        can("yarn_ball", "Yarn", "z", [(-41, 3.5, 3.5), (-50, 8, 8), (-59, 3.5, 3.5)], 6, YARN_WOOL, cap_end=YARN_WOOL),
        can("charge_ring", "Ring", "z", [(-36, 7, 7), (-38, 7, 7)], 8, NEON_CYAN),
        can("capacitor", "Capacitor", "z", [(10, 2.5, 2.5, 8, 1), (-14, 2.5, 2.5, 8, 1)], 6, CAPACITOR, span=True,
            cap_start=RUST_BRASS, cap_end=RUST_BRASS),
        block("grip", "Body", [-2.8, -18, -2], [2.8, -6, 4.5], rot=[-15, 0, 0], origin=[0, -6, 1.25], sides=POLY_BLACK, bottom=POLY_BLACK),
        block("front_handle", "Body", [-2.2, -15, -28], [2.2, -6, -23.5], sides=POLY_BLACK, bottom=POLY_BLACK),
        block("sight", "Body", [-1, 6, -20], [1, 9, -14], sides=DARK_STEEL, top=LASER_CAUTION),
        muzzle([0, 0, -59]),
    ], seed=105)


# =====================================================================================
# 6. CUCUMBER LAUNCHER: pneumatic mortar, cucumber hopper, a pickle in the muzzle, CO2 tank, dial.
# =====================================================================================

def cucumber_launcher() -> dict:
    return spec("cucumber_launcher", "CUCUMBER LAUNCHER (scenes/items/cucumber_launcher.tscn). Barrel -Z. Groups: Body, "
                "Cucumber (pale ribs glow: neon_parts), Gauge (the pressure dial). @Muzzle.", ["Body", "Cucumber", "Gauge"], [
        can("chamber", "Body", "z", [(22, 9, 9), (-44, 9, 9)], 8, INDUSTRIAL, cap_start=DARK_STEEL),
        can("muzzle_ring", "Body", "z", [(-44, 10.5, 10.5), (-48, 10.5, 10.5)], 8, RUST_BRASS, cap_end=BORE),
        can("cucumber", "Cucumber", "z", [(-44, 5.5, 5.5), (-52, 6.5, 6.5), (-62, 5, 5)], 6, CUCUMBER_SKIN, span=True, cap_end=CUKE_END),
        block("hopper", "Body", [-4, 6, -12], [4, 17, -2], rot=[25, 0, 0], origin=[0, 6, -7], sides=INDUSTRIAL, top=CUCUMBER_SKIN),
        can("co2_tank", "Body", "z", [(-4, 4, 4, 0, -13), (-30, 4, 4, 0, -13)], 6, CO2_TANK, span=True,
            cap_start=CHROME_METAL, cap_end=CHROME_METAL),
        block("tank_strap", "Body", [-9.4, -17.4, -19], [9.4, 9.4, -16], faces={"east": POLY_BLACK, "west": POLY_BLACK, "up": POLY_BLACK, "down": POLY_BLACK}),
        block("pressure_dial", "Gauge", [8.4, 0, -32], [10, 4.6, -27.4],
              faces={"east": DIAL, "north": RUST_BRASS, "south": RUST_BRASS, "up": RUST_BRASS, "down": RUST_BRASS}),
        block("grip", "Body", [-3, -20, 2], [3, -8.5, 9], rot=[-15, 0, 0], origin=[0, -8.5, 5.5], sides=POLY_BLACK, bottom=POLY_BLACK),
        muzzle([0, 0, -62]),
    ], seed=106)


# =====================================================================================
# 7. NEON BAT (melee): metal slugger, spiralling cyan/magenta neon tubes, taped grip, studded ring.
# Stands up along +Y like the old model: the handle is at the origin.
# =====================================================================================

def neon_bat() -> dict:
    return spec("neon_bat", "NEON BAT (scenes/items/neon_bat.tscn, MeleeWeapon). Handle at the origin, barrel +Y. Groups: "
                "Body, Barrel (the painted neon spiral glows: neon_parts).", ["Body", "Barrel"], [
        can("pommel_knob", "Body", "y", [(-13, 3.8, 3.8), (-10, 3.8, 3.8)], 6, DARK_STEEL, cap_start=CHROME_METAL),
        can("handle_tape", "Body", "y", [(-10, 2.2, 2.2), (12, 2.4, 2.4)], 6, TAPE_WRAP, span=True),
        can("barrel", "Barrel", "y", [(12, 2.6, 2.6), (30, 4.6, 4.6), (52, 5.4, 5.4)], 6, NEON_SPIRAL, cap_end=CHROME_METAL),
        can("stud_ring", "Body", "y", [(35, 5.1, 5.1), (39, 5.3, 5.3)], 6, STUD_RING),
    ], seed=107)


# =====================================================================================
# 8. THE RED DOT: tactical keychain laser pointer, knurled grip, brass split-ring, DANGER LASER.
# =====================================================================================

def red_dot() -> dict:
    label = block("danger_label", "Body", [-2.08, -0.8, -13], [2.08, 0.8, -5], faces={"east": DANGER_LABEL, "west": DANGER_LABEL})
    return spec("red_dot", "THE RED DOT (scenes/items/red_dot.tscn). Lens -Z. Groups: Body, Lens + Button (red glow). @Muzzle.",
                ["Body", "Lens", "Button"], [
        can("housing", "Body", "z", [(8, 2.2, 2.2), (-15, 2.2, 2.2)], 8, ANODIZED, cap_start=RUST_BRASS),
        can("knurl_grip", "Body", "z", [(6.5, 2.45, 2.45), (1.5, 2.45, 2.45)], 8, KNURL, span=True),
        can("head", "Body", "z", [(-15, 2.4, 2.4), (-19, 2.9, 2.9)], 8, CHROME_METAL),
        disc("lens", "Lens", "z", -18.9, 2.85, 8, LENS, facing=-1),
        label,
        block("push_button", "Button", [-0.8, 1.9, -9.5], [0.8, 3.1, -6.5], sides=NEON_PINK, top=NEON_PINK),
        ring_loop("split_ring", "Body", (0.0, 11.3), 3.2, 2.2, 6, 0.25, RUST_BRASS),
        muzzle([0, 0, -19.2]),
    ], seed=108)


WEAPONS = [pistol, tommy_gun, frozen_tuna, hairball_blaster, yarn_zooka, cucumber_launcher, neon_bat, red_dot]


def main(argv: list) -> None:
    os.makedirs(SPEC_DIR, exist_ok=True)
    paths = []
    for make in WEAPONS:
        s = make()
        path = os.path.join(SPEC_DIR, s["name"] + ".json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(s, f, indent=1)
        paths.append(path)
        mz = [e for e in s["elements"] if e.get("name") == "Muzzle"]
        where = " (muzzle at %s m)" % [round(c / 16.0, 4) for c in mz[0]["position"]] if mz else ""
        print("wrote", os.path.relpath(path, os.path.dirname(HERE)) + where)
    if "--build" in argv:
        for path in paths:
            subprocess.run([sys.executable, os.path.join(HERE, "cypurr_models.py"), "all", path], check=True)


if __name__ == "__main__":
    main(sys.argv[1:])
