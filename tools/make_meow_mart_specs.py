"""Writes the model specs for the MEOW-MART overhaul (tools/model_specs/<name>.json), then you build
each one with:  python tools/cypurr_models.py all tools/model_specs/<name>.json

  mart_cat_sign  - the giant rooftop neon CAT HEAD sign (4.5 m wide) on a steel frame
  security_cam   - an OVERCLEAN security camera on a wall arm (the Head swivels, the Lens glows red)
  rooftop_ac     - a chunky rooftop air-conditioning unit with a big fan grille
  freezer_case   - a 2 m glass-door freezer, glowing cold-blue inside, stocked with fish

16 px = 1 m. The front of every model faces -Z ("north"). Groups named Neon / Lens / Glow are the
parts the game makes glow (LevelKit.make_neon_paint_glow: only the BRIGHT painted pixels glow).
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "model_specs")


def cube(name, group, frm, to, faces=None, sides=None, top=None, origin=None, rotation=None):
    el = {"type": "cube", "name": name, "group": group, "from": frm, "to": to}
    if faces:
        el["faces"] = faces
    if sides:
        el["sides"] = sides
    if top:
        el["top"] = top
    if origin:
        el["origin"] = origin
    if rotation:
        el["rotation"] = rotation
    return el


def save(spec):
    with open(os.path.join(OUT, spec["name"] + ".json"), "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=1)
    print("wrote", spec["name"])


# ---------------------------------------------------------------- the giant cat head sign
PINK = "#ff3fb4"
DARK = "#1a0f24"
cat_sign = {
    "name": "mart_cat_sign", "kind": "set_piece", "texture_size": 128, "seed": 77, "background": DARK,
    "about": "MEOW-MART's rooftop sign: a giant flat CAT HEAD (4 x 3 m) outlined in pink neon, glowing green eyes, "
             "a pink nose, whiskers, and a MEOW-MART bar under its chin, all on a steel frame. Groups: Frame, Neon (glows), "
             "Eyes (glow, blink in game). 16 px = 1 m.",
    "paint": [
        {"op": "comment", "note": "[0,0,64,48] head front: dark, pink neon outline, whiskers, a W mouth"},
        {"op": "fill", "rect": [0, 0, 64, 48], "color": DARK},
        {"op": "noise", "rect": [0, 0, 64, 48], "amount": 0.2, "spread": 0.1},
        {"op": "edge", "rect": [0, 0, 64, 48], "color": PINK},
        {"op": "edge", "rect": [1, 1, 63, 47], "color": PINK},
        {"op": "line", "from": [3, 26], "to": [20, 28], "color": PINK},
        {"op": "line", "from": [3, 32], "to": [20, 31], "color": PINK},
        {"op": "line", "from": [44, 28], "to": [60, 26], "color": PINK},
        {"op": "line", "from": [44, 31], "to": [60, 32], "color": PINK},
        {"op": "line", "from": [26, 36], "to": [29, 39], "color": PINK},
        {"op": "line", "from": [29, 39], "to": [32, 36], "color": PINK},
        {"op": "line", "from": [32, 36], "to": [35, 39], "color": PINK},
        {"op": "line", "from": [35, 39], "to": [38, 36], "color": PINK},
        {"op": "comment", "note": "[64,0,128,48] head back + sides: plum steel panels, rivets"},
        {"op": "fill", "rect": [64, 0, 128, 48], "color": "#2c2035"},
        {"op": "stripes", "rect": [64, 0, 128, 48], "colors": ["#ffffff0c", "#00000000", "#00000022"], "width": 2, "direction": "vertical"},
        {"op": "spots", "rect": [64, 0, 128, 48], "color": "#4a3a2aa0", "count": 10, "size": 1.5},
        {"op": "noise", "rect": [64, 0, 128, 48], "amount": 0.3, "spread": 0.15},
        {"op": "comment", "note": "[0,48,24,72] ear face: dark with a pink neon edge (it's a square turned 45 degrees)"},
        {"op": "fill", "rect": [0, 48, 24, 72], "color": DARK},
        {"op": "edge", "rect": [0, 48, 24, 72], "color": PINK},
        {"op": "edge", "rect": [1, 49, 23, 71], "color": PINK},
        {"op": "fill", "rect": [7, 55, 17, 65], "color": "#5a1a44"},
        {"op": "comment", "note": "[32,48,42,58] eye: bright green with a black slit"},
        {"op": "fill", "rect": [32, 48, 42, 58], "color": "#5dffb0"},
        {"op": "fill", "rect": [36, 49, 38, 57], "color": "#08140e"},
        {"op": "pixels", "points": []},
        {"op": "comment", "note": "[48,48,56,52] nose: bright pink"},
        {"op": "fill", "rect": [48, 48, 56, 52], "color": "#ff70c8"},
        {"op": "comment", "note": "[0,80,80,96] the bar: MEOW-MART in big neon letters"},
        {"op": "fill", "rect": [0, 80, 80, 96], "color": "#120a18"},
        {"op": "edge", "rect": [0, 80, 80, 96], "color": "#3cf0ff"},
        {"op": "text", "pos": [4, 83], "text": "MEOW-MART", "color": "#ff5ac0", "scale": 2, "spacing": 1},
        {"op": "comment", "note": "[80,80,96,96] steel: grey, rusty"},
        {"op": "fill", "rect": [80, 80, 96, 96], "color": "#4a4c55"},
        {"op": "spots", "rect": [80, 80, 96, 96], "color": "#7a4a2aa0", "count": 4, "size": 1.5},
        {"op": "noise", "rect": [80, 80, 96, 96], "amount": 0.4, "spread": 0.2},
    ],
    "groups": [
        {"name": "Frame", "origin": [0, 0, 0]},
        {"name": "Neon", "origin": [0, 0, 0], "parent": "Frame"},
        {"name": "Eyes", "origin": [0, 51, -4], "parent": "Frame"},
    ],
    "elements": [
        # steel legs + cross brace
        cube("leg_l", "Frame", [-26, 0, -1.5], [-23, 26, 1.5], sides=[80, 80, 96, 96], top=[80, 80, 96, 96]),
        cube("leg_r", "Frame", [23, 0, -1.5], [26, 26, 1.5], sides=[80, 80, 96, 96], top=[80, 80, 96, 96]),
        cube("brace", "Frame", [-24, 4, -1], [24, 6, 1], sides=[80, 80, 96, 96], top=[80, 80, 96, 96]),
        # the MEOW-MART bar
        cube("bar", "Neon", [-40, 8, -3], [40, 24, 3],
             faces={"north": [0, 80, 80, 96], "south": [0, 80, 80, 96], "east": [80, 80, 82, 96], "west": [80, 80, 82, 96],
                    "up": [80, 80, 96, 82], "down": [80, 80, 96, 82]}),
        # the head
        cube("head", "Neon", [-32, 26, -2.5], [32, 74, 2.5],
             faces={"north": [0, 0, 64, 48], "south": [64, 0, 128, 48], "east": [64, 0, 69, 48], "west": [64, 0, 69, 48],
                    "up": [64, 0, 128, 5], "down": [64, 0, 128, 5]}),
        # the ears: squares turned 45 degrees, half hidden in the head = triangles
        cube("ear_l", "Neon", [-34, 62, -2], [-10, 86, 2], origin=[-22, 74, 0], rotation=[0, 0, 45],
             faces={"north": [0, 48, 24, 72], "south": [64, 0, 88, 24], "east": [64, 0, 68, 24], "west": [64, 0, 68, 24],
                    "up": [64, 0, 88, 4], "down": [64, 0, 88, 4]}),
        cube("ear_r", "Neon", [10, 62, -2], [34, 86, 2], origin=[22, 74, 0], rotation=[0, 0, 45],
             faces={"north": [0, 48, 24, 72], "south": [64, 0, 88, 24], "east": [64, 0, 68, 24], "west": [64, 0, 68, 24],
                    "up": [64, 0, 88, 4], "down": [64, 0, 88, 4]}),
        # eyes + nose (stick out of the face a little)
        cube("eye_l", "Eyes", [-19, 46, -3.5], [-9, 56, -2.5], faces={"north": [32, 48, 42, 58]}),
        cube("eye_r", "Eyes", [9, 46, -3.5], [19, 56, -2.5], faces={"north": [32, 48, 42, 58]}),
        cube("nose", "Neon", [-4, 40, -3.5], [4, 44, -2.5], faces={"north": [48, 48, 56, 52]}),
    ],
}
# (the "pixels" op with no points does nothing; drop it)
cat_sign["paint"] = [op for op in cat_sign["paint"] if op.get("op") != "pixels"]
save(cat_sign)

# ---------------------------------------------------------------- the security camera
security_cam = {
    "name": "security_cam", "kind": "prop", "texture_size": 64, "seed": 12, "background": "#d8dade",
    "about": "An OVERCLEAN security camera on a wall arm (0.75 m long). The Head group swivels (its pivot is the arm's "
             "end), the Lens group glows red. The wall plate is at z = +0 (stick its back on a wall, facing -Z). 16 px = 1 m.",
    "paint": [
        {"op": "comment", "note": "[0,0,32,16] camera body sides: off-white plastic, OVERCLEAN stencil, grime"},
        {"op": "fill", "rect": [0, 0, 32, 16], "color": "#d8dade"},
        {"op": "gradient", "rect": [0, 0, 32, 16], "top": "#ffffff20", "bottom": "#00000040"},
        {"op": "text", "pos": [2, 5], "text": "OVRCLN", "color": "#2a2c34c0", "spacing": 1},
        {"op": "noise", "rect": [0, 0, 32, 16], "amount": 0.3, "spread": 0.12},
        {"op": "comment", "note": "[32,0,40,8] lens: a glowing red eye"},
        {"op": "fill", "rect": [32, 0, 40, 8], "color": "#200404"},
        {"op": "fill", "rect": [34, 2, 38, 6], "color": "#ff2a1a"},
        {"op": "pixels", "list": [[35, 3, "#ffd0c0"]]},
        {"op": "comment", "note": "[0,16,16,32] dark steel arm + plate"},
        {"op": "fill", "rect": [0, 16, 16, 32], "color": "#33353c"},
        {"op": "noise", "rect": [0, 16, 16, 32], "amount": 0.4, "spread": 0.2},
        {"op": "edge", "rect": [0, 16, 16, 32], "color": "#1c1d22"},
        {"op": "comment", "note": "[16,16,32,24] hood: dark grey"},
        {"op": "fill", "rect": [16, 16, 32, 24], "color": "#4a4d55"},
        {"op": "noise", "rect": [16, 16, 32, 24], "amount": 0.3, "spread": 0.15},
    ],
    "groups": [
        {"name": "Mount", "origin": [0, 0, 0]},
        {"name": "Head", "origin": [0, 0, -7], "parent": "Mount"},
        {"name": "Lens", "origin": [0, -1, -12], "parent": "Head"},
    ],
    "elements": [
        cube("plate", "Mount", [-2.5, -2.5, -0.6], [2.5, 2.5, 0], sides=[0, 16, 16, 32], top=[0, 16, 16, 32]),
        cube("arm", "Mount", [-0.8, -0.8, -7], [0.8, 0.8, -0.6], sides=[0, 16, 16, 32], top=[0, 16, 16, 32]),
        cube("body", "Head", [-2.2, -3.2, -12], [2.2, 0.6, -4],
             faces={"north": [0, 0, 8, 8], "south": [0, 0, 8, 8], "east": [0, 0, 32, 16], "west": [0, 0, 32, 16],
                    "up": [0, 0, 32, 16], "down": [0, 0, 32, 16]}),
        cube("hood", "Head", [-2.8, 0.6, -12.8], [2.8, 1.4, -3.6], sides=[16, 16, 32, 24], top=[16, 16, 32, 24]),
        cube("lens", "Lens", [-1.4, -2.6, -12.6], [1.4, 0.2, -12], faces={"north": [32, 0, 40, 8]}),
    ],
}

save(security_cam)

# ---------------------------------------------------------------- the rooftop AC unit
rooftop_ac = {
    "name": "rooftop_ac", "kind": "prop", "texture_size": 64, "seed": 31, "background": "#8a8f96",
    "about": "A chunky rooftop air-conditioning unit (1.5 x 1.1 x 1.2 m): ribbed grey steel, a big round fan "
             "grille on top (the Fan group spins in game), a pipe running down the back. 16 px = 1 m.",
    "paint": [
        {"op": "comment", "note": "[0,0,48,18] the box sides: ribbed galvanised steel, rust streaks, a hazard sticker"},
        {"op": "fill", "rect": [0, 0, 48, 18], "color": "#8a8f96"},
        {"op": "stripes", "rect": [0, 0, 48, 18], "colors": ["#ffffff18", "#00000000", "#0000002a"], "width": 1, "direction": "vertical"},
        {"op": "gradient", "rect": [0, 8, 48, 18], "top": "#5a3a2000", "bottom": "#5a3a2090"},
        {"op": "fill", "rect": [4, 3, 10, 7], "color": "#f0c020"},
        {"op": "text", "pos": [5, 2], "text": "!", "color": "#1a1a1a"},
        {"op": "noise", "rect": [0, 0, 48, 18], "amount": 0.3, "spread": 0.15},
        {"op": "edge", "rect": [0, 0, 48, 18], "color": "#55595f"},
        {"op": "comment", "note": "[0,24,24,48] the top: grey with the dark fan hole"},
        {"op": "fill", "rect": [0, 24, 24, 48], "color": "#7c8188"},
        {"op": "noise", "rect": [0, 24, 24, 48], "amount": 0.35, "spread": 0.15},
        {"op": "comment", "note": "[24,24,40,40] fan grille: black with silver blades"},
        {"op": "fill", "rect": [24, 24, 40, 40], "color": "#111214"},
        {"op": "line", "from": [24, 24], "to": [39, 39], "color": "#9aa0a8"},
        {"op": "line", "from": [39, 24], "to": [24, 39], "color": "#9aa0a8"},
        {"op": "line", "from": [31, 24], "to": [31, 39], "color": "#6a7078"},
        {"op": "line", "from": [24, 31], "to": [39, 31], "color": "#6a7078"},
        {"op": "edge", "rect": [24, 24, 40, 40], "color": "#5a5e66"},
        {"op": "comment", "note": "[40,24,48,32] pipe: copper"},
        {"op": "fill", "rect": [40, 24, 48, 32], "color": "#a86a3a"},
        {"op": "noise", "rect": [40, 24, 48, 32], "amount": 0.4, "spread": 0.2},
    ],
    "groups": [
        {"name": "Body", "origin": [0, 0, 0]},
        {"name": "Fan", "origin": [0, 18.4, 0], "parent": "Body"},
    ],
    "elements": [
        cube("feet", "Body", [-11, 0, -9], [11, 1.2, 9], sides=[0, 0, 48, 2], top=[0, 24, 24, 48]),
        cube("box", "Body", [-12, 1.2, -9.6], [12, 18, 9.6],
             faces={"north": [0, 0, 48, 18], "south": [0, 0, 48, 18], "east": [0, 0, 40, 18], "west": [0, 0, 40, 18],
                    "up": [0, 24, 24, 48], "down": [0, 24, 24, 48]}),
        cube("fan", "Fan", [-7, 18, -7], [7, 18.8, 7], sides=[24, 24, 40, 25], top=[24, 24, 40, 40]),
        cube("pipe", "Body", [-1, 0, 9.6], [1, 14, 11.6], sides=[40, 24, 48, 32], top=[40, 24, 48, 32]),
    ],
}
save(rooftop_ac)

# ---------------------------------------------------------------- the freezer case
freezer_case = {
    "name": "freezer_case", "kind": "prop", "texture_size": 64, "seed": 58, "background": "#2a2e36",
    "about": "An upright supermarket freezer (2.0 x 2.2 x 0.8 m): two frosty glass doors glowing cold blue, shelves of "
             "fish and tins behind them, a FROZEN header light. Its back goes against a wall (+Z); the Glow group "
             "glows. 16 px = 1 m.",
    "paint": [
        {"op": "comment", "note": "[0,0,32,32] the door fronts: blue-white glow, shelves of goods, frost at the bottom"},
        {"op": "fill", "rect": [0, 0, 32, 32], "color": "#9fe8ff"},
        {"op": "gradient", "rect": [0, 0, 32, 32], "top": "#ffffff40", "bottom": "#3a8ac000"},
        {"op": "fill", "rect": [0, 8, 32, 9], "color": "#c8d8e0"},
        {"op": "fill", "rect": [0, 17, 32, 18], "color": "#c8d8e0"},
        {"op": "fill", "rect": [0, 26, 32, 27], "color": "#c8d8e0"},
        {"op": "fill", "rect": [2, 3, 6, 8], "color": "#ff5a8a"}, {"op": "fill", "rect": [7, 4, 11, 8], "color": "#ffd23a"},
        {"op": "fill", "rect": [12, 3, 16, 8], "color": "#5af0a0"}, {"op": "fill", "rect": [18, 4, 23, 8], "color": "#ff5a8a"},
        {"op": "fill", "rect": [24, 3, 30, 8], "color": "#b07aff"},
        {"op": "fill", "rect": [2, 12, 9, 17], "color": "#e8a060"}, {"op": "fill", "rect": [10, 13, 15, 17], "color": "#ffd23a"},
        {"op": "fill", "rect": [17, 12, 24, 17], "color": "#e8a060"}, {"op": "fill", "rect": [25, 13, 30, 17], "color": "#5ac8ff"},
        {"op": "fill", "rect": [2, 21, 8, 26], "color": "#ff7a3a"}, {"op": "fill", "rect": [9, 22, 16, 26], "color": "#5af0a0"},
        {"op": "fill", "rect": [18, 21, 22, 26], "color": "#ff5a8a"}, {"op": "fill", "rect": [23, 22, 30, 26], "color": "#ffd23a"},
        {"op": "dither", "rect": [0, 26, 32, 32], "color": "#ffffff", "top": 0.1, "bottom": 0.7},
        {"op": "line", "from": [15, 0], "to": [15, 31], "color": "#3a3e48"},
        {"op": "line", "from": [16, 0], "to": [16, 31], "color": "#3a3e48"},
        {"op": "fill", "rect": [12, 10, 14, 20], "color": "#e0e4ea"},
        {"op": "fill", "rect": [18, 10, 20, 20], "color": "#e0e4ea"},
        {"op": "edge", "rect": [0, 0, 32, 32], "color": "#3a3e48"},
        {"op": "comment", "note": "[32,0,64,8] the header: FROZEN in cold neon"},
        {"op": "fill", "rect": [32, 0, 64, 8], "color": "#101620"},
        {"op": "text", "pos": [38, 2], "text": "FROZEN", "color": "#7ae8ff", "spacing": 1},
        {"op": "comment", "note": "[32,8,64,40] the cabinet: dark steel"},
        {"op": "fill", "rect": [32, 8, 64, 40], "color": "#2a2e36"},
        {"op": "stripes", "rect": [32, 8, 64, 40], "colors": ["#ffffff0a", "#00000000", "#00000018"], "width": 1, "direction": "horizontal"},
        {"op": "noise", "rect": [32, 8, 64, 40], "amount": 0.3, "spread": 0.12},
        {"op": "comment", "note": "[0,32,32,40] the kick plate: black vents"},
        {"op": "fill", "rect": [0, 32, 32, 40], "color": "#15171c"},
        {"op": "stripes", "rect": [0, 32, 32, 40], "colors": ["#3a3e48", "#15171c"], "width": 1, "direction": "horizontal"},
    ],
    "groups": [
        {"name": "Body", "origin": [0, 0, 0]},
        {"name": "Glow", "origin": [0, 0, -6], "parent": "Body"},
    ],
    "elements": [
        cube("cabinet", "Body", [-16, 0, -6], [16, 35.2, 6.4],
             faces={"north": [0, 32, 32, 40], "south": [32, 8, 64, 40], "east": [32, 8, 64, 40], "west": [32, 8, 64, 40],
                    "up": [32, 8, 64, 40], "down": [32, 8, 64, 40]}),
        cube("doors", "Glow", [-15, 3, -6.6], [15, 31, -6], faces={"north": [0, 0, 32, 32]}),
        cube("header", "Glow", [-16, 31.4, -6.8], [16, 35.2, -6], faces={"north": [32, 0, 64, 8]}),
    ],
}
save(freezer_case)
