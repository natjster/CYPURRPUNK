# 20. Real models from Blockbench + Claude's tool servers (Model Shop, Sound Lab, Icon Studio)

[Back to the contents page](../SETUP_GUIDE.md)


The game is moving from code-built boxes to real low-poly models (ROADMAP.md §5). The first two
were the **trash bin** and the **traffic cone** you see on street corners and in empty yards; the
**getaway car** (the WEDGE CYBER-INTERCEPTOR, section 3) is one too.

### The folders
| Where | What | Who edits it |
|---|---|---|
| `models/blockbench/*.bbmodel` | the **Blockbench projects** (the master copy of each model, texture inside) | you, in Blockbench (double-click the file) |
| `models/*.glb` | what **Godot** loads (made from the .bbmodel) | nobody by hand: it's exported |
| `tools/model_specs/*.json` | Claude's "recipes" the starter models were built from | Claude |
| `tools/sound_specs/overclean.json` | the list of every OVERCLEAN line + effect the Sound Lab made | Claude |

Starter templates, also in `models/blockbench/`:
- `template_cat.bbmodel`: a cat the same size as the game's cat, with the part names the colour
  system needs (Body, Belly, LegL/LegR, Head, Muzzle, Nose, EyeL/EyeR, EarL/EarR, Tail) in the
  groups **Body, Paws, Head (with Ears inside), Tail**, plus three markers: **hat**, **shades**,
  **neck** (where accessories go). Facing north. Model your cat over it and keep the names.
- `template_roomba.bbmodel`: the VAC-COP, with the groups the enemy code looks for: **Body, Eye,
  SirenRed, SirenBlue, Brush**. Keep those names.

**The real ones (in the game since 10 Nov 2026):** `roomba.bbmodel` (VAC-COP and MEGA VAC-COP), `lint_trapper.bbmodel` and
`squirt_drone.bbmodel` (§8). They were first made from recipes in `tools/make_creature_specs.py`
(rounded heads, eyes and octagonal shells are worked out with a bit of maths there); from now on the
.bbmodel files are the master copies: edit them in Blockbench and ask Claude to re-export. Group
names the game needs: the bots need **Body** (flashes when shot), **Eye**
(glows, crit weak spot), **SirenRed**, **SirenBlue**, plus **Brush/Brush2** (VAC-COP brushes),
**Brush** + **Tank** (LINT-TRAPPER roller + glue canister), **Rotors > Rotor1..4** + **Tank**
(SQUIRT-DRONE). A group's pivot is where it turns (brushes, rotors). (`cat.bbmodel` is a mascot cat
that was tried for player cats and reverted on 10 Nov 2026: the game uses the original cat, §11.)

**The weapons (since 10 Nov 2026):** all eight (`pistol`, `tommy_gun`, `frozen_tuna`,
`hairball_blaster`, `yarn_zooka`, `cucumber_launcher`, `neon_bat`, `red_dot` .bbmodel) come from
recipes in `tools/make_weapon_specs.py` and share one 128x128 texture sheet. How they plug into the
weapon scenes, and which parts glow: §9 "The weapon models".

**The rules (from ROADMAP.md):** props under **150 triangles**, characters under **600**,
vehicles under **500**; textures **64x64** (props) or **128x128** (characters, vehicles, and the
weapons' shared sheet). In Blockbench 16 pixels = 1 metre, Y is
up, and the front of a model faces **north**.

### Changing a model yourself
1. Double-click `models/blockbench/trash_bin.bbmodel` (Blockbench opens it).
2. Repaint it (Paint tab) or move / add boxes (Edit tab). **Ctrl+S** to save.
3. Tell Claude "re-export the trash bin" (or run the line below). The new look is in the game the
   next time it starts. Blockbench's own **File > Export > Export glTF Model** (saved over
   `models/trash_bin.glb`) also works.
```powershell
python tools/cypurr_models.py export models/blockbench/trash_bin.bbmodel
```
It prints the triangle count, texture size and groups, and says **NEEDS WORK** if a rule is broken.

### Putting a model into the game (code)
`LevelKit.instantiate_model("res://models/trash_bin.glb", parent, position, yaw)` loads the
model once, puts a copy where you say, and gives it the game's PS1 look: the wobbly vertices,
flat shading and crisp pixels of `psx_lit.gdshader`, keeping the model's own painted texture and
colours. `LevelKit.psx_ify(node)` does just the look, for a model that's already in a scene.
Models have **no collision** on their own: the city puts each bin inside a `StaticBody3D` with a
box (`_add_bin` in `scripts/city_generator.gd`); cones stay walk-through so cars don't stop dead.

**In the editor (no code):** you can drag a `.glb` from the FileSystem dock into a scene. It looks
plain there (Godot's normal material); call `LevelKit.psx_ify($TheModel)` in that scene's script
to give it the PS1 look, or ask Claude.

**Import settings:** a new `.glb` comes with a `.glb.import` file that keeps the texture inside
the model, uncompressed (exact pixels), without level-of-detail copies. Changes you make in
Godot's **Import** tab stay (the export never overwrites an existing .import file).

### How many bins and cones (no code)
Select **City** in `main.tscn` > Inspector > **Street Props (Blockbench Models)**:
**Trash Bin Model / Traffic Cone Model** (which .glb files), **Yard Bins Min/Max** and
**Yard Cones Min/Max** (the junk pile in each empty yard; some cones lie knocked over),
**Corner Prop Chance** (0-1, per sidewalk corner), **Props At Meow Mart**, **Bins Are Solid**.
They're placed with the city's own random numbers, so every player's city still comes out identical.
(This changed the layout of every city seed once: a seed now gives a different city than before.)

### Claude's tool servers (`.mcp.json` + `tools/`)
`.mcp.json` (in the project folder) lists two small helper programs that **Claude Code starts by
itself** when it works in this project (the first time, it asks you to allow them: say yes).
They give Claude new tools. You never run them; they're free and run on this PC.

| Server (file) | Tools it gives Claude |
|---|---|
| **Model Shop** (`tools/model_mcp.py`) | `create_or_edit_bbmodel` (write/change a Blockbench project: boxes, round cans and cones, free-form "poly" shapes like the car's wedge, groups, markers, a painted pixel-art texture), `export_bbmodel_to_glb`, `inspect_model` (triangles, texture size, groups vs the rules), `list_models` |
| **Icon Studio** (`tools/icon_mcp.py`) | `make_item_icon` (an orthographic SIDE PROFILE of any item, rendered from its real scene / .glb: white with darker detail lines, so the HUD can colour it), `make_status_icon` (the sticky paws / catnip / catdip badges), `make_npc_portrait` (coloured head-and-shoulders portrait of a sewer NPC, or `locked_mystery`: a dark silhouette with a "?"), `make_all_icons`, `list_icons` |
| **Sound Lab** (`tools/sound_mcp.py`) | `generate_overclean_voice` (free text-to-speech + robot + loudspeaker echo + chime), `generate_cat_voice_blips` (Animal Crossing style talking cats: `meow_blip_<name>_1..4.wav`; soft and rounded by default, ask for "crunch" for the old harsh PS1 chatter), `generate_ps1_sfx` (crunchy effects: bin clatter, cone bounce, scratch, PA chime, metal clang, plastic tap, or a custom recipe), `list_sounds` |

The real work is in `tools/cypurr_models.py`, `tools/cypurr_sound.py` and `tools/cypurr_icons.py`,
which also run from a terminal (each prints its instructions when run with no arguments).

**They're switched OFF by default (since 11 Nov 2026), to save Claude usage.** Every helper that is switched on
adds its tool list to every Claude session, even ones that never touch art. To use one for an art or sound job:
1. Open `.claude/settings.local.json` in the project folder (Notepad is fine).
2. Delete that helper's line from the `disabledMcpjsonServers` list (`cypurrpunk-models` = Model Shop,
   `cypurrpunk-icons` = Icon Studio, `cypurrpunk-sound-lab` = Sound Lab). Watch the commas: the last name has none.
3. Start a NEW Claude session (helpers only start when a session starts). Put the line back when you're done.
Or just ask Claude: it can run the same Python scripts directly without the helpers.

**Icons** (`ui/icons/`): `items/<id>.png` (64x64 side profiles of every held item and loot),
`status/<id>.png` (32x32 badges), `npcs/<id>.png` (64x64 portraits of all 14 sewer NPCs +
`locked_mystery.png`). The icon tool reads the scenes the way Godot does (BoxMesh / SphereMesh /
CylinderMesh / CapsuleMesh / PrismMesh / TorusMesh sizes, node positions / rotations / scales, and
the .glb files the guns use), so after a model changes, remake its icon:
```powershell
python tools/cypurr_icons.py all
C:\GoDot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
```
How each item is looked at (side view, from above for round tins, laid down for melee) is the
`ITEMS` table at the top of `tools/cypurr_icons.py`. Remake every OVERCLEAN line:
```powershell
python tools/cypurr_sound.py batch tools/sound_specs/overclean.json
```

**One-time setup on a new PC:** Python 3, then `python -m pip install -r tools/requirements.txt`,
and ffmpeg (`winget install Gyan.FFmpeg`). The voice needs internet while it's being made (it uses
Microsoft Edge's free voices); the game never does. `tools/` has a `.gdignore`, so Godot skips it.
If Claude says the tools aren't there, restart Claude Code in this folder (or type `/mcp` in a
terminal Claude Code to see them).
